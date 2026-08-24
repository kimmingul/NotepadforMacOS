import XCTest
@testable import Notepad

/// 탭 닫기 동작. 마지막 탭을 닫으면 창이 닫혀야 하므로(Windows 11 메모장과 동일),
/// TabManager는 그 경우 빈 탭을 새로 만들지 않아야 한다.
@MainActor
final class CloseTabTests: XCTestCase {

    /// 마지막 탭을 창 닫기 흐름으로 닫으면 탭이 남지 않아야 한다.
    /// 빈 탭이 새로 생기면 창이 닫히기 직전에 세션에 들어가고, 사용자가 보기에는
    /// 탭을 닫았는데 아무 일도 일어나지 않는다.
    func testClosingLastTabForWindowCloseLeavesNoTab() throws {
        let manager = TabManager(sessionID: UUID())
        let id = try XCTUnwrap(manager.selectedTabID)
        XCTAssertEqual(manager.tabs.count, 1, "새 창은 빈 무제 탭 하나로 시작한다")

        manager.closeTab(id, replacingLastTab: false)

        XCTAssertTrue(manager.tabs.isEmpty, "창을 닫는 흐름에서는 빈 탭을 새로 만들면 안 된다")
        XCTAssertNil(manager.selectedTabID)
    }

    /// 기본 동작(창을 닫지 않는 경우)은 최소 1개 탭을 유지한다.
    func testClosingLastTabByDefaultKeepsOneTab() throws {
        let manager = TabManager(sessionID: UUID())
        let id = try XCTUnwrap(manager.selectedTabID)

        manager.closeTab(id)

        XCTAssertEqual(manager.tabs.count, 1, "기본 동작은 빈 탭 하나를 유지한다")
        XCTAssertNotEqual(manager.selectedTabID, id, "닫은 탭이 아니라 새 탭이 선택되어야 한다")
    }

    /// 여러 탭 중 하나를 닫으면 인접 탭이 선택된다.
    func testClosingOneOfSeveralSelectsNeighbour() throws {
        let manager = TabManager(sessionID: UUID())
        manager.newTab(content: "두 번째")
        manager.newTab(content: "세 번째")
        XCTAssertEqual(manager.tabs.count, 3)

        let middle = manager.tabs[1].id
        manager.selectTab(middle)
        manager.closeTab(middle)

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.selectedTabID, manager.tabs[1].id, "닫은 자리의 인접 탭이 선택되어야 한다")
    }

    /// 선택되지 않은 탭을 닫아도 선택은 그대로 유지된다.
    func testClosingUnselectedTabKeepsSelection() throws {
        let manager = TabManager(sessionID: UUID())
        manager.newTab(content: "두 번째")
        let selected = try XCTUnwrap(manager.selectedTabID)
        let other = try XCTUnwrap(manager.tabs.first { $0.id != selected }?.id)

        manager.closeTab(other)

        XCTAssertEqual(manager.selectedTabID, selected)
        XCTAssertEqual(manager.tabs.count, 1)
    }
}
