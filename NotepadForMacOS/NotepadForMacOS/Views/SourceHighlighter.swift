import AppKit

enum SourceHighlightStyle: Equatable {
    case heading
    case codeBlock
    case inlineCode
    case link
    case emphasis
    case listMarker
    case blockquote
    case jsonKey
    case jsonString
    case jsonNumber
    case jsonLiteral
    case xmlComment
    case xmlTag
    case xmlAttribute
    case xmlString
    case logError
    case logWarn
    case logInfo
    case logTimestamp
    case logString
}

struct SourceHighlightToken: Equatable {
    var range: NSRange
    var style: SourceHighlightStyle
}

enum SourceHighlighter {
    private static let maxHighlightedLength = 800_000

    nonisolated static func shouldRepaint(enabled: Bool, hasMarkedText: Bool, length: Int) -> Bool {
        enabled && !hasMarkedText && length > 0
    }

    static func apply(to textView: NSTextView, kind: SourceHighlightKind) {
        guard let layout = textView.layoutManager, let storage = textView.textStorage else { return }
        guard shouldRepaint(enabled: kind.highlights, hasMarkedText: textView.hasMarkedText(), length: storage.length) else {
            return
        }

        let full = NSRange(location: 0, length: storage.length)
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        guard storage.length <= maxHighlightedLength else { return }

        for token in tokens(in: storage.string, kind: kind) {
            layout.addTemporaryAttributes(
                [.foregroundColor: color(for: token.style)],
                forCharacterRange: token.range
            )
        }
    }

    static func tokens(in text: String, kind: SourceHighlightKind) -> [SourceHighlightToken] {
        guard kind.highlights, !text.isEmpty else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        switch kind {
        case .none:
            return []
        case .markdown:
            return markdownTokens(in: ns, full: full)
        case .json:
            return jsonTokens(in: ns, full: full)
        case .xml, .html:
            return xmlTokens(in: ns, full: full)
        case .log:
            return logTokens(in: ns, full: full)
        }
    }

    // MARK: - Markdown

    private static func markdownTokens(in ns: NSString, full: NSRange) -> [SourceHighlightToken] {
        var covered = Coverage()
        var tokens: [SourceHighlightToken] = []

        for range in fenceRanges(in: ns) {
            append(.codeBlock, range, into: &tokens, covered: &covered)
        }
        collect(Self.inlineCode, in: ns, full: full, style: .inlineCode, into: &tokens, covered: &covered)
        collect(Self.link, in: ns, full: full, style: .link, into: &tokens, covered: &covered)
        collect(Self.heading, in: ns, full: full, style: .heading, into: &tokens, covered: &covered)
        collect(Self.listMarker, in: ns, full: full, style: .listMarker, into: &tokens, covered: &covered)
        collect(Self.blockquote, in: ns, full: full, style: .blockquote, into: &tokens, covered: &covered)
        collect(Self.emphasis, in: ns, full: full, style: .emphasis, into: &tokens, covered: &covered)
        return tokens
    }

    private static func fenceRanges(in ns: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var index = 0
        var open: (start: Int, fence: MarkdownFence.Open)?
        while index < ns.length {
            let line = ns.lineRange(for: NSRange(location: index, length: 0))
            let trimmed = ns.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
            if let current = open {
                if MarkdownFence.isClosing(trimmed, of: current.fence) {
                    ranges.append(NSRange(location: current.start, length: NSMaxRange(line) - current.start))
                    open = nil
                }
            } else if let fence = MarkdownFence.opening(of: trimmed) {
                open = (line.location, fence)
            }
            index = NSMaxRange(line)
        }
        if let current = open {
            ranges.append(NSRange(location: current.start, length: ns.length - current.start))
        }
        return ranges
    }

    // MARK: - JSON

    private static func jsonTokens(in ns: NSString, full: NSRange) -> [SourceHighlightToken] {
        var covered = Coverage()
        var tokens: [SourceHighlightToken] = []
        collect(Self.jsonKey, in: ns, full: full, style: .jsonKey, group: 1, into: &tokens, covered: &covered)
        collect(Self.jsonString, in: ns, full: full, style: .jsonString, into: &tokens, covered: &covered)
        collect(Self.jsonNumber, in: ns, full: full, style: .jsonNumber, into: &tokens, covered: &covered)
        collect(Self.jsonLiteral, in: ns, full: full, style: .jsonLiteral, into: &tokens, covered: &covered)
        return tokens
    }

    // MARK: - XML

    private static func xmlTokens(in ns: NSString, full: NSRange) -> [SourceHighlightToken] {
        var covered = Coverage()
        var tokens: [SourceHighlightToken] = []
        collect(Self.xmlComment, in: ns, full: full, style: .xmlComment, into: &tokens, covered: &covered)
        collect(Self.xmlString, in: ns, full: full, style: .xmlString, into: &tokens, covered: &covered)
        collect(Self.xmlTag, in: ns, full: full, style: .xmlTag, into: &tokens, covered: &covered)
        collect(Self.xmlAttribute, in: ns, full: full, style: .xmlAttribute, into: &tokens, covered: &covered)
        return tokens
    }

