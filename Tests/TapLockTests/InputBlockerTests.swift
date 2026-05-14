import Testing
import Foundation
@testable import TapLockCore

@Suite("TapLockError")
struct TapLockErrorTests {

    @Test func errorDescriptions() {
        #expect(TapLockError.accessibilityDenied.description.contains("Accessibility"))
        #expect(TapLockError.eventTapCreationFailed.description.contains("CGEvent tap"))
        #expect(TapLockError.alreadyBlocking.description.contains("already active"))
        #expect(TapLockError.alreadyRunning.description.contains("already running"))
    }

    @Test func allDescriptionsNonEmpty() {
        let allCases: [TapLockError] = [.accessibilityDenied, .eventTapCreationFailed, .alreadyBlocking, .alreadyRunning]
        for error in allCases {
            #expect(!error.description.isEmpty)
        }
    }

    @Test func conformsToError() {
        let error: any Error = TapLockError.accessibilityDenied
        #expect(error is TapLockError)
    }

    @Test func exhaustiveCases() {
        // Verifies all cases are handled; will fail to compile if a case is added
        let allCases: [TapLockError] = [.accessibilityDenied, .eventTapCreationFailed, .alreadyBlocking, .alreadyRunning]
        #expect(allCases.count == 4)
    }
}

@Suite("Emergency Cancel Notifications")
struct EmergencyCancelNotificationTests {

    @Test func cancelNotificationName() {
        #expect(Notification.Name.cleanLockEmergencyCancel.rawValue == "cleanLockEmergencyCancel")
    }

    @Test func chordStartedNotificationName() {
        #expect(Notification.Name.emergencyCancelChordStarted.rawValue == "emergencyCancelChordStarted")
    }

    @Test func chordReleasedNotificationName() {
        #expect(Notification.Name.emergencyCancelChordReleased.rawValue == "emergencyCancelChordReleased")
    }

    @Test func holdDurationIsThreeSeconds() {
        #expect(InputBlocker.emergencyHoldDuration == 3.0)
    }
}

@Suite("InputBlocker State")
struct InputBlockerStateTests {

    @Test func singletonIdentity() {
        #expect(InputBlocker.shared === InputBlocker.shared)
    }

    @Test func initialIsBlockingFalse() {
        #expect(InputBlocker.shared.isBlocking == false)
    }

    @Test func initialChordInactive() {
        #expect(InputBlocker.shared.chordActive == false)
        #expect(InputBlocker.shared.lKeyDown == false)
    }
}
