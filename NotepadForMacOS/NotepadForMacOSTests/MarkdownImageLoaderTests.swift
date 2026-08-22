import XCTest
@testable import Notepad

final class MarkdownImageLoaderTests: XCTestCase {

    func testLocalHTMLAndMarkdownAreDenied() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("<html>hi</html>".utf8).write(to: dir.appendingPathComponent("page.html"))
        try Data("not-an-image".utf8).write(to: dir.appendingPathComponent("note.md"))
        try Data("secret".utf8).write(to: dir.appendingPathComponent("x.svg"))
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: dir.appendingPathComponent("ok.png"))

        let html = await loadLocal(payload: "page.html", directory: dir)
        let markdown = await loadLocal(payload: "note.md", directory: dir)
        let svg = await loadLocal(payload: "x.svg", directory: dir)
        let png = await loadLocal(payload: "ok.png", directory: dir)

        XCTAssertEqual(html, .denied)
        XCTAssertEqual(markdown, .denied)
        XCTAssertEqual(svg, .denied)
        if case .data(_, let mime) = png {
            XCTAssertTrue(mime.hasPrefix("image/"))
        } else {
            XCTFail("png sibling should load as image data, got \(png)")
        }
    }

    func testAcceptsOnlyBoundedImageOrCSS() {
        XCTAssertTrue(MarkdownImageLoader.acceptsResource(byteCount: 1, mime: "image/png"))
        XCTAssertTrue(MarkdownImageLoader.acceptsResource(byteCount: 10, mime: "text/css"))
        XCTAssertFalse(MarkdownImageLoader.acceptsResource(byteCount: 0, mime: "image/png"))
        XCTAssertFalse(MarkdownImageLoader.acceptsResource(byteCount: MarkdownImageLoader.maxResourceBytes + 1, mime: "image/png"))
        XCTAssertFalse(MarkdownImageLoader.acceptsResource(byteCount: 10, mime: "text/html"))
        XCTAssertFalse(MarkdownImageLoader.acceptsResource(byteCount: 10, mime: "image/svg+xml"))
        XCTAssertFalse(MarkdownImageLoader.acceptsResource(byteCount: 10, mime: "text/plain"))
    }

    func testPrivateAndNonHTTPSRemoteURLsAreDenied() {
        XCTAssertTrue(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://example.com/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "http://example.com/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://localhost/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://127.0.0.1/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://192.168.1.4/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://10.0.0.5/a.png")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://169.254.169.254/latest")!))
        XCTAssertFalse(MarkdownImageLoader.isAllowedRemoteURL(URL(string: "https://[::1]/a.png")!))
        XCTAssertTrue(MarkdownImageLoader.hostResolvesToPrivateAddress("localhost"))
        XCTAssertTrue(MarkdownImageLoader.hostResolvesToPrivateAddress("127.0.0.1"))
    }

    private func loadLocal(payload: String, directory: URL) async -> MarkdownImageLoadResult {
        let request = MarkdownImagePolicy.customSchemeURL(kind: "local", payload: payload)!
        return await MarkdownImageLoader.load(
            url: request,
            documentDirectory: directory,
            directoryBookmark: nil,
            allowsRemote: false
        )
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

final class MarkdownPreviewNavigationTests: XCTestCase {

    func testCustomSchemeIsResourceOnly() throws {
        let preview = try XCTUnwrap(URL(string: "\(MarkdownImagePolicy.urlScheme)://preview/"))
        let image = try XCTUnwrap(MarkdownImagePolicy.customSchemeURL(kind: "local", payload: "page.html"))
        let https = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: preview, isMainFrame: true), .allow)
        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: image, isMainFrame: true), .cancel)
        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: image, isMainFrame: false), .allow)
        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: https, isMainFrame: true), .openExternally)
        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: URL(string: "about:blank")!, isMainFrame: true), .allow)
        XCTAssertEqual(MarkdownPreviewNavigation.decide(url: URL(string: "javascript:alert(1)")!, isMainFrame: true), .cancel)
    }
}
