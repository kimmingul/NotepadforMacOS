import Foundation
import Combine

/// Windows 11 Notepad의 세션 복원과 최대한 유사하게 동작.
/// - 저장하지 않은 탭의 내용도 함께 저장
/// - 앱 재시작 / 재부팅 후 복원
/// - 설정에 따라 새 세션 시작 가능
///
/// 디스크 쓰기는 메인 스레드를 막지 않도록 전용 백그라운드 직렬 큐에서 수행한다.
/// 파일 기반 탭은 평문 경로 대신 보안 스코프 북마크로 접근 권한을 함께 보존한다.
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    private let fileManager = FileManager.default

    /// 모든 디스크 I/O를 직렬화하는 백그라운드 큐 (메인 스레드 보호).
    private let ioQueue = DispatchQueue(label: "com.nanumspace.mgkim.NotepadForMacOS.session-io", qos: .utility)

    @Published var shouldRestorePreviousSession: Bool = true

    private var saveWorkItems: [String: DispatchWorkItem] = [:]

    private init() {
        loadSettings()
    }

    // MARK: - Paths (I/O 없이 URL만 구성)

    private var sessionRoot: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("NotepadForMacOS", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
    }

    private func directory(for sessionID: UUID?) -> URL {
        guard let sessionID else { return sessionRoot }
        return sessionRoot
            .appendingPathComponent("Windows", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
    }

    private func manifestURL(sessionID: UUID?) -> URL {
        directory(for: sessionID).appendingPathComponent("session.json")
    }

    private func contentFileURL(for id: UUID, in dir: URL) -> URL {
        dir.appendingPathComponent("\(id.uuidString).txt")
    }

    // MARK: - Settings (간단 @AppStorage 대체)

    func loadSettings() {
        let key = "ShouldRestorePreviousSession"
        if UserDefaults.standard.object(forKey: key) != nil {
            shouldRestorePreviousSession = UserDefaults.standard.bool(forKey: key)
        } else {
            shouldRestorePreviousSession = true // Windows 기본값
        }
    }

    func setRestorePreviousSession(_ value: Bool) {
        shouldRestorePreviousSession = value
        UserDefaults.standard.set(value, forKey: "ShouldRestorePreviousSession")
    }

    // MARK: - Save

    /// 디바운스 저장 (편집 중 과도한 디스크 쓰기 방지). 실제 쓰기는 ioQueue에서 실행.
    func scheduleSave(tabs: [Document], selectedID: UUID?, sessionID: UUID? = nil) {
        let key = sessionKey(for: sessionID)
        saveWorkItems[key]?.cancel()

        let snapshots = tabs.map(TabSnapshot.init)
        let dir = directory(for: sessionID)
        let manifest = manifestURL(sessionID: sessionID)
        let selected = selectedID

        let work = DispatchWorkItem {
            SessionStore.performSave(snapshots, selectedID: selected, dir: dir, manifestURL: manifest)
        }
        saveWorkItems[key] = work
        ioQueue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// 즉시 저장 (탭 닫기, 종료 시, force). 종료 직전에도 완료를 보장하도록 동기 실행.
    func saveSession(tabs: [Document], selectedID: UUID?, sessionID: UUID? = nil) {
        let key = sessionKey(for: sessionID)
        saveWorkItems[key]?.cancel()
        saveWorkItems[key] = nil

        let snapshots = tabs.map(TabSnapshot.init)
        let dir = directory(for: sessionID)
        let manifest = manifestURL(sessionID: sessionID)

        ioQueue.sync {
            SessionStore.performSave(snapshots, selectedID: selectedID, dir: dir, manifestURL: manifest)
        }
    }

    /// 디스크 쓰기 본체. 메인 액터 상태에 접근하지 않는 순수 함수(ioQueue에서 실행).
    private nonisolated static func performSave(
        _ tabs: [TabSnapshot],
        selectedID: UUID?,
        dir: URL,
        manifestURL: URL
    ) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var tabInfos: [[String: Any]] = []
        for tab in tabs {
            var info: [String: Any] = [
                "id": tab.id.uuidString,
                "encoding": tab.encoding,
                "lineEnding": tab.lineEnding,
                "isDirty": tab.isDirty,
                "createdAt": tab.createdAt.timeIntervalSince1970
            ]
            if let path = tab.filePath { info["filePath"] = path }
            if let bookmark = tab.bookmark { info["bookmark"] = bookmark.base64EncodedString() }

            let contentURL = dir.appendingPathComponent("\(tab.id.uuidString).txt")
            if tab.writeContent {
                // dirty 또는 untitled → 내용 별도 저장
                if (try? tab.content.write(to: contentURL, atomically: true, encoding: .utf8)) != nil {
                    info["hasContentFile"] = true
                }
            } else {
                // 파일 기반 + clean → 임시 내용 파일 정리 (용량 절약)
                try? fm.removeItem(at: contentURL)
            }
            tabInfos.append(info)
        }

        let manifest: [String: Any] = [
            "version": 2,
            "selectedTabID": selectedID?.uuidString ?? "",
            "timestamp": Date().timeIntervalSince1970,
            "tabs": tabInfos
        ]

        if let data = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    // MARK: - Load / Restore

    /// 앱 시작 시 호출. Windows처럼 이전 세션 복원.
    func loadSession(sessionID: UUID? = nil) -> (tabs: [Document], selectedID: UUID?) {
        guard shouldRestorePreviousSession else { return ([], nil) }

        let dir = directory(for: sessionID)
        guard let data = try? Data(contentsOf: manifestURL(sessionID: sessionID)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tabInfos = json["tabs"] as? [[String: Any]] else {
            return ([], nil)
        }

        var restoredTabs: [Document] = []
        var selectedID: UUID?
        if let selStr = json["selectedTabID"] as? String, !selStr.isEmpty {
            selectedID = UUID(uuidString: selStr)
        }

        for info in tabInfos {
            guard let idStr = info["id"] as? String, let id = UUID(uuidString: idStr) else { continue }

            let encoding = TextEncoding(rawValue: info["encoding"] as? String ?? "") ?? .utf8
            let lineEnding = LineEnding(rawValue: info["lineEnding"] as? String ?? "") ?? .lf
            let savedDirty = info["isDirty"] as? Bool ?? false
            let hasContentFile = info["hasContentFile"] as? Bool ?? false

            var bookmark: Data?
            if let b64 = info["bookmark"] as? String { bookmark = Data(base64Encoded: b64) }

            var fileURL: URL?
            if let path = info["filePath"] as? String { fileURL = URL(fileURLWithPath: path) }
            // 북마크가 있으면 그쪽이 더 신뢰할 수 있는 위치 (샌드박스 접근 보존)
            if let bookmark {
                var stale = false
                if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                                           relativeTo: nil, bookmarkDataIsStale: &stale) {
                    fileURL = resolved
                }
            }

            var content = ""
            var loadError = false

            if hasContentFile {
                // 저장하지 않은 작업 내용이 우선 (source of truth)
                let contentURL = contentFileURL(for: id, in: dir)
                content = (try? String(contentsOf: contentURL, encoding: .utf8)) ?? ""
            } else if let url = fileURL {
                // clean 파일 기반 탭 → 디스크에서 보안 스코프 접근으로 읽기
                var read: String?
                SecurityScopedFile.access(url, bookmark: bookmark) { resolved in
                    if let data = try? Data(contentsOf: resolved) {
                        read = encoding.decode(data: data) ?? String(data: data, encoding: .utf8)
                    }
                }
                if let read {
                    content = read
                } else {
                    // 원본을 읽지 못함 → 빈 내용으로 덮어쓰지 않도록 표시(자동 dirty 금지)
                    loadError = true
                }
            }

            var doc = Document(
                fileURL: fileURL,
                securityScopedBookmark: bookmark,
                content: content,
                encoding: encoding,
                lineEnding: lineEnding,
                isDirty: savedDirty && hasContentFile   // 미저장 내용이 있을 때만 dirty 유지
            )
            doc.id = id
            doc.loadError = loadError
            if let ts = info["createdAt"] as? TimeInterval {
                doc.createdAt = Date(timeIntervalSince1970: ts)
            }
            restoredTabs.append(doc)
        }

        restoredTabs.sort { $0.createdAt < $1.createdAt }

        if let sel = selectedID, !restoredTabs.contains(where: { $0.id == sel }) {
            selectedID = restoredTabs.first?.id
        }
        if restoredTabs.isEmpty {
            let fresh = Document()
            restoredTabs = [fresh]
            selectedID = fresh.id
        }

        return (restoredTabs, selectedID)
    }

    // MARK: - Clear

    /// 세션 완전 삭제 (새 세션 시작 / 창 닫힘 시)
    func clearSession(sessionID: UUID? = nil) {
        // 지연된 저장이 디렉터리를 다시 만들지 않도록 먼저 취소
        let key = sessionKey(for: sessionID)
        saveWorkItems[key]?.cancel()
        saveWorkItems[key] = nil

        let dir = directory(for: sessionID)
        let manifest = manifestURL(sessionID: sessionID)
        let fm = fileManager
        let hasWindowID = sessionID != nil
        ioQueue.async {
            if hasWindowID {
                try? fm.removeItem(at: dir)
                return
            }
            try? fm.removeItem(at: manifest)
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "txt" {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    func clearAllSessions() {
        saveWorkItems.values.forEach { $0.cancel() }
        saveWorkItems.removeAll()
        let root = sessionRoot
        let fm = fileManager
        ioQueue.sync {
            try? fm.removeItem(at: root)
            try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    /// 닫힌 보조 창의 세션 디렉터리(Sessions/Windows/<uuid>)는 명시적으로 삭제되지 않아
    /// 누적될 수 있다. 오래된(기본 30일) 디렉터리를 정리해 무한 증가와 미저장 텍스트 잔존을 막는다.
    /// macOS 상태 복원은 최근 종료만 대상으로 하므로 오래된 디렉터리 삭제는 복원에 영향을 주지 않는다.
    func pruneOrphanedWindowSessions(olderThanDays days: Int = 30) {
        let windowsDir = sessionRoot.appendingPathComponent("Windows", isDirectory: true)
        let fm = fileManager
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        ioQueue.async {
            guard let entries = try? fm.contentsOfDirectory(
                at: windowsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for dir in entries {
                let modified = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified < cutoff {
                    try? fm.removeItem(at: dir)
                }
            }
        }
    }

    private func sessionKey(for sessionID: UUID?) -> String {
        sessionID?.uuidString ?? "primary"
    }
}

/// 메인 액터의 `[Document]`를 백그라운드 쓰기로 안전하게 넘기기 위한 Sendable 스냅샷.
private struct TabSnapshot: Sendable {
    let id: UUID
    let filePath: String?
    let bookmark: Data?
    let encoding: String
    let lineEnding: String
    let isDirty: Bool
    let createdAt: Date
    let content: String
    let writeContent: Bool

    nonisolated init(_ doc: Document) {
        id = doc.id
        filePath = doc.fileURL?.path
        bookmark = doc.securityScopedBookmark
        encoding = doc.encoding.rawValue
        lineEnding = doc.lineEnding.rawValue
        isDirty = doc.isDirty
        createdAt = doc.createdAt
        content = doc.content
        // 미저장 내용이 있는 경우(dirty 또는 untitled)에만 스크래치 파일 작성.
        // 단, 복원 실패(loadError) 탭은 빈 내용을 덮어쓰지 않도록 작성하지 않음.
        writeContent = (doc.isDirty || doc.fileURL == nil) && !doc.loadError
    }
}
