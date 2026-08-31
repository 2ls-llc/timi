import AppKit
import PixelPalKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var controller: PalController!
    private var observers: [NSObjectProtocol] = []
    private var debugHarness: DebugHarness?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = PalController()
        controller.startRunning()
        debugHarness = DebugHarness(controller: controller)

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.controller.systemDidWake()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.controller.screensChanged()
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
