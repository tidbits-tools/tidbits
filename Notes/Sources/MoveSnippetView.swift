import SwiftUI
import NotesCore

private enum Destination: Hashable {
    case existing(String)
    case new
}

struct MoveSnippetView: View {
    @EnvironmentObject private var appState: AppState

    let snippet: Snippet
    let currentPageID: String
    var onDismiss: (() -> Void)?

    @State private var destination: Destination = .new
    @State private var newPageTitle: String = ""
    @State private var isMoving = false
    @State private var errorMessage: String?
    @State private var hoveredPageID: String?

    // Colors
    private let bgBase = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let textPrimary = Color(white: 0.92)
    private let textSecondary = Color(white: 0.5)
    private let textTertiary = Color(white: 0.38)

    // Filter out current page
    private var otherPages: [Page] {
        appState.pages.filter { $0.id != currentPageID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Move snippet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            // Divider
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Snippet preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Snippet")
                    .font(.system(size: 11))
                    .foregroundColor(textTertiary)

                Text(snippetPreview)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            // Page selector
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(otherPages) { page in
                        PageRow(
                            title: page.title,
                            subtitle: "\(page.snippets.count) snippets",
                            isSelected: destination == .existing(page.id),
                            isHovered: hoveredPageID == page.id
                        )
                        .onTapGesture { destination = .existing(page.id) }
                        .onHover { hoveredPageID = $0 ? page.id : nil }
                    }

                    // New page option
                    PageRow(
                        title: "New page",
                        subtitle: nil,
                        isSelected: destination == .new,
                        isHovered: false,
                        isNew: true
                    )
                    .onTapGesture { destination = .new }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(height: min(CGFloat(otherPages.count + 1) * 44 + 12, 180))

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
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: move) {
                    Text(isMoving ? "Moving..." : "Move")
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
                        .opacity(canMove ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canMove)
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
            if !otherPages.isEmpty {
                destination = .existing(otherPages[0].id)
            }
        }
    }

    private var snippetPreview: String {
        let text = snippet.text
        if text.count > 150 {
            return String(text.prefix(150)) + "..."
        }
        return text
    }

    private var canMove: Bool {
        if isMoving { return false }
        if case .new = destination {
            return !newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func dismiss() {
        onDismiss?()
    }

    private func move() {
        guard let store = appState.store else { return }
        isMoving = true
        errorMessage = nil

        Task {
            do {
                switch destination {
                case .existing(let pageID):
                    try await store.moveSnippet(
                        snippetID: snippet.id,
                        fromPageID: currentPageID,
                        toPageID: pageID
                    )

                case .new:
                    let title = newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    _ = try await store.moveSnippetToNewPage(
                        snippetID: snippet.id,
                        fromPageID: currentPageID,
                        newPageTitle: title
                    )
                }

                await MainActor.run {
                    appState.reloadPages()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = String(describing: error)
                }
            }

            await MainActor.run {
                isMoving = false
            }
        }
    }
}

// MARK: - Page Row
private struct PageRow: View {
    let title: String
    let subtitle: String?
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

            // Title & subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(textSecondary)
                }
            }

            Spacer()

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
