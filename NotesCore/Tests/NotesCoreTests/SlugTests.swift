import XCTest
@testable import NotesCore

final class SlugTests: XCTestCase {

    // MARK: - Basic

    func testBasic() {
        XCTAssertEqual(slugify("Hello World"), "hello-world")
    }

    func testLowercase() {
        XCTAssertEqual(slugify("ALL CAPS"), "all-caps")
    }

    // MARK: - Special character replacements

    func testApostrophe() {
        // Apostrophe is non-alphanumeric, replaced by hyphen
        XCTAssertEqual(slugify("It\u{2019}s a test"), "it-s-a-test")
        XCTAssertEqual(slugify("It's a test"), "it-s-a-test")
    }

    func testPlusWithSpaces() {
        XCTAssertEqual(slugify("confidence + belief"), "confidence-plus-belief")
    }

    func testPlusWithoutSpaces() {
        // Literal replacement, no separator insertion
        XCTAssertEqual(slugify("C++"), "cplusplus")
        XCTAssertEqual(slugify("a+b"), "aplusb")
    }

    func testAmpersand() {
        XCTAssertEqual(slugify("A & B"), "a-and-b")
    }

    func testSpecialChars() {
        XCTAssertEqual(slugify("What?! Really..."), "what-really")
    }

    // MARK: - Edge cases

    func testEmptyString() {
        XCTAssertEqual(slugify(""), "untitled")
    }

    func testAllSpecialChars() {
        XCTAssertEqual(slugify("!!!"), "untitled")
    }

    func testHyphenCollapsing() {
        XCTAssertEqual(slugify("a---b"), "a-b")
    }

    func testLeadingTrailingHyphens() {
        XCTAssertEqual(slugify("--test--"), "test")
    }

    func testUnicodeCombiningChars() {
        // cafe + combining acute accent → cafe (accent stripped)
        XCTAssertEqual(slugify("caf\u{00E9}"), "cafe")
    }

    func testTruncation() {
        let longTitle = String(repeating: "a", count: 250)
        let slug = slugify(longTitle)
        XCTAssertLessThanOrEqual(slug.count, 200)
    }

    func testTruncationDoesNotLeaveTrailingHyphen() {
        // 200 a's followed by a hyphen and more text
        let title = String(repeating: "a", count: 199) + " " + String(repeating: "b", count: 50)
        let slug = slugify(title)
        XCTAssertFalse(slug.hasSuffix("-"))
    }

    // MARK: - Path traversal safety (audit regression)

    func testPathTraversal_DoubleDot() {
        XCTAssertEqual(slugify(".."), "untitled")
    }

    func testPathTraversal_SlashDotDot() {
        XCTAssertEqual(slugify("../../etc/passwd"), "etc-passwd")
    }

    func testPathTraversal_ForwardSlash() {
        let slug = slugify("a/b/c")
        XCTAssertFalse(slug.contains("/"), "Slug must not contain forward slashes")
    }

    func testPathTraversal_NullByte() {
        let slug = slugify("test\0evil")
        XCTAssertFalse(slug.contains("\0"), "Slug must not contain null bytes")
    }

    func testPathTraversal_Backslash() {
        let slug = slugify("a\\b")
        XCTAssertFalse(slug.contains("\\"), "Slug must not contain backslashes")
    }

    // MARK: - Real page titles from the app

    func testRealTitle_Confidence() {
        XCTAssertEqual(
            slugify("It\u{2019}s a confidence + self-belief issue"),
            "it-s-a-confidence-plus-self-belief-issue"
        )
    }

    func testRealTitle_IdentitiesAreMessy() {
        XCTAssertEqual(slugify("Identities are messy"), "identities-are-messy")
    }

    func testRealTitle_ShippingSmall() {
        XCTAssertEqual(slugify("Shipping small"), "shipping-small")
    }

    func testRealTitle_GrassIsGreener() {
        XCTAssertEqual(slugify("Grass is greener"), "grass-is-greener")
    }

    func testRealTitle_HNThinking() {
        XCTAssertEqual(slugify("HN thinking"), "hn-thinking")
    }

    func testRealTitle_DevToolingNiche() {
        XCTAssertEqual(slugify("Dev tooling niche?"), "dev-tooling-niche")
    }

    func testRealTitle_WhatIsEnough() {
        XCTAssertEqual(slugify("What is enough?"), "what-is-enough")
    }

    func testRealTitle_8ballThoughts() {
        XCTAssertEqual(slugify("8ball thoughts"), "8ball-thoughts")
    }

    func testRealTitle_CarrdThinking() {
        XCTAssertEqual(slugify("Carrd thinking"), "carrd-thinking")
    }

    func testRealTitle_TestWithNumbers() {
        XCTAssertEqual(slugify("test 2333"), "test-2333")
    }
}
