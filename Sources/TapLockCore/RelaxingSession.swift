import Cocoa
import Foundation

// MARK: - Types

public enum RelaxTheme: String, Codable, CaseIterable {
    case breathing
    case minimal
    case mini
}

public struct RelaxingSessionConfig: Codable {
    public var interval: Int
    public var breakDuration: Int
    public var theme: RelaxTheme
    public var color: String
    public var opacity: Double
    public var silent: Bool
    public var showPostureReminder: Bool

    public init(
        interval: Int,
        breakDuration: Int,
        theme: RelaxTheme = .breathing,
        color: String = "green",
        opacity: Double = 0.85,
        silent: Bool = false,
        showPostureReminder: Bool = true
    ) {
        self.interval = interval
        self.breakDuration = breakDuration
        self.theme = theme
        self.color = color
        self.opacity = opacity
        self.silent = silent
        self.showPostureReminder = showPostureReminder
    }
}

// MARK: - Session

/// Manages a repeating relaxing break session: waits for the interval,
/// shows a relaxing overlay, then repeats.
public final class RelaxingSession {
    public let config: RelaxingSessionConfig
    private let resolvedColor: (r: Double, g: Double, b: Double)
    private var intervalTimer: Timer?
    private var breakTimer: Timer?
    private var preNotifyTimer: Timer?
    private var postureTimer: Timer?
    private var postureAutoDismissTimer: Timer?
    private var postureController: PostureWindowController?
    private var windowController: RelaxingWindowController?
    public private(set) var isActive = false

    /// Called when the session is cancelled.
    public var onEnd: (() -> Void)?
    /// Called when a break starts.
    public var onBreakStart: (() -> Void)?
    /// Called when a break ends (skip or timeout).
    public var onBreakEnd: (() -> Void)?

    public init(config: RelaxingSessionConfig) {
        self.config = config
        self.resolvedColor = parseColor(config.color) ?? (r: 0, g: 0.8, b: 0) // fallback green
    }

    /// Start the interval loop. Call from main thread.
    public func start() {
        guard !isActive else { return }
        isActive = true
        scheduleNextBreak()
        let formatted = formatDuration(config.interval)
        print("Relaxing session started. Next break in \(formatted).")
    }

    /// Stop everything and clean up.
    public func cancel() {
        guard isActive else { return }
        isActive = false
        intervalTimer?.invalidate()
        intervalTimer = nil
        preNotifyTimer?.invalidate()
        preNotifyTimer = nil
        dismissPostureReminder()
        postureTimer?.invalidate()
        postureTimer = nil
        endBreak()
        onEnd?()
    }

    // MARK: - Internal

    public func skipBreak() {
        endBreak()
        scheduleNextBreak()
    }

    private func scheduleNextBreak() {
        intervalTimer?.invalidate()

        // Pre-notification sound ~10s before break (if interval > 15s and not silent)
        if !config.silent && config.interval > 15 {
            let preDelay = max(0, config.interval - 10)
            preNotifyTimer?.invalidate()
            preNotifyTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(preDelay), repeats: false) { [weak self] _ in
                guard let self, self.isActive else { return }
                self.playSound("Pop")
            }
        }

        intervalTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.interval), repeats: false) { [weak self] _ in
            self?.startBreak()
        }

        // Posture reminder at interval/2
        if config.showPostureReminder && config.interval > 10 {
            let postureDelay = TimeInterval(config.interval) / 2.0
            postureTimer?.invalidate()
            postureTimer = Timer.scheduledTimer(withTimeInterval: postureDelay, repeats: false) { [weak self] _ in
                guard let self, self.isActive else { return }
                self.showPostureReminder()
            }
        }
    }

    private func startBreak() {
        guard isActive else { return }
        dismissPostureReminder()

        if !config.silent { playSound("Blow") }

        windowController = RelaxingWindowController(
            duration: config.breakDuration,
            theme: config.theme,
            color: resolvedColor,
            opacity: config.opacity
        )
        windowController?.onSkip = { [weak self] in
            self?.skipBreak()
        }
        windowController?.showOverlay()
        onBreakStart?()

        // Auto-dismiss after break duration
        breakTimer?.invalidate()
        breakTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.breakDuration), repeats: false) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.skipBreak()
        }

        print("Break started (\(formatDuration(config.breakDuration))). Press Esc or click Skip to dismiss.")
    }

    private func showPostureReminder() {
        dismissPostureReminder()
        postureController = PostureWindowController()
        postureController?.onDismiss = { [weak self] in
            self?.dismissPostureReminder()
        }
        postureController?.showOverlay()

        // Auto-dismiss after 10 seconds
        postureAutoDismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.dismissPostureReminder()
        }
    }

    private func dismissPostureReminder() {
        postureAutoDismissTimer?.invalidate()
        postureAutoDismissTimer = nil
        postureController?.closeOverlay()
        postureController = nil
    }

    private func endBreak() {
        breakTimer?.invalidate()
        breakTimer = nil
        let wasShowing = windowController != nil
        windowController?.closeOverlay()
        windowController = nil
        if wasShowing && !config.silent { playSound("Glass") }
        if wasShowing { onBreakEnd?() }
    }

    private func playSound(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = 0.3
        sound.play()
    }
}
