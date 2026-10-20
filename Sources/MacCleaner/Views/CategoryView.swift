import CleanerCore
import SwiftUI

struct CategoryView: View {
    @Environment(AppState.self) private var app
    let category: CleanupCategory

    private var state: CategoryScanState { app.scanState(for: category) }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: category.title, symbol: category.symbol, subtitle: category.summary) {
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        RiskBadge(risk: category.risk)
                        if let total = state.result?.totalSize {
                            Text(ByteFormat.string(total)).font(.title3.bold()).monospacedDigit()
                        }
                    }
                    HStack {
                        Button("Open Folder") {
                            FileActions.reveal(category.roots(home: app.home).filter {
                                FileManager.default.fileExists(atPath: $0.path)
                            })
                        }
                        Button {
                            Task { await app.scan(category) }
                        } label: {
                            Label(state.result == nil ? "Scan" : "Rescan", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut("r")
                        .disabled(state.isScanning)
                    }
                }
            }
            if let unreadable = state.result?.unreadable, !unreadable.isEmpty {
                unreadableNotice(unreadable)
            }
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if state.result == nil { await app.scan(category) }
        }
    }

    @ViewBuilder private var content: some View {
        if state.isScanning && state.result == nil {
            ProgressView("Measuring \(category.title)…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            FileBrowser(items: state.result?.items ?? [], emptyMessage: "\(category.title) is already clean")
                .overlay(alignment: .top) {
                    if state.isScanning {
                        ProgressView().controlSize(.small).padding(6)
                    }
                }
        }
    }

    private func unreadableNotice(_ paths: [String]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").foregroundStyle(.orange)
            Text("Some folders couldn't be read. Grant Full Disk Access in System Settings › Privacy & Security to include them.")
                .font(.callout)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08))
        .help(paths.joined(separator: "\n"))
    }
}
