import Foundation
import os

/// 앱 샌드박스에서 사용자가 선택한 파일에 지속적으로 접근하기 위한 보안 스코프 북마크 도우미.
///
/// - 문서를 **열 때**는 `makeBookmark(for:readOnly: true)`로 읽기 전용 북마크를 만든다.
/// - 실제 **저장이 성공한 뒤에만** `readOnly: false`로 쓰기 가능 북마크로 승급한다.
/// - 재실행 후에는 `access(_:bookmark:)`로 북마크에서 URL을 해석하고 보안 스코프 접근을
///   연 상태에서만 읽기/쓰기를 수행한 뒤 접근을 해제한다.
nonisolated enum SecurityScopedFile {

    /// Resolves a security-scoped bookmark. If the bookmark is stale, a replacement is returned.
    ///
    /// `readOnly`는 원본 북마크가 어떤 권한으로 만들어졌는지를 알려준다. stale 갱신 시 같은
    /// 권한으로 다시 만들어야 하며, 특히 읽기 전용 북마크를 쓰기 가능으로 넓히면 안 된다
    /// (넓히는 순간 `open(O_RDWR)`가 일어나 문서에 격리 속성이 전파된다).
    static func refreshBookmark(
        _ bookmark: Data?,
        fallbackURL: URL? = nil,
        readOnly: Bool = true
    ) -> (url: URL?, bookmark: Data?) {
        guard let bookmark else { return (fallbackURL, nil) }
        var isStale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return (fallbackURL, bookmark)
        }
        if isStale, let fresh = makeBookmark(for: resolved, readOnly: readOnly) {
            return (resolved, fresh)
        }
        return (resolved, bookmark)
    }

    /// 가능하면 북마크에서 URL을 해석해 보안 스코프 접근을 연 뒤 `body`를 실행하고,
    /// 작업이 끝나면 접근을 해제한다. 북마크가 없으면(같은 실행 세션에서 막 선택한 파일 등)
    /// 전달된 `url`을 그대로 사용한다. stale이면 새 북마크 데이터를 반환한다.
    @discardableResult
    static func access(
        _ url: URL,
        bookmark: Data?,
        readOnly: Bool = true,
        _ body: (URL) -> Void
    ) -> Data? {
        let refreshed = refreshBookmark(bookmark, fallbackURL: url, readOnly: readOnly)
        let target = refreshed.url ?? url
        let started = target.startAccessingSecurityScopedResource()
        defer { if started { target.stopAccessingSecurityScopedResource() } }
        body(target)
        return refreshed.bookmark == bookmark ? nil : refreshed.bookmark
    }

    /// 현재 접근 권한이 있는 URL(파일 패널이나 Launch Services가 막 넘긴 URL 등)에 대해
    /// 재실행 후에도 쓸 수 있는 앱 스코프 보안 북마크를 생성한다.
    ///
    /// `readOnly`가 true면 `.securityScopeAllowOnlyReadAccess`를 붙여 **읽기 전용** 토큰을
    /// 요청한다. 이 구분이 중요한 이유: 쓰기 가능한 스코프 토큰을 만들려면 Foundation이 대상
    /// 파일을 `open(O_RDWR)`로 열어야 하고, App Sandbox는 그 쓰기 의도 open에
    /// `com.apple.quarantine`을 전파한다. 내용을 안 바꾸므로 mtime은 그대로인데 격리만 붙어,
    /// 이후 Finder에서 그 문서를 열 때마다 Gatekeeper 검사 대화상자가 뜨게 된다.
    /// 문서를 여는 시점엔 읽기 권한만 필요하므로 읽기 전용으로 만들고, 쓰기 토큰은 실제 저장이
    /// 성공한 뒤에만 만든다.
    static func makeBookmark(for url: URL, readOnly: Bool) -> Data? {
        var options: URL.BookmarkCreationOptions = [.withSecurityScope]
        if readOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        do {
            return try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            let nsError = error as NSError
            Logger.security.error(
                """
                bookmarkData failed: domain=\(nsError.domain, privacy: .public) \
                code=\(nsError.code, privacy: .public) readOnly=\(readOnly, privacy: .public) \
                underlying=\(String(describing: nsError.userInfo[NSUnderlyingErrorKey]), privacy: .public) \
                desc=\(nsError.localizedDescription, privacy: .public)
                """
            )
            return nil
        }
    }
}

extension Logger {
    /// 샌드박스 권한·북마크 문제 진단용. Console.app 또는
    /// `log show --predicate 'subsystem == "com.nanumspace.mgkim.NotepadForMacOS"'`로 볼 수 있다.
    static let security = Logger(
        subsystem: "com.nanumspace.mgkim.NotepadForMacOS",
        category: "security-scope"
    )
}
