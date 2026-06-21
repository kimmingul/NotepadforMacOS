import SwiftUI

struct SettingsView: View {
    @ObservedObject private var sessionStore = SessionStore.shared

    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("defaultFontName") private var defaultFontName: String = ""
    @AppStorage("wordWrap") private var wordWrapDefault: Bool = false
    @AppStorage("defaultEncodingRaw") private var defaultEncodingRaw: String = TextEncoding.utf8.rawValue

    var body: some View {
        // We wrap everything in an explicit container so the view proposes
        // a stable intrinsic size to the Settings window / SwiftUI layout system.
        // Combined with .defaultSize + AppKit forcing in NotepadApp.swift this
        // makes width/height changes actually take effect.
        VStack(spacing: 0) {
            Form {
                Section(String(localized: "When Notepad starts")) {
                    Toggle("Continue previous session (restore tabs and unsaved content)", isOn: Binding(
                        get: { sessionStore.shouldRestorePreviousSession },
                        set: { sessionStore.setRestorePreviousSession($0) }
                    ))

                    Text("Works like Windows 11 Notepad. When off, the app always starts with a new tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "Editor")) {
                    HStack {
                        Text("Default font size")
                        Spacer()
                        Stepper(value: $fontSize, in: 8...48, step: 1) {
                            Text(String(format: String(localized: "fontSize.points"), Int(fontSize)))
                        }
                    }

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

                    Toggle("Word Wrap by default", isOn: $wordWrapDefault)

                    Picker("Default encoding for new tabs", selection: $defaultEncodingRaw) {
                        ForEach(TextEncoding.allCases) { enc in
                            Text(enc.displayName).tag(enc.rawValue)
                        }
                    }
                }

                Section(String(localized: "Session")) {
                    Button("Start New Session (discard current unsaved tabs)") {
                        sessionStore.clearAllSessions()
                        NotificationCenter.default.post(name: .startNewSessionRequested, object: nil)
                    }
                    .foregroundStyle(.red)

                    Text("Restored tabs and temporary content will be removed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Footer
            Text("Notepad for macOS • Apple Silicon • Plain text only")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 400, minHeight: 510)
    }
}
