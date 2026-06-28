import SwiftUI
import AppKit

/// Reaches the hosting `NSWindow` and makes it translucent so the blurred
/// desktop shows behind the content (the base layer of the Liquid Glass look).
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            // Remove the hairline under the title bar so the whole window reads
            // as one continuous glass panel.
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            // Keep the traffic-light buttons but hide the title bar chrome.
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Frosted blur of whatever is behind the window. This is the vibrancy base;
/// Liquid Glass pills (header / tabs) float on top of it.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Material controls how translucent the panel is. From most solid to
        // most transparent: .underWindowBackground / .windowBackground →
        // .sidebar / .headerView → .menu / .popover → .hudWindow.
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
