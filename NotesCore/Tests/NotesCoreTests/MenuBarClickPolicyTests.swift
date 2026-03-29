import XCTest
@testable import NotesCore

/// Tests for menu bar click behavior.
///
/// The bug: clicking the menu bar icon while the accessibility permission prompt
/// was showing created a second (main) window behind it, resulting in two
/// overlapping windows — one tiny (the prompt) and one full-size (the main window).
///
/// The fix: MenuBarClickPolicy decides what to do based on which windows are active.
final class MenuBarClickPolicyTests: XCTestCase {

    // MARK: - During onboarding

    func testOnboarding_FocusesOnboardingWindow() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: true,
            isPermissionPromptShowing: false,
            hasMainWindow: false
        )
        XCTAssertEqual(action, .focusOnboarding,
            "During onboarding, menu bar click should resurface the onboarding window")
    }

    func testOnboarding_TakesPriority_OverPermissionPrompt() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: true,
            isPermissionPromptShowing: true,
            hasMainWindow: false
        )
        XCTAssertEqual(action, .focusOnboarding,
            "Onboarding takes priority even if permission prompt is also showing")
    }

    func testOnboarding_TakesPriority_OverExistingMainWindow() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: true,
            isPermissionPromptShowing: false,
            hasMainWindow: true
        )
        XCTAssertEqual(action, .focusOnboarding,
            "Onboarding takes priority even if main window exists")
    }

    // MARK: - Permission prompt (post-onboarding)

    func testPermissionPrompt_DismissesAndShowsMain() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: false,
            isPermissionPromptShowing: true,
            hasMainWindow: false
        )
        XCTAssertEqual(action, .dismissPromptAndShowMain,
            "Post-onboarding permission prompt should be dismissed — app is usable without accessibility")
    }

    func testPermissionPrompt_DismissesEvenIfMainWindowExists() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: false,
            isPermissionPromptShowing: true,
            hasMainWindow: true
        )
        XCTAssertEqual(action, .dismissPromptAndShowMain,
            "Permission prompt should be dismissed even if main window already exists")
    }

    // MARK: - Normal operation (no gates)

    func testNoGates_ExistingWindow_ShowsMain() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: false,
            isPermissionPromptShowing: false,
            hasMainWindow: true
        )
        XCTAssertEqual(action, .showMain,
            "With no gates and existing window, just bring it to front")
    }

    func testNoGates_NoWindow_CreatesMain() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: false,
            isPermissionPromptShowing: false,
            hasMainWindow: false
        )
        XCTAssertEqual(action, .createMain,
            "With no gates and no window, create a new main window")
    }
}
