import AppKit
import CleanerCore
import SwiftUI

struct LargeFilesView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var model = app.largeFiles
        VStack(spacing: 0) {
            DetailHeader(
                title: "Large Files", symbol: "doc.viewfinder",
                subtitle: "Find the biggest files under a folder. Only items inside your home folder can be moved to the Trash."
            ) {
                EmptyView()
            }
            HStack(spacing: 12) {
                Button {
                    chooseFolder()
                } label: {
                    Label(model.root.path.replacingOccurrences(of: app.home.path, with: "~"), systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .frame(maxWidth: 320, alignment: .leading)
                Picker("Larger than", selection: $model.threshold) {
                    ForEach(LargeFilesModel.thresholds, id: \.self) { value in
                        Text(ByteFormat.string(value)).tag(value)
                    }
                }
                .frame(width: 200)
                Spacer()
                if model.isScanning {
                    Text("\(model.visitedCount.formatted()) items checked")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    ProgressView().controlSize(.small)
                    Button("Stop") { model.cancel() }
                } else {
                    Button {
                        model.start()
                    } label: {
                        Label("Find Large Files", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            Divider()
            if model.hasScanned || model.isScanning {
                FileBrowser(
                    items: model.items, emptyMessage: model.isScanning ? "Scanning…" : "No files that large",
                    showsAdvice: true)
            } else {
                ContentUnavailableView(
                    "Find space hogs", systemImage: "doc.viewfinder",
                    description: Text("Pick a folder and size, then press Find Large Files."))
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = app.largeFiles.root
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            app.largeFiles.root = url
        }
    }
}
