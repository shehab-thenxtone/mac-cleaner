import Foundation

public enum CommandGroup: String, CaseIterable, Identifiable, Sendable {
    case docker = "Docker"
    case homebrew = "Homebrew"
    case packageManagers = "Package Managers"
    case xcode = "Xcode & Simulators"
    case system = "macOS System"

    public var id: String { rawValue }
}

public struct CleanupCommand: Identifiable, Hashable, Sendable {
    public let id: String
    public let group: CommandGroup
    public let title: String
    public let summary: String
    public let command: String
    /// Executable that must be on PATH for the command to be offered.
    public let requiredTool: String?
    public let risk: RiskLevel
    /// Run through macOS's own administrator prompt (no `sudo` in `command`).
    public let requiresAdmin: Bool

    public init(
        id: String, group: CommandGroup, title: String, summary: String, command: String,
        requiredTool: String? = nil, risk: RiskLevel, requiresAdmin: Bool = false
    ) {
        self.id = id
        self.group = group
        self.title = title
        self.summary = summary
        self.command = command
        self.requiredTool = requiredTool
        self.risk = risk
        self.requiresAdmin = requiresAdmin
    }
}

extension CleanupCommand {
    public static let catalog: [CleanupCommand] = [
        // Docker
        .init(id: "docker-df", group: .docker, title: "Show Docker disk usage",
              summary: "Read-only report of space used by images, containers, volumes and build cache.",
              command: "docker system df", requiredTool: "docker", risk: .safe),
        .init(id: "docker-prune", group: .docker, title: "Prune unused Docker data",
              summary: "Removes stopped containers, unused networks, dangling images and build cache.",
              command: "docker system prune -f", requiredTool: "docker", risk: .review),
        .init(id: "docker-builder-prune", group: .docker, title: "Prune build cache",
              summary: "Removes all BuildKit build cache.",
              command: "docker builder prune -a -f", requiredTool: "docker", risk: .review),
        .init(id: "docker-image-prune", group: .docker, title: "Remove unused images",
              summary: "Removes every image not used by at least one container.",
              command: "docker image prune -a -f", requiredTool: "docker", risk: .review),
        .init(id: "docker-prune-all", group: .docker, title: "Deep prune (incl. volumes)",
              summary: "Removes ALL unused images, containers, networks and volumes. Volume data is lost.",
              command: "docker system prune -a -f --volumes", requiredTool: "docker", risk: .caution),

        // Homebrew
        .init(id: "brew-cleanup", group: .homebrew, title: "Clean up Homebrew",
              summary: "Removes old versions and the entire download cache.",
              command: "brew cleanup --prune=all -s", requiredTool: "brew", risk: .safe),
        .init(id: "brew-autoremove", group: .homebrew, title: "Remove orphaned dependencies",
              summary: "Uninstalls formulae that were only installed as dependencies and are no longer needed.",
              command: "brew autoremove", requiredTool: "brew", risk: .review),
        .init(id: "brew-doctor", group: .homebrew, title: "Run brew doctor",
              summary: "Read-only health check of your Homebrew installation.",
              command: "brew doctor", requiredTool: "brew", risk: .safe),
        .init(id: "brew-cache-size", group: .homebrew, title: "Show Homebrew cache size",
              summary: "Read-only size of the Homebrew download cache.",
              command: "du -sh \"$(brew --cache)\"", requiredTool: "brew", risk: .safe),

        // Package managers
        .init(id: "npm-cache", group: .packageManagers, title: "Clean npm cache",
              summary: "Clears the npm package cache.",
              command: "npm cache clean --force", requiredTool: "npm", risk: .safe),
        .init(id: "yarn-cache", group: .packageManagers, title: "Clean Yarn cache",
              summary: "Clears the global Yarn cache.",
              command: "yarn cache clean", requiredTool: "yarn", risk: .safe),
        .init(id: "pnpm-prune", group: .packageManagers, title: "Prune pnpm store",
              summary: "Removes unreferenced packages from the pnpm store.",
              command: "pnpm store prune", requiredTool: "pnpm", risk: .safe),
        .init(id: "pip-purge", group: .packageManagers, title: "Purge pip cache",
              summary: "Clears pip's wheel and HTTP cache.",
              command: "pip3 cache purge", requiredTool: "pip3", risk: .safe),
        .init(id: "go-modcache", group: .packageManagers, title: "Clean Go module cache",
              summary: "Removes the Go module download cache.",
              command: "go clean -modcache", requiredTool: "go", risk: .safe),
        .init(id: "gradle-stop", group: .packageManagers, title: "Stop Gradle daemons",
              summary: "Stops running Gradle daemons, freeing memory.",
              command: "gradle --stop", requiredTool: "gradle", risk: .safe),

        // Xcode
        .init(id: "simctl-unavailable", group: .xcode, title: "Delete unavailable simulators",
              summary: "Removes simulators whose runtime is no longer installed.",
              command: "xcrun simctl delete unavailable", requiredTool: "xcrun", risk: .safe),
        .init(id: "simctl-runtimes", group: .xcode, title: "List simulator runtimes",
              summary: "Read-only list of installed simulator runtimes and their size.",
              command: "xcrun simctl runtime list", requiredTool: "xcrun", risk: .safe),
        .init(id: "derived-data", group: .xcode, title: "Wipe all DerivedData",
              summary: "Deletes every Xcode DerivedData folder permanently (not via Trash).",
              command: "rm -rf ~/Library/Developer/Xcode/DerivedData/*", risk: .review),

        // macOS
        .init(id: "disk-free", group: .system, title: "Show disk usage",
              summary: "Read-only free space report for mounted volumes.",
              command: "df -h", risk: .safe),
        .init(id: "home-top", group: .system, title: "Largest folders in home",
              summary: "Read-only: the 20 largest top-level folders in your home (may take a while).",
              command: "du -hd1 ~ 2>/dev/null | sort -hr | head -20", risk: .safe),
        .init(id: "tm-list", group: .system, title: "List local Time Machine snapshots",
              summary: "Read-only list of APFS local snapshots, which can hold a lot of space.",
              command: "tmutil listlocalsnapshots /", risk: .safe),
        .init(id: "tm-thin", group: .system, title: "Thin local snapshots",
              summary: "Asks macOS to free up to 50 GB held by local Time Machine snapshots.",
              command: "tmutil thinlocalsnapshots / 50000000000 4", risk: .review),
        .init(id: "ql-reset", group: .system, title: "Reset Quick Look cache",
              summary: "Clears Quick Look thumbnail caches.",
              command: "qlmanage -r cache", risk: .safe),
        .init(id: "empty-trash", group: .system, title: "Empty the Trash",
              summary: "Permanently deletes everything in the Trash, including items this app moved there.",
              command: "osascript -e 'tell application \"Finder\" to empty trash'", risk: .caution),
        .init(id: "flush-dns", group: .system, title: "Flush DNS cache",
              summary: "Clears the system DNS resolver cache. macOS will ask for your password.",
              command: "dscacheutil -flushcache; killall -HUP mDNSResponder", risk: .safe, requiresAdmin: true),
        .init(id: "purge-memory", group: .system, title: "Purge inactive memory",
              summary: "Flushes disk caches from RAM. macOS will ask for your password.",
              command: "purge", risk: .safe, requiresAdmin: true),
    ]
}
