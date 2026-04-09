import Testing
import Foundation
@testable import TapLockCore

@Suite("CountdownTimer Formatting")
struct CountdownTimerTests {

    @Test func formattedTimeZero() {
        let timer = CountdownTimer(duration: 0)
        #expect(timer.formattedTime == "0")
    }

    @Test func formattedTimeSeconds() {
        let timer = CountdownTimer(duration: 45)
        #expect(timer.formattedTime == "45")
    }

    @Test func formattedTimeOneSecond() {
        let timer = CountdownTimer(duration: 1)
        #expect(timer.formattedTime == "1")
    }

    @Test func formattedTimeOneMinute() {
        let timer = CountdownTimer(duration: 60)
        #expect(timer.formattedTime == "1:00")
    }

    @Test func formattedTimeMixed() {
        let timer = CountdownTimer(duration: 90)
        #expect(timer.formattedTime == "1:30")
    }

    @Test func formattedTimePaddedSeconds() {
        let timer = CountdownTimer(duration: 65)
        #expect(timer.formattedTime == "1:05")
    }

    @Test func formattedTimeLarge() {
        let timer = CountdownTimer(duration: 3661)
        #expect(timer.formattedTime == "61:01")
    }

    @Test func remainingSecondsInit() {
        let timer = CountdownTimer(duration: 120)
        #expect(timer.remainingSeconds == 120.0)
    }

    @Test func currentTimeFormat() {
        let timer = CountdownTimer(duration: 10)
        // currentTime should match HH:mm pattern
        let regex = try! NSRegularExpression(pattern: #"^\d{2}:\d{2}$"#)
        let range = NSRange(timer.currentTime.startIndex..., in: timer.currentTime)
        #expect(regex.firstMatch(in: timer.currentTime, range: range) != nil,
                "currentTime '\(timer.currentTime)' should match HH:mm format")
    }
}
