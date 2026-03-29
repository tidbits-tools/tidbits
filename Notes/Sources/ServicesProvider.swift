import AppKit
import NotesCore

final class ServicesProvider: NSObject {
    weak var appState: AppState?

    /// macOS Services entry point. Must match `NSMessage` in Info.plist.
    @objc func addToTidbitsService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let text = PasteboardTextExtractor.extractText(from: pboard)

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "No text found on pasteboard." as NSString
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.appState?.showAddSnippetPanel(text: text)
        }
    }
}


