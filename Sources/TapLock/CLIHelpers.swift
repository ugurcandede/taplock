import TapLockCore
import Foundation

// MARK: - Constants

let version = "0.1.0"
let maxSafetyDuration = 300 // 5 minutes
let defaultRelaxInterval = 25 * 60  // 25 minutes
let defaultRelaxDuration = 5 * 60   // 5 minutes

let pidFilePath: String = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let dir = cacheDir.appendingPathComponent("taplock")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("taplock.pid").path
}()

// MARK: - Exit Codes

enum ExitCode: Int32 {
    case success = 0
    case generalError = 1
    case permissionDenied = 2
    case noActiveSession = 3
}

// MARK: - PID File IPC

/// Check if another TapLock instance is running.
func checkExistingInstance() -> Bool {
    guard let pid = readPIDFile() else { return false }
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
        fputs("Error: No active TapLock session found.\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    if kill(pid, 0) != 0 {
        removePIDFile()
        fputs("Error: No active TapLock session found (stale PID file removed).\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    kill(pid, SIGTERM)
    print("Cancelled TapLock session (PID: \(pid)).")
    exit(ExitCode.success.rawValue)
}

// MARK: - Help & Version

func printHelp() -> Never {
    print("""
    USAGE: taplock [duration] [options]

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

    RELAXING SESSION MODE:
      --relax           Enable repeating relaxing session mode (Pomodoro-style)
      --interval <dur>  Work interval between breaks. Default: 25m. Examples: 20m, 30m, 45m
                        Duration argument sets the break length. Default: 5m.
                        Custom --color sets the relaxing overlay color (default: calming teal).

      Examples:
        taplock --relax                     25-minute work, 5-minute relaxing break, repeat
        taplock --relax 10m                 25-minute work, 10-minute break, repeat
        taplock --relax --interval 50m 10m  50-minute work, 10-minute break, repeat
        taplock --relax --color 2d6a4f      Custom calming green overlay color
    """)
    exit(ExitCode.success.rawValue)
}

func printVersion() -> Never {
    print("taplock \(version)")
    exit(ExitCode.success.rawValue)
}
