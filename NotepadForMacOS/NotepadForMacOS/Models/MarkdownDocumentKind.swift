import Foundation

/// `.md` / `.markdown` only. Untitled and every other extension stay plain text.
enum MarkdownDocumentKind {
    static func isMarkdown(fileURL: URL?) -> Bool {
        guard let ext = fileURL?.pathExtension.lowercased(), !ext.isEmpty else { return false }
        return ext == "md" || ext == "markdown"
    }
}
