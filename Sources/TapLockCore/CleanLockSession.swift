import Cocoa
import Foundation

/// Configuration for a TapLock session.
public struct SessionConfig {
    public var duration: Int
    public var keyboardOnly: Bool
    public var dim: Bool
    public var silent: Bool
    public var showOverlay: Bool
    public var overlayColor: (r: Double, g: Double, b: Double)?
    /// Optional title displayed on the overlay (e.g. "Time to Relax 🌊").
    public var overlayTitle: String?

    public init(
        duration: Int,
        keyboardOnly: Bool = false,
        dim: Bool = false,
        silent: Bool = false,
        showOverlay: Bool = true,
        overlayColor: (r: Double, g: Double, b: Double)? = nil,
        overlayTitle: String? = nil
    ) {
        self.duration = duration
        self.keyboardOnly = keyboardOnly
        self.dim = dim
        self.silent = silent
        self.showOverlay = showOverlay
        self.overlayColor = overlayColor
        self.overlayTitle = overlayTitle
    }
}

/// Orchestrates a complete lock session: input blocking, overlay, brightness, sounds.
/// Reusable by both CLI and future UI app.
public final class TapLockSession {
    private let config: SessionConfig
    private var overlayController: CountdownWindowController?
    private var emergencyObserver: NSObjectProtocol?
    public private(set) var isActive = false

    /// Called when the session ends (normal timeout, emergency cancel, or programmatic cancel).
    public var onEnd: (() -> Void)?

    public init(config: SessionConfig) {
        self.config = config
    }

    /// Start the lock session. Call from main thread.
    /// - Throws: `TapLockError` on failure.
    public func start() throws {
        guard !isActive else { throw TapLockError.alreadyBlocking }

        do {
            try InputBlocker.shared.startBlocking(keyboardOnly: config.keyboardOnly)
        } catch {
            end()
            throw error
        }
        isActive = true

        if config.dim { BrightnessControl.shared.dim() }
        if !config.silent { playSound("Tink") }

        if config.showOverlay {
            overlayController = CountdownWindowController(
                duration: config.duration,
                backgroundColor: config.overlayColor,
                title: config.overlayTitle
            )
            overlayController?.showOverlay()
        }

        // Listen for emergency cancel
        emergencyObserver = NotificationCenter.default.addObserver(
            forName: .cleanLockEmergencyCancel, object: nil, queue: .main
        ) { [weak self] _ in
            self?.end()
        }

        // Schedule auto-unlock
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(config.duration)) { [weak self] in
            self?.end()
        }
    }

    /// Cancel the session programmatically.
    public func cancel() {
        end()
    }

    /// Internal cleanup — idempotent.
    private func end() {
        guard isActive else { return }
        isActive = false

        InputBlocker.shared.stopBlocking()
        BrightnessControl.shared.restore()
        overlayController?.closeOverlay()
        overlayController = nil

        if let observer = emergencyObserver {
            NotificationCenter.default.removeObserver(observer)
            emergencyObserver = nil
        }

        if !config.silent { playSound("Glass") }

        onEnd?()
    }

    /// Play a system sound by name (non-blocking).
    private func playSound(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
