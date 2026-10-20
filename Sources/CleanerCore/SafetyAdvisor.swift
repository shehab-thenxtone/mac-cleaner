import Foundation

public struct SafetyAdvice: Sendable, Equatable {
    public enum Verdict: String, Sendable {
        case safe, review, keep

        public var label: String {
            switch self {
            case .safe: "Safe to delete"
            case .review: "Check before deleting"
            case .keep: "Keep this file"
            }
        }
    }

    public let verdict: Verdict
    public let reason: String
    public let note: String?
}

/// Heuristic advice on whether a file can be removed, based on where it lives and what it is.
public enum SafetyAdvisor {
    static let staleAfterDays = 180

    static let cachePrefixes = [
        "library/caches", "library/logs", ".npm", ".gradle/caches", ".m2/repository",
        ".cargo/registry", ".cache", "library/developer/xcode/deriveddata",
        "library/developer/coresimulator/caches", ".bun/install/cache", "library/pnpm/store",
    ]
    static let vmMarkers = [
        "library/containers/com.docker.docker", "rancher-desktop", ".orbstack", ".colima", ".lima",
        "library/containers/com.utmapp", "virtual machines",
    ]
    static let vmExtensions: Set<String> = ["qcow2", "vmdk", "vdi", "raw", "hdd", "utm", "vhdx"]
    static let archiveExtensions: Set<String> = ["dmg", "pkg", "iso", "xip", "zip", "tar", "gz", "tgz", "7z", "rar"]
    static let personalExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "jpg", "jpeg", "heic", "png", "raw", "cr2", "nef", "arw",
        "mp3", "m4a", "wav", "aiff", "flac", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "key", "pages", "numbers", "psd", "sketch", "fig", "ai",
    ]

    public static func advise(for url: URL, home: URL, lastOpened: Date? = nil, now: Date = Date()) -> SafetyAdvice {
        let (verdict, reason) = classify(url, home: home)
        return SafetyAdvice(verdict: verdict, reason: reason, note: ageNote(lastOpened, now: now))
    }

    static func classify(_ url: URL, home: URL) -> (SafetyAdvice.Verdict, String) {
        do {
            try SafetyGuard.validate(url, home: home, protectedRoots: SafetyGuard.defaultProtectedRoots(home: home))
        } catch let error as SafetyError {
            return (.keep, "\(error.description) Mac Cleaner won't remove it.")
        } catch {
            return (.keep, error.localizedDescription)
        }

        let relative = relativePath(of: url, home: home)
        let components = relative.split(separator: "/").map(String.init)
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        if components.contains("node_modules") {
            return (.safe, "Project dependencies. Reinstall any time with npm/pnpm/yarn install.")
        }
        if cachePrefixes.contains(where: { relative.hasPrefix($0 + "/") }) {
            return (.safe, "Cache or log file. It is regenerated automatically when needed.")
        }
        if vmMarkers.contains(where: { relative.contains($0) }) || vmExtensions.contains(ext)
            || ["docker.raw", "diffdisk", "basedisk"].contains(name) {
            return (.keep, "Virtual machine or container disk. Deleting it wipes all Docker images, containers and volumes (or the whole VM). Use the Docker prune commands instead.")
        }
        if components.contains(".git") {
            return (.keep, "Part of a Git repository's history. Deleting it corrupts the repository; use `git gc` instead.")
        }
        if relative.hasPrefix("library/application support/mobilesync/") {
            return (.review, "iPhone/iPad backup. Delete only if you have a newer backup (e.g. in iCloud).")
        }
        if relative.hasPrefix("library/developer/coresimulator/devices/") {
            return (.review, "Simulator data. Prefer removing whole simulators from Xcode or `xcrun simctl delete unavailable`.")
        }
        if relative.hasPrefix("library/developer/") {
            return (.review, "Developer tooling data (archives, device support, SDKs). Usually re-downloadable, but check you no longer need it.")
        }
        if archiveExtensions.contains(ext) {
            return components.first == "downloads"
                ? (.safe, "Installer or archive in Downloads. Safe once you've installed or extracted it.")
                : (.review, "Installer or archive. Safe once you've installed or extracted it.")
        }
        if components.first == "library" {
            return (.keep, "Application data. Removing it can reset or break the app that owns it.")
        }
        if personalExtensions.contains(ext) {
            return (.review, "Personal file (media or document). Make sure it is backed up before deleting.")
        }
        return (.review, "Unknown file type. Check what it is before deleting.")
    }

    static func ageNote(_ lastOpened: Date?, now: Date) -> String? {
        guard let lastOpened else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastOpened, to: now).day ?? 0
        if days >= staleAfterDays { return "Not opened in \(days) days." }
        if days <= 7 { return "Opened recently, so it may still be in use." }
        return nil
    }

    static func relativePath(of url: URL, home: URL) -> String {
        let target = SafetyGuard.canonical(url).pathComponents
        let base = SafetyGuard.canonicalDirectory(home).pathComponents
        return target.dropFirst(base.count).joined(separator: "/").lowercased()
    }
}
