import Foundation

enum PreviewDocumentKind {
    static func isHTML(fileURL: URL?) -> Bool {
        guard let ext = fileURL?.pathExtension.lowercased(), !ext.isEmpty else { return false }
        return ext == "html" || ext == "htm"
    }

    static func isPreviewable(fileURL: URL?) -> Bool {
        MarkdownDocumentKind.isMarkdown(fileURL: fileURL) || isHTML(fileURL: fileURL)
    }
}
