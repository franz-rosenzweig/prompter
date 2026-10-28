import AppKit
import QuartzCore

/// The prompter's window: borderless, never takes focus, above the menu bar and full-screen
/// apps, on every Space, and left out of screen shares, recordings and screenshots.
final class PrompterPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        // PROMPTER_CAPTURABLE lets the self-test take its picture; nothing else should set it.
        sharingType = ProcessInfo.processInfo.environment["PROMPTER_CAPTURABLE"] == "1" ? .readOnly : .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Up against the top edge, over the menu bar: don't let AppKit push it down.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// What's inside: a black shape (a notch grown downward, or a rounded card when floating),
/// the scrolling text, a control bar on hover, and a dot that lights when it hears you.
final class PrompterView: NSView {
    final class TextView: NSTextView {
        var topPad: CGFloat = 0 { didSet { invalidateTextContainerOrigin() } }
        override var textContainerOrigin: NSPoint { NSPoint(x: 0, y: topPad) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }   // PrompterView takes the mouse
    }

    let storage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    let container = NSTextContainer(size: NSSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
    let textView: TextView
    let scroll = NSScrollView()
    let controls = ControlsBar()

    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    var onUserScroll: (() -> Void)?
    var onResized: (() -> Void)?

    private(set) var placement = Placement.notch
    private var topInset: CGFloat = 0     // the notch's height, where no text goes
    private var ear: CGFloat = 0          // the inward curves where it meets the screen's top edge
    private var mirrored = false
    private let shape = CAShapeLayer()
    private let clip = NSView()           // the text's window: fades its edges, mirrors it
    private let fade = CAGradientLayer()
    private let dot = CALayer()
    private let pauseGlyph = NSImageView()
    private let problemLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        storage.addLayoutManager(layoutManager)
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        textView = TextView(frame: .zero, textContainer: container)
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(shape)

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.textContainerInset = .zero

        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .none
        scroll.contentView.drawsBackground = false

        clip.wantsLayer = true
        clip.layer?.mask = fade
        clip.addSubview(scroll)
        addSubview(clip)

        dot.cornerRadius = 3.5
        dot.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        dot.isHidden = true
        layer?.addSublayer(dot)

        pauseGlyph.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Paused")?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .bold))
        pauseGlyph.contentTintColor = NSColor.white.withAlphaComponent(0.5)
        pauseGlyph.isHidden = true
        addSubview(pauseGlyph)

        problemLabel.font = .systemFont(ofSize: 11, weight: .medium)
        problemLabel.textColor = NSColor.systemOrange
        problemLabel.alignment = .center
        problemLabel.lineBreakMode = .byTruncatingTail
        problemLabel.isHidden = true
        addSubview(problemLabel)

        controls.alphaValue = 0
        addSubview(controls)

        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(placement: Placement, topInset: CGFloat, ear: CGFloat, mirrored: Bool) {
        self.placement = placement
        self.topInset = topInset
        self.ear = ear
        self.mirrored = mirrored
        needsLayout = true
    }

    // MARK: Geometry

    /// The visible text's height, and the line inside it where the line being read sits:
    /// near the top, close to the camera, with one faded line of context above.
    var visibleHeight: CGFloat { scroll.contentView.bounds.height }
    var readingY: CGFloat { (visibleHeight * 0.2).rounded() }

    override func layout() {
        super.layout()
        let b = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = b
        shape.path = outline(in: b)
        shape.fillColor = NSColor.black.withAlphaComponent(placement == .notch ? 1 : 0.9).cgColor

        let pad: CGFloat = placement == .notch ? 22 : 20
        let bottom: CGFloat = placement == .notch ? 10 : 12
        let text = NSRect(x: ear + pad, y: bottom, width: max(40, b.width - 2 * ear - 2 * pad),
                          height: max(30, b.height - topInset - bottom - 4))
        let resized = clip.frame.size != text.size
        clip.frame = text
        scroll.frame = clip.bounds
        fade.frame = clip.bounds
        let top = Double(min(0.2, 22 / text.height)), low = Double(min(0.25, 30 / text.height))
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fade.locations = [0, NSNumber(value: low), NSNumber(value: 1 - top), 1]   // CA's y runs upward here
        fade.startPoint = CGPoint(x: 0.5, y: 0)
        fade.endPoint = CGPoint(x: 0.5, y: 1)
        clip.layer?.sublayerTransform = mirrored
            ? CATransform3DConcat(CATransform3DMakeScale(-1, 1, 1), CATransform3DMakeTranslation(text.width, 0, 0))
            : CATransform3DIdentity

        dot.frame = NSRect(x: text.maxX + 6, y: text.maxY - 9, width: 7, height: 7)
        pauseGlyph.frame = NSRect(x: text.maxX + 4, y: text.maxY - 24, width: 11, height: 11)
        problemLabel.frame = NSRect(x: text.minX, y: bottom, width: text.width, height: 16)
        let size = controls.fittingSize
        controls.frame = NSRect(x: (b.width - size.width) / 2, y: bottom, width: size.width, height: size.height)
        CATransaction.commit()

        if resized { relayoutText(); onResized?() }
    }

    /// The notch, grown: flush with the screen's top edge, curving out into it at the top
    /// corners, rounded at the bottom. Floating, it's a plain rounded card.
    private func outline(in b: NSRect) -> CGPath {
        if placement == .floating {
            return CGPath(roundedRect: b, cornerWidth: 18, cornerHeight: 18, transform: nil)
        }
        let p = CGMutablePath(), r: CGFloat = 20, e = ear
        let l = b.minX + e, rt = b.maxX - e
        p.move(to: CGPoint(x: b.minX, y: b.maxY))
        p.addQuadCurve(to: CGPoint(x: l, y: b.maxY - e), control: CGPoint(x: l, y: b.maxY))
        p.addLine(to: CGPoint(x: l, y: b.minY + r))
        p.addCurve(to: CGPoint(x: l + r, y: b.minY), control1: CGPoint(x: l, y: b.minY + r * 0.45),
                   control2: CGPoint(x: l + r * 0.45, y: b.minY))
        p.addLine(to: CGPoint(x: rt - r, y: b.minY))
        p.addCurve(to: CGPoint(x: rt, y: b.minY + r), control1: CGPoint(x: rt - r * 0.45, y: b.minY),
                   control2: CGPoint(x: rt, y: b.minY + r * 0.45))
        p.addLine(to: CGPoint(x: rt, y: b.maxY - e))
        p.addQuadCurve(to: CGPoint(x: b.maxX, y: b.maxY), control: CGPoint(x: rt, y: b.maxY))
        p.closeSubpath()
        return p
    }

    // MARK: Text

    func setText(_ text: NSAttributedString) {
        storage.setAttributedString(text)
        relayoutText()
    }

    /// The document: blank space above and below the text, so the first line can sit at
    /// the reading line at offset 0 and the last line can scroll up to it.
    func relayoutText() {
        let w = clip.bounds.width
        guard w > 0 else { return }
        container.size = NSSize(width: w, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).height
        textView.topPad = readingY
        textView.frame = NSRect(x: 0, y: 0, width: w, height: used + visibleHeight)
    }

    var contentHeight: CGFloat { layoutManager.usedRect(for: container).height }

    var maxOffset: CGFloat {
        let lastLine = layoutManager.extraLineFragmentRect.height > 0
            ? layoutManager.extraLineFragmentRect.height
            : (storage.length > 0 ? lineRect(at: storage.length - 1).height : 0)
        return max(0, contentHeight - lastLine)
    }

    /// The offset that puts a character's line at the reading line.
    func offset(for location: Int) -> CGFloat {
        guard storage.length > 0 else { return 0 }
        return lineRect(at: min(location, storage.length - 1)).minY
    }

    /// The character on the reading line.
    func locationAtReadingLine() -> Int {
        guard storage.length > 0 else { return 0 }
        let y = offset + 2
        let glyph = layoutManager.glyphIndex(for: NSPoint(x: 1, y: max(0, y)), in: container)
        return layoutManager.characterIndexForGlyph(at: glyph)
    }

    private func lineRect(at location: Int) -> NSRect {
        let glyph = layoutManager.glyphIndexForCharacter(at: location)
        return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    }

    var offset: CGFloat { scroll.contentView.bounds.origin.y }

    func setOffset(_ y: CGFloat) {
        let scale = window?.backingScaleFactor ?? 2
        let y = (y * scale).rounded() / scale
        guard abs(y - offset) > 0.01 else { return }
        scroll.contentView.setBoundsOrigin(NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    /// Follow mode greys out what's been said.
    func dim(upTo location: Int, color: NSColor) {
        let all = NSRange(location: 0, length: storage.length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: all)
        guard location > 0 else { return }
        layoutManager.addTemporaryAttribute(.foregroundColor, value: color.withAlphaComponent(0.3),
                                            forCharacterRange: NSRange(location: 0, length: min(location, storage.length)))
    }

    // MARK: Status

    /// nil: not listening. Otherwise whether it hears talking.
    func setHearing(_ hearing: Bool?) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        dot.isHidden = hearing == nil
        dot.backgroundColor = (hearing == true ? NSColor.systemGreen : NSColor.white.withAlphaComponent(0.22)).cgColor
        CATransaction.commit()
    }

    func setPaused(_ paused: Bool) { pauseGlyph.isHidden = !paused }

    func setProblem(_ text: String?) {
        problemLabel.stringValue = text ?? ""
        problemLabel.isHidden = text == nil
    }

    func showControls(_ show: Bool, animated: Bool = true) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = animated ? 0.15 : 0
            controls.animator().alphaValue = show ? 1 : 0
        }
    }

