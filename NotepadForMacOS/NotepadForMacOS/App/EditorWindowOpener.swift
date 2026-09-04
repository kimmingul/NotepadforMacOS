import SwiftUI

/// 편집기 창이 하나도 없을 때 창을 새로 여는 통로.
///
/// 두 가지 상황이 있다.
///   - **실행 직후, 아직 창이 하나도 없음.** 문서로 콜드 런치되면 SwiftUI는 기본 창을 만들지
///     않고 문서 열기 이벤트가 창을 만들기를 기대한다. 그 이벤트를 우리가 가로채므로
///     (`ExternalOpenEventHandler`) 아무도 창을 만들지 않는다 — 실측: 프로세스는 살아 있고 창 0개.
///     이때는 SwiftUI의 창 열기 액션도 아직 없다(환경에서만 얻을 수 있다). 앱 자신에게
///     reopen을 보내면 SwiftUI가 Dock 아이콘 클릭 때와 같은 경로로 기본 창을 만든다.
///   - **실행 중, 편집기 창이 0개.** 설정 창만 남아 앱이 살아 있는 드문 상황. 창이 살아 있는
///     동안 붙잡아 둔 `\.openWindow` 액션으로 연다.
final class EditorWindowOpener {
    static let shared = EditorWindowOpener()

    private var action: OpenWindowAction?
    /// 창이 뜨기까지의 중복 요청을 한 번으로 묶는다(파일 여러 개를 한꺼번에 열 때).
    private var requestInFlight = false

    func adopt(_ action: OpenWindowAction) {
        self.action = action
    }

    func noteWindowAppeared() {
        requestInFlight = false
    }

    func openWindow() {
        guard !requestInFlight else { return }
        requestInFlight = true

        if let action {
            action(id: "editor", value: UUID())
            return
        }
        // 실행 초기. 평소 실행이면 SwiftUI가 곧 기본 창을 만들므로, 잠깐 기다렸다가 그래도
        // 알려진 창이 없을 때만 reopen을 보낸다(창이 둘 생기지 않게).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard EditorWindowRegistry.shared.isEmpty else {
                self?.requestInFlight = false
                return
            }
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
            // 창이 뜨면 noteWindowAppeared()가 풀어 준다. 어떤 이유로 창이 안 뜨면 다음 요청이
            // 다시 시도할 수 있게 잠시 뒤 풀어 둔다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.requestInFlight = false
            }
        }
    }
}
