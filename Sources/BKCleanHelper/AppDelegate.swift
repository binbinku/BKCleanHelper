import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var coordinator: CleaningCoordinator!
    private var mainWindow: MainWindowController!
    private var statusItem: NSStatusItem!
    private let actionItem = NSMenuItem(title: "开始清洁（60 秒）", action: #selector(toggleCleaning), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "键盘与触摸板清洁工具", action: nil, keyEquivalent: "")
    private var permissionTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening the bundle should reuse its one menu-bar instance.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        coordinator = CleaningCoordinator()
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            coordinator.previousApplication = front
        }
        mainWindow = MainWindowController(coordinator: coordinator)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "BKCleanHelper：键盘清洁")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.toolTip = "BKCleanHelper · 暂停输入一分钟"
        let menu = NSMenu()
        menu.autoenablesItems = false
        stateItem.isEnabled = false
        menu.delegate = self
        menu.addItem(stateItem)
        menu.addItem(.separator())
        actionItem.target = self
        menu.addItem(actionItem)
        let show = NSMenuItem(title: "打开BKCleanHelper…", action: #selector(showMain), keyEquivalent: ",")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出BKCleanHelper", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        coordinator.onChange = { [weak self] in self?.update() }
        installApplicationMenu()
        observeEnvironment()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.coordinator.refreshPermissions() }
        }
        mainWindow.present()
        update()
        if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.coordinator.begin(preview: true) }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if coordinator?.isBusy == false { mainWindow.present() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
        permissionTimer?.invalidate()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func menuWillOpen(_ menu: NSMenu) { coordinator.refreshPermissions(); update() }

    private func update() {
        mainWindow.update()
        let busy = coordinator.isBusy
        actionItem.title = busy ? "结束清洁并恢复输入" : "开始清洁（60 秒）"
        actionItem.isEnabled = busy || coordinator.ready
        statusItem.button?.title = busy ? " \(coordinator.remaining)s" : ""
        switch coordinator.phase {
        case .idle: stateItem.title = "键盘与触摸板清洁工具"
        case .preparing: stateItem.title = "\(coordinator.remaining) 秒后开始"
        case .acquiring: stateItem.title = "正在准备输入拦截…"
        case .cleaning: stateItem.title = coordinator.isPreview ? "界面预览中" : "清洁模式已开启"
        case .stopping: stateItem.title = "正在恢复输入…"
        }
    }

    private func installApplicationMenu() {
        let menu = NSMenu()
        let app = NSMenuItem()
        let submenu = NSMenu()
        let about = NSMenuItem(title: "关于BKCleanHelper", action: #selector(about), keyEquivalent: "")
        about.target = self
        submenu.addItem(about)
        submenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出BKCleanHelper", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        submenu.addItem(quit)
        app.submenu = submenu
        menu.addItem(app)
        NSApp.mainMenu = menu
    }

    private func observeEnvironment() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                               object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular else { return }
            Task { @MainActor [weak self] in self?.coordinator.previousApplication = app }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.coordinator.sessionChanged() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.coordinator.displaysChanged() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.coordinator.sessionChanged() } })
    }

    @objc private func showMain() { if !coordinator.isBusy { mainWindow.present() } }
    @objc private func toggleCleaning() { coordinator.isBusy ? coordinator.cancel() : coordinator.begin() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "BKCleanHelper", .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "一分钟，安心擦一擦。\n键盘与触摸板清洁工具 · 完全本地运行"),
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
