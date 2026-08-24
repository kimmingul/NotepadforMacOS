import XCTest
@testable import Notepad

/// 보안 스코프 북마크 수명주기에서 데이터가 조용히 사라질 수 있는 경로를 지킨다.
/// (다중 모델 검토에서 지목된 항목들을 실제로 측정한다.)
@MainActor
final class BookmarkLifecycleTests: XCTestCase {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bml-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 원본을 읽지 못한 탭은 사용자가 입력해도 "읽지 못했다"는 사실을 유지해야 한다.
    /// 이 플래그가 지워지면 저장 시 덮어쓰기 확인이 건너뛰어지고 원본이 조용히 날아간다.
    func testTypingKeepsUnreadOriginalMarked() throws {
        let manager = TabManager(sessionID: UUID())
        var doc = Document(fileURL: URL(fileURLWithPath: "/private/tmp/bml-missing.txt"), content: "")
        doc.loadError = true
        manager.tabs = [doc]
        manager.selectedTabID = doc.id

        manager.updateContent(for: doc.id, newContent: "사용자가 입력한 한 글자")

        let tab = try XCTUnwrap(manager.document(with: doc.id))
        XCTAssertTrue(tab.isDirty)
        XCTAssertTrue(tab.loadError, "입력이 '원본 읽기 실패' 표시를 지우면 덮어쓰기 확인이 사라진다")
    }

    /// 읽지 못한 탭에 입력한 내용은 세션에 보존되어야 한다(위 안전장치 때문에 버려지면 안 됨).
    func testEditsOnUnreadTabStillPersist() throws {
        let store = SessionStore.shared
        store.shouldRestorePreviousSession = true
        let sessionID = UUID()
        defer { store.clearSession(sessionID: sessionID) }

        var doc = Document(fileURL: URL(fileURLWithPath: "/private/tmp/bml-missing.txt"), content: "입력한 내용")
        doc.isDirty = true
        doc.loadError = true

        store.saveSession(tabs: [doc], selectedID: doc.id, sessionID: sessionID)
        let (restored, _) = store.loadSession(sessionID: sessionID)

        let tab = try XCTUnwrap(restored.first)
        XCTAssertEqual(tab.content, "입력한 내용", "읽기 실패 탭의 편집 내용이 유실됐다")
    }

    /// 저장 후 재실행: 쓰기 가능 북마크로 원자적 저장이 되어야 한다.
    /// (원자적 저장은 같은 디렉터리에 임시 파일을 만들므로 파일 범위 토큰으로 되는지 확인.)
    func testSaveAfterRelaunchUsesWritableBookmark() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("doc.txt")
        try "원본\n".write(to: url, atomically: true, encoding: .utf8)

        let store = SessionStore.shared
        store.shouldRestorePreviousSession = true
        let sessionID = UUID()
        defer { store.clearSession(sessionID: sessionID) }

        // 1회차: 열고 저장 → 쓰기 가능 북마크 확보
        let first = TabManager(sessionID: sessionID)
        XCTAssertTrue(first.openFile(url: url))
        let id = try XCTUnwrap(first.selectedTabID)
        first.updateContent(for: id, newContent: "1회차 저장\n")
        XCTAssertEqual(first.saveTab(id), .saved)
        XCTAssertTrue(try XCTUnwrap(first.document(with: id)).bookmarkAllowsWriting)
        first.forcePersist()

        // 2회차: 복원 후 편집·저장이 패널 없이 성공해야 한다
        let second = TabManager(sessionID: sessionID)
        let restored = try XCTUnwrap(second.tabs.first { $0.fileURL != nil })
        XCTAssertTrue(restored.bookmarkAllowsWriting, "저장으로 얻은 쓰기 권한이 복원에서 유지되지 않았다")
        XCTAssertEqual(restored.content, "1회차 저장\n")

        second.updateContent(for: restored.id, newContent: "2회차 저장\n")
        XCTAssertEqual(second.saveTab(restored.id), .saved, "복원된 쓰기 가능 북마크로 원자적 저장이 실패했다")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "2회차 저장\n")
    }

    /// 대소문자만 다른 경로로 같은 파일을 열면 탭이 하나여야 한다.
    /// (macOS 기본 APFS는 대소문자를 구분하지 않는다. 두 탭이 열리면 서로의 편집을 덮어쓴다.)
    func testCaseVariantPathDoesNotDuplicateTab() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Report.txt")
        try "대소문자\n".write(to: url, atomically: true, encoding: .utf8)

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: url))

        let lowered = dir.appendingPathComponent("report.txt")
        guard FileManager.default.fileExists(atPath: lowered.path) else {
            throw XCTSkip("대소문자를 구분하는 볼륨이라 이 경로는 해당 없음")
        }
        XCTAssertTrue(manager.openFile(url: lowered))

        XCTAssertEqual(
            manager.tabs.filter { $0.fileURL != nil }.count, 1,
            "대소문자만 다른 경로로 같은 파일에 두 탭이 열렸다 — 서로의 편집을 덮어쓴다"
        )
    }

    /// 심볼릭 링크와 실제 파일을 각각 열어도 탭은 하나여야 한다.
    func testSymlinkAndTargetShareOneTab() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appendingPathComponent("target.txt")
        try "링크 대상\n".write(to: target, atomically: true, encoding: .utf8)
        let link = dir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: target))
        XCTAssertTrue(manager.openFile(url: link))

        XCTAssertEqual(
            manager.tabs.filter { $0.fileURL != nil }.count, 1,
            "심볼릭 링크와 대상 파일에 각각 탭이 열렸다"
        )
    }
}
