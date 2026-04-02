import Cocoa
import Foundation

// MARK: - Signal Safety

/// Volatile flag for async-signal-safe handling.
/// Signal handler only sets this; main run loop checks it.
nonisolated(unsafe) var signalReceived: sig_atomic_t = 0

// MARK: - Argument Parsing

struct CLIOptions {
    var duration: Int? = nil
    var keyboardOnly = false
    var noOverlay = false
    var delay: Int = 0
    var colorInput: String? = nil
    var silent = false
    var dim = false
}

func parseArguments() -> CLIOptions {
    let args = Array(CommandLine.arguments.dropFirst())
    var opts = CLIOptions()
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
            opts.keyboardOnly = true
        case "--no-overlay":
            opts.noOverlay = true
        case "--silent":
            opts.silent = true
        case "--dim":
            opts.dim = true
        case "--delay":
            i += 1
            guard i < args.count, let d = Int(args[i]), d > 0 else {
                fputs("Error: --delay requires a positive number of seconds.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.delay = d
        case "--color":
            i += 1
            guard i < args.count else {
                fputs("Error: --color requires a value (e.g. black, fff, FF0000).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.colorInput = args[i]
        default:
            if arg.hasPrefix("-") {
                fputs("Error: Unknown option '\(arg)'. Use --help for usage.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            positionalArgs.append(arg)
        }
        i += 1
    }

    // Validate: at most one positional argument (duration)
    if positionalArgs.count > 1 {
        fputs("Error: Too many arguments. Only one duration value is accepted.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    if let durationArg = positionalArgs.first {
        guard let parsed = parseDuration(durationArg) else {
            fputs("Error: Invalid duration '\(durationArg)'. Examples: 30, 30s, 2m, 1m30s\n", stderr)
            exit(ExitCode.generalError.rawValue)
        }
        opts.duration = parsed
    }

    return opts
}

// MARK: - Main

func main() {
    let opts = parseArguments()
    let effectiveDuration = opts.duration ?? maxSafetyDuration

    // Validate color early
    var overlayColor: (r: Double, g: Double, b: Double)? = nil
    if let colorInput = opts.colorInput {
        overlayColor = parseColor(colorInput)
        if overlayColor == nil {
            fputs("Warning: Invalid color '\(colorInput)'. Using default.\n", stderr)
        }
    }

    // Check for existing instance
    if checkExistingInstance() {
        fputs("Error: Another CleanLock session is already running. Use --cancel to stop it.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    // Check accessibility permission
    if !InputBlocker.checkAccessibility() {
        if !InputBlocker.waitForAccessibility(timeout: 30) {
            fputs("Error: Accessibility permission is required.\n", stderr)
            exit(ExitCode.permissionDenied.rawValue)
        }
    }

    // Signal handlers — only set volatile flag (async-signal-safe)
    signal(SIGTERM) { _ in signalReceived = 1 }
    signal(SIGINT) { _ in signalReceived = 1 }

    // Write PID file
    writePIDFile()

    // Pre-lock delay
    if opts.delay > 0 {
        let durationText = opts.duration == nil
            ? "until cancelled (safety: \(formatDuration(maxSafetyDuration)))"
            : formatDuration(effectiveDuration)
        print("CleanLock will activate in \(opts.delay) seconds for \(durationText)...")
        for i in (1...opts.delay).reversed() {
            print("  \(i)...")
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    // Create and start session
    let session = CleanLockSession(config: SessionConfig(
        duration: effectiveDuration,
        keyboardOnly: opts.keyboardOnly,
        dim: opts.dim,
        silent: opts.silent,
        showOverlay: !opts.noOverlay,
        overlayColor: overlayColor
    ))

    session.onEnd = {
        removePIDFile()
        // Delay exit so end sound can play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(ExitCode.success.rawValue)
        }
    }

    do {
        try session.start()
    } catch {
        fputs("Error: \(error)\n", stderr)
        removePIDFile()
        exit(ExitCode.generalError.rawValue)
    }

    if opts.duration == nil {
        print("Locked until cancelled! Safety auto-unlock in \(formatDuration(maxSafetyDuration)). Press ⌘⌥⌃L for 3 seconds to cancel.")
    } else {
        print("Locked for \(formatDuration(effectiveDuration))! Press ⌘⌥⌃L for 3 seconds to cancel.")
    }

    // Poll for signal flag (async-signal-safe pattern)
    Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
        if signalReceived != 0 {
            session.cancel()
        }
    }

    // Run the main run loop
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()
}

main()
