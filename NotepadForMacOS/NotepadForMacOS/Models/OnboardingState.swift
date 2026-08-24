import Foundation
import AppKit
import Combine

// MARK: - Auto-present once per launch

/// Ensures Welcome / What's New auto-present only once per app launch (multi-window safe).
enum OnboardingCoordinator {
    private static var didAutoPresentThisLaunch = false

    /// Returns true only for the first caller this process lifetime.
    static func claimAutoPresent() -> Bool {
        if didAutoPresentThisLaunch { return false }
        didAutoPresentThisLaunch = true
        return true
    }

    /// Test helper: allow re-claiming in unit tests.
    static func resetForTests() {
        didAutoPresentThisLaunch = false
    }
}

// MARK: - Shared sheet presentation (multi-window + Settings-safe)

/// App-level owner for Welcome / What's New sheets.
/// Editor windows claim presentation; Settings/Help only request — they never need to be key.
@MainActor
final class OnboardingPresenter: ObservableObject {
    static let shared = OnboardingPresenter()

    enum Sheet: Equatable {
        case welcome
        case whatsNew
    }

    @Published private(set) var activeSheet: Sheet?

    /// Window that successfully claimed the current sheet (multi-window safe).
    private var presentationOwnerID: UUID?

    private init() {}

    /// Request a sheet. Any editor window may claim it next.
    func request(_ sheet: Sheet) {
        activeSheet = sheet
        presentationOwnerID = nil
    }

    /// Claim the pending sheet for this editor window. Returns the sheet only for the owner.
    func claim(ownerID: UUID) -> Sheet? {
        guard let sheet = activeSheet else { return nil }
        if let owner = presentationOwnerID, owner != ownerID {
            return nil
        }
        presentationOwnerID = ownerID
        return sheet
    }

    func dismiss(ownerID: UUID) {
        guard presentationOwnerID == nil || presentationOwnerID == ownerID else { return }
        activeSheet = nil
        presentationOwnerID = nil
    }

    /// Bring a main editor window forward so a sheet can attach (e.g. from Settings).
    static func activatePreferredEditorWindow() {
        // Prefer an already-visible editor; fall back to any non-Settings app window.
        let editors = NSApp.windows.filter { window in
            guard window.isVisible || window.isMiniaturized else { return false }
            let title = window.title.lowercased()
            if title.contains("setting") || title.contains("설정") { return false }
            // Main editor titles are "Notepad" / "Notepad - …" or empty during launch.
            return true
        }
        let preferred = editors.first(where: { $0.title.lowercased().contains("notepad") })
            ?? editors.first(where: { !($0.title.lowercased().contains("setting") || $0.title.lowercased().contains("설정")) })
            ?? NSApp.windows.first

        preferred?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Test helper: clear pending presentation.
    func resetForTests() {
        activeSheet = nil
        presentationOwnerID = nil
    }
}

// MARK: - Pure onboarding rules

/// Pure helpers for first-run Welcome and version What's New dialogs.
enum OnboardingState {
    static let hasSeenWelcomeKey = "hasSeenWelcome"
    static let lastSeenWhatsNewVersionKey = "lastSeenWhatsNewVersion"
    static let migrationKey = "onboardingDefaultsMigration"
    static let migrationTokenV11 = "v1.1"

    /// Pre-v1.1 keys that indicate the app was used before onboarding existed.
    static let preV11UserDefaultsKeys: [String] = [
        "ShouldRestorePreviousSession",
        "fontSize",
        "defaultFontName",
        "wordWrap",
        "isDarkMode",
        "showStatusBar",
        "showTabBar",
        "defaultEncodingRaw",
    ]

    /// Show Welcome only when the user has never dismissed it.
    static func shouldShowWelcome(hasSeenWelcome: Bool) -> Bool {
        !hasSeenWelcome
    }

    /// Show What's New when the running version differs from the last acknowledged one.
    /// First install (`lastSeen` empty): skip What's New so Welcome is not stacked.
    static func shouldShowWhatsNew(currentVersion: String, lastSeenVersion: String, hasSeenWelcome: Bool) -> Bool {
        let current = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return false }
        // Pure first run → Welcome only
        if !hasSeenWelcome { return false }
        let last = lastSeenVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if last.isEmpty { return false }
        return last != current
    }

    /// Feature bullets for a marketing version (local, offline).
    static func whatsNewBullets(for version: String) -> [String] {
        switch version {
        case "1.2.4", "1.2.5":
            return [
                String(localized: "whatsNew.1_2_4.gatekeeper"),
                String(localized: "whatsNew.1_2_4.readonly"),
            ]
        case "1.2.3":
            return [
                String(localized: "whatsNew.1_2_3.languages"),
                String(localized: "whatsNew.1_2_3.picker"),
                String(localized: "whatsNew.1_2_3.system"),
                String(localized: "whatsNew.1_2_3.relaunch"),
            ]
        case "1.2.2":
            return [
                String(localized: "whatsNew.1_2_2.parser"),
                String(localized: "whatsNew.1_2_2.scheme"),
                String(localized: "whatsNew.1_2_2.remote"),
                String(localized: "whatsNew.1_2_2.bookmarks"),
                String(localized: "whatsNew.1_2_2.ime"),
            ]
        case "1.2.1":
            return [
                String(localized: "whatsNew.1_2_1.comments"),
                String(localized: "whatsNew.1_2_1.fences"),
                String(localized: "whatsNew.1_2.preview"),
                String(localized: "whatsNew.1_2.highlight"),
                String(localized: "whatsNew.1_2.remote"),
            ]
        case "1.2", "1.2.0":
            return [
                String(localized: "whatsNew.1_2.preview"),
                String(localized: "whatsNew.1_2.highlight"),
                String(localized: "whatsNew.1_2.remote"),
                String(localized: "whatsNew.1_2.browser"),
                String(localized: "whatsNew.1_2.toggle"),
            ]
        case "1.1", "1.1.0":
            return [
                String(localized: "whatsNew.1_1.spell"),
                String(localized: "whatsNew.1_1.autocorrect"),
                String(localized: "whatsNew.1_1.settings"),
                String(localized: "whatsNew.1_1.onboarding"),
                String(localized: "whatsNew.1_1.polish"),
            ]
        default:
            return [String(localized: "whatsNew.generic")]
        }
    }
}

