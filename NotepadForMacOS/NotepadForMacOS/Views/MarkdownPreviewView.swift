import SwiftUI
import AppKit
import WebKit

enum MarkdownPreviewReload {
    static func shouldReload(
        html: String,
        lastHTML: String?,
        directoryBookmark: Data?,
        lastDirectoryBookmark: Data?
    ) -> Bool {
        html != lastHTML || directoryBookmark != lastDirectoryBookmark
    }
}

enum MarkdownPreviewNavigation {
    enum Decision: Equatable {
        case allow
        case cancel
        case openExternally
    }

    static func decide(url: URL, isMainFrame: Bool) -> Decision {
        switch url.scheme?.lowercased() {
        case "about":
            return .allow
        case MarkdownImagePolicy.urlScheme:
            if url.host == "preview" { return .allow }
            if isMainFrame { return .cancel }
            return url.host == "img" ? .allow : .cancel
        case "http", "https", "mailto":
            return .openExternally
        default:
            return .cancel
        }
    }
}

struct MarkdownPreviewPane: View {
    let document: Document
    @EnvironmentObject var preview: MarkdownPreviewController
    @EnvironmentObject var tabManager: TabManager
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var rendered = MarkdownRenderResult(html: "", containsRemoteImages: false, containsLocalImages: false)
    @State private var renderTask: Task<Void, Never>?

