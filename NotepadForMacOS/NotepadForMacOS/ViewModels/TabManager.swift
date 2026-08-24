import Foundation
import SwiftUI
import Combine
import AppKit

/// 저장 시도 결과. 실패 원인을 구분해야 호출 측이 알림과 재승인 패널을 올바르게 고를 수 있다.
enum SaveOutcome: Equatable {
    /// 디스크에 기록 완료.
    case saved
    /// 저장할 경로가 없음 → 호출 측에서 Save As 패널이 필요.
    case noTarget
    /// 선택한 인코딩으로 표현할 수 없는 문자가 있음.
    case encodingFailed
    /// 이 파일에 쓸 권한이 없음(문서를 열 때 만든 읽기 전용 북마크만 있는 상태).
    /// 호출 측에서 같은 경로로 저장 패널을 띄워 사용자가 한 번 승인하면 이후로는 직접 저장된다.
    case notAuthorized
    /// 권한은 있으나 디스크 기록이 실패.
    case writeFailed
}

struct EditorCommand: Equatable {
    let id = UUID()
    let documentID: UUID
    let action: EditorCommandAction
}

enum EditorCommandAction: Equatable {
    case find(search: String, matchCase: Bool, forward: Bool, wrap: Bool)
    case replaceCurrent(search: String, replacement: String, matchCase: Bool)
    case replaceAll(search: String, replacement: String, matchCase: Bool)
    case insertText(String)        // 커서 위치에 삽입 (Time/Date 등), 실행취소 가능
    case setText(String)           // 전체 교체 (인코딩 다시 열기 등)
    case goToLine(Int)
    case printDocument
}

/// 탭 전체를 관리. Windows 11 Notepad의 탭 동작을 모방
final class TabManager: ObservableObject {
    @Published var tabs: [Document] = []
    @Published var selectedTabID: UUID?
    @Published var cursorLine: Int = 1
    @Published var cursorCol: Int = 1
    @Published var selectionLength: Int = 0
    @Published var pendingEditorCommand: EditorCommand?

    /// 마지막 검색어/옵션 (다음 찾기·이전 찾기 반복용)
    private var lastSearch: String = ""
    private var lastMatchCase: Bool = false
    private var lastWrap: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let sessionStore = SessionStore.shared
    private let sessionID: UUID?
    private var terminationObserver: NSObjectProtocol?
    private var sessionResetObserver: NSObjectProtocol?
    private var pendingCursorState: CursorState?

    private struct CursorState: Equatable {
        let documentID: UUID
        let line: Int
        let col: Int
        let selectionLength: Int
    }

    // MARK: - Init & Restore

