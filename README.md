# Vitro

A minimal, native macOS note editor. Rich text with interactive checklists,
organized as native window tabs, wrapped in Liquid Glass.

## Features

- **Rich-text notes** with inline, clickable checkboxes.
- **Native macOS window tabs** — each note is a real tabbed window (`⌘1`, `⌘2`, …,
  drag to reorder, `+` to add). On macOS 26 (Tahoe) the tab bar and titlebar get the
  system's Liquid Glass treatment; editor content floats on a frosted vibrancy base.
- **Titles derive from your text** — the first non-empty line names the note, Apple
  Notes style. No title field to manage.
- **Always-on, file-free storage.** Notes are auto-saved as JSON; you only touch the
  filesystem when you **Export** a note to Markdown.
- **One typeface, Inter**, throughout the app.

## Requirements

- **macOS 26 (Tahoe) or later** — the Liquid Glass and native-tab behavior depend on
  the Tahoe SDK.
- Xcode 26+ / Swift 6.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to regenerate
  the Xcode project from `project.yml`.
- The [Inter](https://rsms.me/inter/) font installed (the app falls back to the system
  font if it isn't).

## Build & run

```sh
# Build, install to /Applications, and launch:
sh scripts/run-local.sh
```

For a quick compile check during development:

```sh
swift build
```

If you add, remove, or rename a source file, regenerate the Xcode project first:

```sh
xcodegen generate
```

> The build is **ad-hoc signed** for local use — it runs on your Mac but is not
> notarized for distribution. Shipping to other machines needs a Developer ID
> certificate.

## Keyboard shortcuts

| Shortcut        | Action            |
| --------------- | ----------------- |
| `⌘T`            | New tab           |
| `⌘W`            | Close tab         |
| `⌘S`            | Export to Markdown|
| `⌘⇧L`           | Insert checklist  |
| `⌘+` / `⌘-`     | Increase / decrease font size |
| `⌘0`            | Reset font size   |

## Project layout

- `Sources/Vitro/Window/` — AppKit window/tab layer (`NoteWindow`, `NoteWindowController`,
  `TabController`).
- `Sources/Vitro/Editor/` — the `NSTextView`-based rich-text editor, checkboxes, and
  line-number gutter.
- `Sources/Vitro/Models/` — `Note` and the `NotesStore` that persists them.
- `main.swift` / `VitroApp.swift` — pure-AppKit entry point and menu.

See [CLAUDE.md](CLAUDE.md) for the architecture in depth.
