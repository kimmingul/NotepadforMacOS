import Foundation
import Combine

enum MarkdownPreviewLayout: String, Equatable {
    case hidden
    case side
    case full
}

/// Window-scoped preview chrome. Remote-image allow is per tab and dies with the tab.
@MainActor
final class MarkdownPreviewController: ObservableObject {
    @Published var layout: MarkdownPreviewLayout = .hidden
    @Published private(set) var remoteAllowedTabIDs: Set<UUID> = []

    private var layoutBeforeFull: MarkdownPreviewLayout = .hidden

    var isVisible: Bool { layout != .hidden }

    func toggleSide() {
        layout = (layout == .side) ? .hidden : .side
    }

    /// Status/tab chrome: show side preview or hide whatever is open, including full screen.
    func toggleChrome() {
        layout = (layout == .hidden) ? .side : .hidden
    }


    func toggleFull() {
        if layout == .full {
            layout = layoutBeforeFull == .full ? .hidden : layoutBeforeFull
        } else {
            layoutBeforeFull = layout
            layout = .full
        }
    }

    func exitFull() {
        guard layout == .full else { return }
        layout = layoutBeforeFull == .full ? .hidden : layoutBeforeFull
    }

    func allowsRemoteImages(for tabID: UUID) -> Bool {
        remoteAllowedTabIDs.contains(tabID)
    }

    func setAllowsRemoteImages(_ allowed: Bool, for tabID: UUID) {
        if allowed {
            remoteAllowedTabIDs.insert(tabID)
        } else {
            remoteAllowedTabIDs.remove(tabID)
        }
    }

    func retainRemoteAllows(forOpenTabs ids: [UUID]) {
        let live = Set(ids)
        remoteAllowedTabIDs = remoteAllowedTabIDs.intersection(live)
    }
}
