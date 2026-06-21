import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 파일 열기/저장/닫기 등 패널·알림이 필요한 문서 동작 모음.
/// 뷰(메뉴 명령)에서 호출하며, AppKit 패널/알림을 직접 다룬다.
enum NotepadDocumentActions {
    @discardableResult
    static func openFileDialog(in tabManager: TabManager, preferredEncoding: TextEncoding? = nil) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text]

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return tabManager.openFile(url: url, preferredEncoding: preferredEncoding)
    }

    @discardableResult
    static func saveCurrentTab(in tabManager: TabManager) -> Bool {
        guard let tab = tabManager.selectedTab else { return false }

        if tab.fileURL != nil {
            // 복원 시 원본을 읽지 못한 탭(loadError)을 빈 내용으로 덮어쓰기 전 확인.
            if tab.loadError, !confirmOverwriteUnreadable(tab) {
                return false
            }
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

    /// 복원 시 원본 파일을 읽지 못해 빈 내용으로 표시된 탭을 저장하려 할 때 확인.
    /// 사용자가 명시적으로 동의해야만 원본을 덮어쓴다(무음 데이터 손실 방지).
    private static func confirmOverwriteUnreadable(_ document: Document) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: String(localized: "overwriteUnreadable.message"), document.displayTitle)
        alert.informativeText = String(localized: "overwriteUnreadable.informative")
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private enum UnsavedCloseChoice {
        case save
        case discard
        case cancel
    }
}
