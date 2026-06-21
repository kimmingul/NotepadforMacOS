import Foundation
import SwiftUI

/// 단일 탭/문서 모델
/// Windows 11 Notepad처럼 파일 경로 + 작업 중인 내용(content) + 인코딩/줄바꿈 상태를 가짐.
///
/// 영속화는 `SessionStore`가 담당한다(파일 경로 대신 보안 스코프 북마크를 저장하므로
/// 이 타입은 `Codable`을 직접 채택하지 않는다).
struct Document: Identifiable, Equatable {
    var id = UUID()
    var fileURL: URL?

    /// 샌드박스에서 재실행 후에도 `fileURL`에 접근하기 위한 앱 스코프 보안 북마크.
    /// 파일을 열거나 저장할 때 생성하며, 세션에 함께 저장된다.
    var securityScopedBookmark: Data?

    /// 실제 편집 중인 텍스트 (항상 Unicode String)
    var content: String

    var encoding: TextEncoding
    var lineEnding: LineEnding

    /// 저장되지 않은 변경이 있는지 (Windows처럼 * 표시)
    var isDirty: Bool = false

    /// 세션 복원을 위한 생성 타임스탬프 (정렬용)
    var createdAt: Date = Date()

    /// 복원 시 원본 파일을 읽지 못했음을 나타내는 일시 플래그(영속화하지 않음).
    /// true이면 화면의 빈 내용으로 원본을 덮어쓰지 않도록 저장 경로에서 사용자에게 확인한다.
    var loadError: Bool = false

    // MARK: - Derived

    var displayTitle: String {
        if let url = fileURL {
            return url.lastPathComponent
        } else {
            return String(localized: "Untitled")
        }
    }

    var fullTitleForWindow: String {
        isDirty ? "\(displayTitle)*" : displayTitle
    }

    var statusEncoding: String {
        encoding.displayName
    }

    var statusLineEnding: String {
        lineEnding.rawValue
    }

    // MARK: - Init

    init(fileURL: URL? = nil,
         securityScopedBookmark: Data? = nil,
         content: String = "",
         encoding: TextEncoding = .utf8,
         lineEnding: LineEnding = .lf,
         isDirty: Bool = false) {
        self.fileURL = fileURL
        self.securityScopedBookmark = securityScopedBookmark
        self.content = content
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
    }

    // MARK: - Helpers

    /// 파일에서 다시 읽어서 content 교체 (Reopen with encoding 용)
    mutating func reloadFromDisk(using newEncoding: TextEncoding) -> Bool {
        guard let url = fileURL else { return false }
        var didReload = false
        SecurityScopedFile.access(url, bookmark: securityScopedBookmark) { resolvedURL in
            guard let data = try? Data(contentsOf: resolvedURL),
                  let newContent = newEncoding.decode(data: data) else { return }
            content = newContent
            encoding = newEncoding
            lineEnding = LineEnding.detect(in: newContent)
            isDirty = false   // 디스크와 동기화된 상태로 간주
            loadError = false
            didReload = true
        }
        return didReload
    }

    // 동등성은 id 기준 (탭 식별용). 내용 변경 감지는 @Published tabs 발행으로 처리.
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}
