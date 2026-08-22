# Spec: In-app language

## Objective

Notepad UI is no longer English/Korean only. Settings can pin a language. Default follows the Mac.

## Assumptions

1. Ship 16 LTR locales: `en`, `ko`, `ja`, `zh-Hans`, `zh-Hant`, `es`, `fr`, `de`, `pt-BR`, `it`, `ru`, `vi`, `id`, `th`, `pl`, `nl`.
2. No RTL (`ar`, `he`) this pass — AppKit mirroring is a separate project.
3. Changing language writes `AppleLanguages` and relaunches. Same-process `String(localized:)` will not flip.
4. Language names in the picker are native (`日本語`, `Deutsch`) so the list is findable in any current UI language.
5. App Store listing text is out of scope.

## Success Criteria

- Fresh install with no override uses macOS preferred language if we ship it, else English.
- Settings → Language → System clears the override.
- Settings → Language → Japanese survives relaunch.
- Unknown stored value behaves as System.
- `./build.sh test` passes.
