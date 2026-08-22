import Foundation

struct HTMLPreviewResult: Equatable {
    var html: String
    var containsRemoteResources: Bool
    var containsLocalResources: Bool
}

enum PreviewChrome {
    static let contentSecurityPolicy =
        "default-src 'none'; img-src notepad-md:; style-src 'unsafe-inline' notepad-md:; script-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none';"
}

/// Static HTML preview: parse with Foundation's HTML tidy, emit an allowlist.
/// Scripts, frames, forms, and event handlers are dropped. Images/CSS go through
/// the custom scheme + folder/remote allow policy.
enum HTMLPreviewSanitizer {
    private static let allowed: Set<String> = [
        "p", "div", "span", "br", "hr",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "li", "dl", "dt", "dd",
        "blockquote", "pre", "code",
        "em", "strong", "b", "i", "u", "s", "sub", "sup", "small", "mark",
        "table", "thead", "tbody", "tfoot", "tr", "th", "td", "caption", "colgroup", "col",
        "a", "img", "figure", "figcaption",
        "header", "footer", "main", "article", "section", "nav", "aside", "address",
        "style", "link"
    ]

    private static let dropSubtree: Set<String> = [
        "script", "iframe", "object", "embed", "applet",
        "form", "input", "button", "textarea", "select", "option", "optgroup",
        "meta", "base", "svg", "math", "video", "audio", "source", "track",
        "canvas", "frame", "frameset", "template", "noscript"
    ]

    private static let voidElements: Set<String> = ["br", "hr", "img", "col", "link"]

    static func sanitize(_ source: String, allowsRemote: Bool) -> HTMLPreviewResult {
        var remote = false
        var local = false
        let fragment: String
        if let root = parseRoot(source) {
            fragment = emitChrome(root, allowsRemote: allowsRemote, remote: &remote, local: &local)
        } else {
            fragment = "<pre><code>\(escape(source))</code></pre>"
        }
        return HTMLPreviewResult(
            html: wrap(fragment),
            containsRemoteResources: remote,
            containsLocalResources: local
        )
    }

    private static func wrap(_ fragment: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(PreviewChrome.contentSecurityPolicy)">
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }

    private static func parseRoot(_ source: String) -> XMLElement? {
        let options: XMLNode.Options = [.documentTidyHTML, .nodeLoadExternalEntitiesNever]
        if let document = try? XMLDocument(xmlString: source, options: options) {
            return document.rootElement()
        }
        let wrapped = "<html><body>\(source)</body></html>"
        return (try? XMLDocument(xmlString: wrapped, options: options))?.rootElement()
    }

    /// Walk html/head/body wrappers so tidy-moved `<style>` / `<header>` still emit.
    private static func emitChrome(
        _ element: XMLElement,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let name = element.name?.lowercased() ?? ""
        if name == "html" || name == "head" || name == "body" {
            return emitChildren(of: element, allowsRemote: allowsRemote, remote: &remote, local: &local)
        }
        return emit(element, allowsRemote: allowsRemote, remote: &remote, local: &local)
    }

    private static func emit(
        _ node: XMLNode,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        switch node.kind {
        case .text:
            return escape(node.stringValue ?? "")
        case .element:
            guard let element = node as? XMLElement else { return "" }
            return emitElement(element, allowsRemote: allowsRemote, remote: &remote, local: &local)
        default:
            return ""
        }
    }

    private static func emitChildren(
        of element: XMLElement,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        element.children?.map { emit($0, allowsRemote: allowsRemote, remote: &remote, local: &local) }.joined() ?? ""
    }

    private static func emitElement(
        _ element: XMLElement,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let name = element.name?.lowercased() ?? ""
        if dropSubtree.contains(name) { return "" }

        if name == "link" {
            return emitStylesheet(element, allowsRemote: allowsRemote, remote: &remote, local: &local)
        }

        guard allowed.contains(name) else {
            return emitChildren(of: element, allowsRemote: allowsRemote, remote: &remote, local: &local)
        }

        if name == "style" {
            let css = rewriteCSS(element.stringValue ?? "", allowsRemote: allowsRemote, remote: &remote, local: &local)
            return "<style>\(css)</style>"
        }

        var attributes = ""
        for attr in element.attributes ?? [] {
            guard let rawName = attr.name else { continue }
            let attrName = rawName.lowercased()
            guard let value = emitAttribute(
                tag: name,
                name: attrName,
                value: attr.stringValue ?? "",
                allowsRemote: allowsRemote,
                remote: &remote,
                local: &local
            ) else { continue }
            attributes += " \(attrName)=\"\(escape(value))\""
        }

        if voidElements.contains(name) {
            return "<\(name)\(attributes)>"
        }
        let inner = emitChildren(of: element, allowsRemote: allowsRemote, remote: &remote, local: &local)
        return "<\(name)\(attributes)>\(inner)</\(name)>"
    }

