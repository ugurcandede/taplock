import Cocoa

/// Plays a macOS system sound by alias name (e.g. "Tink", "Glass", "Pop", "Blow").
public enum SoundPlayer {
    /// - Parameters:
    ///   - name: System sound alias (see `NSSound(named:)`).
    ///   - volume: 0.0–1.0. Default is 1.0 (NSSound's default).
    public static func play(_ name: String, volume: Float = 1.0) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}
