import Foundation
import Observation
import ProximeetDomain

/// Observable wrapper around the in-memory `DemoFlow`.
///
/// Every method forwards to a synchronous domain transition, so the UI never waits for
/// animation or time to change state. Nothing here persists, networks or verifies.
@Observable
final class DemoSession {
    private(set) var flow: DemoFlow

    /// Incremented on every reset. The navigation stack is keyed on it, so all view-local
    /// drafts (picker selections, form text) are discarded together with the model data.
    private(set) var resetGeneration = 0

    init(flow: DemoFlow = DemoFlow()) {
        self.flow = flow
    }

    // MARK: - Read-only state

    /// Bound to `NavigationStack`. The domain only accepts pops, so system back gestures
    /// stay in sync while forward navigation always goes through a validated action.
    var path: [DemoScene] {
        get { flow.path }
        set { flow.adoptNavigationPath(newValue) }
    }

    var draft: DemoDraft { flow.draft }
    var readiness: ReadyForCheckIn? { flow.readiness }
    var hasEnteredData: Bool { flow.draft != DemoDraft() }

    // MARK: - Transitions

    func begin() {
        flow.begin()
    }

    /// Uses the same Gregorian calendar and time zone as the birthday picker.
    func submitBirthday(_ dateOfBirth: Date, calendar: Calendar, now: Date = Date()) -> BirthdayCheck? {
        flow.submitBirthday(dateOfBirth, using: BirthdayEligibility(referenceDate: now, calendar: calendar))
    }

    func continueFromPass() {
        flow.continueFromPass()
    }

    /// Transactional: `.invalid` leaves any previously saved profile untouched.
    func saveProfile(firstName: String, interests: [String]) -> ProfileSaveOutcome {
        flow.saveProfile(firstName: firstName, interests: interests)
    }

    func continueFromGuestList() {
        flow.continueFromGuestList()
    }

    func selectBand(_ intent: BandIntent) {
        flow.selectBand(intent)
    }

    func confirmBand() {
        flow.confirmBand()
    }

    func selectSignal(_ signal: ApproachSignal) {
        flow.selectSignal(signal)
    }

    func confirmSignal() {
        flow.confirmSignal()
    }

    func returnTo(_ scene: DemoScene) {
        flow.returnTo(scene)
    }

    func reset() {
        flow.reset()
        resetGeneration += 1
    }

    // MARK: - Calendar

    /// Gregorian calendar in the device's current time zone, shared by the birthday picker
    /// and the eligibility check so both agree on which day a date falls on.
    static func birthdayCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
