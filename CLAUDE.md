# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Vitro is a macOS note editor: rich text with interactive checkboxes, persisted as
JSON (Markdown only on explicit Export). Notes open as **native macOS window tabs**.

**Requires macOS 26 (Tahoe) and Swift 6.** The deployment target and Liquid Glass /
native-tab behavior depend on the Tahoe SDK — it will not build for earlier macOS.

## Build / run

- `swift build` — fast compile check (SPM). Use this to catch errors quickly.
- `sh scripts/run-local.sh` — the real workflow: builds **Release** via `xcodebuild`,
  replaces `/Applications/Vitro.app`, and launches it. Use this to see changes in the
  actual app (ad-hoc signed, not notarized).
- **`xcodegen generate` after adding/removing/renaming any source file.** The Xcode
  project is generated from `project.yml` and its file list is otherwise stale —
  `swift build` will pass while `xcodebuild` (and thus `run-local.sh`) fails with
  "cannot find X in scope". There are no tests.

## Architecture

This is a **pure-AppKit app** (not SwiftUI lifecycle). The entry point is top-level
code in `main.swift`, which creates the `AppController` (NSApplicationDelegate). The
reason for full AppKit is window control: each note is its own `NSWindow` subclass so
we can drive native tabbing and titlebar styling that SwiftUI doesn't expose.

**Window/tab layer** (`Sources/Vitro/Window/`):
- `NoteWindow` — `NSWindow` subclass, one per note. Native window tabbing via a shared
  `tabbingIdentifier` (`.preferred` → `.automatic`); tabs render in the system's
  default position below a transparent, full-size-content titlebar (Ghostty's "native"
  titlebar style — title text is hidden since the tabs carry titles). The native "+"
  button works because it overrides `newWindowForTab(_:)`.
- `NoteWindowController` — owns one `NoteWindow` + `Note`, hosts the editor via
  `NSHostingView(EditorContent)`, and keeps `window.title` / `window.tab.attributedTitle`
  in sync with the note's derived title (and dims inactive tabs on key/resign).
- `TabController` — creates and groups windows (`addTabbedWindow`), handles new/close,
  and persists the open-tab set. Owned by `AppController`; reached from `NoteWindow`
  via `NSApp.delegate as? AppController`.
- `AppKitSupport` — view-hierarchy helpers (`firstDescendant(withClassName:)`,
  `titlebarView`, etc.) for reaching private AppKit views by class name.

**Editor** (`Sources/Vitro/Editor/`): `RichTextEditor` wraps a custom `NSTextView`
(`CheckboxTextView`). Tab switches recreate the whole view (`.id(note.id)` upstream),
so `makeNSView` loads fresh and `updateNSView` is a no-op. Editor commands (insert
checklist, font size) are delivered as `NotificationCenter` broadcasts
(`.vitroInsertCheckbox`, `.vitroAdjustFont`) that `CheckboxTextView` observes —
`AppController`'s menu actions post these. `Checkbox` also defines the `Markdown` export
enum. `LineNumberRulerView` is the gutter.

**Models** (`Sources/Vitro/Models/`): `Note` is an `ObservableObject`; its `title` is
*derived* from the first non-empty body line (Apple Notes style) — there is no stored
title. `NotesStore` owns all notes and debounce-saves them as `notes.json` in
Application Support. Export to a `.md` file is separate and opt-in.

## Conventions / gotchas

- **One typeface: Inter.** Use `Note.interFont(ofSize:weight:)` for any font (falls back
  to the system font if Inter isn't installed). Don't hardcode `NSFont.systemFont`.
- **Liquid Glass:** glass is the OS-drawn native chrome (tabs/titlebar on Tahoe) plus the
  `VisualEffectBackground` (`.behindWindow` blur) behind editor content. Per Apple's
  guidance, do **not** put glass behind the editor text itself — glass is for the
  control/navigation layer, not content.
- **Persistence keys** (`UserDefaults`): `openTabs` / `selectedTab` (open tabs) and
  `editorFontSize`. Note bodies live in `notes.json`, not UserDefaults.
- **Legacy/unused** from the pre-native-tabs design, kept only to avoid an unrequested
  delete: `Views/RootView.swift`, `Models/Workspace.swift`, and the `WindowConfigurator`
  representable in `Window/WindowConfigurator.swift` (its `VisualEffectBackground` *is*
  still used). Safe to remove.
