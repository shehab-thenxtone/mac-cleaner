import Foundation

public enum SafetyError: Error, Equatable, CustomStringConvertible {
    case outsideHome
    case protectedLocation(String)

    public var description: String {
        switch self {
        case .outsideHome: "Only items inside your home folder can be removed."
        case .protectedLocation(let path): "\(path) is a protected location."
        }
    }
}

/// Decides whether a path may be moved to the Trash by the app.
public enum SafetyGuard {
    /// Folders that may never be removed themselves (their contents may be).
    public static let protectedFolderNames = [
        "Desktop", "Documents", "Downloads", "Library", "Movies", "Music",
        "Pictures", "Public", "Applications", ".Trash",
    ]

    /// Subtrees where nothing may be removed.
    public static let lockedSubtrees = [
        ".ssh", ".gnupg", "Library/Keychains", "Library/Messages", "Library/Mail",
        "Library/Mobile Documents", "Library/Calendars", "Library/Application Support/AddressBook",
        "Library/Containers/com.apple.mail",
    ]

    /// Bundles whose internals must never be removed piecemeal.
    public static let packageExtensions: Set<String> = [
        "app", "photoslibrary", "photolibrary", "musiclibrary", "tvlibrary", "imovielibrary",
        "fcpbundle", "logicx", "sparsebundle", "bundle", "framework", "xcarchive", "pkg",
    ]

    public static func defaultProtectedRoots(home: URL) -> [URL] {
        protectedFolderNames.map { home.appendingPathComponent($0) }
    }

    public static func validate(_ url: URL, home: URL, protectedRoots: [URL]) throws {
        let target = canonical(url)
        // APFS is case-insensitive by default, so compare folded components.
        let homeComponents = folded(canonicalDirectory(home).pathComponents)
        let components = folded(target.pathComponents)

        guard components.count > homeComponents.count,
              Array(components.prefix(homeComponents.count)) == homeComponents else {
            throw SafetyError.outsideHome
        }
        if protectedRoots.contains(where: { folded(canonicalDirectory($0).pathComponents) == components }) {
            throw SafetyError.protectedLocation(target.path)
        }
        let relative = Array(components.dropFirst(homeComponents.count))
        for subtree in lockedSubtrees {
            let parts = folded(subtree.split(separator: "/").map(String.init))
            if relative.starts(with: parts) {
                throw SafetyError.protectedLocation(target.path)
            }
        }
        let homeDepth = homeComponents.count
        for depth in (homeDepth + 1)..<components.count where isPackage(prefixOf: target, depth: depth) {
            throw SafetyError.protectedLocation(target.path)
        }
    }

    /// Library-style bundles identified by extension alone.
    static let libraryExtensions: Set<String> = [
        "photoslibrary", "photolibrary", "musiclibrary", "tvlibrary", "imovielibrary",
        "fcpbundle", "logicx", "sparsebundle",
    ]

    /// Whether the ancestor made of the first `depth` components is a bundle (e.g. .app, .photoslibrary).
    /// Existing folders must look like real bundles (have an Info.plist), so a cache folder named
    /// `com.foo.app` is not mistaken for an application.
    static func isPackage(prefixOf url: URL, depth: Int) -> Bool {
        let path = NSString.path(withComponents: Array(url.pathComponents.prefix(depth)))
        let ext = (path as NSString).pathExtension.lowercased()
        guard packageExtensions.contains(ext) else { return false }
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return true  // can't inspect it: be conservative
        }
        if libraryExtensions.contains(ext) { return true }
        return fm.fileExists(atPath: path + "/Contents/Info.plist") || fm.fileExists(atPath: path + "/Info.plist")
    }

    static func folded(_ components: [String]) -> [String] {
        components.map { $0.lowercased() }
    }

    /// Resolves symlinks in the parent only, so a symlink item is judged by where it lives.
    static func canonical(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        let parent = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        return parent.appendingPathComponent(standardized.lastPathComponent)
    }

    static func canonicalDirectory(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

public struct TrashFailure: Sendable, Equatable {
    public let url: URL
    public let reason: String
}

public struct TrashReport: Sendable {
    public let trashed: [URL]
    public let failures: [TrashFailure]
}

public enum Trasher {
    public typealias Mover = @Sendable (URL) throws -> Void

    public static let finderTrash: Mover = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Moves items to the Trash (recoverable). Every item is checked by `SafetyGuard` first.
    public static func moveToTrash(
        _ urls: [URL], home: URL, protectedRoots: [URL], mover: Mover = finderTrash
    ) -> TrashReport {
        var trashed: [URL] = []
        var failures: [TrashFailure] = []
        for url in urls {
            do {
                try SafetyGuard.validate(url, home: home, protectedRoots: protectedRoots)
                try mover(url)
                trashed.append(url)
            } catch let error as SafetyError {
                failures.append(TrashFailure(url: url, reason: error.description))
            } catch {
                failures.append(TrashFailure(url: url, reason: error.localizedDescription))
            }
        }
        return TrashReport(trashed: trashed, failures: failures)
    }
}
