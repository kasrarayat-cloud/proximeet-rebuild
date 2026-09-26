import Foundation
import XCTest
import ProximeetDomain

/// The approved Signal (chapter 06): the carried intent, one optional approach, the route from
/// the Wristband, and what choosing does not confer. Every name and opener here is fictional
/// test data.
final class SignalRouteTests: XCTestCase {

    // MARK: - Route from the Wristband

    func testOnlyAWristbandWithAnIntentOpensSignal() {
        var flow = WristbandRoute.onWristband()
        XCTAssertFalse(flow.canContinueFromWristband, "no intent, no Continue preview")
        XCTAssertFalse(flow.continueFromWristband())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band], "Signal never opens without an intent")

        flow.chooseIntent(.dating)
        XCTAssertTrue(flow.continueFromWristband())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band, .signal])
        XCTAssertEqual(flow.draft.band, .dating, "the actual chosen intent is carried")
        XCTAssertFalse(flow.continueFromWristband(), "a repeated Continue preview pushes nothing")
        XCTAssertEqual(flow.path.count, 5)
    }

    func testNoOtherRouteReachesSignalWithoutAnIntent() {
        var flow = WristbandRoute.onWristband()
        let before = flow
        XCTAssertFalse(flow.confirmBand(), "the legacy route needs the legacy profile")
        XCTAssertFalse(flow.adoptNavigationPath(flow.path + [.signal]), "navigation can only pop")
        XCTAssertFalse(flow.chooseApproach(.chatFirst), "approach is chosen only on Signal")
        XCTAssertEqual(flow, before)
        XCTAssertFalse(DemoDraft().meetsRequirements(for: .signal))
    }

    // MARK: - One optional approach

    func testAFreshSignalHasNoApproachAndNoContinue() {
        for intent in BandIntent.allCases {
            let flow = SignalRoute.onSignal(intent)
            XCTAssertNil(flow.draft.signal, "no default approach, nothing inferred")
            XCTAssertFalse(flow.continueSignalPreview())
            XCTAssertEqual(SignalSummary(intent: intent, approach: flow.draft.signal).title,
                           "\(intent.title) band · Choose your approach")
        }
    }

    func testAllTwelveIntentAndApproachStates() {
        for intent in BandIntent.allCases {
            for approach in [nil] + ApproachSignal.allCases.map(Optional.some) {
                var flow = SignalRoute.onSignal(intent)
                if let approach { XCTAssertTrue(flow.chooseApproach(approach)) }
                let state = "\(intent) / \(String(describing: approach))"
                XCTAssertEqual(flow.draft.band, intent, state)
                XCTAssertEqual(flow.draft.signal, approach, state)
                XCTAssertEqual(flow.continueSignalPreview(), approach != nil, state)
                XCTAssertEqual(SignalSummary(intent: intent, approach: approach).title,
                               "\(intent.title) band · \(approach?.title ?? "Choose your approach")", state)
                XCTAssertEqual(flow.currentScene, .signal, "\(state): nothing advances")
            }
        }
    }

    func testEveryChangeFromEveryStateSelectsExactlyTheTappedApproach() {
        let starts: [ApproachSignal?] = [nil] + ApproachSignal.allCases.map { $0 }
        for start in starts {
            for target in ApproachSignal.allCases {
                var flow = SignalRoute.onSignal(.business)
                if let start { flow.chooseApproach(start) }
                let changed = flow.chooseApproach(target)
                XCTAssertEqual(flow.draft.signal, target, "\(String(describing: start)) → \(target)")
                XCTAssertEqual(changed, start != target, "\(String(describing: start)) → \(target)")
                XCTAssertTrue(flow.continueSignalPreview())
                XCTAssertEqual(flow.currentScene, .signal)
            }
        }
    }

    func testTappingTheActiveApproachIsANoOpAndNeverClearsIt() {
        for approach in ApproachSignal.allCases {
            var flow = SignalRoute.onSignal(.social)
            flow.chooseApproach(approach)
            let before = flow
            XCTAssertFalse(flow.chooseApproach(approach))
            XCTAssertEqual(flow, before)
            XCTAssertEqual(flow.draft.signal, approach)
        }
    }

    func testTheLastOfRapidChangesWins() {
        var flow = SignalRoute.onSignal(.activity)
        let taps: [ApproachSignal] = [.chatFirst, .okayToSayHello, .okayToSayHello, .chatFirst, .okayToSayHello]
        for tap in taps { flow.chooseApproach(tap) }
        XCTAssertEqual(flow.draft.signal, taps.last)
        XCTAssertEqual(flow.draft.band, .activity, "the intent never changes on Signal")
    }

    func testApproachesAreOnlyChosenOnSignal() {
        var flow = SignalRoute.onSignal(.dating)
        flow.chooseApproach(.chatFirst)
        flow.leaveSignal()
        let before = flow
        XCTAssertFalse(flow.chooseApproach(.okayToSayHello))
        XCTAssertFalse(flow.continueSignalPreview())
        XCTAssertFalse(flow.leaveSignal())
        XCTAssertEqual(flow, before)
    }

    // MARK: - Words

    func testTheApprovedWords() {
        XCTAssertEqual(ApproachSignal.allCases, [.chatFirst, .okayToSayHello])
        XCTAssertEqual(ApproachSignal.allCases.map(\.title), ["Chat first", "Okay to say hello"])
        XCTAssertEqual(ApproachSignal.allCases.map(\.summary),
                       ["Start with a Wave. Chat after you both agree.",
                        "Open to a brief hello. No pressure to continue."])
        XCTAssertEqual(SignalSummary(intent: .social, approach: nil).title, "Social band · Choose your approach")
        XCTAssertEqual(SignalSummary(intent: .dating, approach: .chatFirst).title, "Dating band · Chat first")
        XCTAssertEqual(SignalSummary(intent: .activity, approach: .okayToSayHello).title,
                       "Activity band · Okay to say hello")
    }

    // MARK: - Back, intent changes, earlier edits and re-entry

    func testBackReturnsToTheWristbandKeepingBothValues() {
        var flow = SignalRoute.onSignal(.business)
        flow.chooseApproach(.okayToSayHello)
        XCTAssertTrue(flow.leaveSignal())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band])
        XCTAssertFalse(flow.leaveSignal(), "a repeated Back cannot also leave the Wristband")
        XCTAssertEqual(flow.draft.band, .business)
        XCTAssertEqual(flow.draft.signal, .okayToSayHello)

        XCTAssertTrue(flow.continueFromWristband())
        XCTAssertEqual(flow.draft.signal, .okayToSayHello, "re-entry keeps the approach")
    }

    func testChangingTheIntentKeepsTheApproachForEveryPair() {
        for approach in ApproachSignal.allCases {
            for from in BandIntent.allCases {
                for to in BandIntent.allCases where to != from {
                    var flow = SignalRoute.onSignal(from)
                    flow.chooseApproach(approach)
                    flow.leaveSignal()
                    XCTAssertTrue(flow.chooseIntent(to))
                    XCTAssertTrue(flow.continueFromWristband())
                    XCTAssertEqual(flow.draft.band, to, "\(from) → \(to)")
                    XCTAssertEqual(flow.draft.signal, approach, "\(from) → \(to) keeps \(approach)")
                    XCTAssertEqual(SignalSummary(intent: flow.draft.band!, approach: flow.draft.signal).title,
                                   "\(to.title) band · \(approach.title)")
                }
            }
        }
    }

    func testEditingTheIntroductionKeepsTheIntentAndTheApproach() {
        var flow = SignalRoute.onSignal(.activity)
        flow.chooseApproach(.chatFirst)
        flow.leaveSignal()
        flow.leaveWristband()
        XCTAssertTrue(flow.editIntroduction { $0.opener = "Up for a climb this weekend." })
        XCTAssertTrue(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)))
        XCTAssertEqual(flow.draft.band, .activity)
        XCTAssertTrue(flow.continueFromWristband())
        XCTAssertEqual(flow.draft.signal, .chatFirst)
        XCTAssertEqual(flow.draft.introduction.card?.opener, "Up for a climb this weekend.")
        XCTAssertEqual(flow.draft.introduction.name, "Alex", "never replaced by a fixture")
    }

    func testReEntryWithoutAChoiceStaysUnselected() {
        var flow = SignalRoute.onSignal(.social)
        flow.leaveSignal()
        flow.continueFromWristband()
        XCTAssertNil(flow.draft.signal)
    }

    // MARK: - The endpoint: Places (chapter 07)

    /// Intentionally changed with chapter 07: Continue preview, once available, opens Places (Now,
    /// the first time) instead of showing "End of this preview.". The legacy ready summary stays
    /// unreachable, and a repeated Continue pushes nothing.
    func testContinuePreviewOpensPlacesOnceAndTheLegacyReadyIsUnreachable() {
        var flow = SignalRoute.onSignal(.dating)
        XCTAssertFalse(flow.openPlaces(), "no approach, no Places")
        flow.chooseApproach(.okayToSayHello)
        XCTAssertTrue(flow.continueSignalPreview())
        XCTAssertFalse(flow.confirmSignal(), "the legacy route needs the legacy profile")
        XCTAssertTrue(flow.openPlaces())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band, .signal, .places])
        XCTAssertEqual(flow.placesCategory, .now)
        XCTAssertFalse(flow.openPlaces(), "a repeated Continue preview pushes nothing")
        XCTAssertFalse(flow.continueSignalPreview(), "Continue preview belongs to Signal")
        XCTAssertEqual(flow.path.count, 6)
        XCTAssertEqual(flow.draft.band, .dating)
        XCTAssertEqual(flow.draft.signal, .okayToSayHello)
        XCTAssertNil(flow.readiness)
    }

    // MARK: - Memory and nothing conferred

    func testResetClearsTheApproach() {
        var flow = SignalRoute.onSignal(.business)
        flow.chooseApproach(.chatFirst)
        flow.reset()
        XCTAssertEqual(flow, DemoFlow(), "memory only: a new run starts empty")
        XCTAssertNil(flow.draft.signal)
        XCTAssertNil(flow.draft.band)
    }

    func testChoosingAnApproachConfersNothing() {
        var flow = SignalRoute.onSignal(.social)
        let birthday = flow.draft.birthdayEntry
        let introduction = flow.draft.introduction
        for approach in ApproachSignal.allCases + ApproachSignal.allCases { flow.chooseApproach(approach) }
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band, .signal], "choosing opens nothing")
        XCTAssertNil(flow.draft.dateOfBirth)
        XCTAssertEqual(flow.draft.birthdayEntry, birthday)
        XCTAssertEqual(flow.draft.introduction, introduction)
        XCTAssertNil(flow.draft.profile)
        XCTAssertNil(flow.readiness)
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "checkin", "online",
                     "match", "account", "identity", "consent", "permission", "location", "wave", "chat",
                     "message", "accepted", "request"]
        for label in Self.propertyNames(of: flow) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
    }

    func testNotPersistable() {
        XCTAssertFalse((ApproachSignal.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((ApproachSignal.self as Any.Type) is Decodable.Type)
        XCTAssertFalse((SignalSummary.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((SignalSummary.self as Any.Type) is Decodable.Type)
    }

    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            [child.label ?? ""] + propertyNames(of: child.value)
        }
    }
}

/// The approved route to Signal, with the fictional name "Alex".
enum SignalRoute {
    static func onSignal(_ intent: BandIntent) -> DemoFlow {
        var flow = WristbandRoute.onWristband()
        flow.chooseIntent(intent)
        flow.continueFromWristband()
        return flow
    }
}
