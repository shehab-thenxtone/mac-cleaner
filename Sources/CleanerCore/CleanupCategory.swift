import Foundation

/// How a category's root folders are presented.
public enum ScanMode: Sendable {
    /// List every child of each root as a separate removable item (root itself is kept).
    case children
    /// Each existing root folder is itself a removable item.
    case roots
}

public struct CleanupCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let symbol: String
    public let risk: RiskLevel
    public let mode: ScanMode
    /// Paths relative to the user's home directory.
    public let relativePaths: [String]

    public func roots(home: URL) -> [URL] {
        relativePaths.map { home.appendingPathComponent($0, isDirectory: true) }
    }
}

extension CleanupCategory {
    public static let catalog: [CleanupCategory] = [
        CleanupCategory(
            id: "user-caches", title: "User Caches",
            summary: "Per-app caches in ~/Library/Caches. Apps rebuild them automatically.",
            symbol: "archivebox", risk: .safe, mode: .children,
            relativePaths: ["Library/Caches"]),
        CleanupCategory(
            id: "logs", title: "Logs",
            summary: "Application and diagnostic logs in ~/Library/Logs.",
            symbol: "doc.text", risk: .safe, mode: .children,
            relativePaths: ["Library/Logs"]),
        CleanupCategory(
            id: "xcode-derived", title: "Xcode DerivedData",
            summary: "Build intermediates and indexes. Xcode regenerates them on the next build.",
            symbol: "hammer", risk: .safe, mode: .children,
            relativePaths: ["Library/Developer/Xcode/DerivedData"]),
        CleanupCategory(
            id: "simulator-caches", title: "Simulator Caches",
            summary: "CoreSimulator dyld and runtime caches.",
            symbol: "iphone", risk: .safe, mode: .children,
            relativePaths: ["Library/Developer/CoreSimulator/Caches"]),
        CleanupCategory(
            id: "device-support", title: "Device Support",
            summary: "Debug symbols copied from connected devices. Re-downloaded when a device is attached again.",
            symbol: "cable.connector", risk: .review, mode: .children,
            relativePaths: [
                "Library/Developer/Xcode/iOS DeviceSupport",
                "Library/Developer/Xcode/watchOS DeviceSupport",
                "Library/Developer/Xcode/tvOS DeviceSupport",
                "Library/Developer/Xcode/visionOS DeviceSupport",
            ]),
        CleanupCategory(
            id: "xcode-archives", title: "Xcode Archives",
            summary: "App archives created by Product > Archive. Keep the ones you may need to re-symbolicate.",
            symbol: "shippingbox", risk: .review, mode: .children,
            relativePaths: ["Library/Developer/Xcode/Archives"]),
        CleanupCategory(
            id: "dev-caches", title: "Package Manager Caches",
            summary: "npm, pnpm, Yarn, Bun, Gradle, Maven, Cargo and CocoaPods download caches.",
            symbol: "shippingbox.circle", risk: .review, mode: .roots,
            relativePaths: [
                ".npm/_cacache",
                "Library/pnpm/store",
                ".yarn/berry/cache",
                ".bun/install/cache",
                ".gradle/caches",
                ".m2/repository",
                ".cargo/registry",
                ".cocoapods/repos",
            ]),
        CleanupCategory(
            id: "downloads", title: "Downloads",
            summary: "Everything in ~/Downloads. Check each item before removing it.",
            symbol: "arrow.down.circle", risk: .review, mode: .children,
            relativePaths: ["Downloads"]),
        CleanupCategory(
            id: "ios-backups", title: "iPhone & iPad Backups",
            summary: "Local device backups. Reading this folder may require Full Disk Access.",
            symbol: "externaldrive.badge.timemachine", risk: .caution, mode: .children,
            relativePaths: ["Library/Application Support/MobileSync/Backup"]),
    ]
}
