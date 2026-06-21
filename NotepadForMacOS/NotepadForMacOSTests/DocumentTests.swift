import XCTest
@testable import Notepad

@MainActor
final class DocumentTests: XCTestCase {

    func testDirtyTitleHasAsterisk() {
        var doc = Document(fileURL: URL(fileURLWithPath: "/tmp/foo.txt"), content: "x", isDirty: true)
        XCTAssertEqual(doc.displayTitle, "foo.txt")
        XCTAssertEqual(doc.fullTitleForWindow, "foo.txt*")

        doc.isDirty = false
        XCTAssertEqual(doc.fullTitleForWindow, "foo.txt")
    }

    func testUntitledDocumentHasNoFileURL() {
        let doc = Document()
        XCTAssertNil(doc.fileURL)
        XCTAssertFalse(doc.isDirty)
        XCTAssertEqual(doc.encoding, .utf8)
        XCTAssertEqual(doc.lineEnding, .lf)
    }

    func testEqualityIsByIdentity() {
        let a = Document(content: "one")
        var b = a
        b.content = "two"
        XCTAssertEqual(a, b, "Documents are equal by id (tab identity), not content")

        let c = Document(content: "one")
        XCTAssertNotEqual(a, c)
    }
}
