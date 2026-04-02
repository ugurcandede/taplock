import Cocoa
import Foundation

/// Error types for input blocking operations.
enum CleanLockError: Error, CustomStringConvertible {
    case accessibilityDenied
    case eventTapCreationFailed
    case alreadyBlocking
    case notBlocking

    var description: String {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required to block input."
        case .eventTapCreationFailed:
            return "Failed to create CGEvent tap. Is Accessibility permission granted?"
        case .alreadyBlocking:
            return "Input blocking is already active."
        case .notBlocking:
            return "No active blocking session."
        }
    }
}

/// Notification posted when emergency cancel is triggered (⌘⌥⌃L held 3s).
extension Notification.Name {
    static let cleanLockEmergencyCancel = Notification.Name("cleanLockEmergencyCancel")
}

/// Blocks keyboard and trackpad/mouse input via CGEvent tap.
final class InputBlocker {
    static let shared = InputBlocker()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isBlocking = false
    private var keyboardOnly = false

    /// Tracks when the emergency cancel combo was first detected.
    var emergencyCancelStart: Date?

    /// The screen center point for cursor locking.
    var cursorLockPoint: CGPoint = .zero

    /// The L key's macOS virtual keycode.
    private static let lKeyCode: Int64 = 0x25

    /// Duration the emergency combo must be held.
    private static let emergencyHoldDuration: TimeInterval = 3.0

    private init() {}

    // MARK: - Public API

    /// Start blocking input.
    /// - Parameter keyboardOnly: If true, only keyboard events are blocked.
    /// - Throws: `CleanLockError` if already blocking, no accessibility, or tap creation fails.
    func startBlocking(keyboardOnly: Bool = false) throws {
        guard !isBlocking else { throw CleanLockError.alreadyBlocking }
        guard InputBlocker.checkAccessibility() else { throw CleanLockError.accessibilityDenied }

        self.keyboardOnly = keyboardOnly
        self.emergencyCancelStart = nil

        var eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        if !keyboardOnly {
            eventMask |= (1 << CGEventType.mouseMoved.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.leftMouseUp.rawValue)
                | (1 << CGEventType.rightMouseDown.rawValue)
                | (1 << CGEventType.rightMouseUp.rawValue)
                | (1 << CGEventType.scrollWheel.rawValue)
                | (1 << CGEventType.leftMouseDragged.rawValue)
                | (1 << CGEventType.rightMouseDragged.rawValue)
                // Gesture events (3-finger swipe, pinch, etc.)
                | (1 << 29) // NSEventTypeGesture
                | (1 << 30) // NSEventTypeBeginGesture
                | (1 << 31) // NSEventTypeEndGesture

            // Store screen center for cursor locking
            if let screen = NSScreen.main {
                self.cursorLockPoint = CGPoint(
                    x: screen.frame.midX,
                    y: screen.frame.midY
                )
            }
            // Hide cursor during lock
            NSCursor.hide()
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: InputBlocker.eventTapCallback,
            userInfo: userInfo
        ) else {
            throw CleanLockError.eventTapCreationFailed
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.isBlocking = true
    }

    /// Stop blocking input and clean up.
    func stopBlocking() {
        guard isBlocking else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        // Restore cursor
        if !keyboardOnly {
            NSCursor.unhide()
        }

        eventTap = nil
        runLoopSource = nil
        emergencyCancelStart = nil
        isBlocking = false
    }

    // MARK: - Accessibility

    /// Check if the process has Accessibility permission.
    static func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt the user for Accessibility permission by opening System Settings.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Guide the user through granting Accessibility permission.
    /// - Returns: `true` if permission was granted within the timeout.
    static func waitForAccessibility(timeout: TimeInterval = 30) -> Bool {
        if checkAccessibility() { return true }

        print("CleanLock needs Accessibility permission to block input.")
        print("Opening System Settings > Privacy & Security > Accessibility...")
        print("Please grant permission, then return here.\n")

        requestAccessibility()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if checkAccessibility() {
                print("Accessibility permission granted.\n")
                return true
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        print("Timed out waiting for Accessibility permission.")
        return false
    }

    // MARK: - CGEvent Tap Callback

    /// The C-compatible callback for the CGEvent tap.
    private static let eventTapCallback: CGEventTapCallBack = {
        proxy, type, event, userInfo -> Unmanaged<CGEvent>? in

        // If the tap is disabled by the system, re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let userInfo = userInfo {
                let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
                if let tap = blocker.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let userInfo = userInfo else { return nil }
        let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()

        // Lock cursor to screen center on any mouse movement
        if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged {
            CGWarpMouseCursorPosition(blocker.cursorLockPoint)
        }

        // Emergency cancel detection: ⌘⌥⌃L held for 3 seconds
        if type == .keyDown || type == .flagsChanged {
            let flags = event.flags
            let hasCmd = flags.contains(.maskCommand)
            let hasOpt = flags.contains(.maskAlternate)
            let hasCtrl = flags.contains(.maskControl)

            if hasCmd && hasOpt && hasCtrl {
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == lKeyCode {
                        if blocker.emergencyCancelStart == nil {
                            blocker.emergencyCancelStart = Date()
                        }
                        if let start = blocker.emergencyCancelStart,
                           Date().timeIntervalSince(start) >= emergencyHoldDuration
                        {
                            DispatchQueue.main.async {
                                blocker.stopBlocking()
                                NotificationCenter.default.post(
                                    name: .cleanLockEmergencyCancel, object: nil
                                )
                            }
                            return Unmanaged.passUnretained(event)
                        }
                    }
                }
            } else {
                blocker.emergencyCancelStart = nil
            }
        }

        // Block the event
        return nil
    }
}
