import XCTest
@testable import Notepad

final class MarkdownDocumentKindTests: XCTestCase {

    func testMarkdownExtensions() {
        XCTAssertTrue(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/note.md")))
        XCTAssertTrue(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/NOTE.MD")))
        XCTAssertTrue(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/readme.markdown")))
    }

    func testNonMarkdownStaysPlain() {
        XCTAssertFalse(MarkdownDocumentKind.isMarkdown(fileURL: nil))
        XCTAssertFalse(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/note.txt")))
        XCTAssertFalse(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/note")))
        XCTAssertFalse(MarkdownDocumentKind.isMarkdown(fileURL: URL(fileURLWithPath: "/tmp/note.md.bak")))
    }
}
