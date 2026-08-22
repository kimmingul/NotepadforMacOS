import AppKit
import UniformTypeIdentifiers

/// Routes Finder / Dock / window file drops into the key editor window.
///
/// Launch Services delivers document URLs through `application(_:open:)`
/// (https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:open:)).
/// A window may not exist yet on cold launch, so URLs queue until a TabManager activates.
@MainActor
enum ExternalDocumentOpener {
    private static weak var active: TabManager?
    private static var pending: [URL] = []

    static func activate(_ tabManager: TabManager) {
        active = tabManager
        flush()
    }

    static func deactivate(_ tabManager: TabManager) {
        if active === tabManager {
            active = nil
        }
    }

    static func enqueue(_ urls: [URL]) {
        pending.append(contentsOf: OpenableDocumentType.openableURLs(in: urls))
        flush()
    }

    static func openNow(_ urls: [URL], in tabManager: TabManager) {
        for url in OpenableDocumentType.openableURLs(in: urls) {
            openScoped(url, in: tabManager)
        }
    }

    static func openInDefaultBrowser(_ document: Document) {
        guard let url = document.fileURL else { return }
        SecurityScopedFile.access(url, bookmark: document.securityScopedBookmark) { resolved in
            NSWorkspace.shared.open(resolved)
        }
    }


    @discardableResult
    static func load(_ providers: [NSItemProvider], into tabManager: TabManager) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    openNow([url], in: tabManager)
                }
            }
        }
        return true
    }

    private static func flush() {
        guard let active, !pending.isEmpty else { return }
        let urls = pending
        pending.removeAll()
        for url in urls {
            openScoped(url, in: active)
        }
    }

    private static func openScoped(_ url: URL, in tabManager: TabManager) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        _ = tabManager.openFile(url: url)
    }
}
