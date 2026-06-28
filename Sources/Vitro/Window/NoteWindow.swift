import AppKit

/// One window per note, grouped with the system's native window tabs (shared
/// `tabbingIdentifier`). This is the "native" titlebar style: the window keeps a
/// normal centered title and macOS draws the tab bar in its standard place — a
/// full-width strip just below the titlebar. On macOS 26 (Tahoe) that native tab
/// bar gets the Liquid Glass treatment from the OS automatically.
@MainActor
final class NoteWindow: NSWindow {
    static let tabbingID = "VitroNote"

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = true
        // Transparent titlebar + full-size content + clear background lets the
        // content's behind-window blur show through the title/tab row, so the
        // whole window reads as one continuous glass panel.
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        // The tabs already show the note titles, so the titlebar title text
        // would be redundant — hide it (the window stays titled for tabbing).
        titleVisibility = .hidden

        // `.preferred` ensures restored windows come back as tabs rather than
        // separate windows; relax to `.automatic` afterwards (per Ghostty).
        tabbingIdentifier = Self.tabbingID
        tabbingMode = .preferred
        DispatchQueue.main.async { [weak self] in self?.tabbingMode = .automatic }
    }

    /// Makes the native "+" button appear and routes it to a fresh note tab.
    override func newWindowForTab(_ sender: Any?) {
        (NSApp.delegate as? AppController)?.tabs.newTab(relativeTo: self)
    }

    /// With `.fullSizeContentView` the content view extends under the titlebar
    /// and swallows clicks there, so macOS never sees the double-click that
    /// normally zooms/minimizes a window. Catch it here, before the event is
    /// routed to a view, when it lands in the titlebar strip (above the content
    /// layout rect) and run the user's configured title-bar double-click action.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseUp, event.clickCount == 2,
           event.locationInWindow.y > contentLayoutRect.maxY {
            performTitlebarDoubleClickAction()
            return
        }
        super.sendEvent(event)
    }

    private func performTitlebarDoubleClickAction() {
        // Honour System Settings → Desktop & Dock → "Double-click a window's
        // title bar to". Defaults to zoom (the "expand" the user expects).
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize": performMiniaturize(nil)
        case "None": break
        default: zoom(nil)
        }
    }
}
