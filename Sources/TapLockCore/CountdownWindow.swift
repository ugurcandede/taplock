import Cocoa
import SwiftUI

/// SwiftUI view displaying the countdown timer and cancel hint.
struct CountdownView: View {
    @ObservedObject var timer: CountdownTimer
    var backgroundColor: Color
    var textColor: Color

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text(timer.currentTime)
                    .font(.system(size: 28, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.4))

                Text(timer.formattedTime)
                    .font(.system(size: 120, weight: .light, design: .monospaced))
                    .foregroundColor(textColor)

                Spacer()

                Text("Press ⌘⌥⌃L for 3 seconds to cancel")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor.opacity(0.6))
                    .padding(.bottom, 60)
            }
        }
    }
}

/// Observable timer that counts down from a given duration.
final class CountdownTimer: ObservableObject {
    @Published var remainingSeconds: Double
    @Published var currentTime: String

    private var displayLink: Timer?
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(duration: Int) {
        self.remainingSeconds = Double(duration)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        self.currentTime = f.string(from: Date())
    }

    var formattedTime: String {
        let total = max(0, Int(ceil(remainingSeconds)))
        let mins = total / 60
        let secs = total % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "%d", secs)
    }

    func start() {
        let startDate = Date()
        let initialSeconds = remainingSeconds
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            self.remainingSeconds = max(0, initialSeconds - elapsed)
            self.currentTime = self.timeFormatter.string(from: Date())
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

/// Controls the full-screen overlay window.
final class CountdownWindowController {
    private var panel: NSPanel?
    private let timer: CountdownTimer
    private let backgroundColor: Color
    private let textColor: Color

    /// - Parameters:
    ///   - duration: Lock duration in seconds.
    ///   - backgroundColor: Custom RGB tuple, or nil for default (black 0.85 opacity).
    init(duration: Int, backgroundColor: (r: Double, g: Double, b: Double)? = nil) {
        self.timer = CountdownTimer(duration: duration)
        if let bg = backgroundColor {
            self.backgroundColor = Color(red: bg.r, green: bg.g, blue: bg.b).opacity(0.85)
            let luminance = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
            self.textColor = luminance > 0.5 ? .black : .white
        } else {
            self.backgroundColor = Color.black.opacity(0.85)
            self.textColor = .white
        }
    }

    func showOverlay() {
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(
            rootView: CountdownView(
                timer: timer,
                backgroundColor: backgroundColor,
                textColor: textColor
            )
        )
        hostingView.frame = screen.frame
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        self.panel = panel

        timer.start()
    }

    func closeOverlay() {
        timer.stop()
        panel?.close()
        panel = nil
    }
}
