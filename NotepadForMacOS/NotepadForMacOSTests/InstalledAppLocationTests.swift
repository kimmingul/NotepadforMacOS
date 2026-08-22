import XCTest
@testable import Notepad

final class InstalledAppLocationTests: XCTestCase {

    func testClassifiesApplicationsAndDiskImage() {
        XCTAssertEqual(
            InstalledAppLocation.classify("/Applications/Notepad.app"),
            .applications
        )
        XCTAssertEqual(
            InstalledAppLocation.classify("/Volumes/Notepad/Notepad.app"),
            .diskImage
        )
        XCTAssertEqual(
            InstalledAppLocation.classify("/Volumes/Notepad 1.2.4/Notepad.app"),
            .diskImage
        )
        XCTAssertEqual(
            InstalledAppLocation.classify("/Users/min/Applications/Notepad.app", home: "/Users/min"),
            .applications
        )
        XCTAssertEqual(
            InstalledAppLocation.classify("/Users/min/Downloads/Notepad.app", home: "/Users/min"),
            .other
        )
    }

    func testRegisterPrefersApplicationsCopyWhenRunningFromDiskImage() {
        var registered: URL?
        let installed = URL(fileURLWithPath: "/Applications/Notepad.app")
        let target = LaunchServicesRegistration.registerPreferredCopy(
            runningPath: "/Volumes/Notepad/Notepad.app",
            applicationsCopy: installed,
            fileExists: { $0 == installed },
            register: { registered = $0 }
        )
        XCTAssertEqual(target, installed)
        XCTAssertEqual(registered, installed)
    }

    func testRegisterUsesRunningApplicationsCopy() {
        var registered: URL?
        let running = "/Applications/Notepad.app"
        let target = LaunchServicesRegistration.registerPreferredCopy(
            runningPath: running,
            applicationsCopy: URL(fileURLWithPath: "/Applications/Other.app"),
            fileExists: { _ in false },
            register: { registered = $0 }
        )
        XCTAssertEqual(target?.path, running)
        XCTAssertEqual(registered?.path, running)
    }

    func testRegisterDoesNothingWhenOnlyDiskImageExists() {
        var registered: URL?
        let target = LaunchServicesRegistration.registerPreferredCopy(
            runningPath: "/Volumes/Notepad/Notepad.app",
            applicationsCopy: URL(fileURLWithPath: "/Applications/Notepad.app"),
            fileExists: { _ in false },
            register: { registered = $0 }
        )
        XCTAssertNil(target)
        XCTAssertNil(registered)
    }
}
