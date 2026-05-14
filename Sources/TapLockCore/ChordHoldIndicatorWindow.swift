import Cocoa
import SwiftUI

/// Observable state for the chord-hold indicator.
final class ChordHoldState: ObservableObject {
    @Published var progress: Double = 0
    @Published var remainingText: String = ""
    @Published var statusText: String = "Keep holding…"
    @Published var isVisible: Bool = false
}

/// Modal-style centered indicator shown while the user is holding ⌘⌥⌃L.
/// Visual language matches the relax `minimal` theme: tinted thin material card,
/// rounded heading, thin monospaced numerals.
struct ChordHoldIndicatorView: View {
    @ObservedObject var state: ChordHoldState
    let accentColor: Color?

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 14) {
                Text("Hold to cancel")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 5)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: state.progress)
                        .stroke(
                            Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.05), value: state.progress)

                    Text(state.remainingText)
                        .font(.system(size: 32, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Text(state.statusText)
                    .id(state.statusText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.25), value: state.statusText)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background((accentColor ?? .white).opacity(accentColor == nil ? 0.08 : 0.40))
            .background(.thinMaterial)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
            .opacity(state.isVisible ? 1.0 : 0.0)
            .scaleEffect(state.isVisible ? 1.0 : 0.94)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.isVisible)
        }
    }
}

/// Controls the chord-hold indicator panel: centered, top-most, click-through.
public final class ChordHoldIndicatorController {
    private var panel: NSPanel?
    private let state = ChordHoldState()
    private var tickTimer: Timer?
    private var startDate: Date?
    private var closeWorkItem: DispatchWorkItem?
    public let totalDuration: TimeInterval
    private let accentColor: Color?

    public init(totalDuration: TimeInterval = 3.0, accentColor: (r: Double, g: Double, b: Double)? = nil) {
        self.totalDuration = totalDuration
        if let c = accentColor {
            // Derive a contrasting tint from the user's lock color so the card stands out
            // against the (typically saturated) lock overlay underneath. Dark hues are
            // pushed toward white, light hues are pushed toward black — same hue family,
            // opposite lightness.
            let lum = luminance(r: c.r, g: c.g, b: c.b)
            let target: Double = lum > 0.6 ? 0.0 : 1.0
            let mix = 0.55
            self.accentColor = Color(
                red: c.r * (1 - mix) + target * mix,
                green: c.g * (1 - mix) + target * mix,
                blue: c.b * (1 - mix) + target * mix
            )
        } else {
            self.accentColor = nil
        }
        self.state.remainingText = String(format: "%.1f", totalDuration)
    }

    /// Show the indicator and begin the hold animation. Call from main thread.
    public func show() {
        closeWorkItem?.cancel()
        closeWorkItem = nil

        if panel == nil { createPanel() }
        panel?.orderFrontRegardless()

        startDate = Date()
        state.progress = 0
        state.remainingText = String(format: "%.1f", totalDuration)
        state.statusText = "Keep holding…"
        state.isVisible = true

        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1.0, elapsed / self.totalDuration)
            let remaining = max(0, self.totalDuration - elapsed)
            self.state.progress = progress
            self.state.remainingText = String(format: "%.1f", remaining)
            let nextStatus = progress >= 0.66 ? "Almost there…" : "Keep holding…"
            if self.state.statusText != nextStatus {
                self.state.statusText = nextStatus
            }
            if progress >= 1.0 {
                self.tickTimer?.invalidate()
                self.tickTimer = nil
            }
        }
    }

    /// Hide the indicator with a fade/scale-out. Safe to call repeatedly.
    public func hide() {
        tickTimer?.invalidate()
        tickTimer = nil
        startDate = nil
        state.isVisible = false

        closeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.state.isVisible else { return }
            self.panel?.orderOut(nil)
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Fully tear down the panel and any pending work.
    public func dispose() {
        tickTimer?.invalidate()
        tickTimer = nil
        closeWorkItem?.cancel()
        closeWorkItem = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }
        // Panel is intentionally larger than the card so the shadow has room to render
        // without being clipped by the panel boundary.
        let size = NSSize(width: 260, height: 260)
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true

        let hosting = NSHostingView(rootView: ChordHoldIndicatorView(state: state, accentColor: accentColor))
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.panel = panel
    }
}
