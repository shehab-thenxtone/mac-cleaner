import Foundation
import Testing
@testable import CleanerCore

final class TempHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCleanerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ relative: String, bytes: Int) throws -> URL {
        let target = url.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: target)
        return target
    }
}

struct FileScannerTests {
    @Test func directorySizeCountsNestedFiles() throws {
        let home = try TempHome()
        try home.file("dir/a.bin", bytes: 100_000)
        try home.file("dir/nested/b.bin", bytes: 200_000)

        let size = DirectorySizer.size(of: home.url.appendingPathComponent("dir"))
        #expect(size >= 300_000)
    }

    @Test func directorySizeDoesNotFollowSymlinks() throws {
        let home = try TempHome()
        let big = try home.file("big/blob.bin", bytes: 2_000_000)
        try FileManager.default.createDirectory(
            at: home.url.appendingPathComponent("linker"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: home.url.appendingPathComponent("linker/link"), withDestinationURL: big.deletingLastPathComponent())

        #expect(DirectorySizer.size(of: home.url.appendingPathComponent("linker")) < 100_000)
    }

    @Test func childrenModeListsChildrenLargestFirst() throws {
        let home = try TempHome()
        try home.file("Library/Caches/small/x", bytes: 10_000)
        try home.file("Library/Caches/large/y", bytes: 500_000)
        let category = try #require(CleanupCategory.catalog.first { $0.id == "user-caches" })

        let result = FileScanner.scan(category, home: home.url)

        #expect(result.items.map(\.name) == ["large", "small"])
        #expect(result.items.allSatisfy { $0.isDirectory })
        #expect(result.totalSize >= 510_000)
        #expect(result.unreadable.isEmpty)
    }

    @Test func rootsModeSkipsMissingRoots() throws {
        let home = try TempHome()
        try home.file(".npm/_cacache/index", bytes: 50_000)
        let category = try #require(CleanupCategory.catalog.first { $0.id == "dev-caches" })

        let result = FileScanner.scan(category, home: home.url)

        #expect(result.items.map(\.name) == ["_cacache"])
    }

    @Test func largeFilesFiltersByThreshold() throws {
        let home = try TempHome()
        try home.file("a/huge.bin", bytes: 3_000_000)
        try home.file("b/tiny.txt", bytes: 1_000)

        let found = FileScanner.largeFiles(in: home.url, minimumSize: 1_000_000)

        #expect(found.map(\.name) == ["huge.bin"])
    }

    @Test func scanResultRemovingDropsUrls() {
        let a = FileItem(url: URL(fileURLWithPath: "/tmp/a"), size: 1, modified: nil, isDirectory: false)
        let b = FileItem(url: URL(fileURLWithPath: "/tmp/b"), size: 2, modified: nil, isDirectory: false)
        let result = ScanResult(items: [a, b]).removing([a.url])
        #expect(result.items == [b])
        #expect(result.totalSize == 2)
    }

    @Test func diskSpaceReportsCapacity() throws {
        let disk = try #require(DiskSpace.current(for: FileManager.default.homeDirectoryForCurrentUser))
        #expect(disk.total > 0)
        #expect((0...1).contains(disk.usedFraction))
    }
}
