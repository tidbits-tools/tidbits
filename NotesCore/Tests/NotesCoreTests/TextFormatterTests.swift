import XCTest
@testable import NotesCore

final class TextFormatterTests: XCTestCase {

    // MARK: - Curly Quote Replacement

    func testFormat_ReplacesCurlyDoubleQuotes() {
        let input = "\u{201C}Hello\u{201D}"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "\"Hello\"")
    }

    func testFormat_ReplacesCurlySingleQuotes() {
        let input = "\u{2018}Hello\u{2019}"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "'Hello'")
    }

    func testFormat_PreservesExistingStraightQuotes() {
        let input = "\"Hello\" and 'world'"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "\"Hello\" and 'world'")
    }

    func testFormat_OnlyCurlyQuotes() {
        let input = "\u{201C}\u{201D}\u{2018}\u{2019}"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "\"\"''")
    }

    // MARK: - Capitalization

    func testFormat_CapitalizesFirstLetterOfLine() {
        let result = TextFormatter.format("hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testFormat_DoesNotCapitalizeIndentedLines() {
        let result = TextFormatter.format("  bullet point")
        XCTAssertEqual(result, "  bullet point")
    }

    func testFormat_SkipsAlreadyCapitalizedLines() {
        let result = TextFormatter.format("Already Caps")
        XCTAssertEqual(result, "Already Caps")
    }

    func testFormat_CapitalizesAfterNonLetterPrefix() {
        let result = TextFormatter.format("- hello")
        XCTAssertEqual(result, "- Hello")
    }

    func testFormat_MultipleLines() {
        let input = "first line\nsecond line\nthird line"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "First line\nSecond line\nThird line")
    }

    func testFormat_EmptyString() {
        let result = TextFormatter.format("")
        XCTAssertEqual(result, "")
    }

    func testFormat_EmptyLinesPreserved() {
        let input = "first\n\nsecond"
        let result = TextFormatter.format(input)
        XCTAssertEqual(result, "First\n\nSecond")
    }

    func testFormat_LineStartingWithNumber() {
        // capitalizeFirstLetter finds the first letter 'i' and uppercases it
        let result = TextFormatter.format("3 items in the list")
        XCTAssertEqual(result, "3 Items in the list")
    }

    func testFormat_UnicodeFirstLetter() {
        let result = TextFormatter.format("\u{00E9}toile")
        XCTAssertEqual(result, "\u{00C9}toile")
    }

    // MARK: - formatSnippets

    func testFormatSnippets_ReturnsOnlyChanged() {
        let s1 = Snippet.create(text: "Already clean")
        let s2 = Snippet.create(text: "\u{201C}curly\u{201D}")
        let s3 = Snippet.create(text: "Also Clean")

        let changes = TextFormatter.formatSnippets([s1, s2, s3])
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].original.id, s2.id)
        XCTAssertEqual(changes[0].formatted, "\"Curly\"")
    }

    func testFormatSnippets_NoChanges_ReturnsEmpty() {
        let s1 = Snippet.create(text: "Already clean")
        let s2 = Snippet.create(text: "No curly quotes here")
        let changes = TextFormatter.formatSnippets([s1, s2])
        XCTAssertEqual(changes.count, 0)
    }

    func testFormatSnippets_EmptyArray() {
        let changes = TextFormatter.formatSnippets([])
        XCTAssertEqual(changes.count, 0)
    }
}
