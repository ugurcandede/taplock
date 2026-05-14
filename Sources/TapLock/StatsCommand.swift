import TapLockCore
import Foundation

// MARK: - Argument Parsing

struct StatsOptions {
    enum Period {
        case today
        case lastDays(Int)
        case all
    }
    var period: Period = .today
    var json: Bool = false
    var reset: Bool = false
}

func parseStatsArguments(_ args: [String]) -> StatsOptions {
    var opts = StatsOptions()
    var i = 0
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--help", "-h":
            printStatsHelp()
        case "--today":
            opts.period = .today
        case "--week":
            opts.period = .lastDays(7)
        case "--month":
            opts.period = .lastDays(30)
        case "--all":
            opts.period = .all
        case "--json":
            opts.json = true
        case "--reset":
            opts.reset = true
        default:
            fputs("Error: Unknown option '\(arg)'. Use 'taplock stats --help' for usage.\n", stderr)
            exit(ExitCode.generalError.rawValue)
        }
        i += 1
    }
    return opts
}

func printStatsHelp() -> Never {
    print("""
    USAGE: taplock stats [period] [--json]
           taplock stats --reset

    Show session statistics from the event log
    (\(StatsStore.shared.path)).

    PERIOD (default: today):
      --today    Today's events
      --week     Last 7 days
      --month    Last 30 days
      --all      All recorded events

    OUTPUT:
      --json     Emit summary as JSON for scripting

    OTHER:
      --reset    Delete the event log (cannot be undone)
      -h, --help Show this help
    """)
    exit(ExitCode.success.rawValue)
}

// MARK: - Run

func runStatsMode(_ args: [String]) {
    let opts = parseStatsArguments(args)

    if opts.reset {
        StatsStore.shared.reset()
        print("Stats log cleared.")
        exit(ExitCode.success.rawValue)
    }

    let store = StatsStore.shared
    let events: [StatsEvent]
    let label: String

    switch opts.period {
    case .today:
        events = store.events(on: Date())
        label = "today (\(isoDate(Date())))"
    case .lastDays(let days):
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: end))!
        events = store.events(lastDays: days)
        label = "last \(days) days (\(isoDate(start)) → \(isoDate(end)))"
    case .all:
        events = store.allEvents()
        if let first = events.first {
            label = "all time (since \(isoDate(first.timestamp)))"
        } else {
            label = "all time"
        }
    }

    let summary = StatsSummary.compute(from: events)

    if opts.json {
        printStatsJSON(summary: summary, periodLabel: label, eventCount: events.count)
    } else {
        printStatsText(summary: summary, periodLabel: label)
    }

    exit(ExitCode.success.rawValue)
}

// MARK: - Text output

private func printStatsText(summary: StatsSummary, periodLabel: String) {
    print("TapLock stats — \(periodLabel)")
    print("")

    if summary == .empty {
        print("  No activity yet.")
        return
    }

    let labelW = 8
    let countW = 4

    if summary.lockCount > 0 {
        var line = "  \(pad("Locks", labelW))\(rpad("\(summary.lockCount)", countW))  \(formatDuration(summary.totalLockedSeconds))"
        if summary.emergencyCancellations > 0 {
            line += "   (\(summary.emergencyCancellations) emergency)"
        }
        print(line)
    }

    if summary.breakCount > 0 {
        var line = "  \(pad("Breaks", labelW))\(rpad("\(summary.breakCount)", countW))  \(formatDuration(summary.totalBreakSeconds))"
        if summary.breaksSkippedEarly > 0 {
            line += "   (\(summary.breaksSkippedEarly) skipped early)"
        }
        print(line)
    }

    if summary.relaxSessionCount > 0 {
        let line = "  \(pad("Relax", labelW))\(rpad("\(summary.relaxSessionCount)", countW))  \(formatDuration(summary.totalRelaxSessionSeconds))"
        print(line)
    }
}

private func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

private func rpad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}

// MARK: - JSON output

private struct StatsJSONOutput: Encodable {
    let period: String
    let eventCount: Int
    let lockCount: Int
    let totalLockedSeconds: Int
    let emergencyCancellations: Int
    let breakCount: Int
    let totalBreakSeconds: Int
    let breaksSkippedEarly: Int
    let relaxSessionCount: Int
    let totalRelaxSessionSeconds: Int

    enum CodingKeys: String, CodingKey {
        case period
        case eventCount = "event_count"
        case lockCount = "lock_count"
        case totalLockedSeconds = "total_locked_seconds"
        case emergencyCancellations = "emergency_cancellations"
        case breakCount = "break_count"
        case totalBreakSeconds = "total_break_seconds"
        case breaksSkippedEarly = "breaks_skipped_early"
        case relaxSessionCount = "relax_session_count"
        case totalRelaxSessionSeconds = "total_relax_session_seconds"
    }
}

private func printStatsJSON(summary: StatsSummary, periodLabel: String, eventCount: Int) {
    let output = StatsJSONOutput(
        period: periodLabel,
        eventCount: eventCount,
        lockCount: summary.lockCount,
        totalLockedSeconds: summary.totalLockedSeconds,
        emergencyCancellations: summary.emergencyCancellations,
        breakCount: summary.breakCount,
        totalBreakSeconds: summary.totalBreakSeconds,
        breaksSkippedEarly: summary.breaksSkippedEarly,
        relaxSessionCount: summary.relaxSessionCount,
        totalRelaxSessionSeconds: summary.totalRelaxSessionSeconds
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    guard let data = try? encoder.encode(output),
          let text = String(data: data, encoding: .utf8) else {
        fputs("Error: Could not encode stats as JSON.\n", stderr)
        exit(ExitCode.generalError.rawValue)
    }

    print(text)
}

// MARK: - Helpers

private func isoDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}
