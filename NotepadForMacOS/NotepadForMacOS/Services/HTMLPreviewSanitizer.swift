import Foundation

struct HTMLPreviewResult: Equatable {
    var html: String
    var containsRemoteResources: Bool
    var containsLocalResources: Bool
}

/// Static HTML preview: no scripts, no frames. Images and stylesheets go through
/// the existing custom scheme + folder/remote allow policy.
nonisolated enum HTMLPreviewSanitizer {
    static func sanitize(_ source: String, allowsRemote: Bool) -> HTMLPreviewResult {
        var html = source
        var remote = false
        var local = false

        html = stripBlocks(html, tag: "script")
        html = stripBlocks(html, tag: "iframe")
        html = stripBlocks(html, tag: "object")
        html = stripBlocks(html, tag: "embed")
        html = stripBlocks(html, tag: "applet")
        html = stripBlocks(html, tag: "form")
        html = stripEmpty(html, tag: "meta")
        html = stripEmpty(html, tag: "base")
        html = stripEventHandlers(html)
        html = rewriteLinkTags(html, allowsRemote: allowsRemote, remote: &remote, local: &local)
        html = rewriteAttribute(html, name: "src", allowsRemote: allowsRemote, remote: &remote, local: &local)
        html = rewriteCSSURLs(html, allowsRemote: allowsRemote, remote: &remote, local: &local)
        html = neutralizeDangerousHrefs(html)
        html = injectCSP(html)

        return HTMLPreviewResult(
            html: html,
            containsRemoteResources: remote,
            containsLocalResources: local
        )
    }

    private static func stripBlocks(_ html: String, tag: String) -> String {
        let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>|<\(tag)\\b[^>]*/?>"
        return replace(pattern, in: html, with: "")
    }

    private static func stripEmpty(_ html: String, tag: String) -> String {
        replace("<\(tag)\\b[^>]*/?>", in: html, with: "")
    }

    private static func stripEventHandlers(_ html: String) -> String {
        replace("(?i)\\s+on[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)", in: html, with: "")
    }

    private static func rewriteLinkTags(
        _ html: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let regex = try! NSRegularExpression(pattern: "<link\\b[^>]*>", options: .caseInsensitive)
        let ns = html as NSString
        var output = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            let tag = ns.substring(with: match.range)
            let lower = tag.lowercased()
            guard lower.contains("stylesheet") else {
                output = (output as NSString).replacingCharacters(in: match.range, with: "")
                continue
            }
            let rewritten = rewriteAttribute(tag, name: "href", allowsRemote: allowsRemote, remote: &remote, local: &local)
            output = (output as NSString).replacingCharacters(in: match.range, with: rewritten)
        }
        return output
    }

    private static func rewriteAttribute(
        _ html: String,
        name: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let pattern = "(?i)(\\s\(name)\\s*=\\s*)(\"[^\"]*\"|'[^']*')"
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = html as NSString
        var output = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let raw = ns.substring(with: match.range(at: 2))
            let quote = String(raw.prefix(1))
            let value = String(raw.dropFirst().dropLast())
            let rewritten = rewriteResource(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
            let prefix = ns.substring(with: match.range(at: 1))
            let replacement = rewritten.map { "\(prefix)\(quote)\($0)\(quote)" } ?? prefix + quote + quote
            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return output
    }

    private static func rewriteCSSURLs(
        _ html: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let regex = try! NSRegularExpression(pattern: "url\\(\\s*([\"']?)([^\"')]+)\\1\\s*\\)", options: .caseInsensitive)
        let ns = html as NSString
        var output = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let value = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let rewritten = rewriteResource(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
            let replacement = rewritten.map { "url('\($0)')" } ?? "url('')"
            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return output
    }

    private static func neutralizeDangerousHrefs(_ html: String) -> String {
        replace(
            "(?i)(\\shref\\s*=\\s*)([\"'])\\s*(javascript:|data:|file:)[^\"']*\\2",
            in: html,
            with: "$1$2#$2"
        )
    }

    private static func rewriteResource(
        _ destination: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String? {
        switch MarkdownImagePolicy.classify(destination) {
        case .localRelative(let relative):
            local = true
            return MarkdownImagePolicy.customSchemeURL(kind: "local", payload: relative)?.absoluteString
        case .remote(let url):
            remote = true
            guard allowsRemote else { return nil }
            return MarkdownImagePolicy.customSchemeURL(kind: "remote", payload: url.absoluteString)?.absoluteString
        case .rejected:
            return nil
        }
    }

    private static func injectCSP(_ html: String) -> String {
        let csp = #"<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src notepad-md:; style-src 'unsafe-inline' notepad-md:; script-src 'none'; frame-src 'none'; object-src 'none';">"#
        if let range = html.range(of: "<head", options: .caseInsensitive),
           let close = html[range.lowerBound...].firstIndex(of: ">") {
            let insertAt = html.index(after: close)
            return String(html[..<insertAt]) + csp + String(html[insertAt...])
        }
        return csp + html
    }

    private static func replace(_ pattern: String, in html: String, with template: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: (html as NSString).length)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: template)
    }
}
