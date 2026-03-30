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

    func testAllNotes_ReturnsDirectoryPath() {
        XCTAssertEqual(ClaudePrompt.allNotes(), "~/Library/Application Support/TidbitsLocal")
    }

    func testAllNotes_IsStable() {
        XCTAssertEqual(ClaudePrompt.allNotes(), ClaudePrompt.allNotes())
    }

    // MARK: - page

    func testPage_ReturnsFilePath() {
        let path = ClaudePrompt.page(slug: "daily-journal")
        XCTAssertEqual(path, "~/Library/Application Support/TidbitsLocal/pages/daily-journal.json")
    }

    func testPage_CollisionSlug() {
        let path = ClaudePrompt.page(slug: "duplicate-2")
        XCTAssertTrue(path.contains("duplicate-2.json"))
    }

    func testPage_DoesNotContainIndex() {
        let path = ClaudePrompt.page(slug: "test")
        XCTAssertFalse(path.contains("index.json"))
    }
}
