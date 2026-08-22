import Foundation

enum MarkdownFence {
    struct Open: Equatable {
        var marker: Character
        var count: Int
    }

    static func opening(of trimmedLine: String) -> Open? {
        guard let first = trimmedLine.first, first == "`" || first == "~" else { return nil }
        let count = trimmedLine.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        return Open(marker: first, count: count)
    }

    static func isClosing(_ trimmedLine: String, of open: Open) -> Bool {
        guard trimmedLine.first == open.marker else { return false }
        let count = trimmedLine.prefix(while: { $0 == open.marker }).count
        guard count >= open.count else { return false }
        return trimmedLine.dropFirst(count).allSatisfy(\.isWhitespace)
    }

    static func language(from info: String?) -> String? {
        guard let info else { return nil }
        let token = info.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let cleaned = token.filter { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "_" || $0 == "#" }
        return cleaned.isEmpty ? nil : cleaned
    }

    static func isHTMLComment(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<!--") && trimmed.hasSuffix("-->")
    }
}
