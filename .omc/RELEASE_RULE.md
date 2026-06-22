# Release Rules
<!-- last-analyzed: 2026-06-23T00:00:00Z -->

## Version Sources
- `NotepadForMacOS/NotepadForMacOS.xcodeproj/project.pbxproj`
  - `MARKETING_VERSION` (user-facing version, e.g. `1.0`) — appears in all 4 build configs (app + test target × Debug/Release)
  - `CURRENT_PROJECT_VERSION` (build number, integer) — bump on every store/notarized upload
- No separate VERSION file, package.json, or release automation tool (release-it / semantic-release / etc.).

## Release Trigger
- Manual. No CI. Releases are cut locally via `./build.sh` and published to GitHub with `gh release create`.
- Git tag convention: `vMAJOR.MINOR[.PATCH]` (annotated tags).

## Test Gate
- Command: `./build.sh test` → `xcodebuild test -scheme NotepadForMacOS -destination 'platform=macOS,arch=arm64'`
- Log: `build/last-test.log`. Must pass before tagging.

## Registry / Distribution
Two channels, different certs (see HOW_TO_BUILD.md):
- **GitHub release (outside App Store)** → `./build.sh dist`
  - Signs with `Developer ID Application: MINGUL KIM (XB673TQF3A)` (env `DEVID_APP`)
  - Notarizes + staples if `NOTARY_PROFILE` is set (keychain profile via `xcrun notarytool store-credentials`)
  - Output: `dist/Notepad.dmg` → upload as GitHub release asset
- **Mac App Store** → `./build.sh appstore` (env `APPSTORE_TEAM_ID`, ASC_* upload creds) → `dist/appstore/Notepad.pkg`
- No automated publish step in CI; all uploads are manual.

## Release Notes Strategy
- Conventional Commits (feat/fix/docs/chore/refactor/perf/ci). Generate draft from
  `git log <prev-tag>..HEAD --no-merges --format='%s'` grouped by type.
- No committed CHANGELOG.md yet; release body authored inline in `gh release create`.

## CI Workflow Files
- None (`.github/` absent). Releases are fully local + `gh` CLI.

## First-Time Setup Gaps
- Tags: `v1.0` is published (first release, 2026-06-23, notarized Developer ID DMG).
- No `.github/workflows/release.yml` — optional; current flow is manual via build.sh + gh.
- `dist/`, `build/`, `*.dmg`, `*.xcarchive` are gitignored (good — no build artifacts in git).
- Notarization: keychain profile `notary-profile` is configured (App Store Connect API key
  `~/.appstoreconnect/private_keys/AuthKey_WH8S466B89.p8`, Key ID `WH8S466B89`). So
  `export DEVID_APP="Developer ID Application: MINGUL KIM (XB673TQF3A)"; export NOTARY_PROFILE=notary-profile; ./build.sh dist`
  produces a notarized + stapled `dist/Notepad.dmg` with no further prompts.
- Codesign gotcha: from a non-interactive/headless shell, `codesign` can flake with
  `errSecInternalComponent`. One-time fix in a GUI Terminal:
  `security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db`.
