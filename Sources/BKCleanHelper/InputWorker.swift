import ApplicationServices
import AppKit
import CleanCore
import Darwin
import Foundation

/// All tap state lives on the main CFRunLoop of this subprocess, never the UI's.
final class InputWorker {
    private let simulated: Bool
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var deadline: CleaningDeadline?
    private var emergencyUnlock = EmergencyUnlock()
    private var pendingStop: String?
    private var stopped = false
    private var lastHeartbeat = 0.0
    private var exitStatus: Int32 = 0
    private var observers: [NSObjectProtocol] = []
    private let runLoop = CFRunLoopGetMain()!

    init(simulated: Bool) { self.simulated = simulated }

    func run() -> Int32 {
        // A dead pipe should release the tap, never crash while holding resources.
        signal(SIGPIPE, SIG_IGN)
        guard simulated || (AXIsProcessTrusted() && CGPreflightListenEventAccess()) else {
            send(.init(.error, detail: "请先在系统设置中允许“BKCleanHelper”的辅助功能和输入监控权限。"))
            return 2
        }
        if !simulated && !installTap() {
            send(.init(.error, detail: "系统未允许建立完整的输入拦截，请检查权限后重新打开“BKCleanHelper”。"))
            cleanup()
            return 3
        }

        let now = SessionTime.now
        var duration = CleaningDeadline.duration
        if simulated,
           let index = CommandLine.arguments.firstIndex(of: "--duration"),
           CommandLine.arguments.indices.contains(index + 1),
           let requested = Double(CommandLine.arguments[index + 1]), requested.isFinite {
            duration = min(60, max(0.05, requested))
        }
        deadline = CleaningDeadline(start: now, duration: duration)
        lastHeartbeat = now
        send(.init(.ready, deadline: deadline?.end))
        watchParentPipe()
        observeSessionChanges()

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        CFRunLoopRun()
        cleanup()
        return exitStatus
    }

    private func installTap() -> Bool {
        let context = Unmanaged.passUnretained(self).toOpaque()
        // HID placement is needed before Mission Control / system shortcut handling.
        // Do not silently fall back to a later tap with weaker coverage.
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask.max,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<InputWorker>.fromOpaque(context).takeUnretainedValue()
                    .handle(type: type, event: event)
            }, userInfo: context
        ) else { return false }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
        self.source = source
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let now = SessionTime.now
        if stopped || deadline?.hasExpired(at: now) == true {
            if !stopped { pendingStop = "completed" }
            // Even a delayed timer can never extend the input lock.
            return Unmanaged.passUnretained(event)
        }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // A coverage interruption ends the session; don't show a false lock state.
            pendingStop = "tapDisabled"
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown || type == .keyUp || type == .flagsChanged {
            let modifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
            emergencyUnlock.update(
                keyCode: type == .flagsChanged ? nil : event.getIntegerValueField(.keyboardEventKeycode),
                isDown: type == .flagsChanged ? nil : type == .keyDown,
                modifiers: event.flags.intersection(modifiers) == modifiers, at: now
            )
        }
        // Includes all mouse, scroll, system-defined and delivered gesture events.
        // No input content is logged, replayed, or transmitted.
        return nil
    }

    private func tick() {
        let now = SessionTime.now
        if let reason = pendingStop { stop(reason); return }
        if deadline?.hasExpired(at: now) == true { stop("completed"); return }
        if emergencyUnlock.shouldUnlock(at: now) { stop("emergency"); return }
        if !simulated {
            guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { stop("permissionLost"); return }
            if let tap, !CGEvent.tapIsEnabled(tap: tap) { stop("tapDisabled"); return }
            if CGSessionCopyCurrentDictionary() == nil { stop("sessionChanged"); return }
        }
        if now - lastHeartbeat >= 0.25 {
            lastHeartbeat = now
            send(.init(.heartbeat))
        }
    }

    private func watchParentPipe() {
        let runLoop = self.runLoop
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = Data()
            while true {
                let data = FileHandle.standardInput.availableData
                if data.isEmpty {
                    CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { self?.stop("parentExited") }
                    CFRunLoopWakeUp(runLoop)
                    return
                }
                buffer.append(data)
                if buffer.count > 4096 {
                    CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { self?.stop("invalidCommand") }
                    CFRunLoopWakeUp(runLoop)
                    return
                }
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let command = String(decoding: buffer[..<newline], as: UTF8.self)
                    buffer.removeSubrange(...newline)
                    if command == "stop" {
                        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { self?.stop("cancelled") }
                        CFRunLoopWakeUp(runLoop)
                        return
                    }
                }
            }
        }
    }

    private func observeSessionChanges() {
        guard !simulated else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.stop("sessionChanged")
            })
        }
        for rawName in ["com.apple.screenIsLocked", "com.apple.sessionDidMoveOffConsole"] {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name(rawName), object: nil, queue: .main
            ) { [weak self] _ in self?.stop("sessionChanged") })
        }
    }

    private func stop(_ reason: String) {
        guard !stopped else { return }
        stopped = true
        // Release first, then notify the UI. A failed notification must not hold input.
        cleanup()
        send(.init(.stopped, detail: reason))
        CFRunLoopStop(runLoop)
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(runLoop, source, .commonModes) }
        tap = nil
        source = nil
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()
    }

    private func send(_ message: WorkerMessage) {
        do { try FileHandle.standardOutput.write(contentsOf: message.line()) }
        catch {
            exitStatus = 4
            // Parent disappeared; exiting also invalidates any tap at the OS level.
            cleanup()
            exit(4)
        }
    }
}
