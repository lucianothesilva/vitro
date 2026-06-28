import AppKit

// Pure-AppKit entry point. `NSApplication.delegate` is a weak reference, so the
// controller is held here as a top-level (program-lifetime) binding.
let application = NSApplication.shared
let controller = AppController()
application.delegate = controller
application.run()
