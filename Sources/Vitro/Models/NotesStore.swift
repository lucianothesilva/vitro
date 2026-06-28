import AppKit

/// Owns every note and auto-persists them as JSON in Application Support.
/// Saving to an actual file is a separate, opt-in action (see Export); this
/// store is the always-on, file-free notebook the app edits day to day.
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note]

    private let fileURL: URL
    private var saveWork: DispatchWorkItem?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Vitro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("notes.json")
        self.fileURL = url

        let loaded = NotesStore.load(from: url)
        self.notes = loaded.isEmpty ? [Note.makeWelcome()] : loaded
        if loaded.isEmpty { save() }
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func add() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        save()
        return note
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// Debounced persistence — called on every edit without thrashing the disk.
    func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func save() {
        let dtos = notes.map { $0.toDTO() }
        guard let data = try? JSONEncoder().encode(dtos) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [Note] {
        guard let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([NoteDTO].self, from: data) else {
            return []
        }
        return dtos.map { Note(dto: $0) }
    }
}
