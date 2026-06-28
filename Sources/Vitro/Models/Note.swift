import AppKit

/// A single note. The body is rich text (`NSAttributedString`) so it can hold
/// interactive checkboxes. The header title is derived from the first non-empty
/// line, the way Apple Notes does it.
@MainActor
final class Note: Identifiable, ObservableObject {
    let id: UUID
    @Published var body: NSAttributedString
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(),
         body: NSAttributedString = Note.emptyBody(),
         createdAt: Date = .now,
         modifiedAt: Date = .now) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    var title: String {
        for raw in body.string.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return String(line.prefix(60)) }
        }
        return "New Note"
    }

    var wordCount: Int {
        body.string
            .split { $0 == " " || $0 == "\n" || $0 == "\t" }
            .count
    }

    // MARK: - Styling

    static let defaultFontSize: CGFloat = 22
    private static let fontSizeKey = "editorFontSize"

    /// Editor text size, persisted across launches. Clamped to a sane range.
    @MainActor static var bodyFontSize: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: fontSizeKey)
            return stored > 0 ? stored : defaultFontSize
        }
        set {
            UserDefaults.standard.set(min(48, max(10, newValue)), forKey: fontSizeKey)
        }
    }

    @MainActor static var bodyFont: NSFont {
        interFont(ofSize: bodyFontSize)
    }

    /// Inter at a given size/weight, falling back to the system font if Inter
    /// isn't installed. Used everywhere so the whole app shares one typeface.
    static func interFont(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name: String
        switch weight {
        case .medium: name = "Inter-Medium"
        case .semibold: name = "Inter-SemiBold"
        case .bold: name = "Inter-Bold"
        default: name = "Inter"
        }
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    @MainActor static func defaultAttributes() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.textColor]
    }

    static func emptyBody() -> NSAttributedString {
        NSAttributedString(string: "", attributes: defaultAttributes())
    }

    static func makeWelcome() -> Note {
        let s = NSMutableAttributedString(
            string: "Welcome to Vitro\n\nA simple note editor. Try a checklist:\n",
            attributes: defaultAttributes()
        )
        s.append(Checkbox.attachmentString(checked: false))
        s.append(NSAttributedString(string: " write something", attributes: defaultAttributes()))
        s.append(NSAttributedString(string: "\n", attributes: defaultAttributes()))
        s.append(Checkbox.attachmentString(checked: true))
        s.append(NSAttributedString(string: " open a new tab with ⌘T", attributes: defaultAttributes()))
        return Note(body: s)
    }
}

// MARK: - Persistence

/// JSON-friendly representation. The attributed body is keyed-archived to `Data`
/// so attachments, fonts and the checkbox attribute all survive a relaunch.
struct NoteDTO: Codable {
    let id: UUID
    let bodyData: Data
    let createdAt: Date
    let modifiedAt: Date
}

extension Note {
    func toDTO() -> NoteDTO {
        let data = (try? NSKeyedArchiver.archivedData(withRootObject: body,
                                                      requiringSecureCoding: false)) ?? Data()
        return NoteDTO(id: id, bodyData: data, createdAt: createdAt, modifiedAt: modifiedAt)
    }

    convenience init(dto: NoteDTO) {
        var restored: NSAttributedString?
        if let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: dto.bodyData) {
            unarchiver.requiresSecureCoding = false
            restored = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
        }
        self.init(id: dto.id,
                  body: restored ?? Note.emptyBody(),
                  createdAt: dto.createdAt,
                  modifiedAt: dto.modifiedAt)
    }
}
