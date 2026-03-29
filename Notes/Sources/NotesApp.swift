import SwiftUI
import AppKit
import NotesCore
import ApplicationServices

@MainActor
final class AppState: ObservableObject {
    static private(set) var shared: AppState?

    @Published var pages: [Page] = []

    let store: NotesStore?
    let floatingPanelController = FloatingPanelController()

    init(store: NotesStore?) {
        self.store = store
        AppState.shared = self
    }

    func reloadPages() {
        guard let store else { return }
        Task {
            self.pages = await store.listPages()
        }
    }

    /// Shows the add snippet UI in a floating panel (for Services)
    func showAddSnippetPanel(text: String) {
        reloadPages()
        let view = AddSnippetView(initialText: text, onDismiss: { [weak self] in
            self?.floatingPanelController.close()
        })
        .environmentObject(self)

        floatingPanelController.show(content: view)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    // Static to prevent deallocation
    static var retainedStatusItem: NSStatusItem?
    static var retainedSelf: AppDelegate?
    
    var appState: AppState?
    private let servicesProvider = ServicesProvider()
    private let hotkeyManager = HotkeyManager()
    private var mainWindow: NSWindow?
    private var permissionWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var hideAfterFullScreenExit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        servicesProvider.appState = appState
        hotkeyManager.appState = appState
        NSApp.servicesProvider = servicesProvider
        setupMenuBar()



        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: OnboardingFlow.completedKey)
        if !hasCompletedOnboarding {
            showOnboarding()
        } else {
            checkAccessibilityAndSetupHotkey()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Accessibility & Hotkey

    private func checkAccessibilityAndSetupHotkey() {
        if AXIsProcessTrusted() {
            hotkeyManager.start()
            openMainWindow()
        } else {
            showAccessibilityPrompt()
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.checkAccessibilityAndSetupHotkey()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.collectionBehavior = OnboardingFlow.onboardingWindowCollectionBehavior
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window
    }

    private func showAccessibilityPrompt() {
        let promptView = AccessibilityPromptView(onGranted: { [weak self] in
            self?.permissionWindow?.close()
            self?.permissionWindow = nil
            self?.hotkeyManager.start()
            self?.openMainWindow()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: promptView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.permissionWindow = window
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let isFullScreen = sender.styleMask.contains(.fullScreen)
        switch WindowClosePolicy.action(isFullScreen: isFullScreen) {
        case .exitFullScreenThenHide:
            hideAfterFullScreenExit = true
            sender.toggleFullScreen(nil)
        case .hide:
            sender.orderOut(nil)
        }
        return false
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        if hideAfterFullScreenExit {
            hideAfterFullScreenExit = false
            (notification.object as? NSWindow)?.orderOut(nil)
        }
    }
    
    // MARK: - Menu Bar
    
    private func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        AppDelegate.retainedStatusItem = statusItem
        
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Tidbits")?.withSymbolConfiguration(config)
            button.action = #selector(statusBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
@objc private func statusBarClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            openMainWindow()
            return
        }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            openMainWindow()
        }
    }
    
    private func showContextMenu() {
        guard let button = AppDelegate.retainedStatusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Tidbits", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 5), in: button)
    }
    
    // MARK: - Window Management

    private func openMainWindow() {
        let action = MenuBarClickPolicy.action(
            isOnboarding: onboardingWindow != nil,
            isPermissionPromptShowing: permissionWindow != nil,
            hasMainWindow: mainWindow != nil
        )

        switch action {
        case .focusOnboarding:
            NSApp.activate(ignoringOtherApps: true)
            onboardingWindow?.makeKeyAndOrderFront(nil)

        case .dismissPromptAndShowMain:
            permissionWindow?.close()
            permissionWindow = nil
            if let window = mainWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            } else {
                createMainWindow()
                NSApp.activate(ignoringOtherApps: true)
            }

        case .showMain:
            NSApp.activate(ignoringOtherApps: true)
            mainWindow?.makeKeyAndOrderFront(nil)

        case .createMain:
            createMainWindow()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func createMainWindow() {
        let state: AppState? = appState ?? MainActor.assumeIsolated { AppState.shared }
        guard let appState = state else { return }
        
        let contentView = ContentView()
            .environmentObject(appState)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self  // Handle close to hide instead
        window.isReleasedWhenClosed = false  // Keep window in memory
        window.collectionBehavior = [.fullScreenPrimary, .moveToActiveSpace]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        self.mainWindow = window
    }
}

// Using NSApplicationMain for full control over app lifecycle
enum AppMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Initialize store
        let store: NotesStore?
        do {
            let dirURL = try NotesStore.defaultDirectoryURL(appFolderName: "TidbitsLocal")
            store = try NotesStore(directoryURL: dirURL)
        } catch {
            store = nil
        }

        delegate.appState = AppState(store: store)
        
        // Keep delegate alive
        AppDelegate.retainedSelf = delegate
        
        app.run()
    }
}

@main
struct TidbitsAppLauncher {
    static func main() {
        AppMain.main()
    }
}

