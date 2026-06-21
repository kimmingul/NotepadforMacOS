import Foundation
import Combine

/// Windows 11 Notepad의 TabState / session restore와 최대한 유사하게 동작
/// - 저장하지 않은 탭의 내용도 함께 저장
/// - 앱 재시작 / 재부팅 후 복원
/// - 설정에 따라 새 세션 시작 가능
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    private let fileManager = FileManager.default
    private var sessionDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotepadForMacOS", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func directory(for sessionID: UUID?) -> URL {
        guard let sessionID else {
            return sessionDirectory
        }

        let dir = sessionDirectory
            .appendingPathComponent("Windows", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func manifestURL(sessionID: UUID?) -> URL {
        directory(for: sessionID).appendingPathComponent("session.json")
    }

    /// 세션 내용(텍스트)은 개별 파일로 저장 (큰 내용 대비)
    private func contentFileURL(for id: UUID, sessionID: UUID?) -> URL {
        directory(for: sessionID).appendingPathComponent("\(id.uuidString).txt")
    }

    @Published var shouldRestorePreviousSession: Bool = true

    private var saveWorkItems: [String: DispatchWorkItem] = [:]

    private init() {
        loadSettings()
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

    /// 디바운스 저장 (편집 중 과도한 디스크 쓰기 방지)
    func scheduleSave(tabs: [Document], selectedID: UUID?, sessionID: UUID? = nil) {
        let key = sessionKey(for: sessionID)
        saveWorkItems[key]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.saveSession(tabs: tabs, selectedID: selectedID, sessionID: sessionID)
        }
        saveWorkItems[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// 즉시 저장 (탭 닫기, 종료 시, force)
    func saveSession(tabs: [Document], selectedID: UUID?, sessionID: UUID? = nil) {
        var manifest: [String: Any] = [
            "version": 1,
            "selectedTabID": selectedID?.uuidString ?? "",
            "timestamp": Date().timeIntervalSince1970,
            "tabs": []
        ]

        var tabInfos: [[String: Any]] = []

        for tab in tabs {
            var info: [String: Any] = [
                "id": tab.id.uuidString,
                "encoding": tab.encoding.rawValue,
                "lineEnding": tab.lineEnding.rawValue,
                "isDirty": tab.isDirty,
                "createdAt": tab.createdAt.timeIntervalSince1970
            ]

            if let url = tab.fileURL {
                info["filePath"] = url.path
            }

            // dirty이거나 untitled면 내용 별도 저장
            if tab.isDirty || tab.fileURL == nil {
                let contentURL = contentFileURL(for: tab.id, sessionID: sessionID)
                do {
                    try tab.content.write(to: contentURL, atomically: true, encoding: .utf8)
                    info["hasContentFile"] = true
                } catch {
                    print("Failed to write content for session: \(error)")
                }
            } else {
                // 파일 기반 + clean → 내용 파일 삭제 (용량 절약)
                let contentURL = contentFileURL(for: tab.id, sessionID: sessionID)
                try? fileManager.removeItem(at: contentURL)
            }

            tabInfos.append(info)
        }

        manifest["tabs"] = tabInfos

        do {
            let data = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
            try data.write(to: manifestURL(sessionID: sessionID), options: .atomic)
        } catch {
            print("Session manifest save failed: \(error)")
        }
    }

    // MARK: - Load / Restore

    /// 앱 시작 시 호출. Windows처럼 이전 세션 복원
    func loadSession(sessionID: UUID? = nil) -> (tabs: [Document], selectedID: UUID?) {
        guard shouldRestorePreviousSession else {
            return ([], nil)
        }

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
            guard let idStr = info["id"] as? String,
                  let id = UUID(uuidString: idStr) else { continue }

            let encRaw = info["encoding"] as? String ?? TextEncoding.utf8.rawValue
            let encoding = TextEncoding(rawValue: encRaw) ?? .utf8

            let leRaw = info["lineEnding"] as? String ?? LineEnding.lf.rawValue
            let lineEnding = LineEnding(rawValue: leRaw) ?? .lf

            let isDirty = info["isDirty"] as? Bool ?? false
            let hasContentFile = info["hasContentFile"] as? Bool ?? false

            var content = ""
            var fileURL: URL?

            if let path = info["filePath"] as? String {
                fileURL = URL(fileURLWithPath: path)
            }

            // 내용 복원 우선순위 (robust for missing files)
            if hasContentFile {
                let contentURL = contentFileURL(for: id, sessionID: sessionID)
                if let savedContent = try? String(contentsOf: contentURL, encoding: .utf8) {
                    content = savedContent
                } else if let url = fileURL, let data = try? Data(contentsOf: url), let decoded = encoding.decode(data: data) {
                    content = decoded
                }
            } else if let url = fileURL {
                if let data = try? Data(contentsOf: url), let decoded = encoding.decode(data: data) {
                    content = decoded
                } else {
                    // File disappeared — keep as untitled with empty or previous? For now empty + mark dirty conceptually in caller
                    content = ""
                }
            }

            var finalIsDirty = isDirty
            if fileURL != nil && content.isEmpty {
                finalIsDirty = true
            }

            var doc = Document(
                fileURL: fileURL,
                content: content,
                encoding: encoding,
                lineEnding: lineEnding,
                isDirty: finalIsDirty
            )
            doc.id = id   // 기존 ID 유지 (중요)

            if let ts = info["createdAt"] as? TimeInterval {
                doc.createdAt = Date(timeIntervalSince1970: ts)
            }

            restoredTabs.append(doc)
        }

        // 생성 시간순 정렬 (Windows처럼)
        restoredTabs.sort { $0.createdAt < $1.createdAt }

        // 선택 ID가 유효한지 확인
        if let sel = selectedID, !restoredTabs.contains(where: { $0.id == sel }) {
            selectedID = restoredTabs.first?.id
        }

        if restoredTabs.isEmpty {
            // 최소 하나의 빈 탭
            restoredTabs.append(Document())
            selectedID = restoredTabs.first?.id
        }

        return (restoredTabs, selectedID)
    }

    /// 세션 완전 삭제 (새 세션 시작 시)
    func clearSession(sessionID: UUID? = nil) {
        let dir = directory(for: sessionID)

        if sessionID != nil {
            try? fileManager.removeItem(at: dir)
            return
        }

        try? fileManager.removeItem(at: manifestURL(sessionID: nil))
        // 내용 파일들도 삭제
        if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "txt" {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func clearAllSessions() {
        try? fileManager.removeItem(at: sessionDirectory)
        try? fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        saveWorkItems.values.forEach { $0.cancel() }
        saveWorkItems.removeAll()
    }

    /// 종료 시 정리 (필요시)
    func cleanupOldSessions() {
        // 간단 구현: 오래된 내용 파일 정리 가능
    }

    private func sessionKey(for sessionID: UUID?) -> String {
        sessionID?.uuidString ?? "primary"
    }
}
