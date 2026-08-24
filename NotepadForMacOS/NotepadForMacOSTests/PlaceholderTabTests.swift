import XCTest
@testable import Notepad

/// 실행 시 만들어지는 빈 '제목 없음' 자리표시자 탭 처리.
///
/// 세션이 비어 있으면 창은 항상 자리표시자 탭 하나로 시작한다. 그 상태에서 Finder가 문서를
/// 넘기면 자리표시자가 남아 "빈 탭 + 파일 탭" 두 개가 됐다.
@MainActor
final class PlaceholderTabTests: XCTestCase {

    private func makeTempFile(_ contents: String, name: String = "A.txt") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ph-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// 모든 탭을 닫은 뒤(세션이 빈 상태) 파일을 열면 탭은 하나여야 한다.
    func testOpeningFileReplacesEmptyPlaceholder() throws {
        let url = try makeTempFile("A 내용\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertEqual(manager.tabs.count, 1, "빈 세션은 자리표시자 탭 하나로 시작한다")
        XCTAssertTrue(try XCTUnwrap(manager.tabs.first).isPlaceholder)

        XCTAssertTrue(manager.openFile(url: url))

        XCTAssertEqual(manager.tabs.count, 1, "빈 '제목 없음' 탭이 남아 파일 탭과 나란히 생겼다")
        let tab = try XCTUnwrap(manager.tabs.first)
        XCTAssertEqual(tab.fileURL?.lastPathComponent, "A.txt")
        XCTAssertEqual(tab.content, "A 내용\n")
        XCTAssertEqual(manager.selectedTabID, tab.id)
    }

    /// 자리표시자에 사용자가 입력한 내용이 있으면 버리지 않는다.
    func testOpeningFileKeepsTypedUntitledTab() throws {
        let url = try makeTempFile("A 내용\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        let untitled = try XCTUnwrap(manager.selectedTabID)
        manager.updateContent(for: untitled, newContent: "작성 중인 메모")

        XCTAssertTrue(manager.openFile(url: url))

        XCTAssertEqual(manager.tabs.count, 2, "입력 중인 무제 탭을 버리면 안 된다")
        XCTAssertEqual(manager.document(with: untitled)?.content, "작성 중인 메모")
    }

    /// 파일 탭이 이미 있으면 빈 무제 탭은 사용자가 만든 것이므로 유지한다.
    func testPlaceholderKeptWhenOtherTabsExist() throws {
        let first = try makeTempFile("첫 파일\n", name: "B.txt")
        let second = try makeTempFile("둘째 파일\n", name: "C.txt")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: first))   // 자리표시자를 대체
        manager.newTab()                              // 사용자가 직접 만든 빈 탭
        XCTAssertEqual(manager.tabs.count, 2)

        XCTAssertTrue(manager.openFile(url: second))

        XCTAssertEqual(manager.tabs.count, 3, "사용자가 만든 빈 탭까지 없애면 안 된다")
    }

    /// 파일 두 개를 한 번에 열면 자리표시자 하나만 대체되고 둘 다 열린다.
    func testOpeningTwoFilesFromPlaceholderYieldsTwoTabs() throws {
        let a = try makeTempFile("A\n", name: "A.txt")
        let b = try makeTempFile("B\n", name: "B.txt")
        defer {
            try? FileManager.default.removeItem(at: a.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: b.deletingLastPathComponent())
        }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: a))
        XCTAssertTrue(manager.openFile(url: b))

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs.compactMap { $0.fileURL?.lastPathComponent }, ["A.txt", "B.txt"])
    }
}
