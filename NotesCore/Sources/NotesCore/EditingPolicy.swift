import Foundation

/// Pure logic for managing which snippet is being edited in a document.
/// Extracted from ContentView so it can be unit tested in NotesCore.
public struct EditingState {
    public var editingSnippetID: String?

    public init(editingSnippetID: String? = nil) {
        self.editingSnippetID = editingSnippetID
    }

    /// Stop editing the current snippet (e.g. click outside, escape).
    public mutating func stopEditing() {
        editingSnippetID = nil
    }

    /// Returns true if the given snippet is being edited.
    public func isEditing(_ snippetID: String) -> Bool {
        editingSnippetID == snippetID
    }

    /// Handle a background tap — should dismiss any active editing.
    public mutating func handleBackgroundTap() {
        editingSnippetID = nil
    }

    /// Handle a page change — should dismiss any active editing.
    public mutating func handlePageChange() {
        editingSnippetID = nil
    }

    /// Handle delete — should dismiss editing before deletion.
    public mutating func handleDelete(_ snippetID: String) {
        if editingSnippetID == snippetID {
            editingSnippetID = nil
        }
    }

    /// Handle tapping a different snippet — should switch editing to the new one.
    public mutating func handleSnippetTap(_ snippetID: String) {
        editingSnippetID = snippetID
    }
}
