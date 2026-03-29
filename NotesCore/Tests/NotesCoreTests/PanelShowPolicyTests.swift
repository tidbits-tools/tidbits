import XCTest
@testable import NotesCore

final class PanelShowPolicyTests: XCTestCase {

    private class MockPanelOps: PanelOperations {
        var calls: [String] = []

        func activateApp() { calls.append("activateApp") }
        func orderFront() { calls.append("orderFront") }
        func makeKey() { calls.append("makeKey") }
    }

    func testExecute_CallsAllOperations() {
        let mock = MockPanelOps()
        PanelShowPolicy.execute(on: mock)
        XCTAssertEqual(mock.calls.count, 3, "All three operations must be called")
    }

    func testExecute_ActivatesBeforeOrdering() {
        let mock = MockPanelOps()
        PanelShowPolicy.execute(on: mock)
        XCTAssertEqual(mock.calls[0], "activateApp",
            "App must be activated first — LSUIElement panels are not interactive without activation")
    }

    func testExecute_OrderFrontBeforeMakeKey() {
        let mock = MockPanelOps()
        PanelShowPolicy.execute(on: mock)
        XCTAssertEqual(mock.calls[1], "orderFront")
        XCTAssertEqual(mock.calls[2], "makeKey")
    }

    func testExecute_FullSequence() {
        let mock = MockPanelOps()
        PanelShowPolicy.execute(on: mock)
        XCTAssertEqual(mock.calls, ["activateApp", "orderFront", "makeKey"],
            "Sequence must be: activate → orderFront → makeKey")
    }
}
