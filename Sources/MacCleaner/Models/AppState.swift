import CleanerCore
import Foundation
import Observation

struct CategoryScanState {
    var isScanning = false
    var result: ScanResult?
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class AppState {
    let home: URL
    let categories = CleanupCategory.catalog
    let commands = CleanupCommand.catalog
    let console: ConsoleModel
    let largeFiles: LargeFilesModel

    private(set) var scans: [String: CategoryScanState] = [:]
    private(set) var disk: DiskSpace?
    private(set) var availableTools: Set<String> = []
    private(set) var isScanningAll = false
    private(set) var lastRefreshed: Date?
    var alert: AppAlert?

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
        console = ConsoleModel(home: home)
        largeFiles = LargeFilesModel(root: home)
        refreshDisk()
        refreshTools()
    }

    // MARK: Scanning

    func scanState(for category: CleanupCategory) -> CategoryScanState {
        scans[category.id] ?? CategoryScanState()
    }

    var totalFound: Int64 {
        scans.values.compactMap(\.result?.totalSize).reduce(0, +)
    }

    func scan(_ category: CleanupCategory) async {
        guard !scanState(for: category).isScanning else { return }
        scans[category.id] = CategoryScanState(isScanning: true, result: scans[category.id]?.result)
        let home = self.home
        let result = await Task.detached(priority: .userInitiated) {
            FileScanner.scan(category, home: home)
        }.value
        // Items may have been trashed while this scan was running.
        let gone = Set(result.items.map(\.url).filter { !FileManager.default.fileExists(atPath: $0.path) })
        scans[category.id] = CategoryScanState(isScanning: false, result: result.removing(gone))
    }

    func scanAll() async {
        guard !isScanningAll else { return }
        isScanningAll = true
        for category in categories {
            await scan(category)
        }
        isScanningAll = false
        refreshDisk()
        lastRefreshed = Date()
    }

    /// Re-reads disk space and installed tools, then rescans every category.
    func refreshAll() async {
        refreshDisk()
        refreshTools()
        await scanAll()
    }

    // MARK: Removing

    private var protectedRoots: [URL] {
        SafetyGuard.defaultProtectedRoots(home: home)
            + categories.filter { $0.mode == .children }.flatMap { $0.roots(home: home) }
    }

    func moveToTrash(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let home = self.home
        let protected = protectedRoots
        let report = await Task.detached(priority: .userInitiated) {
            Trasher.moveToTrash(urls, home: home, protectedRoots: protected)
        }.value

        let removed = Set(report.trashed)
        scans = scans.mapValues { state in
            CategoryScanState(isScanning: state.isScanning, result: state.result?.removing(removed))
        }
        largeFiles.remove(removed)
        refreshDisk()

        if !report.failures.isEmpty {
            let lines = report.failures.prefix(12).map { "• \($0.url.lastPathComponent): \($0.reason)" }
            let more = report.failures.count > 12 ? "\n…and \(report.failures.count - 12) more" : ""
            alert = AppAlert(
                title: "\(report.failures.count) item(s) could not be moved to the Trash",
                message: lines.joined(separator: "\n") + more)
        }
    }

    // MARK: Commands

    func isAvailable(_ command: CleanupCommand) -> Bool {
        command.requiredTool.map(availableTools.contains) ?? true
    }

    func run(_ command: CleanupCommand) {
        console.run(title: command.title, command: command.command, asAdmin: command.requiresAdmin) { [weak self] in
            self?.refreshDisk()
        }
    }

    func runCustom(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        console.run(title: "Custom command", command: trimmed, asAdmin: false) { [weak self] in
            self?.refreshDisk()
        }
    }

    // MARK: Environment

    func refreshDisk() {
        disk = DiskSpace.current(for: home)
    }

    func refreshTools() {
        let path = ShellEnvironment.augmentedPath(
            current: ProcessInfo.processInfo.environment["PATH"], home: home)
        let tools = Set(commands.compactMap(\.requiredTool))
        availableTools = tools.filter { ShellEnvironment.isToolAvailable($0, searchPath: path) }
    }
}
