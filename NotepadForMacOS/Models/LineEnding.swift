import Foundation

enum LineEnding: String, CaseIterable, Codable, Identifiable {
    case lf = "LF"
    case crlf = "CRLF"
    case cr = "CR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lf: return String(localized: "lineEnding.lf")
        case .crlf: return String(localized: "lineEnding.crlf")
        case .cr: return String(localized: "lineEnding.cr")
        }
    }

    /// 현재 content에 적용된 줄바꿈을 표준화하거나, 저장용 변환
    var stringRepresentation: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    /// 데이터에서 줄바꿈 자동 감지
    static func detect(in text: String) -> LineEnding {
        if text.contains("\r\n") { return .crlf }
        if text.contains("\r") && !text.contains("\n") { return .cr }
        return .lf
    }

    /// 문자열의 줄바꿈을 이 LineEnding으로 정규화
    func normalize(_ text: String) -> String {
        // 기존 모든 줄바꿈을 \n 으로 통일 후 원하는 것으로 변환
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.replacingOccurrences(of: "\n", with: stringRepresentation)
    }
}
