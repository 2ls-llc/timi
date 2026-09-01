import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement in the bundled app; for `swift run` builds this keeps us out of
// the Dock and Cmd-Tab too.
app.setActivationPolicy(.accessory)

// A minimal main menu: an accessory app has no visible menu bar, but key
// equivalents (⌘, ⌘W ⌘Q, and ⌘V in the custom-duration field) still route
// through it — without one they're dead in the Settings window.
let mainMenu = NSMenu()

let appMenuItem = NSMenuItem()
let appMenu = NSMenu()
appMenu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings),
                keyEquivalent: ",")
appMenu.addItem(.separator())
appMenu.addItem(withTitle: "Quit Timi", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q")
appMenuItem.submenu = appMenu
mainMenu.addItem(appMenuItem)

let editMenuItem = NSMenuItem()
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
editMenu.addItem(.separator())
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),
                 keyEquivalent: "a")
editMenuItem.submenu = editMenu
mainMenu.addItem(editMenuItem)

let windowMenuItem = NSMenuItem()
let windowMenu = NSMenu(title: "Window")
windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)),
                   keyEquivalent: "w")
windowMenuItem.submenu = windowMenu
mainMenu.addItem(windowMenuItem)

app.mainMenu = mainMenu
app.run()
