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

    func testOwnsPreviewDocumentAndPlacesCSPInHead() {
        let result = HTMLPreviewSanitizer.sanitize(
            #"<body><header>Invoice Header</header><p>Hi</p></body>"#,
            allowsRemote: false
        )
        XCTAssertTrue(result.html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(result.html.contains("<head>"))
        XCTAssertTrue(result.html.contains("Content-Security-Policy"))
        XCTAssertTrue(result.html.contains("Invoice"))
        XCTAssertTrue(result.html.contains("Hi"))
        if let body = result.html.range(of: "<body"),
           let csp = result.html.range(of: "Content-Security-Policy") {
            XCTAssertTrue(csp.lowerBound < body.lowerBound, "CSP must live in the app-owned <head>")
        } else {
            XCTFail("expected body and CSP meta")
        }
    }

    func testRewritesSrcsetAndUnquotedRemoteSources() {
        let html = #"<header></header><img src=https://attacker.example/t.png srcset="https://attacker.example/t.png 1x">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertTrue(result.containsRemoteResources)
        XCTAssertFalse(result.html.contains("https://attacker.example"))
    }

    func testRewritesCSSImportAndNestedTags() {
        let html = #"<style>@import "https://cdn.example/x.css";</style><scr<script></script>ipt>alert(1)</script><met<meta>a http-equiv="refresh" content="0;url=https://x">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertFalse(result.html.contains("<script"))
        XCTAssertFalse(result.html.contains("http-equiv=\"refresh\""))
        XCTAssertFalse(result.html.contains("@import \"https://"))
        XCTAssertFalse(result.html.contains("https://cdn.example"))
    }

    func testStripsSlashStyleEventHandlers() {
        let html = #"<img/onerror=alert(1) src="./x.png">"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertFalse(result.html.contains("onerror"))
        XCTAssertTrue(result.html.contains("notepad-md://"))
    }

    func testKeepsHttpLinksAndUnwrapsUnknownTags() {
        let html = #"<font>Hi <a href="https://example.com">site</a></font><custom><em>x</em></custom>"#
        let result = HTMLPreviewSanitizer.sanitize(html, allowsRemote: false)
        XCTAssertTrue(result.html.contains("href=\"https://example.com\""))
        XCTAssertFalse(result.html.contains("<font"))
        XCTAssertFalse(result.html.contains("<custom"))
        XCTAssertTrue(result.html.contains("<em>x</em>"))
        XCTAssertTrue(result.html.contains("Hi"))
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
