import XCTest
@testable import NotesCore

/// Regression tests for the full-screen close bug.
///
/// The bug: clicking the close button while the window was in full-screen mode
/// called `orderOut` (hide) without exiting full-screen first. This left an
/// empty black full-screen Space. Re-opening from the menu bar then showed the
/// window still stuck in full-screen with the title bar auto-hidden.
///
/// The fix: exit full-screen before hiding. The window hides after the
/// full-screen exit transition completes via `windowDidExitFullScreen`.
final class WindowClosePolicyTests: XCTestCase {

    func testFullScreen_ExitsFullScreenBeforeHiding() {
        let action = WindowClosePolicy.action(isFullScreen: true)
        XCTAssertEqual(action, .exitFullScreenThenHide,
            "Must exit full-screen before hiding to avoid empty black Space")
    }

    func testNormalMode_HidesImmediately() {
        let action = WindowClosePolicy.action(isFullScreen: false)
        XCTAssertEqual(action, .hide,
            "In normal mode, just hide the window")
    }
}
