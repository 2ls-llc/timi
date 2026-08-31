import SwiftUI
import KeyboardShortcuts
import PixelPalKit

/// The one SwiftUI surface in the app (§2: AppKit everywhere else).
struct SettingsView: View {
    unowned let controller: PalController
    let sessions: SessionStore
    var onChanged: () -> Void

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
            Section("Character") {
                Picker("Character", selection: binding({ controller.settings.character },
                                                       { controller.switchCharacter(to: $0) })) {
                    ForEach(CharacterID.allCases, id: \.self) { id in
                        Text(CharacterConfig.config(for: id).name).tag(id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

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
                LabeledContent("Pixel Pal",
                               value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                Text("A tiny 1-bit pixel pet that keeps your focus timer. Pip and Mochi were born as web prototypes; this is their native home.")
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

    init(controller: PalController, sessions: SessionStore, onChanged: @escaping () -> Void) {
        self.controller = controller
        self.sessions = sessions
        self.onChanged = onChanged
    }

    func show() {
        if window == nil {
            let view = SettingsView(controller: controller, sessions: sessions,
                                    onChanged: onChanged)
            let hosting = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hosting)
            w.title = "Pixel Pal Settings"
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
