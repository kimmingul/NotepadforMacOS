import SwiftUI

struct SettingsView: View {
    @ObservedObject private var sessionStore = SessionStore.shared

    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("defaultFontName") private var defaultFontName: String = ""
    @AppStorage("wordWrap") private var wordWrapDefault: Bool = false
    @AppStorage("defaultEncodingRaw") private var defaultEncodingRaw: String = TextEncoding.utf8.rawValue

    @AppStorage(SpellingPreferences.spellCheckKey) private var spellCheckEnabled: Bool = SpellingPreferences.defaultSpellCheckEnabled
    @AppStorage(SpellingPreferences.autoCorrectKey) private var autoCorrectEnabled: Bool = SpellingPreferences.defaultAutoCorrectEnabled
    @AppStorage(SpellingPreferences.disabledExtensionsKey) private var disabledExtensionsRaw: String = SpellingPreferences.defaultDisabledExtensionsRaw
    @AppStorage(AppLanguagePreferences.languageKey) private var languageRaw: String = AppLanguage.system.rawValue

    var body: some View {
        // We wrap everything in an explicit container so the view proposes
        // a stable intrinsic size to the Settings window / SwiftUI layout system.
        // Combined with .defaultSize + AppKit forcing in NotepadApp.swift this
        // makes width/height changes actually take effect.
        VStack(spacing: 0) {
            Form {
                Section(String(localized: "settings.language")) {
                    Picker(selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.nativeDisplayName).tag(language.rawValue)
                        }
                    } label: {
                        Text(String(localized: "settings.language"))
                    }
                    Text(String(localized: "settings.language.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "When Notepad starts")) {
                    Toggle(String(localized: "Continue previous session (restore tabs and unsaved content)"), isOn: Binding(
                        get: { sessionStore.shouldRestorePreviousSession },
                        set: { sessionStore.setRestorePreviousSession($0) }
                    ))

                    Text(String(localized: "Works like Windows 11 Notepad. When off, the app always starts with a new tab."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "Editor")) {
                    HStack {
                        Text(String(localized: "Default font size"))
                        Spacer()
                        Text(String(format: String(localized: "fontSize.points"), Int(fontSize)))
                            .monospacedDigit()
                            .frame(minWidth: 50, alignment: .trailing)
                        Stepper(value: $fontSize, in: 8...48, step: 1) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }

                    Text(String(localized: "settings.fontSize.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(String(localized: "Default font"))
                        Spacer()
                        Picker(selection: $defaultFontName) {
                            Text(String(localized: "System Monospaced")).tag("")

                            // 실제 폰트 이름은 절대 번역하지 않음 (verbatim)
                            ForEach(["Menlo", "SF Mono", "Monaco", "Courier", "Courier New"], id: \.self) { name in
                                Text(verbatim: name).tag(name)
                            }
                        } label: {
                            EmptyView()
                        }
                        .frame(width: 180)
                    }

                    Text(String(localized: "settings.font.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(String(localized: "Word Wrap by default"), isOn: $wordWrapDefault)

                    Picker(String(localized: "Default encoding for new tabs"), selection: $defaultEncodingRaw) {
                        ForEach(TextEncoding.allCases) { enc in
                            Text(enc.displayName).tag(enc.rawValue)
                        }
                    }
                }

                Section(String(localized: "settings.spelling")) {
                    Toggle(String(localized: "settings.spellCheck"), isOn: $spellCheckEnabled)

                    Toggle(String(localized: "settings.autoCorrect"), isOn: $autoCorrectEnabled)
                        .disabled(!spellCheckEnabled)

                    Text(String(localized: "settings.spelling.caption"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "settings.disabledExtensions"))
                        TextEditor(text: $disabledExtensionsRaw)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 54, maxHeight: 72)
                            .disabled(!spellCheckEnabled)
                        Text(String(localized: "settings.disabledExtensions.caption"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(String(localized: "settings.disabledExtensions.reset")) {
                            disabledExtensionsRaw = SpellingPreferences.defaultDisabledExtensionsRaw
                        }
                        .disabled(!spellCheckEnabled || disabledExtensionsRaw == SpellingPreferences.defaultDisabledExtensionsRaw)
                    }
                }

                Section(String(localized: "settings.help")) {
                    Button(String(localized: "settings.showWelcomeAgain")) {
                        // Do not flip hasSeenWelcome — just re-present. Presentation is
                        // owned by OnboardingPresenter so Settings need not be the key window.
                        OnboardingPresenter.shared.request(.welcome)
                        OnboardingPresenter.activatePreferredEditorWindow()
                    }
                }

                Section(String(localized: "Session")) {
                    Button(String(localized: "Start New Session (discard current unsaved tabs)")) {
                        sessionStore.clearAllSessions()
                        NotificationCenter.default.post(name: .startNewSessionRequested, object: nil)
                    }
                    .foregroundStyle(.red)

                    Text(String(localized: "Restored tabs and temporary content will be removed."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Footer
            Text(String(localized: "Notepad for macOS • Apple Silicon • Plain text only"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 420, minHeight: 700)
    }


    private var languageBinding: Binding<String> {
        Binding(
            get: { languageRaw },
            set: { newValue in
                let previous = languageRaw
                guard newValue != previous else { return }
                languageRaw = newValue
                AppLanguagePreferences.apply(AppLanguagePreferences.parse(newValue), to: .standard)
                AppRelauncher.confirmAndRelaunch()
            }
        )
    }

}
