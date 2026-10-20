import Foundation
import Testing
@testable import CleanerCore

struct SafetyGuardTests {
    let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    var protected: [URL] {
        SafetyGuard.defaultProtectedRoots(home: home) + [home.appendingPathComponent("Library/Caches")]
    }

    @Test func allowsChildOfCacheFolder() throws {
        try SafetyGuard.validate(
            home.appendingPathComponent("Library/Caches/com.example.app"), home: home, protectedRoots: protected)
    }

    @Test func rejectsHomeItself() {
        #expect(throws: SafetyError.outsideHome) {
            try SafetyGuard.validate(home, home: home, protectedRoots: protected)
        }
    }

    @Test func rejectsPathOutsideHome() {
        #expect(throws: SafetyError.outsideHome) {
            try SafetyGuard.validate(URL(fileURLWithPath: "/System/Library"), home: home, protectedRoots: protected)
        }
    }

    @Test func rejectsSiblingWithSharedPrefix() {
        #expect(throws: SafetyError.outsideHome) {
            try SafetyGuard.validate(URL(fileURLWithPath: "/Users/tester2/file"), home: home, protectedRoots: protected)
        }
    }

    @Test func rejectsTraversalOutOfHome() {
        #expect(throws: SafetyError.outsideHome) {
            try SafetyGuard.validate(
                URL(fileURLWithPath: "/Users/tester/Library/../../other/x"), home: home, protectedRoots: protected)
        }
    }

    @Test(arguments: ["Documents", "Library", "Downloads", "Library/Caches"])
    func rejectsProtectedRoots(relative: String) {
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(home.appendingPathComponent(relative), home: home, protectedRoots: protected)
        }
    }

    @Test(arguments: [".ssh/id_ed25519", ".gnupg/pubring.kbx", "Library/Keychains/login.keychain-db"])
    func rejectsLockedSubtrees(relative: String) {
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(home.appendingPathComponent(relative), home: home, protectedRoots: protected)
        }
    }
}

struct TrasherTests {
    let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

    @Test func movesAllowedItemsAndReportsRejected() {
        let allowed = home.appendingPathComponent("Library/Caches/junk")
        let blocked = home.appendingPathComponent(".ssh/id_rsa")
        let moved = LockedBox<[URL]>([])

        let report = Trasher.moveToTrash(
            [allowed, blocked], home: home, protectedRoots: SafetyGuard.defaultProtectedRoots(home: home),
            mover: { url in moved.mutate { $0.append(url) } })

        #expect(report.trashed == [allowed])
        #expect(moved.value == [allowed])
        #expect(report.failures.map(\.url) == [blocked])
    }

    @Test func reportsMoverErrors() {
        struct Boom: Error {}
        let report = Trasher.moveToTrash(
            [home.appendingPathComponent("Downloads/a.zip")], home: home, protectedRoots: [],
            mover: { _ in throw Boom() })
        #expect(report.trashed.isEmpty)
        #expect(report.failures.count == 1)
    }
}

final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T { lock.withLock { stored } }
    func mutate(_ body: (inout T) -> Void) { lock.withLock { body(&stored) } }
}

struct SafetyGuardHardeningTests {
    let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

    @Test(arguments: ["documents", "LIBRARY", "Library/caches"])
    func protectedRootsAreCaseInsensitive(relative: String) {
        let protected = SafetyGuard.defaultProtectedRoots(home: home) + [home.appendingPathComponent("Library/Caches")]
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(home.appendingPathComponent(relative), home: home, protectedRoots: protected)
        }
    }

    @Test func lockedSubtreesAreCaseInsensitive() {
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(home.appendingPathComponent(".SSH/id_rsa"), home: home, protectedRoots: [])
        }
    }

    @Test(arguments: [
        "Pictures/Photos Library.photoslibrary/originals/A/big.mov",
        "Applications/Foo.app/Contents/Resources/x.bin",
        "Library/Mail/V10/msg.emlx",
        "Library/Messages/Attachments/a.heic",
    ])
    func rejectsPackageInternalsAndPersonalData(relative: String) {
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(home.appendingPathComponent(relative), home: home, protectedRoots: [])
        }
    }

    @Test func allowsWholePackageItself() throws {
        try SafetyGuard.validate(home.appendingPathComponent("Downloads/Old.app"), home: home, protectedRoots: [])
    }
}

struct SafetyGuardDiskTests {
    @Test func cacheFolderNamedLikeAppIsNotAPackage() throws {
        let home = try TempHome()
        let file = try home.file("Library/Caches/com.electron.app/blob.bin", bytes: 10)
        try SafetyGuard.validate(file, home: home.url, protectedRoots: [])
        #expect(SafetyAdvisor.advise(for: file, home: home.url).verdict == .safe)
    }
}

struct SafetyGuardRealBundleTests {
    @Test func realAppBundleInternalsAreProtected() throws {
        let home = try TempHome()
        try home.file("Applications/Real.app/Contents/Info.plist", bytes: 10)
        let inner = try home.file("Applications/Real.app/Contents/Resources/big.bin", bytes: 10)
        #expect(throws: SafetyError.self) {
            try SafetyGuard.validate(inner, home: home.url, protectedRoots: [])
        }
    }
}
