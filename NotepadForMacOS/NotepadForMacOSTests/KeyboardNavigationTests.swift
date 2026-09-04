import XCTest
import AppKit
@testable import Notepad

@MainActor
final class KeyboardNavigationTests: XCTestCase {

    private func createConfiguredTextView(text: String) -> (NSWindow, NSScrollView, NotepadTextView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NotepadTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = textView
        window.contentView = scrollView
        textView.string = text
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        if let container = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: container)
        }
        return (window, scrollView, textView)
    }

    private func sendKeyEvent(
        to textView: NotepadTextView,
        keyCode: UInt16,
        specialKey: NSEvent.SpecialKey,
        modifiers: NSEvent.ModifierFlags = []
    ) {
        let char = unichar(specialKey.rawValue)
        let s = String(UnicodeScalar(char)!)
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers.union([.function]),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: s,
            charactersIgnoringModifiers: s,
            isARepeat: false,
            keyCode: keyCode
        )!
        textView.keyDown(with: event)
    }

    func testHomeMovesCursorToBeginningOfLine() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        // Set cursor in the middle of second line: "Second line has| more words"
        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 115, specialKey: .home)

        // Line 2 starts at index 11 ("First line\n" is 11 chars)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 11, length: 0))
    }

    func testEndMovesCursorToEndOfLine() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        // Set cursor at start of second line
        tv.setSelectedRange(NSRange(location: 11, length: 0))
        sendKeyEvent(to: tv, keyCode: 119, specialKey: .end)

        // Line 2 ends at index 37 (11 + 26)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 37, length: 0))
    }

    func testShiftHomeSelectsToBeginningOfLine() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 115, specialKey: .home, modifiers: [.shift])

        // Selected from index 11 to 26 (length 15)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 11, length: 15))
    }

    func testShiftEndSelectsToEndOfLine() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 119, specialKey: .end, modifiers: [.shift])

        // Selected from index 26 to 37 (length 11)
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 26, length: 11))
    }

    func testCommandHomeMovesToBeginningOfDocument() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 115, specialKey: .home, modifiers: [.command])

        XCTAssertEqual(tv.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testCommandEndMovesToEndOfDocument() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        tv.setSelectedRange(NSRange(location: 5, length: 0))
        sendKeyEvent(to: tv, keyCode: 119, specialKey: .end, modifiers: [.command])

        let totalLength = (text as NSString).length
        XCTAssertEqual(tv.selectedRange(), NSRange(location: totalLength, length: 0))
    }

    func testControlHomeAndEndForWindowsKeyboardFamiliarity() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        // Ctrl + End -> Document end
        tv.setSelectedRange(NSRange(location: 5, length: 0))
        sendKeyEvent(to: tv, keyCode: 119, specialKey: .end, modifiers: [.control])
        let totalLength = (text as NSString).length
        XCTAssertEqual(tv.selectedRange(), NSRange(location: totalLength, length: 0))

        // Ctrl + Home -> Document start
        sendKeyEvent(to: tv, keyCode: 115, specialKey: .home, modifiers: [.control])
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testCommandShiftHomeAndEndSelectsToDocumentExtremes() {
        let text = "First line\nSecond line has more words\nThird line"
        let (_, _, tv) = createConfiguredTextView(text: text)

        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 115, specialKey: .home, modifiers: [.command, .shift])
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 0, length: 26))

        tv.setSelectedRange(NSRange(location: 26, length: 0))
        sendKeyEvent(to: tv, keyCode: 119, specialKey: .end, modifiers: [.command, .shift])
        let totalLength = (text as NSString).length
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 26, length: totalLength - 26))
    }

    func testPageDownAndPageUpMovesCursorInLongDocument() {
        var longText = ""
        for i in 1...200 {
            longText += "Line \(i): A sentence for filling page height to test scrolling and cursor navigation.\n"
        }
        let (_, _, tv) = createConfiguredTextView(text: longText)

        tv.setSelectedRange(NSRange(location: 0, length: 0))
        sendKeyEvent(to: tv, keyCode: 121, specialKey: .pageDown)

        // Cursor should have moved forward significantly (greater than 0)
        let firstPageDownLocation = tv.selectedRange().location
        XCTAssertGreaterThan(firstPageDownLocation, 0, "PageDown must advance cursor position")

        // Another PageDown advances further
        sendKeyEvent(to: tv, keyCode: 121, specialKey: .pageDown)
        let secondPageDownLocation = tv.selectedRange().location
        XCTAssertGreaterThan(secondPageDownLocation, firstPageDownLocation)

        // PageUp moves cursor back
        sendKeyEvent(to: tv, keyCode: 116, specialKey: .pageUp)
        let pageUpLocation = tv.selectedRange().location
        XCTAssertLessThan(pageUpLocation, secondPageDownLocation)
    }

    func testShiftPageDownAndPageUpModifiesSelection() {
        var longText = ""
        for i in 1...200 {
            longText += "Line \(i): A sentence for filling page height to test scrolling and cursor navigation.\n"
        }
        let (_, _, tv) = createConfiguredTextView(text: longText)

        tv.setSelectedRange(NSRange(location: 0, length: 0))
        sendKeyEvent(to: tv, keyCode: 121, specialKey: .pageDown, modifiers: [.shift])

        let range = tv.selectedRange()
        XCTAssertEqual(range.location, 0)
        XCTAssertGreaterThan(range.length, 0, "Shift+PageDown should select text")
    }
}
