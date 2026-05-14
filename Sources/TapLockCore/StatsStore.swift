import Foundation

// MARK: - Event types

/// One persisted event in the stats log. Stored as one JSON object per line.
public enum StatsEvent: Equatable {
    case lockCompleted(LockCompleted)
    case relaxBreak(RelaxBreak)
    case relaxSessionStarted(RelaxSessionStarted)
    case relaxSessionEnded(RelaxSessionEnded)

    public var timestamp: Date {
        switch self {
        case .lockCompleted(let e): return e.timestamp
        case .relaxBreak(let e): return e.timestamp
        case .relaxSessionStarted(let e): return e.timestamp
        case .relaxSessionEnded(let e): return e.timestamp
        }
    }

    public struct LockCompleted: Equatable {
        public let timestamp: Date
        public let plannedSeconds: Int
        public let actualSeconds: Int
        public let emergencyCancelled: Bool
        public let keyboardOnly: Bool
        public let dim: Bool

        public init(timestamp: Date, plannedSeconds: Int, actualSeconds: Int, emergencyCancelled: Bool, keyboardOnly: Bool, dim: Bool) {
            self.timestamp = timestamp
            self.plannedSeconds = plannedSeconds
            self.actualSeconds = actualSeconds
            self.emergencyCancelled = emergencyCancelled
            self.keyboardOnly = keyboardOnly
            self.dim = dim
        }
    }

    public struct RelaxBreak: Equatable {
        public let timestamp: Date
        public let plannedSeconds: Int
        public let actualSeconds: Int
        public let theme: String
        public let skippedEarly: Bool

        public init(timestamp: Date, plannedSeconds: Int, actualSeconds: Int, theme: String, skippedEarly: Bool) {
            self.timestamp = timestamp
            self.plannedSeconds = plannedSeconds
            self.actualSeconds = actualSeconds
            self.theme = theme
            self.skippedEarly = skippedEarly
        }
    }

    public struct RelaxSessionStarted: Equatable {
        public let timestamp: Date
        public let intervalSeconds: Int
        public let breakSeconds: Int
        public let theme: String

        public init(timestamp: Date, intervalSeconds: Int, breakSeconds: Int, theme: String) {
            self.timestamp = timestamp
            self.intervalSeconds = intervalSeconds
            self.breakSeconds = breakSeconds
            self.theme = theme
        }
    }

    public struct RelaxSessionEnded: Equatable {
        public let timestamp: Date
        public let durationSeconds: Int
        public let breaksTaken: Int

        public init(timestamp: Date, durationSeconds: Int, breaksTaken: Int) {
            self.timestamp = timestamp
            self.durationSeconds = durationSeconds
            self.breaksTaken = breaksTaken
        }
    }
}

// MARK: - JSON wire format

/// Flat Codable record used on disk. Optional fields keep older entries readable
/// after new fields are added.
private struct StatsRecord: Codable {
    let type: String
    let timestamp: Date
    let plannedSeconds: Int?
    let actualSeconds: Int?
    let emergencyCancelled: Bool?
    let keyboardOnly: Bool?
    let dim: Bool?
    let theme: String?
    let skippedEarly: Bool?
    let intervalSeconds: Int?
    let breakSeconds: Int?
    let durationSeconds: Int?
    let breaksTaken: Int?

    enum CodingKeys: String, CodingKey {
        case type, timestamp
        case plannedSeconds = "planned_seconds"
        case actualSeconds = "actual_seconds"
        case emergencyCancelled = "emergency_cancelled"
        case keyboardOnly = "keyboard_only"
        case dim
        case theme
        case skippedEarly = "skipped_early"
        case intervalSeconds = "interval_seconds"
        case breakSeconds = "break_seconds"
        case durationSeconds = "duration_seconds"
        case breaksTaken = "breaks_taken"
    }

