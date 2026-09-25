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
    /// Seconds between posture reminders while waiting for a break. nil keeps the
    /// original behavior: a single reminder halfway through the interval.
    public var postureInterval: Int?

    public init(
        interval: Int,
        breakDuration: Int,
        theme: RelaxTheme = .breathing,
        color: String = "green",
        opacity: Double = 0.85,
        silent: Bool = false,
        showPostureReminder: Bool = true,
        postureInterval: Int? = nil
    ) {
        self.interval = interval
        self.breakDuration = breakDuration
        self.theme = theme
        self.color = color
        self.opacity = opacity
        self.silent = silent
        self.showPostureReminder = showPostureReminder
        self.postureInterval = postureInterval
    }
}

// MARK: - Session

/// Manages a repeating relaxing break session: waits for the interval,
/// shows a relaxing overlay, then repeats.
public final class RelaxingSession {
    /// Mutable so appearance settings can change mid-session; changes apply
    /// from the next scheduled break.
    public var config: RelaxingSessionConfig {
        didSet { resolvedColor = Self.resolveColor(config.color) }
    }
    private var resolvedColor: (r: Double, g: Double, b: Double)
    private var intervalTimer: Timer?
    private var breakTimer: Timer?
    private var preNotifyTimer: Timer?
    private var postureTimer: Timer?
    private var postureAutoDismissTimer: Timer?
    private var postureController: PostureWindowController?
    private var windowController: RelaxingWindowController?
    private var sessionStartDate: Date?
    private var breakStartDate: Date?
    private var breaksTaken: Int = 0
    public private(set) var isActive = false

    /// Called when the session is cancelled.
    public var onEnd: (() -> Void)?
    /// Called when a break starts.
    public var onBreakStart: (() -> Void)?
    /// Called when a break ends (skip or timeout).
    public var onBreakEnd: (() -> Void)?

    public init(config: RelaxingSessionConfig) {
        self.config = config
        self.resolvedColor = Self.resolveColor(config.color)
    }

    private static func resolveColor(_ color: String) -> (r: Double, g: Double, b: Double) {
        parseColor(color) ?? (r: 0, g: 0.8, b: 0) // fallback green
    }

    /// Start the interval loop. Call from main thread.
    public func start() {
        guard !isActive else { return }
        isActive = true
        sessionStartDate = Date()
        breaksTaken = 0

        StatsStore.shared.append(.relaxSessionStarted(.init(
            timestamp: sessionStartDate ?? Date(),
            intervalSeconds: config.interval,
            breakSeconds: config.breakDuration,
            theme: config.theme.rawValue
        )))

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

        if let sessionStart = sessionStartDate {
            let duration = Int(Date().timeIntervalSince(sessionStart))
            StatsStore.shared.append(.relaxSessionEnded(.init(
                timestamp: Date(),
                durationSeconds: duration,
                breaksTaken: breaksTaken
            )))
            sessionStartDate = nil
        }

        onEnd?()
    }

    // MARK: - Internal

    public func skipBreak() {
        endBreak()
        scheduleNextBreak()
    }

    /// Start the upcoming break immediately instead of waiting for the interval.
    public func startBreakNow() {
        guard isActive, windowController == nil else { return }
        cancelPendingTimers()
        startBreak()
    }

    private func cancelPendingTimers() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        preNotifyTimer?.invalidate()
        preNotifyTimer = nil
        postureTimer?.invalidate()
        postureTimer = nil
    }

    private func scheduleNextBreak() {
        // Config may have changed since the last schedule (e.g. silent or posture
        // toggled), so clear every pending timer, not only the ones re-created below.
        cancelPendingTimers()

        // Pre-notification sound ~10s before break (if interval > 15s and not silent)
        if !config.silent && config.interval > 15 {
            let preDelay = max(0, config.interval - 10)
            preNotifyTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(preDelay), repeats: false) { [weak self] _ in
                guard let self, self.isActive else { return }
                SoundPlayer.play("Pop", volume: 0.3)
            }
        }

        intervalTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.interval), repeats: false) { [weak self] _ in
            self?.startBreak()
        }

        if config.showPostureReminder, let every = config.postureInterval {
            // Repeat every `every` seconds until the break starts.
            if every > 0 && every < config.interval {
                postureTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(every), repeats: true) { [weak self] _ in
                    guard let self, self.isActive, self.windowController == nil else { return }
                    self.showPostureReminder()
                }
            }
        } else if config.showPostureReminder && config.interval > 10 {
            // Posture reminder at interval/2
            let postureDelay = TimeInterval(config.interval) / 2.0
            postureTimer = Timer.scheduledTimer(withTimeInterval: postureDelay, repeats: false) { [weak self] _ in
                guard let self, self.isActive else { return }
                self.showPostureReminder()
            }
        }
    }

    private func startBreak() {
        guard isActive else { return }
        postureTimer?.invalidate()
        postureTimer = nil
        dismissPostureReminder()
        breakStartDate = Date()

        if !config.silent { SoundPlayer.play("Blow", volume: 0.3) }

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
        // A still-valid breakTimer means we're ending the break before its natural
        // expiration — either user Skip/Esc or session cancel. The timer's own
        // fire-handler runs after the timer becomes invalid, so this distinguishes
        // those two paths.
        let timerWasValid = breakTimer?.isValid ?? false
        breakTimer?.invalidate()
        breakTimer = nil
        let wasShowing = windowController != nil
        windowController?.closeOverlay()
        windowController = nil

        if wasShowing, let breakStart = breakStartDate {
            let actual = Int(Date().timeIntervalSince(breakStart))
            StatsStore.shared.append(.relaxBreak(.init(
                timestamp: breakStart,
                plannedSeconds: config.breakDuration,
                actualSeconds: actual,
                theme: config.theme.rawValue,
                skippedEarly: timerWasValid
            )))
            breaksTaken += 1
        }
        breakStartDate = nil

        if wasShowing && !config.silent { SoundPlayer.play("Glass", volume: 0.3) }
        if wasShowing { onBreakEnd?() }
    }
}
