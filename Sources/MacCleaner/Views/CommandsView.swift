import CleanerCore
import SwiftUI

private struct PendingRun: Identifiable {
    let id = UUID()
    let title: String
    let command: String
    let risk: RiskLevel
    let run: @MainActor () -> Void
}

struct CommandsView: View {
    @Environment(AppState.self) private var app
    @State private var customCommand = ""
    @State private var pending: PendingRun?

    var body: some View {
        VSplitView {
            commandList
                .frame(minHeight: 260)
            ConsoleView(console: app.console)
                .frame(minHeight: 170, idealHeight: 260)
        }
        .confirmationDialog(
            pending.map { "Run “\($0.title)”?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { run in
            Button("Run", role: run.risk == .caution ? .destructive : nil) {
                run.run()
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { run in
            Text("This will execute:\n\n\(run.command)")
        }
    }

    private var commandList: some View {
        List {
            ForEach(CommandGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(app.commands.filter { $0.group == group }) { command in
                        CommandRow(
                            command: command,
                            isAvailable: app.isAvailable(command),
                            isBusy: app.console.isRunning
                        ) {
                            request(command)
                        }
                    }
                }
            }
            Section("Custom Command") {
                HStack {
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    TextField("e.g. docker volume prune -f", text: $customCommand)
                        .textFieldStyle(.plain)
                        .font(.body.monospaced())
                        .onSubmit(requestCustom)
                    Button("Run", action: requestCustom)
                        .disabled(customCommand.trimmingCharacters(in: .whitespaces).isEmpty || app.console.isRunning)
                }
                Text("Runs in a login zsh shell from your home folder. Output appears in the console below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func request(_ command: CleanupCommand) {
        guard command.risk != .safe else {
            app.run(command)
            return
        }
        pending = PendingRun(title: command.title, command: command.command, risk: command.risk) {
            app.run(command)
        }
    }

    private func requestCustom() {
        let text = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !app.console.isRunning else { return }
        pending = PendingRun(title: "Custom command", command: text, risk: .caution) {
            app.runCustom(text)
        }
    }
}

private struct CommandRow: View {
    let command: CleanupCommand
    let isAvailable: Bool
    let isBusy: Bool
    let onRun: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(command.title).font(.headline)
                    RiskBadge(risk: command.risk)
                    if command.requiresAdmin {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .help("macOS will ask for your administrator password")
                    }
                }
                Text(command.summary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(command.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Spacer()
            if isAvailable {
                Button("Run", action: onRun)
                    .disabled(isBusy)
            } else {
                Text("\(command.requiredTool ?? "tool") not installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isAvailable ? 1 : 0.55)
    }
}

struct ConsoleView: View {
    let console: ConsoleModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                Text(console.title).font(.headline)
                if console.isRunning {
                    ProgressView().controlSize(.small)
                } else if let code = console.exitCode {
                    Label(code == 0 ? "Succeeded" : "Exit \(code)",
                          systemImage: code == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(code == 0 ? .green : .red)
                        .font(.callout)
                }
                Spacer()
                Button("Stop") { console.stop() }
                    .disabled(!console.isRunning)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(console.text, forType: .string)
                }
                .disabled(console.text.isEmpty)
                Button("Clear") { console.clear() }
                    .disabled(console.isRunning || console.text.isEmpty)
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(console.text.isEmpty ? "Command output will appear here." : console.text)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(console.text.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: console.text) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}
