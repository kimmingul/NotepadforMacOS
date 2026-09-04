import SwiftUI

/// 편집기 창이 하나도 없을 때 창을 새로 여는 통로.
///
/// 창을 여는 SwiftUI 액션은 환경(`\.openWindow`)에서만 얻을 수 있으므로, 창이 살아 있는 동안
/// 붙잡아 둔다. 필요한 순간은 하나다: 문서 열기 이벤트를 우리가 직접 받는 상태
/// (`ExternalOpenEventHandler`)에서 편집기 창이 0개인 경우. 설정 창만 열려 있어 앱이 살아
/// 있는 드문 상황이며, 이때 파일을 열면 창이 없어 아무 일도 일어나지 않는다.
///
/// 핸들러는 첫 창이 뜬 뒤에 설치되므로, 그 시점에는 이 액션이 이미 확보돼 있다.
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
        guard let action, !requestInFlight else { return }
        requestInFlight = true
        action(id: "editor", value: UUID())
    }
}
