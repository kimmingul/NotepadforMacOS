import XCTest
@testable import Notepad

@MainActor
final class SessionStoreTests: XCTestCase {

    func testSaveLoadRoundtripPreservesUnsavedContent() throws {
        let store = SessionStore.shared
        store.shouldRestorePreviousSession = true

        // 격리된 윈도우 세션 ID로 실제 세션을 건드리지 않음
        let sessionID = UUID()
        defer { store.clearSession(sessionID: sessionID) }

        var doc = Document(content: "복원 테스트 unsaved 😀", encoding: .utf8, lineEnding: .lf, isDirty: true)
        let id = doc.id

        store.saveSession(tabs: [doc], selectedID: id, sessionID: sessionID)

        let (tabs, selected) = store.loadSession(sessionID: sessionID)
        XCTAssertEqual(tabs.count, 1)
        XCTAssertEqual(tabs.first?.content, "복원 테스트 unsaved 😀")
        XCTAssertEqual(tabs.first?.id, id)
        XCTAssertEqual(selected, id)
        XCTAssertEqual(tabs.first?.isDirty, true)
    }

    func testLoadReturnsEmptyWhenRestoreDisabled() {
        let store = SessionStore.shared
        let sessionID = UUID()
        defer {
            store.shouldRestorePreviousSession = true
            store.clearSession(sessionID: sessionID)
        }

        let doc = Document(content: "x", isDirty: true)
        store.saveSession(tabs: [doc], selectedID: doc.id, sessionID: sessionID)

        store.shouldRestorePreviousSession = false
        let (tabs, _) = store.loadSession(sessionID: sessionID)
        XCTAssertTrue(tabs.isEmpty)
    }
}
