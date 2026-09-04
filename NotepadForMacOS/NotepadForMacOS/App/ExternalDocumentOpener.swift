import AppKit
import UniformTypeIdentifiers

/// Finder / Dock / 창 안 드롭으로 들어온 파일을 **어느 창의 탭으로 열지** 결정하고 실행한다.
///
/// 규칙:
///   1. 그 파일을 이미 가진 창이 있으면 그 창이 연다(그 창을 앞으로 가져온다). 같은 파일이
///      두 창에 열리면 저장 순서가 디스크 내용을 결정하고, `TabManager.openFile`의 중복 탭
///      감지는 창 하나 안에서만 동작해 이를 막지 못한다. 같은 파일 판정은
///      `TabManager.hasTab(forFileAt:)` — inode+device 기준이라 이름만 같은 다른 디렉터리의
///      파일은 다른 파일로 본다.
///   2. 아니면 요청한 창(파일 ▸ 열기, 창 안 드롭)이 연다.
///   3. 요청한 창이 없으면(Finder/Dock) 가장 앞의 편집기 창이 연다.
///   4. 창이 하나도 없으면(콜드 런치) URL을 모아 두고, 첫 창이 뜰 때 흘려보낸다.
enum ExternalDocumentOpener {
    private static var pending: [URL] = []

    /// 실행 직후의 첫 처리인지. 콜드 런치에서만 다르게 굴어야 하는 두 가지가 있다(아래 참고).
    private static var didSettleLaunch = false

    /// 문서 열기 이벤트 진입점(`ExternalOpenEventHandler`, `AppDelegate`).
    static func enqueue(_ urls: [URL]) {
        pending.append(contentsOf: OpenableDocumentType.openableURLs(in: urls))
        flushPending()
    }

    /// 창이 화면에 붙거나 key 창이 될 때 호출. 콜드 런치 때 밀린 URL을 처리한다.
    static func flushPending() {
        guard !pending.isEmpty else { return }
        let urls = pending
        pending.removeAll()
        pending = route(urls, preferring: nil, preferredEncoding: nil)
    }

    /// 사용자가 앱 안에서 요청한 열기(파일 ▸ 열기, 드롭).
    /// - Returns: 하나라도 열렸으면 true.
    @discardableResult
    static func open(
        _ urls: [URL],
        preferring requester: TabManager?,
        preferredEncoding: TextEncoding? = nil
    ) -> Bool {
        let openable = OpenableDocumentType.openableURLs(in: urls)
        guard !openable.isEmpty else { return false }
        let unhandled = route(openable, preferring: requester, preferredEncoding: preferredEncoding)
        pending.append(contentsOf: unhandled)
        return unhandled.count < openable.count
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
                    open([url], preferring: tabManager)
                }
            }
        }
        return true
    }

    /// - Returns: 열 창이 없어서 처리하지 못한 URL.
    private static func route(
        _ urls: [URL],
        preferring requester: TabManager?,
        preferredEncoding: TextEncoding?
    ) -> [URL] {
        let registry = EditorWindowRegistry.shared
        let isLaunchFlush = requester == nil && !didSettleLaunch
        var unhandled: [URL] = []
        var openedAny = false

        for url in urls {
            let owner = registry.owner(ofFileAt: url)
            // 콜드 런치에서는 기본(루트 세션) 창을 우선한다. 그 세션만 다음 실행에서 복원되므로,
            // Finder로 연 파일이 복원 대상 밖으로 밀려나지 않게 한다.
            let launchTarget = isLaunchFlush ? registry.primary : nil
            guard let target = owner ?? requester ?? launchTarget ?? registry.frontmost else {
                unhandled.append(url)
                continue
            }
            openScoped(url, in: target, preferredEncoding: preferredEncoding)
            openedAny = true
            if target !== requester {
                registry.focus(target)
            }
        }

        if !unhandled.isEmpty {
            // 창이 한 번이라도 있었다면(설정 창만 남은 상태 등) 새 창을 요청한다. 콜드 런치처럼
            // 아직 창이 한 번도 없었으면 프레임워크가 곧 만들 창을 기다린다(창이 붙을 때 재시도).
            EditorWindowOpener.shared.openWindow()
            return unhandled
        }

        if isLaunchFlush, openedAny {
            didSettleLaunch = true
        }

        return unhandled
    }

    private static func openScoped(_ url: URL, in tabManager: TabManager, preferredEncoding: TextEncoding?) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        _ = tabManager.openFile(url: url, preferredEncoding: preferredEncoding)
    }
}
