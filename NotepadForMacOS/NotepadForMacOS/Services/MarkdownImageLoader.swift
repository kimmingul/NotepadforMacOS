import Foundation
import UniformTypeIdentifiers

nonisolated enum MarkdownImageLoadResult: Equatable, Sendable {
    case data(Data, mime: String)
    case denied
    case missing
}


nonisolated enum MarkdownImageLoader {
    static func load(
        url: URL,
        documentDirectory: URL?,
        directoryBookmark: Data?,
        allowsRemote: Bool
    ) async -> MarkdownImageLoadResult {
        guard let parsed = MarkdownImagePolicy.parseCustomScheme(url) else { return .denied }

        switch parsed.kind {
        case "local":
            return loadLocal(
                destination: parsed.payload,
                documentDirectory: documentDirectory,
                directoryBookmark: directoryBookmark
            )
        case "remote":
            guard allowsRemote,
                  let remote = URL(string: parsed.payload),
                  remote.scheme?.lowercased() == "https" else {
                return .denied
            }
            return await loadRemote(remote)
        default:
            return .denied
        }
    }

    static func mimeType(for fileURL: URL) -> String {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private static func loadLocal(
        destination: String,
        documentDirectory: URL?,
        directoryBookmark: Data?
    ) -> MarkdownImageLoadResult {
        guard let documentDirectory,
              let resolved = MarkdownImagePolicy.resolveLocal(
                destination: destination,
                documentDirectory: documentDirectory
              ) else {
            return .denied
        }

        if let directoryBookmark {
            var result: MarkdownImageLoadResult = .missing
            SecurityScopedFile.access(documentDirectory, bookmark: directoryBookmark) { _ in
                if let data = try? Data(contentsOf: resolved) {
                    result = .data(data, mime: mimeType(for: resolved))
                }
            }
            if case .data = result { return result }
        }

        // Related-item / same-process access may already cover the sibling.
        if let data = try? Data(contentsOf: resolved) {
            return .data(data, mime: mimeType(for: resolved))
        }
        return .missing
    }

    private static func loadRemote(_ url: URL) async -> MarkdownImageLoadResult {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !data.isEmpty else { return .missing }
            let mime = (response as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Content-Type") }?
                .split(separator: ";").first
                .map(String.init)
                ?? mimeType(for: url)
            guard isAllowedPreviewMIME(mime) else { return .denied }
            return .data(data, mime: mime)
        } catch {
            return .missing
        }
    }

    private static func isAllowedPreviewMIME(_ mime: String) -> Bool {
        let lower = mime.lowercased()
        return lower.hasPrefix("image/") || lower == "text/css" || lower == "text/plain"
    }
}

