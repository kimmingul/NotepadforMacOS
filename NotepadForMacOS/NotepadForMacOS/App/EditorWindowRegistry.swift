import AppKit

/// 살아 있는 편집기 창(`TabManager` ↔ `NSWindow`)을 추적한다.
///
/// 두 가지 질문에 답하기 위해 존재한다.
///   - 외부에서 들어온 파일을 **어느 창**이 열어야 하는가: 이미 그 파일을 가진 창이 있으면
///     그 창이다. 같은 파일을 두 창이 각자 열면 저장 순서가 디스크 내용을 결정하고,
///     `TabManager.openFile`의 중복 탭 감지는 창 하나 안에서만 동작해 막지 못한다.
///   - 그 창을 앞으로 가져오려면 어떤 `NSWindow`를 써야 하는가: SwiftUI에는 씬에서
///     `NSWindow`를 얻는 공식 경로가 없어, 창이 붙을 때 뷰가 직접 등록한다.
final class EditorWindowRegistry {
    static let shared = EditorWindowRegistry()

    private struct Entry {
        weak var tabManager: TabManager?
        weak var window: NSWindow?
    }

    private var entries: [Entry] = []


    /// 이 레지스트리가 처음 쓰인 시각(= 실행 직후). 루트 세션 인수는 이 직후에만 허용한다.
    private let startedAt = Date()

    /// 창을 등록한다. `window`는 뷰가 붙기 전에는 `nil`일 수 있어, 붙는 순간 채워 넣는다.
    ///
    /// 창이 실제로 붙은 시점이 중요하다. 그 전까지 이 창은 파일을 열 대상이 될 수 없다
    /// (실측: 화면에 없는 창으로 파일을 보내면 아무 일도 일어나지 않는다). 그래서 창이 붙는
    /// 순간 대기 중인 문서를 다시 흘려보낸다.
    func register(_ tabManager: TabManager, window: NSWindow?) {
        compact()
        if let index = entries.firstIndex(where: { $0.tabManager === tabManager }) {
            if let window { entries[index].window = window }
        } else {
            entries.append(Entry(tabManager: tabManager, window: window))
        }
        guard window != nil else { return }
        adoptPrimarySessionIfOrphaned(tabManager)
        ExternalDocumentOpener.flushPending()
    }

    /// 화면에 뜬 창 중 루트 세션 주인이 없으면 이 창이 넘겨받는다.
    ///
    /// 실행 직후에만 한다. 나중에도 허용하면 사용자가 기본 창을 닫은 뒤 New Window로 만든 빈 창에
    /// 예전 탭들이 되살아난다.
    private func adoptPrimarySessionIfOrphaned(_ tabManager: TabManager) {
        guard Date().timeIntervalSince(startedAt) < 10 else { return }
        guard primary == nil else { return }
        tabManager.adoptPrimarySession()
    }

    // 콜드 런치에서 SwiftUI가 문서 열기 이벤트에 응답해 만든 여분의 빈 창을 프로그램으로
    // 닫아 보는 시도는 철회했다. `performClose`/`close`로 닫으면 문서 라우팅과 경합해서
    // 실측에서 파일이 아예 열리지 않는 실행이 나왔다(창 1개, 루트 세션 비어 있음). 빈 창이
    // 하나 남는 것보다 문서를 잃는 쪽이 훨씬 나쁘므로 정리하지 않는다.

    func unregister(_ tabManager: TabManager) {
        entries.removeAll { $0.tabManager === tabManager || $0.tabManager == nil }
    }

    /// 화면에 있는 편집기 창만. 아직 창에 붙지 않은 항목은 파일을 열 대상이 될 수 없다.
    private var liveEntries: [(manager: TabManager, window: NSWindow)] {
        compact()
        return entries.compactMap { entry in
            guard let manager = entry.tabManager, let window = entry.window else { return nil }
            return (manager, window)
        }
    }

    /// 가장 앞에 있는 편집기 창.
    ///
    /// 설정 창이나 시트가 key window일 수 있으므로 화면 순서(`orderedWindows`)를 기준으로 한다.
    var frontmost: TabManager? {
        let live = liveEntries
        for window in NSApp.orderedWindows {
            if let match = live.first(where: { $0.window === window }) {
                return match.manager
            }
        }
        return live.first?.manager
    }

    /// 루트 세션(다음 실행에서 복원되는 세션)을 가진 창.
    var primary: TabManager? {
        liveEntries.first { $0.manager.ownsPrimarySession }?.manager
    }

    /// 이 파일을 이미 탭으로 가진 창. 없으면 `nil`.
    func owner(ofFileAt url: URL) -> TabManager? {
        liveEntries.first { $0.manager.hasTab(forFileAt: url) }?.manager
    }

    /// 그 파일을 가진 창을 앞으로 가져온다.
    ///
    /// Finder에서 열면 Launch Services가 앱을 활성화하면서 직전에 앞에 있던 창을 다시 올린다.
    /// 그래서 다음 런루프 턴에 한 번 더 올려야 사용자가 그 파일을 실제로 보게 된다.
    /// macOS가 창들을 네이티브 창 탭으로 합쳐 둔 경우에는 창을 올리는 것만으로는 보이지 않아
    /// 탭 그룹의 선택까지 옮긴다.
    func focus(_ tabManager: TabManager) {
        compact()
        guard let window = entries.first(where: { $0.tabManager === tabManager })?.window else { return }
        bringToFront(window)
        DispatchQueue.main.async {
            bringToFront(window)
        }

        func bringToFront(_ window: NSWindow) {
            if let group = window.tabGroup, group.selectedWindow !== window {
                group.selectedWindow = window
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func compact() {
        entries.removeAll { $0.tabManager == nil }
    }
}
