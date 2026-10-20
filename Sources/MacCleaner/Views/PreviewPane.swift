import CleanerCore
import Quartz
import SwiftUI

struct PreviewPane: View {
    let items: [FileItem]
    var home: URL = FileManager.default.homeDirectoryForCurrentUser
    var showsAdvice = false

    var body: some View {
        if let item = items.first {
            VStack(alignment: .leading, spacing: 0) {
                QuickLookPreview(url: item.url)
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                    .background(.background.secondary)
                Divider()
                details(for: item)
                    .padding(14)
            }
        } else {
            ContentUnavailableView(
                "No Selection", systemImage: "eye",
                description: Text("Select an item to preview it with Quick Look."))
        }
    }

    private func details(for item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.count > 1 {
                Text("Previewing 1 of \(items.count) selected items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.name).font(.headline).lineLimit(2).textSelection(.enabled)
            if showsAdvice {
                AdviceCallout(advice: advice(for: item))
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Size", ByteFormat.string(item.size))
                row("Kind", kind(of: item))
                row("Modified", item.modified?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                row("Path", item.url.path)
            }
            .font(.callout)
            HStack {
                Button("Open") { FileActions.open(item.url) }
                Button("Reveal in Finder") { FileActions.reveal(items.map(\.url)) }
                Button("Copy Path") { FileActions.copyPaths(items.map(\.url)) }
            }
            .controlSize(.small)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
        }
    }

    private func advice(for item: FileItem) -> SafetyAdvice {
        let opened = (try? item.url.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
        return SafetyAdvisor.advise(for: item.url, home: home, lastOpened: opened)
    }

    private func kind(of item: FileItem) -> String {
        let values = try? item.url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
        return values?.localizedTypeDescription ?? (item.isDirectory ? "Folder" : "File")
    }
}

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.shouldCloseWithWindow = false
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? NSURL)?.absoluteURL != url.absoluteURL {
            view.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
        view.close()
    }
}

/// "Is this safe to delete?" tip shown for a selected file.
struct AdviceCallout: View {
    let advice: SafetyAdvice

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(advice.verdict.label).font(.callout.weight(.semibold)).foregroundStyle(tint)
                Text(advice.reason).font(.callout).fixedSize(horizontal: false, vertical: true)
                if let note = advice.note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.35)))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch advice.verdict {
        case .safe: .green
        case .review: .orange
        case .keep: .red
        }
    }

    private var symbol: String {
        switch advice.verdict {
        case .safe: "checkmark.shield.fill"
        case .review: "exclamationmark.triangle.fill"
        case .keep: "hand.raised.fill"
        }
    }
}
