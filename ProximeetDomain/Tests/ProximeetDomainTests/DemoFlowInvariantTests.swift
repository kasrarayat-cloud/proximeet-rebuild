import Foundation
import XCTest
import ProximeetDomain

/// Applies long, seeded sequences of arbitrary actions — including out-of-order,
/// repeated and invalid ones — and checks the flow's invariants after every step.
final class DemoFlowInvariantTests: XCTestCase {
    private enum Action {
        case begin
        case submitBirthday(Date)
        case continueFromPass
        case saveProfile(String, [String])
        case continueFromGuestList
        case selectBand(BandIntent)
        case confirmBand
        case selectSignal(ApproachSignal)
        case confirmSignal
        case chooseIntent(BandIntent)
        case chooseApproach(ApproachSignal)
        case continueFromWristband
        case leaveSignal
        case openPlaces
        case choosePlaceCategory(PlaceCategory)
        case openPlaceDetail
        case previewCheckIn
        case leavePlaces
        case leavePlaceDetail
        case backToPlace
        case exploreOtherPlaces
        case reconcileRoute
        /// The current scene's own forward step (legacy or approved), so deep paths are reached by
        /// design rather than by luck: `choice` picks the intent and, on Signal, Places or the
        /// legacy summary.
        case progress(Int)
        case goBack
        case returnTo(DemoScene)
        case adoptPath([DemoScene])
        case reset
    }

    /// Both branches after Welcome: into Places, or the legacy ready summary.
    private static let journeys = [DemoScene.approvedJourney, DemoScene.legacyJourney]

    private static let birthdays = [
        Fixture.adultBirthday, Fixture.underageBirthday, Fixture.futureBirthday, Fixture.date(2008, 9, 24),
    ]
    private static let profiles: [(String, [String])] = [
        (Fixture.firstName, Fixture.interests),
        ("Sample", ["Pottery", "Salsa", "Chess"]),
        ("", ["Jazz", "Chess", "Tennis"]),
        ("Sample", ["Jazz", "jazz", "Tennis"]),
        ("Sample", ["Jazz", "Chess"]),
    ]

    /// One action in four is the current scene's own forward step; the rest are drawn from every
    /// action, valid or not, including the approved Signal and Places transitions.
    private func randomAction(_ rng: inout SplitMix64) -> Action {
        if rng.next(below: 4) == 0 {
            return .progress(rng.next(below: 8))
        }
        switch rng.next(below: 26) {
        case 13: return .chooseIntent(BandIntent.allCases[rng.next(below: 4)])
        case 14: return .chooseApproach(ApproachSignal.allCases[rng.next(below: ApproachSignal.allCases.count)])
        case 15: return .continueFromWristband
        case 16: return .leaveSignal
        case 17, 18: return .openPlaces
        case 19: return .choosePlaceCategory(PlaceCategory.allCases[rng.next(below: 3)])
        case 20: return .openPlaceDetail
        case 21: return .previewCheckIn
        case 22: return [.leavePlaces, .leavePlaceDetail][rng.next(below: 2)]
        case 23: return [.backToPlace, .exploreOtherPlaces][rng.next(below: 2)]
        case 24: return .reconcileRoute
        case 25:
            // A proposed Places path: only pops of the actual path may be adopted.
            let journey = DemoScene.approvedJourney
            return .adoptPath(Array(journey.prefix(rng.next(below: journey.count + 1))))
        case 0: return .begin
        case 1: return .submitBirthday(Self.birthdays[rng.next(below: Self.birthdays.count)])
        case 2: return .continueFromPass
        case 3:
            let profile = Self.profiles[rng.next(below: Self.profiles.count)]
            return .saveProfile(profile.0, profile.1)
        case 4: return .continueFromGuestList
        case 5: return .selectBand(BandIntent.allCases[rng.next(below: 4)])
        case 6: return .confirmBand
        case 7: return .selectSignal(ApproachSignal.allCases[rng.next(below: ApproachSignal.allCases.count)])
        case 8: return .confirmSignal
        case 9: return .goBack
        case 10: return .returnTo(DemoScene.allCases[rng.next(below: DemoScene.allCases.count)])
        case 11:
            // Mix of legitimate pops and attempts to push or rewrite the path.
            let journey = Self.journeys[rng.next(below: Self.journeys.count)]
            let length = rng.next(below: journey.count + 1)
            var proposed = Array(journey.prefix(length))
            if rng.next(below: 3) == 0, !proposed.isEmpty {
                proposed[rng.next(below: proposed.count)] = DemoScene.allCases[rng.next(below: DemoScene.allCases.count)]
            }
            return .adoptPath(proposed)
        default: return .reset
        }
    }

