import Foundation

public enum NotesStoreError: Error, Equatable {
    case pageNotFound
    case indexDesync(pageID: String)
}

/// Single-writer store for notes pages + snippets.
/// Each page is persisted as its own JSON file under `pages/`.
/// A lightweight `index.json` stores page metadata for fast listing.
public actor NotesStore {
    private var index: [String: IndexEntry]  // keyed by page ID
    private var pages: [String: Page]  // keyed by page ID
    private let directoryURL: URL

    public init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        self.index = [:]
        self.pages = [:]

        try ensureDirectoryStructure()

        self.index = try loadIndex()
        self.pages = loadAllPages()

        // Prune index entries whose page file is missing or corrupt
        let orphanIDs = index.keys.filter { pages[$0] == nil }
        if !orphanIDs.isEmpty {
            for id in orphanIDs { index.removeValue(forKey: id) }
            try persistIndex()
        }

        // Remove orphan page files not referenced by any index entry
        Self.removeOrphanPageFiles(in: directoryURL, knownSlugs: Set(index.values.map(\.slug)))
    }

    public static func defaultDirectoryURL(appFolderName: String = "Notes") throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent(appFolderName, isDirectory: true)
    }

    // MARK: - Read

    public func snapshot() -> NotesDatabase {
        NotesDatabase(pages: Array(pages.values), schemaVersion: 1)
    }

    public func listPages() -> [Page] {
        index.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { pages[$0.id] }
    }

    public func page(id: String) -> Page? {
        pages[id]
    }

    // MARK: - Write

    @discardableResult
    public func createPage(title: String) throws -> Page {
        let page = Page.create(title: title)
        let slug = resolveSlug(for: title)
        let entry = IndexEntry.from(page: page, slug: slug)

        pages[page.id] = page
        index[page.id] = entry

        try persistPageAndIndex(page, slug: slug)
        return page
    }

    @discardableResult
    public func addSnippet(toPageID pageID: String, text: String, source: SnippetSource? = nil) throws -> Snippet {
        guard var page = pages[pageID] else {
            throw NotesStoreError.pageNotFound
        }
        let snippet = Snippet.create(text: text, source: source)
        page.snippets.append(snippet)
        page.updatedAt = Date()

        pages[pageID] = page
        try updateIndexEntry(for: pageID, page: page)

        try persistPageAndIndex(page, slug: slugForPage(pageID))
        return snippet
    }

    @discardableResult
    public func createPageAndAddSnippet(pageTitle: String, text: String, source: SnippetSource? = nil) throws -> (Page, Snippet) {
        // Single page write + single index write (not 4 writes from calling createPage then addSnippet)
        var page = Page.create(title: pageTitle)
        let snippet = Snippet.create(text: text, source: source)
        page.snippets = [snippet]

        let slug = resolveSlug(for: pageTitle)
        let entry = IndexEntry.from(page: page, slug: slug)

        pages[page.id] = page
        index[page.id] = entry

        try persistPageAndIndex(page, slug: slug)
        return (page, snippet)
    }

    public func deletePage(id: String) throws {
        guard let entry = index[id] else {
            throw NotesStoreError.pageNotFound
        }
        let slug = entry.slug

        pages.removeValue(forKey: id)
        index.removeValue(forKey: id)

        // Remove page file from disk — non-fatal if file is already gone
        let pageFile = pageFileURL(slug: slug)
        if FileManager.default.fileExists(atPath: pageFile.path) {
            try FileManager.default.removeItem(at: pageFile)
        }
        try persistIndex()
    }

    public func updateSnippet(pageID: String, snippetID: String, newText: String) throws {
        guard var page = pages[pageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard let snippetIdx = page.snippets.firstIndex(where: { $0.id == snippetID }) else {
            throw NotesStoreError.pageNotFound
        }
        page.snippets[snippetIdx].text = newText
        page.updatedAt = Date()

        pages[pageID] = page
        try updateIndexEntry(for: pageID, page: page)

        try persistPageAndIndex(page, slug: slugForPage(pageID))
    }

    public func deleteSnippet(pageID: String, snippetID: String) throws {
        guard var page = pages[pageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard let snippetIdx = page.snippets.firstIndex(where: { $0.id == snippetID }) else {
            throw NotesStoreError.pageNotFound
        }
        page.snippets.remove(at: snippetIdx)
        page.updatedAt = Date()

        pages[pageID] = page
        try updateIndexEntry(for: pageID, page: page)

        try persistPageAndIndex(page, slug: slugForPage(pageID))
    }

    public func updatePageTitle(pageID: String, title: String) throws {
        guard var page = pages[pageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard let existing = index[pageID] else {
            throw NotesStoreError.pageNotFound
        }

        let oldSlug = existing.slug
        let newSlug = resolveSlug(for: title, excluding: pageID)

        page.title = title
        page.updatedAt = Date()
        pages[pageID] = page

        index[pageID] = IndexEntry.from(page: page, slug: newSlug)

        // Crash-safe ordering: write new file → update index → delete old file
        try persistPage(page, slug: newSlug)
        try persistIndex()
        if oldSlug != newSlug {
            let oldFile = pageFileURL(slug: oldSlug)
            if FileManager.default.fileExists(atPath: oldFile.path) {
                try FileManager.default.removeItem(at: oldFile)
            }
        }
    }

    public func replacePageSnippets(pageID: String, snippets: [Snippet]) throws {
        guard var page = pages[pageID] else {
            throw NotesStoreError.pageNotFound
        }
        page.snippets = snippets
        page.updatedAt = Date()

        pages[pageID] = page
        try updateIndexEntry(for: pageID, page: page)

        try persistPageAndIndex(page, slug: slugForPage(pageID))
    }

    public func moveSnippet(snippetID: String, fromPageID: String, toPageID: String) throws {
        guard var fromPage = pages[fromPageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard var toPage = pages[toPageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard let snippetIdx = fromPage.snippets.firstIndex(where: { $0.id == snippetID }) else {
            throw NotesStoreError.pageNotFound
        }

        let snippet = fromPage.snippets.remove(at: snippetIdx)
        toPage.snippets.append(snippet)
        fromPage.updatedAt = Date()
        toPage.updatedAt = Date()

        pages[fromPageID] = fromPage
        pages[toPageID] = toPage
        try updateIndexEntry(for: fromPageID, page: fromPage)
        try updateIndexEntry(for: toPageID, page: toPage)

        // Write destination first — crash after this duplicates snippet (recoverable)
        // rather than losing it (unrecoverable)
        try persistPage(toPage, slug: slugForPage(toPageID))
        try persistPage(fromPage, slug: slugForPage(fromPageID))
        try persistIndex()
    }

    @discardableResult
    public func moveSnippetToNewPage(snippetID: String, fromPageID: String, newPageTitle: String) throws -> Page {
        guard var fromPage = pages[fromPageID] else {
            throw NotesStoreError.pageNotFound
        }
        guard let snippetIdx = fromPage.snippets.firstIndex(where: { $0.id == snippetID }) else {
            throw NotesStoreError.pageNotFound
        }

        let snippet = fromPage.snippets.remove(at: snippetIdx)
        fromPage.updatedAt = Date()

        var newPage = Page.create(title: newPageTitle)
        newPage.snippets = [snippet]

        let newSlug = resolveSlug(for: newPageTitle)
        let newEntry = IndexEntry.from(page: newPage, slug: newSlug)

        pages[fromPageID] = fromPage
        pages[newPage.id] = newPage
        try updateIndexEntry(for: fromPageID, page: fromPage)
        index[newPage.id] = newEntry

        // Write destination first (same crash-safety rationale as moveSnippet)
        try persistPage(newPage, slug: newSlug)
        try persistPage(fromPage, slug: slugForPage(fromPageID))
        try persistIndex()
        return newPage
    }

    // MARK: - Persistence helpers

    private func pageFileURL(slug: String) -> URL {
        directoryURL
            .appendingPathComponent("pages", isDirectory: true)
            .appendingPathComponent("\(slug).json", isDirectory: false)
    }

    private func indexFileURL() -> URL {
        directoryURL.appendingPathComponent("index.json", isDirectory: false)
    }

    private func persistPageAndIndex(_ page: Page, slug: String) throws {
        try persistPage(page, slug: slug)
        try persistIndex()
    }

    private func persistPage(_ page: Page, slug: String) throws {
        let encoder = newJSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(page)
        let url = pageFileURL(slug: slug)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func persistIndex() throws {
        let encoder = newJSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Array(index.values))
        let url = indexFileURL()
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func slugForPage(_ pageID: String) throws -> String {
        guard let entry = index[pageID] else {
            throw NotesStoreError.indexDesync(pageID: pageID)
        }
        return entry.slug
    }

    private func resolveSlug(for title: String, excluding pageID: String? = nil) -> String {
        let base = slugify(title)
        let usedSlugs = Set(index.filter { $0.key != pageID }.map(\.value.slug))
        var candidate = base
        var counter = 2
        while usedSlugs.contains(candidate) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }
        return candidate
    }

    private func updateIndexEntry(for pageID: String, page: Page) throws {
        guard let existing = index[pageID] else {
            throw NotesStoreError.indexDesync(pageID: pageID)
        }
        index[pageID] = IndexEntry.from(page: page, slug: existing.slug)
    }

    private static func removeOrphanPageFiles(in directoryURL: URL, knownSlugs: Set<String>) {
        let pagesDir = directoryURL.appendingPathComponent("pages", isDirectory: true)
        let knownFiles = Set(knownSlugs.map { "\($0).json" })
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: pagesDir.path) else { return }
        for filename in contents where filename.hasSuffix(".json") && !knownFiles.contains(filename) {
            try? FileManager.default.removeItem(at: pagesDir.appendingPathComponent(filename))
        }
    }

    // MARK: - Loading

    private func ensureDirectoryStructure() throws {
        let ownerOnly: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        let pagesDir = directoryURL.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pagesDir, withIntermediateDirectories: true, attributes: ownerOnly)
        // Parent dir may already exist with default perms from createDirectory's intermediates
        try FileManager.default.setAttributes(ownerOnly, ofItemAtPath: directoryURL.path)
    }

    private func loadIndex() throws -> [String: IndexEntry] {
        let url = indexFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        let entries = try newJSONDecoder().decode([IndexEntry].self, from: data)
        return Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a.updatedAt >= b.updatedAt ? a : b })
    }

    private func loadAllPages() -> [String: Page] {
        var result: [String: Page] = [:]
        let pagesDir = directoryURL.appendingPathComponent("pages", isDirectory: true)
        for entry in index.values {
            let url = pagesDir.appendingPathComponent("\(entry.slug).json")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard let data = try? Data(contentsOf: url),
                  let page = try? newJSONDecoder().decode(Page.self, from: data) else { continue }
            result[page.id] = page
        }
        return result
    }
}
