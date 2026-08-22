import XCTest
@testable import Notepad

final class SourceHighlightKindTests: XCTestCase {

    func testDetectsOfficialLanguages() {
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.md")), .markdown)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.markdown")), .markdown)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.json")), .json)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/A.JSON")), .json)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.xml")), .xml)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.html")), .html)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.htm")), .html)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/a.log")), .log)
    }

    func testPlainTextAndUntitledHaveNoHighlight() {
        XCTAssertEqual(SourceHighlightKind.of(fileURL: nil), .none)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/note.txt")), .none)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/note")), .none)
        XCTAssertEqual(SourceHighlightKind.of(fileURL: URL(fileURLWithPath: "/tmp/main.swift")), .none)
    }
}

final class SourceHighlighterTests: XCTestCase {

    func testDoesNotRepaintDuringMarkedText() {
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: true, length: 10))
        XCTAssertTrue(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: false, length: 10))
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: false, hasMarkedText: false, length: 10))
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: false, length: 0))
    }

    func testMarkdownFenceBodyIsNotEmphasis() {
        let text = """
        # Title
        ```
        code *not italic*
        ```
        *italic*
        """
        XCTAssertEqual(style(of: "# Title", in: text, kind: .markdown), .heading)
        XCTAssertEqual(style(of: "*not italic*", in: text, kind: .markdown), .codeBlock)
        XCTAssertEqual(style(of: "*italic*", in: text, kind: .markdown), .emphasis)
    }

    func testMarkdownInlineCodeWinsOverEmphasis() {
        let text = "see `*code*` and **bold**"
        XCTAssertEqual(style(of: "`*code*`", in: text, kind: .markdown), .inlineCode)
        XCTAssertEqual(style(of: "**bold**", in: text, kind: .markdown), .emphasis)
    }

    func testJSONTokens() {
        let text = #"{"name": "Ada", "n": 12, "ok": true}"#
        XCTAssertEqual(style(of: "\"name\"", in: text, kind: .json), .jsonKey)
        XCTAssertEqual(style(of: "\"Ada\"", in: text, kind: .json), .jsonString)
        XCTAssertEqual(style(of: "12", in: text, kind: .json), .jsonNumber)
        XCTAssertEqual(style(of: "true", in: text, kind: .json), .jsonLiteral)
    }

    func testXMLTokens() {
        let text = #"<!-- hi --><item id="1"></item>"#
        XCTAssertEqual(style(of: "<!-- hi -->", in: text, kind: .xml), .xmlComment)
        XCTAssertEqual(style(of: "<item", in: text, kind: .xml), .xmlTag)
        XCTAssertEqual(style(of: "id", in: text, kind: .xml), .xmlAttribute)
        XCTAssertEqual(style(of: "\"1\"", in: text, kind: .xml), .xmlString)
    }

    func testLogTokens() {
        let text = #"2026-08-22 10:00:00 ERROR boom "x""#
        XCTAssertEqual(style(of: "2026-08-22 10:00:00", in: text, kind: .log), .logTimestamp)
        XCTAssertEqual(style(of: "ERROR", in: text, kind: .log), .logError)
        XCTAssertEqual(style(of: "\"x\"", in: text, kind: .log), .logString)
    }

    func testNoneYieldsNoTokens() {
        XCTAssertTrue(SourceHighlighter.tokens(in: "# Title", kind: .none).isEmpty)
    }

    private func style(of snippet: String, in text: String, kind: SourceHighlightKind) -> SourceHighlightStyle? {
        let ns = text as NSString
        let range = ns.range(of: snippet)
        guard range.location != NSNotFound else { return nil }
        return SourceHighlighter.tokens(in: text, kind: kind)
            .first { NSIntersectionRange($0.range, range).length == range.length }?
            .style
    }
}
