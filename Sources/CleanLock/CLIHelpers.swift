import Foundation

// MARK: - Constants

let version = "0.1.0"
let maxSafetyDuration = 300 // 5 minutes

let pidFilePath: String = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let dir = cacheDir.appendingPathComponent("cleanlock")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("cleanlock.pid").path
}()

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

    if let seconds = Int(trimmed) {
        return seconds > 0 ? seconds : nil
    }

    var total = 0
    var matched = false

    if let range = trimmed.range(of: #"(\d+)m"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast()
        if let mins = Int(digits) {
            total += mins * 60
            matched = true
        }
    }

    if let range = trimmed.range(of: #"(\d+)s"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast()
        if let secs = Int(digits) {
            total += secs
            matched = true
        }
    }

    return matched && total > 0 ? total : nil
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

// MARK: - Color Parsing

/// Parse a color name or hex string into RGB components.
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

// MARK: - PID File IPC

/// Check if another CleanLock instance is running.
func checkExistingInstance() -> Bool {
    guard let pid = readPIDFile() else { return false }
    // kill(pid, 0) checks if process exists without sending a signal
    return kill(pid, 0) == 0
}

func writePIDFile() {
    let pid = ProcessInfo.processInfo.processIdentifier
    do {
        try String(pid).write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    } catch {
        fputs("Warning: Could not write PID file: \(error.localizedDescription)\n", stderr)
    }
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
