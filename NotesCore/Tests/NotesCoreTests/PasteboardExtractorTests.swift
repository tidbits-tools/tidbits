import XCTest
import AppKit
@testable import NotesCore

final class PasteboardExtractorTests: XCTestCase {

    // Use a private pasteboard to avoid polluting the system clipboard
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: .init("tools.tidbits.test"))
        pasteboard.clearContents()
    }

    override func tearDown() {
        pasteboard.clearContents()
        NSPasteboard.releaseGlobally(pasteboard)
        super.tearDown()
    }

    // MARK: - Extraction Priority Order

    func testExtractsRTFOverPlainText() {
        // Ghostty scenario: both RTF and plain text on pasteboard, RTF should win
        let plainText = "plain version"
        let rtfText = "rtf version"
        let rtfData = makeRTFData(rtfText)

        pasteboard.declareTypes([.rtf, .string], owner: nil)
        pasteboard.setData(rtfData, forType: .rtf)
        pasteboard.setString(plainText, forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "rtf version")
    }

    func testExtractsHTMLOverPlainText() {
        let htmlString = "<p>This is <strong>bold</strong> text</p>"
        let plainText = "plain fallback"

        pasteboard.declareTypes([.html, .string], owner: nil)
        pasteboard.setData(htmlString.data(using: .utf8)!, forType: .html)
        pasteboard.setString(plainText, forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "This is **bold** text")
    }

    func testExtractsRTFOverHTML() {
        let rtfData = makeRTFData("from rtf")
        let htmlString = "<p>from html</p>"

        pasteboard.declareTypes([.rtf, .html, .string], owner: nil)
        pasteboard.setData(rtfData, forType: .rtf)
        pasteboard.setData(htmlString.data(using: .utf8)!, forType: .html)
        pasteboard.setString("from plain", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "from rtf")
    }

    func testFallsBackToPlainText() {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("just plain text", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "just plain text")
    }

    func testReturnsEmptyForEmptyPasteboard() {
        // No types declared at all
        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "")
    }

    // MARK: - RTF Formatting Preservation

    func testRTFBoldBecomesMarkdown() {
        let attributed = NSMutableAttributedString(string: "This is bold text")
        let boldFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 13), toHaveTrait: .boldFontMask
        )
        attributed.addAttribute(.font, value: boldFont, range: NSRange(location: 8, length: 4))
        let rtfData = rtfDataFrom(attributed)

        pasteboard.declareTypes([.rtf], owner: nil)
        pasteboard.setData(rtfData, forType: .rtf)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertTrue(result.contains("**bold**"), "Expected bold markdown, got: \(result)")
    }

    func testRTFItalicBecomesMarkdown() {
        let attributed = NSMutableAttributedString(string: "This is italic text")
        let italicFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 13), toHaveTrait: .italicFontMask
        )
        attributed.addAttribute(.font, value: italicFont, range: NSRange(location: 8, length: 6))
        let rtfData = rtfDataFrom(attributed)

        pasteboard.declareTypes([.rtf], owner: nil)
        pasteboard.setData(rtfData, forType: .rtf)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertTrue(result.contains("*italic*"), "Expected italic markdown, got: \(result)")
    }

    // MARK: - HTML Formatting Preservation

    func testHTMLListsBecomeBullets() {
        let html = "<ul><li>First</li><li>Second</li></ul>"

        pasteboard.declareTypes([.html], owner: nil)
        pasteboard.setData(html.data(using: .utf8)!, forType: .html)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertTrue(result.contains("• First"), "Expected bullet, got: \(result)")
        XCTAssertTrue(result.contains("• Second"), "Expected bullet, got: \(result)")
    }

    func testHTMLBoldBecomesMarkdown() {
        let html = "<p>Text with <strong>bold</strong> word</p>"

        pasteboard.declareTypes([.html], owner: nil)
        pasteboard.setData(html.data(using: .utf8)!, forType: .html)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "Text with **bold** word")
    }

    // MARK: - Edge Cases

    func testGarbageRTFFallsThrough() {
        // Invalid RTF data should fall through to plain text
        pasteboard.declareTypes([.rtf, .string], owner: nil)
        pasteboard.setData("not rtf".data(using: .utf8)!, forType: .rtf)
        pasteboard.setString("fallback plain", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "fallback plain")
    }

    func testOversizedRTFFallsThrough() {
        // RTF data exceeding maxInputBytes should be skipped
        let hugeString = String(repeating: "a", count: PasteboardTextExtractor.maxInputBytes + 1)
        let hugeRTF = makeRTFData(hugeString)

        pasteboard.declareTypes([.rtf, .string], owner: nil)
        pasteboard.setData(hugeRTF, forType: .rtf)
        pasteboard.setString("small fallback", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "small fallback")
    }

    func testEmptyHTMLFallsThrough() {
        // HTML that parses to empty string should fall through
        let html = "<p>   </p>"

        pasteboard.declareTypes([.html, .string], owner: nil)
        pasteboard.setData(html.data(using: .utf8)!, forType: .html)
        pasteboard.setString("fallback", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "fallback")
    }

    // MARK: - Ghostty Regression

    func testGhosttyStyleRTF_PlainTextInRTFContainer() {
        // Ghostty wraps plain terminal text in RTF. The extracted result
        // should be clean plain text, not RTF artifacts.
        let terminalText = "$ git status\nOn branch main\nnothing to commit"
        let rtfData = makeRTFData(terminalText)

        pasteboard.declareTypes([.rtf], owner: nil)
        pasteboard.setData(rtfData, forType: .rtf)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertTrue(result.contains("git status"), "Should contain terminal text")
        XCTAssertFalse(result.contains("\\rtf"), "Should not contain raw RTF markup")
        XCTAssertFalse(result.contains("{\\"), "Should not contain RTF control sequences")
    }

    // MARK: - Additional Edge Cases

    func testOversizedHTMLFallsThrough() {
        let hugeHTML = "<p>" + String(repeating: "x", count: PasteboardTextExtractor.maxInputBytes + 1) + "</p>"

        pasteboard.declareTypes([.html, .string], owner: nil)
        pasteboard.setData(hugeHTML.data(using: .utf8)!, forType: .html)
        pasteboard.setString("small fallback", forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, "small fallback")
    }

    func testPlainText_WithUnicode() {
        let unicodeText = "Hello 🌍 你好 café"
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(unicodeText, forType: .string)

        let result = PasteboardTextExtractor.extractText(from: pasteboard)
        XCTAssertEqual(result, unicodeText)
    }

    // MARK: - Helpers

    private func makeRTFData(_ plainText: String) -> Data {
        let attributed = NSAttributedString(string: plainText, attributes: [
            .font: NSFont.systemFont(ofSize: 13)
        ])
        return rtfDataFrom(attributed)
    }

    private func rtfDataFrom(_ attributed: NSAttributedString) -> Data {
        let range = NSRange(location: 0, length: attributed.length)
        return attributed.rtf(from: range, documentAttributes: [:])!
    }
}

private extension NSPasteboard {
    /// Release a named pasteboard to free resources
    static func releaseGlobally(_ pasteboard: NSPasteboard) {
        pasteboard.releaseGlobally()
    }
}
