import XCTest
@testable import Notepad

final class MarkdownImagePolicyTests: XCTestCase {

    func testClassifiesRemoteAndLocal() {
        XCTAssertEqual(MarkdownImagePolicy.classify("./img.png"), .localRelative("./img.png"))
        XCTAssertEqual(
            MarkdownImagePolicy.classify("https://example.com/a.png"),
            .remote(URL(string: "https://example.com/a.png")!)
        )
    }


    func testRejectsDangerousSchemes() {
        XCTAssertEqual(MarkdownImagePolicy.classify("javascript:alert(1)"), .rejected)
        XCTAssertEqual(MarkdownImagePolicy.classify("data:image/png;base64,abc"), .rejected)
        XCTAssertEqual(MarkdownImagePolicy.classify("file:///etc/passwd"), .rejected)
        XCTAssertEqual(MarkdownImagePolicy.classify("notepad-md://img"), .rejected)
        XCTAssertEqual(MarkdownImagePolicy.classify("http://example.com/a.png"), .rejected)
        XCTAssertEqual(MarkdownImagePolicy.classify(""), .rejected)
    }


    func testLocalResolveStaysInsideDocumentDirectory() {
        let dir = URL(fileURLWithPath: "/Users/me/notes", isDirectory: true)
        XCTAssertEqual(
            MarkdownImagePolicy.resolveLocal(destination: "img/a.png", documentDirectory: dir)?.path,
            "/Users/me/notes/img/a.png"
        )
        XCTAssertEqual(
            MarkdownImagePolicy.resolveLocal(destination: "./photo.jpg", documentDirectory: dir)?.path,
            "/Users/me/notes/photo.jpg"
        )
        XCTAssertNil(MarkdownImagePolicy.resolveLocal(destination: "../secret.png", documentDirectory: dir))
        XCTAssertNil(MarkdownImagePolicy.resolveLocal(destination: "img/../../etc/passwd", documentDirectory: dir))
        XCTAssertNil(MarkdownImagePolicy.resolveLocal(destination: "https://x.com/a.png", documentDirectory: dir))
    }

    func testCustomSchemeRoundtrip() throws {
        let url = try XCTUnwrap(MarkdownImagePolicy.customSchemeURL(kind: "remote", payload: "https://ex.com/a.png"))
        XCTAssertEqual(url.scheme, "notepad-md")
        let parsed = try XCTUnwrap(MarkdownImagePolicy.parseCustomScheme(url))
        XCTAssertEqual(parsed.kind, "remote")
        XCTAssertEqual(parsed.payload, "https://ex.com/a.png")
    }
}

final class MarkdownPreviewControllerTests: XCTestCase {

    @MainActor
    func testRemoteAllowDiesWithTab() {
        let controller = MarkdownPreviewController()
        let keep = UUID()
        let drop = UUID()
        controller.setAllowsRemoteImages(true, for: keep)
        controller.setAllowsRemoteImages(true, for: drop)
        XCTAssertTrue(controller.allowsRemoteImages(for: drop))
        controller.retainRemoteAllows(forOpenTabs: [keep])
        XCTAssertTrue(controller.allowsRemoteImages(for: keep))
        XCTAssertFalse(controller.allowsRemoteImages(for: drop))
    }

    @MainActor
    func testFullScreenRestoresPreviousLayout() {
        let controller = MarkdownPreviewController()
        XCTAssertEqual(controller.layout, .hidden)
        controller.toggleSide()
        XCTAssertEqual(controller.layout, .side)
        controller.toggleFull()
        XCTAssertEqual(controller.layout, .full)
        controller.exitFull()
        XCTAssertEqual(controller.layout, .side)
    }

    @MainActor
    func testChromeToggleHidesFullScreen() {
        let controller = MarkdownPreviewController()
        controller.toggleFull()
        XCTAssertEqual(controller.layout, .full)
        controller.toggleChrome()
        XCTAssertEqual(controller.layout, .hidden)
    }

    @MainActor
    func testChromeToggleOpensSideFromHidden() {
        let controller = MarkdownPreviewController()
        controller.toggleChrome()
        XCTAssertEqual(controller.layout, .side)
        controller.toggleChrome()
        XCTAssertEqual(controller.layout, .hidden)
    }

}
