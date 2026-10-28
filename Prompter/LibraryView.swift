import SwiftUI

/// The scripts window: the list on the left, the selected script's text on the right.
struct LibraryView: View {
    private var library = Library.shared
    private var prompter = Prompter.shared
    @Environment(\.openSettings) private var openSettings
    @State private var text = ""
    @State private var loadedID: Library.Entry.ID?
    @State private var savedText = ""      // what's on disk, so opening a script doesn't count as an edit
    @State private var pendingSave: Task<Void, Never>?
    @State private var renaming: Library.Entry?
    @State private var newName = ""

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            List(selection: $library.selection) {
                ForEach(library.scripts) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).lineLimit(1)
                        Text(e.modified, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(e.id)
                    .contextMenu {
                        Button("Show in Prompter") { flush(); library.show(e) }
                        Button("Rename…") { startRename(e) }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([e.url]) }
                        Divider()
                        Button("Move to Trash", role: .destructive) { trash(e) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .toolbar {
                ToolbarItem {
                    Button { newScript() } label: { Label("New Script", systemImage: "square.and.pencil") }
                }
            }
        } detail: {
            if loadedID != nil {
                VStack(spacing: 0) {
                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    Divider()
                    Text(stats).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                ContentUnavailableView("No Script", systemImage: "text.quote")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: Binding(get: { prompter.mode }, set: { prompter.setMode($0) })) {
                    ForEach(Mode.allCases) { m in Label(m.label, systemImage: m.symbol).tag(m) }
                }
                .pickerStyle(.segmented)
                .help("Follow: tracks your words · Voice: scrolls while you talk · Steady: fixed speed")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if prompter.isShowing && prompter.scriptID == loadedID { prompter.hide() } else { start() }
                } label: {
                    if prompter.isShowing && prompter.scriptID == loadedID {
                        Label("Hide", systemImage: "stop.fill")
                    } else {
                        Label("Start", systemImage: "play.fill")
                    }
                }
                .disabled(loadedID == nil)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .navigationTitle(current?.title ?? "Prompter")
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let e = renaming { flush(); library.rename(e, to: newName) }
                renaming = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .onChange(of: library.selection, initial: true) { _, id in open(id) }
        .onChange(of: text) { _, t in textChanged(t) }
        .dropDestination(for: URL.self) { urls, _ in
            guard let e = library.importFiles(urls) else { return false }
            library.selection = e.id
            return true
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "SelfTestSettings") { openSettings() }
            if library.selection == nil { library.selection = (library.lastShown ?? library.scripts.first)?.id }
        }
        .onDisappear { flush() }
    }

    private var current: Library.Entry? { library.scripts.first { $0.id == loadedID } }

    private var stats: String {
        let s = Script(text)
        let n = s.words.count
        let secs = Int((Double(n) / 150 * 60).rounded())     // about 150 words a minute
        var parts = ["\(n) words", String(format: "%d:%02d", secs / 60, secs % 60)]
        if !s.cues.isEmpty { parts.append("\(s.cues.count) cues") }
        return parts.joined(separator: " · ")
    }

    private func open(_ id: Library.Entry.ID?) {
        flush()
        guard let id, let e = library.scripts.first(where: { $0.id == id }) else { loadedID = nil; return }
        loadedID = id
        savedText = library.text(of: e)
        text = savedText
    }

    private func textChanged(_ t: String) {
        guard let id = loadedID, let e = current, t != savedText else { return }
        if prompter.isShowing && prompter.scriptID == e.id { prompter.update(t) }
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            library.save(t, to: id)
            savedText = t
        }
    }

    private func flush() {
        guard let id = loadedID, let pending = pendingSave else { return }
        pending.cancel()
        pendingSave = nil
        library.save(text, to: id)
        savedText = text
    }

    private func start() {
        flush()
        if let e = current { library.show(e) }
    }

    private func newScript() {
        flush()
        let e = library.create()
        library.selection = e.id
        startRename(e)
    }

    private func startRename(_ e: Library.Entry) {
        newName = e.title
        renaming = e
    }

    private func trash(_ e: Library.Entry) {
        if e.id == loadedID { pendingSave?.cancel(); pendingSave = nil; loadedID = nil }
        library.delete(e)
        if library.selection == e.id { library.selection = library.scripts.first?.id }
    }
}
