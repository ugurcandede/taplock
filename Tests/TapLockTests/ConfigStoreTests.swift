import Testing
import Foundation
@testable import TapLockCore

@Suite("RelaxingSessionConfig Codable")
struct ConfigStoreTests {

    @Test func defaultValues() {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        #expect(config.theme == .breathing)
        #expect(config.color == "green")
        #expect(config.opacity == 0.85)
        #expect(config.silent == false)
        #expect(config.showPostureReminder == true)
    }

    @Test func encodeDecodeRoundTrip() throws {
        let original = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelaxingSessionConfig.self, from: data)
        #expect(decoded.interval == original.interval)
        #expect(decoded.breakDuration == original.breakDuration)
        #expect(decoded.theme == original.theme)
        #expect(decoded.color == original.color)
        #expect(decoded.opacity == original.opacity)
        #expect(decoded.silent == original.silent)
        #expect(decoded.showPostureReminder == original.showPostureReminder)
    }

    @Test func customValuesRoundTrip() throws {
        let original = RelaxingSessionConfig(
            interval: 2700,
            breakDuration: 600,
            theme: .minimal,
            color: "blue",
            opacity: 0.5,
            silent: true,
            showPostureReminder: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelaxingSessionConfig.self, from: data)
        #expect(decoded.interval == 2700)
        #expect(decoded.breakDuration == 600)
        #expect(decoded.theme == .minimal)
        #expect(decoded.color == "blue")
        #expect(decoded.opacity == 0.5)
        #expect(decoded.silent == true)
        #expect(decoded.showPostureReminder == false)
    }

    @Test func allThemesRoundTrip() throws {
        for theme in RelaxTheme.allCases {
            let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300, theme: theme)
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(RelaxingSessionConfig.self, from: data)
            #expect(decoded.theme == theme, "Theme \(theme.rawValue) did not survive round-trip")
        }
    }

    @Test func decodeFromManualJSON() throws {
        let json = """
        {
            "interval": 900,
            "breakDuration": 120,
            "theme": "mini",
            "color": "red",
            "opacity": 0.7,
            "silent": true,
            "showPostureReminder": false
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(RelaxingSessionConfig.self, from: json)
        #expect(config.interval == 900)
        #expect(config.breakDuration == 120)
        #expect(config.theme == .mini)
        #expect(config.color == "red")
        #expect(config.opacity == 0.7)
        #expect(config.silent == true)
        #expect(config.showPostureReminder == false)
    }

    @Test func decodeMissingFieldFails() {
        let json = """
        {"interval": 900}
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RelaxingSessionConfig.self, from: json)
        }
    }

    @Test func decodeInvalidThemeFails() {
        let json = """
        {
            "interval": 900,
            "breakDuration": 120,
            "theme": "unknown",
            "color": "green",
            "opacity": 0.85,
            "silent": false,
            "showPostureReminder": true
        }
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RelaxingSessionConfig.self, from: json)
        }
    }

    @Test func jsonKeysMatchExpected() throws {
        let config = RelaxingSessionConfig(interval: 1500, breakDuration: 300)
        let data = try JSONEncoder().encode(config)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let expectedKeys: Set<String> = ["interval", "breakDuration", "theme", "color", "opacity", "silent", "showPostureReminder"]
        #expect(Set(dict.keys) == expectedKeys)
    }
}
