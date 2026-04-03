import CleanLockCore
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

// MARK: - PID File IPC

/// Check if another CleanLock instance is running.
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
