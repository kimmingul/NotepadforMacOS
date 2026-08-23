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
        var types: [UTType] = [.plainText, .text, .json, .xml, .html]
        if let markdown = UTType(filenameExtension: "md") { types.append(markdown) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        if let log = UTType(filenameExtension: "log") { types.append(log) }
        panel.allowedContentTypes = types


        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return tabManager.openFile(url: url, preferredEncoding: preferredEncoding)
    }

    @discardableResult
    static func saveCurrentTab(in tabManager: TabManager) -> Bool {
        guard let id = tabManager.selectedTabID, let tab = tabManager.selectedTab else { return false }

        if tab.fileURL != nil {
            // 복원 시 원본을 읽지 못한 탭(loadError)을 빈 내용으로 덮어쓰기 전 확인.
            if tab.loadError, !confirmOverwriteUnreadable(tab) {
                return false
            }
            return apply(tabManager.saveCurrentTab(), for: id, in: tabManager)
        }

        return saveAsCurrentTab(in: tabManager)
    }

    /// 저장 결과를 UI 동작으로 옮긴다.
    ///
    /// `.notAuthorized`는 문서를 열 때 읽기 권한만 확보하기 때문에(쓰기 가능 북마크를 만들면
    /// 문서에 격리 속성이 전파된다) 재실행 후 첫 저장에서 발생할 수 있다. 이때는 같은 경로를
    /// 기본값으로 저장 패널을 띄운다. 사용자가 한 번 승인하면 쓰기 가능 북마크가 만들어져
    /// 이후 저장은 패널 없이 바로 진행된다.
    @discardableResult
    private static func apply(_ outcome: SaveOutcome, for id: UUID, in tabManager: TabManager) -> Bool {
        switch outcome {
        case .saved:
            return true
        case .noTarget, .notAuthorized:
            return saveAsTab(id, in: tabManager)
        case .encodingFailed, .writeFailed:
            if let document = tabManager.document(with: id) {
                showSaveFailedAlert(for: document)
            }
            return false
        }
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
        // 이미 경로가 있는 문서(쓰기 권한 재승인)는 원래 위치와 이름을 기본값으로 보여준다.
        if let existing = document.fileURL {
            panel.directoryURL = existing.deletingLastPathComponent()
            panel.nameFieldStringValue = existing.lastPathComponent
        }

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
        let outcome = tabManager.saveTab(id, to: url, encoding: encoding)

        if outcome != .saved {
            showSaveFailedAlert(for: document)
        }

        return outcome == .saved
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

            let saved = apply(tabManager.saveTab(id), for: id, in: tabManager)
            if saved {
                tabManager.closeTab(id)
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

    static func grantMarkdownFolderAccess(for id: UUID, in tabManager: TabManager) {
        guard let doc = tabManager.document(with: id), let fileURL = doc.fileURL else { return }
        let folder = fileURL.deletingLastPathComponent()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.prompt = String(localized: "markdown.folderAllow")
        panel.message = String(localized: "markdown.folder.help")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // 인접 이미지를 읽기만 하므로 폴더 북마크도 읽기 전용으로 만든다.
        tabManager.setDirectoryBookmark(SecurityScopedFile.makeBookmark(for: url, readOnly: true), for: id)
    }

    private enum UnsavedCloseChoice {
        case save
        case discard
        case cancel
    }
}
