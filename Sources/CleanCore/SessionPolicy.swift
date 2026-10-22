import Darwin
import Foundation

/// Continuous, monotonic seconds, including time spent asleep.
public enum SessionTime {
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    public static var now: Double { Double(mach_continuous_time()) * secondsPerTick }
}

public struct CleaningDeadline: Sendable {
    public static let duration: Double = 60
    public let end: Double

    public init(start: Double, duration: Double = Self.duration) {
        end = start + max(0, duration)
    }

    public func hasExpired(at now: Double) -> Bool { now >= end }
    public func secondsRemaining(at now: Double) -> Int { Int(ceil(max(0, end - now))) }
    public func fractionRemaining(at now: Double, duration: Double = Self.duration) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, (end - now) / duration))
    }
}

/// Physical U + Control + Option + Command, continuously held for two seconds.
/// Repeated keyDown events must never restart the hold timer.
public struct EmergencyUnlock: Sendable {
    public static let keyCode: Int64 = 32
    private var uIsDown = false
    private var modifiersAreDown = false
    private var heldSince: Double?

    public init() {}

    public mutating func update(keyCode: Int64?, isDown: Bool?, modifiers: Bool, at now: Double) {
        if keyCode == Self.keyCode, let isDown { uIsDown = isDown }
        if let keyCode, keyCode != Self.keyCode, isDown == true {
            // Require a fresh U press after another character is pressed.
            uIsDown = false
        }
        modifiersAreDown = modifiers
        if uIsDown && modifiersAreDown {
            if heldSince == nil { heldSince = now }
        } else {
            heldSince = nil
        }
    }

    public func shouldUnlock(at now: Double) -> Bool {
        guard let heldSince, uIsDown, modifiersAreDown else { return false }
        return now - heldSince >= 2
    }
}

public enum WorkerMessageKind: String, Codable, Sendable {
    case ready, heartbeat, stopped, error
}

public struct WorkerMessage: Codable, Sendable {
    public let kind: WorkerMessageKind
    public let deadline: Double?
    public let detail: String?

    public init(_ kind: WorkerMessageKind, deadline: Double? = nil, detail: String? = nil) {
        self.kind = kind
        self.deadline = deadline
        self.detail = detail
    }

    public func line() -> Data {
        var data = (try? JSONEncoder().encode(self)) ?? Data()
        data.append(0x0A)
        return data
    }
}

/// Shared by the pipe reader and background watchdog; neither needs the UI thread.
public final class WorkerHealth: @unchecked Sendable {
    private let lock = NSLock()
    private var lastMessage: Double
    private var finished = false
    private let hardDeadline: Double

    public init(now: Double) {
        lastMessage = now
        hardDeadline = now + CleaningDeadline.duration + 4
    }

    public func received(at now: Double) {
        lock.lock(); defer { lock.unlock() }
        lastMessage = now
    }

    public func finish() {
        lock.lock(); defer { lock.unlock() }
        finished = true
    }

    public func needsTermination(at now: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !finished && (now - lastMessage > 2 || now >= hardDeadline)
    }
}
