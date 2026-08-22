import Foundation

enum SourceHighlightKind: Equatable {
    case none
    case markdown
    case json
    case xml
    case html
    case log

    static func of(fileURL: URL?) -> SourceHighlightKind {
        guard let ext = fileURL?.pathExtension.lowercased(), !ext.isEmpty else { return .none }
        switch ext {
        case "md", "markdown": return .markdown
        case "json": return .json
        case "xml": return .xml
        case "html", "htm": return .html
        case "log": return .log
        default: return .none
        }
    }

    var highlights: Bool { self != .none }
}
