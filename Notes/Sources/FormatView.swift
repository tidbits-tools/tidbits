import SwiftUI
import NotesCore

struct FormatChange: Identifiable {
    let id: String
    let original: String
    let formatted: String
}

struct FormatView: View {
    let snippets: [Snippet]
    var onApply: ([Snippet]) -> Void
    var onDismiss: () -> Void

    @State private var changes: [FormatChange] = []

    // Colors
    private let bgBase = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let textPrimary = Color(white: 0.92)
    private let textSecondary = Color(white: 0.5)
    private let textTertiary = Color(white: 0.38)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundColor(textSecondary)
                Text("Format Text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Content
            if changes.isEmpty {
                emptyView
            } else {
                changesView
            }

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Actions
            actionsBar
        }
        .frame(width: 500, height: 400)
        .background(bgBase)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 40, y: 20)
        .onAppear {
            computeChanges()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundColor(Color.green.opacity(0.7))
            Text("No formatting changes needed.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var changesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(changes) { change in
                    changeView(change)
                }
            }
            .padding(16)
        }
    }

    private func changeView(_ change: FormatChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show diff with highlighted changes
            diffView(original: change.original, formatted: change.formatted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func diffView(original: String, formatted: String) -> some View {
        // Simple diff: show formatted text with changed characters highlighted
        // For simplicity, we'll show the formatted text and highlight curly quotes and capitalized letters
        let attributedString = createDiffAttributedString(original: original, formatted: formatted)
        return Text(attributedString)
            .font(.system(size: 13))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func createDiffAttributedString(original: String, formatted: String) -> AttributedString {
        var result = AttributedString()

        // Simple character-by-character comparison
        let origChars = Array(original)
        let formChars = Array(formatted)

        var i = 0
        var j = 0

        while i < origChars.count || j < formChars.count {
            if i < origChars.count && j < formChars.count {
                if origChars[i] == formChars[j] {
                    // Same character
                    var charStr = AttributedString(String(formChars[j]))
                    charStr.foregroundColor = textSecondary
                    result += charStr
                    i += 1
                    j += 1
                } else {
                    // Different - show formatted with highlight
                    var charStr = AttributedString(String(formChars[j]))
                    charStr.foregroundColor = Color.green
                    charStr.backgroundColor = Color.green.opacity(0.2)
                    result += charStr
                    i += 1
                    j += 1
                }
            } else if j < formChars.count {
                // Added character
                var charStr = AttributedString(String(formChars[j]))
                charStr.foregroundColor = Color.green
                charStr.backgroundColor = Color.green.opacity(0.2)
                result += charStr
                j += 1
            } else {
                // Deleted character (skip)
                i += 1
            }
        }

        return result
    }

    private var actionsBar: some View {
        HStack(spacing: 10) {
            Button(action: onDismiss) {
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
            .keyboardShortcut(.cancelAction)

            Spacer()

            if !changes.isEmpty {
                Button(action: applyChanges) {
                    Text("Apply \(changes.count) change\(changes.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.95))
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
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    private func computeChanges() {
        let formatted = TextFormatter.formatSnippets(snippets)
        changes = formatted.map { change in
            FormatChange(
                id: change.original.id,
                original: change.original.text,
                formatted: change.formatted
            )
        }
    }

    private func applyChanges() {
        let changeMap = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0.formatted) })
        let updatedSnippets = snippets.map { snippet -> Snippet in
            if let newText = changeMap[snippet.id] {
                return Snippet(
                    createdAt: snippet.createdAt,
                    id: snippet.id,
                    source: snippet.source,
                    text: newText
                )
            }
            return snippet
        }
        onApply(updatedSnippets)
    }
}
