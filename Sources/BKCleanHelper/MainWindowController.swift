import AppKit

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let coordinator: CleaningCoordinator
    private let startButton = NSButton(title: "开始清洁", target: nil, action: nil)
    private let previewButton = NSButton(title: "预览清洁界面", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "前往设置…", target: nil, action: nil)
    private let monitoringButton = NSButton(title: "前往设置…", target: nil, action: nil)
    private let accessibilityStatus = NSTextField(labelWithString: "未授权")
    private let monitoringStatus = NSTextField(labelWithString: "未授权")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionHeading = NSTextField(labelWithString: "首次使用，完成两项系统授权")

    init(coordinator: CleaningCoordinator) {
        self.coordinator = coordinator
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "BKCleanHelper"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        coordinator.mainWindow = window
        buildContent()
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        coordinator.refreshPermissions()
        update()
    }

    func update() {
        accessibilityStatus.stringValue = coordinator.accessibilityAllowed ? "已允许" : "未授权"
        monitoringStatus.stringValue = coordinator.inputMonitoringAllowed ? "已允许" : "未授权"
        accessibilityStatus.textColor = coordinator.accessibilityAllowed ? .systemGreen : .secondaryLabelColor
        monitoringStatus.textColor = coordinator.inputMonitoringAllowed ? .systemGreen : .secondaryLabelColor
        accessibilityButton.title = coordinator.accessibilityAllowed ? "查看设置…" : "前往设置…"
        monitoringButton.title = coordinator.inputMonitoringAllowed ? "查看设置…" : "前往设置…"
        permissionHeading.stringValue = coordinator.ready ? "系统权限已就绪" : "首次使用，完成两项系统授权"
        accessibilityButton.isEnabled = !coordinator.isBusy
        monitoringButton.isEnabled = !coordinator.isBusy
        previewButton.isEnabled = !coordinator.isBusy
        switch coordinator.phase {
        case .idle:
            startButton.title = "开始清洁"
            startButton.isEnabled = coordinator.ready
            statusLabel.stringValue = coordinator.notice.isEmpty
                ? (coordinator.ready ? "准备好了，点击开始即可。" : "授权后即可使用，也可以先预览界面。")
                : coordinator.notice
        case .preparing:
            startButton.title = "取消（\(coordinator.remaining) 秒后开始）"
            startButton.isEnabled = true
            statusLabel.stringValue = coordinator.isPreview ? "即将预览，输入不会被屏蔽。" : "请松开按键，准备开始清洁。"
        case .acquiring:
            startButton.title = "取消"
            startButton.isEnabled = true
            statusLabel.stringValue = "正在准备，请松开所有按键和鼠标按钮…"
        case .cleaning:
            startButton.title = "提前结束"
            startButton.isEnabled = true
            statusLabel.stringValue = "\(coordinator.remaining) 秒后自动恢复。"
        case .stopping:
            startButton.title = "正在恢复…"
            startButton.isEnabled = false
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if coordinator.isBusy { coordinator.cancel() }
        return true
    }

    private func buildContent() {
        guard let window else { return }
        let root = NSView()
        window.contentView = root
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 20
        column.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            column.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            column.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            column.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -22),
        ])

        let title = NSTextField(labelWithString: "一分钟，安心擦一擦。")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "暂时放下输入，让 Mac 等你一会儿。")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        let titles = vertical([title, subtitle], spacing: 7)
        let header = NSStackView(views: [symbol("keyboard", size: 38, color: .controlAccentColor), titles])
        header.orientation = .horizontal
        header.spacing = 16
        header.alignment = .centerY
        column.addArrangedSubview(header)

        let deviceTitle = NSTextField(labelWithString: "键盘与触摸板")
        deviceTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        let deviceDetail = NSTextField(labelWithString: "内置与外接设备一起暂停")
        deviceDetail.font = .systemFont(ofSize: 12)
        deviceDetail.textColor = .secondaryLabelColor
        let duration = NSTextField(labelWithString: "60 秒")
        duration.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        duration.textColor = .labelColor
        let deviceRow = horizontal([vertical([deviceTitle, deviceDetail], spacing: 5), spacer(), duration])
        let separator = NSBox()
        separator.boxType = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let info = vertical([
            deviceRow, separator,
            infoRow("timer", "3 秒准备 · 60 秒后自动恢复"),
            infoRow("command", "按住 ⌃⌥⌘U 两秒，随时提前结束"),
        ], spacing: 15)
        let infoCard = card(info)
        column.addArrangedSubview(infoCard)
        infoCard.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        permissionHeading.font = .systemFont(ofSize: 12, weight: .medium)
        permissionHeading.textColor = .secondaryLabelColor
        let permissions = vertical([
            permissionHeading,
            permissionRow("辅助功能", status: accessibilityStatus, button: accessibilityButton),
            permissionRow("输入监控", status: monitoringStatus, button: monitoringButton),
        ], spacing: 12)
        let permissionCard = card(permissions)
        column.addArrangedSubview(permissionCard)
        permissionCard.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibility)
        monitoringButton.target = self
        monitoringButton.action = #selector(openMonitoring)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 2
        column.addArrangedSubview(statusLabel)
        statusLabel.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        statusLabel.heightAnchor.constraint(equalToConstant: 32).isActive = true
        column.setCustomSpacing(10, after: permissionCard)
        column.setCustomSpacing(8, after: statusLabel)

        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.font = .systemFont(ofSize: 14, weight: .medium)
        startButton.keyEquivalent = "\r"
        startButton.target = self
        startButton.action = #selector(startOrCancel)
        startButton.widthAnchor.constraint(equalToConstant: 252).isActive = true
        startButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        window.defaultButtonCell = startButton.cell as? NSButtonCell
        let startRow = centered(startButton)
        column.addArrangedSubview(startRow)
        startRow.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        column.setCustomSpacing(10, after: startRow)

        previewButton.bezelStyle = .inline
        previewButton.font = .systemFont(ofSize: 12)
        previewButton.contentTintColor = .secondaryLabelColor
        previewButton.target = self
        previewButton.action = #selector(preview)
        let previewRow = centered(previewButton)
        column.addArrangedSubview(previewRow)
        previewRow.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
    }

    private func permissionRow(_ title: String, status: NSTextField, button: NSButton) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        status.font = .systemFont(ofSize: 11)
        status.setContentHuggingPriority(.required, for: .horizontal)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        return horizontal([label, spacer(), status, button], spacing: 10)
    }

    private func infoRow(_ icon: String, _ text: String) -> NSStackView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return horizontal([symbol(icon, size: 14, color: .secondaryLabelColor), label], spacing: 9)
    }

    private func card(_ content: NSView) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0.5
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor
        box.cornerRadius = 10
        box.contentViewMargins = .zero
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
        ])
        return box
    }

    private func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImageView {
        let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil)!)
        view.symbolConfiguration = .init(pointSize: size, weight: .regular)
        view.contentTintColor = color
        return view
    }

    private func vertical(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        for view in views { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return stack
    }

    private func horizontal(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private func centered(_ view: NSView) -> NSView {
        let row = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            view.topAnchor.constraint(equalTo: row.topAnchor),
            view.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    @objc private func openAccessibility() { coordinator.openPermission(true) }
    @objc private func openMonitoring() { coordinator.openPermission(false) }
    @objc private func startOrCancel() { coordinator.isBusy ? coordinator.cancel() : coordinator.begin() }
    @objc private func preview() { coordinator.begin(preview: true) }
}
