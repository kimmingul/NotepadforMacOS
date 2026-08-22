import Foundation
import UniformTypeIdentifiers

nonisolated enum MarkdownImageLoadResult: Equatable, Sendable {
    case data(Data, mime: String)
    case denied
    case missing
}

nonisolated enum MarkdownImageLoader {
    static let maxResourceBytes = 8 * 1024 * 1024

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
                  isAllowedRemoteURL(remote) else {
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

    static func acceptsResource(byteCount: Int, mime: String) -> Bool {
        byteCount > 0 && byteCount <= maxResourceBytes && isAllowedPreviewMIME(mime)
    }

    static func isAllowedRemoteURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
        return !isPrivateOrLocalHost(host)
    }

    static func hostResolvesToPrivateAddress(_ host: String) -> Bool {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        hints.ai_family = AF_UNSPEC
        var info: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &info)
        defer { if let info { freeaddrinfo(info) } }
        guard status == 0 else { return true }
        var pointer = info
        while let current = pointer {
            if sockaddrIsPrivate(current.pointee.ai_addr) { return true }
            pointer = current.pointee.ai_next
        }
        return false
    }

    static func isAllowedPreviewMIME(_ mime: String) -> Bool {
        let lower = mime.split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            ?? mime.lowercased()
        if lower.hasPrefix("image/svg") { return false }
        return lower.hasPrefix("image/") || lower == "text/css"
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
                result = readLocalFile(resolved)
            }
            if result != .missing { return result }
        }

        return readLocalFile(resolved)
    }

    private static func readLocalFile(_ resolved: URL) -> MarkdownImageLoadResult {
        guard let data = try? Data(contentsOf: resolved) else { return .missing }
        let mime = mimeType(for: resolved)
        guard acceptsResource(byteCount: data.count, mime: mime) else { return .denied }
        return .data(data, mime: mime)
    }

    private static func loadRemote(_ url: URL) async -> MarkdownImageLoadResult {
        guard let host = url.host, !hostResolvesToPrivateAddress(host) else { return .denied }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await PreviewHTTP.session.data(for: request)
            let mime = (response as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Content-Type") }?
                .split(separator: ";").first
                .map { $0.trimmingCharacters(in: .whitespaces) }
                ?? mimeType(for: url)
            guard acceptsResource(byteCount: data.count, mime: mime) else {
                return data.isEmpty ? .missing : .denied
            }
            return .data(data, mime: mime)
        } catch {
            return .missing
        }
    }

    private static func isPrivateOrLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return true
        }
        if host.contains(":") {
            return host == "::1"
                || host.hasPrefix("fe80:")
                || host.hasPrefix("fc")
                || host.hasPrefix("fd")
                || host.hasPrefix("::ffff:127.")
                || host.hasPrefix("::ffff:10.")
                || host.hasPrefix("::ffff:192.168.")
                || host.hasPrefix("::ffff:169.254.")
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        let a = parts[0], b = parts[1]
        if a == 10 || a == 127 || a == 0 { return true }
        if a == 192 && b == 168 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 169 && b == 254 { return true }
        return false
    }

    private static func sockaddrIsPrivate(_ pointer: UnsafePointer<sockaddr>?) -> Bool {
        guard let pointer else { return true }
        switch Int32(pointer.pointee.sa_family) {
        case AF_INET:
            return pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var addr = sin.pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                    return true
                }
                return isPrivateOrLocalHost(String(cString: buffer))
            }
        case AF_INET6:
            return pointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                var addr = sin6.pointee.sin6_addr
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                guard inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                    return true
                }
                return isPrivateOrLocalHost(String(cString: buffer))
            }
        default:
            return true
        }
    }
}

private final class PreviewRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = PreviewRedirectGuard()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              MarkdownImageLoader.isAllowedRemoteURL(url),
              let host = url.host,
              !MarkdownImageLoader.hostResolvesToPrivateAddress(host) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

private enum PreviewHTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 15
        return URLSession(
            configuration: config,
            delegate: PreviewRedirectGuard.shared,
            delegateQueue: nil
        )
    }()
}
