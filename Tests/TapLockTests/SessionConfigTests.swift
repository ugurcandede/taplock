import Testing
@testable import TapLockCore

@Suite("SessionConfig")
struct SessionConfigTests {

    @Test func defaultValues() {
        let config = SessionConfig(duration: 60)
        #expect(config.duration == 60)
        #expect(config.keyboardOnly == false)
        #expect(config.dim == false)
        #expect(config.silent == false)
        #expect(config.showOverlay == true)
        #expect(config.overlayColor == nil)
    }

    @Test func customValues() {
        let config = SessionConfig(
            duration: 120,
            keyboardOnly: true,
            dim: true,
            silent: true,
            showOverlay: false,
            overlayColor: (r: 0.5, g: 0.3, b: 0.1)
        )
        #expect(config.duration == 120)
        #expect(config.keyboardOnly == true)
        #expect(config.dim == true)
        #expect(config.silent == true)
        #expect(config.showOverlay == false)
        #expect(config.overlayColor != nil)
        #expect(config.overlayColor?.r == 0.5)
        #expect(config.overlayColor?.g == 0.3)
        #expect(config.overlayColor?.b == 0.1)
    }

    @Test func zeroDurationAllowed() {
        let config = SessionConfig(duration: 0)
        #expect(config.duration == 0)
    }

    @Test func negativeDurationAllowed() {
        // Struct has no validation; validation happens at call site
        let config = SessionConfig(duration: -1)
        #expect(config.duration == -1)
    }

    @Test func overlayColorNilByDefault() {
        let config = SessionConfig(duration: 60)
        #expect(config.overlayColor == nil)
    }
}
