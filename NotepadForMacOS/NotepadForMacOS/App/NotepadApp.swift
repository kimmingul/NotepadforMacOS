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


    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage(OnboardingState.hasSeenWelcomeKey) private var hasSeenWelcome: Bool = false
    @AppStorage(OnboardingState.lastSeenWhatsNewVersionKey) private var lastSeenWhatsNewVersion: String = ""

    @State private var showWelcome = false
    @State private var showWhatsNew = false
    /// Stable id so only one editor window claims a shared onboarding sheet.
    @State private var presentationOwnerID = UUID()

    init(sessionID: UUID?) {
        _tabManager = StateObject(wrappedValue: TabManager(sessionID: sessionID))
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
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationTitle(windowTitle)
            .onAppear {
                ExternalDocumentOpener.activate(tabManager)
                evaluateOnboarding()
                claimPendingOnboardingSheet()
            }
            .onChange(of: controlActiveState) { _, state in
                if state == .key {
                    ExternalDocumentOpener.activate(tabManager)
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
                ExternalDocumentOpener.deactivate(tabManager)
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
