import Foundation

/// What the app should do when the user closes the main window.
public enum WindowCloseAction: Equatable {
    /// Window is in full-screen — exit full-screen first, then hide once the transition completes.
    case exitFullScreenThenHide
    /// Window is in normal mode — hide it immediately.
    case hide
}

/// Decides how to handle the main window close button.
///
/// The app hides instead of closing so it stays alive in the menu bar.
/// But if the window is in full-screen mode, calling `orderOut` without
/// exiting full-screen first leaves an empty black full-screen Space.
/// The user gets stuck on a blank screen with no way to interact.
public enum WindowClosePolicy {

    public static func action(isFullScreen: Bool) -> WindowCloseAction {
        isFullScreen ? .exitFullScreenThenHide : .hide
    }
}
