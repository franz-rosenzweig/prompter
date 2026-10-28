import AppKit
import Carbon.HIToolbox

/// Shortcuts that work from any app (Carbon hot keys: no Accessibility permission needed).
/// ⌃⌥P shows and hides the prompter; the rest only count while it shows.
@MainActor final class Hotkeys {
    static let shared = Hotkeys()

    struct Key {
        let id: UInt32
        let code: Int
        let label: String      // as the menus and Settings show it
        let name: String
        let action: @MainActor () -> Void
    }

    static let modifiers = UInt32(controlKey | optionKey)

    let toggle = Key(id: 1, code: kVK_ANSI_P, label: "⌃⌥P", name: "Show / hide") { Prompter.shared.toggle() }
    let playback: [Key] = [
        Key(id: 2, code: kVK_Space, label: "⌃⌥Space", name: "Play / pause") { Prompter.shared.playPause() },
        Key(id: 3, code: kVK_ANSI_Equal, label: "⌃⌥=", name: "Faster") { Prompter.shared.faster() },
        Key(id: 4, code: kVK_ANSI_Minus, label: "⌃⌥−", name: "Slower") { Prompter.shared.slower() },
        Key(id: 5, code: kVK_ANSI_RightBracket, label: "⌃⌥]", name: "Next cue") { Prompter.shared.nextCue() },
        Key(id: 6, code: kVK_ANSI_LeftBracket, label: "⌃⌥[", name: "Previous cue") { Prompter.shared.previousCue() },
        Key(id: 7, code: kVK_ANSI_R, label: "⌃⌥R", name: "Back to start") { Prompter.shared.restart() },
        Key(id: 8, code: kVK_ANSI_M, label: "⌃⌥M", name: "Next mode") { Prompter.shared.cycleMode() },
    ]
    var all: [Key] { [toggle] + playback }

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    func install() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { MainActor.assumeIsolated { Hotkeys.shared.fire(id) } }
            return noErr
        }, 1, &spec, nil, &handler)
        register(toggle)
    }

    func setPlayback(_ on: Bool) {
        for k in playback {
            if on { register(k) } else if let r = refs.removeValue(forKey: k.id) { UnregisterEventHotKey(r) }
        }
    }

    private func register(_ k: Key) {
        guard refs[k.id] == nil else { return }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(k.code), Hotkeys.modifiers, EventHotKeyID(signature: 0x5052_4D54, id: k.id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs[k.id] = ref }
    }

    private func fire(_ id: UInt32) { all.first { $0.id == id }?.action() }
}
