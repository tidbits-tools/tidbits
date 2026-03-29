import Foundation
#if canImport(AppKit)
import AppKit

/// Extracts text from an NSPasteboard using RTF-first priority.
/// Ghostty (and some other apps) put selected text as RTF, not plain text.
/// Order: RTF → HTML → plain text.
public enum PasteboardTextExtractor {
    public static let maxInputBytes = 100_000

    public static func extractText(from pasteboard: NSPasteboard) -> String {
        // 1. Try RTF (Ghostty and rich text apps)
        if let rtfData = pasteboard.data(forType: .rtf),
           rtfData.count < maxInputBytes,
           let text = parseRTFToMarkdown(rtfData) {
            return text
        }

        // 2. Try HTML
        if let htmlData = pasteboard.data(forType: .html),
           htmlData.count < maxInputBytes,
           let htmlString = String(data: htmlData, encoding: .utf8) {
            let text = parseHTMLToMarkdown(htmlString)
            if !text.isEmpty { return text }
        }

        // 3. Fall back to plain text
        return pasteboard.string(forType: .string) ?? ""
    }
}
#endif
