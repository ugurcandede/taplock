import Testing
import Foundation
@testable import TapLockCore

@Suite("RelaxSchedule")
struct RelaxScheduleTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// 2026-10-19 is a Monday.
    private func date(day: Int = 19, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private let weekdays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri

    @Test func defaultScheduleMatchesPlainInterval() {
        let next = RelaxSchedule().nextBreak(after: date(10, 0), interval: 3000, breakDuration: 600, calendar: calendar)
        #expect(next == date(10, 50))
    }

    @Test func insideActiveHoursIsPlainInterval() {
        let s = RelaxSchedule(weekdays: weekdays, activeStart: 9 * 60, activeEnd: 18 * 60)
        #expect(s.nextBreak(after: date(10, 0), interval: 3000, breakDuration: 600, calendar: calendar) == date(10, 50))
    }

    @Test func beforeActiveHoursWaitsFromStart() {
        let s = RelaxSchedule(weekdays: weekdays, activeStart: 9 * 60, activeEnd: 18 * 60)
        #expect(s.nextBreak(after: date(7, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(9, 50))
    }

    @Test func pastActiveEndMovesToNextDay() {
        let s = RelaxSchedule(weekdays: weekdays, activeStart: 9 * 60, activeEnd: 18 * 60)
        #expect(s.nextBreak(after: date(17, 40), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 20, 9, 50))
    }

    @Test func fridayEveningSkipsWeekend() {
        let s = RelaxSchedule(weekdays: weekdays, activeStart: 9 * 60, activeEnd: 18 * 60)
        #expect(s.nextBreak(after: date(day: 23, 17, 40), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 26, 9, 50))
    }

    @Test func quietHoursRestartWaitAfterwards() {
        let s = RelaxSchedule(quietStart: 12 * 60, quietEnd: 13 * 60)
        #expect(s.nextBreak(after: date(11, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(13, 50))
    }

    @Test func startingInsideQuietHoursWaitsFromTheirEnd() {
        let s = RelaxSchedule(quietStart: 12 * 60, quietEnd: 13 * 60)
        #expect(s.nextBreak(after: date(12, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(13, 50))
    }

    @Test func waitSpanningQuietHoursRestarts() {
        let s = RelaxSchedule(quietStart: 12 * 60, quietEnd: 13 * 60)
        // 11:30 + 90m would be 13:00, but the wait crossed lunch.
        #expect(s.nextBreak(after: date(11, 30), interval: 5400, breakDuration: 600, calendar: calendar) == date(14, 30))
    }

    @Test func alignToClockUsesGridFromActiveStart() {
        let s = RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60, alignToClock: true)
        // 50/10 grid: 09:50, 10:50, 11:50 ...
        #expect(s.nextBreak(after: date(10, 17), interval: 3000, breakDuration: 600, calendar: calendar) == date(10, 50))
        #expect(s.nextBreak(after: date(10, 50), interval: 3000, breakDuration: 600, calendar: calendar) == date(11, 50))
        #expect(s.nextBreak(after: date(8, 0), interval: 3000, breakDuration: 600, calendar: calendar) == date(9, 50))
    }

    @Test func alignToClockPomodoro() {
        let s = RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60, alignToClock: true)
        // 25/5 grid: 09:25, 09:55, 10:25 ...
        #expect(s.nextBreak(after: date(9, 30), interval: 1500, breakDuration: 300, calendar: calendar) == date(9, 55))
    }

    @Test func noActiveDaysNeverFires() {
        let s = RelaxSchedule(weekdays: [])
        #expect(s.nextBreak(after: date(10, 0), interval: 3000, breakDuration: 600, calendar: calendar) == nil)
    }

    @Test func allDayWaitCrossesMidnightWithoutRestarting() {
        // 0:00–24:00 every day: midnight isn't a block, so this is the plain interval.
        #expect(RelaxSchedule().nextBreak(after: date(23, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 20, 0, 20))
    }

    @Test func allDayWaitRestartsBeforeOffDay() {
        // Sunday 23:30 with Monday off: the wait restarts Tuesday at midnight.
        let s = RelaxSchedule(weekdays: [1, 3, 4, 5, 6, 7])
        #expect(s.nextBreak(after: date(day: 18, 23, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 20, 0, 50))
    }

    @Test func allDayQuietOnNextDayStillBlocks() {
        let s = RelaxSchedule(quietStart: 0, quietEnd: 60)
        // 23:30 + 50m runs into tomorrow's 0:00–1:00 quiet window.
        #expect(s.nextBreak(after: date(23, 30), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 20, 1, 50))
    }

    @Test func alignedGridRollsToTomorrowsAnchor() {
        let s = RelaxSchedule(alignToClock: true)
        // 0:50, 1:50 ... 23:50, then tomorrow's 0:50, not midnight.
        #expect(s.nextBreak(after: date(23, 55), interval: 3000, breakDuration: 600, calendar: calendar) == date(day: 20, 0, 50))
    }

    @Test func intervalLongerThanHoursNeverFires() {
        let s = RelaxSchedule(activeStart: 9 * 60, activeEnd: 10 * 60)
        #expect(s.nextBreak(after: date(8, 0), interval: 2 * 3600, breakDuration: 600, calendar: calendar) == nil)
    }

    @Test func keepsClockTimeAcrossDST() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // Clocks spring forward on 2026-03-08 at 2:00.
        let saturdayEvening = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 20))!
        let s = RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60)
        let next = s.nextBreak(after: saturdayEvening, interval: 3000, breakDuration: 600, calendar: cal)
        #expect(next == cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 9, minute: 50)))
        let aligned = RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60, alignToClock: true)
        #expect(aligned.nextBreak(after: saturdayEvening, interval: 3000, breakDuration: 600, calendar: cal)
                == cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 9, minute: 50)))
    }

    @Test func validation() {
        #expect(RelaxSchedule().validationError == nil)
        #expect(RelaxSchedule(weekdays: []).validationError != nil)
        #expect(RelaxSchedule(activeStart: 600, activeEnd: 600).validationError != nil)
        #expect(RelaxSchedule(activeStart: 22 * 60, activeEnd: 2 * 60).validationError != nil)
        #expect(RelaxSchedule(quietStart: 720).validationError != nil)
        #expect(RelaxSchedule(quietStart: 780, quietEnd: 720).validationError != nil)
        #expect(RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60, quietStart: 8 * 60, quietEnd: 13 * 60).validationError != nil)
        #expect(RelaxSchedule(activeStart: 9 * 60, activeEnd: 18 * 60, quietStart: 12 * 60, quietEnd: 13 * 60).validationError == nil)
    }

    @Test func activeSecondsSkipsBlockedTime() {
        let s = RelaxSchedule(weekdays: weekdays, activeStart: 9 * 60, activeEnd: 18 * 60, quietStart: 12 * 60, quietEnd: 13 * 60)
        // Monday 8:00 to Monday 14:00: 9–12 and 13–14.
        #expect(s.activeSeconds(from: date(8, 0), to: date(14, 0), calendar: calendar) == 4 * 3600)
        // Friday 17:00 to Monday 10:00: 1h Friday, nothing on the weekend, 1h Monday.
        #expect(s.activeSeconds(from: date(day: 23, 17, 0), to: date(day: 26, 10, 0), calendar: calendar) == 2 * 3600)
        // A full week: 5 days × 8h.
        #expect(s.activeSeconds(from: date(0, 0), to: date(day: 26, 0, 0), calendar: calendar) == 40 * 3600)
    }

    @Test func configWithoutScheduleDecodes() throws {
        let json = #"{"interval":1500,"breakDuration":300,"theme":"breathing","color":"green","opacity":0.85,"silent":false,"showPostureReminder":true}"#
        let config = try JSONDecoder().decode(RelaxingSessionConfig.self, from: Data(json.utf8))
        #expect(config.schedule == nil)
    }
}
