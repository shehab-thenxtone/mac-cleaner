import CleanerCore
import SwiftUI

struct OverviewView: View {
    @Environment(AppState.self) private var app
    @Binding var selection: SidebarItem?

    private var maxCategorySize: Int64 {
        max(app.categories.compactMap { app.scanState(for: $0).result?.totalSize }.max() ?? 1, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                diskCard
                reclaimable
                quickActions
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { app.refreshDisk() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await app.refreshAll() }
                } label: {
                    if app.isScanningAll {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .help("Refresh disk space and rescan all categories (⌘R)")
                .keyboardShortcut("r")
                .disabled(app.isScanningAll)
            }
        }
    }

    // MARK: Disk

    @ViewBuilder private var diskCard: some View {
        if let disk = app.disk {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ByteFormat.string(disk.available))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("available").font(.title3).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteFormat.string(disk.used)) of \(ByteFormat.string(disk.total)) used")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: disk.usedFraction)
                    .tint(diskTint(disk.usedFraction))
                    .scaleEffect(x: 1, y: 2.2, anchor: .center)
                    .padding(.vertical, 4)
                if disk.usedFraction > 0.9 {
                    Label("Your disk is almost full. macOS needs free space for updates and swap.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding(20)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func diskTint(_ fraction: Double) -> Color {
        fraction > 0.9 ? .red : fraction > 0.75 ? .orange : .accentColor
    }

    // MARK: Reclaimable

    private var reclaimable: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reclaimable space").font(.title2.bold())
                    Text(app.totalFound > 0
                         ? "\(ByteFormat.string(app.totalFound)) found across scanned categories"
                         : "Scan to measure caches, logs and developer junk.")
                        .foregroundStyle(.secondary)
                    if let refreshed = app.lastRefreshed {
                        Text("Updated \(refreshed.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button {
                    Task { await app.scanAll() }
                } label: {
                    if app.isScanningAll {
                        ProgressView().controlSize(.small).padding(.horizontal, 20)
                    } else {
                        Label("Scan Everything", systemImage: "sparkle.magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(app.isScanningAll)
            }

            VStack(spacing: 2) {
                ForEach(app.categories) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: CleanupCategory) -> some View {
        let state = app.scanState(for: category)
        let size = state.result?.totalSize ?? 0
        return Button {
            selection = .category(category.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.symbol)
                    .frame(width: 22)
                    .foregroundStyle(category.risk.tint)
                Text(category.title).frame(width: 200, alignment: .leading)
                GeometryReader { proxy in
                    Capsule()
                        .fill(category.risk.tint.opacity(0.75))
                        .frame(width: max(proxy.size.width * CGFloat(size) / CGFloat(maxCategorySize), size > 0 ? 3 : 0))
                        .frame(maxHeight: .infinity)
                }
                .frame(height: 8)
                Group {
                    if state.isScanning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(state.result == nil ? "—" : ByteFormat.string(size))
                            .monospacedDigit()
                            .foregroundStyle(state.result == nil ? .secondary : .primary)
                    }
                }
                .frame(width: 80, alignment: .trailing)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions").font(.title2.bold())
            HStack(spacing: 12) {
                quickAction("brew-cleanup", symbol: "mug")
                quickAction("docker-prune", symbol: "shippingbox")
                quickAction("npm-cache", symbol: "cube")
                quickAction("simctl-unavailable", symbol: "iphone.slash")
            }
            Text("Items removed from cleanup categories go to the Trash. Space is freed once the Trash is emptied.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func quickAction(_ id: String, symbol: String) -> some View {
        if let command = app.commands.first(where: { $0.id == id }) {
            let available = app.isAvailable(command)
            Button {
                selection = .commands
                app.run(command)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: symbol).font(.title2)
                    Text(command.title).font(.headline).multilineTextAlignment(.leading)
                    Text(available ? command.command : "Not installed")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .padding(14)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!available || app.console.isRunning)
            .opacity(available ? 1 : 0.5)
        }
    }
}

private struct RowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : isHovering ? 0.05 : 0)))
            .onHover { isHovering = $0 }
    }
}