    static func from(_ event: StatsEvent) -> StatsRecord {
        switch event {
        case .lockCompleted(let e):
            return StatsRecord(
                type: "lock_completed",
                timestamp: e.timestamp,
                plannedSeconds: e.plannedSeconds,
                actualSeconds: e.actualSeconds,
                emergencyCancelled: e.emergencyCancelled,
                keyboardOnly: e.keyboardOnly,
                dim: e.dim,
                theme: nil, skippedEarly: nil,
                intervalSeconds: nil, breakSeconds: nil,
                durationSeconds: nil, breaksTaken: nil
            )
        case .relaxBreak(let e):
            return StatsRecord(
                type: "relax_break",
                timestamp: e.timestamp,
                plannedSeconds: e.plannedSeconds,
                actualSeconds: e.actualSeconds,
                emergencyCancelled: nil, keyboardOnly: nil, dim: nil,
                theme: e.theme, skippedEarly: e.skippedEarly,
                intervalSeconds: nil, breakSeconds: nil,
                durationSeconds: nil, breaksTaken: nil
            )
        case .relaxSessionStarted(let e):
            return StatsRecord(
                type: "relax_session_started",
                timestamp: e.timestamp,
                plannedSeconds: nil, actualSeconds: nil,
                emergencyCancelled: nil, keyboardOnly: nil, dim: nil,
                theme: e.theme, skippedEarly: nil,
                intervalSeconds: e.intervalSeconds, breakSeconds: e.breakSeconds,
                durationSeconds: nil, breaksTaken: nil
            )
        case .relaxSessionEnded(let e):
            return StatsRecord(
                type: "relax_session_ended",
                timestamp: e.timestamp,
                plannedSeconds: nil, actualSeconds: nil,
                emergencyCancelled: nil, keyboardOnly: nil, dim: nil,
                theme: nil, skippedEarly: nil,
                intervalSeconds: nil, breakSeconds: nil,
                durationSeconds: e.durationSeconds, breaksTaken: e.breaksTaken
            )
        }
    }

    func toEvent() -> StatsEvent? {
        switch type {
        case "lock_completed":
            guard let planned = plannedSeconds, let actual = actualSeconds,
                  let emergency = emergencyCancelled, let kbOnly = keyboardOnly, let dim = dim
            else { return nil }
            return .lockCompleted(.init(
                timestamp: timestamp,
                plannedSeconds: planned, actualSeconds: actual,
                emergencyCancelled: emergency, keyboardOnly: kbOnly, dim: dim
            ))
        case "relax_break":
            guard let planned = plannedSeconds, let actual = actualSeconds,
                  let theme = theme, let skipped = skippedEarly
            else { return nil }
            return .relaxBreak(.init(
                timestamp: timestamp,
                plannedSeconds: planned, actualSeconds: actual,
                theme: theme, skippedEarly: skipped
            ))
        case "relax_session_started":
            guard let interval = intervalSeconds, let brk = breakSeconds, let theme = theme
            else { return nil }
            return .relaxSessionStarted(.init(
                timestamp: timestamp,
                intervalSeconds: interval, breakSeconds: brk, theme: theme
            ))
        case "relax_session_ended":
            guard let dur = durationSeconds, let breaks = breaksTaken else { return nil }
            return .relaxSessionEnded(.init(
                timestamp: timestamp,
                durationSeconds: dur, breaksTaken: breaks
            ))
        default:
            return nil
        }
    }
}

// MARK: - Summary

public struct StatsSummary: Equatable {
    public let lockCount: Int
    public let totalLockedSeconds: Int
    public let emergencyCancellations: Int
    public let breakCount: Int
    public let totalBreakSeconds: Int
    public let breaksSkippedEarly: Int
    public let relaxSessionCount: Int
    public let totalRelaxSessionSeconds: Int

    public static let empty = StatsSummary(
        lockCount: 0, totalLockedSeconds: 0, emergencyCancellations: 0,
        breakCount: 0, totalBreakSeconds: 0, breaksSkippedEarly: 0,
        relaxSessionCount: 0, totalRelaxSessionSeconds: 0
    )

