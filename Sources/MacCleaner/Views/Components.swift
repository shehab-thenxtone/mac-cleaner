import AppKit
import CleanerCore
import SwiftUI

struct RiskBadge: View {
    let risk: RiskLevel

    var body: some View {
        Text(risk.label.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(risk.tint)
            .background(risk.tint.opacity(0.15), in: Capsule())
            .help(risk.helpText)
    }
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe: .green
        case .review: .orange
        case .caution: .red
        }
    }

    var helpText: String {
        switch self {
        case .safe: "Regenerated automatically; safe to remove."
        case .review: "Usually safe, but check before removing."
        case .caution: "May remove data you cannot get back."
        }
    }
}

enum FileActions {
    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func copyPaths(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Header shared by detail screens.
struct DetailHeader<Accessory: View>: View {
    let title: String
    let symbol: String
    let subtitle: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                Text(subtitle).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 16)
            accessory
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
