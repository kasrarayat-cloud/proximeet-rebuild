#if DEBUG
import Foundation
import ProximeetDomain

/// DEBUG-only launch arguments for inspecting scenes directly. Never compiled into Release.
///
///     -ProximeetFixture welcome | birthday | pass | guest-list | band | band-selected |
///                       signal | signal-selected | ready
///     -ProximeetFixtureBand social | dating | business | activity
///     -ProximeetFixtureSignal comeSayHi | chatFirst | withMyCrew | justLooking
///     -ProximeetReduceMotionPreview YES
///
/// The last one is an app-level presentation override for captures; it does not change
/// the system Reduce Motion setting.
enum DebugLaunch {
    static func session(arguments: [String]) -> DemoSession? {
        guard let name = value(after: "-ProximeetFixture", in: arguments),
              let stage = PreviewFixtures.Stage(rawValue: name)
        else { return nil }
        let band = value(after: "-ProximeetFixtureBand", in: arguments).flatMap(BandIntent.init(rawValue:))
        let signal = value(after: "-ProximeetFixtureSignal", in: arguments).flatMap(ApproachSignal.init(rawValue:))
        return PreviewFixtures.session(at: stage, band: band ?? .social, signal: signal ?? .chatFirst)
    }

    static func prefersReducedMotionPreview(arguments: [String]) -> Bool {
        value(after: "-ProximeetReduceMotionPreview", in: arguments) == "YES"
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// Explicitly fictional, deterministic data for previews and DEBUG launches. Built only
/// through the public domain transitions, so fixtures can never reach a state the real
/// flow cannot.
enum PreviewFixtures {
    enum Stage: String {
        /// Fresh demo: nothing entered.
        case welcome
        /// The birthday scene after returning from the pass, so the wheel shows the
        /// fixture date instead of the capture day.
        case birthday
        /// The demo pass right after an eligible fixture birthday.
        case pass
        case guestList = "guest-list"
        case guestListFilled = "guest-list-filled"
        case band
        case bandSelected = "band-selected"
        case signal
        case signalSelected = "signal-selected"
        case ready
    }

    static let firstName = "Alex"
    static let interests = ["Bouldering", "Film photography", "Board games"]

    static func session(
        at stage: Stage,
        band: BandIntent = .social,
        signal: ApproachSignal = .chatFirst
    ) -> DemoSession {
        DemoSession(flow: flow(at: stage, band: band, signal: signal))
    }

    static func flow(at stage: Stage, band: BandIntent, signal: ApproachSignal) -> DemoFlow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        // Midday UTC, so the fixture birthday is 17 May in every time zone within ±11 h.
        let reference = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
        let birthday = calendar.date(from: DateComponents(year: 1995, month: 5, day: 17, hour: 12))
            ?? Date(timeIntervalSince1970: 0)

        var flow = DemoFlow()
        if stage == .welcome { return flow }

        flow.begin()
        flow.submitBirthday(birthday, using: BirthdayEligibility(referenceDate: reference, calendar: calendar))
        if stage == .birthday {
            flow.returnTo(.birthday)
            return flow
        }
        if stage == .pass { return flow }

        flow.continueFromPass()
        if stage == .guestList { return flow }

        flow.saveProfile(firstName: firstName, interests: interests)
        if stage == .guestListFilled { return flow }
        flow.continueFromGuestList()
        if stage == .band { return flow }

        flow.selectBand(band)
        if stage == .bandSelected { return flow }

        flow.confirmBand()
        if stage == .signal { return flow }

        flow.selectSignal(signal)
        if stage == .signalSelected { return flow }

        flow.confirmSignal()
        return flow
    }
}
#endif
