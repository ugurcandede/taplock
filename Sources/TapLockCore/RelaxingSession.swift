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
    /// Wall-clock rules (active hours, quiet hours, clock alignment). nil keeps
    /// the plain "every interval" behavior.
    public var schedule: RelaxSchedule?

    public init(
        interval: Int,
        breakDuration: Int,
        theme: RelaxTheme = .breathing,
        color: String = "green",
        opacity: Double = 0.85,
        silent: Bool = false,
        showPostureReminder: Bool = true,
        postureInterval: Int? = nil,
        schedule: RelaxSchedule? = nil
    ) {
        self.interval = interval
        self.breakDuration = breakDuration
        self.theme = theme
        self.color = color
        self.opacity = opacity
        self.silent = silent
        self.showPostureReminder = showPostureReminder
        self.postureInterval = postureInterval
        self.schedule = schedule
    }
}

// MARK: - Session

/// Manages a repeating relaxing break session: waits for the interval,
/// shows a relaxing overlay, then repeats.
public final class RelaxingSession {
    /// Mutable so settings can change mid-session. Sound and posture changes
    /// apply to the current wait right away; the overlay picks up appearance
    /// changes at the next break. Changing `interval` takes effect next cycle.
    public var config: RelaxingSessionConfig {
        didSet {
            resolvedColor = Self.resolveColor(config.color)
            guard isActive, waitStartDate != nil else { return }
            if !config.showPostureReminder { dismissPostureReminder() }
            scheduleReminders()
        }
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
    /// Start of the current wait for a break; nil during a break or when inactive.
    private var waitStartDate: Date?
    /// When the pending break will start; nil during a break or when inactive.
    public private(set) var nextBreakDate: Date?
    /// While a schedule holds the next break back (outside the hours, quiet hours,
    /// or no full interval left before them): when the countdown to it starts.
    /// nil when counting down, on a break, or without a schedule.
    public var pausedUntil: Date? {
        guard config.schedule != nil, let next = nextBreakDate else { return nil }
        let resume = next.addingTimeInterval(-TimeInterval(config.interval))
        return resume > Date() ? resume : nil
    }
    private var breaksTaken: Int = 0
    private var wakeObserver: NSObjectProtocol?
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

        // Timers don't advance while the Mac sleeps, so re-arm against the wall clock on wake.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }

        scheduleNextBreak()
        if config.schedule != nil, let next = nextBreakDate {
            print("Relaxing session started. Next break at \(next.formatted(date: .abbreviated, time: .shortened)).")
        } else {
            print("Relaxing session started. Next break in \(formatDuration(config.interval)).")
        }
    }

    /// Stop everything and clean up.
    public func cancel() {
        guard isActive else { return }
        isActive = false
        waitStartDate = nil
        nextBreakDate = nil
        intervalTimer?.invalidate()
        intervalTimer = nil
        preNotifyTimer?.invalidate()
        preNotifyTimer = nil
        dismissPostureReminder()
        postureTimer?.invalidate()
        postureTimer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        endBreak()

        if let sessionStart = sessionStartDate {
            // Time outside the schedule's hours isn't session time.
            let duration = config.schedule?.activeSeconds(from: sessionStart, to: Date())
                ?? Int(Date().timeIntervalSince(sessionStart))
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
        // Schedule first so onBreakEnd observers can read nextBreakDate.
        scheduleNextBreak()
        endBreak()
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
        cancelPendingTimers()
        let now = Date()
        waitStartDate = now
        let next = config.schedule?.nextBreak(after: now, interval: config.interval, breakDuration: config.breakDuration)
            ?? now.addingTimeInterval(TimeInterval(config.interval))
        nextBreakDate = next
        armIntervalTimer(at: next)
        scheduleReminders()
    }

    private func armIntervalTimer(at date: Date) {
        intervalTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.startBreak()
        }
        RunLoop.main.add(timer, forMode: .default)
        intervalTimer = timer
    }

    /// While waiting: keep the break at its wall-clock time, or start a fresh wait
    /// if it passed during sleep (being away counts as the break, so don't show one).
    private func handleWake() {
        guard isActive, let next = nextBreakDate else { return }
        if next > Date() {
            armIntervalTimer(at: next)
            scheduleReminders()
        } else {
            scheduleNextBreak()
        }
    }

    /// (Re)schedule the pre-break sound and posture reminders for the current wait.
    /// Delays are measured from the start of the wait, so calling this after a
    /// config change keeps them aligned with the running countdown.
    private func scheduleReminders() {
        preNotifyTimer?.invalidate()
        preNotifyTimer = nil
        postureTimer?.invalidate()
        postureTimer = nil
        guard let waitStart = waitStartDate, let nextBreak = nextBreakDate else { return }
        // A schedule can stretch the wait over off-hours; count reminders only
        // from the last `interval` before the break.
        let effectiveStart = max(waitStart, nextBreak.addingTimeInterval(-TimeInterval(config.interval)))
        let elapsed = Date().timeIntervalSince(effectiveStart)
        let interval = nextBreak.timeIntervalSince(effectiveStart)

        // Pre-notification sound ~10s before break (if interval > 15s and not silent)
        if !config.silent && config.interval > 15 {
            let preDelay = interval - 10 - elapsed
            if preDelay > 0 {
                preNotifyTimer = Timer.scheduledTimer(withTimeInterval: preDelay, repeats: false) { [weak self] _ in
                    guard let self, self.isActive else { return }
                    SoundPlayer.play("Pop", volume: 0.3)
                }
            }
        }

        if config.showPostureReminder, let every = config.postureInterval {
            // Repeat every `every` seconds of the wait until the break starts.
            if every > 0 && every < config.interval {
                let period = TimeInterval(every)
                let firstFire = elapsed < 0
                    ? effectiveStart.addingTimeInterval(period)
                    : Date().addingTimeInterval(period - elapsed.truncatingRemainder(dividingBy: period))
                let timer = Timer(fire: firstFire, interval: period, repeats: true) { [weak self] _ in
                    guard let self, self.isActive, self.windowController == nil else { return }
                    self.showPostureReminder()
                }
                RunLoop.main.add(timer, forMode: .default)
                postureTimer = timer
            }
        } else if config.showPostureReminder && config.interval > 10 {
            // Posture reminder at interval/2
            let postureDelay = interval / 2.0 - elapsed
            if postureDelay > 0 {
                postureTimer = Timer.scheduledTimer(withTimeInterval: postureDelay, repeats: false) { [weak self] _ in
                    guard let self, self.isActive else { return }
                    self.showPostureReminder()
                }
            }
        }
    }

    private func startBreak() {
        guard isActive else { return }
        waitStartDate = nil
        nextBreakDate = nil
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
            // Drop the timer first so endBreak can tell natural expiry from an early skip.
            self.breakTimer = nil
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
        // A still-present breakTimer means we're ending the break before its natural
        // expiration — either user Skip/Esc or session cancel. The timer's own
        // fire-handler clears it before calling skipBreak, so this distinguishes
        // those two paths.
        let timerWasValid = breakTimer != nil
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
