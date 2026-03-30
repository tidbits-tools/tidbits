import SwiftUI
import NotesCore

// MARK: - Design Tokens (Linear/Raycast style)
enum Theme {
    static let bg = Color(red: 0.086, green: 0.086, blue: 0.094)        // #161618
    static let bgElevated = Color(red: 0.075, green: 0.075, blue: 0.082) // #131315
    static let bgHover = Color.white.opacity(0.04)
    static let border = Color.white.opacity(0.06)


    static let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.94)  // #EDEDF0
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.58) // #8C8C94
    static let textTertiary = Color(red: 0.35, green: 0.35, blue: 0.38) // #59595F

    static let accent = Color(red: 0.55, green: 0.45, blue: 1.0)        // Violet
    static let accentSubtle = Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.10)
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPageID: String?
    @State private var isCreatingPage = false
    @State private var newPageTitle = ""
    @State private var hoveredPageID: String?
    @State private var showCopiedAll = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar

            // Divider
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)

            // Detail
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .task {
            appState.reloadPages()
        }
        .sheet(isPresented: $isCreatingPage) {
            createPageSheet
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (with top padding for traffic lights)
            HStack {
                Text("Tidbits")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()

            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            .padding(.bottom, 8)

            VStack(spacing: 2) {
                Button(action: {
                    copyAllPrompt()
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    showCopiedAll = true
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showCopiedAll = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: showCopiedAll ? "checkmark" : "square.on.square")
                            .contentTransition(.symbolEffect(.replace, options: .speed(3)))
                            .font(.system(size: 11))
                            .frame(width: 14)
                        Text(showCopiedAll ? "Copied" : "Copy path")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(showCopiedAll ? Color(red: 0.2, green: 0.83, blue: 0.6) : Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .animation(.easeInOut(duration: 0.2), value: showCopiedAll)
                }
                .buttonStyle(.plain)

                Button(action: { isCreatingPage = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("New document")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Pages list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(appState.pages) { page in
                        SidebarPageRow(
                            page: page,
                            isSelected: selectedPageID == page.id,
                            isHovered: hoveredPageID == page.id
                        )
                        .onTapGesture { selectedPageID = page.id }
                        .onHover { isHovered in
                            hoveredPageID = isHovered ? page.id : nil
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 200)
        .background(Theme.bgElevated)
    }

    private var detail: some View {
        Group {
            if let pageID = selectedPageID,
               let page = appState.pages.first(where: { $0.id == pageID }) {
                PageDetailView(page: page)
                    .environmentObject(appState)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundColor(Theme.textTertiary)
                    Text("Select a page")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
            }
        }
    }

    private var createPageSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New document")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)

            TextField("Title", text: $newPageTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .padding(12)
                .background(Theme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
                .frame(width: 300)

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    newPageTitle = ""
                    isCreatingPage = false
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createPage()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(newPageTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(Theme.bg)
    }

    private func copyAllPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ClaudePrompt.allNotes(), forType: .string)
    }

    private func createPage() {
        guard let store = appState.store else { return }
        let title = newPageTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        Task {
            _ = try? await store.createPage(title: title)
            appState.reloadPages()
            newPageTitle = ""
            isCreatingPage = false
        }
    }
}

// MARK: - Sidebar Row
struct SidebarPageRow: View {
    let page: Page
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack {
            Text(page.title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? Theme.textPrimary : Color.white.opacity(0.4))
                .lineLimit(1)

            Spacer()

            Text("\(page.snippets.count)")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? Theme.accent.opacity(0.6) : Color.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Theme.accentSubtle : (isHovered ? Theme.bgHover.opacity(0.5) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.12) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityLabel(page.title)
    }
}

// MARK: - Page Detail View
struct PageDetailView: View {
    let page: Page
    @EnvironmentObject private var appState: AppState
    @State private var isAddingSnippet = false
    @State private var newSnippetText = ""
    @State private var editingTexts: [String: String] = [:]
    @State private var saveTasks: [String: Task<Void, Never>] = [:]
    @State private var snippetToMove: Snippet?
    @State private var isFormatting = false
    @State private var isEditingTitle = false
    @State private var titleText = ""
    @State private var editTitleText = ""

    @State private var showCopiedPage = false
    @State private var isTitleHovered = false
    @State private var editing = EditingState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title with hover pencil
                HStack(alignment: .center, spacing: 10) {
                    Text(titleText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    if isTitleHovered {
                        Button(action: {
                            editTitleText = titleText
                            isEditingTitle = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onHover { isTitleHovered = $0 }
                .padding(.bottom, 32)
                .opacity(editing.editingSnippetID != nil ? 0.3 : 1)

                // Document section header with Format button
                if !page.snippets.isEmpty {
                    HStack {
                        Button(action: {
                            copyPagePrompt()
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                            showCopiedPage = true
                            Task {
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                showCopiedPage = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCopiedPage ? "checkmark" : "square.on.square")
                                    .contentTransition(.symbolEffect(.replace, options: .speed(3)))
                                    .font(.system(size: 11))
                                    .frame(width: 14)
                                Text("Copy Path")
                                    .font(.system(size: 11))
                                    .opacity(showCopiedPage ? 0 : 1)
                                    .overlay {
                                        Text("Copied")
                                            .font(.system(size: 11))
                                            .opacity(showCopiedPage ? 1 : 0)
                                    }
                            }
                            .foregroundColor(showCopiedPage ? Color(red: 0.2, green: 0.83, blue: 0.6) : Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.2), value: showCopiedPage)
                        }
                        .buttonStyle(.plain)

                        ActionButton(
                            icon: "textformat",
                            label: "Format",
                            action: { isFormatting = true }
                        )

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                    }
                    .padding(.bottom, 8)
                    .opacity(editing.editingSnippetID != nil ? 0.3 : 1)
                }

                // Snippets as simple text blocks
                if page.snippets.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(page.snippets) { snippet in
                            EditableSnippetBlock(
                                snippet: snippet,
                                pageID: page.id,
                                text: editingTexts[snippet.id] ?? snippet.text,
                                isEditing: Binding(
                                    get: { editing.isEditing(snippet.id) },
                                    set: { newValue in
                                        if newValue {
                                            editing.handleSnippetTap(snippet.id)
                                        } else {
                                            editing.stopEditing()
                                        }
                                    }
                                ),
                                onTextChange: { newText in
                                    editingTexts[snippet.id] = newText
                                    debouncedSave(pageID: page.id, snippetID: snippet.id, text: newText)
                                },
                                onDelete: {
                                    editing.handleDelete(snippet.id)
                                    deleteSnippet(pageID: page.id, snippetID: snippet.id)
                                }
                            )
                            .opacity(editing.editingSnippetID != nil && !editing.isEditing(snippet.id) ? 0.3 : 1)
                            .environmentObject(appState)
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                editing.handleBackgroundTap()
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .overlay(alignment: .bottomTrailing) {
            if editing.editingSnippetID == nil {
                addButton
                    .padding(16)
            }
        }
        .sheet(isPresented: $isAddingSnippet) {
            addSnippetSheet
        }
        .sheet(item: $snippetToMove) { snippet in
            MoveSnippetView(
                snippet: snippet,
                currentPageID: page.id,
                onDismiss: { snippetToMove = nil }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $isFormatting) {
            FormatView(
                snippets: page.snippets,
                onApply: { newSnippets in
                    replaceSnippets(newSnippets)
                    isFormatting = false
                },
                onDismiss: { isFormatting = false }
            )
        }
        .sheet(isPresented: $isEditingTitle) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Rename document")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                TextField("Title", text: $editTitleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Theme.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                    .frame(width: 300)

                HStack(spacing: 10) {
                    Spacer()
                    Button("Cancel") {
                        isEditingTitle = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])

                    Button("Save") {
                        saveTitle(editTitleText)
                        isEditingTitle = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(editTitleText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .background(Theme.bg)
        }
        .onAppear {
            titleText = page.title
            isEditingTitle = false
            for snippet in page.snippets {
                editingTexts[snippet.id] = snippet.text
            }
        }
        .onChange(of: page.title) { _, newValue in
            titleText = newValue
        }
        .onChange(of: page.id) { _, _ in
            isEditingTitle = false
            editing.handlePageChange()
            titleText = page.title
        }
    }

    private func copyPagePrompt() {
        NSPasteboard.general.clearContents()
        let slug = appState.store?.slug(forPageID: page.id)
        let path = slug.map { ClaudePrompt.page(slug: $0) } ?? ClaudePrompt.allNotes()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func debouncedSave(pageID: String, snippetID: String, text: String) {
        // Cancel only this snippet's pending save, not others
        saveTasks[snippetID]?.cancel()
        saveTasks[snippetID] = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            guard let store = appState.store else { return }
            try? await store.updateSnippet(pageID: pageID, snippetID: snippetID, newText: text)
            await appState.reloadPages()
        }
    }

    private func saveTitle(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        titleText = trimmed
        guard let store = appState.store else { return }
        Task {
            try? await store.updatePageTitle(pageID: page.id, title: trimmed)
            await appState.reloadPages()
        }
    }

    private func deleteSnippet(pageID: String, snippetID: String) {
        guard let store = appState.store else { return }
        Task {
            try? await store.deleteSnippet(pageID: pageID, snippetID: snippetID)
            await appState.reloadPages()
        }
    }

    private func replaceSnippets(_ snippets: [Snippet]) {
        guard let store = appState.store else { return }
        Task {
            try? await store.replacePageSnippets(pageID: page.id, snippets: snippets)
            await appState.reloadPages()
            // Update local editing state
            editingTexts.removeAll()
            for snippet in snippets {
                editingTexts[snippet.id] = snippet.text
            }
        }
    }

    private var emptyState: some View {
        Text("No snippets yet. Capture text from Safari via Services, or click + to add.")
            .font(.system(size: 15))
            .foregroundColor(Theme.textTertiary)
            .padding(.vertical, 24)
    }

    private var addButton: some View {
        Button(action: { isAddingSnippet = true }) {
            Image(systemName: "pencil")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.bgElevated)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var addSnippetSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add snippet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)

            TextEditor(text: $newSnippetText)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(width: 420, height: 160)
                .padding(12)
                .background(Theme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    newSnippetText = ""
                    isAddingSnippet = false
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addSnippet()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(newSnippetText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(Theme.bg)
    }

    private func addSnippet() {
        guard let store = appState.store else { return }
        let content = newSnippetText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        Task {
            try? await store.addSnippet(toPageID: page.id, text: content)
            appState.reloadPages()
            newSnippetText = ""
            isAddingSnippet = false
        }
    }
}

// MARK: - Editable Snippet Block
struct EditableSnippetBlock: View {
    let snippet: Snippet
    let pageID: String
    let externalText: String
    @Binding var isEditing: Bool
    let onTextChange: (String) -> Void
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var internalText: String
    @State private var showDeleteConfirm = false
    @State private var showSnippetCopied = false

    init(snippet: Snippet, pageID: String, text: String, isEditing: Binding<Bool>, onTextChange: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.snippet = snippet
        self.pageID = pageID
        self.externalText = text
        self._isEditing = isEditing
        self.onTextChange = onTextChange
        self.onDelete = onDelete
        self._internalText = State(initialValue: text)
    }

    private static let snippetFont: Font = .system(size: 15)
    private static let snippetPadding: CGFloat = 16

    var body: some View {
        Group {
            if isEditing {
                TextEditor(text: Binding(
                    get: { internalText },
                    set: { newValue in
                        internalText = newValue
                        onTextChange(newValue)
                    }
                ))
                .font(Self.snippetFont)
                .lineSpacing(0)
                .foregroundColor(Color.white.opacity(0.75))
                .scrollContentBackground(.hidden)
                .textSelection(.enabled)
                .padding(Self.snippetPadding)
                .focused($isFocused)
                .onExitCommand { isEditing = false }
            } else {
                Text(parseMarkdownToAttributedString(internalText, baseColor: Color.white.opacity(0.75)))
                    .font(Self.snippetFont)
                    .lineSpacing(0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Self.snippetPadding)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditing = true }
            }
        }
        .overlay(alignment: .topLeading) {
            if isEditing {
                Text("Editing")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.15)))
                    .offset(y: -22)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isHovered && !isEditing ? Color.white.opacity(0.08) : Color.white.opacity(0.05), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            if isHovered && !isEditing {
                HStack(spacing: 0) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(internalText, forType: .string)
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        showSnippetCopied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            showSnippetCopied = false
                        }
                    }) {
                        Image(systemName: showSnippetCopied ? "checkmark" : "square.on.square")
                            .contentTransition(.symbolEffect(.replace, options: .speed(3)))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(showSnippetCopied ? Color(red: 0.2, green: 0.83, blue: 0.6) : Color.white.opacity(0.5))
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("Copy snippet")

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 12)

                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("Delete snippet")
                }
                .padding(.horizontal, 4)
                .background(Capsule().fill(Theme.bg))
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .offset(x: 8, y: -8)
            }
        }
        .onHover { isHovered = $0 }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: externalText) { _, newValue in
            if !isEditing {
                internalText = newValue
            }
        }
        .alert("Delete snippet?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isEnabled ? Color(white: 0.95) : Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Action Button (with hover state)
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(isHovered ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
