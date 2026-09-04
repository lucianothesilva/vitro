import SwiftUI
import AppKit

extension Notification.Name {
    static let vitroInsertCheckbox = Notification.Name("vitroInsertCheckbox")
    static let vitroExport = Notification.Name("vitroExport")
    /// Object is "increase" | "decrease" | "reset".
    static let vitroAdjustFont = Notification.Name("vitroAdjustFont")
    static let vitroToggleBold = Notification.Name("vitroToggleBold")
    static let vitroToggleCodeBlock = Notification.Name("vitroToggleCodeBlock")
}

/// SwiftUI wrapper around an `NSTextView` we fully control. We own persistence,
/// so the note lives in memory/app-storage and only becomes a file on Export.
struct RichTextEditor: NSViewRepresentable {
    @ObservedObject var note: Note
    var onChange: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        // The text always wraps to the container width, so there is nothing to
        // reach sideways. Without this the trackpad rubber-bands the document
        // horizontally and drags the text over the line-number gutter.
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none

        let contentSize = scroll.contentSize
        let textView = CheckboxTextView(frame: NSRect(origin: .zero, size: contentSize))
        // Swap in the layout manager that paints code-block cards. Touching the
        // text container forces TextKit 1, which this app already relies on
        // (the ruler and checkbox hit-testing use the layout manager directly).
        textView.textContainer?.replaceLayoutManager(CodeBlockLayoutManager())
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        // Native find/replace: NSTextView owns its NSTextFinder and renders the
        // standard find bar inside the scroll view. Menu items drive it via
        // `performTextFinderAction:` (see AppController's Find submenu).
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .textColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 2, height: 24)
        textView.font = Note.bodyFont
        textView.typingAttributes = Note.defaultAttributes()

        let bigDimension = CGFloat.greatestFiniteMagnitude
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: bigDimension, height: bigDimension)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width,
                                                       height: bigDimension)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(note.body)
        // Render at the current global font size regardless of what was stored.
        textView.applyBodyFont(persist: false)

        scroll.documentView = textView

        // Line-number gutter on the left.
        let ruler = LineNumberRulerView(textView: textView)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.ruler = ruler

        // Redraw the gutter as the view scrolls.
        scroll.contentView.postsBoundsChangedNotifications = true
        let scrollToken = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView, queue: .main
        ) { [weak ruler] _ in ruler?.needsDisplay = true }
        context.coordinator.observers.append(scrollToken)

        // Re-flow (wrap) the text to the available width whenever the window /
        // clip view is resized.
        scroll.contentView.postsFrameChangedNotifications = true
        let resizeToken = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scroll.contentView, queue: .main
        ) { [weak textView, weak scroll, weak ruler] _ in
            guard let textView, let scroll else { return }
            let width = scroll.contentView.bounds.width
            textView.frame.size.width = width
            textView.textContainer?.containerSize = NSSize(width: width, height: bigDimension)
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            ruler?.needsDisplay = true
        }
        context.coordinator.observers.append(resizeToken)

        return scroll
    }

    // Tab switches recreate this view via `.id(note.id)`, so the body is loaded
    // fresh in `makeNSView` and there is nothing to reconcile here.
    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: RichTextEditor
        weak var ruler: LineNumberRulerView?
        var observers: [NSObjectProtocol] = []

        init(_ parent: RichTextEditor) { self.parent = parent }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.note.body = textView.attributedString()
            parent.onChange()
            ruler?.needsDisplay = true
        }
    }
}

