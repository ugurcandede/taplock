import TapLockCore
import Foundation

// MARK: - Constants

/// Build-time version. Rewritten by CI from the most recent git tag on release.
let version = "0.1.0"

/// Auto-unlock cap (seconds) when no duration is given. Prevents permanent lockout
/// if the emergency cancel chord fails.
let maxSafetyDuration = 300 // 5 minutes

// MARK: - Exit Codes

enum ExitCode: Int32 {
    case success = 0
    case generalError = 1
    case permissionDenied = 2
    case noActiveSession = 3
}

// MARK: - PID File IPC

/// Per-mode PID file used for cross-terminal cancel.
/// The shared cache directory is created on first instantiation.
struct PIDFile {
    let path: String
    let label: String

    init(name: String, label: String) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = cacheDir.appendingPathComponent("taplock")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.path = dir.appendingPathComponent(name).path
        self.label = label
    }

    /// Write the current process ID into the file.
    func write() {
        let pid = ProcessInfo.processInfo.processIdentifier
        do {
            try String(pid).write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            fputs("Warning: Could not write PID file: \(error.localizedDescription)\n", stderr)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }

    func read() -> pid_t? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8),
              let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return pid
    }

    /// Whether the saved PID still corresponds to a live process.
    func hasActiveProcess() -> Bool {
        guard let pid = read() else { return false }
        return kill(pid, 0) == 0
    }

    /// Send SIGTERM to the saved PID and exit. Stale entries are cleaned up.
    func cancelActive() -> Never {
        guard let pid = read() else {
            fputs("Error: No active \(label) found.\n", stderr)
            exit(ExitCode.noActiveSession.rawValue)
        }

        if kill(pid, 0) != 0 {
            remove()
            fputs("Error: No active \(label) found (stale PID file removed).\n", stderr)
            exit(ExitCode.noActiveSession.rawValue)
        }

        kill(pid, SIGTERM)
        print("Cancelled \(label) (PID: \(pid)).")
        exit(ExitCode.success.rawValue)
    }
}

let lockPIDFile = PIDFile(name: "taplock.pid", label: "TapLock session")
let relaxPIDFile = PIDFile(name: "taplock-relax.pid", label: "relaxing session")

// MARK: - Signal Handlers

/// Install matching SIGTERM + SIGINT handlers, both invoking `onCancel`.
/// The returned sources must be retained by the caller for their lifetime
/// (DispatchSourceSignal stops firing once released).
func installSignalHandlers(onCancel: @escaping () -> Void) -> [DispatchSourceSignal] {
    [SIGTERM, SIGINT].map { signal in
        let source = DispatchSource.makeSignalSource(signal: signal, queue: .main)
        source.setEventHandler(handler: onCancel)
        source.resume()
        return source
    }
}

// MARK: - Help & Version

func printHelp() -> Never {
    print("""
    USAGE: taplock [duration] [options]
           taplock relax [options]
           taplock stats [options]

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
      --no-posture-reminder  Disable posture reminder during session
      --cancel            Cancel active relaxing session
      --config            Show saved configuration
      --reset             Delete saved configuration

    STATS SUBCOMMAND:
      taplock stats                 Today's summary
      taplock stats --week          Last 7 days
      taplock stats --all --json    All-time, machine-readable

      --today / --week / --month / --all   Time period (default: --today)
      --json                              JSON output for scripting
      --reset                             Delete the event log
    """)
    exit(ExitCode.success.rawValue)
}

func printVersion() -> Never {
    print("taplock \(version)")
    exit(ExitCode.success.rawValue)
}
