import Foundation
import Testing
@testable import CleanerCore

struct ShellEnvironmentTests {
    let home = URL(fileURLWithPath: "/Users/tester")

    @Test func augmentedPathKeepsExistingFirstAndDedupes() {
        let path = ShellEnvironment.augmentedPath(current: "/custom/bin:/usr/bin", home: home)
        let parts = path.split(separator: ":").map(String.init)
        #expect(parts.first == "/custom/bin")
        #expect(parts.contains("/opt/homebrew/bin"))
        #expect(parts.contains("/Users/tester/.rd/bin"))
        #expect(parts.filter { $0 == "/usr/bin" }.count == 1)
    }

    @Test func appleScriptEscaping() {
        #expect(ShellEnvironment.appleScriptEscaped(#"echo "hi" \ there"#) == #"echo \"hi\" \\ there"#)
    }

    @Test func adminInvocationUsesOsascript() {
        let invocation = ShellInvocation(command: "purge", asAdmin: true)
        #expect(invocation.executable == "/usr/bin/osascript")
        #expect(invocation.arguments.last == #"do shell script "purge" with administrator privileges"#)
    }

    @Test func regularInvocationUsesLoginZsh() {
        #expect(ShellInvocation(command: "ls", asAdmin: false).arguments == ["-l", "-c", "ls"])
    }

    @Test func toolLookup() {
        #expect(ShellEnvironment.isToolAvailable("ls", searchPath: "/nope:/bin"))
        #expect(!ShellEnvironment.isToolAvailable("definitely-not-a-tool-xyz", searchPath: "/bin:/usr/bin"))
    }
}

struct ShellProcessTests {
    @Test func streamsStdoutStderrAndExitCode() async throws {
        let process = ShellProcess(command: "echo hello; echo oops 1>&2; exit 3")
        try process.start()

        var out = "", err = ""
        var exit: Int32?
        for await event in process.events {
            switch event {
            case .output(let text): out += text
            case .error(let text): err += text
            case .finished(let code): exit = code
            }
        }
        #expect(out.contains("hello"))
        #expect(err.contains("oops"))
        #expect(exit == 3)
    }

    @Test func terminateStopsLongRunningCommand() async throws {
        let process = ShellProcess(command: "sleep 30")
        try process.start()
        process.terminate()

        var exit: Int32?
        for await event in process.events {
            if case .finished(let code) = event { exit = code }
        }
        #expect(exit != 0)
    }
}

struct CatalogTests {
    @Test func commandIdsAreUnique() {
        let ids = CleanupCommand.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func adminCommandsDoNotEmbedSudo() {
        #expect(!CleanupCommand.catalog.contains { $0.command.contains("sudo") })
    }

    @Test func everyGroupHasCommands() {
        for group in CommandGroup.allCases {
            #expect(CleanupCommand.catalog.contains { $0.group == group })
        }
    }

    @Test func categoryIdsAreUniqueAndPathsRelative() {
        let ids = CleanupCategory.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
        let paths = CleanupCategory.catalog.flatMap { $0.relativePaths }
        #expect(!paths.contains { $0.hasPrefix("/") })
    }
}

struct HardeningShellTests {
    @Test func decoderHoldsSplitMultibyteCharacter() {
        let decoder = UTF8ChunkDecoder()
        let bytes = Array("héllo ✓".utf8)
        let split = bytes.firstIndex(of: 0xC3)! + 1  // cut inside "é"
        let first = decoder.decode(Data(bytes[..<split]))
        let second = decoder.decode(Data(bytes[split...]))
        #expect(first + second + decoder.flush() == "héllo ✓")
        #expect(!(first + second).contains("\u{FFFD}"))
    }

    @Test func finishesWhenBackgroundChildHoldsPipe() async throws {
        let process = ShellProcess(command: "sleep 20 & echo started")
        try process.start()
        let start = Date()
        var exit: Int32?
        for await event in process.events {
            if case .finished(let code) = event { exit = code }
        }
        #expect(exit == 0)
        #expect(Date().timeIntervalSince(start) < 5)
    }
}
