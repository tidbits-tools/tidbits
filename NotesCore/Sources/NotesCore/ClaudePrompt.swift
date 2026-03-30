import Foundation

public enum ClaudePrompt {
    public static let notesDirectory = "~/Library/Application Support/TidbitsLocal"

    public static func allNotes() -> String {
        notesDirectory
    }

    public static func page(slug: String) -> String {
        "\(notesDirectory)/pages/\(slug).json"
    }
}
