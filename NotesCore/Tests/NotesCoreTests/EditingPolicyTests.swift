import XCTest
@testable import NotesCore

final class EditingPolicyTests: XCTestCase {

    // MARK: - Initial state

    func testInitialStateHasNothingEditing() {
        let state = EditingState()
        XCTAssertNil(state.editingSnippetID)
    }

    // MARK: - Start editing

    func testTappingSnippetStartsEditing() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        XCTAssertTrue(state.isEditing("snippet-1"))
        XCTAssertEqual(state.editingSnippetID, "snippet-1")
    }

    func testTappingDifferentSnippetSwitchesEditing() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handleSnippetTap("snippet-2")
        XCTAssertFalse(state.isEditing("snippet-1"))
        XCTAssertTrue(state.isEditing("snippet-2"))
    }

    func testOnlyOneSnippetCanBeEditedAtATime() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handleSnippetTap("snippet-2")
        XCTAssertFalse(state.isEditing("snippet-1"))
        XCTAssertTrue(state.isEditing("snippet-2"))
    }

    // MARK: - Stop editing

    func testStopEditingClearsState() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.stopEditing()
        XCTAssertNil(state.editingSnippetID)
        XCTAssertFalse(state.isEditing("snippet-1"))
    }

    // MARK: - Background tap

    func testBackgroundTapExitsEditMode() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handleBackgroundTap()
        XCTAssertNil(state.editingSnippetID)
    }

    func testBackgroundTapWhenNotEditingIsNoOp() {
        var state = EditingState()
        state.handleBackgroundTap()
        XCTAssertNil(state.editingSnippetID)
    }

    // MARK: - Page change

    func testPageChangeExitsEditMode() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handlePageChange()
        XCTAssertNil(state.editingSnippetID)
    }

    // MARK: - Delete

    func testDeletingEditedSnippetExitsEditMode() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handleDelete("snippet-1")
        XCTAssertNil(state.editingSnippetID)
    }

    func testDeletingDifferentSnippetDoesNotExitEditMode() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        state.handleDelete("snippet-2")
        XCTAssertTrue(state.isEditing("snippet-1"))
    }

    // MARK: - isEditing

    func testIsEditingReturnsFalseForNonEditingSnippet() {
        var state = EditingState()
        state.handleSnippetTap("snippet-1")
        XCTAssertFalse(state.isEditing("snippet-2"))
    }

    func testIsEditingReturnsFalseWhenNothingEditing() {
        let state = EditingState()
        XCTAssertFalse(state.isEditing("snippet-1"))
    }
}
