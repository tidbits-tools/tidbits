import XCTest
@testable import NotesCore

final class NotesCoreTests: XCTestCase {

    func testCreatePageAndAddSnippet_RoundTripsToDisk() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "Inbox", text: "hello", source: SnippetSource(applicationName: "Safari", urlString: "https://example.com"))

        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].id, page.id)
        XCTAssertEqual(pages[0].snippets.count, 1)
        XCTAssertEqual(pages[0].snippets[0].id, snippet.id)

        let store2 = try NotesStore(directoryURL: dirURL)
        let pages2 = await store2.listPages()
        XCTAssertEqual(pages2.count, 1)
        XCTAssertEqual(pages2[0].title, "Inbox")
        XCTAssertEqual(pages2[0].snippets.count, 1)
        XCTAssertEqual(pages2[0].snippets[0].text, "hello")
        XCTAssertEqual(pages2[0].snippets[0].source?.applicationName, "Safari")
        XCTAssertEqual(pages2[0].snippets[0].source?.urlString, "https://example.com")
    }

    func testAddSnippetToUnknownPageThrows() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        do {
            _ = try await store.addSnippet(toPageID: UUID().uuidString, text: "x")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - CRUD Tests

    func testCreatePage_AddsPageToStore() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "My Page")
        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].id, page.id)
        XCTAssertEqual(pages[0].title, "My Page")
    }

    func testDeletePage_RemovesFromStore() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "To Delete")
        try await store.deletePage(id: page.id)
        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 0)
    }

    func testDeletePage_UnknownIDThrows() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        do {
            try await store.deletePage(id: UUID().uuidString)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testUpdateSnippet_ChangesText() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "original")
        try await store.updateSnippet(pageID: page.id, snippetID: snippet.id, newText: "updated")

        let pages = await store.listPages()
        XCTAssertEqual(pages[0].snippets[0].text, "updated")
    }

    func testDeleteSnippet_RemovesFromPage() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "to delete")
        try await store.deleteSnippet(pageID: page.id, snippetID: snippet.id)

        let pages = await store.listPages()
        XCTAssertEqual(pages[0].snippets.count, 0)
    }

    func testUpdatePageTitle_ChangesTitle() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "Old Title")
        try await store.updatePageTitle(pageID: page.id, title: "New Title")

        let pages = await store.listPages()
        XCTAssertEqual(pages[0].title, "New Title")
    }

    func testMoveSnippet_BetweenPages() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, snippet) = try await store.createPageAndAddSnippet(pageTitle: "A", text: "moveme")
        let pageB = try await store.createPage(title: "B")
        try await store.moveSnippet(snippetID: snippet.id, fromPageID: pageA.id, toPageID: pageB.id)

        let pages = await store.listPages()
        let a = pages.first { $0.id == pageA.id }!
        let b = pages.first { $0.id == pageB.id }!
        XCTAssertEqual(a.snippets.count, 0)
        XCTAssertEqual(b.snippets.count, 1)
        XCTAssertEqual(b.snippets[0].text, "moveme")
    }

    func testMoveSnippetToNewPage_CreatesPageAndMoves() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, snippet) = try await store.createPageAndAddSnippet(pageTitle: "A", text: "moveme")
        let newPage = try await store.moveSnippetToNewPage(snippetID: snippet.id, fromPageID: pageA.id, newPageTitle: "New Page")

        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 2)
        let a = pages.first { $0.id == pageA.id }!
        let np = pages.first { $0.id == newPage.id }!
        XCTAssertEqual(a.snippets.count, 0)
        XCTAssertEqual(np.snippets.count, 1)
        XCTAssertEqual(np.title, "New Page")
    }

    func testReplacePageSnippets_ReplacesAll() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "old")
        let newSnippets = [Snippet.create(text: "new1"), Snippet.create(text: "new2")]
        try await store.replacePageSnippets(pageID: page.id, snippets: newSnippets)

        let pages = await store.listPages()
        XCTAssertEqual(pages[0].snippets.count, 2)
        XCTAssertEqual(pages[0].snippets[0].text, "new1")
        XCTAssertEqual(pages[0].snippets[1].text, "new2")
    }

    // MARK: - Error Paths: updateSnippet

    func testUpdateSnippet_UnknownPageID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (_, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.updateSnippet(pageID: UUID().uuidString, snippetID: snippet.id, newText: "new")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testUpdateSnippet_UnknownSnippetID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.updateSnippet(pageID: page.id, snippetID: UUID().uuidString, newText: "new")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Error Paths: deleteSnippet

    func testDeleteSnippet_UnknownPageID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (_, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.deleteSnippet(pageID: UUID().uuidString, snippetID: snippet.id)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testDeleteSnippet_UnknownSnippetID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.deleteSnippet(pageID: page.id, snippetID: UUID().uuidString)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Error Paths: updatePageTitle

    func testUpdatePageTitle_UnknownID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        do {
            try await store.updatePageTitle(pageID: UUID().uuidString, title: "New")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Error Paths: replacePageSnippets

    func testReplacePageSnippets_UnknownID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        do {
            try await store.replacePageSnippets(pageID: UUID().uuidString, snippets: [])
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Error Paths: moveSnippet

    func testMoveSnippet_UnknownFromPage_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (_, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        let pageB = try await store.createPage(title: "B")
        do {
            try await store.moveSnippet(snippetID: snippet.id, fromPageID: UUID().uuidString, toPageID: pageB.id)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testMoveSnippet_UnknownToPage_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.moveSnippet(snippetID: snippet.id, fromPageID: page.id, toPageID: UUID().uuidString)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testMoveSnippet_UnknownSnippetID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, _) = try await store.createPageAndAddSnippet(pageTitle: "A", text: "text")
        let pageB = try await store.createPage(title: "B")
        do {
            try await store.moveSnippet(snippetID: UUID().uuidString, fromPageID: pageA.id, toPageID: pageB.id)
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Error Paths: moveSnippetToNewPage

    func testMoveSnippetToNewPage_UnknownFromPage_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (_, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.moveSnippetToNewPage(snippetID: snippet.id, fromPageID: UUID().uuidString, newPageTitle: "New")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    func testMoveSnippetToNewPage_UnknownSnippetID_Throws() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "text")
        do {
            try await store.moveSnippetToNewPage(snippetID: UUID().uuidString, fromPageID: page.id, newPageTitle: "New")
            XCTFail("Expected NotesStoreError.pageNotFound")
        } catch let err as NotesStoreError {
            XCTAssertEqual(err, .pageNotFound)
        }
    }

    // MARK: - Sort Order & Timestamps

    func testListPages_SortedByUpdatedAtDescending() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let pageA = try await store.createPage(title: "A")
        try await Task.sleep(nanoseconds: 10_000_000)
        let pageB = try await store.createPage(title: "B")

        let pages = await store.listPages()
        XCTAssertEqual(pages[0].id, pageB.id, "Most recently updated page should be first")
        XCTAssertEqual(pages[1].id, pageA.id)
    }

    func testAddSnippet_UpdatesPageTimestamp() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "P")
        let originalUpdatedAt = page.updatedAt

        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await store.addSnippet(toPageID: page.id, text: "new snippet")

        let refreshed = await store.page(id: page.id)
        XCTAssertGreaterThan(refreshed!.updatedAt, originalUpdatedAt)
    }

    func testUpdateSnippet_UpdatesPageTimestamp() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "original")
        let originalUpdatedAt = page.updatedAt

        try await Task.sleep(nanoseconds: 10_000_000)
        try await store.updateSnippet(pageID: page.id, snippetID: snippet.id, newText: "updated")

        let refreshed = await store.page(id: page.id)
        XCTAssertGreaterThan(refreshed!.updatedAt, originalUpdatedAt)
    }

    func testDeleteSnippet_UpdatesPageTimestamp() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "to delete")
        let originalUpdatedAt = page.updatedAt

        try await Task.sleep(nanoseconds: 10_000_000)
        try await store.deleteSnippet(pageID: page.id, snippetID: snippet.id)

        let refreshed = await store.page(id: page.id)
        XCTAssertGreaterThan(refreshed!.updatedAt, originalUpdatedAt)
    }

    // MARK: - Page Lookup & Snapshot

    func testPageLookup_ByID() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "Findme")
        let found = await store.page(id: page.id)
        XCTAssertEqual(found?.title, "Findme")

        let notFound = await store.page(id: UUID().uuidString)
        XCTAssertNil(notFound)
    }

    func testSnapshot_ReturnsCurrentState() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "P1")
        let db = await store.snapshot()
        XCTAssertEqual(db.schemaVersion, 1)
        XCTAssertEqual(db.pages.count, 1)
    }

    func testReplacePageSnippets_WithEmptyArray() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "stuff")
        try await store.replacePageSnippets(pageID: page.id, snippets: [])

        let refreshed = await store.page(id: page.id)
        XCTAssertEqual(refreshed!.snippets.count, 0)
    }

    func testCreatePageAndAddSnippet_IncludesSnippetInReturnedPage() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page, snippet) = try await store.createPageAndAddSnippet(pageTitle: "P", text: "hello")
        XCTAssertEqual(page.snippets.count, 1)
        XCTAssertEqual(page.snippets[0].id, snippet.id)
    }

    // MARK: - Integration

    func testFullWorkflow_CreateMoveDelete() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, snippet) = try await store.createPageAndAddSnippet(pageTitle: "A", text: "moveme")
        let pageB = try await store.createPage(title: "B")
        try await store.moveSnippet(snippetID: snippet.id, fromPageID: pageA.id, toPageID: pageB.id)
        try await store.deletePage(id: pageA.id)

        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].id, pageB.id)
        XCTAssertEqual(pages[0].snippets.count, 1)
        XCTAssertEqual(pages[0].snippets[0].text, "moveme")
    }

    func testPersistAndReload_MultiplePages() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (_, _) = try await store.createPageAndAddSnippet(pageTitle: "P1", text: "s1")
        let (_, _) = try await store.createPageAndAddSnippet(pageTitle: "P2", text: "s2")
        let (_, _) = try await store.createPageAndAddSnippet(pageTitle: "P3", text: "s3")

        let store2 = try NotesStore(directoryURL: dirURL)
        let pages = await store2.listPages()
        XCTAssertEqual(pages.count, 3)

        let titles = Set(pages.map(\.title))
        XCTAssertEqual(titles, ["P1", "P2", "P3"])
    }

    // MARK: - Edge Cases

    func testFirstLaunch_EmptyDirectory_StartsEmpty() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 0)
    }

    func testCorruptedIndex_Throws() throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        // Create pages/ dir and write garbage to index.json
        try FileManager.default.createDirectory(
            at: dirURL.appendingPathComponent("pages"),
            withIntermediateDirectories: true)
        try "not json at all {{{".data(using: .utf8)!.write(
            to: dirURL.appendingPathComponent("index.json"))

        XCTAssertThrowsError(try NotesStore(directoryURL: dirURL))
    }

    func testVeryLongText_PersistsCorrectly() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let longText = String(repeating: "a", count: 100_000)
        let store = try NotesStore(directoryURL: dirURL)
        let (page, _) = try await store.createPageAndAddSnippet(pageTitle: "Long", text: longText)

        let store2 = try NotesStore(directoryURL: dirURL)
        let reloaded = await store2.page(id: page.id)
        XCTAssertEqual(reloaded?.snippets[0].text, longText)
    }

    // MARK: - Per-Page File Tests

    func testCreatePage_WritesPageFile() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "My Test Page")

        let pageFile = dirURL.appendingPathComponent("pages/my-test-page.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pageFile.path))
    }

    func testCreatePage_WritesIndex() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "Indexed Page")

        let indexData = try Data(contentsOf: dirURL.appendingPathComponent("index.json"))
        let entries = try newJSONDecoder().decode([IndexEntry].self, from: indexData)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, page.id)
        XCTAssertEqual(entries[0].slug, "indexed-page")
    }

    func testDeletePage_RemovesPageFile() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "To Delete")
        let pageFile = dirURL.appendingPathComponent("pages/to-delete.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: pageFile.path))

        try await store.deletePage(id: page.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pageFile.path))
    }

    func testUpdatePageTitle_RenamesFile() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let page = try await store.createPage(title: "Old Name")
        let oldFile = dirURL.appendingPathComponent("pages/old-name.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldFile.path))

        try await store.updatePageTitle(pageID: page.id, title: "New Name")
        let newFile = dirURL.appendingPathComponent("pages/new-name.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path), "Old file should be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path), "New file should exist")
    }

    func testUpdatePageTitle_CollisionWithExistingPage() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "Target")
        let pageB = try await store.createPage(title: "Other")

        // Rename pageB to same title as existing page
        try await store.updatePageTitle(pageID: pageB.id, title: "Target")

        // Both pages should still exist — collision resolved with suffix
        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 2)

        // Verify both files exist on disk
        let file1 = dirURL.appendingPathComponent("pages/target.json")
        let file2 = dirURL.appendingPathComponent("pages/target-2.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))
    }

    func testSlugCollision_AppendsCounter() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "Duplicate")
        _ = try await store.createPage(title: "Duplicate")

        let file1 = dirURL.appendingPathComponent("pages/duplicate.json")
        let file2 = dirURL.appendingPathComponent("pages/duplicate-2.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))
    }

    func testPersistence_IndexAndPageStayInSync() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (page1, _) = try await store.createPageAndAddSnippet(pageTitle: "P1", text: "s1")
        _ = try await store.createPage(title: "P2")
        try await store.deletePage(id: page1.id)

        // Reload from disk and verify consistency
        let store2 = try NotesStore(directoryURL: dirURL)
        let pages = await store2.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].title, "P2")
    }

    func testMoveSnippet_WritesBothPageFiles() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, snippet) = try await store.createPageAndAddSnippet(pageTitle: "Source", text: "moveme")
        _ = try await store.createPage(title: "Dest")
        try await store.moveSnippet(snippetID: snippet.id, fromPageID: pageA.id, toPageID: (await store.listPages().first { $0.title == "Dest" }!).id)

        // Reload from disk — both pages should reflect the move
        let store2 = try NotesStore(directoryURL: dirURL)
        let pages = await store2.listPages()
        let source = pages.first { $0.title == "Source" }!
        let dest = pages.first { $0.title == "Dest" }!
        XCTAssertEqual(source.snippets.count, 0)
        XCTAssertEqual(dest.snippets.count, 1)
    }

    func testMoveSnippetToNewPage_CreatesPageFile() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        let (pageA, snippet) = try await store.createPageAndAddSnippet(pageTitle: "A", text: "moveme")
        _ = try await store.moveSnippetToNewPage(snippetID: snippet.id, fromPageID: pageA.id, newPageTitle: "Brand New")

        let newFile = dirURL.appendingPathComponent("pages/brand-new.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
    }

    func testMissingPageFile_HandledGracefully() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        // Create a valid store with one page
        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "Exists")
        _ = try await store.createPage(title: "Ghost")

        // Delete one page file directly (simulate corruption)
        try FileManager.default.removeItem(at: dirURL.appendingPathComponent("pages/ghost.json"))

        // Reload — should not crash, just skip the missing page
        let store2 = try NotesStore(directoryURL: dirURL)
        let pages = await store2.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].title, "Exists")
    }

    // MARK: - Audit Regression Tests

    func testOrphanPageFile_CleanedOnStartup() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "Keep")

        // Plant an orphan page file not referenced by the index
        let orphanFile = dirURL.appendingPathComponent("pages/orphan-ghost.json")
        try "{}".data(using: .utf8)!.write(to: orphanFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanFile.path))

        // Reload — orphan should be cleaned up
        let _ = try NotesStore(directoryURL: dirURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanFile.path), "Orphan page file should be removed on startup")

        // The real page should still exist
        let keepFile = dirURL.appendingPathComponent("pages/keep.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: keepFile.path))
    }

    func testDuplicateIDsInIndex_KeepsLatestByUpdatedAt() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let pagesDir = dirURL.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pagesDir, withIntermediateDirectories: true)

        let pageID = UUID().uuidString
        let olderDate = "2025-01-01T00:00:00.000Z"
        let newerDate = "2026-03-28T00:00:00.000Z"

        // Write index with duplicate IDs — different updatedAt and slugs
        let indexJSON = """
        [
          {"id":"\(pageID)","title":"Old","slug":"old","createdAt":"\(olderDate)","updatedAt":"\(olderDate)","snippetCount":0},
          {"id":"\(pageID)","title":"New","slug":"new","createdAt":"\(olderDate)","updatedAt":"\(newerDate)","snippetCount":0}
        ]
        """
        try indexJSON.data(using: .utf8)!.write(to: dirURL.appendingPathComponent("index.json"))

        // Write matching page file for the newer entry
        let pageJSON = """
        {"id":"\(pageID)","title":"New","createdAt":"\(olderDate)","updatedAt":"\(newerDate)","snippets":[]}
        """
        try pageJSON.data(using: .utf8)!.write(to: pagesDir.appendingPathComponent("new.json"))

        let store = try NotesStore(directoryURL: dirURL)
        let pages = await store.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].title, "New", "Should keep the entry with the latest updatedAt")
    }

    func testCorruptPageFile_SkippedGracefully() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "Good")
        _ = try await store.createPage(title: "Bad")

        // Corrupt one page file
        let badFile = dirURL.appendingPathComponent("pages/bad.json")
        try "not valid json {{{".data(using: .utf8)!.write(to: badFile)

        // Reload — should skip corrupt page, prune its index entry
        let store2 = try NotesStore(directoryURL: dirURL)
        let pages = await store2.listPages()
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].title, "Good")
    }

    func testDirectoryPermissions_OwnerOnly() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let _ = try NotesStore(directoryURL: dirURL)

        let dirAttrs = try FileManager.default.attributesOfItem(atPath: dirURL.path)
        XCTAssertEqual(dirAttrs[.posixPermissions] as? Int, 0o700, "Data directory should be owner-only")

        let pagesAttrs = try FileManager.default.attributesOfItem(
            atPath: dirURL.appendingPathComponent("pages").path)
        XCTAssertEqual(pagesAttrs[.posixPermissions] as? Int, 0o700, "Pages directory should be owner-only")
    }

    func testPersistence_FilePermissions() async throws {
        let dirURL = try makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let store = try NotesStore(directoryURL: dirURL)
        _ = try await store.createPage(title: "P")

        // Check index.json permissions
        let indexAttrs = try FileManager.default.attributesOfItem(
            atPath: dirURL.appendingPathComponent("index.json").path)
        XCTAssertEqual(indexAttrs[.posixPermissions] as? Int, 0o600)

        // Check page file permissions
        let pageAttrs = try FileManager.default.attributesOfItem(
            atPath: dirURL.appendingPathComponent("pages/p.json").path)
        XCTAssertEqual(pageAttrs[.posixPermissions] as? Int, 0o600)
    }
}

private func makeTempDirectoryURL() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
