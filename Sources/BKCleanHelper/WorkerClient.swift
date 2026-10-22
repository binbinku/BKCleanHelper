import CleanCore
import Darwin
import Foundation

/// Main-thread API; pipe reading and the watchdog run independently of AppKit.
final class WorkerClient {
    var onMessage: (@MainActor (WorkerMessage) -> Void)?
    var onExit: (@MainActor (Int32) -> Void)?
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let health = WorkerHealth(now: SessionTime.now)
    private var watchdog: DispatchSourceTimer?
    private var stopping = false

    func launch(preview: Bool) throws {
        guard let executable = Bundle.main.executableURL else { throw ClientError.missingExecutable }
        process.executableURL = executable
        process.arguments = preview
            ? ["--input-worker", "--simulate", "--duration", "8"]
            : ["--input-worker"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
        startReader()
        startWatchdog()
    }

    func stop() {
        guard !stopping else { return }
        stopping = true
        try? input.fileHandleForWriting.write(contentsOf: Data("stop\n".utf8))
        try? input.fileHandleForWriting.close()
        // If its run loop is wedged, destroying our own subprocess releases the tap.
        let process = self.process
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    private func startReader() {
        let handle = output.fileHandleForReading
        let process = self.process
        let health = self.health
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = Data()
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                buffer.append(data)
                if buffer.count > 65_536 {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    break
                }
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = Data(buffer[..<newline])
                    buffer.removeSubrange(...newline)
                    guard let message = try? JSONDecoder().decode(WorkerMessage.self, from: line) else { continue }
                    health.received(at: SessionTime.now)
                    Task { @MainActor [weak self] in self?.onMessage?(message) }
                }
            }
            process.waitUntilExit()
            health.finish()
            let status = process.terminationStatus
            Task { @MainActor [weak self] in self?.onExit?(status) }
        }
    }

    private func startWatchdog() {
        let process = self.process
        let health = self.health
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + 0.5, repeating: 0.25)
        timer.setEventHandler {
            if process.isRunning && health.needsTermination(at: SessionTime.now) {
                kill(process.processIdentifier, SIGKILL)
                health.finish()
            }
        }
        watchdog = timer
        timer.resume()
    }

    deinit {
        watchdog?.cancel()
        try? input.fileHandleForWriting.close()
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }

    enum ClientError: LocalizedError {
        case missingExecutable
        var errorDescription: String? { "找不到输入拦截程序，请重新构建或安装“BKCleanHelper”。" }
    }
}
