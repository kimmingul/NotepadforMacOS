import XCTest
@testable import Notepad

final class SpellingPreferencesTests: XCTestCase {

    func testParseDisabledExtensions_commasAndSpaces() {
        let set = SpellingPreferences.parseDisabledExtensions("log, JSON; swift\nmd")
        XCTAssertEqual(set, Set(["log", "json", "swift", "md"]))
    }

    func testParseDisabledExtensions_stripsDots() {
        let set = SpellingPreferences.parseDisabledExtensions(".log, .Py")
        XCTAssertEqual(set, Set(["log", "py"]))
    }

    func testParseDisabledExtensions_empty() {
        XCTAssertTrue(SpellingPreferences.parseDisabledExtensions("").isEmpty)
        XCTAssertTrue(SpellingPreferences.parseDisabledExtensions("  , ; ").isEmpty)
    }

    func testSerializeDisabledExtensions_sorted() {
        let raw = SpellingPreferences.serializeDisabledExtensions(["swift", "log", "json"])
        XCTAssertEqual(raw, "json, log, swift")
    }

    func testSpellingAllowed_globalOff() {
        let allowed = SpellingPreferences.isSpellingAllowed(
            pathExtension: "txt",
            spellCheckEnabled: false,
            disabledExtensions: ["log"]
        )
        XCTAssertFalse(allowed)
    }

    func testSpellingAllowed_untitledUsesGlobal() {
        XCTAssertTrue(
            SpellingPreferences.isSpellingAllowed(
                pathExtension: nil,
                spellCheckEnabled: true,
                disabledExtensions: ["log"]
            )
        )
        XCTAssertTrue(
            SpellingPreferences.isSpellingAllowed(
                pathExtension: "",
                spellCheckEnabled: true,
                disabledExtensions: ["log"]
            )
        )
    }

    func testSpellingAllowed_disabledExtension() {
        let disabled = SpellingPreferences.parseDisabledExtensions(SpellingPreferences.defaultDisabledExtensionsRaw)
        XCTAssertFalse(
            SpellingPreferences.isSpellingAllowed(
                pathExtension: "swift",
                spellCheckEnabled: true,
                disabledExtensions: disabled
            )
        )
        XCTAssertTrue(
            SpellingPreferences.isSpellingAllowed(
                pathExtension: "txt",
                spellCheckEnabled: true,
                disabledExtensions: disabled
            )
        )
    }

    func testSpellingAllowed_fileURLHelper() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        XCTAssertTrue(
            SpellingPreferences.isSpellingAllowed(
                fileURL: url,
                spellCheckEnabled: true,
                disabledExtensionsRaw: "log,json"
            )
        )
        let log = URL(fileURLWithPath: "/tmp/app.log")
        XCTAssertFalse(
            SpellingPreferences.isSpellingAllowed(
                fileURL: log,
                spellCheckEnabled: true,
                disabledExtensionsRaw: "log,json"
            )
        )
    }
}
