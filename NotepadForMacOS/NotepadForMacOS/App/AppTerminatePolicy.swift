import Foundation

/// Finder “Open With” / default-handler launches deliver the file before the
/// first window exists. Quitting on “last window closed” in that gap looks like
/// Gatekeeper: the app starts, dies, and macOS shows a blocked-open dialog.
enum AppTerminatePolicy {
    static func shouldQuitAfterLastWindow(hasPendingDocuments: Bool, launchSettled: Bool) -> Bool {
        launchSettled && !hasPendingDocuments
    }
}
