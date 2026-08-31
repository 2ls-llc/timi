import AppKit
import SwiftUI
import TimiKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var controller: PalController!
    private var sessions: SessionStore!
    private var statusBar: StatusBarController!
    private var hotkey: HotkeyManager!
    private var settingsWindow: SettingsWindowController!
    private var debugHarness: DebugHarness?
    private var observers: [NSObjectProtocol] = []
    private var currentSessionIndex: Int?
    private var midnightTimer: Timer?
    private var screenLocked = false
    private var displaysAsleep = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = SettingsStore()
        sessions = SessionStore()
        controller = PalController(settingsStore: settingsStore)
        controller.sound = ChipSynth()
        controller.setHearts(sessions.heartsToday)

        statusBar = StatusBarController(controller: controller, sessions: sessions,
                                        settingsStore: settingsStore)
        settingsWindow = SettingsWindowController(controller: controller, sessions: sessions) {
            [weak self] in self?.statusBar.refresh()
        }
        statusBar.openSettings = { [weak self] in self?.settingsWindow.show() }

        hotkey = HotkeyManager { [weak self] in
            guard let self else { return }
            self.controller.engine.noteInteraction(tMs: CACurrentMediaTime() * 1000)
            self.controller.tapAction()
            self.statusBar.refresh()
        }

        controller.onSessionStarted = { [weak self] in
            guard let self else { return }
            self.currentSessionIndex = self.sessions.beginSession(
                durationMs: self.controller.timer.durationMs,
                character: self.controller.engine.config.id)
            self.statusBar.refresh()
        }
        controller.onSessionCompleted = { [weak self] in
            guard let self else { return }
            if let index = self.currentSessionIndex {
                self.sessions.completeSession(at: index)
                self.currentSessionIndex = nil
            }
            self.statusBar.refresh()
            self.settingsWindow.bumpStats()
        }
        controller.onModeChanged = { [weak self] in self?.statusBar.refresh() }
        controller.onHeartLanded = { [weak self] in
            self?.statusBar.refresh()
            self?.settingsWindow.bumpStats()
        }
        sessions.onReset = { [weak self] in
            // "Reset hearts…" mid-session: the in-flight record is gone; don't
            // let its finish write through a stale index.
            self?.currentSessionIndex = nil
        }

        controller.startRunning()
        debugHarness = DebugHarness(controller: controller)

        installSystemObservers()
        scheduleMidnightRefresh()
    }

    private func installSystemObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.controller.systemDidWake()
            self.controller.setHearts(self.sessions.heartsToday)
            self.statusBar.refresh()
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.displaysAsleep = true
            self?.updatePauseState()
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.displaysAsleep = false
            self?.updatePauseState()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.controller.screensChanged()
        })
        // Screen lock — distributed notifications, per §10.
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.screenLocked = true
            self?.updatePauseState()
        })
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.screenLocked = false
            self?.updatePauseState()
        })
    }

    /// Frame loop pauses when the panel is hidden, the screen is locked, or the
    /// displays sleep; the timer itself keeps exact wall-clock time regardless.
    private func updatePauseState() {
        let paused = screenLocked || displaysAsleep || !controller.settings.palVisible
        controller.setPaused(paused)
    }

    /// The hearts row shows *today's* sessions — refresh it at local midnight.
    private func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(after: Date(),
                                                   matching: DateComponents(hour: 0, minute: 0, second: 5),
                                                   matchingPolicy: .nextTime) else { return }
        midnightTimer = Timer(fire: nextMidnight, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.controller.setHearts(self.sessions.heartsToday)
            self.statusBar.refresh()
            self.scheduleMidnightRefresh()
        }
        RunLoop.main.add(midnightTimer!, forMode: .common)
    }

    /// Headless smoke test: build and lay out the settings form without showing
    /// a window or stealing focus (the debug harness runs on a live machine).
    func showSettingsForDebug() {
        let view = SettingsView(controller: controller, sessions: sessions,
                                onChanged: {}, ticker: SettingsStatsTicker())
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 420, height: 560)
        hosting.view.layoutSubtreeIfNeeded()
        NSLog("Settings view smoke test OK: \(hosting.view.fittingSize)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        controller.setPaused(true)
    }
}
