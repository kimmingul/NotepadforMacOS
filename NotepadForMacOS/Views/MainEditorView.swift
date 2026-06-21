import SwiftUI
import AppKit

struct MainEditorView: View {
    @EnvironmentObject var tabManager: TabManager

    @AppStorage("showStatusBar") private var showStatusBar: Bool = true
    @AppStorage("showTabBar") private var showTabBar: Bool = true
    @AppStorage("wordWrap") private var wordWrap: Bool = false
    @AppStorage("fontSize") private var fontSize: Double = 14.0

    @State private var showFindSheet = false
    @State private var showGoToLineSheet = false
    @State private var findText = ""
    @State private var replaceText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            if showTabBar {
                TabBarView()
                    .environmentObject(tabManager)

                Divider()
            }

            // Editor
            if let selectedTab = tabManager.selectedTab {
                EditorView(document: selectedTab)
                    .environmentObject(tabManager)
                    .id(selectedTab.id) // 탭 전환 시 뷰 리프레시
            } else {
                VStack {
                    Text("No document open")
                        .foregroundStyle(.secondary)
                    Button("New Tab") {
                        tabManager.newTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Status Bar
            if showStatusBar, let tab = tabManager.selectedTab {
                StatusBarView(document: tab)
                    .environmentObject(tabManager)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFind)) { notification in
            if notification.object as? TabManager === tabManager {
                showFindSheet = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showGoToLine)) { notification in
            if notification.object as? TabManager === tabManager {
                showGoToLineSheet = true
            }
        }
        .sheet(isPresented: $showFindSheet) {
            FindReplaceSheet(
                findText: $findText,
                replaceText: $replaceText,
                onFind: { search, matchCase in
                    tabManager.findInSelectedTab(search: search, matchCase: matchCase)
                },
                onReplace: { search, replacement, matchCase in
                    tabManager.replaceInSelectedTab(search: search, replacement: replacement, matchCase: matchCase)
                },
                onReplaceAll: { search, replacement, matchCase in
                    tabManager.replaceAllInSelectedTab(search: search, replacement: replacement, matchCase: matchCase)
                }
            )
        }
        .sheet(isPresented: $showGoToLineSheet) {
            GoToLineSheet { line in
                tabManager.goToLineInSelectedTab(line)
            }
        }
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManager
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(tab: tab, isSelected: tab.id == tabManager.selectedTabID)
                            .onTapGesture {
                                tabManager.selectTab(tab.id)
                            }
                            .contextMenu {
                                Button("Close Tab") {
                                    NotepadDocumentActions.closeTab(tab.id, in: tabManager)
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }

            Button(action: {
                tabManager.newTab()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .padding(6)
            }
            .buttonStyle(.plain)

            Button(action: {
                isDarkMode.toggle()
            }) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(colorSchemeToggleTitle)
            .accessibilityLabel(Text(colorSchemeToggleTitle))
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var colorSchemeToggleTitle: String {
        isDarkMode ? String(localized: "Switch to Light Mode") : String(localized: "Switch to Dark Mode")
    }
}

struct TabItemView: View {
    let tab: Document
    let isSelected: Bool

    @EnvironmentObject var tabManager: TabManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private let closeButtonSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.fullTitleForWindow)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 60, maxWidth: 180, alignment: .leading)

            Button(action: {
                NotepadDocumentActions.closeTab(tab.id, in: tabManager)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected ? 1 : 0)
            .disabled(!(isHovering || isSelected))
            .frame(width: closeButtonSize, height: closeButtonSize)
            .animation(.easeInOut(duration: 0.15), value: isHovering || isSelected)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.12)
                        : (isHovering ? Color.secondary.opacity(colorScheme == .dark ? 0.15 : 0.08) : .clear)
                )
        )
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .overlay(
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .help(tab.fileURL?.path ?? String(localized: "Unsaved tab"))
    }
}

// EditorView는 별도 파일(EditorView.swift)에 정의됨 (NSTextView 기반)

// MARK: - Status Bar

struct StatusBarView: View {
    let document: Document
    @EnvironmentObject var tabManager: TabManager

    @AppStorage("fontSize") private var fontSize: Double = 14.0

    var body: some View {
        HStack {
            // Real-time from NSTextView selection (G006)
            Text(String(format: String(localized: "status.cursorFormat"), tabManager.cursorLine, tabManager.cursorCol, document.content.count))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            // Right side items with more breathing room
            HStack(spacing: 16) {
                // Zoom level (styled same as encoding)
                Text("\(Int(fontSize / 14.0 * 100))%")
                    .font(.system(size: 11, weight: .medium))

                // Line Ending
                Menu {
                    ForEach(LineEnding.allCases) { le in
                        Button(le.displayName) {
                            tabManager.updateSelectedLineEnding(le)
                        }
                    }
                } label: {
                    Text(document.statusLineEnding)
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .help(String(localized: "Change line ending for this tab (affects next Save)"))

                // Encoding
                Menu {
                    ForEach(TextEncoding.allCases) { enc in
                        Button(enc.displayName) {
                            tabManager.reopenSelectedWithEncoding(enc)
                        }
                    }

                    Divider()

                    ForEach(TextEncoding.allCases) { enc in
                        Button(String(format: String(localized: "Convert to %@"), enc.displayName)) {
                            tabManager.convertSelectedToEncoding(enc)
                        }
                    }
                } label: {
                    Text(document.statusEncoding)
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }
}
