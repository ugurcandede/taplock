import Cocoa
import SwiftUI

// MARK: - SwiftUI View

struct PostureReminderView: View {
    @State private var isAnimating = false
    @State private var appeared = false
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [.green.opacity(0.6), .teal.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 3)
                .padding(.horizontal, 40)
                .padding(.top, 16)

            Spacer().frame(height: 20)

            // Animated figure
            ZStack {
                Circle()
                    .fill(.green.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.15 : 0.9)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Image(systemName: "figure.stand")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.primary.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.04 : 0.96)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }

            Spacer().frame(height: 16)

            // Message
            Text("Posture Check")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Straighten your back & relax your shoulders")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
                .padding(.horizontal, 8)

            Spacer().frame(height: 20)

            // Dismiss
            Button(action: onDismiss) {
                Text("Got it")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(.primary.opacity(0.06))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Text("esc to dismiss")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
                .padding(.bottom, 14)
        }
        .frame(width: 240)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.06), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.easeOut(duration: 0.3), value: appeared)
        .onAppear {
            isAnimating = true
            appeared = true
        }
    }
}

// MARK: - Window Controller

public final class PostureWindowController {
    private var panel: NSPanel?
    private var keyMonitor: Any?

    public var onDismiss: (() -> Void)?

    deinit {
        closeOverlay()
    }

    public init() {}

    public func showOverlay() {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 260
        let height: CGFloat = 280
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height - 80
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let dismissAction: () -> Void = { [weak self] in
            self?.onDismiss?()
        }

        let hostingView = NSHostingView(
            rootView: PostureReminderView(onDismiss: dismissAction)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hostingView

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onDismiss?()
                return nil
            }
            return event
        }
    }

    public func closeOverlay() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.close()
        panel = nil
    }
}
