import Testing
@testable import CleanLockCore

@Suite("Duration Parser")
struct DurationParserTests {
    @Test func plainSeconds() {
        #expect(parseDuration("30") == 30)
        #expect(parseDuration("1") == 1)
        #expect(parseDuration("300") == 300)
    }

    @Test func secondsWithSuffix() {
        #expect(parseDuration("30s") == 30)
        #expect(parseDuration("90s") == 90)
    }

    @Test func minutes() {
        #expect(parseDuration("2m") == 120)
        #expect(parseDuration("5m") == 300)
    }

    @Test func minutesAndSeconds() {
        #expect(parseDuration("1m30s") == 90)
        #expect(parseDuration("2m15s") == 135)
    }

    @Test func zeroAndNegative() {
        #expect(parseDuration("0") == nil)
        #expect(parseDuration("-5") == nil)
        #expect(parseDuration("0s") == nil)
        #expect(parseDuration("0m") == nil)
    }

    @Test func invalid() {
        #expect(parseDuration("abc") == nil)
        #expect(parseDuration("") == nil)
        #expect(parseDuration("m") == nil)
        #expect(parseDuration("s") == nil)
    }

    @Test func whitespace() {
        #expect(parseDuration("  30  ") == 30)
        #expect(parseDuration(" 2m ") == 120)
    }
}

@Suite("Format Duration")
struct FormatDurationTests {
    @Test func seconds() {
        #expect(formatDuration(30) == "30s")
        #expect(formatDuration(1) == "1s")
        #expect(formatDuration(59) == "59s")
    }

    @Test func minutes() {
        #expect(formatDuration(60) == "1m")
        #expect(formatDuration(120) == "2m")
        #expect(formatDuration(300) == "5m")
    }

    @Test func minutesAndSeconds() {
        #expect(formatDuration(90) == "1m30s")
        #expect(formatDuration(135) == "2m15s")
    }
}

@Suite("Color Parser")
struct ColorParserTests {
    @Test func namedColors() {
        let black = parseColor("black")
        #expect(black != nil)
        #expect(black?.r == 0)
        #expect(black?.g == 0)
        #expect(black?.b == 0)

        let white = parseColor("white")
        #expect(white?.r == 1)
        #expect(white?.g == 1)
        #expect(white?.b == 1)

        let red = parseColor("RED")
        #expect(red != nil)
        #expect(red?.r == 1)
    }

    @Test func hex6() {
        let color = parseColor("FF0000")
        #expect(color != nil)
        #expect(color?.r == 1)
        #expect(color?.g == 0)
        #expect(color?.b == 0)
    }

    @Test func hex3() {
        let color = parseColor("fff")
        #expect(color != nil)
        #expect(color?.r == 1)
        #expect(color?.g == 1)
        #expect(color?.b == 1)
    }

    @Test func hashPrefix() {
        #expect(parseColor("#000000") != nil)
        #expect(parseColor("#fff") != nil)
    }

    @Test func invalid() {
        #expect(parseColor("xyz") == nil)
        #expect(parseColor("") == nil)
        #expect(parseColor("12345") == nil)
        #expect(parseColor("GGGGGG") == nil)
    }

    @Test func grayGrey() {
        let gray = parseColor("gray")
        let grey = parseColor("grey")
        #expect(gray?.r == grey?.r)
        #expect(gray?.g == grey?.g)
        #expect(gray?.b == grey?.b)
    }
}
