import XCTest
@testable import NotesCore

final class NotesDatabaseTests: XCTestCase {

    // MARK: - JSON Round-Trip

    func testNotesDatabase_JSONRoundTrip() throws {
        let source = SnippetSource(applicationName: "Safari", urlString: "https://example.com")
        let snippet = Snippet(createdAt: Date(), id: UUID().uuidString, source: source, text: "Hello")
        let insight = Insight(generatedAt: Date(), items: ["Point 1", "Point 2"])
        let insights = PageInsights(distortions: nil, keyPoints: insight)
        let page = Page(createdAt: Date(), id: UUID().uuidString, insights: insights, snippets: [snippet], title: "Test", updatedAt: Date())
        let db = NotesDatabase(pages: [page], schemaVersion: 1)

        let data = try newJSONEncoder().encode(db)
        let decoded = try newJSONDecoder().decode(NotesDatabase.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, db.schemaVersion)
        XCTAssertEqual(decoded.pages.count, 1)
        XCTAssertEqual(decoded.pages[0].title, "Test")
        XCTAssertEqual(decoded.pages[0].snippets[0].text, "Hello")
        XCTAssertEqual(decoded.pages[0].snippets[0].source?.applicationName, "Safari")
        XCTAssertEqual(decoded.pages[0].insights?.keyPoints?.items, ["Point 1", "Point 2"])
    }

    func testNotesDatabase_InitFromInvalidJSON_Throws() {
        let data = "{garbage}".data(using: .utf8)!
        XCTAssertThrowsError(try newJSONDecoder().decode(NotesDatabase.self, from: data))
    }

    func testNotesDatabase_InitFromEmptyData_Throws() {
        let data = Data()
        XCTAssertThrowsError(try newJSONDecoder().decode(NotesDatabase.self, from: data))
    }

    // MARK: - Date Decoding

    func testDateDecoding_WithFractionalSeconds() throws {
        let json = """
        {
            "schemaVersion": 1,
            "pages": [{
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "Test",
                "createdAt": "2024-01-15T10:30:00.123Z",
                "updatedAt": "2024-01-15T10:30:00.456Z",
                "snippets": []
            }]
        }
        """
        let db = try newJSONDecoder().decode(NotesDatabase.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(db.pages[0].title, "Test")
    }

    func testDateDecoding_WithoutFractionalSeconds() throws {
        let json = """
        {
            "schemaVersion": 1,
            "pages": [{
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "Test",
                "createdAt": "2024-01-15T10:30:00Z",
                "updatedAt": "2024-01-15T10:30:00Z",
                "snippets": []
            }]
        }
        """
        let db = try newJSONDecoder().decode(NotesDatabase.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(db.pages[0].title, "Test")
    }

    func testDateDecoding_InvalidDateString_Throws() {
        let json = """
        {
            "schemaVersion": 1,
            "pages": [{
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "Test",
                "createdAt": "not-a-date",
                "updatedAt": "also-not-a-date",
                "snippets": []
            }]
        }
        """
        XCTAssertThrowsError(
            try newJSONDecoder().decode(NotesDatabase.self, from: json.data(using: .utf8)!)
        )
    }

    // MARK: - Convenience Methods

    func testNotesDatabase_Empty_HasCorrectDefaults() {
        let db = NotesDatabase.empty()
        XCTAssertEqual(db.pages.count, 0)
        XCTAssertEqual(db.schemaVersion, 1)
    }

    func testPage_Create_HasUniqueIDs() {
        let a = Page.create(title: "A")
        let b = Page.create(title: "B")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSnippet_Create_HasUniqueIDs() {
        let a = Snippet.create(text: "A")
        let b = Snippet.create(text: "B")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Optional Fields

    func testPageInsights_OptionalFields_DecodeCorrectly() throws {
        // Page with no insights
        let json1 = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "No Insights",
            "createdAt": "2024-01-15T10:30:00.000Z",
            "updatedAt": "2024-01-15T10:30:00.000Z",
            "snippets": []
        }
        """
        let page1 = try newJSONDecoder().decode(Page.self, from: json1.data(using: .utf8)!)
        XCTAssertNil(page1.insights)

        // Page with partial insights (only keyPoints)
        let json2 = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "title": "Partial Insights",
            "createdAt": "2024-01-15T10:30:00.000Z",
            "updatedAt": "2024-01-15T10:30:00.000Z",
            "snippets": [],
            "insights": {
                "keyPoints": {
                    "generatedAt": "2024-01-15T10:30:00.000Z",
                    "items": ["Point 1"]
                }
            }
        }
        """
        let page2 = try newJSONDecoder().decode(Page.self, from: json2.data(using: .utf8)!)
        XCTAssertNotNil(page2.insights?.keyPoints)
        XCTAssertNil(page2.insights?.distortions)
    }

    func testInsight_WithNilItems_RoundTrips() throws {
        let insight = Insight(generatedAt: Date(), items: nil)
        let data = try newJSONEncoder().encode(insight)
        let decoded = try newJSONDecoder().decode(Insight.self, from: data)
        XCTAssertNil(decoded.items)
    }

    func testSnippetSource_OptionalFields_RoundTrip() throws {
        let source = SnippetSource(applicationName: nil, urlString: nil)
        let data = try newJSONEncoder().encode(source)
        let decoded = try newJSONDecoder().decode(SnippetSource.self, from: data)
        XCTAssertNil(decoded.applicationName)
        XCTAssertNil(decoded.urlString)
    }
}
