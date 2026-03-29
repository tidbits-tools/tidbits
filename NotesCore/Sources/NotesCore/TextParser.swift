import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - RTF Parsing

#if canImport(AppKit)
/// Parses RTF data to markdown-style text. Bold becomes **text**, italic becomes *text*.
/// Returns nil if the data cannot be parsed as RTF or the result is empty.
public func parseRTFToMarkdown(_ data: Data) -> String? {
    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
        .documentType: NSAttributedString.DocumentType.rtf
    ]

    guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
        return nil
    }

    var result = extractMarkdownFromAttributedString(attributed)
    result = cleanupWhitespace(result)

    return result.isEmpty ? nil : result
}

/// Extracts text from NSAttributedString, converting bold to **text** and italic to *text*
private func extractMarkdownFromAttributedString(_ attributed: NSAttributedString) -> String {
    var result = ""
    let fullRange = NSRange(location: 0, length: attributed.length)

    attributed.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
        let substring = attributed.attributedSubstring(from: range).string

        var isBold = false
        var isItalic = false

        if let font = attributes[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            isBold = traits.contains(.bold)
            isItalic = traits.contains(.italic)
        }

        if isBold && isItalic {
            result += "***\(substring)***"
        } else if isBold {
            result += "**\(substring)**"
        } else if isItalic {
            result += "*\(substring)*"
        } else {
            result += substring
        }
    }

    // Clean up adjacent markers from split attribute runs (e.g., ****text**** -> **text**)
    result = result.replacingOccurrences(of: "****", with: "**")

    return result
}
#endif

// MARK: - HTML Parsing

/// Converts HTML to plain text while preserving list markers and formatting.
/// - Lists become bullet points (•)
/// - Bold (<strong>, <b>) becomes **text**
/// - Italic (<em>, <i>) becomes *text*
public func parseHTMLToMarkdown(_ html: String) -> String {
    var result = html
    
    // Convert formatting tags to markdown-style markers
    // Bold: <strong> and <b> -> **text**
    result = result.replacingOccurrences(
        of: #"<strong[^>]*>"#,
        with: "**",
        options: [.regularExpression, .caseInsensitive]
    )
    result = result.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)
    result = result.replacingOccurrences(
        of: #"<b>|<b\s[^>]*>"#,
        with: "**",
        options: [.regularExpression, .caseInsensitive]
    )
    result = result.replacingOccurrences(of: "</b>", with: "**", options: .caseInsensitive)
    
    // Italic: <em> and <i> -> *text*
    result = result.replacingOccurrences(
        of: #"<em[^>]*>"#,
        with: "*",
        options: [.regularExpression, .caseInsensitive]
    )
    result = result.replacingOccurrences(of: "</em>", with: "*", options: .caseInsensitive)
    result = result.replacingOccurrences(
        of: #"<i>|<i\s[^>]*>"#,
        with: "*",
        options: [.regularExpression, .caseInsensitive]
    )
    result = result.replacingOccurrences(of: "</i>", with: "*", options: .caseInsensitive)
    
    // Convert list items to bullet points
    result = convertListItemsToBullets(result)
    
    // Convert <br> to newlines
    result = result.replacingOccurrences(
        of: #"<br\s*/?>"#,
        with: "\n",
        options: [.regularExpression, .caseInsensitive]
    )
    
    // Convert </p> and </div> to double newlines
    result = result.replacingOccurrences(
        of: #"</(?:p|div)>"#,
        with: "\n\n",
        options: [.regularExpression, .caseInsensitive]
    )
    
    // Strip remaining HTML tags
    result = result.replacingOccurrences(
        of: #"<[^>]+>"#,
        with: "",
        options: .regularExpression
    )
    
    // Decode common HTML entities
    result = decodeHTMLEntities(result)
    
    // Clean up whitespace
    result = cleanupWhitespace(result)
    
    return result
}

/// Converts <li> elements to bullet points
private func convertListItemsToBullets(_ html: String) -> String {
    var result = ""
    var i = html.startIndex
    
    while i < html.endIndex {
        let remaining = html[i...]
        
        // Skip list container tags
        if remaining.lowercased().hasPrefix("<ol") || remaining.lowercased().hasPrefix("<ul") {
            if let closeIndex = remaining.firstIndex(of: ">") {
                i = html.index(after: closeIndex)
                continue
            }
        }
        
        if remaining.lowercased().hasPrefix("</ol>") {
            i = html.index(i, offsetBy: 5)
            continue
        }
        
        if remaining.lowercased().hasPrefix("</ul>") {
            i = html.index(i, offsetBy: 5)
            continue
        }
        
        // Convert <li> to bullet
        if remaining.lowercased().hasPrefix("<li") {
            if let closeIndex = remaining.firstIndex(of: ">") {
                result += "• "
                i = html.index(after: closeIndex)
                continue
            }
        }
        
        // Convert </li> to newline
        if remaining.lowercased().hasPrefix("</li>") {
            result += "\n"
            i = html.index(i, offsetBy: 5)
            continue
        }
        
        result.append(html[i])
        i = html.index(after: i)
    }
    
    return result
}

/// Decodes common HTML entities
private func decodeHTMLEntities(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "&nbsp;", with: " ")
    result = result.replacingOccurrences(of: "&amp;", with: "&")
    result = result.replacingOccurrences(of: "&lt;", with: "<")
    result = result.replacingOccurrences(of: "&gt;", with: ">")
    result = result.replacingOccurrences(of: "&quot;", with: "\"")
    result = result.replacingOccurrences(of: "&#39;", with: "'")
    result = result.replacingOccurrences(of: "&apos;", with: "'")
    return result
}

/// Cleans up excessive whitespace while preserving intentional line breaks
private func cleanupWhitespace(_ text: String) -> String {
    let lines = text.components(separatedBy: .newlines)
    var cleanedLines: [String] = []
    var blankCount = 0
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            blankCount += 1
            if blankCount <= 1 {
                cleanedLines.append("")
            }
        } else {
            blankCount = 0
            cleanedLines.append(trimmed)
        }
    }
    
    return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

