import SwiftUI
import ApplicationServices
import NotesCore

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step: Int
    @State private var pollTimer: Timer?
    @State private var accessibilityGranted: Bool

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        let granted = AXIsProcessTrusted()
        _step = State(initialValue: OnboardingFlow.initialStep)
        _accessibilityGranted = State(initialValue: granted)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicators
            HStack(spacing: 6) {
                ForEach(0..<OnboardingFlow.totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.accent : Theme.border)
                        .frame(width: i == step ? 24 : 8, height: 4)
                        .animation(.easeInOut(duration: 0.25), value: step)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 32)

            // Content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: accessibilityStep
                case 2: servicesStep
                case 3: doneStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer(minLength: 0)

            // Navigation
            HStack {
                if OnboardingFlow.showBack(step: step) {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = max(0, step - 1) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Spacer()

                switch step {
                case 0:
                    Button("Get Started") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 1 }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding-next")
                case 1:
                    Button(OnboardingFlow.accessibilityNavLabel(granted: accessibilityGranted)) {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 2 }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(accessibilityGranted ? 1.0 : 0.6)
                    .accessibilityIdentifier("onboarding-next")
                case 2:
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 3 }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding-next")
                case 3:
                    Button("Start Using Tidbits") {
                        UserDefaults.standard.set(true, forKey: OnboardingFlow.completedKey)
                        onComplete()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding-next")
                default:
                    EmptyView()
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 36)
        .frame(width: 480, height: 400)
        .background(Theme.bg)
        .onDisappear { stopPolling() }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(Theme.accent)

            VStack(spacing: 10) {
                Text("Welcome to Tidbits")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Capture text from any app and organize it into pages.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            hotkeyBadge
                .padding(.top, 8)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 20) {
            Image(systemName: OnboardingFlow.accessibilityIcon(granted: accessibilityGranted))
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(accessibilityGranted ? Color.green : Theme.accent)

            VStack(spacing: 10) {
                Text(OnboardingFlow.accessibilityTitle(granted: accessibilityGranted))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text(OnboardingFlow.accessibilitySubtitle(granted: accessibilityGranted))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if !accessibilityGranted {
                Button(action: openAccessibilitySettings) {
                    Label("Open System Settings", systemImage: "gear")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)

                Text("Find **Tidbits** in the list and toggle it on.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            if !accessibilityGranted { startPolling() }
        }
        .onDisappear { stopPolling() }
    }

    private var servicesStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(Theme.accent)

            VStack(spacing: 10) {
                Text("Services Menu")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("You can also select text in any app and use\n**right-click \u{2192} Services \u{2192} Add to Tidbits**.\nThis works without any permissions.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Visual hint
            HStack(spacing: 8) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 12))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                Text("Right-click")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                Text("Services")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                Text("Add to Tidbits")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
            .padding(.top, 4)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(Theme.accent)

            VStack(spacing: 10) {
                Text("You\u{2019}re All Set")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("Capture text anytime with **\u{2318}\u{21E7}.** or the Services menu.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Menu bar callout
            HStack(spacing: 10) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Tidbits runs quietly in your menu bar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("No Dock icon \u{2014} click ")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    +
                    Text(Image(systemName: "note.text"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accent)
                    +
                    Text(" in the menu bar to view your tidbits.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
            .padding(.top, 4)
        }
    }

    // MARK: - Hotkey Badge

    private var hotkeyBadge: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingFlow.hotkeySymbols, id: \.self) { symbol in
                keyCap(systemName: symbol)
            }
            keyCap(text: OnboardingFlow.periodKeyText)
        }
    }

    private func keyCap(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
    }

    private func keyCap(text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
    }

    // MARK: - Accessibility Helpers

    private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Hide onboarding so it doesn't cover System Settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            OnboardingWindowPolicy.didRequestSystemSettings(ops: AppKitOnboardingWindowOps())
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    stopPolling()
                    OnboardingWindowPolicy.didGrantAccessibility(ops: AppKitOnboardingWindowOps())
                    withAnimation(.easeInOut(duration: 0.3)) {
                        accessibilityGranted = true
                    }
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

/// Bridges OnboardingWindowPolicy to real AppKit calls
private struct AppKitOnboardingWindowOps: OnboardingWindowOperations {
    private var onboardingWindow: NSWindow? {
        NSApp.windows.first { $0.collectionBehavior.contains(.canJoinAllSpaces) }
    }

    func hideWindow() {
        onboardingWindow?.orderOut(nil)
    }

    func showWindowAndActivate() {
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
