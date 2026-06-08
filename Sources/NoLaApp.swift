import AppKit
import SwiftUI

@main
struct NoLaApp: App {

    init() {
        // Single-instance guard.
        // Runs before SwiftUI constructs any scene, so the duplicate never
        // adds a menu-bar icon or touches queue.json.
        //
        // Debug and Release share the same bundle ID; Xcode kills the
        // previous Debug process on each re-run so this is transparent
        // during normal development. If you ever need both simultaneously
        // (e.g. Debug + installed Release), give one a different bundle ID
        // in project.yml.
        let bundleID = Bundle.main.bundleIdentifier ?? "com.rodrigogaray.nola"
        let duplicates = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if let existing = duplicates.first {
            // Bring the already-running instance's menu-bar popover to attention.
            existing.activate(options: .activateIgnoringOtherApps)
            exit(0)   // terminate before any scene or state is created
        }
    }

    var body: some Scene {
        MenuBarExtra("NoLa", systemImage: "arrow.down.circle.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        // Settings window managed by SettingsWindowController (not a Settings scene)
        // because openSettings() doesn't work in a pure LSUIElement app.
    }
}
