import Cocoa
import SwiftUI

/// macOS 앱 라이프사이클 지원.
/// TabManager가 willTerminateNotification을 직접 관찰하여 세션 강제 저장.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // TabManager observer가 forcePersist를 처리함
        print("[AppDelegate] willTerminate — session persist should have run via observer")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Windows 11 Notepad처럼 마지막 탭/창 닫으면 종료 (단일 윈도우 앱 느낌)
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force write immediately
        try? "=== Notepad Menu Debug Started at launch ===\n".write(toFile: logFilePath, atomically: true, encoding: .utf8)
        logToFile("App did finish launching. Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        logToFile("User: \(NSUserName())")
        logToFile("Will scan menus in a moment...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.customizeMenuIcons()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.customizeMenuIcons()
            self?.logToFile("=== Debug scan finished ===")
        }
    }

    private let logFilePath: String = FileManager.default.temporaryDirectory.appendingPathComponent("Notepad_Debug.txt").path

    private func logToFile(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        let url = URL(fileURLWithPath: logFilePath)
        do {
            if FileManager.default.fileExists(atPath: logFilePath) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Last resort: try to create
            try? data.write(to: url, options: .atomic)
        }
    }

    private func customizeMenuIcons() {
        guard let mainMenu = NSApplication.shared.mainMenu else {
            logToFile("ERROR: mainMenu is nil")
            return
        }

        logToFile("Starting menu scan...")

        for menuItem in mainMenu.items {
            let parentTitle = menuItem.title
            let isViewMenu = parentTitle == "View" || parentTitle == "보기" || parentTitle.lowercased().contains("view")

            guard let submenu = menuItem.submenu else { continue }

            if isViewMenu {
                logToFile("Found View menu: '\(parentTitle)'")
                // View 메뉴 전체 구조를 파일에 덤프
                for item in submenu.items {
                    logToFile("  VIEW ITEM: '\(item.title)'")
                    if let sub = item.submenu {
                        for subItem in sub.items {
                            logToFile("    SUB: '\(subItem.title)'")
                        }
                    }
                }
            }

            customizeItems(in: submenu, parentTitle: parentTitle)
        }

        logToFile("Menu scan completed")
    }

    private func customizeItems(in menu: NSMenu, parentTitle: String) {
        for item in menu.items {
            let title = item.title
            let isViewParent = parentTitle == "View" || parentTitle == "보기"

            if isViewParent {
                if title == "Show Tab Bar" || title == "탭 막대 보기" {
                    item.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
                    logToFile("✅ Set icon for: '\(title)'")
                } else if title == "Hide Tab Bar" || title == "탭 막대 가리기" {
                    item.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
                    logToFile("✅ Set icon for: '\(title)'")
                } else if title == "Show All Tabs" || title == "모든 탭 보기" || title.contains("모든 탭") || title.lowercased().contains("all tabs") {
                    item.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
                    logToFile("✅ Set icon for: '\(title)'")
                }
            }

            if let subsubmenu = item.submenu {
                customizeItems(in: subsubmenu, parentTitle: title)
            }
        }
    }
}
