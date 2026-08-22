import XCTest
@testable import Notepad

final class AppTerminatePolicyTests: XCTestCase {

    func testDoesNotQuitDuringLaunch() {
        XCTAssertFalse(
            AppTerminatePolicy.shouldQuitAfterLastWindow(
                hasPendingDocuments: false,
                launchSettled: false
            )
        )
    }

    func testDoesNotQuitWhileDocumentsArePending() {
        XCTAssertFalse(
            AppTerminatePolicy.shouldQuitAfterLastWindow(
                hasPendingDocuments: true,
                launchSettled: true
            )
        )
    }

    func testQuitsAfterLaunchWhenIdle() {
        XCTAssertTrue(
            AppTerminatePolicy.shouldQuitAfterLastWindow(
                hasPendingDocuments: false,
                launchSettled: true
            )
        )
    }
}
