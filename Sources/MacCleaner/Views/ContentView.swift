import CleanerCore
import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case largeFiles
    case commands
    case category(String)
}

struct ContentView: View {
    @Environment(AppState.self) private var app
    @State private var selection: SidebarItem?
    @State private var backStack: [SidebarItem] = []
    @State private var forwardStack: [SidebarItem] = []
    @State private var isTraversingHistory = false

    init(initialSelection: SidebarItem = .overview) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            List(selection: $selection) {
                Section("Dashboard") {
                    Label("Overview", systemImage: "gauge.with.dots.needle.33percent").tag(SidebarItem.overview)
                    Label("Large Files", systemImage: "doc.viewfinder").tag(SidebarItem.largeFiles)
                    Label("Commands", systemImage: "terminal")
                        .badge(app.console.isRunning ? Text("running") : nil)
                        .tag(SidebarItem.commands)
                }
                Section("Cleanup") {
                    ForEach(app.categories) { category in
                        Label(category.title, systemImage: category.symbol)
                            .badge(sizeBadge(for: category))
                            .tag(SidebarItem.category(category.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle(title(for: selection))
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button(action: goBack) {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .help("Back")
                        .disabled(!canGoBack)
                        .keyboardShortcut("[", modifiers: .command)
                        Button(action: goForward) {
                            Label("Forward", systemImage: "chevron.right")
                        }
                        .help("Forward")
                        .disabled(forwardStack.isEmpty)
                        .keyboardShortcut("]", modifiers: .command)
                    }
                }
        }
        .onChange(of: selection) { old, _ in
            guard !isTraversingHistory else {
                isTraversingHistory = false
                return
            }
            if let old { backStack.append(old) }
            forwardStack = []
        }
        .alert(
            app.alert?.title ?? "",
            isPresented: Binding(get: { app.alert != nil }, set: { if !$0 { app.alert = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.alert?.message ?? "")
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .overview, nil:
            OverviewView(selection: $selection)
        case .largeFiles:
            LargeFilesView()
        case .commands:
            CommandsView()
        case .category(let id):
            if let category = app.categories.first(where: { $0.id == id }) {
                CategoryView(category: category).id(id)
            }
        }
    }

    // MARK: History

    private var current: SidebarItem { selection ?? .overview }

    /// Back is always available off the Overview, falling back to it when history is empty.
    private var canGoBack: Bool { !backStack.isEmpty || current != .overview }

    private func goBack() {
        let target = backStack.popLast() ?? .overview
        guard target != current else { return }
        forwardStack.append(current)
        navigate(to: target)
    }

    private func goForward() {
        guard let target = forwardStack.popLast() else { return }
        backStack.append(current)
        navigate(to: target)
    }

    private func navigate(to item: SidebarItem) {
        isTraversingHistory = true
        selection = item
    }

    private func title(for item: SidebarItem?) -> String {
        switch item ?? .overview {
        case .overview: "Overview"
        case .largeFiles: "Large Files"
        case .commands: "Commands"
        case .category(let id): app.categories.first { $0.id == id }?.title ?? "Mac Cleaner"
        }
    }

    private func sizeBadge(for category: CleanupCategory) -> Text? {
        let state = app.scanState(for: category)
        if state.isScanning { return Text("…") }
        guard let total = state.result?.totalSize, total > 0 else { return nil }
        return Text(ByteFormat.string(total))
    }
}
