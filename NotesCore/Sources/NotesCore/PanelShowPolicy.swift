import Foundation

/// Defines the operations needed to show a floating panel.
/// Extracted so the call sequence can be tested without AppKit.
public protocol PanelOperations {
    func activateApp()
    func orderFront()
    func makeKey()
}

/// Encapsulates the correct sequence for showing a floating panel.
/// LSUIElement apps must activate before ordering the panel, otherwise
/// the panel appears but isn't interactive until the user clicks it.
public enum PanelShowPolicy {
    public static func execute(on ops: PanelOperations) {
        ops.activateApp()
        ops.orderFront()
        ops.makeKey()
    }
}
