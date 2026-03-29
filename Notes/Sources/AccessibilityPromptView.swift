import SwiftUI
import ApplicationServices

struct AccessibilityPromptView: View {
    var onGranted: () -> Void

    @State private var pollTimer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Theme.textTertiary)

            VStack(spacing: 8) {
                Text("Enable Global Shortcut")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("Tidbits captures selected text with **⌘⇧.** (Command + Shift + Period).\nmacOS needs your permission to enable this.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: openAccessibilitySettings) {
                Text("Open System Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.95))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("Find **Tidbits** in the list and toggle it on.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)

            Spacer()
        }
        .padding(32)
        .frame(width: 400, height: 320)
        .background(Theme.bg)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private func openAccessibilitySettings() {
        // Trigger the system prompt and open settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    stopPolling()
                    onGranted()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
