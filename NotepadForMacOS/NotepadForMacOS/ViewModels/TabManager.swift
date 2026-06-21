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
            tabs[index].isDirty = true
            // 사용자가 직접 내용을 입력했으므로 더 이상 '원본 읽기 실패' 상태가 아니다.
            // (이 플래그를 비워야 편집 내용이 세션 스크래치로 저장된다.)
            tabs[index].loadError = false
        }
    }

    // MARK: - File Operations

    @discardableResult
    func openFile(url: URL, preferredEncoding: TextEncoding? = nil) -> Bool {
        // 이미 같은 파일이 열려 있으면 해당 탭으로 이동 (경로 표준화로 심볼릭/북마크 차이 흡수)
        let target = url.standardizedFileURL
        if let existing = tabs.firstIndex(where: { $0.fileURL?.standardizedFileURL == target }) {
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

    /// 현재 시간을 Windows Notepad 형식으로 커서 위치에 삽입(실행취소 가능, 에디터에서 처리).
    func insertTimeDate() {
        guard let id = selectedTabID else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a M/d/yyyy"   // Windows Notepad 스타일
        let timeString = formatter.string(from: Date())
        pendingEditorCommand = EditorCommand(documentID: id, action: .insertText(timeString))
    }

    func updateCursor(line: Int, col: Int, selectionLength: Int = 0) {
        cursorLine = line
        cursorCol = col
        self.selectionLength = selectionLength
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
