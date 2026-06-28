import AppKit

// View-hierarchy spelunking helpers. The native tab bar lives in private AppKit
// views (NSTabBar, NSTitlebarAccessoryClipView, NSToolbarView, …) that have no
// public API, so we reach them by class name. Ported from Ghostty's macOS app.

extension NSView {
    /// The absolute root of the view hierarchy (walks up the superview chain).
    var rootView: NSView {
        var root: NSView = self
        while let superview = root.superview { root = superview }
        return root
    }

    /// First descendant (depth-first) whose class name matches `name`.
    func firstDescendant(withClassName name: String) -> NSView? {
        for subview in subviews {
            if String(describing: type(of: subview)) == name { return subview }
            if let found = subview.firstDescendant(withClassName: name) { return found }
        }
        return nil
    }

    /// First ancestor whose class name matches `name`.
    func firstSuperview(withClassName name: String) -> NSView? {
        guard let superview else { return nil }
        if String(describing: type(of: superview)) == name { return superview }
        return superview.firstSuperview(withClassName: name)
    }

    /// Whether `self` or any descendant has the given class name.
    func contains(className name: String) -> Bool {
        if String(describing: type(of: self)) == name { return true }
        for subview in subviews where subview.contains(className: name) { return true }
        return false
    }
}

extension NSWindow {
    /// The private `NSTitlebarView`, reached via KVC on the theme frame.
    var titlebarView: NSView? {
        guard let themeFrame = contentView?.rootView else { return nil }
        guard themeFrame.responds(to: Selector(("titlebarView"))) else { return nil }
        return themeFrame.value(forKey: "titlebarView") as? NSView
    }

    /// The private `NSTabBar`, if the window currently shows one.
    var tabBarView: NSView? {
        titlebarView?.firstDescendant(withClassName: "NSTabBar")
    }

    /// The `NSTextField` that draws the centered window title, if present.
    var titlebarTextField: NSTextField? {
        titlebarView?.firstDescendant(withClassName: "NSTextField") as? NSTextField
    }
}

extension Array {
    /// Bounds-checked subscript.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
