import Foundation

public enum RiskLevel: String, Sendable, CaseIterable {
    case safe, review, caution

    public var label: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .caution: "Caution"
        }
    }
}

public struct FileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let size: Int64
    public let modified: Date?
    public let isDirectory: Bool

    public init(url: URL, size: Int64, modified: Date?, isDirectory: Bool) {
        self.url = url
        self.size = size
        self.modified = modified
        self.isDirectory = isDirectory
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
    public var location: String { url.deletingLastPathComponent().path }
    public var modifiedSortKey: Date { modified ?? .distantPast }
}

public struct ScanResult: Sendable {
    public let items: [FileItem]
    public let unreadable: [String]

    public init(items: [FileItem], unreadable: [String] = []) {
        self.items = items
        self.unreadable = unreadable
    }

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    public func removing(_ urls: Set<URL>) -> ScanResult {
        ScanResult(items: items.filter { !urls.contains($0.url) }, unreadable: unreadable)
    }
}

public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
