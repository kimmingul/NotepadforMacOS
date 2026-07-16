import Foundation

/// Win11 Notepad-style spelling preferences (plain helpers for settings + editor).
///
/// Defaults:
/// - Spell check **on** (prose-friendly, like modern Notepad)
/// - Autocorrect **off** (safer for code/logs and Korean mixed typing)
/// - Common code/log extensions disabled for continuous checking
enum SpellingPreferences {
    static let spellCheckKey = "spellCheckEnabled"
    static let autoCorrectKey = "autoCorrectEnabled"
    static let disabledExtensionsKey = "spellCheckDisabledExtensions"

    /// Default list of path extensions (no dots) that skip spell check when a file is open.
    static let defaultDisabledExtensionsRaw =
        "log,csv,json,xml,yaml,yml,md,sh,py,js,ts,tsx,jsx,c,h,cpp,hpp,swift,go,rs,java,kt,rb,php,sql,toml,ini,cfg,conf"

    static var defaultSpellCheckEnabled: Bool { true }
    static var defaultAutoCorrectEnabled: Bool { false }

    /// Parse a comma/space/newline-separated extension list into a normalized set (lowercase, no dots).
    static func parseDisabledExtensions(_ raw: String) -> Set<String> {
        let separators = CharacterSet(charactersIn: ",;\n\t ")
        return Set(
            raw
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
                .filter { !$0.isEmpty }
        )
    }

    /// Serialize a set back to a stable comma-separated string (sorted).
    static func serializeDisabledExtensions(_ extensions: Set<String>) -> String {
        extensions
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: ", ")
    }

    /// Whether continuous spell checking / autocorrect should be active for this document.
    static func isSpellingAllowed(
        pathExtension: String?,
        spellCheckEnabled: Bool,
        disabledExtensions: Set<String>
    ) -> Bool {
        guard spellCheckEnabled else { return false }
        guard let ext = pathExtension?.lowercased(), !ext.isEmpty else {
            // Untitled / no extension → use global toggle
            return true
        }
        return !disabledExtensions.contains(ext)
    }

    static func isSpellingAllowed(
        fileURL: URL?,
        spellCheckEnabled: Bool,
        disabledExtensionsRaw: String
    ) -> Bool {
        isSpellingAllowed(
            pathExtension: fileURL?.pathExtension,
            spellCheckEnabled: spellCheckEnabled,
            disabledExtensions: parseDisabledExtensions(disabledExtensionsRaw)
        )
    }
}
