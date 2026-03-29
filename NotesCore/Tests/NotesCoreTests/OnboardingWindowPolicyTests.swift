import XCTest
@testable import NotesCore

/// Regression tests for the onboarding window hide/show sequence.
///
/// The onboarding window uses canJoinAllSpaces so it follows the user across
/// spaces (including when System Settings opens on the desktop from a fullscreen
/// space). Without the hide/show sequence, the onboarding window covers System
/// Settings on every space, making it impossible to toggle Accessibility permission.
///
/// The correct behavior:
/// 1. User clicks "Open System Settings" → onboarding window hides
/// 2. User toggles Accessibility in System Settings
/// 3. Polling detects grant → onboarding window reappears with green checkmark
final class OnboardingWindowPolicyTests: XCTestCase {

    private class MockWindowOps: OnboardingWindowOperations {
        var calls: [String] = []

        func hideWindow() { calls.append("hideWindow") }
        func showWindowAndActivate() { calls.append("showWindowAndActivate") }
    }

    // MARK: - Open System Settings

    func testDidRequestSystemSettings_HidesWindow() {
        let mock = MockWindowOps()
        OnboardingWindowPolicy.didRequestSystemSettings(ops: mock)
        XCTAssertEqual(mock.calls, ["hideWindow"],
            "Window must hide when System Settings is opened so it doesn't cover the settings UI")
    }

    func testDidRequestSystemSettings_DoesNotShow() {
        let mock = MockWindowOps()
        OnboardingWindowPolicy.didRequestSystemSettings(ops: mock)
        XCTAssertFalse(mock.calls.contains("showWindowAndActivate"),
            "Window must not reappear when opening System Settings")
    }

    // MARK: - Accessibility Granted

    func testDidGrantAccessibility_ShowsAndActivates() {
        let mock = MockWindowOps()
        OnboardingWindowPolicy.didGrantAccessibility(ops: mock)
        XCTAssertEqual(mock.calls, ["showWindowAndActivate"],
            "Window must reappear and activate when accessibility is granted")
    }

    func testDidGrantAccessibility_DoesNotHide() {
        let mock = MockWindowOps()
        OnboardingWindowPolicy.didGrantAccessibility(ops: mock)
        XCTAssertFalse(mock.calls.contains("hideWindow"),
            "Window must not hide when accessibility is granted")
    }

    // MARK: - Full Sequence

    func testFullSequence_HideThenShow() {
        let mock = MockWindowOps()
        OnboardingWindowPolicy.didRequestSystemSettings(ops: mock)
        OnboardingWindowPolicy.didGrantAccessibility(ops: mock)
        XCTAssertEqual(mock.calls, ["hideWindow", "showWindowAndActivate"],
            "Full sequence: hide when opening settings, show when granted")
    }
}
