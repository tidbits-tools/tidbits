# Tidbits

Local-only native macOS app for saving text snippets via global hotkey and Services menu. No network, no sync, no auth.

## Project Layout

- `project.yml`: xcodegen spec (source of truth)
- `Tidbits.xcodeproj`: generated (do not hand-edit; run `make generate`)
- `Notes/`: SwiftUI app sources + plist
- `NotesCore/`: Swift package (models, storage, tests)
- `Makefile`: build/install/update/release commands

## Build

```bash
make build           # Build release (Developer ID signed if Signing.xcconfig exists, ad-hoc otherwise)
make build-unsigned  # Build with explicit ad-hoc signing (for contributors)
make test            # Run 222 unit tests
make dev             # Kill → build → run from build dir
make update          # Kill → build → install → run
make install         # Copy to /Applications
make generate        # Regenerate Xcode project from project.yml
make clean           # Remove build artifacts and .xcodeproj
make kill            # Kill running Tidbits app
```

### Build via Xcode

```bash
make generate
open Tidbits.xcodeproj
```

Select scheme **Tidbits** → Run (⌘R).

### Signing (for distribution)

Copy `Signing.xcconfig.example` to `Signing.xcconfig` and fill in your Developer ID credentials. `Signing.xcconfig` is gitignored — xcodebuild reads it directly via `-xcconfig`. Without it, `make build` falls back to ad-hoc signing.

Release pipeline (maintainer only): `make release` → build → notarize app → staple app → create DMG → sign/notarize/staple DMG.

### CI

CI workflows use `macos-15` runners (Xcode 16). xcodegen on Xcode 16 generates project format 77 which is incompatible with Xcode 15. Do not downgrade runners to `macos-14`.

- `ci.yml`: Runs tests + unsigned build on push to main and PRs
- `release.yml`: Triggered by `v*` tags. Tests gate the release job. Uses GitHub secrets for signing (API key auth for notarization, not keychain-profile).

**Certificate import**: The `security import` call must use `-f pkcs12` without `-t cert`. The `-t cert` flag treats a `.p12` as certificate-only and silently discards the private key, causing `set-key-partition-list` to fail. Match Apple's `import-codesign-certs` action flags: `-A -T /usr/bin/codesign -T /usr/bin/security -f pkcs12`.

## Schema

`NotesCore/Sources/NotesCore/NotesDatabase.swift` is the source of truth for data types. Edit directly — there is no code generation.

- IDs are `String` (UUID format), not native `UUID`
- Dates use custom ISO8601 decoder with fractional seconds support
- Use `newJSONDecoder()` / `newJSONEncoder()` for all serialization

## Architecture

| Directory | Purpose |
|-----------|---------|
| `Notes/Sources/` | SwiftUI app (views, hotkey manager, floating panel) |
| `NotesCore/Sources/` | Testable core logic (store, database types, text parsing, formatting) |
| `NotesCore/Tests/` | 222 tests across 14 test files |

Data is stored at `~/Library/Application Support/TidbitsLocal/` with per-page JSON files:
- `index.json` — lightweight page metadata (id, title, slug, dates, snippet count)
- `pages/{slug}.json` — full page content with snippets

All files have 0o600 permissions.

## Key Behaviors

**Global hotkey (⌘⇧.)**: Simulates Cmd+C via CGEvent, waits 150ms for the pasteboard to update, then reads it (RTF → HTML → plain text priority). Opens floating panel for page selection. Requires Accessibility permission.

Uses `CGEventSource(stateID: .privateState)` to create an isolated keyboard state — without this, physically-held modifier keys (Shift, Command) leak into the simulated keypress and terminal emulators like Ghostty see `⌘⇧C` instead of `⌘C`.

**Key repeat protection**: `HotkeyPolicy` rejects `event.isARepeat` and checks panel visibility before triggering.

**Cancel button**: Uses `.keyboardShortcut(.escape, modifiers: [])` not `.cancelAction` — the latter maps to `⌘.` which conflicts with the `⌘⇧.` hotkey.

**Services menu**: Select text → right click → Services → Add to Tidbits. No permissions needed.

**Pasteboard reading order**: RTF → HTML → plain text. Ghostty puts selected text on the pasteboard as RTF, not plain text. `PasteboardTextExtractor` tries RTF first and converts bold/italic to markdown.

## Development Gotchas

### TCC / Accessibility Permission Invalidation

**Every rebuild changes the app binary signature**, which invalidates the macOS TCC (Transparency, Consent, and Control) database entry for Accessibility permission. Symptoms:
- `AXIsProcessTrusted()` returns `false` even though Tidbits appears toggled on in System Settings
- Global hotkey stops working
- Onboarding shows "not granted" even after previously granting

**Fix**: System Settings → Privacy & Security → Accessibility → remove Tidbits → re-add it. This will keep happening on every rebuild until the app has proper code signing via Apple Developer Program.

### UserDefaults / Stale Sandbox Container

The app previously had App Sandbox enabled. A stale container at `~/Library/Containers/tools.tidbits/` may exist. When present, `defaults delete tools.tidbits` targets the container plist (empty) instead of the real one at `~/Library/Preferences/tools.tidbits.plist`.

**Fix**: Remove the stale container: `rm -rf ~/Library/Containers/tools.tidbits`. After that, `defaults delete` works correctly. If issues persist, also `killall -u $(whoami) cfprefsd` to flush the in-memory cache.

### Onboarding skipped after Accessibility reset

If you remove Tidbits from Accessibility preferences and relaunch, the app skips the full onboarding (welcome → accessibility → services → done) and shows only the accessibility prompt. This is because `hasCompletedOnboarding` persists in UserDefaults independently of TCC state.

**Fix**: `defaults delete tools.tidbits hasCompletedOnboarding` then relaunch.

### Sandbox vs swift test

`swift test` may fail with `sandbox_apply: Operation not permitted`. Run with sandbox disabled or use `make test`.

## Tests

222 tests across 14 files in `NotesCore/Tests/`:

| File | Coverage |
|------|----------|
| `ClaudePromptTests` | Copy-path prompt generation, file path correctness |
| `EditingPolicyTests` | Snippet editing state, tap handling, background tap, page change |
| `HotkeyPolicyTests` | Key repeat guard, panel visibility guard |
| `MenuBarClickPolicyTests` | Menu bar click routing based on active window state |
| `NotesCoreTests` | NotesStore CRUD, error paths, sort order, timestamps, persistence, integration |
| `NotesDatabaseTests` | JSON round-trip, date decoding, optional fields |
| `OnboardingFlowTests` | Initial step, back button visibility, hotkey symbols |
| `OnboardingWindowPolicyTests` | Window hide/show sequence during System Settings interaction |
| `PanelShowPolicyTests` | Panel show activation sequence |
| `PasteboardExtractorTests` | Extraction priority (RTF > HTML > plain), size limits, Ghostty regression |
| `SlugTests` | Slug generation, collision resolution, special characters |
| `TextFormatterTests` | Curly quote replacement, capitalization rules, formatSnippets |
| `TextParserTests` | RTF/HTML parsing, entity decoding, whitespace cleanup |
| `WindowClosePolicyTests` | Full-screen exit before hide |
