import XCTest
@testable import Notepad

final class MarkdownImageLoaderTests: XCTestCase {

    func testFileBookmarkDoesNotServeMarkdownAsImage() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let markdownURL = dir.appendingPathComponent("note.md")
        try Data("not-an-image".utf8).write(to: markdownURL)
        let fileBookmark = SecurityScopedFile.makeBookmark(for: markdownURL)
        XCTAssertNotNil(fileBookmark)

        let request = try XCTUnwrap(
            MarkdownImagePolicy.customSchemeURL(kind: "local", payload: "missing.png")
        )
        let result = await MarkdownImageLoader.load(
            url: request,
            documentDirectory: dir,
            directoryBookmark: nil,
            allowsRemote: false
        )

        if case .data = result {
            XCTFail("file bookmark must not return the markdown file as image bytes")
        }
    }

    func testRemoteHTTPIsDeniedEvenWhenAllowed() async throws {
        let request = try XCTUnwrap(
            MarkdownImagePolicy.customSchemeURL(kind: "remote", payload: "http://example.com/a.png")
        )
        let result = await MarkdownImageLoader.load(
            url: request,
            documentDirectory: nil,
            directoryBookmark: nil,
            allowsRemote: true
        )
        XCTAssertEqual(result, .denied)
    }
}

final class MarkdownSourceHighlighterTests: XCTestCase {

    func testDoesNotRepaintDuringMarkedText() {
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: true, length: 10))
        XCTAssertTrue(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: false, length: 10))
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: false, hasMarkedText: false, length: 10))
        XCTAssertFalse(SourceHighlighter.shouldRepaint(enabled: true, hasMarkedText: false, length: 0))
    }

}

final class MarkdownPreviewReloadTests: XCTestCase {

    func testReloadsWhenDirectoryBookmarkChanges() {
        let html = "<p>same</p>"
        let before = Data([1])
        let after = Data([2])
        XCTAssertFalse(
            MarkdownPreviewReload.shouldReload(
                html: html,
                lastHTML: html,
                directoryBookmark: before,
                lastDirectoryBookmark: before
            )
        )
        XCTAssertTrue(
            MarkdownPreviewReload.shouldReload(
                html: html,
                lastHTML: html,
                directoryBookmark: after,
                lastDirectoryBookmark: before
            )
        )
    }
}
