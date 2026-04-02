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
      duration          Lock duration. Examples: 30, 30s, 2m, 1m30s
                        No duration = lock until cancelled (safety auto-unlock: 5m)

    OPTIONS:
      --cancel          Cancel an active lock session
      --keyboard-only   Block keyboard only, not trackpad
      --no-overlay      Skip the full-screen overlay UI
      --delay <seconds> Wait before activating lock
      --color <value>   Overlay color: name (black, red, blue...) or hex (000, #fff, FF0000)
      --silent          Disable sound effects
      --dim             Reduce screen brightness to minimum during lock
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
        BrightnessControl.shared.restore()
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
    let maxSafetyDuration = 300 // 5 minutes
    var duration: Int? = nil
    var keyboardOnly = false
    var noOverlay = false
    var delay: Int = 0
    var overlayColorHex: String? = nil
    var silent = false
    var dim = false

    var positionalArgs: [String] = []
    var i = 0

    while i < args.count {
        let arg = args[i]
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
        case "--delay":
            i += 1
            guard i < args.count, let d = Int(args[i]), d > 0 else {
                fputs("Error: --delay requires a positive number of seconds.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            delay = d
        case "--color":
            i += 1
            guard i < args.count else {
                fputs("Error: --color requires a hex value (e.g. 000000, FF0000).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            overlayColorHex = args[i]
        case "--silent":
            silent = true
        case "--dim":
            dim = true
        default:
            if arg.hasPrefix("-") {
                fputs("Error: Unknown option '\(arg)'. Use --help for usage.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            positionalArgs.append(arg)
        }
        i += 1
    }

    // Parse duration from positional argument
    if let durationArg = positionalArgs.first {
        guard let parsed = parseDuration(durationArg) else {
            fputs("Error: Invalid duration '\(durationArg)'. Examples: 30, 30s, 2m, 1m30s\n", stderr)
            exit(ExitCode.generalError.rawValue)
        }
        duration = parsed
    }

    // Effective duration: user-specified or safety max
    let effectiveDuration = duration ?? maxSafetyDuration

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

    // Countdown before locking
    if delay > 0 {
        let durationText = duration == nil
            ? "until cancelled (safety: \(formatDuration(maxSafetyDuration)))"
            : formatDuration(effectiveDuration)
        print("CleanLock will activate in \(delay) seconds for \(durationText)...")
        for i in (1...delay).reversed() {
            print("  \(i)...")
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    // Start blocking
    do {
        try InputBlocker.shared.startBlocking(keyboardOnly: keyboardOnly)
    } catch {
        fputs("Error: \(error)\n", stderr)
        removePIDFile()
        exit(ExitCode.generalError.rawValue)
    }

    if dim { BrightnessControl.shared.dim() }
    if !silent { playSound("Tink") }

    if duration == nil {
        print("Locked until cancelled! Safety auto-unlock in \(formatDuration(maxSafetyDuration)). Press ⌘⌥⌃L for 3 seconds to cancel.")
    } else {
        print("Locked for \(formatDuration(effectiveDuration))! Press ⌘⌥⌃L for 3 seconds to cancel.")
    }

    // Show overlay if requested
    var overlayController: CountdownWindowController?
    if !noOverlay {
        let color = overlayColorHex.flatMap { parseColor($0) }
        overlayController = CountdownWindowController(
            duration: effectiveDuration,
            backgroundColor: color
        )
        overlayController?.showOverlay()
    }

    // Listen for emergency cancel
    var cancelled = false
    let observer = NotificationCenter.default.addObserver(
        forName: .cleanLockEmergencyCancel, object: nil, queue: .main
    ) { _ in
        cancelled = true
        BrightnessControl.shared.restore()
        if !silent { playSound("Glass") }
        print("\nEmergency cancel triggered.")
        overlayController?.closeOverlay()
        removePIDFile()
        exit(ExitCode.success.rawValue)
    }

    // Schedule auto-unlock after duration
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(effectiveDuration)) {
        guard !cancelled else { return }
        InputBlocker.shared.stopBlocking()
        BrightnessControl.shared.restore()
        if !silent { playSound("Glass") }
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

/// Play a system sound by name. Does nothing if sound not found.
func playSound(_ name: String) {
    NSSound(named: NSSound.Name(name))?.play()
}

/// Parse a hex color string (e.g. "000000", "FF0000") into RGB components.
func parseColor(_ input: String) -> (r: Double, g: Double, b: Double)? {
    let namedColors: [String: (r: Double, g: Double, b: Double)] = [
        "black": (0, 0, 0),
        "white": (1, 1, 1),
        "red": (1, 0, 0),
        "green": (0, 0.8, 0),
        "blue": (0, 0, 1),
        "yellow": (1, 1, 0),
        "orange": (1, 0.65, 0),
        "purple": (0.5, 0, 0.5),
        "gray": (0.5, 0.5, 0.5),
        "grey": (0.5, 0.5, 0.5),
    ]

    if let named = namedColors[input.lowercased()] {
        return named
    }

    // Hex parsing: fff, #fff, ffffff, #ffffff
    var clean = input.hasPrefix("#") ? String(input.dropFirst()) : input
    if clean.count == 3 {
        clean = clean.map { "\($0)\($0)" }.joined()
    }
    guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
    return (
        r: Double((value >> 16) & 0xFF) / 255.0,
        g: Double((value >> 8) & 0xFF) / 255.0,
        b: Double(value & 0xFF) / 255.0
    )
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
