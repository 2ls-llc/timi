import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement in the bundled app; for `swift run` builds this keeps us out of
// the Dock and Cmd-Tab too.
app.setActivationPolicy(.accessory)
app.run()