    public init(
        lockCount: Int, totalLockedSeconds: Int, emergencyCancellations: Int,
        breakCount: Int, totalBreakSeconds: Int, breaksSkippedEarly: Int,
        relaxSessionCount: Int, totalRelaxSessionSeconds: Int
    ) {
        self.lockCount = lockCount
        self.totalLockedSeconds = totalLockedSeconds
        self.emergencyCancellations = emergencyCancellations
        self.breakCount = breakCount
        self.totalBreakSeconds = totalBreakSeconds
        self.breaksSkippedEarly = breaksSkippedEarly
        self.relaxSessionCount = relaxSessionCount
        self.totalRelaxSessionSeconds = totalRelaxSessionSeconds
    }

    public static func compute(from events: [StatsEvent]) -> StatsSummary {
        var lockCount = 0, totalLocked = 0, emergencies = 0
        var breakCount = 0, totalBreak = 0, skippedEarly = 0
        var relaxCount = 0, totalRelax = 0

        for event in events {
            switch event {
            case .lockCompleted(let e):
                lockCount += 1
                totalLocked += e.actualSeconds
                if e.emergencyCancelled { emergencies += 1 }
            case .relaxBreak(let e):
                breakCount += 1
                totalBreak += e.actualSeconds
                if e.skippedEarly { skippedEarly += 1 }
            case .relaxSessionStarted:
                break
            case .relaxSessionEnded(let e):
                relaxCount += 1
                totalRelax += e.durationSeconds
            }
        }

        return StatsSummary(
            lockCount: lockCount, totalLockedSeconds: totalLocked, emergencyCancellations: emergencies,
            breakCount: breakCount, totalBreakSeconds: totalBreak, breaksSkippedEarly: skippedEarly,
            relaxSessionCount: relaxCount, totalRelaxSessionSeconds: totalRelax
        )
    }
}

// MARK: - Store

/// Append-only JSONL event log at `~/Library/Application Support/taplock/events.jsonl`.
public final class StatsStore {
    public static let shared = StatsStore()

    private let queue = DispatchQueue(label: "com.ugurcandede.taplock.stats", qos: .utility)
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Designated initializer for tests. The shared singleton uses the default path.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = supportDir.appendingPathComponent("taplock")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("events.jsonl")
        }

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public var path: String { fileURL.path }

    /// Append one event. Fire-and-forget; failures are logged to stderr.
    public func append(_ event: StatsEvent) {
        queue.async { [weak self] in
            self?.appendSync(event)
        }
    }

    /// Synchronous append, mainly for tests and CLI exit paths.
    public func appendSync(_ event: StatsEvent) {
        let record = StatsRecord.from(event)
        do {
            let data = try encoder.encode(record)
            var line = data
            line.append(0x0A) // newline
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                // File doesn't exist yet — create with the first line.
                try line.write(to: fileURL, options: .atomic)
            }
        } catch {
            FileHandle.standardError.write(Data("Warning: Could not append stats event: \(error.localizedDescription)\n".utf8))
        }
    }

    /// All events in the log, oldest first. Malformed/unknown lines are skipped.
    public func allEvents() -> [StatsEvent] {
        return queue.sync { readAllSync() }
    }

    /// Events within the given date interval (inclusive on both ends).
    public func events(in range: DateInterval) -> [StatsEvent] {
        return allEvents().filter { range.contains($0.timestamp) }
    }

    /// Convenience: events whose timestamp falls on the same calendar day as `date`,
    /// in the user's current calendar.
    public func events(on date: Date, calendar: Calendar = .current) -> [StatsEvent] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events(in: DateInterval(start: start, end: end))
    }

    /// Convenience: events from the past `days` days, inclusive of today.
    public func events(lastDays days: Int, from reference: Date = Date(), calendar: Calendar = .current) -> [StatsEvent] {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))!
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: reference))!
        return events(in: DateInterval(start: start, end: endOfToday))
    }

    /// Delete the log entirely. Used by `--reset` and tests.
    public func reset() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func readAllSync() -> [StatsEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8)
        else { return [] }

        var events: [StatsEvent] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let record = try? decoder.decode(StatsRecord.self, from: lineData),
                  let event = record.toEvent()
            else { continue }
            events.append(event)
        }
        return events
    }
}
