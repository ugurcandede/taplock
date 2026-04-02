import CoreGraphics
import Foundation

/// Controls screen brightness via private DisplayServices framework.
/// Falls back gracefully if the API is unavailable.
final class BrightnessControl {
    static let shared = BrightnessControl()

    private var originalBrightness: Float?
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
    var isAvailable: Bool {
        return getBrightness != nil && setBrightness != nil
    }

    /// Save current brightness and dim to minimum.
    func dim() {
        guard let get = getBrightness, let set = setBrightness else { return }
        var current: Float = 0
        if get(CGMainDisplayID(), &current) == 0 {
            originalBrightness = current
            _ = set(CGMainDisplayID(), 0.0)
        }
    }

    /// Restore brightness to the value saved by `dim()`.
    func restore() {
        guard let set = setBrightness, let original = originalBrightness else { return }
        _ = set(CGMainDisplayID(), original)
        originalBrightness = nil
    }
}
