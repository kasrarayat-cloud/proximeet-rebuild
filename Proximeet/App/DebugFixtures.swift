#if DEBUG
import Foundation
import ProximeetDomain

/// DEBUG-only launch arguments for inspecting scenes directly. Never compiled into Release.
///
///     -ProximeetFixture welcome | birthday | birthday-adult | birthday-under18 | pass |
///                       guest-list | guest-list-filled | guest-list-card | guest-list-name-only |
///                       wristband | wristband-social | wristband-dating | wristband-business |
///                       wristband-activity | signal | signal-selected | places | place-detail |
///                       place-explanation | band | band-selected | ready
///     -ProximeetFixtureBand social | dating | business | activity
///     -ProximeetFixtureSignal chatFirst | okayToSayHello
///     -ProximeetFixtureCategory now | later | upcoming
///
/// `signal` and `signal-selected` open the approved Signal through the same gates as the real
/// route; they need an explicit `-ProximeetFixtureBand` (and `signal-selected` an explicit
/// `-ProximeetFixtureSignal`): no intent or approach is ever assumed. `places`, `place-detail`
/// and `place-explanation` continue from `signal-selected` through Signal's Continue preview (the
/// category, Now unless given, through its tab; the detail through View place; the explanation
/// through Preview check-in, which only an eligible intent at Common Ground opens: otherwise the
/// fixture stays on the detail, as the app would). They need an explicit band and approach too.
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
        let category = value(after: "-ProximeetFixtureCategory", in: arguments).flatMap(PlaceCategory.init(rawValue:))
        if stage == .signal || stage == .signalSelected {
            guard let band, stage == .signal || signal != nil else { return nil }
            return PreviewFixtures.session(at: stage, band: band, signal: signal ?? .chatFirst)
        }
        if PreviewFixtures.Stage.placesStages.contains(stage) {
            guard let band, let signal else { return nil }
            return PreviewFixtures.session(at: stage, band: band, signal: signal, category: category ?? .now)
        }
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
        /// The approved Birthday, fresh: DD / MMM / YYYY.
        case birthday
        /// The approved Birthday with 12 May 1997 entered and checked (adult example).
        case birthdayAdult = "birthday-adult"
        /// The approved Birthday with 12 May 2012 entered and checked (under-18 example).
        case birthdayUnder18 = "birthday-under18"
        /// The approved Pass (intro), opened from Birthday's Continue with 12 May 1997.
        case pass
        /// The approved Guest List editor, empty, opened from a completed Pass.
        case guestList = "guest-list"
        /// The editor with the approved fictional Alex example.
        case guestListFilled = "guest-list-filled"
        /// The personal card of the fictional Alex example.
        case guestListCard = "guest-list-card"
        /// The personal card with only the fictional name: no opener, no interests.
        case guestListNameOnly = "guest-list-name-only"
        /// The approved Wristband, unselected, opened from the fictional example's card.
        case wristband
        /// The approved Wristband with one intent chosen.
        case wristbandSocial = "wristband-social"
        case wristbandDating = "wristband-dating"
        case wristbandBusiness = "wristband-business"
        case wristbandActivity = "wristband-activity"
        /// The approved Signal for the given intent, no approach, opened from its Wristband.
        case signal
        /// The approved Signal for the given intent with the given approach chosen.
        case signalSelected = "signal-selected"
        /// The approved Places, browsing the given category (through Signal's Continue preview).
        case places
        /// The given category's venue detail (through View place).
        case placeDetail = "place-detail"
        /// Common Ground's check-in explanation (through Preview check-in; eligible intents only).
        case placeExplanation = "place-explanation"
        /// Legacy, unapproved later scenes, reached through the legacy route for their captures.
        case band
        case bandSelected = "band-selected"
        case ready

        /// The approved Places stages.
        static let placesStages: Set<Stage> = [.places, .placeDetail, .placeExplanation]
    }

    static let firstName = "Alex"
    static let interests = ["Bouldering", "Film photography", "Board games"]

    /// The approved Guest List's fictional example (Figma 36:169). Never a real person's data,
    /// and never used outside previews and DEBUG launches.
    static let exampleIntroduction = GuestIntroduction(
        name: "Alex",
        opener: "Always up for coffee and a good story.",
        interests: GuestIntroduction.Interest.allCases
    )

    static func session(
        at stage: Stage,
        band: BandIntent = .social,
        signal: ApproachSignal = .chatFirst,
        category: PlaceCategory = .now
    ) -> DemoSession {
        let session = DemoSession(flow: flow(at: stage, band: band, signal: signal, category: category))
        // The Guest List below a Wristband, Signal or Places fixture shows its card too, as on the
        // real route.
        session.fixtureOpensGuestListCard = [.guestListCard, .guestListNameOnly, .wristband, .wristbandSocial,
                                             .wristbandDating, .wristbandBusiness, .wristbandActivity,
                                             .signal, .signalSelected].contains(stage) || Stage.placesStages.contains(stage)
        return session
    }

    static func flow(at stage: Stage, band: BandIntent, signal: ApproachSignal,
                     category: PlaceCategory = .now) -> DemoFlow {
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
        switch stage {
        case .birthday:
            return flow
        case .birthdayAdult, .birthdayUnder18, .pass, .guestList, .guestListFilled, .guestListCard, .guestListNameOnly,
             .wristband, .wristbandSocial, .wristbandDating, .wristbandBusiness, .wristbandActivity,
             .signal, .signalSelected, .places, .placeDetail, .placeExplanation:
            // The approved Figma example dates, entered and checked through the domain.
            let today = CivilDate(year: 2026, month: 9, day: 24) ?? CivilDate.day(of: reference, in: calendar.timeZone)
            flow.updateBirthday { entry in
                entry.setDay(12)
                entry.setMonth(5)
                entry.setYear(stage == .birthdayUnder18 ? 2012 : 1997)
                entry.commit(today: today)
            }
            if stage == .birthdayAdult || stage == .birthdayUnder18 { return flow }
            // Through Birthday's own gate, as a guest would reach it.
            _ = flow.continueFromBirthday(today: today)
            if stage == .pass { return flow }
            // Through the Pass's Continue preview, after a completed demo. (The Pass screen below
            // is a new view, so it shows its intro; only the real route leaves it complete.)
            var demo = PassDemo()
            demo.start()
            demo.finish()
            flow.continueFromCompletedPass(demo)
            switch stage {
            case .guestListFilled, .guestListCard:
                flow.editIntroduction { $0 = exampleIntroduction }
            case .guestListNameOnly:
                flow.editIntroduction { $0.name = exampleIntroduction.name }
            case .wristband, .wristbandSocial, .wristbandDating, .wristbandBusiness, .wristbandActivity,
                 .signal, .signalSelected, .places, .placeDetail, .placeExplanation:
                // Through the card's Continue preview, as a guest would reach it.
                flow.editIntroduction { $0 = exampleIntroduction }
                var card = GuestListDemo()
                card.preview(flow.draft.introduction)
                flow.continueFromGuestListCard(card)
                let intents: [Stage: BandIntent] = [.wristbandSocial: .social, .wristbandDating: .dating,
                                                    .wristbandBusiness: .business, .wristbandActivity: .activity]
                if let intent = intents[stage] {
                    flow.chooseIntent(intent)
                }
                if stage == .signal || stage == .signalSelected || Stage.placesStages.contains(stage) {
                    // Through the Wristband's Continue preview, with the given intent.
                    flow.chooseIntent(band)
                    flow.continueFromWristband()
                    if stage != .signal {
                        flow.chooseApproach(signal)
                    }
                }
                if Stage.placesStages.contains(stage) {
                    // Through Signal's Continue preview, the category's tab, View place and
                    // Preview check-in: each only where the app itself allows it.
                    flow.openPlaces()
                    flow.choosePlaceCategory(stage == .placeExplanation ? .now : category)
                    if stage != .places {
                        flow.openPlaceDetail()
                    }
                    if stage == .placeExplanation {
                        flow.previewCheckIn()
                    }
                }
            default:
                break
            }
            return flow
        default:
            break
        }
        // Later, unapproved scenes are reached through the legacy route, for their own captures.
        flow.submitBirthday(birthday, using: BirthdayEligibility(referenceDate: reference, calendar: calendar))
        flow.continueFromPass()
        flow.saveProfile(firstName: firstName, interests: interests)
        flow.continueFromGuestList()
        if stage == .band { return flow }

        flow.selectBand(band)
        if stage == .bandSelected { return flow }

        flow.confirmBand()
        flow.selectSignal(signal)
        flow.confirmSignal()
        return flow
    }
}
#endif
