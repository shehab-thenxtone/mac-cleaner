import AppKit
import SwiftUI

@main
struct MacCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup("Mac Cleaner") {
            ContentView()
                .environment(app)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .commands { SidebarCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare SwiftPM executable (`swift run`).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["MACCLEANER_SNAPSHOT_DIR"] {
            Task { @MainActor in
                await SnapshotRenderer.renderAll(to: URL(fileURLWithPath: dir))
                NSApp.terminate(nil)
            }
        }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
