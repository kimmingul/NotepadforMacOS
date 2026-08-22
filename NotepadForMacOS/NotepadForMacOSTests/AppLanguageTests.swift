import XCTest
@testable import Notepad

final class AppLanguageTests: XCTestCase {

    func testParse_missingOrUnknownIsSystem() {
        XCTAssertEqual(AppLanguagePreferences.parse(nil), .system)
        XCTAssertEqual(AppLanguagePreferences.parse(""), .system)
        XCTAssertEqual(AppLanguagePreferences.parse("xx"), .system)
        XCTAssertEqual(AppLanguagePreferences.parse("en"), .english)
        XCTAssertEqual(AppLanguagePreferences.parse("zh-Hans"), .chineseSimplified)
        XCTAssertEqual(AppLanguagePreferences.parse("pt-BR"), .portugueseBrazil)
    }

    func testResolve_explicitLanguageWins() {
        let resolved = AppLanguagePreferences.resolvedLocalization(
            language: .korean,
            available: ["en", "ko", "ja"],
            preferredFromSystem: ["en-US", "en"]
        )
        XCTAssertEqual(resolved, "ko")
    }

    func testResolve_systemUsesMacPreferred() {
        let resolved = AppLanguagePreferences.resolvedLocalization(
            language: .system,
            available: ["en", "ko", "ja", "fr"],
            preferredFromSystem: ["fr-CA", "en"]
        )
        XCTAssertEqual(resolved, "fr")
    }

    func testResolve_systemFallsBackToEnglish() {
        let resolved = AppLanguagePreferences.resolvedLocalization(
            language: .system,
            available: ["en", "ko"],
            preferredFromSystem: ["sv", "fi"]
        )
        XCTAssertEqual(resolved, "en")
    }

    func testResolve_explicitUnavailableFallsBackToSystemMatch() {
        let resolved = AppLanguagePreferences.resolvedLocalization(
            language: .thai,
            available: ["en", "ja"],
            preferredFromSystem: ["ja-JP"]
        )
        XCTAssertEqual(resolved, "ja")
    }

    func testApply_systemRemovesAppleLanguages() {
        let suite = "AppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        AppLanguagePreferences.apply(.japanese, to: defaults)
        XCTAssertEqual(defaults.string(forKey: AppLanguagePreferences.languageKey), "ja")
        XCTAssertEqual(defaults.stringArray(forKey: AppLanguagePreferences.appleLanguagesKey), ["ja"])

        defaults.synchronize()
        AppLanguagePreferences.apply(.system, to: defaults)
        XCTAssertEqual(defaults.string(forKey: AppLanguagePreferences.languageKey), "system")
        XCTAssertNil(suiteValue(defaults, suite: suite, key: AppLanguagePreferences.appleLanguagesKey))
    }

    func testApplyStored_unknownDefaultsToSystem() {
        let suite = "AppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("nope", forKey: AppLanguagePreferences.languageKey)
        defaults.set(["de"], forKey: AppLanguagePreferences.appleLanguagesKey)

        AppLanguagePreferences.applyStored(to: defaults)
        defaults.synchronize()
        XCTAssertEqual(defaults.string(forKey: AppLanguagePreferences.languageKey), "system")
        XCTAssertNil(suiteValue(defaults, suite: suite, key: AppLanguagePreferences.appleLanguagesKey))
    }

    func testSupportedCodesMatchShippedLocales() {
        let codes = AppLanguage.shippedLocalizations
        XCTAssertTrue(codes.contains("en"))
        XCTAssertTrue(codes.contains("ko"))
        XCTAssertTrue(codes.contains("zh-Hans"))
        XCTAssertTrue(codes.contains("pt-BR"))
        XCTAssertFalse(codes.contains("system"))
        XCTAssertEqual(codes.count, AppLanguage.allCases.count - 1)
    }

    /// UserDefaults falls back to NSGlobalDomain (system AppleLanguages). Assert the suite only.
    private func suiteValue(_ defaults: UserDefaults, suite: String, key: String) -> Any? {
        defaults.persistentDomain(forName: suite)?[key]
    }
}

