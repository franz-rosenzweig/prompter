import AppKit

/// Checks run by selftest.sh, from a test copy of the app (its own bundle id and settings).
///   -SelfTest unit   the parser and Follow's matcher; prints PASS/FAIL, exits
///   -SelfTest demo   shows the sample in the prompter and prints its window, for a picture
@MainActor enum SelfTest {
    static func quietExitIfTesting() {
        guard ProcessInfo.processInfo.environment["PROMPTER_TEST"] != nil else { return }
        // pictures in either look, whatever the Mac is set to: -PrompterAppearance light|dark
        switch UserDefaults.standard.string(forKey: "PrompterAppearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        // a test copy that fails exits quietly, so no crash dialog lands on the screen
        NSSetUncaughtExceptionHandler { e in
            FileHandle.standardError.write("EXCEPTION \(e.name.rawValue): \(e.reason ?? "")\n".data(using: .utf8)!)
            _exit(70)
        }
    }

    static func demo() {
        for w in NSApp.windows where !(w is PrompterPanel) { w.orderOut(nil) }
        let p = Prompter.shared
        p.show(Library.sample, id: "Sample.md")
        let d = UserDefaults.standard
        if d.object(forKey: "PrompterCursor") != nil { p.pretendHeard(through: d.integer(forKey: "PrompterCursor")) }
        if d.bool(forKey: "PrompterPlay") && !p.isPlaying { p.playPause() }
        if d.bool(forKey: "PrompterHearing") { p.pretendHearing() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            for w in NSApp.windows where !(w is PrompterPanel) { w.orderOut(nil) }
            let id = CGWindowID(p.windowNumber)
            let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
            let sharing = info?[kCGWindowSharingState as String] as? Int ?? -1
            print("WINDOW \(p.windowNumber) frame=\(NSStringFromRect(p.panelFrame)) sharing=\(sharing) screen=\(NSScreen.forPrompter?.localizedName ?? "?")")
            fflush(stdout)
        }
    }

    // MARK: Unit

    private static var failures = 0

    private static func check(_ ok: Bool, _ what: String) {
        print(ok ? "PASS \(what)" : "FAIL \(what)")
        if !ok { failures += 1 }
    }

    static func unit() -> Bool {
        let s = Script(Library.sample)
        check(s.cues.map(\.title) == ["Opening", "Where we are", "What changes", "Close"], "cues: \(s.cues.map(\.title))")
        check(s.words.first?.key == "thanks", "first spoken word is the first after the heading")
        check(!s.words.contains { $0.key == "pause" }, "a [direction] isn't spoken")
        check(!s.words.contains { $0.key == "opening" }, "a heading isn't spoken")
        check(s.words.contains { $0.key == "were" }, "apostrophes dropped: we're → were")
        let text = s.text.string as NSString
        check(s.words.allSatisfy { Script.normalize(text.substring(with: $0.range)) == $0.key }, "word ranges point at their words")
        check(s.word(atOrAfter: 0) == 0 && s.word(atOrAfter: text.length) == s.words.count, "word(atOrAfter:) at the ends")

        check(Matcher.same("presentation", "presentations"), "same: plural")
        check(Matcher.same("quarter", "quater"), "same: one letter off")
        check(!Matcher.same("the", "they"), "not same: short words differ")
        check(Matcher.same("ship", "shipped"), "same: cut-off partial result")

        let words = s.words.map(\.key)
        let m = Matcher(words: words)
        check(read(m, words, noise: { _ in nil }).final >= words.count - 1, "reads a clean script to the end")
        let noisy = read(m, words, noise: { i in i % 7 == 3 ? "zzgarble" : (i % 11 == 5 ? "" : nil) })
        check(noisy.final >= words.count - 2, "reads through misheard and dropped words (\(noisy.final)/\(words.count))")
        check(noisy.maxAhead <= 1, "never runs ahead of the speaker (max \(noisy.maxAhead))")

        // talking off script: unrelated words shouldn't move it far
        var cursor = 10
        for n in 1...12 {
            let adlib = Array("so anyway the thing about my cat is that she sleeps all day long".split(separator: " ").map(String.init).prefix(n))
            if let e = m.locate(heard: adlib, cursor: cursor), e + 1 > cursor { cursor = e + 1 }
        }
        check(cursor <= 13, "an ad-lib moves it at most a couple of short words (\(cursor))")

        // skipping a sentence: it catches up after a few words
        cursor = 5
        let skipTo = 20
        var heard: [String] = []
        for i in skipTo..<skipTo + 5 {
            heard.append(words[i])
            if let e = m.locate(heard: heard, cursor: cursor), e + 1 > cursor { cursor = e + 1 }
        }
        check(cursor == skipTo + 5, "catches up after a skipped sentence (\(cursor), want \(skipTo + 5))")

        print(failures == 0 ? "SELFTEST passed" : "SELFTEST failed: \(failures)")
        return failures == 0
    }

    /// A speaker reading `words` aloud, the recognizer reporting the utterance so far after
    /// each word and starting a new utterance every 15 words. `noise` swaps a word for
    /// another ("" drops it).
    private static func read(_ m: Matcher, _ words: [String], noise: (Int) -> String?) -> (final: Int, maxAhead: Int) {
        var cursor = 0, heard: [String] = [], maxAhead = 0
        for i in words.indices {
            if i % 15 == 0 { heard = [] }
            let w = noise(i) ?? words[i]
            if !w.isEmpty { heard.append(w) }
            if let e = m.locate(heard: heard, cursor: cursor), e + 1 > cursor { cursor = e + 1 }
            maxAhead = max(maxAhead, cursor - (i + 1))
        }
        return (cursor, maxAhead)
    }
}
