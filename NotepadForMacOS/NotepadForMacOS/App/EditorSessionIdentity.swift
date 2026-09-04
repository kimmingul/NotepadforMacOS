import Foundation

/// 편집기 창의 세션 신원을 정한다.
///
/// 세션 디렉터리는 `sessionID`로 갈린다: `nil`은 루트(`Sessions/`)이고, **다음 실행에서
/// 복원되는 세션은 그 루트 하나**다. 나머지는 `Sessions/Windows/<uuid>/`에 들어간다.
///
/// `WindowGroup(for: UUID.self)`가 넘겨주는 값은 `UUID?`이고, UUID를 실제로 넣어주는 곳은
/// New Window 명령뿐이다. 프레임워크가 만든 창은 값이 `nil`이라 루트 세션을 그대로 다시
/// 복원했고(첫 창의 탭 목록이 새 창에 통째로 나타남), 그 뒤로는 두 창이 같은 `session.json`에
/// 번갈아 써서 마지막에 쓴 창이 이겼다. 탭 목록이 사라지고, 저장 성공으로 승격된
/// 쓰기 가능 북마크가 다른 창의 오래된 스냅샷으로 되돌아가 재승인 패널이 다시 뜨는 경로다.
///
/// 그래서 루트 세션은 **프로세스에서 처음 만들어진 창 하나**만 갖는다. 이후의 값 없는 창은
/// 자기 UUID 세션을 받아 서로를 덮어쓰지 않는다.
final class EditorSessionIdentity {
    static let shared = EditorSessionIdentity()

    private var primaryClaimed = false

    /// - Parameter requested: `WindowGroup`이 넘긴 값. New Window는 UUID를, 그 밖의 창은 `nil`.
    /// - Returns: 첫 호출에서 `nil`(루트 세션), 그 다음부터는 새 UUID.
    func resolve(_ requested: UUID?) -> UUID? {
        if let requested { return requested }
        if primaryClaimed { return UUID() }
        primaryClaimed = true
        return nil
    }
}
