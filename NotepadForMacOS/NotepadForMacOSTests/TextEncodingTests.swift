import XCTest
@testable import Notepad

@MainActor
final class TextEncodingTests: XCTestCase {

    func testUTF8Roundtrip() throws {
        let text = "Hello 안녕하세요 😀 123"
        let data = try XCTUnwrap(TextEncoding.utf8.encode(text))
        let decoded = TextEncoding.utf8.decode(data: data)
        XCTAssertEqual(decoded, text)
    }

    func testUTF8BOMAddsAndStripsBOM() throws {
        let text = "한글 BOM test"
        let data = try XCTUnwrap(TextEncoding.utf8BOM.encode(text))
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF], "UTF-8 BOM prefix expected")
        let decoded = TextEncoding.utf8BOM.decode(data: data)
        XCTAssertEqual(decoded, text, "BOM should be stripped on decode")
    }

    func testEUCKRRoundtrip() throws {
        let text = "안녕하세요 테스트 123"
        let data = try XCTUnwrap(TextEncoding.eucKR.encode(text))
        let decoded = TextEncoding.eucKR.decode(data: data)
        XCTAssertEqual(decoded, text)
    }

    func testEUCKRCannotEncodeUnrepresentable() {
        XCTAssertTrue(TextEncoding.eucKR.canEncode("안녕하세요"))
        XCTAssertFalse(TextEncoding.eucKR.canEncode("😀"), "Emoji is not representable in EUC-KR")
    }

    func testUTF16Roundtrips() throws {
        let text = "UTF-16 한글 ✓"
        let le = try XCTUnwrap(TextEncoding.utf16LE.encode(text))
        XCTAssertEqual(TextEncoding.utf16LE.decode(data: le), text)
        let be = try XCTUnwrap(TextEncoding.utf16BE.encode(text))
        XCTAssertEqual(TextEncoding.utf16BE.decode(data: be), text)
    }

    func testDetectByBOM() {
        XCTAssertEqual(TextEncoding.detect(from: Data([0xEF, 0xBB, 0xBF, 0x41])), .utf8BOM)
        XCTAssertEqual(TextEncoding.detect(from: Data([0xFF, 0xFE, 0x41, 0x00])), .utf16LE)
        XCTAssertEqual(TextEncoding.detect(from: Data([0xFE, 0xFF, 0x00, 0x41])), .utf16BE)
    }

    func testDetectPlainUTF8() throws {
        let data = try XCTUnwrap("plain ascii and 한글".data(using: .utf8))
        XCTAssertEqual(TextEncoding.detect(from: data), .utf8)
    }
}
