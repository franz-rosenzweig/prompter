import AppKit

/// A script as the prompter shows it. The source is plain text:
///   # Heading      a cue: a section you can jump to, shown small, never read aloud
///   [slow down]    a direction to yourself, shown dim, never read aloud
///   anything else  the words you say
struct Script {
    struct Word { let key: String; let range: NSRange }
    struct Cue: Identifiable { let id: Int; let title: String; let location: Int }

    struct Style {
        var fontSize: CGFloat = 24
        var color: NSColor = .white
        var alignment: NSTextAlignment = .left
        var lineSpacing: CGFloat = 1.2

        static var current: Style {
            let d = Pref.d
            return Style(fontSize: CGFloat(d.double(forKey: Pref.fontSize)),
                         color: NSColor(hex: d.string(forKey: Pref.textColor) ?? "") ?? .white,
                         alignment: d.string(forKey: Pref.alignment) == "center" ? .center : .left,
                         lineSpacing: CGFloat(d.double(forKey: Pref.lineSpacing)))
        }
    }

    let text: NSAttributedString
    let words: [Word]        // the spoken words, in order
    let cues: [Cue]

    init(_ source: String, style: Style = .current) {
        let out = NSMutableAttributedString()
        var words: [Word] = [], cues: [Cue] = []

        let para = NSMutableParagraphStyle()
        para.alignment = style.alignment
        para.lineHeightMultiple = style.lineSpacing
        para.paragraphSpacing = style.fontSize * 0.5
        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: style.fontSize, weight: .semibold),
            .foregroundColor: style.color, .paragraphStyle: para,
        ]
        var aside = body
        aside[.font] = NSFont.systemFont(ofSize: style.fontSize * 0.8, weight: .regular).italic
        aside[.foregroundColor] = style.color.withAlphaComponent(0.45)
        let cuePara = para.mutableCopy() as! NSMutableParagraphStyle
        cuePara.paragraphSpacingBefore = style.fontSize * 0.6
        cuePara.paragraphSpacing = style.fontSize * 0.2
        let cueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(11, style.fontSize * 0.5), weight: .bold),
            .foregroundColor: style.color.withAlphaComponent(0.5), .kern: 1.2, .paragraphStyle: cuePara,
        ]

        var paragraph: [String] = []
        func flush() {
            guard !paragraph.isEmpty else { return }
            if out.length > 0 { out.append(NSAttributedString(string: "\n", attributes: body)) }
            let line = paragraph.joined(separator: " ")
            paragraph = []
            // spoken runs and [directions], in order
            var rest = Substring(line)
            while !rest.isEmpty {
                if let open = rest.firstIndex(of: "["), let close = rest[open...].firstIndex(of: "]") {
                    append(String(rest[..<open]), spoken: true)
                    append(String(rest[open...close]), spoken: false)
                    rest = rest[rest.index(after: close)...]
                } else {
                    append(String(rest), spoken: true)
                    rest = ""
                }
            }
        }
        func append(_ s: String, spoken: Bool) {
            guard !s.isEmpty else { return }
            let start = out.length
            out.append(NSAttributedString(string: s, attributes: spoken ? body : aside))
            guard spoken else { return }
            for (key, r) in Script.tokens(s) {
                words.append(Word(key: key, range: NSRange(location: start + r.location, length: r.length)))
            }
        }

        for raw in source.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if out.length > 0 { out.append(NSAttributedString(string: "\n", attributes: body)) }
                cues.append(Cue(id: cues.count, title: title.isEmpty ? "Cue \(cues.count + 1)" : title, location: out.length))
                out.append(NSAttributedString(string: title.uppercased(), attributes: cueAttrs))
            } else {
                paragraph.append(line)
            }
        }
        flush()

        text = out
        self.words = words
        self.cues = cues
    }

    /// The index of the first spoken word at or after a character.
    func word(atOrAfter location: Int) -> Int {
        var lo = 0, hi = words.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if NSMaxRange(words[mid].range) <= location { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Words as the matcher compares them: lower case, no accents or apostrophes, with their
    /// ranges in `s` (UTF-16, as NSString counts).
    static func tokens(_ s: String) -> [(String, NSRange)] {
        let ns = s as NSString
        return wordPattern.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let key = normalize(ns.substring(with: m.range))
            return key.isEmpty ? nil : (key, m.range)
        }
    }

    static func keys(_ s: String) -> [String] { tokens(s).map(\.0) }

    static func normalize(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { $0 != "'" && $0 != "’" }
    }

    private static let wordPattern = try! NSRegularExpression(pattern: "[\\p{L}\\p{N}][\\p{L}\\p{N}\\p{M}'’]*")
}

/// Follow mode's ear: lines up the end of what the recognizer heard with the script near
/// where the speaker was, and says which script word they just said.
struct Matcher {
    let words: [String]

    /// `heard`: the words of the utterance so far, as the recognizer has them now.
    /// `cursor`: the script word expected next. Returns the index of the script word just said.
    func locate(heard: [String], cursor: Int) -> Int? {
        let tail = Array(heard.suffix(6))
        guard let last = tail.last, !words.isEmpty else { return nil }
        let lo = max(0, cursor - 3), hi = min(words.count - 1, cursor + 40)
        guard lo <= hi else { return nil }

        var best: Int?, bestScore = -Double.infinity
        for end in lo...hi {
            // The last word heard says where they are; a garbled or ad-libbed last word can
            // be skipped if the one before it lines up instead.
            let part: ArraySlice<String>
            if Matcher.same(last, words[end]) {
                part = tail[...]
            } else if tail.count > 1, Matcher.same(tail[tail.count - 2], words[end]) {
                part = tail.dropLast()
            } else {
                continue
            }
            let window = words[max(0, end - part.count - 1)...end]
            let score = Matcher.common(part, window)
            let jump = end - cursor
            // the further ahead, the more words must agree (short words count half)
            let needed = jump <= 2 ? 0.5 : jump <= 10 ? 1.5 : 2.5
            guard score >= needed else { continue }
            let ranked = score - 0.04 * Double(abs(jump))
            if ranked > bestScore { bestScore = ranked; best = end }
        }
        return best
    }

    /// The longest run of words the two share in order; a short word counts half.
    static func common(_ a: ArraySlice<String>, _ b: ArraySlice<String>) -> Double {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var dp = Array(repeating: Array(repeating: 0.0, count: b.count + 1), count: a.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                if same(a[i - 1], b[j - 1]) {
                    dp[i][j] = max(dp[i][j], dp[i - 1][j - 1] + (min(a[i - 1].count, b[j - 1].count) >= 4 ? 1 : 0.5))
                }
            }
        }
        return dp[a.count][b.count]
    }

    /// Close enough: the same, one cut short (a partial result), or a letter or two off.
    static func same(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = min(a.count, b.count)
        guard shorter >= 4 else { return false }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        return distance(a, b, limit: shorter >= 8 ? 2 : 1)
    }

    private static func distance(_ a: String, _ b: String, limit: Int) -> Bool {
        let a = Array(a), b = Array(b)
        guard abs(a.count - b.count) <= limit else { return false }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            if cur.min()! > limit { return false }
            prev = cur
        }
        return prev[b.count] <= limit
    }
}

extension NSFont {
    var italic: NSFont {
        NSFont(descriptor: fontDescriptor.withSymbolicTraits(.italic), size: pointSize) ?? self
    }
}
