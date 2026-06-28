import AppKit

/// A code block is a run of text carrying a custom `key` attribute, rendered in
/// a monospaced font on a rounded dark card. Like the checkbox attribute it
/// lives inside the `NSAttributedString`, so it survives archiving and toggling
/// is just an attribute change. The attribute only *marks* which characters
/// belong; the card itself is drawn by `CodeBlockLayoutManager`.
enum CodeBlock {
    static let key = NSAttributedString.Key("VitroCodeBlock")

    // MARK: - Visuals

    /// Dark navy card, close to the screenshot's `#212130`.
    static let backgroundColor = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.17, alpha: 1)
    static let textColor = NSColor(white: 0.92, alpha: 1)
    static let cornerRadius: CGFloat = 8
    /// Inset from the card edges to the code text.
    static let horizontalPadding: CGFloat = 14
    /// How far the card is inset from each line's box, leaving a small gap to the
    /// surrounding text. Kept small so the card hugs the code.
    static let externalGap: CGFloat = 3

    /// Monospaced font tracking the editor's current size, so ⌘+/- zooms code too.
    @MainActor static func font(ofSize size: CGFloat = Note.bodyFontSize) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Code lines use the same horizontal inset and **no** extra paragraph
    /// spacing: each code line is its own paragraph, so any before/after spacing
    /// would bloat the gap between every row. The card's breathing room comes
    /// from the line box itself, not paragraph spacing — this also makes typing
    /// new lines inside a block "just work" (they inherit the same flat style).
    static func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = horizontalPadding
        style.headIndent = horizontalPadding
        style.tailIndent = -horizontalPadding
        return style
    }

    /// The full attribute set that turns a run into code.
    @MainActor static func attributes(ofSize size: CGFloat = Note.bodyFontSize)
        -> [NSAttributedString.Key: Any] {
        [.font: font(ofSize: size),
         .foregroundColor: textColor,
         .paragraphStyle: paragraphStyle(),
         key: NSNumber(value: true)]
    }
}

/// Draws the rounded dark card behind any run marked with `CodeBlock.key`,
/// before the glyphs (and the selection highlight) are drawn on top.
final class CodeBlockLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        if let textStorage, let container = textContainers.first {
            let shownChars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
            let nsString = textStorage.string as NSString
            let full = NSRange(location: 0, length: textStorage.length)
            textStorage.enumerateAttribute(CodeBlock.key, in: full, options: []) { value, runRange, _ in
                guard value != nil,
                      NSIntersectionRange(runRange, shownChars).length > 0 else { return }

                // Drop a trailing newline: it lays out a zero-width fragment at
                // the start of the *next* line and would add a sliver above/below
                // the card. The newline sits on the same fragment as its line, so
                // the box is unchanged otherwise.
                var charRange = runRange
                while charRange.length > 0,
                      nsString.character(at: charRange.location + charRange.length - 1) == 10 {
                    charRange.length -= 1
                }
                guard charRange.length > 0 else { return }

                // Union the actual line-fragment rects (whole run, even if only
                // partly visible) so the rounded corners are always complete.
                let glyphRange = self.glyphRange(forCharacterRange: charRange,
                                                 actualCharacterRange: nil)
                var box = CGRect.null
                enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, _, _ in
                    box = box.union(rect)
                }
                guard !box.isNull else { return }

                let pad = container.lineFragmentPadding
                box.origin.x = pad
                box.size.width = container.size.width - 2 * pad
                box = box.insetBy(dx: 0, dy: CodeBlock.externalGap)
                box = box.offsetBy(dx: origin.x, dy: origin.y)
                box = box.integral   // snap to whole pixels to avoid seams

                let path = NSBezierPath(roundedRect: box,
                                        xRadius: CodeBlock.cornerRadius,
                                        yRadius: CodeBlock.cornerRadius)
                CodeBlock.backgroundColor.setFill()
                path.fill()
            }
        }
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    }
}
