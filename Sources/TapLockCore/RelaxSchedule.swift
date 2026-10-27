import Foundation

/// Why a schedule is holding the next break back, for the paused screen.
public enum RelaxPauseReason: Equatable {
    /// An off day, or before or after the active hours.
    case outsideHours
    case quietHours
    /// Inside the hours, but no full interval fits before quiet hours start.
    case beforeQuietHours
    /// Inside the hours, but no full interval fits before they end.
    case doneForToday
}

/// Optional wall-clock rules for a relax session. A session without a schedule
/// keeps the plain behavior: a break every `interval` seconds after the last one.
public struct RelaxSchedule: Codable, Equatable {
    /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday) on which breaks may fire.
    public var weekdays: Set<Int>
    /// Active window, in minutes from midnight. Breaks only fire in [start, end).
    /// Ranges never cross midnight; end may be 24 * 60.
    public var activeStart: Int
    public var activeEnd: Int
    /// Optional quiet window (e.g. lunch), in minutes from midnight. No breaks in [start, end).
    /// Both nil or both set, and inside the active window.
    public var quietStart: Int?
    public var quietEnd: Int?
    /// Break on a fixed grid: activeStart + interval, then every interval + break.
    public var alignToClock: Bool

    public init(
        weekdays: Set<Int> = Set(1...7),
        activeStart: Int = 0,
        activeEnd: Int = 24 * 60,
        quietStart: Int? = nil,
        quietEnd: Int? = nil,
        alignToClock: Bool = false
    ) {
        self.weekdays = weekdays
        self.activeStart = activeStart
        self.activeEnd = activeEnd
        self.quietStart = quietStart
        self.quietEnd = quietEnd
        self.alignToClock = alignToClock
    }

    /// Why the schedule can't be used, or nil if it is well-formed. It can still
    /// allow no break at all (e.g. interval longer than the hours); `nextBreak` tells.
    public var validationError: String? {
        if weekdays.isEmpty { return "Pick at least one day" }
        if !(0 <= activeStart && activeStart < activeEnd && activeEnd <= 24 * 60) {
            return "Hours must start before they end"
        }
        if (quietStart == nil) != (quietEnd == nil) { return "Quiet hours need a start and an end" }
        if let qs = quietStart, let qe = quietEnd {
            if qs >= qe { return "Quiet hours must start before they end" }
            if qs < activeStart || qe > activeEnd { return "Quiet hours must be within active hours" }
        }
        return nil
    }

    /// When the next break should start for a wait that began at `waitStart`.
    /// A wait that runs into an off day, the end of the active window or the quiet
    /// window restarts in full when that block ends. Returns nil if no break can ever fire.
    public func nextBreak(
        after waitStart: Date,
        interval: Int,
        breakDuration: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard validationError == nil else { return nil }
        var resume = waitStart
        // Each pass either returns or jumps to the start or end of a blocked range;
        // at most four per day over a week bounds the loop.
        for _ in 0..<64 {
            if let until = blockedUntil(resume, calendar: calendar) {
                resume = until
                continue
            }
            let candidate = alignToClock
                ? gridPoint(after: resume, interval: interval, breakDuration: breakDuration, calendar: calendar)
                : resume.addingTimeInterval(TimeInterval(interval))
            let blockStart = nextBlockStart(after: resume, calendar: calendar)
            if candidate < blockStart { return candidate }
            resume = blockStart
        }
        return nil
    }

    /// Why breaks are held back at `date`, for a session whose next break is
    /// more than an interval away.
    public func pauseReason(at date: Date, calendar: Calendar = .current) -> RelaxPauseReason {
        let minute = secondOfDay(date, calendar: calendar) / 60
        let activeToday = weekdays.contains(calendar.component(.weekday, from: date))
        if !activeToday || minute < activeStart || minute >= activeEnd { return .outsideHours }
        if let qs = quietStart, let qe = quietEnd {
            if minute >= qs && minute < qe { return .quietHours }
            if minute < qs { return .beforeQuietHours }
        }
        return .doneForToday
    }

    /// Seconds of [from, to) that fall inside active, non-quiet time.
    public func activeSeconds(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        guard validationError == nil, from < to else { return 0 }
        var ranges = [(activeStart, activeEnd)]
        if let qs = quietStart, let qe = quietEnd {
            ranges = [(activeStart, qs), (qe, activeEnd)]
        }
        var total: TimeInterval = 0
        var day = calendar.startOfDay(for: from)
        while day < to {
            if weekdays.contains(calendar.component(.weekday, from: day)) {
                for (start, end) in ranges {
                    let lo = max(from, time(start * 60, on: day, calendar: calendar))
                    let hi = min(to, time(end * 60, on: day, calendar: calendar))
                    if lo < hi { total += hi.timeIntervalSince(lo) }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return Int(total)
    }

    /// First grid point strictly after `date`. The grid is anchored to the day's
    /// active start so the rhythm matches simple mode, just pinned to the clock.
    /// Computed in wall-clock seconds so a DST change doesn't shift it.
    private func gridPoint(after date: Date, interval: Int, breakDuration: Int, calendar: Calendar) -> Date {
        let anchor = activeStart * 60 + interval
        let now = secondOfDay(date, calendar: calendar)
        guard now >= anchor else { return time(anchor, on: date, calendar: calendar) }
        let period = interval + breakDuration
        let point = anchor + ((now - anchor) / period + 1) * period
        if point < 24 * 3600 { return time(point, on: date, calendar: calendar) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return time(anchor, on: tomorrow, calendar: calendar)
    }

    /// Start of the first blocked range after an unblocked `date`: the quiet window
    /// if it is still ahead, otherwise the end of the active window. With 0:00–24:00
    /// hours, midnight is only a block if the next day is off.
    private func nextBlockStart(after date: Date, calendar: Calendar) -> Date {
        var day = date
        var minute = secondOfDay(date, calendar: calendar) / 60
        for _ in 0..<8 {
            // `date` is unblocked, so on its own day minute == qs can't happen.
            if let qs = quietStart, minute <= qs {
                return time(qs * 60, on: day, calendar: calendar)
            }
            let end = time(activeEnd * 60, on: day, calendar: calendar)
            guard activeStart == 0, activeEnd == 24 * 60,
                  weekdays.contains(calendar.component(.weekday, from: end)) else { return end }
            day = end
            minute = 0
        }
        return .distantFuture
    }

    /// nil if a break may fire at `date`; otherwise the moment the block ends.
    private func blockedUntil(_ date: Date, calendar: Calendar) -> Date? {
        let minute = secondOfDay(date, calendar: calendar) / 60
        let activeToday = weekdays.contains(calendar.component(.weekday, from: date))

        if activeToday && minute < activeStart {
            return time(activeStart * 60, on: date, calendar: calendar)
        }
        if !activeToday || minute >= activeEnd {
            for offset in 1...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) else { continue }
                if weekdays.contains(calendar.component(.weekday, from: day)) {
                    return time(activeStart * 60, on: day, calendar: calendar)
                }
            }
            return .distantFuture
        }
        if let qs = quietStart, let qe = quietEnd, minute >= qs && minute < qe {
            return time(qe * 60, on: date, calendar: calendar)
        }
        return nil
    }

    private func secondOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
    }

    /// Wall-clock time `second` seconds after midnight on `date`'s day. 24:00 and
    /// later is the next midnight. Set by components, not added, so DST days keep
    /// the clock time.
    private func time(_ second: Int, on date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        if second >= 24 * 3600 {
            return calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return calendar.date(bySettingHour: second / 3600, minute: second % 3600 / 60, second: second % 60, of: day) ?? day
    }
}
