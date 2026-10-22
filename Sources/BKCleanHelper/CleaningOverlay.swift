import AppKit

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class CleaningOverlay {
    private var panels: [NSPanel] = []
    private var rings: [CountdownRing] = []

    init(preview: Bool) {
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame,
                                     styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = NSColor(white: 0.055, alpha: 1)
            panel.appearance = NSAppearance(named: .darkAqua)
            panel.setFrame(screen.frame, display: false)

            let root = NSView()
            panel.contentView = root
            let content = NSStackView()
            content.orientation = .vertical
            content.alignment = .centerX
            content.spacing = 20
            content.translatesAutoresizingMaskIntoConstraints = false

            let symbol = NSImageView(image: NSImage(systemSymbolName: "keyboard", accessibilityDescription: "清洁模式")!)
            symbol.contentTintColor = .secondaryLabelColor
            symbol.symbolConfiguration = .init(pointSize: 34, weight: .regular)
            content.addArrangedSubview(symbol)

            let heading = NSTextField(labelWithString: preview ? "清洁界面预览" : "安心擦一擦")
            heading.font = .systemFont(ofSize: 20, weight: .medium)
            heading.textColor = .labelColor
            content.addArrangedSubview(heading)

            let ring = CountdownRing()
            ring.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([ring.widthAnchor.constraint(equalToConstant: 252), ring.heightAnchor.constraint(equalToConstant: 252)])
            rings.append(ring)
            content.addArrangedSubview(ring)

            let state = NSTextField(labelWithString: preview ? "预览期间，输入保持可用" : "键盘与触摸板已暂停")
            state.font = .systemFont(ofSize: 17, weight: .medium)
            state.textColor = .labelColor
            content.addArrangedSubview(state)
            let detail = NSTextField(labelWithString: preview ? "实际清洁模式为 60 秒，到时自动恢复" : "包括外接键盘与鼠标 · 到时自动恢复")
            detail.font = .systemFont(ofSize: 13)
            detail.textColor = .secondaryLabelColor
            content.setCustomSpacing(8, after: state)
            content.addArrangedSubview(detail)

            let shortcut = NSTextField(labelWithString: preview ? "这是界面预览，并未屏蔽输入" : "提前结束：按住 ⌃⌥⌘U 两秒")
            shortcut.font = .systemFont(ofSize: 12, weight: .medium)
            shortcut.textColor = .tertiaryLabelColor
            content.setCustomSpacing(32, after: detail)
            content.addArrangedSubview(shortcut)

            root.addSubview(content)
            NSLayoutConstraint.activate([
                content.centerXAnchor.constraint(equalTo: root.centerXAnchor),
                content.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -12),
            ])
            panels.append(panel)
        }
    }

    func show() { panels.forEach { $0.orderFrontRegardless() } }
    func update(seconds: Int, fraction: Double) { rings.forEach { $0.update(seconds: seconds, fraction: fraction) } }
    func close() { panels.forEach { $0.orderOut(nil); $0.close() }; panels.removeAll(); rings.removeAll() }
}

private final class CountdownRing: NSView {
    private var fraction = 1.0
    private let number = NSTextField(labelWithString: "60")

    override init(frame: NSRect) {
        super.init(frame: frame)
        number.font = .monospacedDigitSystemFont(ofSize: 94, weight: .ultraLight)
        number.textColor = .labelColor
        number.alignment = .center
        number.translatesAutoresizingMaskIntoConstraints = false
        let unit = NSTextField(labelWithString: "秒后恢复")
        unit.font = .systemFont(ofSize: 12, weight: .medium)
        unit.textColor = .secondaryLabelColor
        unit.translatesAutoresizingMaskIntoConstraints = false
        addSubview(number)
        addSubview(unit)
        NSLayoutConstraint.activate([
            number.centerXAnchor.constraint(equalTo: centerXAnchor),
            number.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            unit.centerXAnchor.constraint(equalTo: centerXAnchor),
            unit.topAnchor.constraint(equalTo: number.bottomAnchor, constant: -1),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(seconds: Int, fraction: Double) {
        if number.stringValue != String(seconds) { number.stringValue = String(seconds) }
        self.fraction = fraction
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 5, dy: 5)
        let track = NSBezierPath(ovalIn: rect)
        track.lineWidth = 2
        NSColor.white.withAlphaComponent(0.09).setStroke()
        track.stroke()
        guard fraction > 0 else { return }
        let arc = NSBezierPath()
        arc.lineWidth = 2.5
        arc.lineCapStyle = .round
        arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                      startAngle: 90, endAngle: CGFloat(90 - fraction * 360), clockwise: true)
        NSColor.controlAccentColor.setStroke()
        arc.stroke()
    }
}
