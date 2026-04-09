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