    private static func emitStylesheet(
        _ element: XMLElement,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let rel = element.attribute(forName: "rel")?.stringValue?.lowercased() ?? ""
        guard rel.contains("stylesheet") else { return "" }
        let href = element.attribute(forName: "href")?.stringValue ?? ""
        guard let rewritten = rewriteResource(href, allowsRemote: allowsRemote, remote: &remote, local: &local) else {
            return ""
        }
        return "<link rel=\"stylesheet\" href=\"\(escape(rewritten))\">"
    }

    private static func emitAttribute(
        tag: String,
        name: String,
        value: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String? {
        if name.hasPrefix("on") || name == "srcdoc" || name.contains(":") { return nil }

        switch (tag, name) {
        case ("a", "href"):
            return sanitizedLink(value)
        case ("img", "src"):
            return rewriteResource(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
        case ("img", "srcset"):
            return rewriteSrcset(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
        case ("img", "alt"), ("img", "title"), ("a", "title"):
            return value
        case ("img", "width"), ("img", "height"), ("td", "colspan"), ("th", "colspan"),
             ("td", "rowspan"), ("th", "rowspan"), ("col", "span"):
            return value.allSatisfy(\.isNumber) ? value : nil
        case (_, "class"), (_, "id"), (_, "title"):
            return value
        case (_, "style"):
            return rewriteCSS(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
        default:
            return nil
        }
    }

    private static func sanitizedLink(_ destination: String) -> String {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") || lower.hasPrefix("mailto:") {
            return trimmed
        }
        return "#"
    }

    private static func rewriteSrcset(
        _ value: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        value.split(separator: ",", omittingEmptySubsequences: false).map { part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = trimmed.split(whereSeparator: \.isWhitespace)
            guard let first = tokens.first else { return String(part) }
            let descriptor = tokens.dropFirst().joined(separator: " ")
            let rewritten = rewriteResource(String(first), allowsRemote: allowsRemote, remote: &remote, local: &local) ?? ""
            return descriptor.isEmpty ? rewritten : "\(rewritten) \(descriptor)"
        }.joined(separator: ", ")
    }

    private static func rewriteCSS(
        _ css: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        var output = rewriteCSSURLs(css, allowsRemote: allowsRemote, remote: &remote, local: &local)
        output = rewriteCSSImports(output, allowsRemote: allowsRemote, remote: &remote, local: &local)
        return output
    }

    private static func rewriteCSSURLs(
        _ css: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let regex = try! NSRegularExpression(pattern: "url\\(\\s*([\"']?)([^\"')]+)\\1\\s*\\)", options: .caseInsensitive)
        let ns = css as NSString
        var output = css
        let matches = regex.matches(in: css, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let value = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let rewritten = rewriteResource(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
            let replacement = rewritten.map { "url('\($0)')" } ?? "url('')"
            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return output
    }

    private static func rewriteCSSImports(
        _ css: String,
        allowsRemote: Bool,
        remote: inout Bool,
        local: inout Bool
    ) -> String {
        let regex = try! NSRegularExpression(
            pattern: "@import\\s+(?!url\\()[\"']([^\"']+)[\"']",
            options: .caseInsensitive
        )
        let ns = css as NSString
        var output = css
        let matches = regex.matches(in: css, range: NSRange(location: 0, length: ns.length)).reversed()
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let value = ns.substring(with: match.range(at: 1))
            let rewritten = rewriteResource(value, allowsRemote: allowsRemote, remote: &remote, local: &local)
            let replacement = rewritten.map { "@import '\($0)'" } ?? "@import ''"
            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return output
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

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
