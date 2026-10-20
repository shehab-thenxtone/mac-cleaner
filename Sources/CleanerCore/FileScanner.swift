import Foundation

public enum DirectorySizer {
    static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey, .contentModificationDateKey,
    ]

    static func allocated(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }

    /// Allocated on-disk size. Symlinks are never followed.
    public static func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: keys)
        if values?.isSymbolicLink == true || values?.isDirectory != true {
            return allocated(values)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [],
            errorHandler: { _, _ in true }  // skip unreadable entries, keep counting
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            if Task.isCancelled { break }
            guard let childValues = try? child.resourceValues(forKeys: keys),
                  childValues.isDirectory != true else { continue }
            total += allocated(childValues)
        }
        return total
    }
}

public enum FileScanner {
    public static func item(for url: URL) -> FileItem {
        let values = try? url.resourceValues(forKeys: DirectorySizer.keys)
        let isDirectory = values?.isDirectory == true && values?.isSymbolicLink != true
        return FileItem(
            url: url,
            size: DirectorySizer.size(of: url),
            modified: values?.contentModificationDate,
            isDirectory: isDirectory)
    }

    public static func scan(_ category: CleanupCategory, home: URL) -> ScanResult {
        let fm = FileManager.default
        var items: [FileItem] = []
        var unreadable: [String] = []

        for root in category.roots(home: home) where fm.fileExists(atPath: root.path) {
            if Task.isCancelled { break }
            switch category.mode {
            case .roots:
                items.append(item(for: root))
            case .children:
                do {
                    let children = try fm.contentsOfDirectory(
                        at: root, includingPropertiesForKeys: Array(DirectorySizer.keys), options: [])
                    items.append(contentsOf: children.map(item(for:)))
                } catch {
                    unreadable.append(root.path)
                }
            }
        }
        return ScanResult(items: items.sorted { $0.size > $1.size }, unreadable: unreadable)
    }

    /// Finds regular files at or above `minimumSize` under `root`, largest first.
    public static func largeFiles(
        in root: URL, minimumSize: Int64, limit: Int = 1000,
        progress: @Sendable (Int) -> Void = { _ in }
    ) -> [FileItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .contentModificationDateKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [FileItem] = []
        var visited = 0
        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            visited += 1
            if visited % 2000 == 0 { progress(visited) }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let size = DirectorySizer.allocated(values)
            if size >= minimumSize {
                found.append(FileItem(
                    url: url, size: size, modified: values.contentModificationDate, isDirectory: false))
            }
        }
        progress(visited)
        return Array(found.sorted { $0.size > $1.size }.prefix(limit))
    }
}

public struct DiskSpace: Sendable, Equatable {
    public let total: Int64
    public let available: Int64

    public init(total: Int64, available: Int64) {
        self.total = total
        self.available = available
    }

    public var used: Int64 { max(total - available, 0) }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public static func current(for url: URL) -> DiskSpace? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskSpace(total: Int64(total), available: available)
    }
}
