import Foundation

// MARK: - RelaxingSessionConfig

/// Configuration for a repeating relaxing session cycle
/// (work interval → relax lock → work interval → relax lock → …).
public struct RelaxingSessionConfig {
    /// Work interval in seconds between each relaxing session.
    public var interval: Int
    /// Duration of each relaxing session in seconds.
    public var duration: Int
    /// Custom overlay color. Defaults to a calming teal when nil.
    public var overlayColor: (r: Double, g: Double, b: Double)?
    public var dim: Bool
    public var silent: Bool
    public var keyboardOnly: Bool

    /// Default calming teal used when no custom color is provided.
    public static let defaultColor: (r: Double, g: Double, b: Double) = (0.04, 0.40, 0.45)

    /// Default title shown on the relaxing lock overlay.
    public static let defaultTitle = "Time to Relax 🌊"

    public init(
        interval: Int,
        duration: Int,
        overlayColor: (r: Double, g: Double, b: Double)? = nil,
        dim: Bool = false,
        silent: Bool = false,
        keyboardOnly: Bool = false
    ) {
        self.interval = interval
        self.duration = duration
        self.overlayColor = overlayColor
        self.dim = dim
        self.silent = silent
        self.keyboardOnly = keyboardOnly
    }
}

// MARK: - RelaxingSession

/// Runs a repeating cycle of work intervals followed by a relaxing lock session.
///
/// Example with a 25-minute work interval and a 5-minute relaxing break:
/// ```
/// let config = RelaxingSessionConfig(interval: 25 * 60, duration: 5 * 60)
/// let session = RelaxingSession(config: config)
/// session.onRelaxStart = { count in print("Break #\(count) started") }
/// session.onRelaxEnd   = { count in print("Break #\(count) ended") }
/// session.start()
/// ```
public final class RelaxingSession {
    private let config: RelaxingSessionConfig
    private var activeSession: TapLockSession?
    private var intervalTimer: DispatchSourceTimer?
    public private(set) var isActive = false
    public private(set) var sessionCount = 0

    /// Called when the entire relaxing cycle is cancelled.
    public var onEnd: (() -> Void)?
    /// Called when a relaxing lock starts. Parameter is the 1-based session count.
    public var onRelaxStart: ((Int) -> Void)?
    /// Called when a relaxing lock ends. Parameter is the 1-based session count.
    public var onRelaxEnd: ((Int) -> Void)?

    public init(config: RelaxingSessionConfig) {
        self.config = config
    }

    // MARK: - Public Interface

    /// Start the repeating relaxing session cycle. Call from the main thread.
    public func start() {
        guard !isActive else { return }
        isActive = true
        scheduleNextSession()
    }

    /// Cancel all pending and active relaxing sessions.
    public func cancel() {
        guard isActive else { return }
        isActive = false
        intervalTimer?.cancel()
        intervalTimer = nil
        activeSession?.cancel()
        activeSession = nil
        onEnd?()
    }

    // MARK: - Private

    private func scheduleNextSession() {
        guard isActive else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(config.interval))
        timer.setEventHandler { [weak self] in
            self?.startRelaxSession()
        }
        timer.resume()
        intervalTimer = timer
    }

    private func startRelaxSession() {
        guard isActive else { return }
        intervalTimer = nil
        sessionCount += 1
        let currentCount = sessionCount

        let color = config.overlayColor ?? RelaxingSessionConfig.defaultColor
        let sessionConfig = SessionConfig(
            duration: config.duration,
            keyboardOnly: config.keyboardOnly,
            dim: config.dim,
            silent: config.silent,
            showOverlay: true,
            overlayColor: color,
            overlayTitle: RelaxingSessionConfig.defaultTitle
        )

        let session = TapLockSession(config: sessionConfig)
        session.onEnd = { [weak self] in
            guard let self else { return }
            self.activeSession = nil
            self.onRelaxEnd?(currentCount)
            if self.isActive {
                self.scheduleNextSession()
            }
        }

        activeSession = session
        onRelaxStart?(currentCount)

        do {
            try session.start()
        } catch {
            activeSession = nil
            if isActive {
                scheduleNextSession()
            }
        }
    }
}
