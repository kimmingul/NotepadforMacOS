import XCTest
@testable import Notepad

final class HTMLPreviewSanitizerTests: XCTestCase {

    func testStripsScriptAndEventHandlers() {
        let html = #"<p onclick="alert(1)">Hi</p><script>alert(1)</script>"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertFalse(result.html.contains("<script"))
        XCTAssertFalse(result.html.contains("onclick"))
        XCTAssertTrue(result.html.contains("Hi"))
    }

    func testStripsIframeAndNonStylesheetLinks() {
        let html = #"<iframe src="https://evil.example"></iframe><link rel="preload" href="https://x.com/a.js">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: true)
        XCTAssertFalse(result.html.contains("<iframe"))
        XCTAssertFalse(result.html.contains("preload"))
        XCTAssertFalse(result.html.contains("evil.example"))
    }

    func testRewritesLocalImageAndCSSToCustomScheme() {
        let html = #"<link rel="stylesheet" href="./app.css"><img src="./cat.png" alt="c">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertTrue(result.containsLocalResources)
        XCTAssertFalse(result.containsRemoteResources)
        XCTAssertTrue(result.html.contains("notepad-md://"))
        XCTAssertFalse(result.html.contains("href=\"./app.css\""))
        XCTAssertFalse(result.html.contains("src=\"./cat.png\""))
    }

    func testRemoteCSSAndImagesBlockedUntilAllowed() {
        let html = #"<link rel="stylesheet" href="https://cdn.example/app.css"><img src="https://cdn.example/a.png">"#
        let blocked = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertTrue(blocked.containsRemoteResources)
        XCTAssertFalse(blocked.html.contains("src=\"https://"))
        XCTAssertFalse(blocked.html.contains("href=\"https://"))

        let allowed = HTMLPreviewSanitizer.sanitize(html, allowsRemote: true)
        XCTAssertTrue(allowed.html.contains("notepad-md://"))
        XCTAssertFalse(allowed.html.contains("src=\"https://cdn.example"))
        XCTAssertFalse(allowed.html.contains("href=\"https://cdn.example"))
    }

    func testRejectsJavascriptAndFileURLs() {
        let html = #"<img src="javascript:alert(1)"><link rel="stylesheet" href="file:///etc/passwd">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: true)
        XCTAssertFalse(result.html.contains("javascript:"))
        XCTAssertFalse(result.html.contains("file://"))
    }

    func testRewritesCSSUrlFunctions() {
        let html = #"<style>body{background:url(./bg.png)}</style>"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertTrue(result.containsLocalResources)
        XCTAssertTrue(result.html.contains("notepad-md://"))
        XCTAssertFalse(result.html.contains("url(./bg.png)"))
    }
}

final class PreviewDocumentKindTests: XCTestCase {

    func testHTMLAndMarkdownArePreviewable() {
        XCTAssertTrue(PreviewDocumentKind.isHTML(fileURL: URL(fileURLWithPath: "/tmp/a.html")))
        XCTAssertTrue(PreviewDocumentKind.isHTML(fileURL: URL(fileURLWithPath: "/tmp/a.HTM")))
        XCTAssertTrue(PreviewDocumentKind.isPreviewable(fileURL: URL(fileURLWithPath: "/tmp/a.md")))
        XCTAssertTrue(PreviewDocumentKind.isPreviewable(fileURL: URL(fileURLWithPath: "/tmp/a.html")))
        XCTAssertFalse(PreviewDocumentKind.isPreviewable(fileURL: URL(fileURLWithPath: "/tmp/a.json")))
        XCTAssertFalse(PreviewDocumentKind.isPreviewable(fileURL: nil))
    }
}
