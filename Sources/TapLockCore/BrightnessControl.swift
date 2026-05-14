import CoreGraphics
import Foundation

/// Controls screen brightness via private DisplayServices framework.
/// Falls back gracefully if the API is unavailable.
public final class BrightnessControl {
    public static let shared = BrightnessControl()

    private var originalBrightness: Float?
    private var animationTimer: Timer?
    private var getBrightness: GetBrightnessFn?
    private var setBrightness: SetBrightnessFn?

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ) else { return }

        if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightness = unsafeBitCast(sym, to: GetBrightnessFn.self)
        }
        if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightness = unsafeBitCast(sym, to: SetBrightnessFn.self)
        }
    }

    /// Whether brightness control is available on this system.
    public var isAvailable: Bool {
        return getBrightness != nil && setBrightness != nil
    }

    /// Save current brightness (only on first call) and dim to minimum.
    /// Subsequent calls without an intervening `restore(clearSaved: true)` only animate
    /// to 0 — the saved baseline is preserved, so `restore` can return to the original.
    public func dim(animated: Bool = false, duration: TimeInterval = 0.4) {
        guard let get = getBrightness else { return }

        if originalBrightness == nil {
            var current: Float = 0
            guard get(CGMainDisplayID(), &current) == 0 else { return }
            originalBrightness = current
        }

        animateBrightness(to: 0.0, animated: animated, duration: duration)
    }

    /// Restore brightness to the value captured by the first `dim()` call.
    /// - Parameter clearSaved: When `true` (default), forgets the saved baseline.
    ///   Pass `false` for a temporary restore (e.g. while showing the cancel countdown)
    ///   so a later `dim()` can re-darken to zero without overwriting the original.
    public func restore(animated: Bool = false, duration: TimeInterval = 0.4, clearSaved: Bool = true) {
        guard let original = originalBrightness else { return }
        animateBrightness(to: original, animated: animated, duration: duration) { [weak self] in
            if clearSaved {
                self?.originalBrightness = nil
            }
        }
    }

    private func animateBrightness(
        to target: Float,
        animated: Bool,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard let get = getBrightness, let set = setBrightness else { return }

        animationTimer?.invalidate()
        animationTimer = nil

        if !animated || duration <= 0 {
            _ = set(CGMainDisplayID(), target)
            completion?()
            return
        }

        var current: Float = 0
        guard get(CGMainDisplayID(), &current) == 0 else {
            _ = set(CGMainDisplayID(), target)
            completion?()
            return
        }

        let start = current
        let startDate = Date()
        let frameInterval: TimeInterval = 1.0 / 60.0

        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] timer in
            guard let self = self, let setFn = self.setBrightness else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startDate)
            let progress = min(1.0, elapsed / duration)
            // ease-out cubic
            let eased = 1.0 - pow(1.0 - progress, 3.0)
            let value = start + (target - start) * Float(eased)
            _ = setFn(CGMainDisplayID(), value)

            if progress >= 1.0 {
                timer.invalidate()
                self.animationTimer = nil
                _ = setFn(CGMainDisplayID(), target)
                completion?()
            }
        }
    }
}
