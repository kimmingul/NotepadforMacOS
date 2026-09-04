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

    /// 문서 열기 이벤트를 프레임워크보다 먼저 받는다. 실행 중에 전달되는 문서(콜드 런치)에
    /// SwiftUI가 창을 하나 더 만드는 것을 막는다. 자세한 이유는 `ExternalOpenEventHandler` 참고.
    func applicationWillFinishLaunching(_ notification: Notification) {
        ExternalOpenEventHandler.shared.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ExternalOpenEventHandler.shared.install()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppDelegate.isTerminating = true
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// 평소에는 `ExternalOpenEventHandler`가 문서 열기 이벤트를 먼저 받아 이 메서드는 호출되지
    /// 않는다. AppKit이 어떤 경로로든 자기 핸들러를 되살려 여기로 오더라도 같은 큐에 넣는다.
    func application(_ application: NSApplication, open urls: [URL]) {
        ExternalDocumentOpener.enqueue(urls)
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
