import Foundation

nonisolated enum MarkdownImageKind: Equatable, Sendable {
    case localRelative(String)
    case remote(URL)
    case rejected
}

nonisolated enum MarkdownImagePolicy {
    static let urlScheme = "notepad-md"

    static func classify(_ destination: String) -> MarkdownImageKind {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .rejected }

        let lower = trimmed.lowercased()
        if trimmed.hasPrefix("//") || trimmed.contains("\\") {
            return .rejected
        }
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") || lower.hasPrefix("file:") || lower.hasPrefix("http:") {
            return .rejected
        }
        if lower.hasPrefix("https:") {
            guard lower.hasPrefix("https://"),
                  let url = URL(string: trimmed), url.scheme?.lowercased() == "https" else {
                return .rejected
            }
            return .remote(url)
        }

        if trimmed.contains("://") {
            return .rejected
        }
        return .localRelative(trimmed)
    }

    /// Resolve a relative/local destination against the markdown file's directory.
    /// Rejects escape via `..` outside that directory. `documentDirectory` must be a directory URL.
    static func resolveLocal(destination: String, documentDirectory: URL) -> URL? {
        let kind = classify(destination)
        guard case .localRelative(let relative) = kind else { return nil }

        let base = documentDirectory.standardizedFileURL
        let resolved = URL(fileURLWithPath: relative, relativeTo: base).standardizedFileURL
        let basePath = base.path
        let resolvedPath = resolved.path
        if resolvedPath == basePath { return nil }
        let prefix = basePath.hasSuffix("/") ? basePath : basePath + "/"
        guard resolvedPath.hasPrefix(prefix) else { return nil }
        return resolved
    }

    static func customSchemeURL(kind: String, payload: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "img"
        components.queryItems = [
            URLQueryItem(name: "k", value: kind),
            URLQueryItem(name: "p", value: payload)
        ]
        return components.url
    }

    static func parseCustomScheme(_ url: URL) -> (kind: String, payload: String)? {
        guard url.scheme?.lowercased() == urlScheme, url.host == "img" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let kind = items.first(where: { $0.name == "k" })?.value,
              let payload = items.first(where: { $0.name == "p" })?.value else {
            return nil
        }
        return (kind, payload)
    }
}
