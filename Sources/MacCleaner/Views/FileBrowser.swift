import CleanerCore
import SwiftUI

/// Table of items with a Quick Look preview pane and Move-to-Trash confirmation.
struct FileBrowser: View {
    @Environment(AppState.self) private var app
    let items: [FileItem]
    var emptyMessage = "Nothing found."
    var showsAdvice = false

    @State private var selection = Set<URL>()
    @State private var sortOrder = [KeyPathComparator(\FileItem.size, order: .reverse)]
    @State private var pendingTrash: [FileItem] = []

    private var sorted: [FileItem] { items.sorted(using: sortOrder) }
    private var selectedItems: [FileItem] { items.filter { selection.contains($0.url) } }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                table
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                selectionBar
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)

            PreviewPane(items: selectedItems, home: app.home, showsAdvice: showsAdvice)
                .frame(minWidth: 300, idealWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            trashTitle, isPresented: Binding(get: { !pendingTrash.isEmpty }, set: { if !$0 { pendingTrash = [] } }),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let urls = pendingTrash.map(\.url)
                pendingTrash = []
                selection.subtract(urls)
                Task { await app.moveToTrash(urls) }
            }
            Button("Cancel", role: .cancel) { pendingTrash = [] }
        } message: {
            Text(trashMessage)
        }
        .onChange(of: items) { _, newItems in
            selection.formIntersection(newItems.map(\.url))
        }
    }

    private var table: some View {
        Table(sorted, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 6) {
                    Image(nsImage: FileActions.icon(for: item.url))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(item.name).lineLimit(1).truncationMode(.middle)
                }
            }
            .width(min: 180, ideal: 280)
            TableColumn("Size", value: \.size) { item in
                Text(ByteFormat.string(item.size))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
            TableColumn("Modified", value: \.modifiedSortKey) { item in
                Text(item.modified.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100, max: 130)
            TableColumn("Location", value: \.location) { item in
                Text(abbreviated(item.location))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            let chosen = items.filter { urls.contains($0.url) }
            Button("Reveal in Finder") { FileActions.reveal(chosen.map(\.url)) }
            Button("Copy Path") { FileActions.copyPaths(chosen.map(\.url)) }
            Divider()
            Button("Move to Trash…", role: .destructive) { pendingTrash = chosen }
        } primaryAction: { urls in
            urls.first.map(FileActions.open)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(emptyMessage, systemImage: "sparkles")
            }
        }
    }

    private var selectionBar: some View {
        HStack {
            Text("\(items.count) items · \(ByteFormat.string(items.reduce(0) { $0 + $1.size }))")
                .foregroundStyle(.secondary)
            Spacer()
            if !selection.isEmpty {
                Text("\(selectedItems.count) selected · \(ByteFormat.string(selectedItems.reduce(0) { $0 + $1.size }))")
                    .monospacedDigit()
            }
            Button("Select All") { selection = Set(items.map(\.url)) }
                .disabled(items.isEmpty)
            Button(role: .destructive) {
                pendingTrash = selectedItems
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .disabled(selection.isEmpty)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var trashTitle: String {
        "Move \(pendingTrash.count) item\(pendingTrash.count == 1 ? "" : "s") to the Trash?"
    }

    private var trashMessage: String {
        let total = ByteFormat.string(pendingTrash.reduce(0) { $0 + $1.size })
        let names = pendingTrash.prefix(5).map(\.name).joined(separator: "\n")
        let more = pendingTrash.count > 5 ? "\n…and \(pendingTrash.count - 5) more" : ""
        return "\(names)\(more)\n\n\(total) will be freed once you empty the Trash. You can restore items from the Trash until then."
    }

    private func abbreviated(_ path: String) -> String {
        path.replacingOccurrences(of: app.home.path, with: "~")
    }
}
