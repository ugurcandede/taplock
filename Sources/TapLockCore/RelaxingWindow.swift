import Cocoa
import SwiftUI

// MARK: - SwiftUI Views

struct RelaxingView: View {
    @ObservedObject var timer: CountdownTimer
    let theme: RelaxTheme
    let accentColor: Color
    let overlayOpacity: Double
    let textColor: Color
    let onSkip: () -> Void

    var body: some View {
        switch theme {
        case .breathing:
            breathingLayout
        case .minimal:
            minimalLayout
        case .mini:
            miniLayout
        }
    }

    private var breathingLayout: some View {
        ZStack {
            BreathingBackground(accentColor: accentColor, opacity: overlayOpacity)

            VStack(spacing: 30) {
                Spacer()

                Text("Take a break")
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .foregroundColor(textColor)

                Text(timer.currentTime)
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.8))

                Text(timer.formattedTime)
                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.5))

                Spacer()

                skipButton
                skipHint
            }
        }
    }

    private var minimalLayout: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Take a break")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)

                Text(timer.currentTime)
                    .font(.system(size: 36, weight: .thin, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.9))

                Text(timer.formattedTime)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.5))

                skipButton
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
            .background(accentColor.opacity(0.35))
            .background(.thinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }

    private var miniLayout: some View {
        VStack {
            HStack(spacing: 16) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                Text("Take a break")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)

                Text(timer.formattedTime)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.6))

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.2), radius: 10)
            .padding(.top, 12)

            Spacer()
        }
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("Skip")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor.opacity(0.8))
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                .background(textColor.opacity(0.15))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var skipHint: some View {
        Text("Press Esc to skip")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(textColor.opacity(0.35))
            .padding(.bottom, 50)
    }
}

// MARK: - Breathing Theme Background

struct BreathingBackground: View {
    let accentColor: Color
    var opacity: Double = 0.85
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Color.black.opacity(opacity)
                .ignoresSafeArea()

            Circle()
                .fill(accentColor.opacity(0.3))
                .frame(width: 300, height: 300)
                .scaleEffect(isPulsing ? 1.4 : 0.8)
                .opacity(isPulsing ? 0.6 : 0.2)
                .blur(radius: 60)
                .animation(
                    .easeInOut(duration: 4).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }
        }
    }
}

// MARK: - Window Controller

/// Controls the full-screen relaxing overlay.
public final class RelaxingWindowController {
    private var panel: NSPanel?
    private let timer: CountdownTimer
    private let theme: RelaxTheme
    private let accentColor: Color
    private let opacity: Double
    private let textColor: Color
    private var keyMonitor: Any?

    public var onSkip: (() -> Void)?

    deinit {
        closeOverlay()
    }

    public init(duration: Int, theme: RelaxTheme, color: (r: Double, g: Double, b: Double), opacity: Double = 0.85) {
        self.timer = CountdownTimer(duration: duration)
        self.theme = theme
        self.opacity = opacity
        self.accentColor = Color(red: color.r, green: color.g, blue: color.b)

        // Determine text color based on theme
        switch theme {
        case .breathing, .mini:
            self.textColor = .white
        case .minimal:
            let luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
            self.textColor = luminance > 0.5 ? .black : .white
        }
    }

    public func showOverlay() {
        guard let screen = NSScreen.main else { return }

        let panelFrame: NSRect
        if theme == .mini {
            // Small bar at top center of screen
            let barWidth: CGFloat = 340
            let barHeight: CGFloat = 50
            let x = screen.frame.midX - barWidth / 2
            let y = screen.frame.maxY - barHeight - 12
            panelFrame = NSRect(x: x, y: y, width: barWidth, height: barHeight)
        } else {
            panelFrame = screen.frame
        }

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let skipAction: () -> Void = { [weak self] in
            self?.onSkip?()
        }

        let hostingView = NSHostingView(
            rootView: RelaxingView(
                timer: timer,
                theme: theme,
                accentColor: accentColor,
                overlayOpacity: opacity,
                textColor: textColor,
                onSkip: skipAction
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: panelFrame.size)
        panel.contentView = hostingView

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        timer.start()

        // Escape key monitor
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.onSkip?()
                return nil
            }
            return event
        }
    }

    public func closeOverlay() {
        timer.stop()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.close()
        panel = nil
    }
}
