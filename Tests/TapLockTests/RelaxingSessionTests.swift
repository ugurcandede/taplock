import Testing
@testable import TapLockCore

@Suite("RelaxingSessionConfig")
struct RelaxingSessionConfigTests {

    @Test func defaultColorIsCalming() {
        let color = RelaxingSessionConfig.defaultColor
        // Should be a dark, desaturated teal — not pure black or white
        #expect(color.r < 0.5)
        #expect(color.g > 0.1)
        #expect(color.b > 0.1)
    }

    @Test func initStoresValues() {
        let config = RelaxingSessionConfig(interval: 1500, duration: 300)
        #expect(config.interval == 1500)
        #expect(config.duration == 300)
        #expect(config.overlayColor == nil)
        #expect(config.dim == false)
        #expect(config.silent == false)
        #expect(config.keyboardOnly == false)
    }

    @Test func customColorIsStored() {
        let config = RelaxingSessionConfig(
            interval: 600,
            duration: 120,
            overlayColor: (r: 0.1, g: 0.5, b: 0.4)
        )
        #expect(config.overlayColor?.r == 0.1)
        #expect(config.overlayColor?.g == 0.5)
        #expect(config.overlayColor?.b == 0.4)
    }

    @Test func flagsAreStored() {
        let config = RelaxingSessionConfig(
            interval: 900,
            duration: 300,
            dim: true,
            silent: true,
            keyboardOnly: true
        )
        #expect(config.dim == true)
        #expect(config.silent == true)
        #expect(config.keyboardOnly == true)
    }

    @Test func sessionObjectCreation() {
        let config = RelaxingSessionConfig(interval: 1500, duration: 300)
        let session = RelaxingSession(config: config)
        #expect(session.isActive == false)
        #expect(session.sessionCount == 0)
    }
}
