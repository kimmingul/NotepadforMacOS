import Foundation

/// Windows 11 Notepad 스타일 + 한국어 지원 인코딩
enum TextEncoding: String, CaseIterable, Codable, Identifiable, Sendable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8 with BOM"
    case eucKR = "EUC-KR"
    case utf16LE = "UTF-16 LE"
    case utf16BE = "UTF-16 BE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .utf8: return String(localized: "encoding.utf8")
        case .utf8BOM: return String(localized: "encoding.utf8BOM")
        case .eucKR: return String(localized: "encoding.eucKR")
        case .utf16LE: return String(localized: "encoding.utf16LE")
        case .utf16BE: return String(localized: "encoding.utf16BE")
        }
    }

    /// Foundation에서 사용 가능한 encoding (BOM 처리는 별도)
    var foundationEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM:
            return .utf8
        case .eucKR:
            // EUC-KR 지원 (macOS에서 잘 동작)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        case .utf16LE:
            return .utf16LittleEndian
        case .utf16BE:
            return .utf16BigEndian
        }
    }

    /// 파일에서 데이터를 읽어 지정 인코딩으로 디코드
    func decode(data: Data) -> String? {
        if self == .utf8BOM {
            // BOM 제거 후 UTF-8 시도
            let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
            if data.starts(with: bom) {
                let contentData = data.dropFirst(3)
                return String(data: contentData, encoding: .utf8)
            }
            return String(data: data, encoding: .utf8)
        }
        return String(data: data, encoding: foundationEncoding)
    }

    /// 현재 문자열을 지정 인코딩의 Data로 인코딩 (BOM 포함 처리)
    func encode(_ string: String) -> Data? {
        guard let data = string.data(using: foundationEncoding) else { return nil }

        if self == .utf8BOM {
            var bomData = Data([0xEF, 0xBB, 0xBF])
            bomData.append(data)
            return bomData
        }
        return data
    }

    /// 손실 없이 이 인코딩으로 표현할 수 있는 문자열인지 검사.
    /// (예: 이모지/한자를 EUC-KR로 변환하려는 경우 false)
    func canEncode(_ string: String) -> Bool {
        string.data(using: foundationEncoding, allowLossyConversion: false) != nil
    }

    /// 파일 확장자나 내용 기반 간단 자동 감지 힌트 (MVP에서는 호출 시 옵션으로 사용)
    static func detect(from data: Data, suggested: TextEncoding? = nil) -> TextEncoding {
        if suggested != nil { return suggested! }

        // BOM 체크
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8BOM
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return .utf16LE
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return .utf16BE
        }

        // UTF-8 유효성 우선 시도
        if let _ = String(data: data, encoding: .utf8) {
            return .utf8
        }

        // EUC-KR 시도 (한국어 파일 흔한 경우)
        let euc = TextEncoding.eucKR
        if let _ = String(data: data, encoding: euc.foundationEncoding) {
            return .eucKR
        }

        return .utf8
    }
}
