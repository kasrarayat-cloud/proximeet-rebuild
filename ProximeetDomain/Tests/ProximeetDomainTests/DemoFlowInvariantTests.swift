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
        case goBack
        case returnTo(DemoScene)
        case adoptPath([DemoScene])
        case reset
    }

    private static let journey = Array(DemoScene.allCases.dropFirst())

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

    private func randomAction(_ rng: inout SplitMix64) -> Action {
        switch rng.next(below: 13) {
        case 0: return .begin
        case 1: return .submitBirthday(Self.birthdays[rng.next(below: Self.birthdays.count)])
        case 2: return .continueFromPass
        case 3:
            let profile = Self.profiles[rng.next(below: Self.profiles.count)]
            return .saveProfile(profile.0, profile.1)
        case 4: return .continueFromGuestList
        case 5: return .selectBand(BandIntent.allCases[rng.next(below: 4)])
        case 6: return .confirmBand
        case 7: return .selectSignal(ApproachSignal.allCases[rng.next(below: 4)])
        case 8: return .confirmSignal
        case 9: return .goBack
        case 10: return .returnTo(DemoScene.allCases[rng.next(below: DemoScene.allCases.count)])
        case 11:
            // Mix of legitimate pops and attempts to push or rewrite the path.
            let length = rng.next(below: Self.journey.count + 1)
            var proposed = Array(Self.journey.prefix(length))
            if rng.next(below: 3) == 0, !proposed.isEmpty {
                proposed[rng.next(below: proposed.count)] = DemoScene.allCases[rng.next(below: 7)]
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
        case .goBack: flow.goBack()
        case .returnTo(let scene): flow.returnTo(scene)
        case .adoptPath(let path): flow.adoptNavigationPath(path)
        case .reset: flow.reset()
        }
    }

    private func assertInvariants(_ flow: DemoFlow, after action: Action, step: Int, seed: UInt64) {
        let context = "seed \(seed), step \(step), after \(action)"

        XCTAssertEqual(flow.path, Array(Self.journey.prefix(flow.path.count)), "Path out of order: \(context)")

        for scene in flow.path {
            XCTAssertTrue(flow.draft.meetsRequirements(for: scene), "\(scene) reached without its data: \(context)")
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
        for seed in UInt64(1)...40 {
            var rng = SplitMix64(seed: seed)
            var flow = DemoFlow()
            for step in 0..<400 {
                let action = randomAction(&rng)
                apply(action, to: &flow)
                assertInvariants(flow, after: action, step: step, seed: seed)
                if flow.currentScene == .readyForCheckIn { reachedReady += 1 }
            }
        }
        XCTAssertGreaterThan(reachedReady, 0, "Sequences should sometimes reach the ready scene")
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
