import Foundation

/// Lightweight metadata for a page, stored in `index.json`.
/// Contains everything needed for the sidebar list without loading snippets.
public struct IndexEntry: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var slug: String
    public var createdAt: Date
    public var updatedAt: Date
    public var snippetCount: Int

    public init(id: String, title: String, slug: String,
                createdAt: Date, updatedAt: Date, snippetCount: Int) {
        self.id = id
        self.title = title
        self.slug = slug
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snippetCount = snippetCount
    }

    /// Create an index entry from a full Page object.
    public static func from(page: Page, slug: String) -> IndexEntry {
        IndexEntry(
            id: page.id,
            title: page.title,
            slug: slug,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            snippetCount: page.snippets.count
        )
    }
}
