import SwiftUI

@main
struct PrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        Pref.register()
        if UserDefaults.standard.string(forKey: "SelfTest") == "unit" { exit(SelfTest.unit() ? 0 : 1) }
    }

    var body: some Scene {
        Window("Prompter", id: "library") { LibraryView() }
            .defaultSize(width: 860, height: 560)
            .commands { PrompterCommands() }
        Settings { SettingsView() }
        MenuBarExtra("Prompter", systemImage: "text.quote") { MenuBarMenu() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            SelfTest.quietExitIfTesting()
            Hotkeys.shared.install()
            if UserDefaults.standard.string(forKey: "SelfTest") == "demo" { SelfTest.demo() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// The menu bar's menu: what's needed mid-call without finding the window.
struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    private var prompter = Prompter.shared
    private var library = Library.shared

    var body: some View {
        Button(prompter.isShowing ? "Hide Prompter" : "Show Prompter") { prompter.toggle() }
            .disabled(!prompter.isShowing && library.scripts.isEmpty)
        if prompter.isShowing {
            Button(prompter.isPlaying ? "Pause" : "Play") { prompter.playPause() }
            Button("Back to Start") { prompter.restart() }
            if !prompter.cues.isEmpty {
                Menu("Cues") {
                    ForEach(prompter.cues) { c in
                        Toggle(c.title, isOn: Binding(get: { prompter.currentCue == c.id }, set: { _ in prompter.jump(toCue: c.id) }))
                    }
                }
            }
        }
        Picker("Mode", selection: Binding(get: { prompter.mode }, set: { prompter.setMode($0) })) {
            ForEach(Mode.allCases) { Text($0.label).tag($0) }
        }
        if let problem = prompter.problem { Text(problem) }
        Divider()
        Menu("Scripts") {
            ForEach(library.scripts) { e in Button(e.title) { library.show(e) } }
        }
        Button("Open Scripts…") {
            openWindow(id: "library")
            NSApp.activate()
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Prompter") { NSApp.terminate(nil) }
    }
}

struct PrompterCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Script") { Library.shared.selection = Library.shared.create().id }
                .keyboardShortcut("n")
        }
        CommandMenu("Prompter") {
            let p = Prompter.shared
            Button(p.isShowing ? "Hide Prompter" : "Show Prompter") { p.toggle() }
                .keyboardShortcut("p", modifiers: [.control, .option])
            Button(p.isPlaying ? "Pause" : "Play") { p.playPause() }
                .keyboardShortcut(.space, modifiers: [.control, .option])
                .disabled(!p.isShowing)
            Button("Back to Start") { p.restart() }
                .keyboardShortcut("r", modifiers: [.control, .option])
                .disabled(!p.isShowing)
            Divider()
            Button("Next Cue") { p.nextCue() }
                .keyboardShortcut("]", modifiers: [.control, .option])
                .disabled(!p.isShowing || p.cues.isEmpty)
            Button("Previous Cue") { p.previousCue() }
                .keyboardShortcut("[", modifiers: [.control, .option])
                .disabled(!p.isShowing || p.cues.isEmpty)
            Divider()
            Button("Faster") { p.faster() }
                .keyboardShortcut("=", modifiers: [.control, .option])
            Button("Slower") { p.slower() }
                .keyboardShortcut("-", modifiers: [.control, .option])
            Button("Next Mode") { p.cycleMode() }
                .keyboardShortcut("m", modifiers: [.control, .option])
        }
    }
}
