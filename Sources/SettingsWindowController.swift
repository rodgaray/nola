import AppKit
import SwiftUI

/// Manages the Settings window for a pure LSUIElement menu-bar app.
///
/// Two-phase approach to reliably steal focus from a foreground regular app:
///
///   Phase 1 (synchronous): setActivationPolicy(.regular)
///     The OS queues the policy change but hasn't applied it yet.
///
///   Phase 2 (next run-loop pass via async): activate + makeKeyAndOrderFront
///     + orderFrontRegardless
///     By the time this runs the policy change is effective, so activate() can
///     actually steal focus from whatever was frontmost, and the window lands
///     visibly in front.
///
/// Without the async gap, activate() fires while policy is still .accessory and
/// the OS silently ignores it, leaving the window behind the active app.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() {}

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: controller)
            win.title = "Preferencias — NoLa"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            win.setFrameAutosaveName("NoLaSettings")
            win.delegate = self
            window = win
        }

        // Phase 1: request the policy change (async effect inside AppKit).
        NSApp.setActivationPolicy(.regular)

        // Phase 2: one run-loop pass later, the policy is applied.
        // Now activate the app and bring the window forward.
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
            // orderFrontRegardless forces the window above the previous
            // frontmost app's windows even if it briefly regains focus
            // during the MenuBarExtra popover dismiss animation.
            self?.window?.orderFrontRegardless()
        }
    }

    // Restore .accessory so NoLa disappears from the Dock / Cmd-Tab switcher.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
