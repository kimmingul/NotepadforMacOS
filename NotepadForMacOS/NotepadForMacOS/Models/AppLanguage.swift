import Foundation

/// In-app UI language. `system` follows the Mac; anything else pins an lproj.
enum AppLanguage: String, CaseIterable, Identifiable, Equatable {
    case system = "system"
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case russian = "ru"
    case vietnamese = "vi"
    case indonesian = "id"
    case thai = "th"
    case polish = "pl"
    case dutch = "nl"

    var id: String { rawValue }

    /// BCP-47 / lproj folder name. `nil` means follow macOS.
    var bcp47: String? {
        self == .system ? nil : rawValue
    }

    /// Native name so the picker is findable regardless of the current UI language.
    var nativeDisplayName: String {
        switch self {
        case .system: return String(localized: "settings.language.system")
        case .english: return "English"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portugueseBrazil: return "Português (Brasil)"
        case .italian: return "Italiano"
        case .russian: return "Русский"
        case .vietnamese: return "Tiếng Việt"
        case .indonesian: return "Bahasa Indonesia"
        case .thai: return "ไทย"
        case .polish: return "Polski"
        case .dutch: return "Nederlands"
        }
    }

    static var shippedLocalizations: [String] {
        allCases.compactMap(\.bcp47)
    }
}

enum AppLanguagePreferences {
    static let languageKey = "appLanguage"
    static let appleLanguagesKey = "AppleLanguages"

    static func parse(_ raw: String?) -> AppLanguage {
        guard let raw, let language = AppLanguage(rawValue: raw) else { return .system }
        return language
    }

    static func apply(_ language: AppLanguage, to defaults: UserDefaults) {
        defaults.set(language.rawValue, forKey: languageKey)
        if let code = language.bcp47 {
            defaults.set([code], forKey: appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: appleLanguagesKey)
        }
    }

    static func applyStored(to defaults: UserDefaults = .standard) {
        apply(parse(defaults.string(forKey: languageKey)), to: defaults)
    }

    /// Picks the lproj that will actually load.
    static func resolvedLocalization(
        language: AppLanguage,
        available: [String] = AppLanguage.shippedLocalizations,
        preferredFromSystem: [String] = Locale.preferredLanguages
    ) -> String {
        if let code = language.bcp47, available.contains(code) {
            return code
        }
        return Bundle.preferredLocalizations(
            from: available,
            forPreferences: preferredFromSystem
        ).first ?? "en"
    }
}
