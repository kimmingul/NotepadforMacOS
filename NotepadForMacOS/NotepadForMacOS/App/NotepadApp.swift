import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct NotepadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    // Immediate debug write (runs very early)
    private static let _debugInit: Void = {
        let user = NSUserName()
        let path = "/Users/\(user)/Desktop/Notepad_Menu_Debug.txt"
        let msg = "[\(Date())] NotepadApp struct loaded. User=\(user)\n"
        try? msg.write(toFile: path, atomically: true, encoding: .utf8)
    }()

    var body: some Scene {
        WindowGroup("Notepad", id: "editor", for: UUID.self) { windowID in
            NotepadWindowView(sessionID: windowID.wrappedValue)
        }
        .commands {
            NotepadCommands()
        }

        // === Settings window sizing notes ===
        // Changing only .frame(min/ideal) on the content of a `Settings {}` scene
        // frequently has no visible effect. Reasons:
        //   1. Settings scene sizing is driven by intrinsic content size + scene modifiers.
        //   2. macOS persists the window frame in ~/Library/Saved Application State/com.jbnu.mgkim.NotepadForMacOS.savedState
        //      Once shown, later launches restore the old size and ignore ideal/min values.
        //
        // Reliable combination used here:
        //   - .defaultSize + .windowResizability on the scene
        //   - Explicit .frame(min/ideal) + .onAppear AppKit forcing on the content
        //   - Matching .frame on the root container inside SettingsView
        //
        // For development, if you still don't see changes after rebuild, clear saved state:
        //   rm -rf ~/Library/Saved\ Application\ State/com.jbnu.mgkim.NotepadForMacOS.savedState
        // Then fully quit the app and reopen Settings (Cmd+, or menu).
        Settings {
            SettingsView()
                // NOTE: .frame on the content alone is often ignored for Settings scenes.
                // We combine (1) scene-level .defaultSize + .windowResizability and
                // (2) explicit AppKit frame forcing (see forceSettingsWindowSize) to
                // reliably override macOS persisted window frames.
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

        // Force debug file write from view (guaranteed to run)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("Notepad_Debug.txt").path
        let msg = "[\(Date())] NotepadWindowView init called. session=\(sessionID?.uuidString ?? "nil")\n"
        try? msg.write(toFile: path, atomically: true, encoding: .utf8)
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
            .onAppear {
                let path = FileManager.default.temporaryDirectory.appendingPathComponent("Notepad_Debug.txt").path
                var content = "[\(Date())] NotepadWindowView onAppear. Window shown.\n"
                // Dump the current main menu structure, especially View menu
                if let main = NSApp.mainMenu {
                    content += "Main menu items:\n"
                    for m in main.items {
                        content += "  - \(m.title)\n"
                        if m.title == "보기" || m.title == "View" {
                            if let sub = m.submenu {
                                content += "    View submenu:\n"
                                for it in sub.items {
                                    content += "      * \(it.title)\n"
                                    if let ssub = it.submenu {
                                        for s in ssub.items {
                                            content += "        - \(s.title)\n"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                try? content.write(toFile: path, atomically: true, encoding: .utf8)
            }
    }

    private var windowTitle: String {
        guard let tab = tabManager.selectedTab, tab.fileURL != nil else {
            return String(localized: "Notepad")
        }
        return "\(String(localized: "Notepad")) - \(tab.fullTitleForWindow)"
    }
}

struct NotepadCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedObject private var tabManager: TabManager?

    @AppStorage("showStatusBar") private var showStatusBar: Bool = true
    @AppStorage("showTabBar") private var showTabBar: Bool = true
    @AppStorage("wordWrap") private var wordWrap: Bool = false
    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                tabManager?.newTab()
            } label: {
                Label(String(localized: "New Tab"), systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(tabManager == nil)

            Button {
                openWindow(id: "editor", value: UUID())
            } label: {
                Label(String(localized: "New Window"), systemImage: "macwindow.badge.plus")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(after: .newItem) {
            Button {
                guard let tabManager else { return }
                NotepadDocumentActions.openFileDialog(in: tabManager)
            } label: {
                Label(String(localized: "Open..."), systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(tabManager == nil)

            Menu {
                ForEach(TextEncoding.allCases) { enc in
                    Button(enc.displayName) {
                        guard let tabManager else { return }
                        NotepadDocumentActions.openFileDialog(in: tabManager, preferredEncoding: enc)
                    }
                }
            } label: {
                Label(String(localized: "Open with Encoding"), systemImage: "textformat")
            }
            .disabled(tabManager == nil)
        }

        CommandGroup(replacing: .saveItem) {
            Button {
                guard let tabManager else { return }
                _ = NotepadDocumentActions.saveCurrentTab(in: tabManager)
            } label: {
                Label(String(localized: "Save"), systemImage: "arrow.down.doc")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(tabManager?.selectedTab == nil)

            Button {
                guard let tabManager else { return }
                _ = NotepadDocumentActions.saveAsCurrentTab(in: tabManager)
            } label: {
                Label(String(localized: "Save As..."), systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(tabManager?.selectedTab == nil)
        }

        CommandGroup(after: .pasteboard) {
            Button {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            } label: {
                Label(String(localized: "Select All"), systemImage: "checkmark.square")
            }
            .keyboardShortcut("a", modifiers: .command)

            Divider()

            Button {
                guard let tabManager else { return }
                NotificationCenter.default.post(name: .showFind, object: tabManager)
            } label: {
                Label(String(localized: "Find..."), systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(tabManager == nil)

            Button {
                guard let tabManager else { return }
                NotificationCenter.default.post(name: .showGoToLine, object: tabManager)
            } label: {
                Label(String(localized: "Go to Line..."), systemImage: "arrow.right.to.line")
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(tabManager == nil)

            Button {
                tabManager?.insertTimeDate()
            } label: {
                Label(String(localized: "Time/Date"), systemImage: "clock")
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!)), modifiers: [])
            .disabled(tabManager == nil)
        }

        CommandGroup(before: .sidebar) {
            Button {
                wordWrap.toggle()
            } label: {
                Label(
                    wordWrap ? String(localized: "Disable Word Wrap") : String(localized: "Enable Word Wrap"),
                    systemImage: "arrow.left.and.right"
                )
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Divider()

            Toggle(isOn: $isDarkMode) {
                Label(String(localized: "Dark Mode"), systemImage: "moon")
            }

            Divider()

            Button {
                fontSize = min(fontSize + 1, 72)
            } label: {
                Label(String(localized: "Zoom In"), systemImage: "plus.magnifyingglass")
            }
            .keyboardShortcut("+", modifiers: .command)

            Button {
                fontSize = max(fontSize - 1, 8)
            } label: {
                Label(String(localized: "Zoom Out"), systemImage: "minus.magnifyingglass")
            }
            .keyboardShortcut("-", modifiers: .command)

            Button {
                fontSize = 14.0
            } label: {
                Label(String(localized: "Reset Zoom"), systemImage: "magnifyingglass")
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Toggle(isOn: $showStatusBar) {
                Label(String(localized: "Show Status Bar"), systemImage: "rectangle.bottomthird.inset.filled")
            }

            Divider()

            Toggle(isOn: $showTabBar) {
                Label(String(localized: "Show Tab Bar"), systemImage: "rectangle.split.2x1")
            }

            Button {
                // 모든 탭 보기: 모든 에디터 창을 앞으로 가져오기
                for window in NSApp.windows where window.identifier?.rawValue.contains("editor") ?? true {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label(String(localized: "Show All Tabs"), systemImage: "square.grid.2x2")
            }
        }

        CommandGroup(after: .windowList) {
            Button {
                guard let tabManager else { return }
                NotepadDocumentActions.closeSelectedTab(in: tabManager)
            } label: {
                Label(String(localized: "Close Tab"), systemImage: "xmark.square")
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(tabManager?.selectedTab == nil)
        }

        CommandGroup(replacing: .help) {
            Button {
                var options: [NSApplication.AboutPanelOptionKey: Any] = [
                    .applicationName: String(localized: "Notepad for macOS"),
                    .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                    .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                ]
                
                // Credits.rtf를 명시적으로 로드 (번들 복사 문제 회피에 더 안정적)
                if let creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
                   let credits = try? NSAttributedString(
                       url: creditsURL,
                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                       documentAttributes: nil
                   ) {
                    options[.credits] = credits
                }
                
                NSApplication.shared.orderFrontStandardAboutPanel(options: options)
            } label: {
                Label(String(localized: "About Notepad for macOS"), systemImage: "info.circle")
            }

            Button {
                if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label(String(localized: "View License"), systemImage: "doc.text")
            }
        }
    }
}

enum NotepadDocumentActions {
    @discardableResult
    static func openFileDialog(in tabManager: TabManager, preferredEncoding: TextEncoding? = nil) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text]

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        tabManager.openFile(url: url, preferredEncoding: preferredEncoding)
        return true
    }

    @discardableResult
    static func saveCurrentTab(in tabManager: TabManager) -> Bool {
        guard let tab = tabManager.selectedTab else { return false }

        if tab.fileURL != nil {
            let saved = tabManager.saveCurrentTab()
            if !saved {
                showSaveFailedAlert(for: tab)
            }
            return saved
        }

        return saveAsCurrentTab(in: tabManager)
    }

    @discardableResult
    static func saveAsCurrentTab(in tabManager: TabManager) -> Bool {
        guard let id = tabManager.selectedTabID else { return false }
        return saveAsTab(id, in: tabManager)
    }

    @discardableResult
    static func saveAsTab(_ id: UUID, in tabManager: TabManager) -> Bool {
        guard let document = tabManager.document(with: id) else { return false }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = document.displayTitle

        let encodingPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        TextEncoding.allCases.forEach { encodingPicker.addItem(withTitle: $0.displayName) }
        if let index = TextEncoding.allCases.firstIndex(of: document.encoding) {
            encodingPicker.selectItem(at: index)
        }

        let accessoryView = NSStackView()
        accessoryView.orientation = .horizontal
        accessoryView.alignment = .centerY
        accessoryView.spacing = 8
        accessoryView.addArrangedSubview(NSTextField(labelWithString: String(localized: "Encoding:")))
        accessoryView.addArrangedSubview(encodingPicker)
        panel.accessoryView = accessoryView

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        let selectedIndex = max(0, encodingPicker.indexOfSelectedItem)
        let encoding = TextEncoding.allCases[selectedIndex]
        let saved = tabManager.saveTab(id, to: url, encoding: encoding)

        if !saved {
            showSaveFailedAlert(for: document)
        }

        return saved
    }

    @discardableResult
    static func closeSelectedTab(in tabManager: TabManager) -> Bool {
        guard let id = tabManager.selectedTabID else { return false }
        return closeTab(id, in: tabManager)
    }

    @discardableResult
    static func closeTab(_ id: UUID, in tabManager: TabManager) -> Bool {
        guard let document = tabManager.document(with: id) else { return false }

        guard document.isDirty else {
            tabManager.closeTab(id)
            return true
        }

        switch promptForUnsavedChanges(document) {
        case .save:
            if document.fileURL == nil {
                let saved = saveAsTab(id, in: tabManager)
                if saved {
                    tabManager.closeTab(id)
                }
                return saved
            }

            let saved = tabManager.saveTab(id)

            if saved {
                tabManager.closeTab(id)
            } else {
                showSaveFailedAlert(for: document)
            }
            return saved
        case .discard:
            tabManager.closeTab(id)
            return true
        case .cancel:
            return false
        }
    }

    private static func promptForUnsavedChanges(_ document: Document) -> UnsavedCloseChoice {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: String(localized: "unsavedChanges.message"), document.displayTitle)
        alert.informativeText = String(localized: "unsavedChanges.informative")
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Don't Save"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .discard
        default:
            return .cancel
        }
    }

    private static func showSaveFailedAlert(for document: Document) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(format: String(localized: "saveFailed.message"), document.displayTitle)
        alert.informativeText = String(localized: "saveFailed.informative")
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private enum UnsavedCloseChoice {
        case save
        case discard
        case cancel
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
/// Why this exists:
/// - `.frame(idealWidth/Height:)` + even `.defaultSize` on `Settings` can be overridden
///   by macOS window restoration (Saved Application State).
/// - The grouped Form inside SettingsView proposes its own intrinsic size.
/// - We explicitly locate the window (by localized title) and call setFrame.
///
/// Call this from .onAppear inside the Settings content. A small delay gives SwiftUI
/// time to create and attach the real NSWindow.
private func forceSettingsWindowSize() {
    // Give the window a moment to be created and made key/visible
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        // Find the Settings window. It uses the localized "Settings" title.
        // We avoid matching the main editor windows by excluding "Notepad" in title.
        guard let window = NSApp.windows.first(where: { w in
            guard w.isVisible else { return false }
            let t = w.title.lowercased()
            let isSettingsTitle = t.contains("setting") || t.contains("설정")
            let isNotMainEditor = !t.contains("notepad")
            return isSettingsTitle && isNotMainEditor
        }) else {
            return
        }

        // Desired size — keep in sync with .defaultSize above and the .frame on SettingsView
        let targetSize = NSSize(width: 420, height: 570)

        // Preserve current top-left (standard macOS window coordinate behavior)
        var newFrame = window.frame
        newFrame.size = targetSize

        window.setFrame(newFrame, display: true, animate: false)

        // Prevent the content from being squeezed or auto-grown too aggressively later
        window.contentMinSize = targetSize
        // Allow the user a little room if they want to resize slightly (contentSize resizability still applies)
        window.contentMaxSize = NSSize(width: 560, height: 690)
    }
}
