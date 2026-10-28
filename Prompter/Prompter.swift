import AppKit
import QuartzCore
import Observation

/// Runs the prompter: puts the panel at the top of the screen (or floating), scrolls the
/// script in one of three ways, and answers the controls, the menus and the shortcuts.
///   Follow  moves line by line as the recognizer hears the script's words
///   Voice   scrolls at the set speed while you talk, stops when you stop
///   Steady  scrolls at the set speed until paused
@MainActor @Observable final class Prompter {
    static let shared = Prompter()

    private(set) var isShowing = false
    private(set) var isPlaying = false
    private(set) var scriptID = ""      // the file name of the script showing
    private(set) var cues: [Script.Cue] = []
    private(set) var currentCue: Int?
    private(set) var problem: String?
    private(set) var mode = Mode.follow

    @ObservationIgnored private var panel: PrompterPanel?
    @ObservationIgnored private var view: PrompterView?
    @ObservationIgnored private var source = ""
    @ObservationIgnored private var script = Script("")
    @ObservationIgnored private var matcher = Matcher(words: [])
    @ObservationIgnored private var cursor = 0                 // Follow: the script word expected next
    @ObservationIgnored private var followTarget: CGFloat = 0
    @ObservationIgnored private var jumpTarget: CGFloat?
    @ObservationIgnored private var velocity: CGFloat = 0
    @ObservationIgnored private var lastTick: CFTimeInterval = 0
    @ObservationIgnored private var lastVoice: CFTimeInterval = -10
    @ObservationIgnored private var userScrollUntil: CFTimeInterval = 0
    @ObservationIgnored private var hovering = false
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private let listener = Listener()
    @ObservationIgnored private var style = Script.Style.current
    @ObservationIgnored private var geometry = ""              // the prefs the panel's frame depends on
    @ObservationIgnored private var language = ""
    @ObservationIgnored private var speed: CGFloat = 12
    @ObservationIgnored private var threshold: Float = 0.4
    @ObservationIgnored private var hoverPauses = true

