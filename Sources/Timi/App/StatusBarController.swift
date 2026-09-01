import AppKit
import KeyboardShortcuts
import TimiKit

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
        menu.autoenablesItems = false  // manual isEnabled control below
        menu.delegate = self
        statusItem.menu = menu
        refresh()
    }

    /// The 1 Hz title timer exists only while a clock is actually displayed
    /// (running/paused + setting on); .common mode keeps it updating while the
    /// menu is open, and the tolerance lets the system coalesce wakeups.
    private func updateClockTimer() {
        let mode = controller.timer.mode
        let wanted = settingsStore.settings.showMenuBarClock &&
            (mode == .running || mode == .paused)
        if wanted && clockTimer == nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.refreshTitle()
            }
            t.tolerance = 0.2
            RunLoop.main.add(t, forMode: .common)
            clockTimer = t
        } else if !wanted, let t = clockTimer {
            t.invalidate()
            clockTimer = nil
        }
    }

    // MARK: - Icon + title

    func refresh() {
        refreshIcon()
        refreshTitle()
        updateClockTimer()
    }

    private func refreshIcon() {
        let running = controller.timer.mode == .running || controller.timer.mode == .paused
        let key = "timi-\(running)"
        if iconCache[key] == nil {
            iconCache[key] = Self.makeIcon(tinted: running,
                                           primary: controller.engine.config.palette.primary)
        }
        statusItem.button?.image = iconCache[key]
        statusItem.button?.imagePosition = .imageLeading
        // Dimmed while Timi is hidden — the only visible cue that she's gone.
        statusItem.button?.appearsDisabled = !settingsStore.settings.palVisible
        statusItem.button?.setAccessibilityLabel("Timi")
        statusItem.button?.setAccessibilityValue(controller.palView.axValue)
    }

    @objc private func showTips() {
        if !settingsStore.settings.palVisible { controller.setPalVisible(true) }
        controller.showFirstRunHint()
    }

    private func refreshTitle() {
        guard let button = statusItem.button else { return }
        let mode = controller.timer.mode
        if settingsStore.settings.showMenuBarClock, mode == .running || mode == .paused {
            let rem = controller.timer.remainingMs(now: Date())
            button.title = (mode == .paused ? " ⏸ " : " ") + formatMillis(rem)
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        } else {
            button.title = ""
        }
    }

    /// Timi's portrait: 13×12-ish sprite drawn into an 18 pt canvas.
    static func makeIcon(tinted: Bool, primary: RGBA) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let color: CGColor = tinted
                ? CGColor(srgbRed: CGFloat(primary.r) / 255, green: CGFloat(primary.g) / 255,
                          blue: CGFloat(primary.b) / 255, alpha: 1)
                : CGColor(gray: 0, alpha: 1)
            ctx.setFillColor(color)
            let body = Sprites.STAND
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
            // ears
            px(1, -1); px(2, -1); px(1, -2)
            px(11, -1); px(10, -1); px(11, -2)
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
        let start = NSMenuItem(title: primaryTitle, action: #selector(tapAction), keyEquivalent: "")
        // Mirrors the recorded hotkey, whatever it is (menus are built on the main thread).
        MainActor.assumeIsolated { start.setShortcut(for: .togglePal) }
        start.target = self
        menu.addItem(start)

        let reset = NSMenuItem(title: "Reset", action: #selector(resetAction), keyEquivalent: "")
        reset.target = self
        // In .done the primary item already reads "Reset" — don't offer two.
        reset.isEnabled = mode == .running || mode == .paused
        menu.addItem(reset)

        menu.addItem(.separator())

        for preset in DurationPreset.all {
            let item = NSMenuItem(title: preset.menuTitle, action: #selector(pickPreset(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = preset.ms
            item.state = controller.timer.durationMs == preset.ms ? .on : .off
            item.isEnabled = mode == .idle
            menu.addItem(item)
        }
        let custom = NSMenuItem(title: "Custom…", action: #selector(customDuration), keyEquivalent: "")
        custom.target = self
        custom.isEnabled = mode == .idle
        menu.addItem(custom)

        menu.addItem(.separator())

        let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = settingsStore.settings.muted ? .off : .on
        menu.addItem(soundItem)

        let visible = settingsStore.settings.palVisible
        let showHide = NSMenuItem(title: visible ? "Hide Timi" : "Show Timi",
                                  action: #selector(togglePal), keyEquivalent: "")
        showHide.target = self
        menu.addItem(showHide)

        let cabinet = NSMenuItem(title: "Cabinet Frame (CRT Look)", action: #selector(toggleCabinet), keyEquivalent: "")
        cabinet.target = self
        cabinet.state = settingsStore.settings.cabinetFrame ? .on : .off
        menu.addItem(cabinet)

        if Bundle.main.bundleIdentifier != nil {
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
            login.target = self
            login.state = LoginItem.isEnabled ? .on : .off  // the system's truth, not a stored flag
            menu.addItem(login)
        }

        let tips = NSMenuItem(title: "Show Tips", action: #selector(showTips), keyEquivalent: "")
        tips.target = self
        tips.isEnabled = mode == .idle  // the tips teach idle gestures (tap to start…)
        menu.addItem(tips)

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

        let quit = NSMenuItem(title: "Quit Timi", action: #selector(NSApplication.terminate(_:)),
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
        controller.promptCustomDuration()
    }

    @objc private func toggleSound() {
        controller.toggleMute()
        refresh()
    }

    @objc private func togglePal() {
        controller.setPalVisible(!settingsStore.settings.palVisible)
        refresh()
    }

    @objc private func toggleCabinet() {
        controller.setCabinet(!settingsStore.settings.cabinetFrame)
    }

    @objc private func toggleLogin() {
        // Toggle from the system's actual state, not the stored flag — they can
        // disagree after edits in System Settings or a requires-approval limbo.
        controller.setLaunchAtLogin(!LoginItem.isEnabled)
    }

    @objc private func showSettings() {
        openSettings?()
    }
}
