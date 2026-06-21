import Cocoa

/// 앱 라이프사이클 지원.
/// - Windows 11 Notepad처럼 마지막 창을 닫으면 앱을 종료한다.
/// - 세션 강제 저장은 `TabManager`가 `willTerminateNotification`을 직접 관찰해 처리한다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
