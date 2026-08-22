import Foundation
import UniformTypeIdentifiers

/// Files this app will open from Finder, Dock drops, and in-window drops.
nonisolated enum OpenableDocumentType {
    static let filenameExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "log", "json", "xml", "html", "htm"
    ]

    static func isOpenable(_ url: URL) -> Bool {
        guard url.isFileURL, !url.hasDirectoryPath else { return false }

        let ext = url.pathExtension.lowercased()
        if filenameExtensions.contains(ext) { return true }
        if ext.isEmpty { return true }

        guard let type = UTType(filenameExtension: ext) else { return false }
        if type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .audio) {
            return false
        }
        return type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .xml) || type.conforms(to: .html)
    }

    static func openableURLs(in urls: [URL]) -> [URL] {
        urls.filter(isOpenable)
    }
}
