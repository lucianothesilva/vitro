import AppKit

/// A left gutter that numbers each logical line of the text view, like a code
/// editor. Drawn transparently so it blends into the glass panel.
final class LineNumberRulerView: NSRulerView {
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 28
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Skip the default opaque background fill — let the panel show through.
    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let content = textView.string as NSString
        let inset = textView.textContainerInset
        let relativePoint = convert(NSPoint.zero, from: textView)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Note.interFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect,
                                                         in: container)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange,
                                                            actualGlyphRange: nil)
        let endIndex = NSMaxRange(visibleCharRange)

        var lineNumber = firstLineNumber(upTo: visibleCharRange.location, in: content)
        var charIndex = visibleCharRange.location

        while charIndex < endIndex && charIndex < content.length {
            let lineRange = content.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange,
                                                      actualCharacterRange: nil)
            var effective = NSRange()
            let fragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location, effectiveRange: &effective,
                withoutAdditionalLayout: true)

            let y = fragmentRect.minY + relativePoint.y + inset.height
            draw(number: lineNumber, atY: y, lineHeight: fragmentRect.height, attributes: attributes)

            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next <= charIndex { break }
            charIndex = next
        }

        // Number the trailing empty line (empty doc, or text ending in newline).
        if content.length == 0 ||
            content.character(at: content.length - 1) == unichar(10) {
            let extra = layoutManager.extraLineFragmentRect
            if extra.height > 0 {
                let y = extra.minY + relativePoint.y + inset.height
                draw(number: lineNumber, atY: y, lineHeight: extra.height, attributes: attributes)
            }
        }
    }

    private func draw(number: Int, atY y: CGFloat, lineHeight: CGFloat,
                      attributes: [NSAttributedString.Key: Any]) {
        let text = "\(number)" as NSString
        let size = text.size(withAttributes: attributes)
        let x = ruleThickness - size.width - 6
        let drawY = y + (lineHeight - size.height) / 2
        text.draw(at: NSPoint(x: x, y: drawY), withAttributes: attributes)
    }

    private func firstLineNumber(upTo index: Int, in content: NSString) -> Int {
        var line = 1
        var i = 0
        while i < index {
            if content.character(at: i) == unichar(10) { line += 1 }
            i += 1
        }
        return line
    }
}
