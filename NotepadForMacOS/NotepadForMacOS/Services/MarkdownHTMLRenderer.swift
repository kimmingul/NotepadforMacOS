import Foundation
import Markdown

struct MarkdownRenderResult: Equatable {
    var html: String
    var containsRemoteImages: Bool
    var containsLocalImages: Bool
}

enum MarkdownHTMLRenderer {
    static func render(
        _ source: String,
        allowsRemoteImages: Bool,
        isDark: Bool
    ) -> MarkdownRenderResult {
        let document = Markdown.Document(parsing: source)
        var visitor = HTMLVisitor(allowsRemoteImages: allowsRemoteImages)
        let body = visitor.visit(document)
        let page = wrap(body: body, isDark: isDark)
        return MarkdownRenderResult(
            html: page,
            containsRemoteImages: visitor.containsRemoteImages,
            containsLocalImages: visitor.containsLocalImages
        )
    }

    static func wrap(body: String, isDark: Bool) -> String {
        let bg = isDark ? "#1e1e1e" : "#ffffff"
        let fg = isDark ? "#f2f2f2" : "#1d1d1f"
        let muted = isDark ? "#a1a1a6" : "#6e6e73"
        let codeBg = isDark ? "#2c2c2e" : "#f2f2f7"
        let border = isDark ? "#3a3a3c" : "#d2d2d7"
        let link = isDark ? "#64d2ff" : "#0066cc"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        html, body { margin: 0; padding: 0; background: \(bg); color: \(fg);
          font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
        .md { padding: 12px 16px 32px; }
        h1,h2,h3,h4,h5,h6 { font-weight: 600; line-height: 1.25; margin: 1.2em 0 0.4em; }
        h1 { font-size: 1.6em; } h2 { font-size: 1.35em; } h3 { font-size: 1.15em; }
        p, ul, ol, pre, table, blockquote { margin: 0.6em 0; }
        a { color: \(link); }
        code { font-family: ui-monospace, Menlo, monospace; font-size: 0.92em;
          background: \(codeBg); padding: 0.1em 0.35em; border-radius: 3px; }
        pre { background: \(codeBg); padding: 10px 12px; overflow: auto; border-radius: 4px; position: relative; }
        pre code { padding: 0; background: none; }
        pre .lang { display: block; text-align: right; font: 11px/1.2 -apple-system, BlinkMacSystemFont, sans-serif;
          color: \(muted); margin: 0 0 6px; }
        blockquote { border-left: 3px solid \(border); padding-left: 10px; color: \(muted); }
        table { border-collapse: collapse; }
        th, td { border: 1px solid \(border); padding: 4px 8px; }
        img { max-width: 100%; height: auto; }
        hr { border: none; border-top: 1px solid \(border); }
        .blocked { color: \(muted); font-size: 12px; }
        input[type=checkbox] { pointer-events: none; }
        </style>
        </head>
        <body><div class="md">\(body)</div></body>
        </html>
        """
    }
}

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    let allowsRemoteImages: Bool
    var containsRemoteImages = false
    var containsLocalImages = false
    var inTableHead = false

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Markdown.Document) -> String { defaultVisit(document) }
    mutating func visitParagraph(_ paragraph: Paragraph) -> String { "<p>\(defaultVisit(paragraph))</p>" }
    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>\(defaultVisit(heading))</h\(level)>"
    }
    mutating func visitText(_ text: Text) -> String { escape(text.string) }
    mutating func visitEmphasis(_ emphasis: Emphasis) -> String { "<em>\(defaultVisit(emphasis))</em>" }
    mutating func visitStrong(_ strong: Strong) -> String { "<strong>\(defaultVisit(strong))</strong>" }
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(defaultVisit(strikethrough))</del>"
    }
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escape(inlineCode.code))</code>"
    }
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let code = escape(codeBlock.code)
        guard let lang = MarkdownFence.language(from: codeBlock.language) else {
            return "<pre><code>\(code)</code></pre>"
        }
        return "<pre><span class=\"lang\">\(escape(lang))</span><code class=\"language-\(escape(lang))\">\(code)</code></pre>"
    }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String { " " }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String { "<br>" }
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String { "<hr>" }
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\(defaultVisit(blockQuote))</blockquote>"
    }
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\(defaultVisit(unorderedList))</ul>"
    }
    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\(defaultVisit(orderedList))</ol>"
    }
    mutating func visitListItem(_ listItem: ListItem) -> String {
        let box: String
        switch listItem.checkbox {
        case .checked: box = "<input type=\"checkbox\" checked> "
        case .unchecked: box = "<input type=\"checkbox\"> "
        case nil: box = ""
        }
        return "<li>\(box)\(defaultVisit(listItem))</li>"
    }
    mutating func visitLink(_ link: Link) -> String {
        let children = defaultVisit(link)
        guard let dest = link.destination, isSafeLink(dest) else { return children }
        return "<a href=\"\(escape(dest))\">\(children)</a>"
    }
    mutating func visitImage(_ image: Image) -> String {
        let alt = defaultVisit(image)
        guard let source = image.source else {
            return "<span class=\"blocked\">\(alt)</span>"
        }
        switch MarkdownImagePolicy.classify(source) {
        case .localRelative(let relative):
            containsLocalImages = true
            guard let url = MarkdownImagePolicy.customSchemeURL(kind: "local", payload: relative) else {
                return "<span class=\"blocked\">\(alt)</span>"
            }
            return "<img src=\"\(escape(url.absoluteString))\" alt=\"\(alt)\">"
        case .remote(let remote):
            containsRemoteImages = true
            if allowsRemoteImages, let url = MarkdownImagePolicy.customSchemeURL(kind: "remote", payload: remote.absoluteString) {
                return "<img src=\"\(escape(url.absoluteString))\" alt=\"\(alt)\">"
            }
            return "<p class=\"blocked\">\(String(localized: "markdown.remoteBlocked"))</p>"
        case .rejected:
            return "<span class=\"blocked\">\(alt)</span>"
        }
    }
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        if MarkdownFence.isHTMLComment(html.rawHTML) { return "" }
        return "<pre><code>\(escape(html.rawHTML))</code></pre>"
    }
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        if MarkdownFence.isHTMLComment(inlineHTML.rawHTML) { return "" }
        return escape(inlineHTML.rawHTML)
    }
    mutating func visitTable(_ table: Table) -> String { "<table>\(defaultVisit(table))</table>" }
    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        inTableHead = true
        defer { inTableHead = false }
        return "<thead>\(defaultVisit(tableHead))</thead>"
    }
    mutating func visitTableBody(_ tableBody: Table.Body) -> String { "<tbody>\(defaultVisit(tableBody))</tbody>" }
    mutating func visitTableRow(_ tableRow: Table.Row) -> String { "<tr>\(defaultVisit(tableRow))</tr>" }
    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let tag = inTableHead ? "th" : "td"
        return "<\(tag)>\(defaultVisit(tableCell))</\(tag)>"
    }
}

private func escape(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func isSafeLink(_ destination: String) -> Bool {
    let lower = destination.lowercased()
    return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("mailto:")
}
