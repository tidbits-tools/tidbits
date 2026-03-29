import AppKit
import SwiftUI
import NotesCore

/// A floating panel that can appear over fullscreen apps
/// Works because the app is an LSUIElement (agent app) which doesn't trigger space switches
final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Float above other windows including fullscreen
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        // Hide traffic light buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        // Set the content
        self.contentView = contentView

        // Center on screen
        self.center()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Controller for the floating panel
@MainActor
final class FloatingPanelController {
    private(set) var panel: FloatingPanel?
    private var hostingView: NSHostingView<AnyView>?
    
    func show<Content: View>(content: Content) {
        // Close existing panel if any
        close()

        // Create hosting view with the SwiftUI content
        let hostingView = NSHostingView(rootView: AnyView(content))

        // Create and configure the panel
        let panel = FloatingPanel(contentView: hostingView)

        // Show the panel - with LSUIElement, this won't switch spaces
        // Uses PanelShowPolicy to enforce correct activation sequence
        PanelShowPolicy.execute(on: AppKitPanelOps(panel: panel))

        self.panel = panel
        self.hostingView = hostingView
    }
    
    func close() {
        panel?.close()
        panel = nil
        hostingView = nil
    }
    
    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

/// Bridges PanelShowPolicy to real AppKit calls
private struct AppKitPanelOps: PanelOperations {
    let panel: NSPanel

    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func orderFront() {
        panel.orderFrontRegardless()
    }

    func makeKey() {
        panel.makeKeyAndOrderFront(nil)
    }
}

