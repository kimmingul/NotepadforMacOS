import Cocoa

/// 앱 라이프사이클 지원.
/// - Windows 11 Notepad처럼 마지막 창을 닫으면 앱을 종료한다.
/// - 세션 강제 저장은 `TabManager`가 `willTerminateNotification`을 직접 관찰해 처리한다.
/// - `isTerminating`은 "앱 종료 중"과 "창만 닫음"을 구분해, 종료 시에는 세션을 보존(복원용)하고
///   사용자가 창만 닫았을 때는 해당 창의 세션을 정리하기 위한 신호다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 앱이 종료 절차에 들어갔는지 여부. 창 닫힘(onDisappear)보다 먼저 설정되도록
    /// `applicationShouldTerminate`에서 켠다.
    static private(set) var isTerminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppDelegate.isTerminating = true
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// 진행 중인 입력기(IME) 조합 텍스트를 강제로 커밋하기 위한 도우미.
/// 한글/CJK 조합 중에 창을 닫거나 앱을 종료하면 조합 중 텍스트가 모델에 반영되지 않을 수 있으므로,
/// 세션을 저장하기 직전에 호출해 first responder를 잠시 해제했다가 복원한다.
enum NotepadTextInput {
    static func commitActiveComposition() {
        for window in NSApp.windows {
            guard let textView = window.firstResponder as? NSTextView, textView.hasMarkedText() else { continue }
            window.makeFirstResponder(nil)   // 조합 텍스트 커밋
            window.makeFirstResponder(textView)
        }
    }
}
