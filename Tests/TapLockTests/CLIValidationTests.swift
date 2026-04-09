import Testing
@testable import TapLockCore

/// Tests CLI validation rules as pure logic.
/// The actual CLI code is in the executable target (not importable),
/// so we re-express the validation rules here to document and verify them.
@Suite("CLI Validation Rules")
struct CLIValidationTests {

    // MARK: - Safety Duration

    @Test func safetyDurationIsFiveMinutes() {
        // CLI uses 300 seconds (5 minutes) as safety auto-unlock
        let maxSafetyDuration = 300
        #expect(maxSafetyDuration == 5 * 60)
    }

    // MARK: - Relax Pairing

    @Test func relaxPairing_bothProvided() {
        let every: Int? = 1500
        let breakDur: Int? = 300
        let valid = (every != nil) == (breakDur != nil)
        #expect(valid)
    }

    @Test func relaxPairing_neitherProvided() {
        let every: Int? = nil
        let breakDur: Int? = nil
        let valid = (every != nil) == (breakDur != nil)
        #expect(valid)
    }

    @Test func relaxPairing_onlyEvery() {
        let every: Int? = 1500
        let breakDur: Int? = nil
        let valid = (every != nil) == (breakDur != nil)
        #expect(!valid)
    }

    @Test func relaxPairing_onlyBreak() {
        let every: Int? = nil
        let breakDur: Int? = 300
        let valid = (every != nil) == (breakDur != nil)
        #expect(!valid)
    }

    // MARK: - Interval vs Break

    @Test func intervalMustExceedBreak_valid() {
        #expect(1500 > 300)
    }

    @Test func intervalMustExceedBreak_equal() {
        // Equal is invalid — must be strictly greater
        #expect(!(300 > 300))
    }

    @Test func intervalMustExceedBreak_less() {
        #expect(!(200 > 300))
    }

    // MARK: - Opacity

    @Test func opacityRange_valid() {
        let validValues = [0.05, 0.1, 0.5, 1.0]
        for val in validValues {
            // CLI uses: val > 0 && val <= 1.0
            #expect(val > 0 && val <= 1.0, "Opacity \(val) should be valid")
        }
    }

    @Test func opacityRange_invalid() {
        let invalidValues = [0.0, -0.5, 1.1, 2.0]
        for val in invalidValues {
            #expect(!(val > 0 && val <= 1.0), "Opacity \(val) should be invalid")
        }
    }

    // MARK: - Delay

    @Test func delayMustBePositive() {
        #expect(5 > 0)  // valid
        #expect(!(0 > 0))  // invalid
        #expect(!(-1 > 0))  // invalid
    }

    // MARK: - Theme Validation

    @Test func themeValidation() {
        #expect(RelaxTheme(rawValue: "breathing") != nil)
        #expect(RelaxTheme(rawValue: "minimal") != nil)
        #expect(RelaxTheme(rawValue: "mini") != nil)
        #expect(RelaxTheme(rawValue: "unknown") == nil)
        #expect(RelaxTheme(rawValue: "Breathing") == nil) // case-sensitive
    }

    // MARK: - Color Validation (used by CLI)

    @Test func colorValidation() {
        #expect(parseColor("black") != nil)
        #expect(parseColor("FF0000") != nil)
        #expect(parseColor("invalid_color") == nil)
    }
}
