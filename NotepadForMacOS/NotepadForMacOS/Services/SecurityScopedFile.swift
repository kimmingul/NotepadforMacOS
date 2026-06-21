import Foundation

/// 앱 샌드박스에서 사용자가 선택한 파일에 지속적으로 접근하기 위한 보안 스코프 북마크 도우미.
///
/// - 파일을 열거나 저장할 때 `makeBookmark(for:)`로 앱 스코프 북마크를 만들어 세션에 저장한다.
/// - 재실행 후에는 `access(_:bookmark:)`로 북마크에서 URL을 해석하고 보안 스코프 접근을
///   연 상태에서만 읽기/쓰기를 수행한 뒤 접근을 해제한다.
enum SecurityScopedFile {

    /// 가능하면 북마크에서 URL을 해석해 보안 스코프 접근을 연 뒤 `body`를 실행하고,
    /// 작업이 끝나면 접근을 해제한다. 북마크가 없으면(같은 실행 세션에서 막 선택한 파일 등)
    /// 전달된 `url`을 그대로 사용한다.
    static func access(_ url: URL, bookmark: Data?, _ body: (URL) -> Void) {
        var target = url
        if let bookmark {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                target = resolved
            }
        }
        let started = target.startAccessingSecurityScopedResource()
        defer { if started { target.stopAccessingSecurityScopedResource() } }
        body(target)
    }

    /// 현재 접근 권한이 있는 URL(파일 패널이 막 반환한 URL 등)에 대해
    /// 재실행 후에도 쓸 수 있는 앱 스코프 보안 북마크를 생성한다.
    static func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
