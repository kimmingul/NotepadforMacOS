import Foundation
import SwiftUI
import Combine
import AppKit

struct EditorCommand: Equatable {
    let id = UUID()
    let documentID: UUID
    let action: EditorCommandAction
}

enum EditorCommandAction: Equatable {
    case find(search: String, matchCase: Bool)
    case replace(search: String, replacement: String, matchCase: Bool)
    case goToLine(Int)
}

/// 탭 전체를 관리. Windows 11 Notepad의 탭 동작을 모방
final class TabManager: ObservableObject {
    @Published var tabs: [Document] = []
    @Published var selectedTabID: UUID?
    @Published var cursorLine: Int = 1
    @Published var cursorCol: Int = 1
    @Published var pendingEditorCommand: EditorCommand?

    private var cancellables = Set<AnyCancellable>()
    private let sessionStore = SessionStore.shared
    private let sessionID: UUID?
    private var terminationObserver: NSObjectProtocol?
    private var sessionResetObserver: NSObjectProtocol?

    // MARK: - Init & Restore

    init(sessionID: UUID? = nil) {
        self.sessionID = sessionID

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
        forcePersist()
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

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasSelected = selectedTabID == id
        tabs.remove(at: index)

        if wasSelected {
            if tabs.isEmpty {
                newTab() // 항상 최소 1개 탭 유지 (Notepad 스타일)
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
            if !tabs[index].isDirty {
                tabs[index].isDirty = true
            }
        }
    }

    // MARK: - File Operations

    @discardableResult
    func openFile(url: URL, preferredEncoding: TextEncoding? = nil) -> Bool {
        // 이미 같은 파일이 열려 있으면 해당 탭으로 이동
        if let existing = tabs.firstIndex(where: { $0.fileURL == url }) {
            selectedTabID = tabs[existing].id
            return true
        }

        // 재실행 후에도 접근하기 위해 보안 스코프 북마크를 생성(권한이 있는 현재 URL 기준).
        let bookmark = SecurityScopedFile.makeBookmark(for: url)
        guard let data = try? Data(contentsOf: url) else { return false }

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
        tabs.append(doc)
        selectedTabID = doc.id
        persistSession()
        return true
    }

    /// 현재 선택 탭 저장
    @discardableResult
    func saveCurrentTab(to url: URL? = nil) -> Bool {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return false }

        return saveTab(id, to: url, encoding: tabs[index].encoding, lineEnding: tabs[index].lineEnding)
    }

    @discardableResult
    func saveTab(_ id: UUID, to url: URL? = nil, encoding: TextEncoding? = nil, lineEnding: LineEnding? = nil) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return false }

        let targetURL = url ?? tabs[index].fileURL

        if targetURL == nil {
            // Save As 필요 — 호출 측에서 패널 띄워야 함
            return false
        }

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
            return false
        }

        guard let destination = targetURL else { return false }
        let isNewTarget = (url != nil && url != doc.fileURL)

        // 기존 파일 재저장은 보안 스코프 북마크로 접근; Save As(새 URL)는 패널이 권한 부여.
        var wrote = false
        if isNewTarget || doc.securityScopedBookmark == nil {
            wrote = ((try? data.write(to: destination, options: .atomic)) != nil)
        } else {
            SecurityScopedFile.access(destination, bookmark: doc.securityScopedBookmark) { resolved in
                wrote = ((try? data.write(to: resolved, options: .atomic)) != nil)
            }
        }
        guard wrote else { return false }

        tabs[index].fileURL = destination
        tabs[index].isDirty = false
        tabs[index].loadError = false
        // 새 위치이거나 북마크가 없으면 재실행 후 접근을 위해 북마크 생성/갱신
        if isNewTarget || tabs[index].securityScopedBookmark == nil {
            tabs[index].securityScopedBookmark = SecurityScopedFile.makeBookmark(for: destination)
        }
        persistSession()
        return true
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

    func startNewSession() {
        sessionStore.clearSession(sessionID: sessionID)
        resetToFreshTab()
    }

    private func resetToFreshTab() {
        tabs.removeAll()
        selectedTabID = nil
        cursorLine = 1
        cursorCol = 1
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

    func insertTimeDate() {
        guard let id = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a M/d/yyyy"   // Windows Notepad 스타일
        let timeString = formatter.string(from: Date())

        let current = tabs[index].content
        let newContent = current + (current.isEmpty || current.hasSuffix("\n") ? "" : "\n") + timeString + "\n"

        tabs[index].content = newContent
        tabs[index].isDirty = true
    }

    func updateCursor(line: Int, col: Int) {
        cursorLine = line
        cursorCol = col
    }

    // MARK: - Editor Commands

    func findInSelectedTab(search: String, matchCase: Bool) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        pendingEditorCommand = EditorCommand(
            documentID: id,
            action: .find(search: search, matchCase: matchCase)
        )
    }

    func replaceInSelectedTab(search: String, replacement: String, matchCase: Bool) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        pendingEditorCommand = EditorCommand(
            documentID: id,
            action: .replace(search: search, replacement: replacement, matchCase: matchCase)
        )
    }

    func replaceAllInSelectedTab(search: String, replacement: String, matchCase: Bool) {
        guard let id = selectedTabID, !search.isEmpty else { return }
        let options: String.CompareOptions = matchCase ? [] : .caseInsensitive
        guard let current = selectedTab?.content else { return }
        let newContent = current.replacingOccurrences(of: search, with: replacement, options: options)
        updateContent(for: id, newContent: newContent)
    }

    func goToLineInSelectedTab(_ line: Int) {
        guard let id = selectedTabID, line > 0 else { return }
        pendingEditorCommand = EditorCommand(documentID: id, action: .goToLine(line))
    }
}
