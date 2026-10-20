#if DEBUG
import AppKit
import CleanerCore
import SwiftUI

/// Debug-only: renders each screen offscreen to PNG (set MACCLEANER_SNAPSHOT_DIR).
@MainActor
enum SnapshotRenderer {
    static func renderAll(to directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = AppState()
        await app.scanAll()
        app.run(app.commands.first { $0.id == "docker-df" }!)
        app.largeFiles.root = app.home.appendingPathComponent("Library/Developer")
        app.largeFiles.threshold = 100_000_000
        app.largeFiles.start()
        while app.largeFiles.isScanning { try? await Task.sleep(for: .milliseconds(300)) }
        try? await Task.sleep(for: .seconds(4))

        let samples = Array(app.largeFiles.items.prefix(4))
        let adviceView = HStack(alignment: .top, spacing: 0) {
            PreviewPane(items: Array(samples.prefix(1)), home: app.home, showsAdvice: true)
                .frame(width: 420, height: 780)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(samples) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.url.path.replacingOccurrences(of: app.home.path, with: "~"))
                            .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                        AdviceCallout(advice: SafetyAdvisor.advise(for: item.url, home: app.home))
                    }
                }
            }
            .padding(16)
            .frame(width: 820, height: 780, alignment: .top)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        let adviceHost = NSHostingView(rootView: adviceView)
        adviceHost.frame = NSRect(x: 0, y: 0, width: 1240, height: 780)
        let adviceWindow = NSWindow(contentRect: adviceHost.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        adviceWindow.contentView = adviceHost
        try? await Task.sleep(for: .seconds(1))
        if let rep = adviceHost.bitmapImageRepForCachingDisplay(in: adviceHost.bounds) {
            adviceHost.cacheDisplay(in: adviceHost.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: directory.appendingPathComponent("advice.png"))
        }

        let screens: [(String, SidebarItem)] = [
            ("overview", .overview),
            ("caches", .category("user-caches")),
            ("commands", .commands),
            ("largefiles", .largeFiles),
        ]
        for (name, item) in screens {
            let root = ContentView(initialSelection: item).environment(app).frame(width: 1240, height: 780)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
                styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            let host = NSHostingView(rootView: root)
            host.sizingOptions = []
            window.contentView = host
            window.setContentSize(NSSize(width: 1240, height: 780))
            window.orderBack(nil)
            try? await Task.sleep(for: .seconds(1.5))
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: directory.appendingPathComponent("\(name).png"))
            window.orderOut(nil)
        }
    }
}
#endif
