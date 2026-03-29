import Foundation

// MARK: - NotesDatabase
public struct NotesDatabase: Codable, Equatable, Sendable {
    public var pages: [Page]
    public var schemaVersion: Int

    public enum CodingKeys: String, CodingKey {
        case pages = "pages"
        case schemaVersion = "schemaVersion"
    }

    public init(pages: [Page], schemaVersion: Int) {
        self.pages = pages
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Page
public struct Page: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var id: String
    public var insights: PageInsights?
    public var snippets: [Snippet]
    public var title: String
    public var updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case id = "id"
        case insights = "insights"
        case snippets = "snippets"
        case title = "title"
        case updatedAt = "updatedAt"
    }

    public init(createdAt: Date, id: String, insights: PageInsights?, snippets: [Snippet], title: String, updatedAt: Date) {
        self.createdAt = createdAt
        self.id = id
        self.insights = insights
        self.snippets = snippets
        self.title = title
        self.updatedAt = updatedAt
    }
}

// MARK: - PageInsights
public struct PageInsights: Codable, Equatable, Sendable {
    public var distortions: Insight?
    public var keyPoints: Insight?

    public enum CodingKeys: String, CodingKey {
        case distortions = "distortions"
        case keyPoints = "keyPoints"
    }

    public init(distortions: Insight?, keyPoints: Insight?) {
        self.distortions = distortions
        self.keyPoints = keyPoints
    }
}

// MARK: - Insight
public struct Insight: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var items: [String]?

    public enum CodingKeys: String, CodingKey {
        case generatedAt = "generatedAt"
        case items = "items"
    }

    public init(generatedAt: Date, items: [String]?) {
        self.generatedAt = generatedAt
        self.items = items
    }
}

// MARK: - Snippet
public struct Snippet: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var id: String
    public var source: SnippetSource?
    public var text: String

    public enum CodingKeys: String, CodingKey {
        case createdAt = "createdAt"
        case id = "id"
        case source = "source"
        case text = "text"
    }

    public init(createdAt: Date, id: String, source: SnippetSource?, text: String) {
        self.createdAt = createdAt
        self.id = id
        self.source = source
        self.text = text
    }
}

// MARK: - SnippetSource
public struct SnippetSource: Codable, Equatable, Sendable {
    public var applicationName: String?
    public var urlString: String?

    public enum CodingKeys: String, CodingKey {
        case applicationName = "applicationName"
        case urlString = "urlString"
    }

    public init(applicationName: String?, urlString: String?) {
        self.applicationName = applicationName
        self.urlString = urlString
    }
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let fallbackFormatter = ISO8601DateFormatter()
    fallbackFormatter.formatOptions = [.withInternetDateTime]
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        if let date = formatter.date(from: dateString) {
            return date
        }
        if let date = fallbackFormatter.date(from: dateString) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
    }
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

// MARK: - Convenience Extensions (appended by generate.sh)

extension NotesDatabase {
    /// Empty database with default schema version
    public static func empty() -> NotesDatabase {
        NotesDatabase(pages: [], schemaVersion: 1)
    }
}

extension Page: Identifiable {
    /// Create a new page with auto-generated ID and timestamps
    public static func create(title: String, snippets: [Snippet] = [], insights: PageInsights? = nil) -> Page {
        let now = Date()
        return Page(createdAt: now, id: UUID().uuidString, insights: insights, snippets: snippets, title: title, updatedAt: now)
    }
}

extension Snippet: Identifiable {
    /// Create a new snippet with auto-generated ID and timestamp
    public static func create(text: String, source: SnippetSource? = nil) -> Snippet {
        Snippet(createdAt: Date(), id: UUID().uuidString, source: source, text: text)
    }
}
