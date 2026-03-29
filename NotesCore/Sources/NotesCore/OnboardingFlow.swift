import AppKit

public enum OnboardingFlow {
    public static let completedKey = "hasCompletedOnboarding"
    public static let totalSteps = 4

    /// The SF Symbol names used for hotkey key caps.
    /// "period" is NOT a valid SF Symbol — use Text(".") for the period key.
    public static let hotkeySymbols: [String] = ["command", "shift"]



    /// The period key is rendered as text, not an SF Symbol.
    public static let periodKeyText = "."

    // MARK: - Accessibility step content

    public static func accessibilityTitle(granted: Bool) -> String {
        granted ? "Permission Granted" : "Accessibility Permission"
    }

    public static func accessibilitySubtitle(granted: Bool) -> String {
        granted
            ? "The global hotkey is ready to use."
            : "To capture text, Tidbits simulates Cmd+C \u{2014} macOS requires Accessibility permission for this."
    }

    public static func accessibilityIcon(granted: Bool) -> String {
        granted ? "checkmark.shield.fill" : "shield.lefthalf.filled"
    }

    public static func accessibilityNavLabel(granted: Bool) -> String {
        granted ? "Continue" : "Skip for Now"
    }

    /// Always starts at the welcome step.
    public static let initialStep = 0

    // MARK: - Onboarding window config

    /// The onboarding window must join all spaces so it follows the user
    /// when System Settings opens on the desktop from a fullscreen space.
    /// Without this, the window gets stranded in the fullscreen space.
    public static let onboardingWindowCollectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces]

    /// Whether the back button should be shown on a given step.
    public static func showBack(step: Int) -> Bool {
        // Must be between first and last step
        guard step > 0 && step < totalSteps - 1 else { return false }
        return true
    }
}
