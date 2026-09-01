import SwiftUI
import KeyboardShortcuts
import TimiKit

/// Bumped from outside (session completes, hearts land) so an open Settings
/// window's stats stay live.
final class SettingsStatsTicker: ObservableObject {
    @Published var generation = 0
}

/// The one SwiftUI surface in the app (§2: AppKit everywhere else).
struct SettingsView: View {
    unowned let controller: PalController
    let sessions: SessionStore
    var onChanged: () -> Void
    @ObservedObject var ticker: SettingsStatsTicker

    @State private var revision = 0
    @State private var confirmResetHearts = false

    private func binding<T>(_ get: @escaping () -> T,
                            _ set: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: get) { newValue in
            set(newValue)
            revision += 1
            onChanged()
        }
    }

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Sound effects", isOn: binding({ !controller.settings.muted },
                                                      { controller.setSound(on: $0) }))
                HStack {
                    Text("Volume")
                    Slider(value: binding({ controller.settings.volume },
                                          { controller.setVolume($0) }), in: 0...1)
                        .disabled(controller.settings.muted)
                }
            }

            Section("Menu Bar") {
                Toggle("Show remaining time", isOn: binding({ controller.settings.showMenuBarClock },
                                                            { controller.setShowMenuBarClock($0) }))
            }

            Section("Interaction") {
                Picker("Respond to the mouse", selection: binding({ controller.settings.interactionMode },
                                                                  { controller.setInteractionMode($0) })) {
                    Text("When hovering the pal").tag(InteractionMode.hover)
                    Text("Only while holding ⌥").tag(InteractionMode.holdOption)
                    Text("Always").tag(InteractionMode.always)
                }
                KeyboardShortcuts.Recorder("Start / Pause hotkey", name: .togglePal)
            }

            Section("Appearance") {
                Toggle("Cabinet frame (CRT look)", isOn: binding({ controller.settings.cabinetFrame },
                                                                 { controller.setCabinet($0) }))
                Toggle("Outline (helps on light backgrounds)",
                       isOn: binding({ controller.settings.outlineOn },
                                     { controller.setHighContrastOutline($0) }))
            }

            Section("Notifications") {
                Toggle("Notify when a session finishes",
                       isOn: binding({ controller.settings.notificationsEnabled },
                                     { controller.setNotificationsEnabled($0) }))
            }

            if Bundle.main.bundleIdentifier != nil {
                Section("Login") {
                    Toggle("Launch at login", isOn: binding({ controller.settings.launchAtLogin },
                                                            { controller.setLaunchAtLogin($0) }))
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
                        revision += 1
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
                Text("© Two Ls LLC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .frame(minHeight: 520, maxHeight: 640)
        .id(revision)
    }
}

/// Hosts the SwiftUI settings in a normal titled window; activates the app so a
/// LSUIElement process can show and focus it.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private unowned let controller: PalController
    private let sessions: SessionStore
    private let onChanged: () -> Void
    private let ticker = SettingsStatsTicker()

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
            let view = SettingsView(controller: controller, sessions: sessions,
                                    onChanged: onChanged, ticker: ticker)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "Timi Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            w.delegate = self
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
