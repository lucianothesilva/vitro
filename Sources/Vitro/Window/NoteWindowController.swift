import AppKit
import SwiftUI

/// Owns one `NoteWindow` and binds it to a single `Note`: hosts the editor and
/// keeps the window title (and therefore the native tab label) in sync with the
/// note's derived title.
@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let note: Note
    private let store: NotesStore
    private weak var tabs: TabController?

    init(note: Note, store: NotesStore, tabs: TabController) {
        self.note = note
        self.store = store
        self.tabs = tabs

        let window = NoteWindow()
        super.init(window: window)
        window.delegate = self

        // Every edit (including checkbox toggles) flows through this onChange,
        // so it's also where we refresh the title that drives the tab label.
        let content = EditorContent(note: note) { [weak self] in
            guard let self else { return }
            self.note.modifiedAt = .now
            self.store.scheduleSave()
            self.refreshTitle()
        }
        window.contentView = NSHostingView(rootView: content)
        refreshTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Keep the window title and the native tab label in sync with the note and
    /// in Inter. The tab color tracks key state so inactive tabs still dim like
    /// native ones. (The centered titlebar title is hidden — see `NoteWindow`.)
    private func refreshTitle() {
        guard let window else { return }
        window.title = note.title

        let active = window.isKeyWindow
        window.tab.attributedTitle = NSAttributedString(string: note.title, attributes: [
            .font: Note.interFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: active ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshTitle() }
    func windowDidResignKey(_ notification: Notification) { refreshTitle() }

    func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = note.title + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Markdown.string(from: note.body).write(to: url, atomically: true, encoding: .utf8)
    }

    func windowWillClose(_ notification: Notification) {
        tabs?.controllerWillClose(self)
    }
}
