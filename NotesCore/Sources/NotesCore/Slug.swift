import Foundation

/// Converts a page title to a filesystem-safe slug.
///
/// Algorithm matches `scripts/migrate-to-per-page.py` exactly:
/// NFKD normalize → lowercase → literal `+`→`plus`, `&`→`and` → regex `[^a-z0-9]+` → `-` →
/// strip leading/trailing `-` → collapse `--` → truncate to 200 chars → `"untitled"` if empty.
public func slugify(_ title: String) -> String {
    // NFKD normalize — strips combining marks (accents etc.)
    let scalars = title.decomposedStringWithCompatibilityMapping.unicodeScalars
    let stripped = String(scalars.filter { !CharacterSet.nonBaseCharacters.contains($0) })

    var s = stripped.lowercased()

    // Literal replacements (no separators — "C++" becomes "cplusplus")
    s = s.replacingOccurrences(of: "+", with: "plus")
    s = s.replacingOccurrences(of: "&", with: "and")

    // Replace non-alphanumeric runs with hyphens
    s = s.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)

    // Strip leading/trailing hyphens
    s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    // Collapse multiple hyphens
    s = s.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)

    // Truncate to 200 chars (APFS 255-byte limit minus .json + collision suffix)
    if s.count > 200 {
        s = String(s.prefix(200))
        // Don't leave a trailing hyphen after truncation
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    return s.isEmpty ? "untitled" : s
}
