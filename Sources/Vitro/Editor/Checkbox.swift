import AppKit

/// A checkbox is a single `NSTextAttachment` character carrying a custom
/// `key` attribute that records its checked state. Because it lives inside the
/// `NSAttributedString`, it survives archiving (persistence) and round-trips
/// cleanly; toggling just swaps the attachment image and the bool attribute.
enum Checkbox {
    static let key = NSAttributedString.Key("VitroCheckbox")

    static func image(checked: Bool) -> NSImage {
        let name = checked ? "checkmark.circle.fill" : "circle"
        // Palette color forces white (and makes the symbol non-template, so it
        // ignores the text color).
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        let base = NSImage(systemSymbolName: name,
                           accessibilityDescription: checked ? "Checked" : "Unchecked")
        return base?.withSymbolConfiguration(config) ?? NSImage()
    }

    /// A one-character attributed string representing a checkbox.
    @MainActor static func attachmentString(checked: Bool) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image(checked: checked)
        attachment.bounds = CGRect(x: 0, y: -2, width: 16, height: 16)

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(
            [key: NSNumber(value: checked), .font: Note.bodyFont],
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}

/// Converts an attributed note (with checkbox attachments) into Markdown so it
/// can be exported as a real `.md`/`.txt` file on demand.
enum Markdown {
    static func string(from attr: NSAttributedString) -> String {
        var out = ""
        var inCode = false
        let ns = attr.string as NSString
        let full = NSRange(location: 0, length: attr.length)
        attr.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            let nowCode = attrs[CodeBlock.key] != nil
            if nowCode && !inCode { out += "```\n"; inCode = true }
            if !nowCode && inCode { out += "\n```\n"; inCode = false }

            if let checked = attrs[Checkbox.key] as? NSNumber {
                out += checked.boolValue ? "- [x] " : "- [ ] "
            } else {
                out += ns.substring(with: range)
            }
        }
        if inCode { out += "\n```\n" }
        return out
    }
}
