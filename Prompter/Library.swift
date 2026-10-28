import AppKit
import Observation

/// The scripts: plain text files in ~/Library/Application Support/Prompter/Scripts, newest
/// first. A script's name is its file's.
@MainActor @Observable final class Library {
    static let shared = Library()

    struct Entry: Identifiable, Hashable {
        var id: String { url.lastPathComponent }
        let url: URL
        var title: String
        var modified: Date
    }

    private(set) var scripts: [Entry] = []
    var selection: Entry.ID?          // the one open in the editor
    let folder: URL

    private init() {
        let base = ProcessInfo.processInfo.environment["PROMPTER_SCRIPTS"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Prompter/Scripts", isDirectory: true)
        folder = base
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? Library.sample.write(to: folder.appendingPathComponent("Sample.md"), atomically: true, encoding: .utf8)
        }
        reload()
        // files dropped into the folder in the Finder show up when you come back to the app
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Library.shared.reload() }
        }
    }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                                                 options: [.skipsHiddenFiles])) ?? []
        scripts = urls.filter { ["md", "txt", "markdown"].contains($0.pathExtension.lowercased()) }.map { url in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return Entry(url: url, title: url.deletingPathExtension().lastPathComponent, modified: date)
        }.sorted { $0.modified > $1.modified }
    }

    func text(of e: Entry) -> String { (try? String(contentsOf: e.url, encoding: .utf8)) ?? "" }

    func save(_ text: String, to id: Entry.ID) {
        guard let i = scripts.firstIndex(where: { $0.id == id }) else { return }
        try? text.write(to: scripts[i].url, atomically: true, encoding: .utf8)
        scripts[i].modified = Date()
    }

    @discardableResult
    func create(_ text: String = "", name: String = "Untitled") -> Entry {
        var url = folder.appendingPathComponent("\(name).md")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(name) \(n).md")
            n += 1
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        reload()
        return scripts.first { $0.url == url } ?? Entry(url: url, title: url.deletingPathExtension().lastPathComponent, modified: Date())
    }

    /// A new name: the file's. Returns the entry as it is now.
    @discardableResult
    func rename(_ e: Entry, to name: String) -> Entry {
        let clean = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != e.title else { return e }
        let url = folder.appendingPathComponent(clean).appendingPathExtension(e.url.pathExtension)
        guard !FileManager.default.fileExists(atPath: url.path),
              (try? FileManager.default.moveItem(at: e.url, to: url)) != nil else { return e }
        let wasSelected = selection == e.id
        if Pref.d.string(forKey: Pref.lastScript) == e.id { Pref.d.set(url.lastPathComponent, forKey: Pref.lastScript) }
        Prompter.shared.renamed(from: e.id, to: url.lastPathComponent)
        reload()
        if wasSelected { selection = url.lastPathComponent }
        return scripts.first { $0.url == url } ?? e
    }

    func importFiles(_ urls: [URL]) -> Entry? {
        var last: Entry?
        for u in urls {
            guard let text = try? String(contentsOf: u, encoding: .utf8) else { continue }
            last = create(text, name: u.deletingPathExtension().lastPathComponent)
        }
        return last
    }

    /// To the Trash, not gone.
    func delete(_ e: Entry) {
        try? FileManager.default.trashItem(at: e.url, resultingItemURL: nil)
        reload()
    }

    var lastShown: Entry? {
        let name = Pref.d.string(forKey: Pref.lastScript)
        return scripts.first { $0.id == name }
    }

    func show(_ e: Entry) {
        Pref.d.set(e.id, forKey: Pref.lastScript)
        Prompter.shared.show(text(of: e), id: e.id)
    }

    static let sample = """
    # Opening
    Thanks for making the time. I want to walk you through three things today, and then leave room for questions.

    # Where we are
    Last quarter we shipped the new reader. People open it more often, and they stay longer.
    [pause]
    But the first week is still where we lose most of them.

    # What changes
    So we're cutting the setup down to one screen. You pick what you want to read, and you're in.

    # Close
    That's the plan. What would you push back on?
    """
}