// MARK: - One-time defaults migration (v1.0 → v1.1)

/// Planned seed values for a one-time onboarding defaults migration.
struct OnboardingMigrationPlan: Equatable {
    /// When non-nil, write this value to `hasSeenWelcome`.
    var hasSeenWelcome: Bool?
    /// When non-nil, write this value to `lastSeenWhatsNewVersion`.
    var lastSeenWhatsNewVersion: String?
    /// Whether the migration token should be stamped (even if no values change).
    var shouldStampMigration: Bool
}

enum OnboardingMigration {
    /// Pure decision: how to seed onboarding keys for v1.1.
    ///
    /// - Fresh install: stamp only → Welcome shows (hasSeenWelcome stays false).
    /// - Upgrade from pre-v1.1: seed welcome-seen + lastSeen="1.0" → What's New shows.
    /// - Already has onboarding keys: stamp only, leave values alone.
    static func plan(
        alreadyMigrated: Bool,
        hasSeenWelcomeKeyPresent: Bool,
        lastSeenVersion: String,
        hasPreV11Evidence: Bool
    ) -> OnboardingMigrationPlan {
        if alreadyMigrated {
            return OnboardingMigrationPlan(
                hasSeenWelcome: nil,
                lastSeenWhatsNewVersion: nil,
                shouldStampMigration: false
            )
        }

        let last = lastSeenVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasSeenWelcomeKeyPresent || !last.isEmpty {
            return OnboardingMigrationPlan(
                hasSeenWelcome: nil,
                lastSeenWhatsNewVersion: nil,
                shouldStampMigration: true
            )
        }

        if hasPreV11Evidence {
            return OnboardingMigrationPlan(
                hasSeenWelcome: true,
                lastSeenWhatsNewVersion: "1.0",
                shouldStampMigration: true
            )
        }

        // Brand-new install of 1.1+
        return OnboardingMigrationPlan(
            hasSeenWelcome: nil,
            lastSeenWhatsNewVersion: nil,
            shouldStampMigration: true
        )
    }

    static func hasPreV11Evidence(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> Bool {
        for key in OnboardingState.preV11UserDefaultsKeys {
            if defaults.object(forKey: key) != nil { return true }
        }
        return hasApplicationSupportEvidence(fileManager: fileManager)
    }

    /// True if Application Support already has NotepadForMacOS data (sessions, etc.).
    static func hasApplicationSupportEvidence(fileManager: FileManager = .default) -> Bool {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let root = appSupport.appendingPathComponent("NotepadForMacOS", isDirectory: true)
        guard fileManager.fileExists(atPath: root.path) else { return false }
        let contents = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        return !contents.isEmpty
    }

    /// Apply one-time migration before any `@AppStorage` onboarding reads.
    /// Safe to call multiple times; stamps `onboardingDefaultsMigration = v1.1`.
    ///
    /// - Parameter hasPreV11EvidenceOverride: For tests; when nil, auto-detect from defaults + disk.
    static func applyIfNeeded(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        hasPreV11EvidenceOverride: Bool? = nil
    ) {
        let already = defaults.string(forKey: OnboardingState.migrationKey) == OnboardingState.migrationTokenV11
        let evidence = hasPreV11EvidenceOverride
            ?? hasPreV11Evidence(defaults: defaults, fileManager: fileManager)
        let plan = plan(
            alreadyMigrated: already,
            hasSeenWelcomeKeyPresent: defaults.object(forKey: OnboardingState.hasSeenWelcomeKey) != nil,
            lastSeenVersion: defaults.string(forKey: OnboardingState.lastSeenWhatsNewVersionKey) ?? "",
            hasPreV11Evidence: evidence
        )

        guard plan.shouldStampMigration || plan.hasSeenWelcome != nil || plan.lastSeenWhatsNewVersion != nil else {
            return
        }

        if let seen = plan.hasSeenWelcome {
            defaults.set(seen, forKey: OnboardingState.hasSeenWelcomeKey)
        }
        if let version = plan.lastSeenWhatsNewVersion {
            defaults.set(version, forKey: OnboardingState.lastSeenWhatsNewVersionKey)
        }
        if plan.shouldStampMigration {
            defaults.set(OnboardingState.migrationTokenV11, forKey: OnboardingState.migrationKey)
        }
    }
}
