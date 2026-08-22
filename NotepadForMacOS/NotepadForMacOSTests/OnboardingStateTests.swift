import XCTest
@testable import Notepad

final class OnboardingStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        OnboardingCoordinator.resetForTests()
    }

    func testShouldShowWelcome() {
        XCTAssertTrue(OnboardingState.shouldShowWelcome(hasSeenWelcome: false))
        XCTAssertFalse(OnboardingState.shouldShowWelcome(hasSeenWelcome: true))
    }

    func testWhatsNewSkippedOnFirstRun() {
        // First install: Welcome only
        XCTAssertFalse(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.1.0",
                lastSeenVersion: "",
                hasSeenWelcome: false
            )
        )
    }

    func testWhatsNewOnUpgrade() {
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.0",
                hasSeenWelcome: true
            )
        )
    }

    func testWhatsNewNotRepeatedForSameVersion() {
        XCTAssertFalse(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.1.0",
                hasSeenWelcome: true
            )
        )
    }

    func testWhatsNewEmptyCurrentNeverShows() {
        XCTAssertFalse(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "  ",
                lastSeenVersion: "1.0",
                hasSeenWelcome: true
            )
        )
    }

    func testWhatsNewBulletsFor11() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.1.0")
        XCTAssertEqual(bullets.count, 5)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor12() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.0")
        XCTAssertEqual(bullets.count, 5)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor121() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.1")
        XCTAssertEqual(bullets.count, 5)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor126() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.6")
        XCTAssertEqual(bullets.count, 2)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor125() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.5")
        XCTAssertEqual(bullets.count, 2)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor124() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.4")
        XCTAssertEqual(bullets.count, 2)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewBulletsFor123() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.3")
        XCTAssertEqual(bullets.count, 4)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewShowsWhenUpgradingFrom122To123() {
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.2.3",
                lastSeenVersion: "1.2.2",
                hasSeenWelcome: true
            )
        )
    }

    func testWhatsNewBulletsFor122() {
        let bullets = OnboardingState.whatsNewBullets(for: "1.2.2")
        XCTAssertEqual(bullets.count, 5)
        XCTAssertFalse(bullets.contains { $0.isEmpty })
    }

    func testWhatsNewShowsWhenUpgradingFrom121To122() {
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.2.2",
                lastSeenVersion: "1.2.1",
                hasSeenWelcome: true
            )
        )
    }

    func testWhatsNewShowsWhenUpgradingFrom12To121() {
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.2.1",
                lastSeenVersion: "1.2.0",
                hasSeenWelcome: true
            )
        )
    }


    func testWhatsNewShowsWhenUpgradingFrom11To12() {
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.2.0",
                lastSeenVersion: "1.1.0",
                hasSeenWelcome: true
            )
        )
    }


    func testOnboardingCoordinatorClaimsOnce() {
        OnboardingCoordinator.resetForTests()
        XCTAssertTrue(OnboardingCoordinator.claimAutoPresent())
        XCTAssertFalse(OnboardingCoordinator.claimAutoPresent())
        OnboardingCoordinator.resetForTests()
        XCTAssertTrue(OnboardingCoordinator.claimAutoPresent())
    }

    // MARK: - Migration plan (Codex finding #1)

    func testMigrationPlan_alreadyMigrated_noop() {
        let plan = OnboardingMigration.plan(
            alreadyMigrated: true,
            hasSeenWelcomeKeyPresent: false,
            lastSeenVersion: "",
            hasPreV11Evidence: true
        )
        XCTAssertNil(plan.hasSeenWelcome)
        XCTAssertNil(plan.lastSeenWhatsNewVersion)
        XCTAssertFalse(plan.shouldStampMigration)
    }

    func testMigrationPlan_freshInstall_stampOnly() {
        let plan = OnboardingMigration.plan(
            alreadyMigrated: false,
            hasSeenWelcomeKeyPresent: false,
            lastSeenVersion: "",
            hasPreV11Evidence: false
        )
        XCTAssertNil(plan.hasSeenWelcome)
        XCTAssertNil(plan.lastSeenWhatsNewVersion)
        XCTAssertTrue(plan.shouldStampMigration)
        // After stamp with empty keys, Welcome still shows:
        XCTAssertTrue(OnboardingState.shouldShowWelcome(hasSeenWelcome: false))
        XCTAssertFalse(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.1.0",
                lastSeenVersion: "",
                hasSeenWelcome: false
            )
        )
    }

    func testMigrationPlan_upgradeFromV10_seedsWhatsNewPath() {
        let plan = OnboardingMigration.plan(
            alreadyMigrated: false,
            hasSeenWelcomeKeyPresent: false,
            lastSeenVersion: "",
            hasPreV11Evidence: true
        )
        XCTAssertEqual(plan.hasSeenWelcome, true)
        XCTAssertEqual(plan.lastSeenWhatsNewVersion, "1.0")
        XCTAssertTrue(plan.shouldStampMigration)

        // Seeded values produce What's New, not Welcome.
        XCTAssertFalse(OnboardingState.shouldShowWelcome(hasSeenWelcome: true))
        XCTAssertTrue(
            OnboardingState.shouldShowWhatsNew(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.0",
                hasSeenWelcome: true
            )
        )
    }

    func testMigrationPlan_existingOnboardingKeys_stampOnly() {
        let plan = OnboardingMigration.plan(
            alreadyMigrated: false,
            hasSeenWelcomeKeyPresent: true,
            lastSeenVersion: "1.1.0",
            hasPreV11Evidence: true
        )
        XCTAssertNil(plan.hasSeenWelcome)
        XCTAssertNil(plan.lastSeenWhatsNewVersion)
        XCTAssertTrue(plan.shouldStampMigration)
    }

    func testMigrationApply_seedsAndIsIdempotent() {
        let suiteName = "OnboardingMigrationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Simulate v1.0 usage without depending on the host's Application Support.
        OnboardingMigration.applyIfNeeded(defaults: defaults, hasPreV11EvidenceOverride: true)

        XCTAssertEqual(defaults.string(forKey: OnboardingState.migrationKey), OnboardingState.migrationTokenV11)
        XCTAssertTrue(defaults.bool(forKey: OnboardingState.hasSeenWelcomeKey))
        XCTAssertEqual(defaults.string(forKey: OnboardingState.lastSeenWhatsNewVersionKey), "1.0")

        // Second apply must not rewrite user-dismissed state.
        defaults.set("1.1.0", forKey: OnboardingState.lastSeenWhatsNewVersionKey)
        OnboardingMigration.applyIfNeeded(defaults: defaults, hasPreV11EvidenceOverride: true)
        XCTAssertEqual(defaults.string(forKey: OnboardingState.lastSeenWhatsNewVersionKey), "1.1.0")
    }

    func testMigrationApply_freshInstall_doesNotSeedWelcomeSeen() {
        let suiteName = "OnboardingMigrationFresh.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingMigration.applyIfNeeded(defaults: defaults, hasPreV11EvidenceOverride: false)

        XCTAssertEqual(defaults.string(forKey: OnboardingState.migrationKey), OnboardingState.migrationTokenV11)
        XCTAssertNil(defaults.object(forKey: OnboardingState.hasSeenWelcomeKey))
        XCTAssertNil(defaults.object(forKey: OnboardingState.lastSeenWhatsNewVersionKey))
    }

    @MainActor
    func testPresenter_claimIsExclusive() {
        let presenter = OnboardingPresenter.shared
        presenter.resetForTests()

        let a = UUID()
        let b = UUID()
        presenter.request(.welcome)
        XCTAssertEqual(presenter.claim(ownerID: a), .welcome)
        XCTAssertNil(presenter.claim(ownerID: b))
        presenter.dismiss(ownerID: a)
        XCTAssertNil(presenter.activeSheet)
    }
}
