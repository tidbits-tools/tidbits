import AppKit
import Carbon.HIToolbox
import NotesCore

final class HotkeyManager {
    var appState: AppState?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // Default: Command + Shift + Period (⌘⇧.)
    private static let hotkeyID = EventHotKeyID(signature: OSType(0x54494442), id: 1) // "TIDB"

    func start() {
        guard hotkeyRef == nil else { return }

        var hotKeyID = Self.hotkeyID

        // Install Carbon event handler for hotkey events
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // Register ⌘⇧. as global hotkey
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Period),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func stop() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    fileprivate func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.performCapture()
        }
    }

    @MainActor
    private func performCapture() {
        guard HotkeyPolicy.shouldCapture(
            isRepeat: false,
            isPanelVisible: appState?.floatingPanelController.isVisible ?? false
        ) else { return }
        simulateCopyAndCapture()
    }

    @MainActor
    private func simulateCopyAndCapture() {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .privateState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_C), keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // Wait for pasteboard to update, then read it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let appState = self?.appState else { return }

            // Don't re-trigger if panel appeared during the wait
            guard HotkeyPolicy.shouldCapture(
                isRepeat: false,
                isPanelVisible: appState.floatingPanelController.isVisible
            ) else { return }

            // Check if pasteboard actually changed (text was selected)
            guard pasteboard.changeCount != previousChangeCount else {
                appState.showAddSnippetPanel(text: "")
                return
            }

            let text = PasteboardTextExtractor.extractText(from: pasteboard)
            appState.showAddSnippetPanel(text: text)
        }
    }
}

// Carbon event handler callback (must be a free function)
private func hotkeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkey()
    return noErr
}
