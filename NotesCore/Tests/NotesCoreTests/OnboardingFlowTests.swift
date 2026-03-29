import XCTest
import AppKit
@testable import NotesCore

final class OnboardingFlowTests: XCTestCase {

    // MARK: - totalSteps

    func testTotalSteps_IsFour() {
        XCTAssertEqual(OnboardingFlow.totalSteps, 4)
    }

    // MARK: - initialStep

    func testInitialStep_IsZero() {
        XCTAssertEqual(OnboardingFlow.initialStep, 0)
    }

    // MARK: - showBack

    func testShowBack_Step0_Hidden() {
        XCTAssertFalse(OnboardingFlow.showBack(step: 0))
    }

    func testShowBack_Step1_Shown() {
        XCTAssertTrue(OnboardingFlow.showBack(step: 1))
    }

    func testShowBack_Step2_Shown() {
        XCTAssertTrue(OnboardingFlow.showBack(step: 2))
    }

    func testShowBack_Step3_Hidden() {
        XCTAssertFalse(OnboardingFlow.showBack(step: 3))
    }

    // MARK: - Hotkey key caps: regression for blank period square

    func testHotkeySymbols_AllExistAsSFSymbols() {
        // Regression: "period" is NOT a valid SF Symbol and renders as blank.
        // Only "command" and "shift" should be SF Symbols.
        for symbol in OnboardingFlow.hotkeySymbols {
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil),
                            "\(symbol) must be a valid SF Symbol — if this fails, a key cap will render blank")
        }
    }

    func testHotkeySymbols_DoesNotContainPeriod() {
        // Regression: "period" as an SF Symbol name renders a blank square.
        // The period key must be rendered as Text("."), not Image(systemName:).
        XCTAssertFalse(OnboardingFlow.hotkeySymbols.contains("period"),
                        "Period must NOT be an SF Symbol — use periodKeyText instead")
    }

    // MARK: - Accessibility step content: regression for green checkmark

    func testAccessibilityTitle_WhenGranted_ShowsPermissionGranted() {
        XCTAssertEqual(OnboardingFlow.accessibilityTitle(granted: true), "Permission Granted")
    }

    func testAccessibilityTitle_WhenNotGranted_ShowsAccessibilityPermission() {
        XCTAssertEqual(OnboardingFlow.accessibilityTitle(granted: false), "Accessibility Permission")
    }

    func testAccessibilitySubtitle_WhenGranted_ShowsReady() {
        XCTAssertEqual(OnboardingFlow.accessibilitySubtitle(granted: true), "The global hotkey is ready to use.")
    }

    func testAccessibilitySubtitle_WhenNotGranted_ExplainsWhy() {
        XCTAssertTrue(OnboardingFlow.accessibilitySubtitle(granted: false).contains("Accessibility permission"))
    }

    func testAccessibilityIcon_WhenGranted_IsCheckmark() {
        XCTAssertEqual(OnboardingFlow.accessibilityIcon(granted: true), "checkmark.shield.fill")
    }

    func testAccessibilityIcon_WhenNotGranted_IsShield() {
        XCTAssertEqual(OnboardingFlow.accessibilityIcon(granted: false), "shield.lefthalf.filled")
    }

    func testAccessibilityIcon_BothAreValidSFSymbols() {
        XCTAssertNotNil(NSImage(systemSymbolName: OnboardingFlow.accessibilityIcon(granted: true), accessibilityDescription: nil))
        XCTAssertNotNil(NSImage(systemSymbolName: OnboardingFlow.accessibilityIcon(granted: false), accessibilityDescription: nil))
    }

    func testAccessibilityNavLabel_WhenGranted_IsContinue() {
        XCTAssertEqual(OnboardingFlow.accessibilityNavLabel(granted: true), "Continue")
    }

    func testAccessibilityNavLabel_WhenNotGranted_IsSkip() {
        XCTAssertEqual(OnboardingFlow.accessibilityNavLabel(granted: false), "Skip for Now")
    }

    func testPeriodKeyText_IsDot() {
        XCTAssertEqual(OnboardingFlow.periodKeyText, ".")
    }

    func testPeriodSFSymbol_DoesNotExist() {
        // Prove that "period" is not a valid SF Symbol — this is WHY we use Text
        let img = NSImage(systemSymbolName: "period", accessibilityDescription: nil)
        XCTAssertNil(img, "If Apple adds a 'period' SF Symbol, we can switch back to Image(systemName:)")
    }

    // MARK: - Onboarding window collection behavior
    // Regression: without canJoinAllSpaces, the onboarding window gets stranded
    // in a fullscreen space when the user clicks "Open System Settings" and gets
    // taken to the desktop. This took hours to debug.

    func testOnboardingWindowBehavior_ContainsCanJoinAllSpaces() {
        XCTAssertTrue(
            OnboardingFlow.onboardingWindowCollectionBehavior.contains(.canJoinAllSpaces),
            "Onboarding window must join all spaces — without this, it gets stranded in fullscreen when System Settings opens on the desktop"
        )
    }

    // MARK: - Edge cases

    func testShowBack_NegativeStep_Hidden() {
        XCTAssertFalse(OnboardingFlow.showBack(step: -1))
    }

    func testShowBack_BeyondLastStep_Hidden() {
        XCTAssertFalse(OnboardingFlow.showBack(step: 5))
    }
}