    // MARK: - Log

    private static func logTokens(in ns: NSString, full: NSRange) -> [SourceHighlightToken] {
        var covered = Coverage()
        var tokens: [SourceHighlightToken] = []
        collect(Self.logTimestamp, in: ns, full: full, style: .logTimestamp, into: &tokens, covered: &covered)
        collect(Self.logError, in: ns, full: full, style: .logError, into: &tokens, covered: &covered)
        collect(Self.logWarn, in: ns, full: full, style: .logWarn, into: &tokens, covered: &covered)
        collect(Self.logInfo, in: ns, full: full, style: .logInfo, into: &tokens, covered: &covered)
        collect(Self.logString, in: ns, full: full, style: .logString, into: &tokens, covered: &covered)
        return tokens
    }

    // MARK: - Shared

    private static func collect(
        _ regex: NSRegularExpression,
        in ns: NSString,
        full: NSRange,
        style: SourceHighlightStyle,
        group: Int = 0,
        into tokens: inout [SourceHighlightToken],
        covered: inout Coverage
    ) {
        regex.enumerateMatches(in: ns as String, range: full) { match, _, _ in
            guard let match else { return }
            let range = group > 0 && group < match.numberOfRanges ? match.range(at: group) : match.range
            guard range.location != NSNotFound, range.length > 0 else { return }
            append(style, range, into: &tokens, covered: &covered)
        }
    }

    private static func append(
        _ style: SourceHighlightStyle,
        _ range: NSRange,
        into tokens: inout [SourceHighlightToken],
        covered: inout Coverage
    ) {
        guard !covered.intersects(range) else { return }
        tokens.append(SourceHighlightToken(range: range, style: style))
        covered.add(range)
    }

    private static func color(for style: SourceHighlightStyle) -> NSColor {
        switch style {
        case .heading: return .systemBlue
        case .codeBlock, .inlineCode: return .systemPurple
        case .link: return .systemTeal
        case .emphasis: return .systemOrange
        case .listMarker, .blockquote: return .systemIndigo
        case .jsonKey: return .systemBlue
        case .jsonString: return .systemTeal
        case .jsonNumber: return .systemPurple
        case .jsonLiteral: return .systemOrange
        case .xmlComment: return .secondaryLabelColor
        case .xmlTag: return .systemBlue
        case .xmlAttribute: return .systemIndigo
        case .xmlString: return .systemTeal
        case .logError: return .systemRed
        case .logWarn: return .systemOrange
        case .logInfo: return .systemBlue
        case .logTimestamp: return .secondaryLabelColor
        case .logString: return .systemTeal
        }
    }

    private static let heading = regex("^(#{1,6})\\s+.*$", options: .anchorsMatchLines)
    private static let inlineCode = regex("`[^`\\n]+`")
    private static let link = regex("\\[[^\\]]+\\]\\([^\\)]+\\)")
    private static let listMarker = regex("^[ \\t]*([-*+]|\\d+\\.)\\s+", options: .anchorsMatchLines)
    private static let blockquote = regex("^[ \\t]*>\\s?.*$", options: .anchorsMatchLines)
    private static let emphasis = regex("(\\*\\*|__)[^\\n]+?\\1|(\\*|_)[^\\n]+?\\2")

    private static let jsonKey = regex("(\"(?:\\\\.|[^\"\\\\])*\")\\s*:")
    private static let jsonString = regex("\"(?:\\\\.|[^\"\\\\])*\"")
    private static let jsonNumber = regex("(?<![\\w.])-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?(?![\\w.])")
    private static let jsonLiteral = regex("\\b(?:true|false|null)\\b")

    private static let xmlComment = regex("<!--[\\s\\S]*?-->")
    private static let xmlString = regex("\"[^\"\\n]*\"|'[^'\\n]*'")
    private static let xmlTag = regex("</?[A-Za-z_:][\\w:.-]*")
    private static let xmlAttribute = regex("(?<=\\s)[A-Za-z_:][\\w:.-]*(?=\\s*=)")

    private static let logTimestamp = regex("\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}")
    private static let logError = regex("\\b(?:ERROR|FATAL|CRITICAL)\\b")
    private static let logWarn = regex("\\bWARN(?:ING)?\\b")
    private static let logInfo = regex("\\b(?:INFO|DEBUG)\\b")
    private static let logString = regex("\"[^\"\\n]*\"")

    private static func regex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }
}

private struct Coverage {
    private var ranges: [NSRange] = []

    mutating func add(_ range: NSRange) {
        ranges.append(range)
    }

    func intersects(_ range: NSRange) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
