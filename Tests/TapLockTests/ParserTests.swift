import Testing
@testable import TapLockCore

// MARK: - Duration Parser

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

    @Test func hours() {
        #expect(parseDuration("1h") == 3600)
        #expect(parseDuration("2h") == 7200)
    }

    @Test func hoursAndMinutes() {
        #expect(parseDuration("1h30m") == 5400)
    }

    @Test func hoursMinutesSeconds() {
        #expect(parseDuration("1h2m3s") == 3723)
    }

    @Test func hoursAndSeconds() {
        #expect(parseDuration("1h30s") == 3630)
    }

    @Test func leadingZeros() {
        #expect(parseDuration("01m05s") == 65)
    }

    @Test func allZeroComponents() {
        #expect(parseDuration("0h0m0s") == nil)
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
        #expect(parseDuration("h") == nil)
    }

    @Test func whitespace() {
        #expect(parseDuration("  30  ") == 30)
        #expect(parseDuration(" 2m ") == 120)
    }

    @Test func largeValues() {
        #expect(parseDuration("99h") == 356400)
    }
}

// MARK: - Format Duration

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

    @Test func hoursOnly() {
        #expect(formatDuration(3600) == "1h")
        #expect(formatDuration(7200) == "2h")
    }

    @Test func hoursAndMinutes() {
        #expect(formatDuration(5400) == "1h30m")
    }

    @Test func hoursMinutesSeconds() {
        #expect(formatDuration(3723) == "1h2m3s")
    }

    @Test func hoursZeroMinutesSeconds() {
        #expect(formatDuration(3601) == "1h0m1s")
    }

    @Test func zero() {
        #expect(formatDuration(0) == "0s")
    }

    @Test func largeValue() {
        #expect(formatDuration(86400) == "24h")
    }
}

// MARK: - Duration Round-Trip

@Suite("Duration Round-Trip")
struct DurationRoundTripTests {
    @Test func roundTrips() {
        let values = [1, 45, 90, 120, 3600, 3723, 7200]
        for val in values {
            let formatted = formatDuration(val)
            let parsed = parseDuration(formatted)
            #expect(parsed == val, "Round-trip failed for \(val): formatted='\(formatted)', parsed=\(String(describing: parsed))")
        }
    }
}

// MARK: - Color Parser

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

    @Test func allNamedColorsExist() {
        let names = ["black", "white", "red", "green", "blue", "yellow", "orange", "purple", "gray", "grey"]
        for name in names {
            #expect(parseColor(name) != nil, "Named color '\(name)' should parse")
        }
    }

    @Test func caseInsensitivity() {
        let variants = ["BLACK", "Black", "bLaCk"]
        for v in variants {
            let c = parseColor(v)
            #expect(c?.r == 0)
            #expect(c?.g == 0)
            #expect(c?.b == 0)
        }
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

    @Test func hex3WithHash() {
        let color = parseColor("#f00")
        #expect(color?.r == 1)
        #expect(color?.g == 0)
        #expect(color?.b == 0)
    }

    @Test func hex3Expansion() {
        // "abc" expands to "aabbcc"
        let color = parseColor("abc")
        #expect(color != nil)
        #expect(color?.r == Double(0xAA) / 255.0)
        #expect(color?.g == Double(0xBB) / 255.0)
        #expect(color?.b == Double(0xCC) / 255.0)
    }

    @Test func hashPrefix() {
        #expect(parseColor("#000000") != nil)
        #expect(parseColor("#fff") != nil)
        #expect(parseColor("#00FF00")?.g == 1)
    }

    @Test func invalid() {
        #expect(parseColor("xyz") == nil)
        #expect(parseColor("") == nil)
        #expect(parseColor("12345") == nil)
        #expect(parseColor("GGGGGG") == nil)
    }

    @Test func invalidLengths() {
        #expect(parseColor("1234") == nil)
        #expect(parseColor("12345") == nil)
        #expect(parseColor("#") == nil)
    }

    @Test func invalidHexChars() {
        #expect(parseColor("ZZZZZZ") == nil)
    }

    @Test func hexBoundaries() {
        let black = parseColor("000000")
        #expect(black?.r == 0)
        #expect(black?.g == 0)
        #expect(black?.b == 0)

        let white = parseColor("FFFFFF")
        #expect(white?.r == 1)
        #expect(white?.g == 1)
        #expect(white?.b == 1)
    }

    @Test func grayGrey() {
        let gray = parseColor("gray")
        let grey = parseColor("grey")
        #expect(gray?.r == grey?.r)
        #expect(gray?.g == grey?.g)
        #expect(gray?.b == grey?.b)
    }

    @Test func hexMixedCase() {
        let a = parseColor("aAbBcC")
        let b = parseColor("AABBCC")
        #expect(a?.r == b?.r)
        #expect(a?.g == b?.g)
        #expect(a?.b == b?.b)
    }
}

// MARK: - Luminance

@Suite("Luminance")
struct LuminanceTests {
    @Test func black() {
        #expect(luminance(r: 0, g: 0, b: 0) == 0.0)
    }

    @Test func white() {
        #expect(luminance(r: 1, g: 1, b: 1) == 1.0)
    }

    @Test func pureRed() {
        #expect(luminance(r: 1, g: 0, b: 0) == 0.299)
    }

    @Test func pureGreen() {
        #expect(luminance(r: 0, g: 1, b: 0) == 0.587)
    }

    @Test func pureBlue() {
        #expect(luminance(r: 0, g: 0, b: 1) == 0.114)
    }

    @Test func yellowIsLight() {
        let lum = luminance(r: 1, g: 1, b: 0)
        #expect(lum > 0.5, "Yellow should be perceived as light")
    }

    @Test func midGrayThreshold() {
        let lum = luminance(r: 0.5, g: 0.5, b: 0.5)
        // 0.5 is NOT > 0.5, so text should be white (dark text threshold not met)
        #expect(lum == 0.5)
        #expect(!(lum > 0.5))
    }
}
