import CleanerCore
import Foundation
import Observation

@MainActor
@Observable
final class LargeFilesModel {
    static let thresholds: [Int64] = [100, 250, 500, 1_000, 5_000].map { $0 * 1_000_000 }

    var root: URL {
        didSet {
            cancel()
            items = []
            hasScanned = false
        }
    }
    var threshold: Int64 = 500_000_000
    private(set) var items: [FileItem] = []
    private(set) var isScanning = false
    private(set) var visitedCount = 0
    private(set) var hasScanned = false

    private var work: Task<[FileItem], Never>?
    private var generation = 0

    init(root: URL) {
        self.root = root
    }

    func start() {
        cancel()
        isScanning = true
        visitedCount = 0
        generation += 1
        let token = generation
        let root = self.root
        let threshold = self.threshold
        let work = Task.detached(priority: .userInitiated) { [weak self] in
            FileScanner.largeFiles(in: root, minimumSize: threshold) { visited in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    self.visitedCount = visited
                }
            }
        }
        self.work = work
        Task {
            let found = await work.value
            guard self.work == work else { return }  // superseded by a newer scan
            items = found
            isScanning = false
            hasScanned = true
            self.work = nil
        }
    }

    func cancel() {
        work?.cancel()
        work = nil
        isScanning = false
    }

    func remove(_ urls: Set<URL>) {
        items = items.filter { !urls.contains($0.url) }
    }
}
