import XCTest
@testable import NotesCore

final class HotkeyPolicyTests: XCTestCase {

    // MARK: - Key Repeat Guard (Fix 1)
    // Without this guard, held-down keys fire simulateCopyAndCapture repeatedly,
    // causing the panel text to flash then disappear.

    func testShouldCapture_NormalKeyPress() {
        XCTAssertTrue(
            HotkeyPolicy.shouldCapture(isRepeat: false, isPanelVisible: false),
            "Normal (non-repeat) keypress with no panel should trigger capture"
        )
    }

    func testShouldCapture_RejectKeyRepeat() {
        XCTAssertFalse(
            HotkeyPolicy.shouldCapture(isRepeat: true, isPanelVisible: false),
            "Key repeat events must be ignored to prevent text flash bug"
        )
    }

    // MARK: - Panel Visibility Guard (Fix 2)
    // Without this guard, a second hotkey press while the panel is showing
    // sends Cmd+C to the panel itself, gets empty text, and replaces the panel.

    func testShouldCapture_RejectWhenPanelVisible() {
        XCTAssertFalse(
            HotkeyPolicy.shouldCapture(isRepeat: false, isPanelVisible: true),
            "Must not re-trigger capture while panel is already showing"
        )
    }

    func testShouldCapture_RejectRepeatAndPanelVisible() {
        XCTAssertFalse(
            HotkeyPolicy.shouldCapture(isRepeat: true, isPanelVisible: true),
            "Both conditions present should still reject"
        )
    }
}
