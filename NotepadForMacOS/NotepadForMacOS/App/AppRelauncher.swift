import AppKit

enum AppRelauncher {
    static func confirmAndRelaunch() {
        let alert = NSAlert()
        alert.messageText = String(localized: "settings.language.relaunch")
        alert.informativeText = String(localized: "settings.language.relaunch.message")
        alert.addButton(withTitle: String(localized: "settings.language.relaunch.now"))
        alert.addButton(withTitle: String(localized: "settings.language.relaunch.later"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        relaunchNow()
    }

    static func relaunchNow() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
