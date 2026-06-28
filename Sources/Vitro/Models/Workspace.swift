import SwiftUI

/// Tracks which notes are open as tabs and which one is selected. The open set
/// and selection are remembered across launches via `UserDefaults`.
@MainActor
final class Workspace: ObservableObject {
    @Published var openNoteIDs: [UUID]
    @Published var selectedID: UUID?

    let store: NotesStore

    private static let openKey = "openTabs"
    private static let selectedKey = "selectedTab"

    init(store: NotesStore) {
        self.store = store

        let saved = (UserDefaults.standard.array(forKey: Self.openKey) as? [String])?
            .compactMap(UUID.init(uuidString:)) ?? []
        let valid = saved.filter { id in store.notes.contains { $0.id == id } }

        if valid.isEmpty {
            let first = store.notes.first ?? store.add()
            self.openNoteIDs = [first.id]
            self.selectedID = first.id
        } else {
            self.openNoteIDs = valid
            let savedSelection = UserDefaults.standard.string(forKey: Self.selectedKey)
                .flatMap(UUID.init(uuidString:))
            self.selectedID = valid.first { $0 == savedSelection } ?? valid.first
        }
    }

    var openTabs: [Note] {
        openNoteIDs.compactMap { store.note(id: $0) }
    }

    var selectedNote: Note? {
        selectedID.flatMap { store.note(id: $0) }
    }

    func newTab() {
        let note = store.add()
        openNoteIDs.append(note.id)
        selectedID = note.id
        persist()
    }

    func select(_ id: UUID) {
        selectedID = id
        persist()
    }

    func close(_ id: UUID) {
        guard let index = openNoteIDs.firstIndex(of: id) else { return }
        let wasSelected = selectedID == id
        openNoteIDs.remove(at: index)

        if openNoteIDs.isEmpty {
            persist()
            newTab()
            return
        }
        if wasSelected {
            selectedID = openNoteIDs[min(index, openNoteIDs.count - 1)]
        }
        persist()
    }

    func closeSelected() {
        if let selectedID { close(selectedID) }
    }

    func touch(_ note: Note) {
        note.modifiedAt = .now
        store.scheduleSave()
    }

    private func persist() {
        UserDefaults.standard.set(openNoteIDs.map(\.uuidString), forKey: Self.openKey)
        UserDefaults.standard.set(selectedID?.uuidString, forKey: Self.selectedKey)
    }
}
