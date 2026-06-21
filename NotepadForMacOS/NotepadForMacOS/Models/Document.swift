import Foundation
import SwiftUI

/// 단일 탭/문서 모델
/// Windows 11 Notepad처럼 파일 경로 + 작업 중인 내용(content) + 인코딩/줄바꿈 상태를 가짐
struct Document: Identifiable, Codable, Equatable {
    var id = UUID()
    var fileURL: URL?

    /// 실제 편집 중인 텍스트 (항상 Unicode String)
    var content: String

    var encoding: TextEncoding
    var lineEnding: LineEnding

    /// 저장되지 않은 변경이 있는지 (Windows처럼 * 표시)
    var isDirty: Bool = false

    /// 세션 복원을 위한 생성 타임스탬프 (정렬용)
    var createdAt: Date = Date()

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
         content: String = "",
         encoding: TextEncoding = .utf8,
         lineEnding: LineEnding = .lf,
         isDirty: Bool = false) {
        self.fileURL = fileURL
        self.content = content
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
    }

    // Codable 수동 구현 (URL은 bookmark 등 처리 필요하지만 간단히 path 저장)
    enum CodingKeys: String, CodingKey {
        case id, filePath, content, encoding, lineEnding, isDirty, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let path = try container.decodeIfPresent(String.self, forKey: .filePath) {
            fileURL = URL(fileURLWithPath: path)
        }
        content = try container.decode(String.self, forKey: .content)
        encoding = try container.decode(TextEncoding.self, forKey: .encoding)
        lineEnding = try container.decode(LineEnding.self, forKey: .lineEnding)
        isDirty = try container.decode(Bool.self, forKey: .isDirty)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileURL?.path, forKey: .filePath)
        try container.encode(content, forKey: .content)
        try container.encode(encoding, forKey: .encoding)
        try container.encode(lineEnding, forKey: .lineEnding)
        try container.encode(isDirty, forKey: .isDirty)
        try container.encode(createdAt, forKey: .createdAt)
    }

    // MARK: - Helpers

    /// 파일에서 다시 읽어서 content 교체 (Reopen with encoding 용)
    mutating func reloadFromDisk(using newEncoding: TextEncoding) -> Bool {
        guard let url = fileURL else { return false }
        do {
            let data = try Data(contentsOf: url)
            let detected = TextEncoding.detect(from: data, suggested: newEncoding)
            if let newContent = detected.decode(data: data) {
                content = newContent
                encoding = newEncoding
                lineEnding = LineEnding.detect(in: newContent)
                isDirty = false   // 디스크와 동기화된 상태로 간주 (사용자 의도에 따라 dirty 유지 가능)
                return true
            }
        } catch {
            print("Reload failed: \(error)")
        }
        return false
    }

    /// 현재 content를 주어진 인코딩으로 변환 시도 (Convert)
    mutating func convertToEncoding(_ newEncoding: TextEncoding) {
        // 간단 구현: 인코딩 플래그만 변경. 실제 변환은 저장 시 수행.
        // 필요시 여기서 roundtrip encode/decode로 시뮬레이션 가능.
        encoding = newEncoding
        isDirty = true
    }

    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}
