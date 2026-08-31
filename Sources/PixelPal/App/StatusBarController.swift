import AppKit
import PixelPalKit

/// Menu-bar presence: a pixel portrait of the active character (template when
/// idle, tinted while running), optional remaining-time text, and the app menu.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private unowned let controller: PalController
    private let sessions: SessionStore
    private let settingsStore: SettingsStore
    var openSettings: (() -> Void)?

    private var clockTimer: Timer?
    private var iconCache: [String: NSImage] = [:]

    init(controller: PalController, sessions: SessionStore, settingsStore: SettingsStore) {
        self.controller = controller
        self.sessions = sessions
        self.settingsStore = settingsStore
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refresh()

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshTitle()
        }
    }

    // MARK: - Icon + title

    func refresh() {
        refreshIcon()
        refreshTitle()
    }

    private func refreshIcon() {
        let running = controller.timer.mode == .running || controller.timer.mode == .paused
        let id = controller.engine.config.id
        let key = "\(id.rawValue)-\(running)"
        if iconCache[key] == nil {
            iconCache[key] = Self.makeIcon(for: id, tinted: running,
                                           primary: controller.engine.config.palette.primary)
        }
        statusItem.button?.image = iconCache[key]
        statusItem.button?.imagePosition = .imageLeading
    }

    private func refreshTitle() {
        guard let button = statusItem.button else { return }
        let mode = controller.timer.mode
        if settingsStore.settings.showMenuBarClock, mode == .running || mode == .paused {
            let rem = controller.timer.remainingMs(now: Date())
            button.title = " " + formatMillis(rem)
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        } else {
            button.title = ""
        }
    }

    /// 13×12-ish sprite drawn 2 px per cell into a 36×36 (18 pt @2x) canvas.
    static func makeIcon(for id: CharacterID, tinted: Bool, primary: RGBA) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let color: CGColor = tinted
                ? CGColor(srgbRed: CGFloat(primary.r) / 255, green: CGFloat(primary.g) / 255,
                          blue: CGFloat(primary.b) / 255, alpha: 1)
                : CGColor(gray: 0, alpha: 1)
            ctx.setFillColor(color)
            let body = id == .pip ? Sprites.PIP_BODY : Sprites.MOCHI_STAND
            let feet = Sprites.FEET_A
            let cell: CGFloat = 1.25
            let originX = (rect.width - 13 * cell) / 2
            let originY = (rect.height - CGFloat(body.count + 3) * cell) / 2
            func px(_ x: Int, _ y: Int) {
                ctx.fill(CGRect(x: originX + CGFloat(x) * cell,
                                y: originY + CGFloat(y + 2) * cell,
                                width: cell, height: cell))
            }
            for (r, row) in body.enumerated() {
                for (c, ch) in row.utf8.enumerated() where ch == UInt8(ascii: "#") {
                    px(c, r)
                }
            }
            for (c, ch) in feet.utf8.enumerated() where ch == UInt8(ascii: "#") {
                px(c, body.count)
            }
            if id == .pip {
                px(6, -1)  // ahoge
            } else {
                px(1, -1); px(2, -1); px(1, -2)      // ears
                px(11, -1); px(10, -1); px(11, -2)
            }
            // punch out the eyes
            ctx.setBlendMode(.clear)
            let eyeRow = 3
            px(3, eyeRow); px(3, eyeRow + 1)
            px(9, eyeRow); px(9, eyeRow + 1)
            return true
        }
        image.isTemplate = !tinted
        return image
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let mode = controller.timer.mode

        let primaryTitle: String
        switch mode {
        case .idle: primaryTitle = "Start"
        case .running: primaryTitle = "Pause"
        case .paused: primaryTitle = "Resume"
        case .done: primaryTitle = "Reset"
        }
        let start = NSMenuItem(title: primaryTitle, action: #selector(tapAction), keyEquivalent: " ")
        start.keyEquivalentModifierMask = [.control, .option]
        start.target = self
        menu.addItem(start)

        let reset = NSMenuItem(title: "Reset", action: #selector(resetAction), keyEquivalent: "")
        reset.target = self
        reset.isEnabled = mode != .idle
        menu.addItem(reset)

        menu.addItem(.separator())

        for (label, ms) in [("30 seconds", 30_000.0), ("5 minutes", 300_000.0),
                            ("15 minutes", 900_000.0), ("25 minutes", 1_500_000.0)] {
            let item = NSMenuItem(title: label, action: #selector(pickPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ms
            item.state = controller.timer.durationMs == ms ? .on : .off
            item.isEnabled = mode == .idle
            menu.addItem(item)
        }
        let custom = NSMenuItem(title: "Custom…", action: #selector(customDuration), keyEquivalent: "")
        custom.target = self
        custom.isEnabled = mode == .idle
        menu.addItem(custom)

        menu.addItem(.separator())

        let characterMenu = NSMenu()
        for id in CharacterID.allCases {
            let item = NSMenuItem(title: CharacterConfig.config(for: id).name,
                                  action: #selector(pickCharacter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id.rawValue
            item.state = controller.engine.config.id == id ? .on : .off
            characterMenu.addItem(item)
        }
        let characterItem = NSMenuItem(title: "Character", action: nil, keyEquivalent: "")
        characterItem.submenu = characterMenu
        menu.addItem(characterItem)

        let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = settingsStore.settings.muted ? .off : .on
        menu.addItem(soundItem)

        let visible = settingsStore.settings.palVisible
        let showHide = NSMenuItem(title: visible ? "Hide Pal" : "Show Pal",
                                  action: #selector(togglePal), keyEquivalent: "")
        showHide.target = self
        menu.addItem(showHide)

        let cabinet = NSMenuItem(title: "Cabinet Frame", action: #selector(toggleCabinet), keyEquivalent: "")
        cabinet.target = self
        cabinet.state = settingsStore.settings.cabinetFrame ? .on : .off
        menu.addItem(cabinet)

        if Bundle.main.bundleIdentifier != nil {
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
            login.target = self
            login.state = settingsStore.settings.launchAtLogin ? .on : .off
            menu.addItem(login)
        }

        menu.addItem(.separator())

        let hearts = sessions.heartsToday
        let lifetime = sessions.lifetimeCompleted
        let streak = sessions.streakDays
        let heartLine = NSMenuItem(
            title: "♥ \(hearts) today · \(lifetime) all time" +
                (streak > 1 ? " · \(streak)-day streak" : ""),
            action: nil, keyEquivalent: "")
        heartLine.isEnabled = false
        menu.addItem(heartLine)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Pixel Pal", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func tapAction() {
        controller.tapAction()
        refresh()
    }

    @objc private func resetAction() {
        controller.resetAction()
        refresh()
    }

    @objc private func pickPreset(_ sender: NSMenuItem) {
        guard let ms = sender.representedObject as? Double else { return }
        controller.pickDuration(ms: ms)
    }

    @objc private func customDuration() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Custom Duration"
        alert.informativeText = "Focus session length in minutes (1–90)."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 90, height: 24))
        field.placeholderString = "25"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn,
              let minutes = Double(field.stringValue.trimmingCharacters(in: .whitespaces)),
              minutes > 0 else { return }
        controller.pickDuration(ms: clamp(minutes, 1, 90) * 60_000)
    }

    @objc private func pickCharacter(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = CharacterID(rawValue: raw) else { return }
        controller.switchCharacter(to: id)
        refresh()
    }

    @objc private func toggleSound() {
        controller.toggleMute()
        refresh()
    }

    @objc private func togglePal() {
        controller.setPalVisible(!settingsStore.settings.palVisible)
    }

    @objc private func toggleCabinet() {
        controller.setCabinet(!settingsStore.settings.cabinetFrame)
    }

    @objc private func toggleLogin() {
        controller.setLaunchAtLogin(!settingsStore.settings.launchAtLogin)
    }

    @objc private func showSettings() {
        openSettings?()
    }
}
