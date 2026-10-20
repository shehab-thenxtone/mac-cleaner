import Foundation

public enum ShellEnvironment {
    /// GUI apps launched from Finder get a minimal PATH; add the usual tool locations.
    public static func augmentedPath(current: String?, home: URL) -> String {
        let h = home.path
        let extras = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin",
            "\(h)/.rd/bin", "\(h)/.docker/bin", "\(h)/.orbstack/bin",
            "/Applications/Docker.app/Contents/Resources/bin",
            "\(h)/.local/bin", "\(h)/.volta/bin", "\(h)/.bun/bin", "\(h)/.cargo/bin",
            "/usr/local/go/bin", "\(h)/go/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        let existing = (current ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (existing + extras)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }

    public static func environment(base: [String: String], home: URL) -> [String: String] {
        var env = base
        env["PATH"] = augmentedPath(current: base["PATH"], home: home)
        env["HOME"] = home.path
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        env["HOMEBREW_NO_COLOR"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return env
    }

    public static func appleScriptEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    public static func isToolAvailable(_ tool: String, searchPath: String) -> Bool {
        searchPath.split(separator: ":").contains {
            FileManager.default.isExecutableFile(atPath: "\($0)/\(tool)")
        }
    }
}

public struct ShellInvocation: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(command: String, asAdmin: Bool) {
        if asAdmin {
            executable = "/usr/bin/osascript"
            arguments = [
                "-e",
                "do shell script \"\(ShellEnvironment.appleScriptEscaped(command))\" with administrator privileges",
            ]
        } else {
            executable = "/bin/zsh"
            arguments = ["-l", "-c", command]
        }
    }
}

public enum ShellEvent: Sendable, Equatable {
    case output(String)
    case error(String)
    case finished(Int32)
}

/// Runs one shell command and streams its stdout/stderr as events.
public final class ShellProcess: @unchecked Sendable {
    public let events: AsyncStream<ShellEvent>
    private let continuation: AsyncStream<ShellEvent>.Continuation
    private let process = Process()

    public init(
        command: String, asAdmin: Bool = false,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        (events, continuation) = AsyncStream.makeStream(of: ShellEvent.self)
        let invocation = ShellInvocation(command: command, asAdmin: asAdmin)
        process.executableURL = URL(fileURLWithPath: invocation.executable)
        process.arguments = invocation.arguments
        process.environment = ShellEnvironment.environment(base: baseEnvironment, home: home)
        process.currentDirectoryURL = home
        process.standardInput = FileHandle.nullDevice
    }

    public func start() throws {
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let drained = DispatchGroup()
        attach(stdout, group: drained) { .output($0) }
        attach(stderr, group: drained) { .error($0) }

        let continuation = self.continuation
        let readers = [stdout.fileHandleForReading, stderr.fileHandleForReading]
        process.terminationHandler = { finished in
            DispatchQueue.global().async {
                // A background child may keep the pipes open; don't wait on it forever.
                _ = drained.wait(timeout: .now() + Self.drainGracePeriod)
                readers.forEach { $0.readabilityHandler = nil }
                continuation.yield(.finished(finished.terminationStatus))
                continuation.finish()
            }
        }
        continuation.onTermination = { [weak self] reason in
            if case .cancelled = reason { self?.terminate() }
        }
        do {
            try process.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            continuation.finish()
            throw error
        }
    }

    static let drainGracePeriod: DispatchTimeInterval = .seconds(1)

    /// Sends SIGTERM to the shell and its direct children, then SIGKILL if it lingers.
    public func terminate() {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-TERM", "-P", "\(pid)"]
        try? pkill.run()
        pkill.waitUntilExit()
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.process.isRunning == true { kill(pid, SIGKILL) }
        }
    }

    private func attach(_ pipe: Pipe, group: DispatchGroup, as event: @escaping @Sendable (String) -> ShellEvent) {
        group.enter()
        let continuation = self.continuation
        let done = OnceFlag()
        let decoder = UTF8ChunkDecoder()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                let rest = decoder.flush()
                if !rest.isEmpty { continuation.yield(event(rest)) }
                if done.set() { group.leave() }
                return
            }
            let text = decoder.decode(data)
            if !text.isEmpty { continuation.yield(event(text)) }
        }
    }
}

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var isSet = false

    /// Returns true only for the first caller.
    func set() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isSet { return false }
        isSet = true
        return true
    }
}

/// Decodes a byte stream as UTF-8 without splitting multi-byte characters across chunks.
public final class UTF8ChunkDecoder: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    public init() {}

    public func decode(_ data: Data) -> String {
        lock.withLock {
            pending.append(data)
            let bytes = [UInt8](pending)
            let cut = Self.completePrefixLength(bytes)
            pending = Data(bytes[cut...])
            return String(decoding: bytes[..<cut], as: UTF8.self)
        }
    }

    public func flush() -> String {
        lock.withLock {
            defer { pending = Data() }
            return String(decoding: pending, as: UTF8.self)
        }
    }

    /// Length of the prefix that ends on a complete UTF-8 sequence.
    static func completePrefixLength(_ bytes: [UInt8]) -> Int {
        var index = bytes.count - 1
        var continuation = 0
        while index >= 0 && continuation < 4 {
            let byte = bytes[index]
            if byte & 0xC0 != 0x80 {
                let needed = byte < 0x80 ? 1 : byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : byte >= 0xC0 ? 2 : 1
                return continuation + 1 < needed ? index : bytes.count
            }
            index -= 1
            continuation += 1
        }
        return bytes.count
    }
}