    private func apply(_ action: Action, to flow: inout DemoFlow) {
        switch action {
        case .begin: flow.begin()
        case .submitBirthday(let date): flow.submitBirthday(date, using: Fixture.eligibility)
        case .continueFromPass: flow.continueFromPass()
        case .saveProfile(let name, let interests): flow.saveProfile(firstName: name, interests: interests)
        case .continueFromGuestList: flow.continueFromGuestList()
        case .selectBand(let band): flow.selectBand(band)
        case .confirmBand: flow.confirmBand()
        case .selectSignal(let signal): flow.selectSignal(signal)
        case .confirmSignal: flow.confirmSignal()
        case .chooseIntent(let intent): flow.chooseIntent(intent)
        case .chooseApproach(let approach): flow.chooseApproach(approach)
        case .continueFromWristband: flow.continueFromWristband()
        case .leaveSignal: flow.leaveSignal()
        case .openPlaces: flow.openPlaces()
        case .choosePlaceCategory(let category): flow.choosePlaceCategory(category)
        case .openPlaceDetail: flow.openPlaceDetail()
        case .previewCheckIn: flow.previewCheckIn()
        case .leavePlaces: flow.leavePlaces()
        case .leavePlaceDetail: flow.leavePlaceDetail()
        case .backToPlace: flow.backToPlace()
        case .exploreOtherPlaces: flow.exploreOtherPlaces()
        case .reconcileRoute: flow.reconcileRoute()
        case .progress(let choice):
            switch flow.currentScene {
            case .welcome: flow.begin()
            case .birthday: flow.submitBirthday(Fixture.adultBirthday, using: Fixture.eligibility)
            case .demoPass: flow.continueFromPass()
            case .guestList:
                flow.saveProfile(firstName: Fixture.firstName, interests: Fixture.interests)
                flow.continueFromGuestList()
            case .band:
                flow.selectBand(BandIntent.allCases[choice / 2])
                flow.confirmBand()
            case .signal:
                flow.selectSignal(ApproachSignal.allCases[choice % ApproachSignal.allCases.count])
                if choice % 2 == 0 { flow.openPlaces() } else { flow.confirmSignal() }
            case .places: flow.openPlaceDetail()
            case .placeDetail: flow.previewCheckIn()
            case .readyForCheckIn, .placeExplanation: break
            }
        case .goBack: flow.goBack()
        case .returnTo(let scene): flow.returnTo(scene)
        case .adoptPath(let path): flow.adoptNavigationPath(path)
        case .reset: flow.reset()
        }
    }

    private func assertInvariants(_ flow: DemoFlow, after action: Action, step: Int, seed: UInt64) {
        let context = "seed \(seed), step \(step), after \(action)"

        XCTAssertTrue(Self.journeys.contains { Array($0.prefix(flow.path.count)) == flow.path },
                      "Path out of order: \(flow.path) \(context)")

        for scene in flow.path {
            XCTAssertTrue(flow.draft.meetsRequirements(for: scene), "\(scene) reached without its data: \(context)")
            XCTAssertTrue(flow.allows(scene), "\(scene) shown when not allowed: \(context)")
        }
        if flow.path.contains(.placeExplanation) {
            XCTAssertEqual(flow.placeVenue, .commonGround, "The explanation is Common Ground's only: \(context)")
            XCTAssertEqual(flow.placeEligibility?.canPreviewCheckIn, true, "An ineligible explanation: \(context)")
        }

        if let birthday = flow.draft.dateOfBirth {
            XCTAssertEqual(Fixture.eligibility.evaluate(dateOfBirth: birthday), .eligible, "Ineligible birthday kept: \(context)")
        }

        XCTAssertEqual(flow.readiness != nil, flow.currentScene == .readyForCheckIn, "Readiness mismatch: \(context)")
        if let summary = flow.readiness {
            XCTAssertEqual(summary.profile, flow.draft.profile, context)
            XCTAssertEqual(summary.band, flow.draft.band, context)
            XCTAssertEqual(summary.signal, flow.draft.signal, context)
            XCTAssertEqual(summary.passMark, .demo, context)
            XCTAssertEqual(summary.visibility, .notVisibleToAnyone, context)
        }
    }

    func testInvariantsHoldAcrossArbitraryActionSequences() {
        var reachedReady = 0
        var reachedPlaces = 0
        var reachedExplanation = 0
        for seed in UInt64(1)...40 {
            var rng = SplitMix64(seed: seed)
            var flow = DemoFlow()
            for step in 0..<400 {
                let action = randomAction(&rng)
                apply(action, to: &flow)
                assertInvariants(flow, after: action, step: step, seed: seed)
                if flow.currentScene == .readyForCheckIn { reachedReady += 1 }
                if flow.path.contains(.places) { reachedPlaces += 1 }
                if flow.currentScene == .placeExplanation { reachedExplanation += 1 }
            }
        }
        XCTAssertGreaterThan(reachedReady, 0, "Sequences should sometimes reach the ready scene")
        XCTAssertGreaterThan(reachedPlaces, 0, "Sequences should sometimes reach Places")
        XCTAssertGreaterThan(reachedExplanation, 0, "Sequences should sometimes reach the check-in explanation")
    }

    func testSameActionSequenceAlwaysProducesTheSameState() {
        for seed in UInt64(100)...110 {
            var first = SplitMix64(seed: seed)
            var second = SplitMix64(seed: seed)
            var a = DemoFlow()
            var b = DemoFlow()
            for _ in 0..<300 {
                apply(randomAction(&first), to: &a)
            }
            for _ in 0..<300 {
                apply(randomAction(&second), to: &b)
            }
            XCTAssertEqual(a, b, "seed \(seed)")
        }
    }
}

/// Small deterministic generator so failures are reproducible from the seed.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}
