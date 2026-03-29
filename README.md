# Tidbits (macOS)

Local-only macOS app for saving selected text into simple "pages" (collections of snippets).

## Project layout

- `project.yml`: xcodegen spec (source of truth)
- `Tidbits.xcodeproj`: generated (do not hand-edit; re-generate)
- `Notes/`: app sources + plist + entitlements
- `NotesCore/`: Swift package (models, storage, tests)
- `Makefile`: build/install/update commands

## Quick start (Makefile)

From this folder:

```bash
make update   # build, install to /Applications, and run
```

Other commands:

| Command              | Description                                              |
|----------------------|----------------------------------------------------------|
| `make build`         | Build release (signed if `Signing.xcconfig` exists)      |
| `make build-unsigned`| Build without signing (for contributors)                 |
| `make update`        | Kill → build → install → run (full update cycle)         |
| `make dev`           | Kill → build → run from build dir (faster, no install)   |
| `make install`       | Kill → build → copy to /Applications                     |
| `make run`           | Launch from /Applications                                |
| `make generate`      | Regenerate Xcode project from project.yml                |
| `make test`          | Run NotesCore unit tests                                 |
| `make clean`         | Remove build artifacts and .xcodeproj                    |
| `make kill`          | Kill running Tidbits app                                 |

## Build/run via Xcode (development)

```bash
make generate
open Tidbits.xcodeproj
```

Then in Xcode: select scheme **Tidbits** → Run (⌘R).

## Storage

JSON persisted via `NotesCore.NotesStore` into Application Support under `TidbitsLocal`.

## Text capture

Two capture methods:

### Global hotkey (⌘⇧.)

Select text anywhere, press **Command + Shift + Period**. Requires Accessibility permission (prompted on first launch).

**How it works**: Simulates `Cmd+C` via CGEvent, waits 150ms, reads the pasteboard. Uses `CGEventSource(stateID: .privateState)` to create an isolated keyboard state — without this, physically-held modifier keys (Shift, Command) leak into the simulated keypress and terminal emulators like Ghostty see `⌘⇧C` instead of `⌘C`.

**Key repeat protection**: The hotkey handler ignores `event.isARepeat` and checks panel visibility before triggering. Without these guards, holding the hotkey fires a second capture attempt — by then the panel is focused, the simulated `Cmd+C` goes to the panel (nothing to copy), and the panel gets replaced with empty text. See `HotkeyPolicy` in NotesCore for the testable logic.

**Cancel button uses Escape only**: The panel's Cancel button uses `.keyboardShortcut(.escape, modifiers: [])` instead of `.cancelAction`. On macOS, `.cancelAction` maps to both Escape and `⌘.` (Command+Period), which conflicts with the `⌘⇧.` hotkey when Shift is released slightly before the other keys.

### Services (right-click)

Select text → right click → **Services** → **Add to Tidbits**. Works everywhere including Ghostty. No permissions needed.

**Pasteboard reading order**: RTF → HTML → plain text. Ghostty puts selected text on the pasteboard as RTF, not plain text. `PasteboardTextExtractor` tries RTF first and converts bold/italic to markdown.

## Tests

222 tests across 14 files in `NotesCore/Tests/`:

```bash
make test   # or: cd NotesCore && swift test
```
