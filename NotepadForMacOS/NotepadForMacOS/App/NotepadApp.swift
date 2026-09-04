import SwiftUI
import AppKit

@main
struct NotepadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    init() {
        // AppleLanguages is read at process start; this keeps the stored
        // preference and the override in sync for the *next* launch.
        AppLanguagePreferences.applyStored()
        // Seed onboarding defaults before any window reads @AppStorage keys.
        OnboardingMigration.applyIfNeeded()
    }

    var body: some Scene {
        // 편집기 창은 하나의 `WindowGroup`이 담당한다. 값(UUID)이 있는 창은 New Window로
        // 만든 보조 창이고, 값이 없는 창은 실행 시 만들어지는 기본 창이다.
        //
        // 외부 문서 열기 이벤트로 이 그룹이 창을 새로 만들지 못하게 막는 일은
        // `ExternalOpenEventHandler`가 이벤트를 직접 받아 처리한다. 씬 구성으로 막으려는 시도
        // (`.handlesExternalEvents(matching: [])`, 기본 창을 단일 `Window`로 분리)는 모두
        // 실측에서 더 나빴다: 콜드 런치에서 빈 창이 4개까지 늘었다.
        WindowGroup("Notepad", id: "editor", for: UUID.self) { windowID in
            NotepadWindowView(sessionID: windowID.wrappedValue)
        }
        .commands {
            NotepadCommands()
        }

        // === Settings window sizing notes ===
        // Changing only .frame(min/ideal) on the content of a `Settings {}` scene
        // frequently has no visible effect, because macOS persists the window frame
        // in Saved Application State and restores it on later launches. The reliable
        // combination is: scene-level .defaultSize + .windowResizability, explicit
        // .frame on the content, plus AppKit frame forcing (forceSettingsWindowSize).
        Settings {
            SettingsView()
                .frame(minWidth: 420, idealWidth: 440, minHeight: 700, idealHeight: 760)
                .onAppear(perform: forceSettingsWindowSize)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 760)
    }
}

struct NotepadWindowView: View {
    @StateObject private var tabManager: TabManager
    @StateObject private var preview = MarkdownPreviewController()
    @ObservedObject private var onboardingPresenter = OnboardingPresenter.shared
    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.openWindow) private var openWindow


    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage(OnboardingState.hasSeenWelcomeKey) private var hasSeenWelcome: Bool = false
    @AppStorage(OnboardingState.lastSeenWhatsNewVersionKey) private var lastSeenWhatsNewVersion: String = ""

    @State private var showWelcome = false
    @State private var showWhatsNew = false
    /// Stable id so only one editor window claims a shared onboarding sheet.
    @State private var presentationOwnerID = UUID()

    init(sessionID: UUID?) {
        // 값 없는 창이 여러 개 생겨도 루트 세션은 하나만 갖는다. EditorSessionIdentity 참고.
        // 클레임은 StateObject의 autoclosure 안에서 일어나야 한다. 뷰 struct는 여러 번
        // 초기화되지만 StateObject는 창당 한 번만 만들어진다.
        _tabManager = StateObject(
            wrappedValue: TabManager(sessionID: EditorSessionIdentity.shared.resolve(sessionID))
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        MainEditorView()
            .environmentObject(tabManager)
            .environmentObject(preview)
            .focusedSceneObject(tabManager)
            .focusedSceneObject(preview)
            .frame(minWidth: 600, minHeight: 400)
            .background(EditorWindowRegistrar(tabManager: tabManager))
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationTitle(windowTitle)
            .onAppear {
                EditorWindowRegistry.shared.register(tabManager, window: nil)
                EditorWindowOpener.shared.adopt(openWindow)
                EditorWindowOpener.shared.noteWindowAppeared()
                // 창이 생긴 다음부터 문서 열기 이벤트를 직접 받는다(설치는 한 번만 유효).
                ExternalOpenEventHandler.shared.install()
                ExternalDocumentOpener.flushPending()
                evaluateOnboarding()
                claimPendingOnboardingSheet()
            }
            .onChange(of: controlActiveState) { _, state in
                if state == .key {
                    ExternalDocumentOpener.flushPending()
                }
            }
            .onChange(of: onboardingPresenter.activeSheet) { _, _ in
                claimPendingOnboardingSheet()
            }
            .sheet(isPresented: $showWelcome, onDismiss: {
                hasSeenWelcome = true
                // After first-run Welcome, record current version so What's New
                // only appears on a later upgrade.
                if lastSeenWhatsNewVersion.isEmpty {
                    lastSeenWhatsNewVersion = appVersion
                }
                onboardingPresenter.dismiss(ownerID: presentationOwnerID)
            }) {
                WelcomeView {
                    showWelcome = false
                }
            }
            .sheet(isPresented: $showWhatsNew, onDismiss: {
                lastSeenWhatsNewVersion = appVersion
                onboardingPresenter.dismiss(ownerID: presentationOwnerID)
            }) {
                WhatsNewView(
                    version: appVersion,
                    bullets: OnboardingState.whatsNewBullets(for: appVersion)
                ) {
                    showWhatsNew = false
                }
            }
            .onChange(of: tabManager.tabs.map(\.id)) { _, ids in
                preview.retainRemoteAllows(forOpenTabs: ids)
            }
            .onDisappear {
                EditorWindowRegistry.shared.unregister(tabManager)
                NotepadTextInput.commitActiveComposition()
                if AppDelegate.isTerminating {
                    tabManager.forcePersist()          // 앱 종료 → 복원을 위해 보존
                } else {
                    tabManager.discardWindowSession()  // 창만 닫음 → 세션 디렉터리 정리
                }
            }
    }

    private func evaluateOnboarding() {
        // Only one window should auto-request onboarding per launch.
        guard OnboardingCoordinator.claimAutoPresent() else { return }
        if OnboardingState.shouldShowWelcome(hasSeenWelcome: hasSeenWelcome) {
            onboardingPresenter.request(.welcome)
            return
        }
        if OnboardingState.shouldShowWhatsNew(
            currentVersion: appVersion,
            lastSeenVersion: lastSeenWhatsNewVersion,
            hasSeenWelcome: hasSeenWelcome
        ) {
            onboardingPresenter.request(.whatsNew)
        }
    }

    private func claimPendingOnboardingSheet() {
        guard let sheet = onboardingPresenter.claim(ownerID: presentationOwnerID) else { return }
        switch sheet {
        case .welcome:
            showWelcome = true
        case .whatsNew:
            showWhatsNew = true
        }
    }

    private var windowTitle: String {
        guard let tab = tabManager.selectedTab, tab.fileURL != nil else {
            return String(localized: "Notepad")
        }
        return "\(String(localized: "Notepad")) - \(tab.fullTitleForWindow)"
    }
}

