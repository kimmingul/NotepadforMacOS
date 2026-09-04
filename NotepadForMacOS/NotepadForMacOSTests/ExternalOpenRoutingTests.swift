import XCTest
@testable import Notepad

/// Finder/Dock로 들어온 파일을 어느 창이 열지 결정하는 규칙.
///
/// 배경: 실행 중에 파일을 열면 SwiftUI `WindowGroup`이 창을 새로 만들었고, 그 창은 값이 없어
/// (`UUID?` == nil) 첫 창과 같은 루트 세션을 다시 복원했다. 그래서 기존 탭이 전부 복제돼 보이고,
/// 두 창이 같은 `session.json`에 번갈아 써서 마지막에 쓴 창이 이겼다.
@MainActor
final class ExternalOpenRoutingTests: XCTestCase {

    private func makeTempFile(_ contents: String, name: String, in dirName: String? = nil) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(dirName ?? "route-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - 세션 신원

    /// 루트 세션은 프로세스에서 처음 만들어진 창 하나만 갖는다.
    /// 값 없는 창이 여러 개 생기면 나머지는 자기 UUID 세션을 받아야 한다.
    func testOnlyFirstValuelessWindowClaimsRootSession() {
        let identity = EditorSessionIdentity()

        XCTAssertNil(identity.resolve(nil), "첫 창은 루트 세션을 갖는다")

        let second = identity.resolve(nil)
        let third = identity.resolve(nil)
        XCTAssertNotNil(second, "두 번째 값 없는 창이 루트 세션을 또 쓰면 세션 파일을 서로 덮어쓴다")
        XCTAssertNotNil(third)
        XCTAssertNotEqual(second, third, "창마다 다른 세션이어야 한다")
    }

    /// New Window가 넘긴 값은 그대로 유지된다(창별 세션 복원).
    func testExplicitWindowValueIsPreserved() {
        let identity = EditorSessionIdentity()
        let requested = UUID()
        XCTAssertEqual(identity.resolve(requested), requested)
        XCTAssertNil(identity.resolve(nil), "명시적 값은 루트 클레임을 소비하지 않는다")
    }

    func testPrimarySessionFlagMatchesSessionID() {
        XCTAssertTrue(TabManager(sessionID: nil).ownsPrimarySession)
        XCTAssertFalse(TabManager(sessionID: UUID()).ownsPrimarySession)
    }

    // MARK: - 같은 파일 판정 (앱 전역 중복 방지)

    /// 같은 디렉터리의 같은 파일은 같은 파일이다.
    func testSameFileIsDetectedInWindow() throws {
        let url = try makeTempFile("내용\n", name: "same.txt")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertFalse(manager.hasTab(forFileAt: url))
        XCTAssertTrue(manager.openFile(url: url))
        XCTAssertTrue(manager.hasTab(forFileAt: url))
    }

    /// 이름만 같고 디렉터리가 다르면 다른 파일이다(사용자 요구 사항).
    func testSameNameInAnotherDirectoryIsADifferentFile() throws {
        let first = try makeTempFile("첫 번째\n", name: "report.txt")
        let second = try makeTempFile("두 번째\n", name: "report.txt")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: first))

        XCTAssertFalse(
            manager.hasTab(forFileAt: second),
            "이름이 같아도 다른 디렉터리의 파일은 같은 파일이 아니다"
        )
    }

    // MARK: - 여분의 빈 창 정리 조건

    /// 실행 직후 정리 대상은 '손대지 않은 빈 탭 하나'인 창뿐이다.
    func testUntouchedPlaceholderWindowIsRecognised() {
        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.holdsOnlyUntouchedPlaceholder, "새 창은 빈 자리표시자 탭 하나로 시작한다")
    }

    /// 입력한 내용이 있는 창은 절대 정리 대상이 아니다(미저장 내용 보호).
    func testWindowWithTypedTextIsNotAPlaceholder() throws {
        let manager = TabManager(sessionID: UUID())
        let id = try XCTUnwrap(manager.selectedTabID)
        manager.updateContent(for: id, newContent: "작성 중")

        XCTAssertFalse(manager.holdsOnlyUntouchedPlaceholder, "미저장 내용이 있는 창을 닫으면 안 된다")
    }

    /// 파일이 열려 있는 창도 정리 대상이 아니다.
    func testWindowWithFileTabIsNotAPlaceholder() throws {
        let url = try makeTempFile("파일\n", name: "kept.txt")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: url))

        XCTAssertFalse(manager.holdsOnlyUntouchedPlaceholder)
    }

    /// 탭이 여러 개면(빈 탭을 사용자가 추가한 경우 포함) 정리 대상이 아니다.
    func testWindowWithSeveralTabsIsNotAPlaceholder() {
        let manager = TabManager(sessionID: UUID())
        manager.newTab()

        XCTAssertFalse(manager.holdsOnlyUntouchedPlaceholder)
    }
}
