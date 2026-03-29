import Foundation

/// What the app should do when the user clicks the menu bar icon.
public enum MenuBarClickAction: Equatable {
    /// Onboarding isn't done — bring it to front, don't open the main window.
    case focusOnboarding
    /// Permission prompt is showing but onboarding is done — dismiss it and open the main window.
    case dismissPromptAndShowMain
    /// Main window exists but is hidden — bring it to front.
    case showMain
    /// No main window yet — create and show it.
    case createMain
}

/// Decides what happens when the user clicks the menu bar icon.
///
/// Rules:
/// - During onboarding, the menu bar click resurfaces the onboarding window.
///   The user hasn't finished setup, so the main window isn't appropriate yet.
/// - After onboarding, if the permission prompt is showing (e.g., after a rebuild
///   invalidated TCC), dismiss it and open the main window. The app is fully usable
///   without accessibility — only the hotkey is disabled.
/// - Otherwise, show or create the main window.
public enum MenuBarClickPolicy {

    public static func action(
        isOnboarding: Bool,
        isPermissionPromptShowing: Bool,
        hasMainWindow: Bool
    ) -> MenuBarClickAction {
        if isOnboarding {
            return .focusOnboarding
        }
        if isPermissionPromptShowing {
            return .dismissPromptAndShowMain
        }
        if hasMainWindow {
            return .showMain
        }
        return .createMain
    }
}
