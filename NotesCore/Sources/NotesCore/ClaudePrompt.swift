import Foundation

public enum ClaudePrompt {
    public static let notesDirectory = "~/Library/Application Support/TidbitsLocal"

    public static func allNotes() -> String {
        "Read my notes index at \(notesDirectory)/index.json and page files in \(notesDirectory)/pages/ — these are my saved tidbits organized into pages."
    }

    public static func page(title: String, slug: String? = nil) -> String {
        if let slug {
            return "Read the page \"\(title)\" from \(notesDirectory)/pages/\(slug).json"
        }
        return "Read the page \"\(title)\" — find its slug in \(notesDirectory)/index.json, then read \(notesDirectory)/pages/{slug}.json"
    }
}