    private init() {
        mode = Mode(rawValue: Pref.d.string(forKey: Pref.mode) ?? "") ?? .follow
        language = Pref.d.string(forKey: Pref.language) ?? ""
        readPrefs()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Prompter.shared.prefsChanged() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Prompter.shared.place() }
        }
        listener.onLevel = { [weak self] level in self?.heard(level: level) }
        listener.onHeard = { [weak self] words in self?.heard(words: words) }
        listener.onProblem = { [weak self] text in
            self?.problem = text
            self?.view?.setProblem(text)
        }
    }

    // MARK: Showing

    func show(_ source: String, id: String) {
        if isShowing && source == self.source && id == scriptID { return }
        let keep = isShowing && id == scriptID     // the same script, edited
        self.source = source
        scriptID = id
        build()
        if !isShowing { place() }
        load(keepPlace: keep)
        if !isShowing {
            isShowing = true
            panel?.orderFrontRegardless()
            startLink()
            Hotkeys.shared.setPlayback(true)
            setPlaying(mode != .steady)
        }
    }

    /// The editor changed the script that's showing: keep the place.
    func update(_ source: String) {
        guard isShowing, source != self.source else { return }
        self.source = source
        load(keepPlace: true)
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        setPlaying(false)
        listener.stop()
        link?.invalidate()
        link = nil
        panel?.orderOut(nil)
        Hotkeys.shared.setPlayback(false)
        problem = nil
        view?.setProblem(nil)
    }

    func toggle() {
        if isShowing { hide(); return }
        guard let s = Library.shared.lastShown ?? Library.shared.scripts.first else { return }
        Library.shared.show(s)
    }

    func renamed(from old: String, to new: String) {
        if scriptID == old { scriptID = new }
    }

    private func build() {
        guard panel == nil else { return }
        let panel = PrompterPanel()
        let view = PrompterView(frame: panel.contentLayoutRect)
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
        view.onHover = { [weak self] inside in self?.hover(inside) }
        view.onClick = { [weak self] in self?.playPause() }
        view.onUserScroll = { [weak self] in self?.userScrolled() }
        view.onResized = { [weak self] in self?.reanchor() }
        view.controls.add("mode", symbol: mode.symbol, help: "Mode") { [weak self] in self?.cycleMode() }
        view.controls.add("back", symbol: "backward.end.fill", help: "Previous cue") { [weak self] in self?.previousCue() }
        view.controls.add("play", symbol: "pause.fill", help: "Pause") { [weak self] in self?.playPause() }
        view.controls.add("next", symbol: "forward.end.fill", help: "Next cue") { [weak self] in self?.nextCue() }
        view.controls.add("slower", symbol: "tortoise.fill", help: "Slower") { [weak self] in self?.slower() }
        view.controls.add("faster", symbol: "hare.fill", help: "Faster") { [weak self] in self?.faster() }
        view.controls.add("close", symbol: "xmark", help: "Hide") { [weak self] in self?.hide() }
        if UserDefaults.standard.bool(forKey: "PrompterShowControls") { view.controls.alphaValue = 1 }
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { _ in
            MainActor.assumeIsolated { Prompter.shared.saveFloatingFrame() }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { _ in
            MainActor.assumeIsolated { Prompter.shared.saveFloatingFrame() }
        }
        self.panel = panel
        self.view = view
        refreshControls()
    }

    private func load(keepPlace: Bool) {
        guard let view else { return }
        let anchor = keepPlace ? view.locationAtReadingLine() : nil
        script = Script(source, style: style)
        matcher = Matcher(words: script.words.map(\.key))
        cues = script.cues
        view.setText(script.text)
        if let anchor {
            cursor = min(cursor, script.words.count)
            let o = view.offset(for: min(anchor, max(0, script.text.length - 1)))
            view.setOffset(o)
            followTarget = view.offset(for: wordLocation(cursor))
        } else {
            cursor = 0
            followTarget = 0
            view.setOffset(0)
        }
        jumpTarget = nil
        dimSpoken()
        updateCue()
        if isShowing && mode != .steady && !listener.running { listen() }
    }

    /// Where the panel goes: hanging from the top edge, centred under the camera, or
    /// wherever the floating window was left. Width and Height size it either way.
    func place() {
        guard let panel, let view, let screen = NSScreen.forPrompter else { return }
        let d = Pref.d
        let textHeight = CGFloat(d.double(forKey: Pref.height))
        let mirrored = d.bool(forKey: Pref.mirror)
        if Placement(rawValue: d.string(forKey: Pref.placement) ?? "") == .floating {
            let w = CGFloat(d.double(forKey: Pref.width)), h = textHeight + 30
            let saved = NSRectFromString(d.string(forKey: Pref.floatingFrame) ?? "")
            // keep the top-left corner where it was left, so a new size grows down and right
            var frame = NSRect(x: saved.minX, y: saved.maxY - h, width: w, height: h)
            if saved.width < 1 || !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                let v = screen.visibleFrame
                frame = NSRect(x: v.midX - w / 2, y: v.maxY - h - 60, width: w, height: h)
            }
            view.configure(placement: .floating, topInset: 14, ear: 0, mirrored: mirrored)
            panel.isMovable = true
            panel.hasShadow = true
            panel.setFrame(frame, display: true)
        } else {
            let notch = screen.notchSize
            let top = notch.height > 0 ? notch.height : 6
            let ear: CGFloat = 10
            let width = max(CGFloat(d.double(forKey: Pref.width)), notch.width + 80)
            let h = top + textHeight + 14
            let s = screen.frame
            view.configure(placement: .notch, topInset: top, ear: ear, mirrored: mirrored)
            panel.isMovable = false
            panel.hasShadow = false
            panel.setFrame(NSRect(x: (s.midX - width / 2 - ear).rounded(), y: s.maxY - h, width: width + 2 * ear, height: h), display: true)
        }
        view.layoutSubtreeIfNeeded()
    }

    private func saveFloatingFrame() {
        guard let panel, view?.placement == .floating, isShowing else { return }
        Pref.d.set(NSStringFromRect(panel.frame), forKey: Pref.floatingFrame)
    }

    /// The text re-wrapped (a new width or font): keep the same words on the reading line.
    private func reanchor() {
        guard let view, isShowing else { return }
        followTarget = view.offset(for: wordLocation(cursor))
    }

    // MARK: Settings

    private func readPrefs() {
        let d = Pref.d
        speed = CGFloat(d.double(forKey: Pref.speed))
        threshold = Float(0.5 - 0.3 * d.double(forKey: Pref.sensitivity))   // 0.35 ≈ -39 dB
        hoverPauses = d.bool(forKey: Pref.hoverPauses)
    }

    private func prefsChanged() {
        readPrefs()
        let newMode = Mode(rawValue: Pref.d.string(forKey: Pref.mode) ?? "") ?? .follow
        if newMode != mode { setMode(newMode) }
        let newStyle = Script.Style.current
        if newStyle.fontSize != style.fontSize || newStyle.color != style.color
            || newStyle.alignment != style.alignment || newStyle.lineSpacing != style.lineSpacing {
            style = newStyle
            if isShowing { load(keepPlace: true) }
        }
        let d = Pref.d
        let g = [Pref.width, Pref.height, Pref.placement, Pref.display, Pref.mirror]
            .map { "\(d.object(forKey: $0) ?? "")" }.joined(separator: "|")
        if g != geometry {
            geometry = g
            if isShowing { place() }
        }
        let lang = d.string(forKey: Pref.language) ?? ""
        if lang != language {
            language = lang
            if isShowing && mode == .follow { listen() }
        }
    }

    // MARK: Controls

    func playPause() { setPlaying(!isPlaying) }

    private func setPlaying(_ on: Bool) {
        isPlaying = on
        velocity = 0
        if on && mode != .steady && isShowing && !listener.running { listen() }
        view?.setPaused(!on && isShowing)
        refreshControls()
    }

    func setMode(_ m: Mode) {
        mode = m
        if Pref.d.string(forKey: Pref.mode) != m.rawValue { Pref.d.set(m.rawValue, forKey: Pref.mode) }
        if let view {
            cursor = script.word(atOrAfter: view.locationAtReadingLine())
            followTarget = view.offset
        }
        dimSpoken()
        if isShowing {
            if m == .steady { listener.stop(); view?.setHearing(nil); problem = nil; view?.setProblem(nil) } else { listen() }
        }
        refreshControls()
    }

    func cycleMode() { setMode(mode.next) }

    func faster() { Pref.d.set(min(120, Double(speed) * 1.15).rounded(), forKey: Pref.speed) }
    func slower() { Pref.d.set(max(4, Double(speed) / 1.15).rounded(), forKey: Pref.speed) }

    func restart() { jump(to: 0, word: 0) }

    func jump(toCue i: Int) {
        guard cues.indices.contains(i) else { return }
        jump(to: cues[i].location, word: script.word(atOrAfter: cues[i].location))
    }

    func nextCue() {
        guard let view else { return }
        let here = view.locationAtReadingLine()
        if let c = cues.first(where: { $0.location > here }) { jump(toCue: c.id) }
    }

    func previousCue() {
        guard let view else { return }
        // from just past a cue's start, go to the one before it
        let here = view.locationAtReadingLine()
        if let c = cues.last(where: { $0.location < here && view.offset(for: $0.location) < view.offset - 4 }) {
            jump(toCue: c.id)
        } else {
            restart()
        }
    }

    private func jump(to location: Int, word: Int) {
        guard let view else { return }
        cursor = word
        let o = location == 0 ? 0 : view.offset(for: location)
        jumpTarget = o
        followTarget = o
        dimSpoken()
    }

    private func refreshControls() {
        guard let view else { return }
        view.controls.setSymbol("play", isPlaying ? "pause.fill" : "play.fill", help: isPlaying ? "Pause" : "Play")
        view.controls.setSymbol("mode", mode.symbol, help: mode.label)
        view.controls.setHidden("slower", mode == .follow)
        view.controls.setHidden("faster", mode == .follow)
        view.controls.setHidden("back", cues.isEmpty)
        view.controls.setHidden("next", cues.isEmpty)
        view.needsLayout = true
    }

    private func hover(_ inside: Bool) {
        // pictures shouldn't depend on where the pointer happens to be
        if UserDefaults.standard.bool(forKey: "PrompterNoHover") { return }
        hovering = inside
        if !UserDefaults.standard.bool(forKey: "PrompterShowControls") { view?.showControls(inside) }
    }

    private func userScrolled() {
        userScrollUntil = CACurrentMediaTime() + 0.6
        jumpTarget = nil
    }

    // MARK: Listening

    private func listen() {
        guard isShowing, mode != .steady, ProcessInfo.processInfo.environment["PROMPTER_NO_MIC"] == nil else { return }
        view?.setHearing(false)
        let text = script.text.string as NSString
        let hints = Array(Set(script.words.map { text.substring(with: $0.range) }.filter { $0.count >= 7 })).prefix(100)
        Task { await listener.start(recognize: mode == .follow, hints: Array(hints)) }
    }

    private func heard(level: Float) {
        let talking = level > threshold
        if talking { lastVoice = CACurrentMediaTime() }
        view?.setHearing(CACurrentMediaTime() - lastVoice < 0.4)
    }

    private func heard(words: [String]) {
        guard mode == .follow, isPlaying, let view else { return }
        guard let end = matcher.locate(heard: words, cursor: cursor), end + 1 > cursor else { return }
        cursor = end + 1
        followTarget = view.offset(for: wordLocation(cursor))
        dimSpoken()
    }

    private func wordLocation(_ i: Int) -> Int {
        if script.words.isEmpty { return 0 }
        return i < script.words.count ? script.words[i].range.location : NSMaxRange(script.words.last!.range)
    }

    private func dimSpoken() {
        view?.dim(upTo: mode == .follow && cursor > 0 ? wordLocation(cursor) : 0, color: style.color)
    }

    // MARK: Scrolling

    private func startLink() {
        guard link == nil, let view else { return }
        let l = view.displayLink(target: LinkTarget { [weak self] in self?.tick($0) }, selector: #selector(LinkTarget.fire(_:)))
        l.add(to: .main, forMode: .common)
        lastTick = CACurrentMediaTime()
        link = l
    }

    private func tick(_ link: CADisplayLink) {
        guard let view else { return }
        let now = link.timestamp
        let dt = CGFloat(min(0.1, max(0, now - lastTick)))
        lastTick = now

        if now < userScrollUntil {
            // the trackpad has it; Follow picks up from wherever it's left
            if mode == .follow {
                cursor = script.word(atOrAfter: view.locationAtReadingLine())
                followTarget = view.offset
                dimSpoken()
            }
            updateCue()
            return
        }
        var y = view.offset
        if let t = jumpTarget {
            y += (t - y) * (1 - exp(-dt * 10))
            if abs(t - y) < 0.5 { y = t; jumpTarget = nil }
        } else {
            let moving = isPlaying && !(hovering && hoverPauses)
            switch mode {
            case .steady:
                if moving { y += speed * dt }
            case .voice:
                let want = moving && now - lastVoice < 0.5 ? speed : 0
                velocity += (want - velocity) * min(1, dt * 6)
                y += velocity * dt
            case .follow:
                if moving { y += (followTarget - y) * (1 - exp(-dt * 4)) }
            }
        }
        view.setOffset(min(max(0, y), view.maxOffset))
        updateCue()
    }

    private func updateCue() {
        guard let view, !cues.isEmpty else { if currentCue != nil { currentCue = nil }; return }
        let here = view.locationAtReadingLine()
        let c = cues.last(where: { $0.location <= here })?.id
        if c != currentCue { currentCue = c }
    }

    // MARK: Tests

    /// For the self-test: as if the recognizer had heard up to script word `i`.
    func pretendHeard(through i: Int) {
        cursor = i + 1
        followTarget = view?.offset(for: wordLocation(cursor)) ?? 0
        jumpTarget = followTarget
        dimSpoken()
    }

    /// For pictures: the dot lit, as if it heard talking.
    func pretendHearing() { view?.setHearing(true) }

    var windowNumber: Int { panel?.windowNumber ?? 0 }
    var panelFrame: NSRect { panel?.frame ?? .zero }
}

/// The display link's target (it keeps its target alive, so not the Prompter itself).
private final class LinkTarget: NSObject {
    let action: @MainActor (CADisplayLink) -> Void
    init(_ action: @escaping @MainActor (CADisplayLink) -> Void) { self.action = action }
    @objc func fire(_ link: CADisplayLink) { MainActor.assumeIsolated { action(link) } }
}
