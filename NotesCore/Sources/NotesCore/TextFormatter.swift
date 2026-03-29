import Foundation

/// Deterministic text formatting (no AI required)
public enum TextFormatter {
    /// Format text with deterministic rules:
    /// - Replace curly quotes with straight quotes
    /// - Capitalize first letter of each non-indented line
    public static func format(_ text: String) -> String {
        var result = text

        // 1. Replace curly quotes with straight quotes
        // Left double quote (U+201C), Right double quote (U+201D)
        // Left single quote (U+2018), Right single quote (U+2019)
        result = result
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")

        // 2. Process line by line for capitalization
        let lines = result.components(separatedBy: "\n")
        let formattedLines = lines.map { line -> String in
            if line.isEmpty { return line }

            // Skip indented lines (likely bullet points)
            if line.first?.isWhitespace == true { return line }

            // Capitalize first letter of line (skip any non-letters: markdown, etc.)
            return capitalizeFirstLetter(line)
        }

        return formattedLines.joined(separator: "\n")
    }

    /// Capitalize the first alphabetic character in a string
    private static func capitalizeFirstLetter(_ text: String) -> String {
        var result = ""
        var foundLetter = false

        for char in text {
            if !foundLetter && char.isLetter && char.isLowercase {
                result.append(char.uppercased())
                foundLetter = true
            } else {
                result.append(char)
                if char.isLetter {
                    foundLetter = true
                }
            }
        }

        return result
    }

    /// Format multiple snippets, returning only those that changed
    public static func formatSnippets(_ snippets: [Snippet]) -> [(original: Snippet, formatted: String)] {
        var changes: [(original: Snippet, formatted: String)] = []

        for snippet in snippets {
            let formatted = format(snippet.text)
            if formatted != snippet.text {
                changes.append((original: snippet, formatted: formatted))
            }
        }

        return changes
    }
}
