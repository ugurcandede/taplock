import TapLockCore
import Foundation

// MARK: - Constants

let version = "0.1.0"
let maxSafetyDuration = 300 // 5 minutes

let pidFilePath: String = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let dir = cacheDir.appendingPathComponent("taplock")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("taplock.pid").path
}()

let relaxPidFilePath: String = {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let dir = cacheDir.appendingPathComponent("taplock")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("taplock-relax.pid").path
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

// MARK: - Relax PID File IPC

func checkExistingRelaxInstance() -> Bool {
    guard let pid = readRelaxPIDFile() else { return false }
    return kill(pid, 0) == 0
}

func writeRelaxPIDFile() {
    let pid = ProcessInfo.processInfo.processIdentifier
    do {
        try String(pid).write(toFile: relaxPidFilePath, atomically: true, encoding: .utf8)
    } catch {
        fputs("Warning: Could not write relax PID file: \(error.localizedDescription)\n", stderr)
    }
}

func removeRelaxPIDFile() {
    try? FileManager.default.removeItem(atPath: relaxPidFilePath)
}

func readRelaxPIDFile() -> pid_t? {
    guard let contents = try? String(contentsOfFile: relaxPidFilePath, encoding: .utf8),
          let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines))
    else {
        return nil
    }
    return pid
}

func cancelActiveRelaxSession() -> Never {
    guard let pid = readRelaxPIDFile() else {
        fputs("Error: No active relaxing session found.\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    if kill(pid, 0) != 0 {
        removeRelaxPIDFile()
        fputs("Error: No active relaxing session found (stale PID file removed).\n", stderr)
        exit(ExitCode.noActiveSession.rawValue)
    }

    kill(pid, SIGTERM)
    print("Cancelled relaxing session (PID: \(pid)).")
    exit(ExitCode.success.rawValue)
}

// MARK: - Help & Version

func printHelp() -> Never {
    print("""
    USAGE: taplock [duration] [options]
           taplock relax [options]

    Temporarily disable keyboard and trackpad input while cleaning your Mac.

    ARGUMENTS:
      duration          Lock duration. Examples: 30, 30s, 2m, 1h, 1h30m
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

    RELAX SUBCOMMAND:
      taplock relax                 Start with saved config
      taplock relax --every 25m --break 5m
                                    Periodic break reminders (saves config)

      --every <duration>  Interval between breaks (e.g. 25m, 1h, 1h30m)
      --break <duration>  Break duration (e.g. 5m, 10m, 30s)
      --theme <name>      Visual theme: breathing (default), minimal, mini
      --color <value>     Overlay color (default: green)
      --opacity <0.1-1.0> Overlay opacity (default: 0.85)
      --silent            Disable all sounds including pre-notification
      --cancel            Cancel active relaxing session
      --config            Show saved configuration
      --reset             Delete saved configuration
    """)
    exit(ExitCode.success.rawValue)
}

func printVersion() -> Never {
    print("taplock \(version)")
    exit(ExitCode.success.rawValue)
}
