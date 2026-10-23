import Foundation

// MARK: - Duration Parsing

/// Parses a duration string into seconds.
/// Supported formats: `30`, `30s`, `2m`, `1m30s`, `90s`
public func parseDuration(_ input: String) -> Int? {
    let trimmed = input.trimmingCharacters(in: .whitespaces)

    if let seconds = Int(trimmed) {
        return seconds > 0 ? seconds : nil
    }

    var total = 0
    var matched = false

    if let range = trimmed.range(of: #"(\d+)h"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast()
        if let hours = Int(digits) {
            total += hours * 3600
            matched = true
        }
    }

    if let range = trimmed.range(of: #"(\d+)m"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast()
        if let mins = Int(digits) {
            total += mins * 60
            matched = true
        }
    }

    if let range = trimmed.range(of: #"(\d+)s"#, options: .regularExpression) {
        let digits = trimmed[range].dropLast()
        if let secs = Int(digits) {
            total += secs
            matched = true
        }
    }

    return matched && total > 0 ? total : nil
}

/// Format seconds into a human-readable string.
public func formatDuration(_ seconds: Int) -> String {
    if seconds >= 3600 {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if mins == 0 && secs == 0 { return "\(hours)h" }
        if secs == 0 { return "\(hours)h\(mins)m" }
        return "\(hours)h\(mins)m\(secs)s"
    }
    if seconds >= 60 {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs == 0 { return "\(mins)m" }
        return "\(mins)m\(secs)s"
    }
    return "\(seconds)s"
}

// MARK: - Luminance

/// Calculate perceived luminance from RGB components (0.0–1.0).
public func luminance(r: Double, g: Double, b: Double) -> Double {
    0.299 * r + 0.587 * g + 0.114 * b
}

// MARK: - Color Parsing

/// Parse a color name or hex string into RGB components.
public func parseColor(_ input: String) -> (r: Double, g: Double, b: Double)? {
    let namedColors: [String: (r: Double, g: Double, b: Double)] = [
        "black": (0, 0, 0),
        "white": (1, 1, 1),
        "red": (1, 0, 0),
        "green": (0, 0.8, 0),
        "blue": (0, 0, 1),
        "yellow": (1, 1, 0),
        "orange": (1, 0.65, 0),
        "purple": (0.5, 0, 0.5),
        "gray": (0.5, 0.5, 0.5),
        "grey": (0.5, 0.5, 0.5),
    ]

    if let named = namedColors[input.lowercased()] {
        return named
    }

    var clean = input.hasPrefix("#") ? String(input.dropFirst()) : input
    if clean.count == 3 {
        clean = clean.map { "\($0)\($0)" }.joined()
    }
    guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
    return (
        r: Double((value >> 16) & 0xFF) / 255.0,
        g: Double((value >> 8) & 0xFF) / 255.0,
        b: Double(value & 0xFF) / 255.0
    )
}

// MARK: - Schedule Parsing

/// Parses weekdays like `mon-fri`, `sat,sun` or `mon,wed-fri` into Calendar weekday
/// numbers (1 = Sunday ... 7 = Saturday). Ranges may wrap around the week (`fri-mon`).
public func parseWeekdays(_ input: String) -> Set<Int>? {
    let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    var days = Set<Int>()
    for part in input.lowercased().split(separator: ",", omittingEmptySubsequences: false) {
        let ends = part.split(separator: "-", omittingEmptySubsequences: false)
            .map { names.firstIndex(of: $0.trimmingCharacters(in: .whitespaces)) }
        guard (1...2).contains(ends.count), let first = ends[0], let last = ends[ends.count - 1] else { return nil }
        var day = first
        days.insert(day + 1)
        while day != last {
            day = (day + 1) % 7
            days.insert(day + 1)
        }
    }
    return days
}

/// Parses `HH:MM-HH:MM` (or `H-H`) into minutes from midnight. The range can't
/// cross midnight; the end may be 24:00.
public func parseTimeRange(_ input: String) -> (start: Int, end: Int)? {
    let parts = input.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, let start = parseClockTime(parts[0]), let end = parseClockTime(parts[1]),
          start < end else { return nil }
    return (start, end)
}

private func parseClockTime(_ input: Substring) -> Int? {
    let hm = input.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
    guard (1...2).contains(hm.count), hm[0].allSatisfy(\.isNumber), let hour = Int(hm[0]) else { return nil }
    var minute = 0
    if hm.count == 2 {
        guard hm[1].count == 2, hm[1].allSatisfy(\.isNumber), let m = Int(hm[1]) else { return nil }
        minute = m
    }
    guard minute < 60, hour * 60 + minute <= 24 * 60 else { return nil }
    return hour * 60 + minute
}
