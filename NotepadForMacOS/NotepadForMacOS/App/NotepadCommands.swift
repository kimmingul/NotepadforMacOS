import SwiftUI
import AppKit

/// 메인 메뉴 명령 트리. Windows 11 Notepad의 메뉴/단축키를 macOS 관례에 맞게 매핑.
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
