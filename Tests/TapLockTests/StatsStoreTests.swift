import Testing
import Foundation
@testable import TapLockCore

// MARK: - JSONL roundtrip

@Suite("StatsStore JSONL roundtrip")
struct StatsStoreRoundtripTests {
    private static func tempStore() -> StatsStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("taplock-stats-\(UUID().uuidString).jsonl")
        return StatsStore(fileURL: url)
    }

    @Test func appendsAndReadsLockCompleted() {
        let store = Self.tempStore()
        defer { store.reset() }

        let ts = Date(timeIntervalSince1970: 1_715_000_000)
        let event: StatsEvent = .lockCompleted(.init(
            timestamp: ts, plannedSeconds: 1800, actualSeconds: 1800,
            emergencyCancelled: false, keyboardOnly: false, dim: true
        ))
        store.appendSync(event)

        let all = store.allEvents()
        #expect(all.count == 1)
        #expect(all.first == event)
    }

    @Test func appendsAndReadsAllEventTypes() {
        let store = Self.tempStore()
        defer { store.reset() }

        let ts = Date(timeIntervalSince1970: 1_715_000_000)
        let events: [StatsEvent] = [
            .lockCompleted(.init(timestamp: ts, plannedSeconds: 1800, actualSeconds: 1500,
                                 emergencyCancelled: true, keyboardOnly: true, dim: false)),
            .relaxSessionStarted(.init(timestamp: ts.addingTimeInterval(60),
                                       intervalSeconds: 1500, breakSeconds: 300, theme: "breathing")),
            .relaxBreak(.init(timestamp: ts.addingTimeInterval(120),
                              plannedSeconds: 300, actualSeconds: 180,
                              theme: "breathing", skippedEarly: true)),
            .relaxSessionEnded(.init(timestamp: ts.addingTimeInterval(180),
                                     durationSeconds: 5400, breaksTaken: 3))
        ]
        for e in events { store.appendSync(e) }

        let read = store.allEvents()
        #expect(read.count == 4)
        #expect(read == events)
    }

    @Test func malformedLinesAreSkipped() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("taplock-stats-malformed-\(UUID().uuidString).jsonl")

        let mixed = """
        not json
        {"type":"unknown_type","timestamp":"2026-05-14T10:00:00Z"}
        {"type":"lock_completed","timestamp":"2026-05-14T10:00:00Z","planned_seconds":60,"actual_seconds":60,"emergency_cancelled":false,"keyboard_only":false,"dim":false}

        """
        try mixed.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = StatsStore(fileURL: url)
        let events = store.allEvents()
        #expect(events.count == 1)
        if case .lockCompleted = events.first {} else {
            Issue.record("Expected single lock_completed event after skipping malformed lines")
        }
    }
}

// MARK: - Time-window queries

@Suite("StatsStore date queries")
struct StatsStoreDateQueryTests {
    private static func tempStore() -> StatsStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("taplock-stats-\(UUID().uuidString).jsonl")
        return StatsStore(fileURL: url)
    }

    @Test func eventsOnDayMatchesCalendarDay() {
        let store = Self.tempStore()
        defer { store.reset() }

        let cal = Calendar(identifier: .gregorian)
        let today10am = cal.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 10))!
        let yesterday11pm = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 23))!
        let tomorrow1am = cal.date(from: DateComponents(year: 2026, month: 5, day: 15, hour: 1))!

        for ts in [today10am, yesterday11pm, tomorrow1am] {
            store.appendSync(.lockCompleted(.init(
                timestamp: ts, plannedSeconds: 60, actualSeconds: 60,
                emergencyCancelled: false, keyboardOnly: false, dim: false
            )))
        }

        let todayEvents = store.events(on: today10am, calendar: cal)
        #expect(todayEvents.count == 1)
        #expect(todayEvents.first?.timestamp == today10am)
    }

    @Test func lastDaysIncludesToday() {
        let store = Self.tempStore()
        defer { store.reset() }

        let cal = Calendar(identifier: .gregorian)
        let reference = cal.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        let dayMinus6 = cal.date(byAdding: .day, value: -6, to: reference)!
        let dayMinus7 = cal.date(byAdding: .day, value: -7, to: reference)!

        for ts in [reference, dayMinus6, dayMinus7] {
            store.appendSync(.lockCompleted(.init(
                timestamp: ts, plannedSeconds: 60, actualSeconds: 60,
                emergencyCancelled: false, keyboardOnly: false, dim: false
            )))
        }

        let week = store.events(lastDays: 7, from: reference, calendar: cal)
        // Today + 6 days back = 7 days inclusive. dayMinus7 should be excluded.
        #expect(week.count == 2)
    }
}

// MARK: - Summary aggregation

@Suite("StatsSummary aggregation")
struct StatsSummaryTests {

    @Test func emptyEventsProducesZeroSummary() {
        let summary = StatsSummary.compute(from: [])
        #expect(summary == .empty)
    }

    @Test func aggregatesLockSessions() {
        let events: [StatsEvent] = [
            .lockCompleted(.init(timestamp: Date(), plannedSeconds: 1800, actualSeconds: 1800,
                                 emergencyCancelled: false, keyboardOnly: false, dim: false)),
            .lockCompleted(.init(timestamp: Date(), plannedSeconds: 600, actualSeconds: 420,
                                 emergencyCancelled: true, keyboardOnly: false, dim: true)),
        ]
        let s = StatsSummary.compute(from: events)
        #expect(s.lockCount == 2)
        #expect(s.totalLockedSeconds == 2220)
        #expect(s.emergencyCancellations == 1)
    }

    @Test func aggregatesBreaksAndSessions() {
        let events: [StatsEvent] = [
            .relaxSessionStarted(.init(timestamp: Date(), intervalSeconds: 1500, breakSeconds: 300, theme: "breathing")),
            .relaxBreak(.init(timestamp: Date(), plannedSeconds: 300, actualSeconds: 300,
                              theme: "breathing", skippedEarly: false)),
            .relaxBreak(.init(timestamp: Date(), plannedSeconds: 300, actualSeconds: 120,
                              theme: "breathing", skippedEarly: true)),
            .relaxSessionEnded(.init(timestamp: Date(), durationSeconds: 5400, breaksTaken: 2)),
        ]
        let s = StatsSummary.compute(from: events)
        #expect(s.breakCount == 2)
        #expect(s.totalBreakSeconds == 420)
        #expect(s.breaksSkippedEarly == 1)
        #expect(s.relaxSessionCount == 1)
        #expect(s.totalRelaxSessionSeconds == 5400)
    }

    @Test func sessionStartedDoesNotInflateSessionCount() {
        // Only relaxSessionEnded increments the session count — a stale started
        // event without its end shouldn't count.
        let events: [StatsEvent] = [
            .relaxSessionStarted(.init(timestamp: Date(), intervalSeconds: 1500, breakSeconds: 300, theme: "breathing"))
        ]
        let s = StatsSummary.compute(from: events)
        #expect(s.relaxSessionCount == 0)
    }
}
