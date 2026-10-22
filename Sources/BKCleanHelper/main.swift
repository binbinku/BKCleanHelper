import AppKit
import Darwin
import Foundation

// The worker may close its command pipe while the UI is sending a final stop.
// Let FileHandle report EPIPE instead of terminating the menu-bar application.
signal(SIGPIPE, SIG_IGN)

// A separate instance of the same signed executable owns the event tap.
// --simulate exercises its lifecycle without permissions or intercepted input.
if CommandLine.arguments.contains("--input-worker") {
    let simulated = CommandLine.arguments.contains("--simulate")
    let worker = InputWorker(simulated: simulated)
    exit(worker.run())
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
