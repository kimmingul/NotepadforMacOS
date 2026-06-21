import XCTest
@testable import Notepad

final class LineEndingTests: XCTestCase {

    func testDetect() {
        XCTAssertEqual(LineEnding.detect(in: "a\r\nb"), .crlf)
        XCTAssertEqual(LineEnding.detect(in: "a\rb"), .cr)
        XCTAssertEqual(LineEnding.detect(in: "a\nb"), .lf)
        XCTAssertEqual(LineEnding.detect(in: "no breaks"), .lf)
    }

    func testNormalizeToCRLF() {
        let mixed = "a\nb\r\nc\rd"
        XCTAssertEqual(LineEnding.crlf.normalize(mixed), "a\r\nb\r\nc\r\nd")
    }

    func testNormalizeToLF() {
        let mixed = "a\nb\r\nc\rd"
        XCTAssertEqual(LineEnding.lf.normalize(mixed), "a\nb\nc\nd")
    }

    func testNormalizeIsIdempotentForLF() {
        let lf = "line1\nline2\n"
        XCTAssertEqual(LineEnding.lf.normalize(lf), lf)
    }
}
