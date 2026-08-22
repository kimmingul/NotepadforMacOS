import XCTest
@testable import Notepad

final class OpenableDocumentTypeTests: XCTestCase {

    func testAcceptsPlainTextAndMarkdownExtensions() {
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/note.txt")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/note.text")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/note.md")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/NOTE.MD")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/readme.markdown")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/app.log")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/data.json")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/config.xml")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/index.html")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/index.htm")))
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/main.swift")))
    }

    func testAcceptsExtensionlessFiles() {
        XCTAssertTrue(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/Makefile")))
    }

    func testRejectsDirectoriesBinariesAndRemoteURLs() {
        XCTAssertFalse(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp", isDirectory: true)))
        XCTAssertFalse(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/photo.png")))
        XCTAssertFalse(OpenableDocumentType.isOpenable(URL(fileURLWithPath: "/tmp/doc.pdf")))
        XCTAssertFalse(OpenableDocumentType.isOpenable(URL(string: "https://example.com/note.txt")!))
    }

    func testFiltersMixedDropList() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/n.md"),
            URL(fileURLWithPath: "/tmp", isDirectory: true)
        ]
        XCTAssertEqual(
            OpenableDocumentType.openableURLs(in: urls).map(\.lastPathComponent),
            ["a.txt", "n.md"]
        )
    }
}