    init(sessionID: UUID? = nil) {
        self.sessionID = sessionID

        // 기본(첫) 창에서 한 번, 오래된 보조 창 세션 디렉터리를 정리
        if sessionID == nil {
            sessionStore.pruneOrphanedWindowSessions()
        }

        // 시작 시 세션 복원
        restoreFromSession()

        // 내용 변경 시 세션 저장 스케줄 (dirty 처리는 updateContent에서 담당)
        $tabs
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistSession()
            }
            .store(in: &cancellables)

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NotepadTextInput.commitActiveComposition()
            self?.forcePersist()
        }

        sessionResetObserver = NotificationCenter.default.addObserver(
            forName: .startNewSessionRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetToFreshTab()
        }
    }

    deinit {
        // 영속화는 onDisappear(창 닫힘)와 willTerminate(앱 종료) 옵저버가 메인 스레드에서
        // 이미 처리한다. deinit은 임의 스레드에서 실행될 수 있어 여기서 디스크 I/O를 하지 않는다.
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        if let sessionResetObserver {
            NotificationCenter.default.removeObserver(sessionResetObserver)
        }
    }

    private func restoreFromSession() {
        let (restored, selected) = sessionStore.loadSession(sessionID: sessionID)
        self.tabs = restored
        self.selectedTabID = selected ?? restored.first?.id

        // 빈 상태면 새 탭 하나 생성
        if tabs.isEmpty {
            newTab()
        }
    }

    // MARK: - Tab Operations

    var selectedTab: Document? {
        guard let id = selectedTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    func document(with id: UUID) -> Document? {
        tabs.first { $0.id == id }
    }

    func selectTab(_ id: UUID) {
        selectedTabID = id
        persistSession()
    }

    /// 다음 탭으로 순환 (Ctrl+Tab)
    func selectNextTab() {
        guard tabs.count > 1, let id = selectedTabID,
              let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectTab(tabs[(idx + 1) % tabs.count].id)
    }

    /// 이전 탭으로 순환 (Ctrl+Shift+Tab)
    func selectPreviousTab() {
        guard tabs.count > 1, let id = selectedTabID,
              let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectTab(tabs[(idx - 1 + tabs.count) % tabs.count].id)
    }

    /// 드래그로 탭 재정렬: `id` 탭을 `targetID` 탭 위치로 이동.
    func moveTab(_ id: UUID, before targetID: UUID) {
        guard id != targetID, let from = tabs.firstIndex(where: { $0.id == id }) else { return }
        let moved = tabs.remove(at: from)
        let insertIndex = tabs.firstIndex(where: { $0.id == targetID }) ?? min(from, tabs.count)
        tabs.insert(moved, at: insertIndex)
        persistSession()
    }

    func newTab(content: String = "", fileURL: URL? = nil) {
        let defaultEncRaw = UserDefaults.standard.string(forKey: "defaultEncodingRaw") ?? TextEncoding.utf8.rawValue
        let defaultEnc = TextEncoding(rawValue: defaultEncRaw) ?? .utf8

        let newDoc = Document(
            fileURL: fileURL,
            content: content,
            encoding: defaultEnc,
            lineEnding: .lf,
            isDirty: fileURL == nil && !content.isEmpty
        )
        tabs.append(newDoc)
        selectedTabID = newDoc.id
        persistSession()
    }

    /// 탭을 닫는다.
    ///
    /// - Parameter replacingLastTab: 마지막 탭을 닫을 때 빈 탭을 새로 만들지 여부.
    ///   창을 닫는 흐름에서는 false를 넘겨야 한다. true로 두면 창이 닫히기 직전에 빈 탭이
    ///   생겨 세션에 남고, 사용자가 보기에는 탭을 닫았는데 아무 일도 일어나지 않는다.
    func closeTab(_ id: UUID, replacingLastTab: Bool = true) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasSelected = selectedTabID == id
        tabs.remove(at: index)

        if wasSelected {
            if tabs.isEmpty {
                if replacingLastTab {
                    newTab() // 항상 최소 1개 탭 유지 (Notepad 스타일)
                } else {
                    selectedTabID = nil
                }
            } else {
                // 인접 탭 선택 (Windows처럼)
                let newIndex = min(index, tabs.count - 1)
                selectedTabID = tabs[newIndex].id
            }
        }

        persistSession()
    }

    // MARK: - Content & State

    func updateContent(for id: UUID, newContent: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if tabs[index].content != newContent {
            tabs[index].content = newContent
            tabs[index].isDirty = true
            // loadError는 "원본을 한 번도 읽지 못했다"는 사실이므로 입력으로 지우지 않는다.
            // 지우면 저장 시 덮어쓰기 확인이 건너뛰어지고, 읽지 못한 원본이 거의 빈 내용으로
            // 조용히 덮어써진다. 편집 내용의 세션 보존은 isDirty가 결정한다.
        }
    }

    func setDirectoryBookmark(_ data: Data?, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].directoryBookmark = data
        persistSession()
    }

    // MARK: - File Operations

    @discardableResult
    func openFile(url: URL, preferredEncoding: TextEncoding? = nil) -> Bool {
        // 이미 같은 파일이 열려 있으면 그 탭으로 이동한다.
        //
        // 단, 그 탭이 복원 때 원본을 읽지 못한 상태(loadError)면 그냥 전환하면 안 된다.
        // 복원 시점에는 유효한 북마크가 없으면 샌드박스가 읽기를 거부하는데, 지금은 Launch
        // Services가 이 URL에 접근 권한을 부여한 상태다. 그대로 전환만 하면 그 탭은 영구히 빈
        // 화면으로 남아, Finder에서 몇 번을 열어도 내용이 나오지 않는다.
        //
        // 이 경우 깨진 탭을 자리에서 빼고 아래의 정상 열기 경로로 새로 읽는다. 별도 재읽기
        // 경로를 두면 읽기 전용 북마크 생성이 실패해(측정 확인) 다음 실행에서 또 빈 탭이 된다.
        let target = Self.identity(of: url)
        var replacementIndex: Int?
        if let existing = tabs.firstIndex(where: { $0.fileURL.map(Self.identity) == target }) {
            guard tabs[existing].loadError else {
                // 정상적으로 열려 있는 탭이면 그 탭으로만 전환한다(미저장 편집 보호).
                //
                // 다만 북마크가 없는 탭은 여기서 발급해 둔다. 세션에 경로만 있고 북마크가 없는
                // 탭도 `com.apple.macl`이 남아 있는 동안은 복원 읽기가 성공하기 때문에
                // loadError가 아니고, 그러면 아무도 북마크를 만들지 않는다. 그 상태로 macl
                // 접근이 끊기면(다른 앱이 파일을 새로 쓰는 등) 그 탭은 조용히 빈 탭이 된다.
                // 지금은 Launch Services가 이 URL에 접근 권한을 준 시점이라 발급할 수 있다.
                if tabs[existing].securityScopedBookmark == nil,
                   let fresh = SecurityScopedFile.makeBookmark(for: url, readOnly: true) {
                    tabs[existing].securityScopedBookmark = fresh
                    tabs[existing].bookmarkAllowsWriting = false
                    persistSession()
                }
                selectedTabID = tabs[existing].id
                return true
            }
            tabs.remove(at: existing)
            replacementIndex = existing
        }

        // 재실행 후에도 **읽을** 수 있도록 읽기 전용 보안 스코프 북마크를 만든다.
        // 여기서 쓰기 가능 북마크를 만들면 Foundation이 문서를 open(O_RDWR)로 열고,
        // App Sandbox가 그 쓰기 의도 open에 com.apple.quarantine을 전파한다(내용/mtime은
        // 그대로인데 격리만 붙어 이후 Finder 열기마다 Gatekeeper 대화상자가 뜬다).
        // 쓰기 가능 북마크는 실제 저장이 성공한 뒤에만 만든다(saveTab 참고).
        var bookmark = SecurityScopedFile.makeBookmark(for: url, readOnly: true)
        guard let data = try? Data(contentsOf: url) else { return false }
        if bookmark == nil {
            // 깨진 탭을 교체하는 경로에서 첫 시도가 실패하는 경우가 관측됐다. 읽기가 성공한
            // 지금 한 번 더 시도한다. 그래도 실패하면 이번 실행에서는 내용만 보여주고, 다음에
            // 이 파일을 다시 열 때 북마크를 만든다(복원 시 빈 탭이 되는 것보다 낫다).
            bookmark = SecurityScopedFile.makeBookmark(for: url, readOnly: true)
        }

        let encoding = preferredEncoding ?? TextEncoding.detect(from: data)
        let content = encoding.decode(data: data) ?? String(data: data, encoding: .utf8) ?? ""
        let le = LineEnding.detect(in: content)

        let doc = Document(
            fileURL: url,
            securityScopedBookmark: bookmark,
            content: content,
            encoding: encoding,
            lineEnding: le,
            isDirty: false
        )
        // 자리 결정:
        //  - 복원 실패로 비운 탭이 있으면 그 자리를 유지해 탭 순서가 튀지 않게 한다.
        //  - 그렇지 않고 창이 빈 '제목 없음' 자리표시자 하나뿐이면 그 자리를 대체한다.
        //    (세션이 비었을 때 항상 만들어지는 탭이라, 그대로 두면 Finder에서 파일을 열 때
        //     빈 탭과 파일 탭이 함께 남는다.)
        if replacementIndex == nil, tabs.count == 1, tabs[0].isPlaceholder {
            tabs.removeAll()
            replacementIndex = 0
        }
        if let replacementIndex, replacementIndex <= tabs.count {
            tabs.insert(doc, at: replacementIndex)
        } else {
            tabs.append(doc)
        }
        selectedTabID = doc.id
        persistSession()
        return true
    }

    /// 같은 파일인지 비교하기 위한 신원.
    ///
    /// 파일이 존재하면 파일 시스템이 주는 식별자(inode + device)를 쓴다. 경로 문자열 비교는
    /// 세 가지 경우에 같은 파일을 다른 파일로 오판하고, 그러면 한 파일에 두 탭이 열려 서로의
    /// 편집을 덮어쓴다.
    ///   - 한글 등 비ASCII 이름: 파일 시스템은 분해형(NFD), 세션 저장 경로는 조합형(NFC)
    ///   - macOS 기본 APFS는 대소문자를 구분하지 않는다: `Report.txt`와 `report.txt`가 같은 파일
    ///   - 하드링크나 심볼릭 링크로 같은 파일에 이르는 서로 다른 경로
    ///
    /// 파일이 없으면(삭제됨, 아직 저장 안 됨) 식별자를 얻을 수 없으므로 정규화한 경로로 비교한다.
    private static func identity(of url: URL) -> String {
        // 리소스 값 조회는 심볼릭 링크를 따라가지 않는다. 링크와 대상이 서로 다른 식별자로
        // 보이면 같은 파일에 탭이 두 개 열리므로, 먼저 링크를 해소한다.
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        if let identifier = try? resolved.resourceValues(forKeys: [.fileResourceIdentifierKey])
            .fileResourceIdentifier {
            return "file:\(identifier)"
        }
        return "path:" + resolved.path.precomposedStringWithCanonicalMapping
    }

    /// 현재 선택 탭 저장
    @discardableResult
    func saveCurrentTab(to url: URL? = nil) -> SaveOutcome {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return .noTarget }

        return saveTab(id, to: url, encoding: tabs[index].encoding, lineEnding: tabs[index].lineEnding)
    }

    @discardableResult
    func saveTab(_ id: UUID, to url: URL? = nil, encoding: TextEncoding? = nil, lineEnding: LineEnding? = nil) -> SaveOutcome {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return .noTarget }

        // Save As가 필요한 경우(대상 없음)는 호출 측에서 패널을 띄운다.
        guard let destination = url ?? tabs[index].fileURL else { return .noTarget }

        if let encoding {
            tabs[index].encoding = encoding
        }
        if let lineEnding {
            tabs[index].lineEnding = lineEnding
        }

        let doc = tabs[index]
        let normalizedContent = doc.lineEnding.normalize(doc.content)

        guard let data = doc.encoding.encode(normalizedContent) else {
            // 선택한 인코딩으로 표현할 수 없는 문자가 있음 (호출 측에서 알림 표시)
            return .encodingFailed
        }

        let isNewTarget = (url != nil && url != doc.fileURL)

        // 쓰기 경로 선택:
        // - Save As(새 URL)이거나 북마크가 없으면 패널/Launch Services가 이번 실행에 부여한
        //   권한으로 직접 쓴다.
        // - 쓰기 가능 북마크가 있으면 그 스코프를 열고 쓴다(재실행 후에도 유효).
        // - 읽기 전용 북마크만 있으면(문서를 열었고 아직 한 번도 저장하지 않은 상태) 이번 실행에
        //   남아 있는 권한으로 직접 시도한다. 재실행 이후라면 권한이 없어 실패하고,
        //   .notAuthorized로 호출 측이 재승인 패널을 띄운다.
        var writeError: Error?
        func write(to target: URL) -> Bool {
            do {
                try data.write(to: target, options: .atomic)
                return true
            } catch {
                writeError = error
                return false
            }
        }

        var wrote = false
        if isNewTarget || doc.securityScopedBookmark == nil {
            wrote = write(to: destination)
        } else if doc.bookmarkAllowsWriting {
            SecurityScopedFile.access(
                destination,
                bookmark: doc.securityScopedBookmark,
                readOnly: false
            ) { resolved in
                wrote = write(to: resolved)
            }
        } else {
            wrote = write(to: destination)
        }
        guard wrote else {
            // 실패 원인을 북마크 종류로 추측하면 디스크가 꽉 찬 경우까지 "재승인 필요"로
            // 오판해 엉뚱한 저장 패널을 띄운다. 실제 상황을 보고 판정한다.
            return TabManager.isPermissionFailure(writeError, destination: destination)
                ? .notAuthorized
                : .writeFailed
        }

        tabs[index].fileURL = destination
        tabs[index].isDirty = false
        tabs[index].loadError = false
        // 저장이 성공한 이 시점에는 이미 이 파일에 쓰기 권한이 있다. 그러므로 지금 쓰기 가능
        // 북마크로 승급해도 새로 격리를 유발하지 않는다(방금 우리가 파일을 기록했다).
        // 문서를 여는 시점에 이걸 만들면 안 되는 이유는 makeBookmark 주석 참고.
        if isNewTarget || !tabs[index].bookmarkAllowsWriting {
            if let writable = SecurityScopedFile.makeBookmark(for: destination, readOnly: false) {
                tabs[index].securityScopedBookmark = writable
                tabs[index].bookmarkAllowsWriting = true
            }
        }
        persistSession()
        return .saved
    }

    /// 저장 실패가 권한 문제인지(재승인하면 해결됨), 진짜 디스크 오류인지 구분한다.
    /// 전자는 저장 패널로 한 번 승인받으면 되고, 후자는 사용자에게 알려야 한다.
    ///
    /// 오류 코드만으로는 부족하다. 샌드박스 거부는 여러 코드로 흩어져 나오고, 원자적 쓰기는
    /// 같은 디렉터리에 임시 파일을 만들다 실패하기도 한다. 그래서 대상에 대한 쓰기 권한을
    /// `access(2)`로 직접 확인한다. `access(2)`는 파일을 열지 않으므로 격리 속성을 유발하지 않는다.
    private static func isPermissionFailure(_ error: Error?, destination: URL) -> Bool {
        if let error = error as NSError?, matchesPermissionCode(error) {
            return true
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            return !fileManager.isWritableFile(atPath: destination.path)
        }
        // 새로 만드는 파일은 담길 디렉터리에 쓸 수 있는지가 기준이다.
        return !fileManager.isWritableFile(atPath: destination.deletingLastPathComponent().path)
    }

    private static func matchesPermissionCode(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain,
           error.code == NSFileWriteNoPermissionError || error.code == NSFileWriteVolumeReadOnlyError {
            return true
        }
        if error.domain == NSPOSIXErrorDomain,
           error.code == Int(EACCES) || error.code == Int(EPERM) || error.code == Int(EROFS) {
            return true
        }
        // Foundation은 원인을 NSUnderlyingError로 감싸 올려보내는 경우가 많다.
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return matchesPermissionCode(underlying)
        }
        return false
    }

    // MARK: - Encoding features (요청 핵심 기능)

    /// "파일 열린 인코딩 변경" - Reopen with encoding
    /// 파일 기반일 경우 디스크에서 다시 읽음
    func reopenSelectedWithEncoding(_ newEncoding: TextEncoding) {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        var doc = tabs[index]
        let success = doc.reloadFromDisk(using: newEncoding)

        if success {
            tabs[index] = doc
            // 다시 읽은 내용을 에디터에 반영 (전체 교체)
            pendingEditorCommand = EditorCommand(documentID: id, action: .setText(doc.content))
        } else {
            // 파일이 없거나 실패 → 단순히 플래그 변경
            tabs[index].encoding = newEncoding
            tabs[index].isDirty = true
        }
        persistSession()
    }

    /// Convert to encoding (현재 내용 기준으로 인코딩 변경). 실제 변환은 다음 저장 시 수행.
    /// 대상 인코딩으로 표현할 수 없는 문자가 있으면 false를 반환(호출 측에서 경고 가능).
    @discardableResult
    func convertSelectedToEncoding(_ newEncoding: TextEncoding) -> Bool {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return false }

        let representable = newEncoding.canEncode(tabs[index].content)
        tabs[index].encoding = newEncoding
        tabs[index].isDirty = true
        persistSession()
        return representable
    }

    // MARK: - Session

    private func persistSession() {
        sessionStore.scheduleSave(tabs: tabs, selectedID: selectedTabID, sessionID: sessionID)
    }

    /// Force immediate session save (for app termination, critical points)
    func forcePersist() {
        sessionStore.saveSession(tabs: tabs, selectedID: selectedTabID, sessionID: sessionID)
    }

    /// 사용자가 창을 명시적으로 닫았을 때(앱 종료가 아닌 경우) 호출.
    /// - 기본 창은 항상 보존(다음 실행 시 복원).
    /// - 보조 창은 미저장 내용이 있으면 보존(Windows 11처럼), 없으면 디렉터리를 정리해 누적을 막는다.
    ///   (창 닫기는 탭 닫기 확인을 거치지 않으므로 미저장 내용을 임의로 버리지 않는다.)
    func discardWindowSession() {
        guard sessionID != nil else {
            forcePersist()   // 기본('primary') 세션은 절대 버리지 않음
            return
        }
        let hasUnsaved = tabs.contains { $0.isDirty || ($0.fileURL == nil && !$0.content.isEmpty) }
        if hasUnsaved {
            forcePersist()
        } else {
            sessionStore.clearSession(sessionID: sessionID)
        }
    }

    func startNewSession() {
        sessionStore.clearSession(sessionID: sessionID)
        resetToFreshTab()
    }

    private func resetToFreshTab() {
        pendingCursorState = nil
        tabs.removeAll()
        selectedTabID = nil
        cursorLine = 1
        cursorCol = 1
        selectionLength = 0
        pendingEditorCommand = nil
        newTab()
    }

    // MARK: - Utility

    func updateSelectedEncoding(_ encoding: TextEncoding) {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].encoding = encoding
        tabs[index].isDirty = true
    }

    func updateSelectedLineEnding(_ le: LineEnding) {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].lineEnding = le
        tabs[index].isDirty = true
    }

    // MARK: - Time/Date (F5)

    /// 현재 시간을 Windows Notepad 형식으로 커서 위치에 삽입(실행취소 가능, 에디터에서 처리).
    func insertTimeDate() {
        guard let id = selectedTabID else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a M/d/yyyy"   // Windows Notepad 스타일
        let timeString = formatter.string(from: Date())
        pendingEditorCommand = EditorCommand(documentID: id, action: .insertText(timeString))
    }

    func updateCursor(for documentID: UUID, line: Int, col: Int, selectionLength: Int = 0) {
        guard selectedTabID == documentID else { return }

        let state = CursorState(documentID: documentID, line: line, col: col, selectionLength: selectionLength)
        if pendingCursorState == state { return }
        if pendingCursorState == nil,
           cursorLine == line,
           cursorCol == col,
           self.selectionLength == selectionLength {
            return
        }

        pendingCursorState = state
        DispatchQueue.main.async { [weak self] in
            self?.applyPendingCursorUpdate()
        }
    }

    private func applyPendingCursorUpdate() {
        guard let state = pendingCursorState else { return }
        pendingCursorState = nil

        guard selectedTabID == state.documentID else { return }
        guard cursorLine != state.line ||
              cursorCol != state.col ||
              selectionLength != state.selectionLength else { return }

        cursorLine = state.line
        cursorCol = state.col
        selectionLength = state.selectionLength
    }

    // MARK: - Editor Commands

    func findInSelectedTab(search: String, matchCase: Bool, forward: Bool = true, wrap: Bool = true) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        lastSearch = search
        lastMatchCase = matchCase
        lastWrap = wrap
        pendingEditorCommand = EditorCommand(
            documentID: id,
            action: .find(search: search, matchCase: matchCase, forward: forward, wrap: wrap)
        )
    }

    /// 다음/이전 찾기 (Cmd+G / Cmd+Shift+G). 마지막 검색어를 반복.
    func repeatLastFind(forward: Bool) {
        guard !lastSearch.isEmpty else { return }
        findInSelectedTab(search: lastSearch, matchCase: lastMatchCase, forward: forward, wrap: lastWrap)
    }

    func replaceInSelectedTab(search: String, replacement: String, matchCase: Bool) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        lastSearch = search
        lastMatchCase = matchCase
        pendingEditorCommand = EditorCommand(
            documentID: id,
            action: .replaceCurrent(search: search, replacement: replacement, matchCase: matchCase)
        )
    }

    /// Replace All — 에디터의 textStorage를 통해 한 번에 처리(실행취소 가능).
    func replaceAllInSelectedTab(search: String, replacement: String, matchCase: Bool) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        lastSearch = search
        lastMatchCase = matchCase
        pendingEditorCommand = EditorCommand(
            documentID: id,
            action: .replaceAll(search: search, replacement: replacement, matchCase: matchCase)
        )
    }

    func goToLineInSelectedTab(_ line: Int) {
        guard let id = selectedTabID, line > 0 else { return }
        pendingEditorCommand = EditorCommand(documentID: id, action: .goToLine(line))
    }

    /// 현재 탭 인쇄 요청 (에디터에서 NSPrintOperation 실행).
    func requestPrint() {
        guard let id = selectedTabID else { return }
        pendingEditorCommand = EditorCommand(documentID: id, action: .printDocument)
    }
}