    // MARK: Mouse

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if controls.alphaValue > 0.5, let v = controls.hitTest(local) { return v }
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseDown(with event: NSEvent) {
        if placement == .floating {
            window?.performDrag(with: event)
        } else if event.clickCount == 1 {
            onClick?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        scroll.scrollWheel(with: event)
        onUserScroll?()
    }
}

/// The bar that shows while the pointer is over the prompter.
final class ControlsBar: NSView {
    private let stack = NSStackView()
    private var buttons: [String: GlyphButton] = [:]

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.18, alpha: 0.95).cgColor
        layer?.cornerRadius = 13
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func add(_ name: String, symbol: String, help: String, _ action: @escaping () -> Void) {
        let b = GlyphButton(symbol: symbol, help: help, action)
        buttons[name] = b
        stack.addArrangedSubview(b)
    }

    func setSymbol(_ name: String, _ symbol: String, help: String? = nil) {
        buttons[name]?.setSymbol(symbol)
        if let help { buttons[name]?.toolTip = help }
    }

    func setHidden(_ name: String, _ hidden: Bool) { buttons[name]?.isHidden = hidden }
}

final class GlyphButton: NSButton {
    private var handler: () -> Void = {}

    convenience init(symbol: String, help: String, _ handler: @escaping () -> Void) {
        self.init(frame: .zero)
        self.handler = handler
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .white
        toolTip = help
        setSymbol(symbol)
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 24).isActive = true
        heightAnchor.constraint(equalToConstant: 20).isActive = true
    }

    func setSymbol(_ name: String) {
        image = NSImage(systemSymbolName: name, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
    }

    @objc private func fire() { handler() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
