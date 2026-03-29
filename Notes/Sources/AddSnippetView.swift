import SwiftUI
import NotesCore

private enum Destination: Hashable {
    case existing(String)
    case new
}

// MARK: - Markdown Text Parsing
/// Parses simple markdown (**bold**, *italic*) and returns an AttributedString
func parseMarkdownToAttributedString(_ text: String, baseColor: Color = .white) -> AttributedString {
    var result = AttributedString()
    var remaining = text[...]
    
    while !remaining.isEmpty {
        // Look for bold (***text*** for bold+italic, **text** for bold, *text* for italic)
        if let boldItalicRange = remaining.range(of: #"\*\*\*(.+?)\*\*\*"#, options: .regularExpression) {
            // Add text before the match
            let before = remaining[..<boldItalicRange.lowerBound]
            if !before.isEmpty {
                var plain = AttributedString(String(before))
                plain.foregroundColor = baseColor
                result += plain
            }
            
            // Extract and style the bold+italic text
            let matched = String(remaining[boldItalicRange])
            let content = String(matched.dropFirst(3).dropLast(3))
            var styled = AttributedString(content)
            styled.font = .system(size: 15, weight: .bold).italic()
            styled.foregroundColor = baseColor
            result += styled
            
            remaining = remaining[boldItalicRange.upperBound...]
        } else if let boldRange = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
            // Add text before the match
            let before = remaining[..<boldRange.lowerBound]
            if !before.isEmpty {
                var plain = AttributedString(String(before))
                plain.foregroundColor = baseColor
                result += plain
            }
            
            // Extract and style the bold text
            let matched = String(remaining[boldRange])
            let content = String(matched.dropFirst(2).dropLast(2))
            var styled = AttributedString(content)
            styled.font = .system(size: 15, weight: .bold)
            styled.foregroundColor = baseColor
            result += styled
            
            remaining = remaining[boldRange.upperBound...]
        } else if let italicRange = remaining.range(of: #"\*([^*]+?)\*"#, options: .regularExpression) {
            // Add text before the match
            let before = remaining[..<italicRange.lowerBound]
            if !before.isEmpty {
                var plain = AttributedString(String(before))
                plain.foregroundColor = baseColor
                result += plain
            }
            
            // Extract and style the italic text
            let matched = String(remaining[italicRange])
            let content = String(matched.dropFirst(1).dropLast(1))
            var styled = AttributedString(content)
            styled.font = .system(size: 15).italic()
            styled.foregroundColor = baseColor
            result += styled
            
            remaining = remaining[italicRange.upperBound...]
        } else {
            // No more matches, add the rest
            var plain = AttributedString(String(remaining))
            plain.foregroundColor = baseColor
            result += plain
            break
        }
    }
    
    return result
}

struct AddSnippetView: View {
    @EnvironmentObject private var appState: AppState

    let initialText: String
    var onDismiss: (() -> Void)?

    init(initialText: String, onDismiss: (() -> Void)? = nil) {
        self.initialText = initialText
        self.onDismiss = onDismiss
        _editableText = State(initialValue: initialText)
    }

    @State private var editableText: String
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    @State private var destination: Destination = .new
    @State private var newPageTitle: String = ""
    @State private var isSaving = false
    @State private var isSaved = false
    @State private var errorMessage: String?
    @State private var hoveredPageID: String?

    // Colors
    private let bgBase = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let textPrimary = Color(white: 0.92)
    private let textSecondary = Color(white: 0.5)
    private let textTertiary = Color(white: 0.38)

    var body: some View {
        VStack(spacing: 0) {
            // Header - simple
            Text("Add to Tidbits")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
                .onTapGesture { isEditing = false }
            
            // Divider
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            
            // Page selector
            ScrollView {
                VStack(spacing: 0) {
                    // New page option
                    PageRow(
                        title: "New page",
                        isSelected: destination == .new,
                        isHovered: false,
                        isNew: true
                    )
                    .onTapGesture { isEditing = false; destination = .new }

                    ForEach(appState.pages) { page in
                        PageRow(
                            title: page.title,
                            count: page.snippets.count,
                            isSelected: destination == .existing(page.id),
                            isHovered: hoveredPageID == page.id
                        )
                        .onTapGesture { isEditing = false; destination = .existing(page.id) }
                        .onHover { hoveredPageID = $0 ? page.id : nil }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(height: min(CGFloat(appState.pages.count + 1) * 44 + 12, 180))
            
            // New page title input
            if case .new = destination {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                
                TextField("Page title", text: $newPageTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            
            // Preview / Edit section
            VStack(alignment: .leading, spacing: 8) {
                Text("Snippet")
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditing = false }
                    .animation(nil, value: isEditing)

                if isEditing {
                    // Editing mode - TextEditor with box
                    TextEditor(text: $editableText)
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary)
                        .scrollContentBackground(.hidden)
                        .lineSpacing(4)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .focused($isTextEditorFocused)
                        .onAppear {
                            isTextEditorFocused = true
                        }
                        .onChange(of: isTextEditorFocused) { _, focused in
                            if !focused {
                                isEditing = false
                            }
                        }
                        .onKeyPress(.escape) {
                            isEditing = false
                            return .handled
                        }
                } else {
                    // Preview mode - original styling, tap anywhere to edit
                    Text(parseMarkdownToAttributedString(editableText, baseColor: textSecondary))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditing = true
                        }
                }
            }
            .padding(16)
            .frame(height: isEditing ? 280 : 120, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
            
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            
            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1, green: 0.4, blue: 0.4))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }
            
            // Actions
            HStack(spacing: 10) {
                Button(action: dismiss) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textSecondary)
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
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(action: save) {
                    HStack(spacing: 4) {
                        if isSaved {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(isSaved ? "Saved" : (isSaving ? "Saving..." : "Save"))
                    }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSaved ? Color(red: 0.2, green: 0.83, blue: 0.6) : Color(white: 0.95))
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
                        .opacity(canSave ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 420)
        .background(bgBase)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 40, y: 20)
        .onAppear {
            destination = .new
        }
    }
    
    private var canSave: Bool {
        if isSaving { return false }
        if editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if case .new = destination {
            return !newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }
    
    private func dismiss() {
        onDismiss?()
    }

    private func save() {
        guard let store = appState.store else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let textToSave = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
                switch destination {
                case .existing(let pageID):
                    _ = try await store.addSnippet(
                        toPageID: pageID,
                        text: textToSave,
                        source: SnippetSource(applicationName: "Services", urlString: nil)
                    )
                case .new:
                    let title = newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    _ = try await store.createPageAndAddSnippet(
                        pageTitle: title,
                        text: textToSave,
                        source: SnippetSource(applicationName: "Services", urlString: nil)
                    )
                }

                await MainActor.run {
                    isSaving = false
                    isSaved = true
                    appState.reloadPages()
                }

                try? await Task.sleep(nanoseconds: 600_000_000)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    self.errorMessage = String(describing: error)
                }
            }
        }
    }
}

// MARK: - Page Row
private struct PageRow: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let isHovered: Bool
    var isNew: Bool = false

    private let textPrimary = Color(white: 0.92)
    private let textSecondary = Color(white: 0.5)

    var body: some View {
        HStack(spacing: 12) {
            // Simple icon
            Image(systemName: isNew ? "plus.circle" : "doc.text")
                .font(.system(size: 16))
                .foregroundColor(textSecondary)
                .frame(width: 24)

            // Title
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(textPrimary)
                .lineLimit(1)

            Spacer()

            // Count
            if let count {
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.35))
            }

            // Checkmark
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.06) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
    }
}