/// 이 창의 `NSWindow`를 레지스트리에 연결한다.
///
/// SwiftUI에는 씬에서 `NSWindow`를 얻는 공식 경로가 없다. 뷰가 창에 붙는 순간
/// (`viewDidMoveToWindow`)을 잡아야 한다. `updateNSView`에서 `view.window`를 읽으면 아직
/// 창에 붙지 않아 `nil`인 창이 생기고(실측), 그 창은 앞으로 가져올 수도, 정리할 수도 없다.
private struct EditorWindowRegistrar: NSViewRepresentable {
    let tabManager: TabManager

    func makeNSView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView()
        let manager = tabManager
        view.onWindowChange = { window in
            guard let window else { return }
            EditorWindowRegistry.shared.register(manager, window: window)
        }
        EditorWindowRegistry.shared.register(manager, window: view.window)
        return view
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        if let window = nsView.window {
            EditorWindowRegistry.shared.register(tabManager, window: window)
        }
    }
}

/// 창에 붙는 순간을 알려주는 빈 뷰.
final class WindowTrackingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

extension Notification.Name {
    static let showFind = Notification.Name("showFind")
    static let showGoToLine = Notification.Name("showGoToLine")
    static let startNewSessionRequested = Notification.Name("startNewSessionRequested")
}

// MARK: - Settings window sizing (works around SwiftUI Settings + saved state)

/// Force the Settings (Preferences) window to a specific size.
///
/// `.frame`/`.defaultSize` on a `Settings` scene can be overridden by macOS window
/// restoration, so we take the key window after SwiftUI attaches the real NSWindow.
/// Title matching is avoided so this still works after a language change.
private func forceSettingsWindowSize() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        guard let window = NSApp.keyWindow, window.isVisible else { return }

        let targetSize = NSSize(width: 440, height: 760)
        var newFrame = window.frame
        newFrame.size = targetSize
        window.setFrame(newFrame, display: true, animate: false)
        window.contentMinSize = targetSize
        window.contentMaxSize = NSSize(width: 560, height: 900)
    }
}
