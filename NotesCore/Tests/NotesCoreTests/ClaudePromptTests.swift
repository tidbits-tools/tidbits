import XCTest
@testable import NotesCore

final class ClaudePromptTests: XCTestCase {

    // MARK: - notesDirectory

    func testNotesDirectory_PointsToApplicationSupport() {
        XCTAssertTrue(ClaudePrompt.notesDirectory.contains("Application Support/TidbitsLocal"))
    }

    func testNotesDirectory_DoesNotEndWithJSON() {
        XCTAssertFalse(ClaudePrompt.notesDirectory.hasSuffix(".json"))
    }

    // MARK: - allNotes

    func testAllNotes_ContainsIndexPath() {
        let prompt = ClaudePrompt.allNotes()
        XCTAssertTrue(prompt.contains("index.json"))
    }

    func testAllNotes_ContainsPagesDirectory() {
        let prompt = ClaudePrompt.allNotes()
        XCTAssertTrue(prompt.contains("pages/"))
    }

    func testAllNotes_ContainsReadInstruction() {
        let prompt = ClaudePrompt.allNotes()
        XCTAssertTrue(prompt.hasPrefix("Read my notes"))
    }

    func testAllNotes_MentionsPages() {
        let prompt = ClaudePrompt.allNotes()
        XCTAssertTrue(prompt.contains("pages"))
    }

    func testAllNotes_IsStable() {
        XCTAssertEqual(ClaudePrompt.allNotes(), ClaudePrompt.allNotes())
    }

    func testAllNotes_ExactPaths() {
        let prompt = ClaudePrompt.allNotes()
        XCTAssertTrue(prompt.contains("~/Library/Application Support/TidbitsLocal/index.json"))
        XCTAssertTrue(prompt.contains("~/Library/Application Support/TidbitsLocal/pages/"))
    }

    // MARK: - page

    func testPage_ContainsTitle() {
        let prompt = ClaudePrompt.page(title: "Daily Journal")
        XCTAssertTrue(prompt.contains("\"Daily Journal\""))
    }

    func testPage_WithSlug_ContainsDirectPath() {
        let prompt = ClaudePrompt.page(title: "Daily Journal", slug: "daily-journal")
        XCTAssertTrue(prompt.contains("daily-journal.json"))
        XCTAssertFalse(prompt.contains("index.json"), "Should not need index fallback when slug is provided")
    }

    func testPage_WithoutSlug_FallsBackToIndex() {
        let prompt = ClaudePrompt.page(title: "Test")
        XCTAssertTrue(prompt.contains("index.json"))
        XCTAssertTrue(prompt.contains("{slug}.json"))
    }

    func testPage_ContainsReadInstruction() {
        let prompt = ClaudePrompt.page(title: "Test", slug: "test")
        XCTAssertTrue(prompt.hasPrefix("Read the page"))
    }

    func testPage_QuotesTitleProperly() {
        let prompt = ClaudePrompt.page(title: "My \"Special\" Page", slug: "my-special-page")
        XCTAssertTrue(prompt.contains("My \"Special\" Page"))
    }

    func testPage_HandlesEmptyTitle() {
        let prompt = ClaudePrompt.page(title: "", slug: "untitled")
        XCTAssertTrue(prompt.contains("untitled.json"))
    }

    func testPage_HandlesLongTitle() {
        let longTitle = String(repeating: "a", count: 1000)
        let prompt = ClaudePrompt.page(title: longTitle, slug: "aaa")
        XCTAssertTrue(prompt.contains(longTitle))
    }

    func testPage_ExactPath_WithSlug() {
        let prompt = ClaudePrompt.page(title: "HN thinking", slug: "hn-thinking")
        XCTAssertTrue(prompt.contains("~/Library/Application Support/TidbitsLocal/pages/hn-thinking.json"))
    }

    func testPage_CollisionSlug_UsesProvidedSlug() {
        // If the store resolved a collision suffix, the prompt should use it
        let prompt = ClaudePrompt.page(title: "Duplicate", slug: "duplicate-2")
        XCTAssertTrue(prompt.contains("duplicate-2.json"))
        XCTAssertFalse(prompt.contains("index.json"))
    }
}
