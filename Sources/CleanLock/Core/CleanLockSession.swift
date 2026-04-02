import Cocoa
import Foundation

/// Configuration for a CleanLock session.
struct SessionConfig {
    var duration: Int
    var keyboardOnly: Bool = false
    var dim: Bool = false
    var silent: Bool = false
    var showOverlay: Bool = true
    var overlayColor: (r: Double, g: Double, b: Double)? = nil
}

/// Orchestrates a complete lock session: input blocking, overlay, brightness, sounds.
/// Reusable by both CLI and future UI app.
final class CleanLockSession {
    private let config: SessionConfig
    private var overlayController: CountdownWindowController?
    private var emergencyObserver: NSObjectProtocol?
    private(set) var isActive = false

    /// Called when the session ends (normal timeout, emergency cancel, or programmatic cancel).
    var onEnd: (() -> Void)?

    init(config: SessionConfig) {
        self.config = config
    }

    /// Start the lock session. Call from main thread.
    /// - Throws: `CleanLockError` on failure.
    func start() throws {
        guard !isActive else { throw CleanLockError.alreadyBlocking }

        try InputBlocker.shared.startBlocking(keyboardOnly: config.keyboardOnly)
        isActive = true

        if config.dim { BrightnessControl.shared.dim() }
        if !config.silent { playSound("Tink") }

        if config.showOverlay {
            overlayController = CountdownWindowController(
                duration: config.duration,
                backgroundColor: config.overlayColor
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
    func cancel() {
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
