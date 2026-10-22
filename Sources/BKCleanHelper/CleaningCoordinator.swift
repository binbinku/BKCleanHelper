import AppKit
import ApplicationServices
import CleanCore

@MainActor
final class CleaningCoordinator {
    enum Phase { case idle, preparing, acquiring, cleaning, stopping }

    var onChange: (() -> Void)?
    private(set) var phase: Phase = .idle
    private(set) var isPreview = false
    private(set) var remaining = 60
    private(set) var notice = ""
    private(set) var accessibilityAllowed = false
    private(set) var inputMonitoringAllowed = false
    var ready: Bool { accessibilityAllowed && inputMonitoringAllowed }
    var isBusy: Bool { phase != .idle }

    weak var mainWindow: NSWindow?
    var previousApplication: NSRunningApplication?
    private var worker: WorkerClient?
    private var ticker: Timer?
    private var prepareUntil = 0.0
    private var acquireStartedAt = 0.0
    private var cleaningUntil = 0.0
    private var overlay: CleaningOverlay?

    init() { refreshPermissions() }

    func refreshPermissions() {
        let accessibility = AXIsProcessTrusted()
        let monitoring = CGPreflightListenEventAccess()
        if accessibility != accessibilityAllowed || monitoring != inputMonitoringAllowed {
            accessibilityAllowed = accessibility
            inputMonitoringAllowed = monitoring
            onChange?()
        }
    }

    func openPermission(_ accessibility: Bool) {
        if accessibility {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            _ = CGRequestListenEventAccess()
        }
        let pane = accessibility ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func begin(preview: Bool = false) {
        guard !isBusy else { return }
        refreshPermissions()
        guard preview || ready else {
            notice = "请先完成下方两项权限设置。"
            onChange?()
            return
        }
        notice = ""
        isPreview = preview
        phase = .preparing
        remaining = 3
        prepareUntil = SessionTime.now + 3
        onChange?()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        guard isBusy else { return }
        finish(notice: "已结束，输入已恢复。")
    }

    func sessionChanged() {
        guard isBusy else { return }
        finish(notice: "本轮清洁已结束，输入已恢复。")
    }

    func displaysChanged() {
        guard phase == .cleaning else { return }
        overlay?.close()
        overlay = CleaningOverlay(preview: isPreview)
        updateCountdown()
        overlay?.show()
    }

    func shutdown() {
        ticker?.invalidate()
        ticker = nil
        worker?.stop()
        worker = nil
        overlay?.close()
        overlay = nil
    }

    private func tick() {
        switch phase {
        case .preparing:
            let next = max(0, Int(ceil(prepareUntil - SessionTime.now)))
            if next != remaining { remaining = next; onChange?() }
            if next == 0 {
                phase = .acquiring
                acquireStartedAt = SessionTime.now
                onChange?()
            }
        case .acquiring:
            if worker != nil { return }
            // Never swallow the release of a key/button pressed before locking.
            if !isPreview && anyInputIsHeld() {
                if SessionTime.now - acquireStartedAt > 8 {
                    finish(notice: "请松开所有按键和鼠标按钮，再开始清洁。")
                }
                return
            }
            startWorker()
        case .cleaning:
            updateCountdown()
            if SessionTime.now >= cleaningUntil {
                finish(notice: isPreview ? "预览结束。" : "清洁完成，输入已恢复。")
            }
        case .idle, .stopping: break
        }
    }

    private func anyInputIsHeld() -> Bool {
        for code in 0..<128 where CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(code)) { return true }
        for raw in 0..<5 {
            if let button = CGMouseButton(rawValue: UInt32(raw)),
               CGEventSource.buttonState(.combinedSessionState, button: button) { return true }
        }
        return false
    }

    private func startWorker() {
        let client = WorkerClient()
        worker = client
        client.onMessage = { [weak self, weak client] message in
            guard let self, let client, self.worker === client else { return }
            self.handle(message)
        }
        client.onExit = { [weak self, weak client] status in
            guard let self, let client, self.worker === client, self.isBusy else { return }
            self.finish(notice: status == 0 ? "本轮清洁已结束，输入已恢复。" : "清洁模式意外中断，输入已恢复。请重新检查权限。")
        }
        do { try client.launch(preview: isPreview) }
        catch { finish(notice: error.localizedDescription) }
    }

    private func handle(_ message: WorkerMessage) {
        switch message.kind {
        case .ready:
            guard phase == .acquiring, let deadline = message.deadline else { return }
            phase = .cleaning
            cleaningUntil = deadline
            overlay = CleaningOverlay(preview: isPreview)
            updateCountdown()
            mainWindow?.orderOut(nil)
            // Nonactivating, click-through panels never become an extra input lock.
            previousApplication?.activate(options: [])
            overlay?.show()
            onChange?()
        case .heartbeat: break
        case .error:
            finish(notice: message.detail ?? "无法启用清洁模式，请检查系统权限。")
        case .stopped:
            let text: String
            switch message.detail {
            case "completed": text = isPreview ? "预览结束。" : "清洁完成，输入已恢复。"
            case "emergency": text = "已提前结束，输入已恢复。"
            case "permissionLost": text = "权限发生变化，清洁已中断，输入已恢复。"
            case "tapDisabled": text = "系统中断了输入拦截，清洁已停止。请勿继续擦拭。"
            default: text = "本轮清洁已结束，输入已恢复。"
            }
            finish(notice: text)
        }
    }

    private func updateCountdown() {
        let next = max(0, Int(ceil(cleaningUntil - SessionTime.now)))
        let fraction = max(0, min(1, (cleaningUntil - SessionTime.now) / (isPreview ? 8 : 60)))
        overlay?.update(seconds: next, fraction: fraction)
        if next != remaining { remaining = next; onChange?() }
    }

    private func finish(notice: String) {
        guard phase != .idle else { return }
        let returnToPreviewWindow = isPreview && phase == .cleaning
        phase = .stopping
        ticker?.invalidate()
        ticker = nil
        let client = worker
        worker = nil
        client?.stop()
        overlay?.close()
        overlay = nil
        self.notice = notice
        remaining = 60
        phase = .idle
        refreshPermissions()
        onChange?()
        if returnToPreviewWindow {
            mainWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
