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

// MARK: - Relax Argument Parsing

struct RelaxOptions {
    var every: Int? = nil
    var breakDuration: Int? = nil
    var theme: String? = nil
    var colorInput: String? = nil
    var opacity: Double? = nil
    var silent = false
}

func parseRelaxArguments(_ args: [String]) -> RelaxOptions {
    var opts = RelaxOptions()
    var i = 0

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--help", "-h":
            printHelp()
        case "--cancel":
            cancelActiveRelaxSession()
        case "--config":
            showRelaxConfig()
        case "--reset":
            resetRelaxConfig()
        case "--silent":
            opts.silent = true
        case "--every":
            i += 1
            guard i < args.count, let d = parseDuration(args[i]) else {
                fputs("Error: --every requires a valid duration (e.g. 25m, 45m).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.every = d
        case "--break":
            i += 1
            guard i < args.count, let d = parseDuration(args[i]) else {
                fputs("Error: --break requires a valid duration (e.g. 5m, 10m).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.breakDuration = d
        case "--theme":
            i += 1
            guard i < args.count else {
                fputs("Error: --theme requires a value (breathing, minimal).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.theme = args[i]
        case "--color":
            i += 1
            guard i < args.count else {
                fputs("Error: --color requires a value (e.g. green, blue, FF0000).\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.colorInput = args[i]
        case "--opacity":
            i += 1
            guard i < args.count, let val = Double(args[i]), val > 0 && val <= 1.0 else {
                fputs("Error: --opacity requires a value between 0.1 and 1.0.\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            opts.opacity = val
        default:
            fputs("Error: Unknown option '\(arg)'. Use --help for usage.\n", stderr)
            exit(ExitCode.generalError.rawValue)
        }
        i += 1
    }

    return opts
}

func showRelaxConfig() -> Never {
    guard let config = ConfigStore.loadRelaxConfig() else {
        print("No saved relaxing session configuration.")
        exit(ExitCode.success.rawValue)
    }
    print("Saved relaxing session configuration:")
    print("  Interval:  \(formatDuration(config.interval))")
    print("  Break:     \(formatDuration(config.breakDuration))")
    print("  Theme:     \(config.theme.rawValue)")
    print("  Color:     \(config.color)")
    print("  Opacity:   \(config.opacity)")
    print("  Silent:    \(config.silent)")
    exit(ExitCode.success.rawValue)
}

func resetRelaxConfig() -> Never {
    do {
        try ConfigStore.removeRelaxConfig()
        print("Relaxing session configuration removed.")
    } catch {
        fputs("Error: Could not remove config: \(error.localizedDescription)\n", stderr)
    }
    exit(ExitCode.success.rawValue)
}

// MARK: - Run Relax Mode

func runRelaxMode(_ args: [String]) {
    let opts = parseRelaxArguments(args)

    // Validate: --every and --break must be provided together
    if (opts.every != nil) != (opts.breakDuration != nil) {
        fputs("Error: --every and --break must be provided together.\n", stderr)
        fputs("Example: taplock relax --every 25m --break 5m\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    // Load saved config or build from arguments
    var config: RelaxingSessionConfig
    if let every = opts.every, let breakDur = opts.breakDuration {
        // Validate theme
        var theme: RelaxTheme = .breathing
        if let themeInput = opts.theme {
            guard let parsed = RelaxTheme(rawValue: themeInput) else {
                fputs("Error: Unknown theme '\(themeInput)'. Available: breathing, minimal, mini\n", stderr)
                exit(ExitCode.generalError.rawValue)
            }
            theme = parsed
        }

        // Validate color
        let colorStr = opts.colorInput ?? "green"
        if parseColor(colorStr) == nil {
            fputs("Warning: Invalid color '\(colorStr)'. Using default green.\n", stderr)
        }

        config = RelaxingSessionConfig(
            interval: every,
            breakDuration: breakDur,
            theme: theme,
            color: colorStr,
            opacity: opts.opacity ?? 0.85,
            silent: opts.silent
        )

        // Auto-save config
        do {
            try ConfigStore.saveRelaxConfig(config)
        } catch {
            fputs("Warning: Could not save config: \(error.localizedDescription)\n", stderr)
        }
    } else if let saved = ConfigStore.loadRelaxConfig() {
        config = saved
        // Allow overriding individual options from saved config
        if let themeInput = opts.theme {
            if let parsed = RelaxTheme(rawValue: themeInput) {
                config.theme = parsed
            }
        }
        if let colorInput = opts.colorInput {
            config.color = colorInput
        }
        if let opacity = opts.opacity {
            config.opacity = opacity
        }
        if opts.silent {
            config.silent = true
        }
    } else {
        fputs("Error: No saved config. Provide --every and --break on first use.\n", stderr)
        fputs("Example: taplock relax --every 25m --break 5m\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    // Validate interval > break duration
    if config.interval <= config.breakDuration {
        fputs("Error: --every must be longer than --break.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    // Check for existing relax instance
    if checkExistingRelaxInstance() {
        fputs("Error: Another relaxing session is already running. Use 'taplock relax --cancel' to stop it.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    writeRelaxPIDFile()

    let session = RelaxingSession(config: config)

    session.onEnd = {
        removeRelaxPIDFile()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(ExitCode.success.rawValue)
        }
    }

    session.start()

    // Signal handling
    let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigTermSource.setEventHandler { session.cancel() }
    sigTermSource.resume()

    let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigIntSource.setEventHandler { session.cancel() }
    sigIntSource.resume()

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()
}

// MARK: - Run Lock Mode

func runLockMode() {
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

// MARK: - Main

func main() {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.first == "relax" {
        runRelaxMode(Array(args.dropFirst()))
    } else {
        runLockMode()
    }
}

main()
