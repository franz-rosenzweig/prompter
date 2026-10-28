import SwiftUI
import Speech

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Prompter", systemImage: "rectangle.topthird.inset.filled") { LookSettings() }
            Tab("Voice", systemImage: "waveform") { VoiceSettings() }
            Tab("Shortcuts", systemImage: "command") { ShortcutSettings() }
        }
        .frame(width: 480, height: 560)
    }
}

private struct LookSettings: View {
    @AppStorage(Pref.placement) private var placement = Placement.notch.rawValue
    @AppStorage(Pref.display) private var display = ""
    @AppStorage(Pref.width) private var width = 520.0
    @AppStorage(Pref.height) private var height = 150.0
    @AppStorage(Pref.fontSize) private var fontSize = 24.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.2
    @AppStorage(Pref.textColor) private var textColor = "#FFFFFF"
    @AppStorage(Pref.alignment) private var alignment = "left"
    @AppStorage(Pref.mirror) private var mirror = false

    var body: some View {
        Form {
            Section {
                Picker("Placement", selection: $placement) {
                    ForEach(Placement.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Display", selection: $display) {
                    Text("Automatic").tag("")
                    ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                }
                if placement == Placement.notch.rawValue {
                    SliderRow(title: "Width", value: $width, range: 280...1000, step: 10, unit: "pt")
                    SliderRow(title: "Height", value: $height, range: 60...420, step: 5, unit: "pt")
                }
            }
            Section {
                SliderRow(title: "Text size", value: $fontSize, range: 14...64, step: 1, unit: "pt")
                SliderRow(title: "Line spacing", value: $lineSpacing, range: 1.0...1.8, step: 0.05, unit: "×", digits: 2)
                ColorPicker("Text color", selection: Binding(
                    get: { Color(nsColor: NSColor(hex: textColor) ?? .white) },
                    set: { textColor = NSColor($0).hex }), supportsOpacity: false)
                Picker("Alignment", selection: $alignment) {
                    Text("Left").tag("left")
                    Text("Center").tag("center")
                }
                .pickerStyle(.segmented)
                Toggle("Mirror", isOn: $mirror)
            }
        }
        .formStyle(.grouped)
    }
}

private struct VoiceSettings: View {
    @AppStorage(Pref.mode) private var mode = Mode.follow.rawValue
    @AppStorage(Pref.speed) private var speed = 12.0
    @AppStorage(Pref.sensitivity) private var sensitivity = 0.5
    @AppStorage(Pref.hoverPauses) private var hoverPauses = true
    @AppStorage(Pref.language) private var language = ""

    private let languages: [(id: String, name: String)] = SFSpeechRecognizer.supportedLocales()
        .map { ($0.identifier, Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
        .sorted { $0.name < $1.name }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Follow") { Text("tracks your words").foregroundStyle(.secondary) }
                LabeledContent("Voice") { Text("scrolls while you talk").foregroundStyle(.secondary) }
                LabeledContent("Steady") { Text("fixed speed").foregroundStyle(.secondary) }
            }
            Section {
                SliderRow(title: "Speed", value: $speed, range: 4...120, step: 1, unit: "pt/s")
                SliderRow(title: "Mic sensitivity", value: $sensitivity, range: 0...1, step: 0.05, unit: "", digits: 2)
                Picker("Language", selection: $language) {
                    Text("Automatic").tag("")
                    ForEach(languages, id: \.id) { Text($0.name).tag($0.id) }
                }
                Toggle("Pause on hover", isOn: $hoverPauses)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            Section {
                ForEach(Hotkeys.shared.all, id: \.id) { k in
                    LabeledContent(k.name) { Text(k.label).monospaced() }
                }
            }
            Section {
                LabeledContent("Play / pause") { Text("Click").foregroundStyle(.secondary) }
                LabeledContent("Pause") { Text("Hover").foregroundStyle(.secondary) }
                LabeledContent("Move") { Text("Scroll").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var digits = 0

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: step)
                Text(String(format: "%.\(digits)f", value) + (unit.isEmpty ? "" : " \(unit)"))
                    .monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }
}
