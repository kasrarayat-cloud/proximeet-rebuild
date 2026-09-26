import Foundation
import XCTest
import ProximeetDomain

/// The approved Wristband (chapter 05): one optional intent, its route from the Guest List card,
/// and what it does not confer. Every name and opener here is fictional test data.
final class WristbandRouteTests: XCTestCase {

    // MARK: - Route from the Guest List card

    func testOnlyTheCardOfAPreviewableIntroductionOpensTheWristband() {
        var flow = WristbandRoute.onGuestList(named: "Alex")
        var editor = GuestListDemo()
        XCTAssertFalse(flow.continueFromGuestListCard(editor), "the editor has no Continue preview")
        XCTAssertEqual(flow.currentScene, .guestList)

        editor.preview(flow.draft.introduction)
        XCTAssertTrue(flow.continueFromGuestListCard(editor))
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band])
        XCTAssertFalse(flow.continueFromGuestListCard(editor), "a repeated Continue preview pushes nothing")
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band])
    }

    func testABlankOrOverLimitIntroductionCannotOpenTheWristband() {
        var flow = WristbandRoute.onGuestList(named: "Alex")
        let card = WristbandRoute.card(for: flow.draft.introduction)
        flow.editIntroduction { $0.name = " \n " }
        XCTAssertFalse(flow.continueFromGuestListCard(card))
        flow.editIntroduction { $0 = GuestIntroduction(name: "Alex", opener: String(repeating: "x", count: 121)) }
        XCTAssertFalse(flow.continueFromGuestListCard(card))
        XCTAssertEqual(flow.currentScene, .guestList)
    }

    func testTheLegacyRoutesCannotBypassTheCardOrReachSignal() {
        var flow = WristbandRoute.onGuestList(named: "Alex")
        XCTAssertFalse(flow.continueFromGuestList(), "the legacy route needs the legacy profile")
        flow = WristbandRoute.onWristband()
        flow.chooseIntent(.social)
        XCTAssertFalse(flow.confirmBand(), "the approved Wristband never reaches Signal")
        XCTAssertEqual(flow.currentScene, .band)
    }

    // MARK: - One optional intent

    func testAFreshWristbandHasNoIntentAndNoContinue() {
        let flow = WristbandRoute.onWristband()
        XCTAssertNil(flow.draft.band, "no default, nothing inferred from the introduction")
        XCTAssertFalse(flow.continueWristbandPreview())
        XCTAssertEqual(WristbandSummary(choice: flow.draft.band),
                       WristbandSummary(choice: nil))
        XCTAssertEqual(WristbandSummary(choice: nil).title, "Your moment. Your choice.")
        XCTAssertEqual(WristbandSummary(choice: nil).explanation, "Pick the band that fits right now.")
    }

    func testEveryChangeFromEveryStateSelectsExactlyTheTappedIntent() {
        let starts: [BandIntent?] = [nil] + BandIntent.allCases.map { $0 }
        for start in starts {
            for target in BandIntent.allCases {
                var flow = WristbandRoute.onWristband()
                if let start { flow.chooseIntent(start) }
                let changed = flow.chooseIntent(target)
                XCTAssertEqual(flow.draft.band, target, "\(String(describing: start)) → \(target)")
                XCTAssertEqual(changed, start != target, "\(String(describing: start)) → \(target) reports a change only when it is one")
                XCTAssertTrue(flow.continueWristbandPreview())
                XCTAssertEqual(flow.currentScene, .band, "nothing advances")
            }
        }
    }

    func testTappingTheSelectedIntentIsANoOpAndNeverClearsIt() {
        for intent in BandIntent.allCases {
            var flow = WristbandRoute.onWristband()
            flow.chooseIntent(intent)
            let before = flow
            XCTAssertFalse(flow.chooseIntent(intent))
            XCTAssertEqual(flow, before)
            XCTAssertEqual(flow.draft.band, intent)
        }
    }

    func testTheLastOfRapidChangesWins() {
        var flow = WristbandRoute.onWristband()
        let taps: [BandIntent] = [.social, .dating, .business, .activity, .dating, .dating, .social, .business]
        for tap in taps { flow.chooseIntent(tap) }
        XCTAssertEqual(flow.draft.band, taps.last)
    }

    func testIntentsAreOnlyChosenOnTheWristband() {
        var flow = WristbandRoute.onGuestList(named: "Alex")
        let before = flow
        XCTAssertFalse(flow.chooseIntent(.dating))
        XCTAssertFalse(flow.continueWristbandPreview())
        XCTAssertFalse(flow.leaveWristband())
        XCTAssertEqual(flow, before)
    }

    // MARK: - Words derived from the intent

    func testTheApprovedWordsInTheApprovedOrder() {
        XCTAssertEqual(BandIntent.allCases, [.social, .dating, .business, .activity])
        XCTAssertEqual(BandIntent.allCases.map(\.title), ["Social", "Dating", "Business", "Activity"])
        XCTAssertEqual(BandIntent.allCases.map(\.wristbandHint),
                       ["People & moments", "Romantic connection", "Ideas & work", "Do something"])
        XCTAssertEqual(BandIntent.allCases.map(\.wristbandExplanation),
                       ["Meet people. Share a moment.", "Explore a romantic connection.",
                        "Exchange ideas and opportunities.", "Find someone to do things with."])
        for intent in BandIntent.allCases {
            let summary = WristbandSummary(choice: intent)
            XCTAssertEqual(summary.title, "\(intent.title) · Selected")
            XCTAssertEqual(summary.explanation, intent.wristbandExplanation)
        }
    }

    // MARK: - Back, re-entry and memory

    func testBackReturnsToTheGuestListAndReEntryKeepsTheIntent() {
        var flow = WristbandRoute.onWristband()
        flow.chooseIntent(.business)
        let introduction = flow.draft.introduction
        XCTAssertTrue(flow.leaveWristband())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList])
        XCTAssertFalse(flow.leaveWristband(), "a repeated Back cannot also leave the Guest List")
        XCTAssertEqual(flow.draft.band, .business)
        XCTAssertEqual(flow.draft.introduction, introduction)

        XCTAssertTrue(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)))
        XCTAssertEqual(flow.draft.band, .business, "re-entry keeps the intent")
    }

    func testReEntryWithoutAChoiceStaysUnselected() {
        var flow = WristbandRoute.onWristband()
        flow.leaveWristband()
        flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction))
        XCTAssertNil(flow.draft.band)
    }

    func testEditingTheIntroductionKeepsTheIntentAndShowsTheNewWords() {
        var flow = WristbandRoute.onWristband()
        flow.chooseIntent(.activity)
        flow.leaveWristband()
        XCTAssertTrue(flow.editIntroduction { $0.opener = "Up for a climb this weekend." })
        XCTAssertTrue(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)))
        XCTAssertEqual(flow.draft.band, .activity)
        XCTAssertEqual(flow.draft.introduction.card?.opener, "Up for a climb this weekend.")
        XCTAssertEqual(flow.draft.introduction.name, "Alex", "never replaced by a fixture")
    }

    func testResetClearsTheIntent() {
        var flow = WristbandRoute.onWristband()
        flow.chooseIntent(.dating)
        flow.reset()
        XCTAssertNil(flow.draft.band, "memory only: a new run starts unselected")
        XCTAssertEqual(flow.draft.introduction, GuestIntroduction())
    }

    // MARK: - Nothing is conferred

    func testChoosingAnIntentConfersNothing() {
        var flow = WristbandRoute.onWristband()
        let birthday = flow.draft.birthdayEntry
        for intent in BandIntent.allCases { flow.chooseIntent(intent) }
        XCTAssertTrue(flow.continueWristbandPreview())
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band], "no later scene")
        XCTAssertNil(flow.draft.dateOfBirth)
        XCTAssertEqual(flow.draft.birthdayEntry, birthday)
        XCTAssertNil(flow.draft.profile)
        XCTAssertNil(flow.draft.signal, "approach preference belongs to Signal")
        XCTAssertNil(flow.readiness)
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "checkin", "online",
                     "match", "account", "identity", "consent", "permission", "location"]
        for label in Self.propertyNames(of: flow) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
    }

    func testNotPersistable() {
        XCTAssertFalse((BandIntent.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((WristbandSummary.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((WristbandSummary.self as Any.Type) is Decodable.Type)
    }

    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            [child.label ?? ""] + propertyNames(of: child.value)
        }
    }
}

/// The approved route to the Wristband, with the fictional name "Alex".
enum WristbandRoute {
    static func onGuestList(named name: String) -> DemoFlow {
        var flow = GuestListRoute.onGuestList()
        flow.editIntroduction { $0.name = name }
        return flow
    }

    static func card(for introduction: GuestIntroduction) -> GuestListDemo {
        var demo = GuestListDemo()
        demo.preview(introduction)
        return demo
    }

    static func onWristband() -> DemoFlow {
        var flow = onGuestList(named: "Alex")
        flow.continueFromGuestListCard(card(for: flow.draft.introduction))
        return flow
    }
}
