import SwiftUI

/// First-run welcome sheet (Win11 Notepad discovery style). Offline, no analytics.
struct WelcomeView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "welcome.title"))
                        .font(.title2.weight(.semibold))
                    Text(String(localized: "welcome.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                welcomeRow(icon: "rectangle.split.3x1", text: String(localized: "welcome.bullet.tabs"))
                welcomeRow(icon: "arrow.counterclockwise", text: String(localized: "welcome.bullet.session"))
                welcomeRow(icon: "textformat.abc", text: String(localized: "welcome.bullet.encoding"))
                welcomeRow(icon: "text.badge.checkmark", text: String(localized: "welcome.bullet.spelling"))
                welcomeRow(icon: "magnifyingglass", text: String(localized: "welcome.bullet.find"))
            }

            Text(String(localized: "welcome.footer"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button(String(localized: "welcome.getStarted")) {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func welcomeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
