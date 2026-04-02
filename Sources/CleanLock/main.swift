import Cocoa
import Foundation

// MARK: - Constants

let version = "0.1.0"
let pidFilePath = "/tmp/cleanlock.pid"

// MARK: - Exit Codes

enum ExitCode: Int32 {
    case success = 0
    case generalError = 1
    case permissionDenied = 2
    case noActiveSession = 3
}

// MARK: - Duration Parsing

/// Parses a duration string into seconds.
/// Supported formats: `30`, `30s`, `2m`, `1m30s`, `90s`
func parseDuration(_ input: String) -> Int? {
    let trimmed = input.trimmingCharacters(in: .whitespaces)

    // Plain number → seconds
    if let seconds = Int(trimmed) {
        return seconds > 0 ? seconds : nil
    }

    // Regex: optional minutes + optional seconds (e.g., "2m", "30s", "1m30s")
    var total = 0
    var matched = false

    // Match minutes
    if let range = trimmed.range(of: #"(\d+)m"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast() // drop "m"
        if let mins = Int(digits) {
            total += mins * 60
            matched = true
        }
    }

    // Match seconds
    if let range = trimmed.range(of: #"(\d+)s"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast() // drop "s"
        if let secs = Int(digits) {
            total += secs
            matched = true
        }
    }

    return matched && total > 0 ? total : nil
}

// MARK: - PID File IPC

func writePIDFile() {
    let pid = ProcessInfo.processInfo.processIdentifier
    try? String(pid).write(toFile: pidFilePath, atomically: true, encoding: .utf8)
}

func removePIDFile() {
    try? FileManager.default.removeItem(atPath: pidFilePath)
}

func readPIDFile() -> pid_t? {
    guard let contents = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
          let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
        return nil
    }
    return pid
}

// MARK: - Cancel Active Session

func cancelActiveSession() -> Never {
    guard let pid = readPIDFile() else {
        fputs("Error: No active CleanLock session found.\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    // Check if the process is actually running
    if kill(pid, 0) != 0 {
        removePIDFile()
        fputs("Error: No active CleanLock session found (stale PID file removed).\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    kill(pid, SIGTERM)
    print("Cancelled CleanLock session (PID: \(pid)).")
    exit(ExitCode.success.rawValue)
}

// MARK: - Help & Version

func printHelp() -> Never {
    print("""
    USAGE: cleanlock [duration] [options]

    Temporarily disable keyboard and trackpad input while cleaning your Mac.

    ARGUMENTS:
      duration          Lock duration. Examples: 30, 30s, 2m, 1m30s (default: 60s)

    OPTIONS:
      --cancel          Cancel an active lock session
      --keyboard-only   Block keyboard only, not trackpad
      --no-overlay      Skip the full-screen overlay UI
      -h, --help        Show this help
      -v, --version     Show version
    """)
    exit(ExitCode.success.rawValue)
}

func printVersion() -> Never {
    print("cleanlock \(version)")
    exit(ExitCode.success.rawValue)
}

// MARK: - Signal Handling

func setupSignalHandlers() {
    let handler: @convention(c) (Int32) -> Void = { _ in
        InputBlocker.shared.stopBlocking()
        removePIDFile()
        exit(ExitCode.success.rawValue)
    }
    signal(SIGTERM, handler)
    signal(SIGINT, handler)
}

// MARK: - Main

func main() {
    let args = Array(CommandLine.arguments.dropFirst())

    // Parse flags
    var duration: Int = 60
    var keyboardOnly = false
    var noOverlay = false

    var positionalArgs: [String] = []

    for arg in args {
        switch arg {
        case "--help", "-h":
            printHelp()
        case "--version", "-v":
            printVersion()
        case "--cancel":
            cancelActiveSession()
        case "--keyboard-only":
            keyboardOnly = true
        case "--no-overlay":
            noOverlay = true
        default:
            if arg.hasPrefix("-") {
                fputs("Error: Unknown option '\(arg)'. Use --help for usage.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            positionalArgs.append(arg)
        }
    }

    // Parse duration from positional argument
    if let durationArg = positionalArgs.first {
        guard let parsed = parseDuration(durationArg) else {
            fputs("Error: Invalid duration '\(durationArg)'. Examples: 30, 30s, 2m, 1m30s\n", stderr)
            exit(ExitCode.generalError.rawValue)
        }
        duration = parsed
    }

    // Check accessibility permission
    if !InputBlocker.checkAccessibility() {
        if !InputBlocker.waitForAccessibility(timeout: 30) {
            fputs("Error: Accessibility permission is required.\n", stderr)
            exit(ExitCode.permissionDenied.rawValue)
        }
    }

    // Set up signal handlers for clean exit
    setupSignalHandlers()

    // Write PID file
    writePIDFile()

    // Countdown before locking — gives time to switch windows for testing
    print("CleanLock will activate in 3 seconds for \(formatDuration(duration))...")
    for i in (1...3).reversed() {
        print("  \(i)...")
        Thread.sleep(forTimeInterval: 1.0)
    }

    // Start blocking
    do {
        try InputBlocker.shared.startBlocking(keyboardOnly: keyboardOnly)
    } catch {
        fputs("Error: \(error)\n", stderr)
        removePIDFile()
        exit(ExitCode.generalError.rawValue)
    }

    print("Locked! Press ⌘⌥⌃L for 3 seconds to cancel.")

    // Show overlay if requested
    var overlayController: CountdownWindowController?
    if !noOverlay {
        overlayController = CountdownWindowController(duration: duration)
        overlayController?.showOverlay()
    }

    // Listen for emergency cancel
    var cancelled = false
    let observer = NotificationCenter.default.addObserver(
        forName: .cleanLockEmergencyCancel, object: nil, queue: .main
    ) { _ in
        cancelled = true
        print("\nEmergency cancel triggered.")
        overlayController?.closeOverlay()
        removePIDFile()
        exit(ExitCode.success.rawValue)
    }

    // Schedule auto-unlock after duration
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
        guard !cancelled else { return }
        InputBlocker.shared.stopBlocking()
        overlayController?.closeOverlay()
        removePIDFile()
        print("\nCleanLock session ended.")
        exit(ExitCode.success.rawValue)
    }

    // Run the main run loop (required for CGEvent tap + overlay)
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()

    _ = observer // keep the observer alive
}

/// Format seconds into a human-readable string.
func formatDuration(_ seconds: Int) -> String {
    if seconds >= 60 {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(mins)m"
        }
        return "\(mins)m\(secs)s"
    }
    return "\(seconds)s"
}

main()
