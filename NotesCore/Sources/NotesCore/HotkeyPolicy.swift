import Foundation

/// Pure logic for deciding whether a hotkey event should trigger text capture.
/// Extracted from HotkeyManager so it can be unit tested in NotesCore.
public enum HotkeyPolicy {
    /// Returns true if the hotkey event should trigger text capture.
    /// - Parameters:
    ///   - isRepeat: Whether the key event is a repeat (held-down key)
    ///   - isPanelVisible: Whether the snippet panel is currently showing
    public static func shouldCapture(isRepeat: Bool, isPanelVisible: Bool) -> Bool {
        guard !isRepeat else { return false }
        guard !isPanelVisible else { return false }
        return true
    }
}
