import Foundation
import XCTest
import ProximeetDomain

/// The approved Places (chapter 07): the fixed fictional catalog, eligibility from the actual
/// intent and the fixed snapshot, the routes into and around Places, and what browsing does not
/// confer. Every venue, host, name and opener here is fictional test data.
final class PlacesRouteTests: XCTestCase {

    // MARK: - The fixed fictional catalog

    func testTheCatalogIsTheApprovedFixedSnapshot() {
        XCTAssertEqual(PlacesSnapshot.label, "Fictional venues · demo Thursday, 8 pm")
        XCTAssertEqual(PlaceCategory.allCases, [.now, .later, .upcoming])
        XCTAssertEqual(PlaceCategory.allCases.map(\.title), ["Now", "Later", "Upcoming"])
        XCTAssertEqual(PlaceCategory.allCases.map(\.venue), [.commonGround, .afterglow, .fieldwork],
                       "each category filters the catalog to exactly one venue")
        XCTAssertEqual(Venue.allCases.map(\.category), [.now, .later, .upcoming])
        XCTAssertEqual(Venue.allCases.map(\.name), ["Common Ground", "Afterglow", "Fieldwork"])
        XCTAssertEqual(Venue.allCases.map(\.kind), ["Fictional venue · Café", "Fictional venue · Listening lounge",
                                                    "Fictional venue · Creative workshop"])
        XCTAssertEqual(Venue.allCases.map(\.schedule), ["Today · 6–10 pm", "Tonight · 9–11 pm", "Saturday · 10 am–1 pm"])
        XCTAssertEqual(Venue.allCases.map(\.hostLine), ["Host · Common Ground team", "Host · Afterglow hosts",
                                                        "Host · Fieldwork studio"])
        XCTAssertEqual(Venue.allCases.map(\.brief), [
            "Coffee, small tables, and room for an unhurried conversation.",
            "A warm listening room for records, conversation, and a little curiosity.",
            "A shared table for making, learning, and meeting through a small project.",
        ])
        XCTAssertEqual(Venue.allCases.map(\.permittedIntents), [[.social, .business], [.social, .dating],
                                                                 [.activity, .business]])
        XCTAssertEqual(Venue.allCases.map(\.availability), [.open, .future(opens: "Opens at 9 pm"),
                                                            .future(opens: "Opens Saturday")])
        XCTAssertEqual(PlacesSnapshot.rules, ["Respect a no.", "Stay within the venue."])
    }

    func testTheCheckInExplanationWords() {
        XCTAssertEqual(CheckInExplanation.venue, .commonGround)
        XCTAssertEqual(CheckInExplanation.headline, ["Arrive.", "Then connect."])
        XCTAssertEqual(CheckInExplanation.support, "A place opens when you’re really there.")
        XCTAssertEqual(CheckInExplanation.context, "Fictional venue · Today, 6–10 pm")
        XCTAssertEqual(CheckInExplanation.steps.map(\.title), ["Confirm you’re here", "Scan the venue’s code"])
        XCTAssertEqual(CheckInExplanation.steps.map(\.explanation), [
            "One location check while the app is open. No background tracking.",
            "Scan the rotating QR shown at the venue.",
        ])
        XCTAssertEqual(CheckInExplanation.presenceBoundary, "You stay private until both checks pass.")
        XCTAssertEqual(CheckInExplanation.demoBoundary, "Demo · no location or camera used.")
    }

    // MARK: - Eligibility: all twelve intent × venue combinations

