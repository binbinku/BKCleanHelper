import XCTest
@testable import CleanCore

final class SessionPolicyTests: XCTestCase {
    func testDeadlineExpiresAtExactlySixtySeconds() {
        let deadline = CleaningDeadline(start: 100)
        XCTAssertEqual(deadline.secondsRemaining(at: 100), 60)
        XCTAssertEqual(deadline.secondsRemaining(at: 159.01), 1)
        XCTAssertFalse(deadline.hasExpired(at: 159.999))
        XCTAssertTrue(deadline.hasExpired(at: 160))
        XCTAssertEqual(deadline.secondsRemaining(at: 180), 0)
        XCTAssertEqual(deadline.fractionRemaining(at: 180), 0)
    }

    func testClockJumpPastDeadlineCannotExtendLock() {
        let deadline = CleaningDeadline(start: 100)
        XCTAssertTrue(deadline.hasExpired(at: 1000))
        XCTAssertEqual(deadline.secondsRemaining(at: 1000), 0)
    }

    func testEmergencyUnlockRequiresContinuousChord() {
        var chord = EmergencyUnlock()
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 10)
        XCTAssertFalse(chord.shouldUnlock(at: 11.99))
        XCTAssertTrue(chord.shouldUnlock(at: 12))
        chord.update(keyCode: 32, isDown: false, modifiers: true, at: 12.1)
        XCTAssertFalse(chord.shouldUnlock(at: 20))
    }

    func testAutoRepeatDoesNotResetEmergencyHold() {
        var chord = EmergencyUnlock()
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 10)
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 11)
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 11.9)
        XCTAssertTrue(chord.shouldUnlock(at: 12))
    }

    func testModifierReleaseResetsEmergencyHold() {
        var chord = EmergencyUnlock()
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 10)
        chord.update(keyCode: nil, isDown: nil, modifiers: false, at: 11)
        XCTAssertFalse(chord.shouldUnlock(at: 20))
        chord.update(keyCode: nil, isDown: nil, modifiers: true, at: 20)
        XCTAssertFalse(chord.shouldUnlock(at: 21.99))
        XCTAssertTrue(chord.shouldUnlock(at: 22))
    }

    func testUnrelatedKeyCannotTriggerEmergencyUnlock() {
        var chord = EmergencyUnlock()
        chord.update(keyCode: 32, isDown: true, modifiers: false, at: 10)
        XCTAssertFalse(chord.shouldUnlock(at: 20))
        chord.update(keyCode: 32, isDown: true, modifiers: true, at: 30)
        chord.update(keyCode: 0, isDown: true, modifiers: true, at: 31)
        XCTAssertFalse(chord.shouldUnlock(at: 40))
    }

    func testWatchdogDetectsMissingHeartbeatsAndAbsoluteDeadline() {
        let health = WorkerHealth(now: 10)
        XCTAssertFalse(health.needsTermination(at: 12))
        XCTAssertTrue(health.needsTermination(at: 12.01))
        health.received(at: 73.9)
        XCTAssertFalse(health.needsTermination(at: 73.99))
        XCTAssertTrue(health.needsTermination(at: 74))
        health.finish()
        health.finish()
        XCTAssertFalse(health.needsTermination(at: 100))
    }

    func testWorkerProtocolRoundTrip() throws {
        let message = WorkerMessage(.ready, deadline: 123.5, detail: "就绪")
        let line = message.line()
        XCTAssertEqual(line.last, 0x0A)
        let decoded = try JSONDecoder().decode(WorkerMessage.self, from: line.dropLast())
        XCTAssertEqual(decoded.kind, .ready)
        XCTAssertEqual(decoded.deadline, 123.5)
        XCTAssertEqual(decoded.detail, "就绪")
    }
}
