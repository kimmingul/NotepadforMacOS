import SwiftUI
import AppKit

/// 붙여넣기(Cmd+V) 후 비-wrap 모드에서 레이아웃/스크롤이 동기화되지 않던 문제를
/// 바로잡기 위한 NSTextView 서브클래스.
///
/// 붙여넣기는 텍스트 변경일 뿐 아니라 커서를 붙여넣은 끝으로 옮기고 그 위치를
/// 보이게 스크롤한다. 긴 한 줄을 붙여넣으면 가로 오프셋이 생겨 문장 중간이 보이고,
/// document 프레임이 즉시 갱신되지 않아 가로 스크롤바도 나타나지 않는다.
/// 타이핑은 `insertText(_:)` 경로라 이 오버라이드의 영향을 받지 않으므로,
/// "붙여넣을 때만 맨 앞으로" 동작을 안전하게 구현할 수 있다.
final class NotepadTextView: NSTextView {
    private var didAlignInitialScroll = false

    /// 탭 복귀(.id로 뷰 재생성) 시 가로 스크롤이 여백폭만큼 밀려 첫 글자가 좌측
    /// 테두리에 붙던 문제를, 화면이 그려지기 **직전**에 동기로 바로잡는다.
    /// (이전엔 async로 그린 뒤 고쳐서 "여백 없음 → 여백 있음" 2단계 깜박임이 있었다.)
    override func viewWillDraw() {
        super.viewWillDraw()
        guard !didAlignInitialScroll,
              let scrollView = enclosingScrollView,
              let container = textContainer else { return }
        didAlignInitialScroll = true
        layoutManager?.ensureLayout(for: container)
        let clip = scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: clip.bounds.origin.y))
        scrollView.reflectScrolledClipView(clip)
    }

    private func revealPasteStart(from insertLoc: Int) {
        guard let scrollView = enclosingScrollView,
              let layoutManager, let textContainer else { return }
        // 레이아웃을 동기 강제 → document 폭이 즉시 확정된다.
        layoutManager.ensureLayout(for: textContainer)
        // 스크롤러 기하를 갱신해 (오버레이) 스크롤바가 곧바로 반영되게 한다.
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollView.tile()
        // 커서(끝)가 아니라 붙여넣은 줄의 맨 앞으로 스크롤 → 좌측 여백도 복원된다.
        let ns = string as NSString
        let safeLoc = min(max(0, insertLoc), ns.length)
        let lineStart = ns.lineRange(for: NSRange(location: safeLoc, length: 0)).location
        scrollRangeToVisible(NSRange(location: lineStart, length: 0))
        // 가로 위치를 확실히 줄 맨 앞(x=0)으로 강제한다(좌측 여백 복원).
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        origin.x = 0
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }

    override func paste(_ sender: Any?) {
        let insertLoc = selectedRange().location
        super.paste(sender)
        revealPasteStart(from: insertLoc)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let insertLoc = selectedRange().location
        super.pasteAsPlainText(sender)
        revealPasteStart(from: insertLoc)
    }
}

/// NSTextView 기반 에디터.
///
/// 설계: NSTextView가 편집 중 텍스트의 **단일 소스(source of truth)**다.
/// - 사용자 입력 → `textDidChange` → 모델(`TabManager.tabs[i].content`) 갱신.
/// - 프로그램적 편집(찾기/바꾸기, 시간·날짜 삽입, 인코딩 다시 열기, 인쇄)은 모두
///   Coordinator가 textView에 직접 적용 → 커서/선택/실행취소가 보존된다.
/// - `updateNSView`는 폰트/색/줄바꿈만 갱신하고 텍스트를 재대입하지 않는다(커서 점프 방지).
/// 탭 전환은 상위 뷰의 `.id(tab.id)`로 인스턴스가 새로 생성되어 처리된다.
struct EditorTextView: NSViewRepresentable {
    let documentID: UUID
    @EnvironmentObject var tabManager: TabManager

    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("defaultFontName") private var defaultFontName: String = ""
    @AppStorage("wordWrap") private var wordWrap: Bool = false

