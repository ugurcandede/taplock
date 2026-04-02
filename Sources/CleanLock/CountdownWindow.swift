import Cocoa
import SwiftUI

/// SwiftUI view displaying the countdown timer and cancel hint.
struct CountdownView: View {
    @ObservedObject var timer: CountdownTimer

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text(timer.formattedTime)
                    .font(.system(size: 120, weight: .light, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Text("Press ⌘⌥⌃L for 3 seconds to cancel")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 60)
            }
        }
    }
}

/// Observable timer that counts down from a given duration.
final class CountdownTimer: ObservableObject {
    @Published var remainingSeconds: Double

    private var displayLink: Timer?

    init(duration: Int) {
        self.remainingSeconds = Double(duration)
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

    init(duration: Int) {
        self.timer = CountdownTimer(duration: duration)
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

        let hostingView = NSHostingView(rootView: CountdownView(timer: timer))
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
