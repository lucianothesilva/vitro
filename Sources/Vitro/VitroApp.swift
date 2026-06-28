import AppKit

/// App entry point. This is a pure-AppKit app (see `main.swift`) so we can own
/// the `NSWindow` subclass needed to hoist the native tab bar into the titlebar.
/// Notes are persisted by `NotesStore`; open tabs are real windows managed by
/// `TabController`.
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    let store = NotesStore()
    lazy var tabs = TabController(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched as a bare SPM executable: promote to a regular, active app so
        // its windows can become key (you can type).
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        tabs.restoreOnLaunch()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Actions

    @objc func newTab(_ sender: Any?) { tabs.newTab(relativeTo: NSApp.keyWindow) }
    @objc func exportNote(_ sender: Any?) { tabs.exportKeyNote() }
    @objc func insertChecklist(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroInsertCheckbox, object: nil)
    }
    @objc func toggleBold(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroToggleBold, object: nil)
    }
    @objc func toggleCodeBlock(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroToggleCodeBlock, object: nil)
    }
    @objc func increaseFont(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroAdjustFont, object: "increase")
    }
    @objc func decreaseFont(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroAdjustFont, object: "decrease")
    }
    @objc func resetFont(_ sender: Any?) {
        NotificationCenter.default.post(name: .vitroAdjustFont, object: "reset")
    }

    // MARK: Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Vitro",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Vitro",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                        action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Vitro",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, to: mainMenu)

        // File
        let fileMenu = NSMenu(title: "File")
        let newTab = fileMenu.addItem(withTitle: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        newTab.target = self
        fileMenu.addItem(withTitle: "Close Tab", action: Selector(("performClose:")), keyEquivalent: "w")
        fileMenu.addItem(.separator())
        let export = fileMenu.addItem(withTitle: "Export…", action: #selector(exportNote(_:)), keyEquivalent: "s")
        export.target = self
        addSubmenu(fileMenu, to: mainMenu)

        // Edit (selectors route to the first responder — the text view)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        editMenu.addItem(.separator())

        // Find submenu — items route through the responder chain to the text
        // view's NSTextFinder. The tag selects the NSTextFinder.Action.
        let findMenu = NSMenu(title: "Find")
        addFinderItem(to: findMenu, title: "Find…", key: "f", action: .showFindInterface)
        addFinderItem(to: findMenu, title: "Find and Replace…", key: "f",
                      modifiers: [.command, .option], action: .showReplaceInterface)
        addFinderItem(to: findMenu, title: "Find Next", key: "g", action: .nextMatch)
        addFinderItem(to: findMenu, title: "Find Previous", key: "g",
                      modifiers: [.command, .shift], action: .previousMatch)
        addFinderItem(to: findMenu, title: "Use Selection for Find", key: "e",
                      action: .setSearchString)
        let findItem = editMenu.addItem(withTitle: "Find", action: nil, keyEquivalent: "")
        findItem.submenu = findMenu

        addSubmenu(editMenu, to: mainMenu)

        // Format
        let formatMenu = NSMenu(title: "Format")
        let bold = formatMenu.addItem(withTitle: "Bold",
                        action: #selector(toggleBold(_:)), keyEquivalent: "b")
        bold.target = self
        let code = formatMenu.addItem(withTitle: "Code Block",
                        action: #selector(toggleCodeBlock(_:)), keyEquivalent: "c")
        code.keyEquivalentModifierMask = [.command, .shift]
        code.target = self
        let checklist = formatMenu.addItem(withTitle: "Insert Checklist",
                        action: #selector(insertChecklist(_:)), keyEquivalent: "l")
        checklist.keyEquivalentModifierMask = [.command, .shift]
        checklist.target = self
        formatMenu.addItem(.separator())
        let inc = formatMenu.addItem(withTitle: "Increase Font Size",
                        action: #selector(increaseFont(_:)), keyEquivalent: "+")
        inc.target = self
        let dec = formatMenu.addItem(withTitle: "Decrease Font Size",
                        action: #selector(decreaseFont(_:)), keyEquivalent: "-")
        dec.target = self
        let reset = formatMenu.addItem(withTitle: "Reset Font Size",
                        action: #selector(resetFont(_:)), keyEquivalent: "0")
        reset.target = self
        addSubmenu(formatMenu, to: mainMenu)

        // Window (AppKit auto-fills the window list + native tab commands)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: Selector(("performMiniaturize:")), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: Selector(("performZoom:")), keyEquivalent: "")
        addSubmenu(windowMenu, to: mainMenu)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func addSubmenu(_ submenu: NSMenu, to mainMenu: NSMenu) {
        let item = NSMenuItem()
        item.submenu = submenu
        mainMenu.addItem(item)
    }

    /// A find-bar menu item. No target: `performTextFinderAction:` travels the
    /// responder chain to the focused text view, which validates it. The item's
    /// tag carries the `NSTextFinder.Action`.
    @discardableResult
    private func addFinderItem(to menu: NSMenu, title: String, key: String,
                              modifiers: NSEvent.ModifierFlags = .command,
                              action: NSTextFinder.Action) -> NSMenuItem {
        let item = menu.addItem(withTitle: title,
                                action: Selector(("performTextFinderAction:")),
                                keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.tag = action.rawValue
        return item
    }
}
