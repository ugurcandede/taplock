import TapLockCore
import Cocoa
import Foundation

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
        fputs("Error: Another TapLock session is already running. Use --cancel to stop it.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    // Check accessibility permission
    if !InputBlocker.checkAccessibility() {
        if !InputBlocker.waitForAccessibility(timeout: 30) {
            fputs("Error: Accessibility permission is required.\n", stderr)
            exit(ExitCode.permissionDenied.rawValue)
        }
    }

    // Write PID file
    writePIDFile()

    // Session setup
    let config = SessionConfig(
        duration: effectiveDuration,
        keyboardOnly: opts.keyboardOnly,
        dim: opts.dim,
        silent: opts.silent,
        showOverlay: !opts.noOverlay,
        overlayColor: overlayColor
    )

    let session = TapLockSession(config: config)

    session.onEnd = {
        removePIDFile()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(ExitCode.success.rawValue)
        }
    }

    // Start function (called immediately or after delay)
    let startLock = {
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
    }

    // Pre-lock delay (non-blocking)
    if opts.delay > 0 {
        let durationText = opts.duration == nil
            ? "until cancelled (safety: \(formatDuration(maxSafetyDuration)))"
            : formatDuration(effectiveDuration)
        print("TapLock will activate in \(opts.delay) seconds for \(durationText)...")

        var remaining = opts.delay
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            print("  \(remaining)...")
            remaining -= 1
            if remaining < 0 {
                timer.invalidate()
                startLock()
            }
        }
    } else {
        startLock()
    }

    // Signal handling via DispatchSource (replaces polling timer)
    let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigTermSource.setEventHandler { session.cancel() }
    sigTermSource.resume()

    let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigIntSource.setEventHandler { session.cancel() }
    sigIntSource.resume()

    // Run the main run loop
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()
}

main()
