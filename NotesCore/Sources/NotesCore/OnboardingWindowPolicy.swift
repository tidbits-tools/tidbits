import Foundation

/// Defines window operations needed during onboarding accessibility flow.
public protocol OnboardingWindowOperations {
    func hideWindow()
    func showWindowAndActivate()
}

/// Encapsulates the onboarding window behavior when requesting accessibility permission.
///
/// When the user clicks "Open System Settings":
/// - The onboarding window must hide so it doesn't cover System Settings
///
/// When accessibility is granted (detected by polling):
/// - The onboarding window must reappear and activate
///
/// This sequence prevents the onboarding window from covering System Settings
/// on all spaces (since the window uses canJoinAllSpaces).
public enum OnboardingWindowPolicy {

    /// Called when the user clicks "Open System Settings".
    /// Hides the onboarding window so System Settings is accessible.
    public static func didRequestSystemSettings(ops: OnboardingWindowOperations) {
        ops.hideWindow()
    }

    /// Called when accessibility permission is detected as granted.
    /// Brings the onboarding window back to show the success state.
    public static func didGrantAccessibility(ops: OnboardingWindowOperations) {
        ops.showWindowAndActivate()
    }
}