    /// The approved matrix (`LAYOUT_SPEC.json` eligibility.matrix), verbatim.
    private static let matrix: [(Venue, BandIntent, Bool, String, String, String)] = [
        (.commonGround, .social, true, "Preview check-in", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
        (.commonGround, .dating, false, "Not available for Dating", "Your Dating band doesn’t match this session.",
         "Your Dating band doesn’t match this session."),
        (.commonGround, .business, true, "Preview check-in", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
        (.commonGround, .activity, false, "Not available for Activity", "Your Activity band doesn’t match this session.",
         "Your Activity band doesn’t match this session."),
        (.afterglow, .social, false, "Opens at 9 pm", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
        (.afterglow, .dating, false, "Opens at 9 pm", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
        (.afterglow, .business, false, "Not available for Business", "Your Business band doesn’t match this session.",
         "Your Business band doesn’t match this session."),
        (.afterglow, .activity, false, "Not available for Activity", "Your Activity band doesn’t match this session.",
         "Your Activity band doesn’t match this session."),
        (.fieldwork, .social, false, "Not available for Social", "Your Social band doesn’t match this session.",
         "Your Social band doesn’t match this session."),
        (.fieldwork, .dating, false, "Not available for Dating", "Your Dating band doesn’t match this session.",
         "Your Dating band doesn’t match this session."),
        (.fieldwork, .business, false, "Opens Saturday", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
        (.fieldwork, .activity, false, "Opens Saturday", "Your profile stays private until check-in.",
         "Sample session · not a reservation"),
    ]

    func testAllTwelveCombinationsMatchTheApprovedMatrix() {
        XCTAssertEqual(Self.matrix.count, Venue.allCases.count * BandIntent.allCases.count)
        for (venue, intent, preview, primary, browse, detail) in Self.matrix {
            let state = "\(venue) / \(intent)"
            let eligibility = PlaceEligibility(venue: venue, intent: intent)
            XCTAssertEqual(eligibility.canPreviewCheckIn, preview, state)
            XCTAssertEqual(eligibility.intentMatches, venue.permittedIntents.contains(intent), state)
            XCTAssertEqual(eligibility.isOpen, venue == .commonGround, state)
            XCTAssertEqual(eligibility.primaryLabel, primary, state)
            XCTAssertEqual(eligibility.browseBoundary, browse, state)
            XCTAssertEqual(eligibility.detailBoundary, detail, state)
            XCTAssertEqual(eligibility.disabledReason == nil, preview, "\(state): a disabled action always says why")
        }
    }

    func testOnlySocialOrBusinessAtCommonGroundCanPreviewCheckIn() {
        let eligible = Venue.allCases.flatMap { venue in BandIntent.allCases.map { (venue, $0) } }
            .filter { PlaceEligibility(venue: $0.0, intent: $0.1).canPreviewCheckIn }
        XCTAssertEqual(eligible.map(\.0), [.commonGround, .commonGround])
        XCTAssertEqual(eligible.map(\.1), [.social, .business])
    }

    func testAMismatchIsExplainedBeforeAFutureLabel() {
        // Social at Fieldwork: future AND mismatched; the mismatch wins, the schedule stays.
        let social = PlaceEligibility(venue: .fieldwork, intent: .social)
        XCTAssertFalse(social.isOpen)
        XCTAssertFalse(social.intentMatches)
        XCTAssertEqual(social.primaryLabel, "Not available for Social")
        XCTAssertEqual(social.disabledReason, "Your Social band doesn’t match this session.")
        XCTAssertEqual(Venue.fieldwork.schedule, "Saturday · 10 am–1 pm", "the schedule stays visible")
        // A matching future session: its label, and a reason that is not a mismatch.
        let activity = PlaceEligibility(venue: .fieldwork, intent: .activity)
        XCTAssertEqual(activity.primaryLabel, "Opens Saturday")
        XCTAssertEqual(activity.disabledReason, "This fictional session is not open in the demo snapshot. Opens Saturday.")
    }

    // MARK: - Clock independence

    /// The snapshot has no clock: no Places API takes a date, a time or a zone, and the only date
    /// the journey reads (the Birthday check's "today", taken from the device day in the app) does
    /// not change anything in Places. Flows built on very different days give identical outcomes
    /// for every intent, category, label and route.
    func testAvailabilityIsTheSameWhateverTheDay() {
        for intent in BandIntent.allCases {
            let reference = placesOutcomes(PlacesRoute.onPlaces(intent, approach: .chatFirst))
            for (year, month, day) in [(2026, 9, 24), (2026, 9, 27), (2030, 1, 1), (2041, 12, 31), (2099, 6, 15)] {
                let today = CivilDate(year: year, month: month, day: day)!
                let flow = PlacesRoute.onPlaces(intent, approach: .chatFirst, today: today)
                XCTAssertEqual(flow.currentScene, .places, "\(intent) on \(year)-\(month)-\(day)")
                XCTAssertEqual(placesOutcomes(flow), reference, "\(intent) on \(year)-\(month)-\(day)")
            }
        }
    }

    func testThePlacesSourceReadsNoClockCalendarOrLocation() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/ProximeetDomain/Places.swift")
        let code = try String(contentsOf: source, encoding: .utf8)
            .split(separator: "\n").map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[..<comment.lowerBound]
            }.joined(separator: "\n")
        // APIs, not words: the approved copy itself says "One location check…". (Imports are
        // checked by DomainSourceGuardTests: Foundation only.)
        for token in ["Date", "Calendar", "TimeZone", "Locale", "Timer", "Clock", "Duration", "CoreLocation",
                      "CLLocation", "AVCapture"] {
            XCTAssertFalse(code.contains(token), "Places.swift uses \(token)")
        }
    }

    // MARK: - Entry, categories and retention

    func testSignalsContinueOpensNowFirstAndTheCategoryIsRetained() {
        var flow = PlacesRoute.onSignal(.dating, approach: .okayToSayHello)
        XCTAssertTrue(flow.openPlaces())
        XCTAssertEqual(flow.currentScene, .places)
        XCTAssertEqual(flow.placesCategory, .now, "first entry opens Now")

        XCTAssertTrue(flow.choosePlaceCategory(.upcoming))
        XCTAssertEqual(flow.placeVenue, .fieldwork)
        XCTAssertTrue(flow.leavePlaces(), "Back returns to the actual Signal")
        XCTAssertEqual(flow.currentScene, .signal)
        XCTAssertEqual(flow.draft.band, .dating)
        XCTAssertEqual(flow.draft.signal, .okayToSayHello)
        XCTAssertFalse(flow.leavePlaces(), "a repeated Back cannot also leave Signal")

        XCTAssertTrue(flow.openPlaces())
        XCTAssertEqual(flow.placesCategory, .upcoming, "re-entry keeps the category")
        XCTAssertEqual(flow.placeVenue, .fieldwork)
    }

    func testTabsFilterTheCatalogAndTheSelectedTabIsANoOp() {
        var flow = PlacesRoute.onPlaces(.social, approach: .chatFirst)
        for category in [PlaceCategory.later, .upcoming, .now, .later] {
            XCTAssertTrue(flow.choosePlaceCategory(category), "\(category)")
            XCTAssertEqual(flow.placeVenue, category.venue)
            let before = flow
            XCTAssertFalse(flow.choosePlaceCategory(category), "tapping the selected tab does nothing")
            XCTAssertEqual(flow, before)
        }
    }

    func testTheLastOfRapidCategoryChangesWins() {
        var flow = PlacesRoute.onPlaces(.activity, approach: .okayToSayHello)
        let taps: [PlaceCategory] = [.later, .upcoming, .upcoming, .now, .later, .upcoming]
        for tap in taps { flow.choosePlaceCategory(tap) }
        XCTAssertEqual(flow.placesCategory, taps.last)
        XCTAssertEqual(flow.path.last, .places, "tabs never navigate")
    }

    func testCategoriesChangeOnlyOnBrowsing() {
        var flow = PlacesRoute.onPlaces(.social, approach: .chatFirst)
        flow.openPlaceDetail()
        let before = flow
        XCTAssertFalse(flow.choosePlaceCategory(.later), "no tabs on a detail")
        XCTAssertEqual(flow, before)
        var signal = PlacesRoute.onSignal(.social, approach: .chatFirst)
        XCTAssertFalse(signal.choosePlaceCategory(.later), "no tabs on Signal")
    }

    // MARK: - Details and the explanation

    func testEveryVenueDetailOpensForEveryIntentAndBackReturnsToItsCategory() {
        for intent in BandIntent.allCases {
            for category in PlaceCategory.allCases {
                var flow = PlacesRoute.onPlaces(intent, approach: .chatFirst)
                flow.choosePlaceCategory(category)
                XCTAssertTrue(flow.openPlaceDetail(), "\(intent) / \(category): every detail is browsable")
                XCTAssertEqual(flow.currentScene, .placeDetail)
                XCTAssertEqual(flow.placeVenue, category.venue)
                XCTAssertFalse(flow.openPlaceDetail(), "a repeated View place pushes nothing")
                XCTAssertTrue(flow.leavePlaceDetail())
                XCTAssertEqual(flow.currentScene, .places)
                XCTAssertEqual(flow.placesCategory, category, "Back returns to the originating category")
                XCTAssertFalse(flow.leavePlaceDetail(), "a repeated Back cannot also leave browsing")
            }
        }
    }

    func testOnlyAnEligibleDetailOpensTheExplanation() {
        for intent in BandIntent.allCases {
            for category in PlaceCategory.allCases {
                var flow = PlacesRoute.onPlaces(intent, approach: .okayToSayHello)
                flow.choosePlaceCategory(category)
                flow.openPlaceDetail()
                let eligible = PlaceEligibility(venue: category.venue, intent: intent).canPreviewCheckIn
                let before = flow
                XCTAssertEqual(flow.previewCheckIn(), eligible, "\(intent) / \(category)")
                if eligible {
                    XCTAssertEqual(flow.currentScene, .placeExplanation)
                    XCTAssertFalse(flow.previewCheckIn(), "a repeated Preview check-in pushes nothing")
                    XCTAssertEqual(flow.path.count, before.path.count + 1)
                } else {
                    XCTAssertEqual(flow, before, "\(intent) / \(category): a disabled action changes nothing")
                }
                XCTAssertFalse(flow.draft.meetsRequirements(for: .placeExplanation) != PlaceEligibility(
                    venue: .commonGround, intent: intent).canPreviewCheckIn)
            }
        }
    }

    func testTheExplanationsExits() {
        for intent in [BandIntent.social, .business] {
            var flow = PlacesRoute.onExplanation(intent)
            XCTAssertTrue(flow.backToPlace(), "Back to place")
            XCTAssertEqual(flow.currentScene, .placeDetail)
            XCTAssertEqual(flow.placeVenue, .commonGround)
            XCTAssertFalse(flow.backToPlace())

            XCTAssertTrue(flow.previewCheckIn())
            XCTAssertTrue(flow.exploreOtherPlaces(), "Explore other places")
            XCTAssertEqual(flow.currentScene, .places)
            XCTAssertEqual(flow.placesCategory, .now, "explicitly Now browsing")
            XCTAssertFalse(flow.exploreOtherPlaces())
            XCTAssertEqual(flow.draft.band, intent)
            XCTAssertEqual(flow.draft.signal, .chatFirst)
        }
    }

    // MARK: - Band changes, missing choices and stale routes

    func testABandChangeRecomputesEligibilityAndKeepsTheApproachProfileAndCategory() {
        var flow = PlacesRoute.onPlaces(.social, approach: .okayToSayHello)
        let introduction = flow.draft.introduction
        XCTAssertEqual(flow.placeEligibility?.canPreviewCheckIn, true, "Social at Common Ground")
        XCTAssertTrue(flow.choosePlaceCategory(.later))
        XCTAssertTrue(flow.leavePlaces())
        XCTAssertTrue(flow.leaveSignal())
        XCTAssertTrue(flow.chooseIntent(.dating))
        XCTAssertTrue(flow.continueFromWristband())
        XCTAssertEqual(flow.draft.signal, .okayToSayHello, "the approach is kept")
        XCTAssertTrue(flow.openPlaces())
        XCTAssertEqual(flow.placesCategory, .later, "the category is kept")
        XCTAssertEqual(flow.placeEligibility, PlaceEligibility(venue: .afterglow, intent: .dating))
        XCTAssertEqual(flow.placeEligibility?.primaryLabel, "Opens at 9 pm", "Dating now matches Afterglow")
        XCTAssertTrue(flow.choosePlaceCategory(.now))
        XCTAssertEqual(flow.placeEligibility?.canPreviewCheckIn, false, "Dating does not match Common Ground")
        XCTAssertEqual(flow.placeEligibility?.primaryLabel, "Not available for Dating")
        flow.openPlaceDetail()
        XCTAssertFalse(flow.previewCheckIn(), "recomputed from the new intent")
        XCTAssertEqual(flow.draft.introduction, introduction, "the profile is kept")
    }

    func testMissingChoicesKeepTheGuestOnTheirOwnChoiceScreens() {
        var noApproach = PlacesRoute.onSignal(.social, approach: nil)
        XCTAssertFalse(noApproach.openPlaces(), "no approach: Signal, the approach's own screen")
        XCTAssertEqual(noApproach.currentScene, .signal)
        XCTAssertFalse(noApproach.draft.meetsRequirements(for: .places))

        var wristband = WristbandRoute.onWristband()
        XCTAssertFalse(wristband.continueFromWristband(), "no intent: the Wristband, the intent's own screen")
        XCTAssertFalse(wristband.openPlaces())
        XCTAssertFalse(DemoDraft().meetsRequirements(for: .places))
        XCTAssertFalse(DemoDraft().meetsRequirements(for: .placeExplanation))
    }

    func testNavigationCanOnlyPopAndAValidRouteIsNotTrimmed() {
        var flow = PlacesRoute.onSignal(.business, approach: .chatFirst)
        XCTAssertFalse(flow.adoptNavigationPath(flow.path + [.places]), "a pushed Places path")
        XCTAssertFalse(flow.adoptNavigationPath(flow.path + [.places, .placeDetail, .placeExplanation]))
        flow.openPlaces()
        flow.openPlaceDetail()
        XCTAssertFalse(flow.adoptNavigationPath(flow.path + [.placeExplanation]), "the explanation only through its guard")
        XCTAssertFalse(flow.reconcileRoute(), "a valid route is left alone")
        XCTAssertTrue(flow.path.allSatisfy { flow.allows($0) })
        // A system back gesture from a detail is a pop: browsing, category kept.
        flow.leavePlaceDetail()
        flow.choosePlaceCategory(.upcoming)
        flow.openPlaceDetail()
        XCTAssertTrue(flow.adoptNavigationPath(Array(flow.path.dropLast())))
        XCTAssertEqual(flow.placesCategory, .upcoming)
        XCTAssertFalse(flow.allows(.placeExplanation), "the explanation belongs to Common Ground only")
    }

    // MARK: - Nothing conferred, memory only

    func testBrowsingAndTheExplanationConferNothing() {
        var flow = PlacesRoute.onSignal(.business, approach: .okayToSayHello)
        let draft = flow.draft
        flow.openPlaces()
        for category in PlaceCategory.allCases + PlaceCategory.allCases {
            flow.choosePlaceCategory(category)
            flow.openPlaceDetail()
            flow.previewCheckIn()
            flow.backToPlace()
            flow.leavePlaceDetail()
        }
        flow.choosePlaceCategory(.now)
        flow.openPlaceDetail()
        flow.previewCheckIn()
        flow.exploreOtherPlaces()
        XCTAssertEqual(flow.draft, draft, "the intent, the approach and the introduction are never overwritten")
        XCTAssertNil(flow.readiness)
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "checkedin", "attend", "online",
                     "match", "account", "identity", "consent", "permission", "location", "camera", "scan",
                     "credential", "reserv", "booking", "wave", "chat", "message", "room", "keep"]
        for label in Self.propertyNames(of: flow) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
    }

    func testRelaunchResetsTheDraftAndTheBrowsingState() {
        var flow = PlacesRoute.onExplanation(.social)
        flow.backToPlace()
        flow.leavePlaceDetail()
        flow.choosePlaceCategory(.upcoming)
        flow.reset()
        XCTAssertEqual(flow, DemoFlow(), "memory only: a new run starts empty")
        XCTAssertEqual(flow.placesCategory, .now)
    }

    func testNotPersistable() {
        for type in [PlaceCategory.self, Venue.self, VenueAvailability.self, PlaceEligibility.self] as [Any.Type] {
            XCTAssertFalse(type is Encodable.Type, "\(type)")
            XCTAssertFalse(type is Decodable.Type, "\(type)")
        }
    }

    // MARK: - Helpers

    private func placesOutcomes(_ start: DemoFlow) -> [String] {
        var outcomes: [String] = []
        for category in PlaceCategory.allCases {
            var flow = start
            flow.choosePlaceCategory(category)
            let eligibility = flow.placeEligibility
            flow.openPlaceDetail()
            let opened = flow.previewCheckIn()
            outcomes.append("\(category) \(flow.placeVenue) \(eligibility?.primaryLabel ?? "?") \(opened)")
        }
        return outcomes
    }

    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            [child.label ?? ""] + propertyNames(of: child.value)
        }
    }
}

/// The approved route into Places, with the fictional name "Alex".
enum PlacesRoute {
    static func onSignal(_ intent: BandIntent, approach: ApproachSignal?, today: CivilDate = GuestListRoute.today) -> DemoFlow {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { entry in
            entry.setDay(12)
            entry.setMonth(5)
            entry.setYear(1997)
            entry.commit(today: today)
        }
        flow.continueFromBirthday(today: today)
        flow.continueFromCompletedPass(GuestListRoute.completedPass())
        flow.editIntroduction { $0.name = "Alex" }
        flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction))
        flow.chooseIntent(intent)
        flow.continueFromWristband()
        if let approach { flow.chooseApproach(approach) }
        return flow
    }

    static func onPlaces(_ intent: BandIntent, approach: ApproachSignal, today: CivilDate = GuestListRoute.today) -> DemoFlow {
        var flow = onSignal(intent, approach: approach, today: today)
        flow.openPlaces()
        return flow
    }

    static func onExplanation(_ intent: BandIntent) -> DemoFlow {
        var flow = onPlaces(intent, approach: .chatFirst)
        flow.openPlaceDetail()
        flow.previewCheckIn()
        return flow
    }
}
