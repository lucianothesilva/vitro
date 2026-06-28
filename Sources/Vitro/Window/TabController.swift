import AppKit

/// Creates note windows and groups them as native tabs. Replaces the old
/// single-window `Workspace`: each open tab is now a real `NoteWindow` in one
/// tab group. The set of open notes is remembered across launches.
@MainActor
final class TabController {
    private let store: NotesStore
    private var controllers: [NoteWindowController] = []

    private static let openKey = "openTabs"
    private static let selectedKey = "selectedTab"

    init(store: NotesStore) {
        self.store = store
    }

    /// Open the notes that were tabs last launch (or a sensible default), all in
    /// one tab group, and focus the previously selected one.
    func restoreOnLaunch() {
        let savedIDs = (UserDefaults.standard.array(forKey: Self.openKey) as? [String])?
            .compactMap(UUID.init(uuidString:)) ?? []
        var notes = savedIDs.compactMap { store.note(id: $0) }
        if notes.isEmpty {
            notes = [store.notes.first ?? store.add()]
        }

        for note in notes { _ = open(note) }

        let selected = UserDefaults.standard.string(forKey: Self.selectedKey)
            .flatMap(UUID.init(uuidString:))
        let target = controllers.first { $0.note.id == selected } ?? controllers.first
        target?.window?.makeKeyAndOrderFront(nil)
        persist()
    }

    /// Create a brand-new note and open it as a tab next to `window`.
    func newTab(relativeTo window: NSWindow?) {
        let note = store.add()
        _ = open(note, tabbedTo: window ?? NSApp.keyWindow)
    }

    /// Export the note shown in the current key window.
    func exportKeyNote() {
        (NSApp.keyWindow?.windowController as? NoteWindowController)?.export()
    }

    @discardableResult
    private func open(_ note: Note, tabbedTo sibling: NSWindow? = nil) -> NoteWindowController {
        // Re-focus an already-open note rather than duplicating it.
        if let existing = controllers.first(where: { $0.note.id == note.id }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return existing
        }

        let controller = NoteWindowController(note: note, store: store, tabs: self)
        controllers.append(controller)

        let anchor = sibling ?? controllers.dropLast().last?.window
        if let anchor, let newWindow = controller.window {
            anchor.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        } else {
            controller.showWindow(nil)
        }
        persist()
        return controller
    }

    func controllerWillClose(_ controller: NoteWindowController) {
        controllers.removeAll { $0 === controller }
        persist()
    }

    private func persist() {
        let ids = controllers.map(\.note.id.uuidString)
        UserDefaults.standard.set(ids, forKey: Self.openKey)
        let selected = (NSApp.keyWindow?.windowController as? NoteWindowController)?.note.id
        UserDefaults.standard.set(selected?.uuidString, forKey: Self.selectedKey)
    }
}
