import XCTest
import AppKit
@testable import NotesCore

final class TextParserTests: XCTestCase {

    // MARK: - RTF Parsing Tests (Ghostty regression)

    func testParseRTF_PlainText() {
        let rtfData = makeRTFData("Hello from Ghostty")
        let result = parseRTFToMarkdown(rtfData)
        XCTAssertEqual(result, "Hello from Ghostty")
    }

    func testParseRTF_BoldText() {
        let attributed = NSMutableAttributedString(string: "This is bold text")
        let boldFont = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13), toHaveTrait: .boldFontMask)
        attributed.addAttribute(.font, value: boldFont, range: NSRange(location: 8, length: 4))
        let result = parseRTFToMarkdown(rtfDataFrom(attributed))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("**bold**"), "Expected bold markdown, got: \(result!)")
    }

    func testParseRTF_ItalicText() {
        let attributed = NSMutableAttributedString(string: "This is italic text")
        let italicFont = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
        attributed.addAttribute(.font, value: italicFont, range: NSRange(location: 8, length: 6))
        let result = parseRTFToMarkdown(rtfDataFrom(attributed))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("*italic*"), "Expected italic markdown, got: \(result!)")
    }

    func testParseRTF_ReturnsNilForEmptyData() {
        let result = parseRTFToMarkdown(Data())
        XCTAssertNil(result)
    }

    func testParseRTF_ReturnsNilForGarbageData() {
        let result = parseRTFToMarkdown("not rtf at all".data(using: .utf8)!)
        XCTAssertNil(result)
    }

    // MARK: - RTF Helpers

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

    // MARK: - HTML Parsing Tests
    
    func testParseHTML_PlainText() {
        let result = parseHTMLToMarkdown("Hello world")
        XCTAssertEqual(result, "Hello world")
    }
    
    func testParseHTML_StrongToBold() {
        let result = parseHTMLToMarkdown("<p>This is <strong>bold</strong> text</p>")
        XCTAssertEqual(result, "This is **bold** text")
    }
    
    func testParseHTML_BToBold() {
        let result = parseHTMLToMarkdown("<p>This is <b>bold</b> text</p>")
        XCTAssertEqual(result, "This is **bold** text")
    }
    
    func testParseHTML_EmToItalic() {
        let result = parseHTMLToMarkdown("<p>This is <em>italic</em> text</p>")
        XCTAssertEqual(result, "This is *italic* text")
    }
    
    func testParseHTML_IToItalic() {
        let result = parseHTMLToMarkdown("<p>This is <i>italic</i> text</p>")
        XCTAssertEqual(result, "This is *italic* text")
    }
    
    func testParseHTML_UnorderedList() {
        let html = "<ul><li>First item</li><li>Second item</li></ul>"
        let result = parseHTMLToMarkdown(html)
        XCTAssertTrue(result.contains("• First item"))
        XCTAssertTrue(result.contains("• Second item"))
    }
    
    func testParseHTML_OrderedList() {
        let html = "<ol><li>First item</li><li>Second item</li></ol>"
        let result = parseHTMLToMarkdown(html)
        XCTAssertTrue(result.contains("• First item"))
        XCTAssertTrue(result.contains("• Second item"))
    }
    
    func testParseHTML_ListWithFormatting() {
        let html = "<ol><li><strong>Bold item</strong></li><li>Normal item</li></ol>"
        let result = parseHTMLToMarkdown(html)
        XCTAssertTrue(result.contains("• **Bold item**"))
        XCTAssertTrue(result.contains("• Normal item"))
    }
    
    func testParseHTML_BreakTags() {
        let result = parseHTMLToMarkdown("Line one<br>Line two<br/>Line three")
        XCTAssertTrue(result.contains("Line one"))
        XCTAssertTrue(result.contains("Line two"))
        XCTAssertTrue(result.contains("Line three"))
    }
    
    func testParseHTML_ParagraphTags() {
        let result = parseHTMLToMarkdown("<p>Paragraph one</p><p>Paragraph two</p>")
        XCTAssertTrue(result.contains("Paragraph one"))
        XCTAssertTrue(result.contains("Paragraph two"))
    }
    
    func testParseHTML_HTMLEntities() {
        let result = parseHTMLToMarkdown("Tom &amp; Jerry &lt;3 &gt; &quot;quotes&quot;")
        XCTAssertEqual(result, "Tom & Jerry <3 > \"quotes\"")
    }
    
    func testParseHTML_StrongWithAttributes() {
        let result = parseHTMLToMarkdown("<strong data-start=\"1\" data-end=\"10\">bold text</strong>")
        XCTAssertEqual(result, "**bold text**")
    }
    
    func testParseHTML_ComplexChatGPTExample() {
        let html = """
        <ol data-start="1129" data-end="1277">
        <li data-start="1129" data-end="1167">
        <p data-start="1132" data-end="1167"><strong data-start="1132" data-end="1167">The stakes inflate artificially</strong></p>
        </li>
        <li data-start="1168" data-end="1219">
        <p data-start="1171" data-end="1219"><strong data-start="1171" data-end="1219">Your self-worth gets tethered to the outcome</strong></p>
        </li>
        </ol>
        """
        let result = parseHTMLToMarkdown(html)
        // Check that list items have bullets
        XCTAssertTrue(result.contains("•"), "Should contain bullet points")
        // Check that bold formatting is preserved
        XCTAssertTrue(result.contains("**The stakes inflate artificially**"), "Should contain bold text")
        XCTAssertTrue(result.contains("**Your self-worth gets tethered to the outcome**"), "Should contain second bold text")
    }
    
    func testParseHTML_MixedBoldAndItalic() {
        let result = parseHTMLToMarkdown("<p>They feel <strong>less obligation for any single attempt to matter</strong>.</p>")
        XCTAssertEqual(result, "They feel **less obligation for any single attempt to matter**.")
    }
    
    func testParseHTML_NestedTags() {
        let result = parseHTMLToMarkdown("<p><strong><em>Bold and italic</em></strong></p>")
        XCTAssertEqual(result, "***Bold and italic***")
    }

    // MARK: - HTML Entity Edge Cases

    func testParseHTML_NbspEntity() {
        let result = parseHTMLToMarkdown("hello&nbsp;world")
        XCTAssertEqual(result, "hello world")
    }

    func testParseHTML_AposEntity() {
        let result1 = parseHTMLToMarkdown("it&#39;s")
        XCTAssertEqual(result1, "it's")
        let result2 = parseHTMLToMarkdown("it&apos;s")
        XCTAssertEqual(result2, "it's")
    }

    func testParseHTML_EmptyString() {
        let result = parseHTMLToMarkdown("")
        XCTAssertEqual(result, "")
    }

    func testParseHTML_OnlyWhitespace() {
        let result = parseHTMLToMarkdown("   ")
        XCTAssertEqual(result, "")
    }

    // MARK: - Whitespace Cleanup

    func testCleanupWhitespace_MultipleBlankLines() {
        let html = "<p>First</p><p></p><p></p><p></p><p>Second</p>"
        let result = parseHTMLToMarkdown(html)
        // Multiple blank lines should collapse
        XCTAssertFalse(result.contains("\n\n\n"), "Should not have 3+ consecutive newlines")
        XCTAssertTrue(result.contains("First"))
        XCTAssertTrue(result.contains("Second"))
    }

    func testCleanupWhitespace_LeadingTrailingTrimmed() {
        let html = "<p></p><p>Content</p><p></p>"
        let result = parseHTMLToMarkdown(html)
        XCTAssertFalse(result.hasPrefix("\n"))
        XCTAssertFalse(result.hasSuffix("\n"))
        XCTAssertTrue(result.contains("Content"))
    }

    // MARK: - HTML Block Elements

    func testParseHTML_DivTags() {
        let result = parseHTMLToMarkdown("<div>First</div><div>Second</div>")
        XCTAssertTrue(result.contains("First"))
        XCTAssertTrue(result.contains("Second"))
        // Divs should produce newlines between them
        XCTAssertNotEqual(result, "FirstSecond")
    }
}

