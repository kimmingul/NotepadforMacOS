import XCTest
@testable import Notepad

final class MarkdownHTMLRendererTests: XCTestCase {

    func testRendersHeadingAndEmphasis() {
        let html = MarkdownHTMLRenderer.render("# Hi\n\nHello *world*", allowsRemoteImages: false, isDark: false).html
        XCTAssertTrue(html.contains("<h1>Hi</h1>"))
        XCTAssertTrue(html.contains("<em>world</em>"))
        XCTAssertTrue(html.contains("Content-Security-Policy"))
    }

    func testEscapesRawHTML() {
        let html = MarkdownHTMLRenderer.render("<script>alert(1)</script>", allowsRemoteImages: false, isDark: false).html
        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testRemoteImageBlockedHasNoHttpsSrc() {
        let result = MarkdownHTMLRenderer.render(
            "![x](https://example.com/a.png)",
            allowsRemoteImages: false,
            isDark: false
        )
        XCTAssertTrue(result.containsRemoteImages)
        XCTAssertFalse(result.html.contains("src=\"https://"))
        XCTAssertTrue(result.html.contains("blocked"))
    }

    func testRemoteImageAllowedUsesCustomScheme() {
        let html = MarkdownHTMLRenderer.render(
            "![x](https://example.com/a.png)",
            allowsRemoteImages: true,
            isDark: false
        ).html
        XCTAssertTrue(html.contains("notepad-md://"))
        XCTAssertFalse(html.contains("src=\"https://example.com"))
    }

    func testRejectsJavascriptImage() {
        let html = MarkdownHTMLRenderer.render(
            "![x](javascript:alert(1))",
            allowsRemoteImages: true,
            isDark: false
        ).html
        XCTAssertFalse(html.contains("javascript:"))
        XCTAssertFalse(html.contains("src=\"https://"))
    }

    func testLocalImageUsesCustomScheme() {
        let result = MarkdownHTMLRenderer.render("![cat](./cat.png)", allowsRemoteImages: false, isDark: false)
        XCTAssertTrue(result.containsLocalImages)
        XCTAssertTrue(result.html.contains("notepad-md://"))
        XCTAssertTrue(result.html.contains("alt=\"cat\""))
    }

    func testHTMLCommentsAreOmittedFromPreview() {
        let html = MarkdownHTMLRenderer.render(
            "Hello\n\n<!-- hidden comment -->\n\nAfter <!-- inline-note --> done",
            allowsRemoteImages: false,
            isDark: false
        ).html
        XCTAssertTrue(html.contains("Hello"))
        XCTAssertTrue(html.contains("After"))
        XCTAssertTrue(html.contains("done"))
        XCTAssertFalse(html.contains("&lt;!--"))
        XCTAssertFalse(html.contains("hidden comment"))
        XCTAssertFalse(html.contains("inline-note"))
    }

    func testFenceInfoStringUsesFirstTokenAsLanguageLabel() {
        let html = MarkdownHTMLRenderer.render(
            "```md id=\"foo\"\n# Title\n*hi*\n```",
            allowsRemoteImages: false,
            isDark: false
        ).html
        XCTAssertTrue(html.contains("language-md"))
        XCTAssertTrue(html.contains(">md<"))
        XCTAssertTrue(html.contains("# Title"))
        XCTAssertFalse(html.contains("<h1>"))
        XCTAssertFalse(html.contains("id=&quot;foo&quot;"))
    }

}
