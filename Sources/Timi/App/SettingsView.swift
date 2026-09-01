import SwiftUI
import KeyboardShortcuts
import UserNotifications
import TimiKit

/// Bumped from outside (session completes, hearts land) so an open Settings
/// window's stats stay live.
final class SettingsStatsTicker: ObservableObject {
    @Published var generation = 0
}

/// The one SwiftUI surface in the app (§2: AppKit everywhere else). Observes
/// the settings store directly, so changes made from the menu or the strip
/// show up here too, and controls never have to be rebuilt to refresh.
struct SettingsView: View {
    unowned let controller: PalController
    @ObservedObject var store: SettingsStore
    let sessions: SessionStore
    var onChanged: () -> Void
    @ObservedObject var ticker: SettingsStatsTicker

    @State private var confirmResetHearts = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private func binding<T>(_ get: @escaping () -> T,
                            _ set: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: get) { newValue in
            set(newValue)
            onChanged()
        }
    }

    var body: some View {
        let s = store.settings
        return Form {
            Section("Sound") {
                Toggle("Sound effects", isOn: binding({ !s.muted }, { controller.setSound(on: $0) }))
                HStack {
                    Text("Volume")
                    Slider(value: binding({ s.volume }, { controller.setVolume($0) }),
                           in: 0...1,
                           onEditingChanged: { editing in
                               if !editing { controller.sound.play(.blip) }  // hear the level
                           })
                        .disabled(s.muted)
                }
            }

            Section("Menu Bar") {
                Toggle("Show remaining time", isOn: binding({ s.showMenuBarClock },
                                                            { controller.setShowMenuBarClock($0) }))
            }

            Section("Interaction") {
                Picker("Respond to the mouse", selection: binding({ s.interactionMode },
                                                                  { controller.setInteractionMode($0) })) {
                    Text("When hovering Timi").tag(InteractionMode.hover)
                    Text("Only while holding ⌥").tag(InteractionMode.holdOption)
                    Text("Always (the area around Timi blocks clicks)").tag(InteractionMode.always)
                }
                KeyboardShortcuts.Recorder("Start / Pause hotkey", name: .togglePal)
            }

            Section("Appearance") {
                Toggle("Cabinet frame (CRT look)", isOn: binding({ s.cabinetFrame },
                                                                 { controller.setCabinet($0) }))
                Toggle("Outline (helps on light backgrounds)",
                       isOn: binding({ s.outlineOn }, { controller.setHighContrastOutline($0) }))
            }

            Section("Notifications") {
                Toggle("Notify when a session finishes",
                       isOn: binding({ s.notificationsEnabled },
                                     { controller.setNotificationsEnabled($0) }))
                if notificationStatus == .denied {
                    HStack {
                        Text("Notifications are turned off for Timi in System Settings.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            if LoginItem.available {
                Section("Login") {
                    Toggle("Launch at login", isOn: binding({ LoginItem.isEnabled },
                                                            { controller.setLaunchAtLogin($0) }))
                    if LoginItem.requiresApproval {
                        HStack {
                            Text("Waiting for your approval in System Settings › Login Items.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Login Items") { LoginItem.openSystemSettings() }
                        }
                    }
                }
            }

            Section("Hearts") {
                LabeledContent("Today", value: "\(sessions.heartsToday)")
                LabeledContent("All time", value: "\(sessions.lifetimeCompleted)")
                LabeledContent("Streak", value: "\(sessions.streakDays) day\(sessions.streakDays == 1 ? "" : "s")")
                Button("Reset hearts…", role: .destructive) {
                    confirmResetHearts = true
                }
                .confirmationDialog("Erase every recorded session and heart?",
                                    isPresented: $confirmResetHearts) {
                    Button("Erase all hearts", role: .destructive) {
                        sessions.resetAll()
                        controller.setHearts(0)
                        ticker.generation += 1
                        onChanged()
                    }
                }
            }

            Section("About") {
                LabeledContent("Timi",
                               value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                Text("A tiny pixel cat that lives on your desktop and keeps your focus timer. Timi was born as a web prototype; this is her native home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("Timi on GitHub", destination: URL(string: "https://github.com/2ls/timi")!)
                Text("© Two Ls LLC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .frame(minHeight: 560, maxHeight: 720)
        .onAppear {
            controller.notifier.authorizationStatus { notificationStatus = $0 }
        }
    }
}

/// Hosts the SwiftUI settings in a normal titled window; activates the app so a
/// LSUIElement process can show and focus it, and hands activation back to the
/// previous app when the window closes.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private unowned let controller: PalController
    private let sessions: SessionStore
    private let onChanged: () -> Void
    private let ticker = SettingsStatsTicker()
    private var previousApp: NSRunningApplication?

    init(controller: PalController, sessions: SessionStore, onChanged: @escaping () -> Void) {
        self.controller = controller
        self.sessions = sessions
        self.onChanged = onChanged
    }

    /// Re-render the stats section of an open window (session completed, etc.).
    func bumpStats() {
        ticker.generation += 1
    }

    func show() {
        if window == nil {
            let view = SettingsView(controller: controller, store: controller.settingsStore,
                                    sessions: sessions, onChanged: onChanged, ticker: ticker)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "Timi Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            w.delegate = self
            window = w
        }
        if window?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        PalController.returnFocus(to: previousApp)
        previousApp = nil
    }
}