    private var allowsRemote: Bool { preview.allowsRemoteImages(for: document.id) }
    private var isHTML: Bool { PreviewDocumentKind.isHTML(fileURL: document.fileURL) }


    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(String(localized: "markdown.preview"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if rendered.containsRemoteImages {
                    Button {
                        preview.setAllowsRemoteImages(!allowsRemote, for: document.id)
                    } label: {
                        Text(remoteAllowTitle)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .help(String(localized: isHTML ? "html.remote.help" : "markdown.remote.help"))
                }
                if rendered.containsLocalImages, document.fileURL != nil {
                    Button {
                        NotepadDocumentActions.grantMarkdownFolderAccess(for: document.id, in: tabManager)
                    } label: {
                        Text(String(localized: "markdown.folderAllow"))
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .help(String(localized: isHTML ? "html.folder.help" : "markdown.folder.help"))
                }
                Button {
                    ExternalDocumentOpener.openInDefaultBrowser(document)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .disabled(document.fileURL == nil)
                .help(String(localized: document.fileURL == nil ? "preview.browser.saveFirst" : "preview.browser.help"))

                Button {
                    preview.toggleFull()
                } label: {
                    Image(systemName: preview.layout == .full ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderless)
                .help(preview.layout == .full
                      ? String(localized: "markdown.exitFull")
                      : String(localized: "markdown.full"))
                Button {
                    preview.layout = .hidden
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "markdown.hide"))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            MarkdownPreviewWebView(
                html: rendered.html,
                document: document,
                allowsRemote: allowsRemote,
                onEscape: {
                    if preview.layout == .full {
                        preview.exitFull()
                    }
                }
            )
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear { scheduleRender() }
        .onChange(of: document.content) { _, _ in scheduleRender() }
        .onChange(of: allowsRemote) { _, _ in scheduleRender() }
        .onChange(of: isDarkMode) { _, _ in scheduleRender() }
        .onKeyPress(.escape) {
            if preview.layout == .full {
                preview.exitFull()
                return .handled
            }
            return .ignored
        }
    }

    private func scheduleRender() {
        renderTask?.cancel()
        renderTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true {
                scheduleRender()
                return
            }
            if PreviewDocumentKind.isHTML(fileURL: document.fileURL) {
                let result = HTMLPreviewSanitizer.sanitize(document.content, allowsRemote: allowsRemote)
                rendered = MarkdownRenderResult(
                    html: result.html,
                    containsRemoteImages: result.containsRemoteResources,
                    containsLocalImages: result.containsLocalResources
                )
            } else {
                rendered = MarkdownHTMLRenderer.render(
                    document.content,
                    allowsRemoteImages: allowsRemote,
                    isDark: isDarkMode
                )
            }
        }
    }

    private var remoteAllowTitle: String {
        if isHTML {
            return String(localized: allowsRemote ? "html.remoteOn" : "html.remoteAllow")
        }
        return String(localized: allowsRemote ? "markdown.remoteOn" : "markdown.remoteAllow")
    }

}

final class MarkdownPreviewWKWebView: WKWebView {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            onEscape?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct MarkdownPreviewWebView: NSViewRepresentable {
    let html: String
    let document: Document
    let allowsRemote: Bool
    var onEscape: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MarkdownPreviewWKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator, forURLScheme: MarkdownImagePolicy.urlScheme)
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()

        let webView = MarkdownPreviewWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.escapeHandler = onEscape
        webView.onEscape = { [weak coordinator = context.coordinator] in
            coordinator?.handleEscape()
        }
        context.coordinator.apply(html: html, document: document, allowsRemote: allowsRemote)
        return webView
    }

    func updateNSView(_ webView: MarkdownPreviewWKWebView, context: Context) {
        context.coordinator.webView = webView
        context.coordinator.escapeHandler = onEscape
        webView.onEscape = { [weak coordinator = context.coordinator] in
            coordinator?.handleEscape()
        }
        context.coordinator.apply(html: html, document: document, allowsRemote: allowsRemote)
    }

    final class Coordinator: NSObject, WKURLSchemeHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var document: Document?
        var allowsRemote = false
        var escapeHandler: () -> Void = {}
        private var lastHTML: String?
        private var lastDirectoryBookmark: Data?
        private var inflight = Set<ObjectIdentifier>()

        func handleEscape() {
            escapeHandler()
        }

        func apply(html: String, document: Document, allowsRemote: Bool) {
            self.document = document
            self.allowsRemote = allowsRemote
            guard MarkdownPreviewReload.shouldReload(
                html: html,
                lastHTML: lastHTML,
                directoryBookmark: document.directoryBookmark,
                lastDirectoryBookmark: lastDirectoryBookmark
            ) else { return }
            lastHTML = html
            lastDirectoryBookmark = document.directoryBookmark
            let base = URL(string: "\(MarkdownImagePolicy.urlScheme)://preview/")
            webView?.loadHTMLString(html, baseURL: base)
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            let id = ObjectIdentifier(urlSchemeTask)
            inflight.insert(id)
            let requestURL = urlSchemeTask.request.url
            let doc = document
            let remote = allowsRemote
            Task.detached {
                let result: MarkdownImageLoadResult
                if let requestURL, requestURL.host == "img" {
                    result = await MarkdownImageLoader.load(
                        url: requestURL,
                        documentDirectory: doc?.fileURL?.deletingLastPathComponent(),
                        directoryBookmark: doc?.directoryBookmark,
                        allowsRemote: remote
                    )
                } else {
                    result = .denied
                }
                await MainActor.run {
                    guard self.inflight.contains(id) else { return }
                    self.inflight.remove(id)
                    switch result {
                    case let .data(data, mime):
                        let response = URLResponse(
                            url: requestURL ?? URL(string: "\(MarkdownImagePolicy.urlScheme)://img")!,
                            mimeType: mime,
                            expectedContentLength: data.count,
                            textEncodingName: nil
                        )
                        urlSchemeTask.didReceive(response)
                        urlSchemeTask.didReceive(data)
                        urlSchemeTask.didFinish()
                    case .denied, .missing:
                        urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
            inflight.remove(ObjectIdentifier(urlSchemeTask))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            switch MarkdownPreviewNavigation.decide(
                url: url,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true
            ) {
            case .allow:
                decisionHandler(.allow)
            case .openExternally:
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            case .cancel:
                decisionHandler(.cancel)
            }
        }
    }
}