/// `NSTextView` that knows about checkboxes: clicking one toggles it, and it can
/// insert a checklist item on command.
final class CheckboxTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: .vitroInsertCheckbox, object: nil)
        NotificationCenter.default.removeObserver(self, name: .vitroAdjustFont, object: nil)
        NotificationCenter.default.removeObserver(self, name: .vitroToggleBold, object: nil)
        NotificationCenter.default.removeObserver(self, name: .vitroToggleCodeBlock, object: nil)
        if window != nil {
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleInsertCheckbox),
                name: .vitroInsertCheckbox, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleAdjustFont(_:)),
                name: .vitroAdjustFont, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleToggleBold),
                name: .vitroToggleBold, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleToggleCodeBlock),
                name: .vitroToggleCodeBlock, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Paste as plain text using the app's own style, so copying from a chat /
    /// web page doesn't drag in the source's background, text color or font.
    override func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: string) else { return }
        // Pasting inside a code block keeps the block's styling (so you can drop
        // a snippet straight in); elsewhere it lands as plain app-styled text.
        let inCode = typingAttributes[CodeBlock.key] != nil
        let attrs = inCode ? CodeBlock.attributes() : Note.defaultAttributes()
        textStorage?.replaceCharacters(
            in: range,
            with: NSAttributedString(string: string, attributes: attrs))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (string as NSString).length, length: 0))
        typingAttributes = attrs
    }

    @objc private func handleInsertCheckbox() {
        guard window?.firstResponder === self else { return }
        insertChecklistItem()
    }

    @objc private func handleToggleBold() {
        guard window?.firstResponder === self else { return }
        toggleBold()
    }

    @objc private func handleToggleCodeBlock() {
        guard window?.firstResponder === self else { return }
        toggleCodeBlock()
    }

    /// Turn the selected whole lines into a code block, or revert them to body
    /// text if they already are one. Code blocks are line-based, so the
    /// selection is expanded to full paragraphs first.
    func toggleCodeBlock() {
        guard let textStorage else { return }
        let nsString = textStorage.string as NSString
        let range = nsString.lineRange(for: selectedRange())

        // Already code only if *every* character in range is marked.
        var isCode: Bool
        if range.length > 0 {
            isCode = true
            textStorage.enumerateAttribute(CodeBlock.key, in: range, options: []) { value, _, stop in
                if value == nil { isCode = false; stop.pointee = true }
            }
        } else {
            isCode = typingAttributes[CodeBlock.key] != nil
        }

        guard shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage.beginEditing()
        if isCode {
            textStorage.removeAttribute(CodeBlock.key, range: range)
            textStorage.removeAttribute(.paragraphStyle, range: range)
            textStorage.addAttribute(.font, value: Note.bodyFont, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            typingAttributes = Note.defaultAttributes()
        } else {
            textStorage.addAttributes(CodeBlock.attributes(), range: range)
            typingAttributes = CodeBlock.attributes()
        }
        textStorage.endEditing()
        didChangeText()
        layoutManager?.invalidateDisplay(forCharacterRange: range)
    }

    /// Return inside a code block normally adds another code line. But pressing
    /// Return on a *blank* line leaves the block: that line (and everything you
    /// type next) reverts to body text — the standard "double-Enter to exit".
    override func insertNewline(_ sender: Any?) {
        guard typingAttributes[CodeBlock.key] != nil, let textStorage else {
            super.insertNewline(sender)
            return
        }
        let nsString = textStorage.string as NSString
        let line = nsString.lineRange(for: NSRange(location: selectedRange().location, length: 0))
        let blank = nsString.substring(with: line)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n")).isEmpty
        // Only a blank line at the *end* of the block exits. A blank line with
        // more code below it is just an empty row inside the block.
        let after = NSMaxRange(line)
        let codeBelow = after < textStorage.length
            && textStorage.attribute(CodeBlock.key, at: after, effectiveRange: nil) != nil
        guard blank && !codeBelow else {
            super.insertNewline(sender)   // extend the block with a new code line
            return
        }

        // Leave the block: strip code styling from this blank line and reset the
        // typing attributes so further input is plain body text.
        guard shouldChangeText(in: line, replacementString: nil) else { return }
        textStorage.beginEditing()
        if line.length > 0 {
            textStorage.removeAttribute(CodeBlock.key, range: line)
            textStorage.removeAttribute(.paragraphStyle, range: line)
            textStorage.addAttribute(.font, value: Note.bodyFont, range: line)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: line)
        }
        textStorage.endEditing()
        typingAttributes = Note.defaultAttributes()
        didChangeText()
        layoutManager?.invalidateDisplay(forCharacterRange: line)
    }

    private func isBold(_ font: NSFont?) -> Bool {
        guard let font else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.bold)
            || font.fontName.lowercased().contains("bold")
    }

    /// Toggle Inter-Bold over the selection (or the typing attributes when the
    /// selection is empty), preserving each run's point size.
    func toggleBold() {
        guard let textStorage else { return }
        let range = selectedRange()

        if range.length == 0 {
            let nowBold = isBold(typingAttributes[.font] as? NSFont)
            typingAttributes[.font] = Note.interFont(ofSize: Note.bodyFontSize,
                                                     weight: nowBold ? .regular : .bold)
            return
        }

        guard shouldChangeText(in: range, replacementString: nil) else { return }

        // If the whole selection is already bold, unbold; otherwise bold all.
        var allBold = true
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            if !isBold(value as? NSFont) { allBold = false; stop.pointee = true }
        }
        let targetWeight: NSFont.Weight = allBold ? .regular : .bold

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let size = (value as? NSFont)?.pointSize ?? Note.bodyFontSize
            textStorage.addAttribute(.font,
                                     value: Note.interFont(ofSize: size, weight: targetWeight),
                                     range: subrange)
        }
        textStorage.endEditing()
        didChangeText()
    }

    @objc private func handleAdjustFont(_ notification: Notification) {
        switch notification.object as? String {
        case "increase": Note.bodyFontSize += 2
        case "decrease": Note.bodyFontSize -= 2
        case "reset": Note.bodyFontSize = Note.defaultFontSize
        default: break
        }
        applyBodyFont(persist: true)
    }

    /// Re-apply the current global font (size) to every run of text. Single-font
    /// app, so this is just a size/family normalization that also re-wraps.
    func applyBodyFont(persist: Bool) {
        guard let textStorage else { return }
        let size = Note.bodyFontSize
        let full = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            // Re-apply at the new size but keep bold runs bold.
            let weight: NSFont.Weight = isBold(value as? NSFont) ? .bold : .regular
            textStorage.addAttribute(.font, value: Note.interFont(ofSize: size, weight: weight), range: range)
        }
        // Code-block runs stay monospaced — re-apply at the new size after the
        // pass above has reset everything to Inter.
        textStorage.enumerateAttribute(CodeBlock.key, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            textStorage.addAttribute(.font, value: CodeBlock.font(ofSize: size), range: range)
        }
        textStorage.endEditing()
        typingAttributes = Note.defaultAttributes()
        if persist { didChangeText() }
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let layoutManager, let textContainer, let textStorage else {
            super.mouseDown(with: event); return
        }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerInset.width
        point.y -= textContainerInset.height

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer,
                                                  fractionOfDistanceThroughGlyph: &fraction)
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.contains(point) else { super.mouseDown(with: event); return }

        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        if charIndex >= 0, charIndex < textStorage.length,
           let checked = textStorage.attribute(Checkbox.key, at: charIndex,
                                               effectiveRange: nil) as? NSNumber {
            toggle(at: charIndex, checked: checked.boolValue)
            return
        }
        super.mouseDown(with: event)
    }

    private func toggle(at index: Int, checked: Bool) {
        guard let textStorage else { return }
        let range = NSRange(location: index, length: 1)
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage.replaceCharacters(in: range,
                                      with: Checkbox.attachmentString(checked: !checked))
        didChangeText()
    }

    func insertChecklistItem() {
        guard let textStorage else { return }
        let nsString = textStorage.string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: selectedRange().location, length: 0))

        let item = NSMutableAttributedString()
        item.append(Checkbox.attachmentString(checked: false))
        item.append(NSAttributedString(string: " ", attributes: Note.defaultAttributes()))

        let insertRange = NSRange(location: lineRange.location, length: 0)
        guard shouldChangeText(in: insertRange, replacementString: nil) else { return }
        textStorage.insert(item, at: lineRange.location)
        didChangeText()
        setSelectedRange(NSRange(location: lineRange.location + item.length, length: 0))
        typingAttributes = Note.defaultAttributes()
    }
}
