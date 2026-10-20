import CleanerCore
import Foundation
import Observation

@MainActor
@Observable
final class ConsoleModel {
    private static let maxCharacters = 200_000

    private(set) var text = ""
    private(set) var title = "Console"
    private(set) var isRunning = false
    private(set) var exitCode: Int32?

    private let home: URL
    private var process: ShellProcess?
    private var length = 0

    init(home: URL) {
        self.home = home
    }

    func run(title: String, command: String, asAdmin: Bool, onFinish: @escaping @MainActor () -> Void = {}) {
        guard !isRunning else { return }
        self.title = title
        exitCode = nil
        append("\n$ \(command)\(asAdmin ? "   (as administrator)" : "")\n")

        let process = ShellProcess(command: command, asAdmin: asAdmin, home: home)
        do {
            try process.start()
        } catch {
            append("Failed to start: \(error.localizedDescription)\n")
            return
        }
        self.process = process
        isRunning = true

        Task { [weak self] in
            for await event in process.events {
                self?.handle(event)
            }
            self?.finish()
            onFinish()
        }
    }

    func stop() {
        guard let process else { return }
        process.terminate()
        append("\n[stop requested]\n")
    }

    func clear() {
        text = ""
        length = 0
        exitCode = nil
    }

    private func handle(_ event: ShellEvent) {
        switch event {
        case .output(let chunk), .error(let chunk):
            append(chunk)
        case .finished(let code):
            exitCode = code
            append("\n[exit \(code)]\n")
        }
    }

    private func finish() {
        isRunning = false
        process = nil
    }

    private func append(_ chunk: String) {
        text.append(chunk)
        length += chunk.count
        if length > Self.maxCharacters {
            text = String(text.suffix(Self.maxCharacters * 3 / 4))
            length = text.count
        }
    }
}
