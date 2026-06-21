import SwiftUI
import AppKit

/// NSTextView 기반 에디터 (커서 위치, 정확한 제어, 큰 파일 대응)
struct BetterEditorView: NSViewRepresentable {
    let documentID: UUID
    @Binding var text: String
    @EnvironmentObject var tabManager: TabManager

    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("defaultFontName") private var defaultFontName: String = ""
    @AppStorage("wordWrap") private var wordWrap: Bool = false

    /// Returns the font to use for the editor, respecting the user's default font choice.
    private var currentEditorFont: NSFont {
        let size = CGFloat(fontSize)
        if defaultFontName.isEmpty {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        // Try the stored name, plus common SF Mono variants
        let candidates = [defaultFontName, "SFMono-Regular", "SF Mono"]
        for name in candidates where !name.isEmpty {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = currentEditorFont
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = context.coordinator

        // Word wrap 토글 (기본은 wrap)
        textView.textContainer?.widthTracksTextView = wordWrap
        textView.isHorizontallyResizable = !wordWrap
        if wordWrap {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        if textView.string != text {
            textView.string = text
        }

        textView.font = currentEditorFont
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        scrollView.backgroundColor = .textBackgroundColor

        // Word wrap 업데이트
        textView.textContainer?.widthTracksTextView = wordWrap
        textView.isHorizontallyResizable = !wordWrap
        if wordWrap {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.handlePendingCommandIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(documentID: documentID, text: $text, tabManager: tabManager)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let documentID: UUID
        @Binding var text: String
        weak var tabManager: TabManager?
        weak var textView: NSTextView?
        private var lastHandledCommandID: UUID?

        init(documentID: UUID, text: Binding<String>, tabManager: TabManager) {
            self.documentID = documentID
            self._text = text
            self.tabManager = tabManager
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if text != textView.string {
                text = textView.string
                tabManager?.updateContent(for: documentID, newContent: textView.string)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateCursor(for: textView)
        }

        func handlePendingCommandIfNeeded() {
            guard let command = tabManager?.pendingEditorCommand,
                  command.documentID == documentID,
                  command.id != lastHandledCommandID,
                  let textView else { return }

            lastHandledCommandID = command.id

            switch command.action {
            case let .find(search, matchCase):
                find(search: search, matchCase: matchCase, in: textView)
            case let .replace(search, replacement, matchCase):
                replace(search: search, with: replacement, matchCase: matchCase, in: textView)
            case let .goToLine(line):
                goToLine(line, in: textView)
            }
        }

        private func find(search: String, matchCase: Bool, in textView: NSTextView) {
            guard let range = findRange(search: search, matchCase: matchCase, in: textView) else {
                NSSound.beep()
                return
            }

            selectAndReveal(range, in: textView)
        }

        private func replace(search: String, with replacement: String, matchCase: Bool, in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            let targetRange: NSRange?

            if selection(selectedRange, matches: search, matchCase: matchCase, in: textView) {
                targetRange = selectedRange
            } else {
                targetRange = findRange(
                    search: search,
                    matchCase: matchCase,
                    in: textView,
                    startingAt: selectedRange.location
                )
            }

            guard let range = targetRange else {
                NSSound.beep()
                return
            }

            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()

            let replacementLength = (replacement as NSString).length
            let nextSearchStart = min(range.location + replacementLength, (textView.string as NSString).length)
            if let nextRange = findRange(
                search: search,
                matchCase: matchCase,
                in: textView,
                startingAt: nextSearchStart
            ) {
                selectAndReveal(nextRange, in: textView)
            } else {
                selectAndReveal(NSRange(location: range.location, length: replacementLength), in: textView)
            }
        }

        private func goToLine(_ line: Int, in textView: NSTextView) {
            let location = locationForLine(line, in: textView.string)
            selectAndReveal(NSRange(location: location, length: 0), in: textView)
        }

        private func findRange(
            search: String,
            matchCase: Bool,
            in textView: NSTextView,
            startingAt explicitStart: Int? = nil
        ) -> NSRange? {
            guard !search.isEmpty else { return nil }

            let nsText = textView.string as NSString
            guard nsText.length > 0 else { return nil }

            let selectedRange = textView.selectedRange()
            let defaultStart = selectedRange.length > 0 ? NSMaxRange(selectedRange) : selectedRange.location
            let start = min(max(0, explicitStart ?? defaultStart), nsText.length)
            let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive

            let forwardRange = NSRange(location: start, length: nsText.length - start)
            let foundForward = nsText.range(of: search, options: options, range: forwardRange)
            if foundForward.location != NSNotFound {
                return foundForward
            }

            guard start > 0 else { return nil }
            let wrappedRange = NSRange(location: 0, length: start)
            let foundWrapped = nsText.range(of: search, options: options, range: wrappedRange)
            return foundWrapped.location == NSNotFound ? nil : foundWrapped
        }

        private func selection(_ range: NSRange, matches search: String, matchCase: Bool, in textView: NSTextView) -> Bool {
            guard range.length > 0 else { return false }
            let nsText = textView.string as NSString
            guard NSMaxRange(range) <= nsText.length else { return false }

            let selectedText = nsText.substring(with: range) as NSString
            let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive
            return selectedText.compare(search, options: options) == .orderedSame
        }

        private func locationForLine(_ targetLine: Int, in string: String) -> Int {
            guard targetLine > 1 else { return 0 }

            let nsText = string as NSString
            var currentLine = 1
            var location = 0

            while location < nsText.length && currentLine < targetLine {
                let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
                let nextLocation = NSMaxRange(lineRange)

                guard nextLocation > location else { break }
                location = nextLocation
                currentLine += 1
            }

            return min(location, nsText.length)
        }

        private func selectAndReveal(_ range: NSRange, in textView: NSTextView) {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            updateCursor(for: textView)
        }

        private func updateCursor(for textView: NSTextView) {
            let nsText = textView.string as NSString
            let loc = min(textView.selectedRange().location, nsText.length)
            var line = 1
            var lineStart = 0
            var scanLocation = 0

            while scanLocation < loc {
                let lineRange = nsText.lineRange(for: NSRange(location: scanLocation, length: 0))
                let nextLocation = NSMaxRange(lineRange)

                guard nextLocation > scanLocation, nextLocation <= loc else { break }
                line += 1
                lineStart = nextLocation
                scanLocation = nextLocation
            }

            let col = max(1, loc - lineStart + 1)
            tabManager?.updateCursor(line: line, col: col)
        }
    }
}

// MARK: - 기존 간단 TextEditor 뷰에서 전환용 래퍼 (MainEditorView에서 사용)

struct EditorView: View {
    let document: Document
    @EnvironmentObject var tabManager: TabManager

    @AppStorage("wordWrap") private var wordWrap: Bool = false
    @AppStorage("defaultFontName") private var defaultFontName: String = ""
    @State private var text: String = ""

    var body: some View {
        BetterEditorView(documentID: document.id, text: $text)
            .environmentObject(tabManager)
            .id("\(document.id)-\(wordWrap)-\(defaultFontName)") // force update when wrap or default font changes
            .onAppear {
                text = document.content
            }
            .onChange(of: document.content) { _, newValue in
                if text != newValue {
                    text = newValue
                }
            }
    }
}
