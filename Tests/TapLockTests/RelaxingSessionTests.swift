import Testing
import Foundation
@testable import TapLockCore

// MARK: - RelaxTheme

@Suite("RelaxTheme")
struct RelaxThemeTests {

    @Test func allCasesCount() {
        #expect(RelaxTheme.allCases.count == 3)
    }

    @Test func rawValues() {
        #expect(RelaxTheme.breathing.rawValue == "breathing")
        #expect(RelaxTheme.minimal.rawValue == "minimal")
        #expect(RelaxTheme.mini.rawValue == "mini")
    }

    @Test func initFromRawValue() {
        #expect(RelaxTheme(rawValue: "breathing") == .breathing)
        #expect(RelaxTheme(rawValue: "minimal") == .minimal)
        #expect(RelaxTheme(rawValue: "mini") == .mini)
        #expect(RelaxTheme(rawValue: "invalid") == nil)
        #expect(RelaxTheme(rawValue: "") == nil)
    }

    @Test func codableRoundTrip() throws {
        for theme in RelaxTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(RelaxTheme.self, from: data)
            #expect(decoded == theme)
        }
    }
}

// MARK: - RelaxingSessionConfig

@Suite("RelaxingSessionConfig")
struct RelaxingSessionConfigTests {

    @Test func defaultValues() {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        #expect(config.interval == 1500)
        #expect(config.breakDuration == 300)
        #expect(config.theme == .breathing)
        #expect(config.color == "green")
        #expect(config.opacity == 0.85)
        #expect(config.silent == false)
        #expect(config.showPostureReminder == true)
    }

    @Test func customValues() {
        let config = RelaxingSessionConfig(
            interval: 2700,
            breakDuration: 600,
            theme: .mini,
            color: "red",
            opacity: 0.5,
            silent: true,
            showPostureReminder: false
        )
        #expect(config.interval == 2700)
        #expect(config.breakDuration == 600)
        #expect(config.theme == .mini)
        #expect(config.color == "red")
        #expect(config.opacity == 0.5)
        #expect(config.silent == true)
        #expect(config.showPostureReminder == false)
    }
}

// MARK: - RelaxingSession

@Suite("RelaxingSession State")
struct RelaxingSessionStateTests {

    @Test func initiallyInactive() {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        let session = RelaxingSession(config: config)
        #expect(session.isActive == false)
    }

    @Test func configRetained() {
        let config = RelaxingSessionConfig(
            interval: 1500,
            breakDuration: 300,
            theme: .minimal,
            color: "blue",
            opacity: 0.7,
            silent: true,
            showPostureReminder: false
        )
        let session = RelaxingSession(config: config)
        #expect(session.config.interval == 1500)
        #expect(session.config.breakDuration == 300)
        #expect(session.config.theme == .minimal)
        #expect(session.config.color == "blue")
        #expect(session.config.opacity == 0.7)
        #expect(session.config.silent == true)
        #expect(session.config.showPostureReminder == false)
    }

    @Test func invalidColorFallback() {
        // Session should create without error even with invalid color
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300, color: "not_a_color")
        let session = RelaxingSession(config: config)
        #expect(session.config.color == "not_a_color")
        // resolvedColor falls back to green internally — session still works
    }

    @Test func validColor() {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300, color: "red")
        let session = RelaxingSession(config: config)
        #expect(session.config.color == "red")
    }

    @Test func callbacksSettable() {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        let session = RelaxingSession(config: config)

        var endCalled = false
        var breakStartCalled = false
        var breakEndCalled = false

        session.onEnd = { endCalled = true }
        session.onBreakStart = { breakStartCalled = true }
        session.onBreakEnd = { breakEndCalled = true }

        // Callbacks are set but not yet invoked
        #expect(!endCalled)
        #expect(!breakStartCalled)
        #expect(!breakEndCalled)
    }
}
