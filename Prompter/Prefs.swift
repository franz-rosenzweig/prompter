import AppKit
import SwiftUI

/// Every setting, kept in UserDefaults. Settings binds to these keys with @AppStorage, and
/// the prompter reads them live: it watches UserDefaults and re-lays itself out.
enum Pref {
    static let fontSize = "fontSize"            // points
    static let textColor = "textColor"          // "#RRGGBB"
    static let width = "width"                  // the prompter's width, points
    static let height = "height"                // the text area's height, points
    static let lineSpacing = "lineSpacing"      // a multiple of the line height
    static let alignment = "alignment"          // "left" or "center"
    static let mirror = "mirror"                // flipped left to right, for a beam-splitter rig
    static let speed = "speed"                  // points a second, in Steady and Voice
    static let mode = "mode"                    // Mode.rawValue
    static let sensitivity = "sensitivity"      // 0...1: how quiet still counts as talking
    static let hoverPauses = "hoverPauses"
    static let placement = "placement"          // Placement.rawValue
    static let display = "display"              // a screen's localizedName, or "" for the notch's
    static let floatingFrame = "floatingFrame"  // NSStringFromRect, where the floating window was left
    static let language = "language"            // the recognizer's locale, or "" for this Mac's
    static let lastScript = "lastScript"        // the file name of the script last shown

    static func register() {
        UserDefaults.standard.register(defaults: [
            fontSize: 24.0, textColor: "#FFFFFF", width: 520.0, height: 150.0, lineSpacing: 1.2,
            alignment: "left", mirror: false, speed: 12.0, mode: Mode.follow.rawValue,
            sensitivity: 0.5, hoverPauses: true, placement: Placement.notch.rawValue, display: "",
            language: "",
        ])
    }

    static var d: UserDefaults { .standard }
}

enum Mode: String, CaseIterable, Identifiable {
    case follow, voice, steady
    var id: String { rawValue }
    var label: String {
        switch self {
        case .follow: "Follow"
        case .voice: "Voice"
        case .steady: "Steady"
        }
    }
    var symbol: String {
        switch self {
        case .follow: "text.quote"
        case .voice: "mic"
        case .steady: "metronome"
        }
    }
    var next: Mode { Mode.allCases[(Mode.allCases.firstIndex(of: self)! + 1) % Mode.allCases.count] }
}

enum Placement: String, CaseIterable, Identifiable {
    case notch, floating
    var id: String { rawValue }
    var label: String { self == .notch ? "Top of screen" : "Floating" }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    var hex: String {
        guard let c = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSScreen {
    /// The screen the prompter goes on: the one picked in Settings, else the one with a
    /// notch (the camera is above it), else the main one.
    static var forPrompter: NSScreen? {
        let name = Pref.d.string(forKey: Pref.display) ?? ""
        if !name.isEmpty, let s = screens.first(where: { $0.localizedName == name }) { return s }
        return screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? main ?? screens.first
    }

    /// The camera housing's size, or zero on a screen without one.
    var notchSize: NSSize {
        // a test copy can pretend, for pictures taken on a screen without one: -PrompterFakeNotch 200x32
        if ProcessInfo.processInfo.environment["PROMPTER_TEST"] != nil,
           let fake = UserDefaults.standard.string(forKey: "PrompterFakeNotch")?.split(separator: "x").compactMap({ Double($0) }),
           fake.count == 2 {
            return NSSize(width: fake[0], height: fake[1])
        }
        guard safeAreaInsets.top > 0, let l = auxiliaryTopLeftArea, let r = auxiliaryTopRightArea else { return .zero }
        return NSSize(width: frame.width - l.width - r.width, height: safeAreaInsets.top)
    }
}
