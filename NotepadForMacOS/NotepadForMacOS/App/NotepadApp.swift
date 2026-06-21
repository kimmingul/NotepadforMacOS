import SwiftUI
import AppKit

@main
struct NotepadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

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
                .frame(minWidth: 400, idealWidth: 420, minHeight: 510, idealHeight: 570)
                .onAppear(perform: forceSettingsWindowSize)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 570)
    }
}

struct NotepadWindowView: View {
    @StateObject private var tabManager: TabManager
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    init(sessionID: UUID?) {
        _tabManager = StateObject(wrappedValue: TabManager(sessionID: sessionID))
    }

    var body: some View {
        MainEditorView()
            .environmentObject(tabManager)
            .focusedSceneObject(tabManager)
            .frame(minWidth: 600, minHeight: 400)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationTitle(windowTitle)
            .onDisappear {
                tabManager.forcePersist()
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
/// restoration, so we locate the window (by localized title) and call setFrame after
/// a short delay that lets SwiftUI attach the real NSWindow.
private func forceSettingsWindowSize() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        guard let window = NSApp.windows.first(where: { w in
            guard w.isVisible else { return false }
            let t = w.title.lowercased()
            let isSettingsTitle = t.contains("setting") || t.contains("설정")
            let isNotMainEditor = !t.contains("notepad")
            return isSettingsTitle && isNotMainEditor
        }) else { return }

        let targetSize = NSSize(width: 420, height: 570)
        var newFrame = window.frame
        newFrame.size = targetSize
        window.setFrame(newFrame, display: true, animate: false)
        window.contentMinSize = targetSize
        window.contentMaxSize = NSSize(width: 560, height: 690)
    }
}