    private var currentEditorFont: NSFont {
        let size = CGFloat(fontSize)
        if defaultFontName.isEmpty {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        let candidates = [defaultFontName, "SFMono-Regular", "SF Mono"]
        for name in candidates where !name.isEmpty {
            if let font = NSFont(name: name, size: size) { return font }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // 팩토리(scrollableTextView)는 서브클래스를 만들 수 없으므로 수동 구성한다.
        let textView = NotepadTextView(frame: .zero)
        let scrollView = NSScrollView()
        scrollView.documentView = textView

        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        // 클래식(legacy) 스크롤바를 항상 표시한다.
        scrollView.scrollerStyle = .legacy
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        // 상·하·좌·우 일관된 작은 여백. 좌측 여백을 lineFragmentPadding 대신 inset으로
        // 통일해 상단 여백과 동일하게 맞춘다.
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.textContainer?.lineFragmentPadding = 0
        // autoresizingMask는 wrap 여부에 따라 applyWrap에서 설정한다
        // (비-wrap에서 [.width]는 콘텐츠 폭을 클립 폭에 묶어 가로 스크롤을 막는다).
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = currentEditorFont
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = context.coordinator
        textView.string = tabManager.document(with: documentID)?.content ?? ""

        applyWrap(to: textView, scrollView: scrollView)
        context.coordinator.textView = textView

        // 초기 커서를 맨 앞으로. 가로 정렬(x=0)은 깜박임 없이 첫 그리기 직전에
        // NotepadTextView.viewWillDraw()가 동기로 수행한다.
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // 텍스트는 textView가 소유하므로 재대입하지 않는다. 표시 속성만 갱신.
        if textView.font != currentEditorFont { textView.font = currentEditorFont }
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        scrollView.backgroundColor = .textBackgroundColor
        applyWrap(to: textView, scrollView: scrollView)
        context.coordinator.handlePendingCommandIfNeeded()
    }

    private func applyWrap(to textView: NSTextView, scrollView: NSScrollView) {
        // 줄바꿈(wrap)이 켜지면 가로 스크롤이 불필요하므로 가로 스크롤러를 끈다.
        scrollView.hasHorizontalScroller = !wordWrap
        textView.textContainer?.widthTracksTextView = wordWrap
        textView.isHorizontallyResizable = !wordWrap
        let unbounded = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        if wordWrap {
            let width = scrollView.contentSize.width
            textView.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
            // wrap: 텍스트뷰 폭이 클립 폭을 따라가야 한다.
            textView.autoresizingMask = [.width]
        } else {
            textView.textContainer?.containerSize = unbounded
            textView.maxSize = unbounded
            // 비-wrap: 콘텐츠가 클립보다 넓어질 수 있어야 하므로 폭을 묶지 않는다.
            textView.autoresizingMask = []
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(documentID: documentID, tabManager: tabManager)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let documentID: UUID
        weak var tabManager: TabManager?
        weak var textView: NSTextView?
        private var lastHandledCommandID: UUID?

        init(documentID: UUID, tabManager: TabManager) {
            self.documentID = documentID
            self.tabManager = tabManager
        }

        // MARK: Delegate

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            tabManager?.updateContent(for: documentID, newContent: textView.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateCursor(for: textView)
        }

        // MARK: Pending commands

        func handlePendingCommandIfNeeded() {
            guard let command = tabManager?.pendingEditorCommand,
                  command.documentID == documentID,
                  command.id != lastHandledCommandID,
                  let textView else { return }
            lastHandledCommandID = command.id

            switch command.action {
            case let .find(search, matchCase, forward, wrap):
                find(search: search, matchCase: matchCase, forward: forward, wrap: wrap, in: textView)
            case let .replaceCurrent(search, replacement, matchCase):
                replaceCurrent(search: search, with: replacement, matchCase: matchCase, in: textView)
            case let .replaceAll(search, replacement, matchCase):
                replaceAll(search: search, with: replacement, matchCase: matchCase, in: textView)
            case let .insertText(text):
                insert(text, in: textView)
            case let .setText(text):
                setEntireText(text, in: textView)
            case let .goToLine(line):
                goToLine(line, in: textView)
            case .printDocument:
                printText(in: textView)
            }

            // 일회성 명령을 소비한다. 탭 전환 시 .id로 Coordinator가 재생성되면
            // lastHandledCommandID가 초기화되어 같은 명령이 다시 실행되는 것을 방지.
            // (@Published를 뷰 업데이트 중에 변경하지 않도록 비동기로 클리어)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.tabManager?.pendingEditorCommand?.id == command.id {
                    self.tabManager?.pendingEditorCommand = nil
                }
            }
        }

        // MARK: Find / Replace

        private func find(search: String, matchCase: Bool, forward: Bool, wrap: Bool, in textView: NSTextView) {
            guard let range = findRange(search: search, matchCase: matchCase, forward: forward, wrap: wrap, in: textView) else {
                NSSound.beep()
                return
            }
            selectAndReveal(range, in: textView)
        }

        private func replaceCurrent(search: String, with replacement: String, matchCase: Bool, in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            let target: NSRange?
            if selection(selectedRange, matches: search, matchCase: matchCase, in: textView) {
                target = selectedRange
            } else {
                target = findRange(search: search, matchCase: matchCase, forward: true, in: textView)
            }
            guard let range = target else { NSSound.beep(); return }

            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()

            let nextStart = range.location + (replacement as NSString).length
            if let next = findRange(search: search, matchCase: matchCase, forward: true, in: textView, startOverride: nextStart) {
                selectAndReveal(next, in: textView)
            } else {
                selectAndReveal(NSRange(location: range.location, length: (replacement as NSString).length), in: textView)
            }
        }

        private func replaceAll(search: String, with replacement: String, matchCase: Bool, in textView: NSTextView) {
            let nsText = textView.string as NSString
            guard nsText.length > 0 else { NSSound.beep(); return }
            let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive

            // 발생 횟수 확인 (없으면 beep)
            let firstMatch = nsText.range(of: search, options: options)
            guard firstMatch.location != NSNotFound else { NSSound.beep(); return }

            let newString = nsText.replacingOccurrences(
                of: search, with: replacement, options: options,
                range: NSRange(location: 0, length: nsText.length)
            )
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard textView.shouldChangeText(in: fullRange, replacementString: newString) else { return }
            textView.textStorage?.replaceCharacters(in: fullRange, with: newString)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            updateCursor(for: textView)
        }

        private func findRange(
            search: String,
            matchCase: Bool,
            forward: Bool,
            wrap: Bool = true,
            in textView: NSTextView,
            startOverride: Int? = nil
        ) -> NSRange? {
            guard !search.isEmpty else { return nil }
            let nsText = textView.string as NSString
            guard nsText.length > 0 else { return nil }

            let selectedRange = textView.selectedRange()
            var options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive

            if forward {
                let start = min(max(0, startOverride ?? (selectedRange.length > 0 ? NSMaxRange(selectedRange) : selectedRange.location)), nsText.length)
                let forwardRange = NSRange(location: start, length: nsText.length - start)
                let found = nsText.range(of: search, options: options, range: forwardRange)
                if found.location != NSNotFound { return found }
                guard wrap else { return nil }
                let wrapped = nsText.range(of: search, options: options, range: NSRange(location: 0, length: start))
                return wrapped.location == NSNotFound ? nil : wrapped
            } else {
                options.insert(.backwards)
                let end = min(max(0, startOverride ?? selectedRange.location), nsText.length)
                let backRange = NSRange(location: 0, length: end)
                let found = nsText.range(of: search, options: options, range: backRange)
                if found.location != NSNotFound { return found }
                guard wrap else { return nil }
                let wrapped = nsText.range(of: search, options: options, range: NSRange(location: end, length: nsText.length - end))
                return wrapped.location == NSNotFound ? nil : wrapped
            }
        }

        private func selection(_ range: NSRange, matches search: String, matchCase: Bool, in textView: NSTextView) -> Bool {
            guard range.length > 0 else { return false }
            let nsText = textView.string as NSString
            guard NSMaxRange(range) <= nsText.length else { return false }
            let selectedText = nsText.substring(with: range) as NSString
            let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive
            return selectedText.compare(search, options: options) == .orderedSame
        }

        // MARK: Insert / replace whole / go to line

        private func insert(_ text: String, in textView: NSTextView) {
            let range = textView.selectedRange()
            guard textView.shouldChangeText(in: range, replacementString: text) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: text)
            textView.didChangeText()
            let newLocation = range.location + (text as NSString).length
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            textView.scrollRangeToVisible(textView.selectedRange())
            updateCursor(for: textView)
        }

        /// 전체 텍스트 교체(인코딩 다시 열기). 모델은 이미 갱신되어 있으므로
        /// dirty를 만들지 않도록 string 직접 대입(실행취소 비대상).
        private func setEntireText(_ text: String, in textView: NSTextView) {
            guard textView.string != text else { return }
            textView.string = text
            // 디스크에서 다시 읽은 것이므로 이전 버퍼 기준의 실행취소 기록을 비운다.
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            updateCursor(for: textView)
        }

        private func goToLine(_ line: Int, in textView: NSTextView) {
            let location = locationForLine(line, in: textView.string)
            selectAndReveal(NSRange(location: location, length: 0), in: textView)
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

        // MARK: Print

        private func printText(in textView: NSTextView) {
            let printInfo = NSPrintInfo.shared
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            let pageWidth = max(72, printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin)

            let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: .greatestFiniteMagnitude))
            printView.isVerticallyResizable = true
            printView.isHorizontallyResizable = false
            printView.textContainer?.containerSize = NSSize(width: pageWidth, height: .greatestFiniteMagnitude)
            printView.textContainer?.widthTracksTextView = true
            printView.font = textView.font
            printView.string = textView.string

            let operation = NSPrintOperation(view: printView, printInfo: printInfo)
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            operation.run()
        }

        // MARK: Selection helpers

        private func selectAndReveal(_ range: NSRange, in textView: NSTextView) {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            updateCursor(for: textView)
        }

        private func updateCursor(for textView: NSTextView) {
            let nsText = textView.string as NSString
            let selected = textView.selectedRange()
            let loc = min(selected.location, nsText.length)
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
            tabManager?.updateCursor(line: line, col: col, selectionLength: selected.length)
        }
    }
}
