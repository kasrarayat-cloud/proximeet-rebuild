import Foundation
import XCTest
import ProximeetDomain

/// The approved Guest List's stages and its route from the approved Pass (chapter 04).
final class GuestListRouteTests: XCTestCase {

    // MARK: - Stages

    func testStartsAtTheEditor() {
        XCTAssertEqual(GuestListDemo().stage, .editor)
    }

    func testPreviewNeedsAPreviewableDraft() {
        var demo = GuestListDemo()
        XCTAssertFalse(demo.preview(GuestIntroduction()), "no name")
        XCTAssertFalse(demo.preview(GuestIntroduction(name: " \n ")), "blank name")
        XCTAssertFalse(demo.preview(GuestIntroduction(name: "Alex", opener: String(repeating: "x", count: 121))))
        XCTAssertEqual(demo.stage, .editor)
        XCTAssertTrue(demo.preview(GuestIntroduction(name: "Alex")), "a name alone is enough")
        XCTAssertEqual(demo.stage, .card)
    }

    func testRepeatedOrStaleActionsNeverSkipAStage() {
        var demo = GuestListDemo()
        let alex = GuestIntroduction(name: "Alex")
        XCTAssertFalse(demo.edit(), "the editor has no edit")
        XCTAssertFalse(demo.continuePreview(), "the editor has no endpoint")
        demo.preview(alex)
        XCTAssertFalse(demo.preview(alex), "a second Preview does nothing")
        XCTAssertEqual(demo.stage, .card)
        XCTAssertTrue(demo.edit())
        XCTAssertFalse(demo.edit(), "a second Edit does nothing")
        XCTAssertEqual(demo.stage, .editor)
    }

    func testContinuePreviewOnlyEndsTheReviewAndNeverChangesTheStage() {
        var demo = GuestListDemo()
        demo.preview(GuestIntroduction(name: "Alex"))
        XCTAssertTrue(demo.continuePreview())
        XCTAssertTrue(demo.continuePreview())
        XCTAssertEqual(demo.stage, .card, "no later chapter")
    }

    // MARK: - Route from the Pass

    func testOnlyACompletedPassOpensTheGuestList() {
        var flow = GuestListRoute.onPass()
        var demo = PassDemo()
        XCTAssertFalse(flow.continueFromCompletedPass(demo), "intro")
        demo.start()
        XCTAssertFalse(flow.continueFromCompletedPass(demo), "in progress")
        XCTAssertEqual(flow.path, [.birthday, .demoPass])
        demo.finish()
        XCTAssertTrue(flow.continueFromCompletedPass(demo))
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList])
        XCTAssertFalse(flow.continueFromCompletedPass(demo), "a repeated Continue preview pushes nothing")
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList])
        XCTAssertEqual(demo.stage, .complete, "the Pass stays complete underneath")
    }

    func testTheGuestListNeedsTheBirthdayGateToo() {
        var flow = DemoFlow()
        flow.begin()
        XCTAssertFalse(flow.continueFromCompletedPass(GuestListRoute.completedPass()), "not on the Pass")
        XCTAssertFalse(flow.draft.meetsRequirements(for: .guestList), "no eligible date")
        XCTAssertEqual(flow.path, [.birthday])
    }

    func testEditsAreOnlyAcceptedOnTheGuestList() {
        var flow = GuestListRoute.onPass()
        let before = flow
        XCTAssertFalse(flow.editIntroduction { $0.name = "Alex" })
        XCTAssertFalse(flow.leaveGuestList())
        XCTAssertEqual(flow, before)
    }

    func testBackReturnsToThePassAndReEntryKeepsTheDraft() {
        var flow = GuestListRoute.onGuestList()
        let raw = GuestIntroduction(name: "  Alex ", opener: "Always up for coffee and a good story.\n",
                                    interests: [.coffee, .outdoors])
        flow.editIntroduction { $0 = raw }

        XCTAssertTrue(flow.leaveGuestList())
        XCTAssertEqual(flow.currentScene, .demoPass)
        XCTAssertEqual(flow.draft.introduction, raw, "Back keeps the raw draft")
        XCTAssertFalse(flow.leaveGuestList(), "a repeated Back cannot also leave the Pass")
        XCTAssertEqual(flow.path, [.birthday, .demoPass])

        XCTAssertTrue(flow.continueFromCompletedPass(GuestListRoute.completedPass()))
        XCTAssertEqual(flow.draft.introduction, raw, "re-entry shows the same draft")

        // Leaving the Pass for Birthday and coming back through its gate keeps it too.
        flow.leaveGuestList()
        flow.leavePass()
        flow.continueFromBirthday(today: GuestListRoute.today)
        flow.continueFromCompletedPass(GuestListRoute.completedPass())
        XCTAssertEqual(flow.currentScene, .guestList)
        XCTAssertEqual(flow.draft.introduction, raw, "the draft lasts for the demo run")
    }

    func testResetClearsTheIntroduction() {
        var flow = GuestListRoute.onGuestList()
        flow.editIntroduction { $0 = GuestIntroduction(name: "Alex", opener: "Hello", interests: [.coffee]) }
        flow.reset()
        XCTAssertEqual(flow.draft.introduction, GuestIntroduction(), "memory only: a new run starts empty")
        XCTAssertEqual(flow.path, [])
    }

    // MARK: - Nothing is conferred

    func testTheRouteConfersNoVerificationVisibilityOrLaterChapter() throws {
        var flow = GuestListRoute.onGuestList()
        let birthday = flow.draft.birthdayEntry
        flow.editIntroduction { $0 = GuestIntroduction(name: "Alex", opener: "Hi", interests: GuestIntroduction.Interest.allCases) }
        var demo = GuestListDemo()
        XCTAssertTrue(demo.preview(flow.draft.introduction))
        XCTAssertTrue(demo.continuePreview())
        demo.edit()

        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList], "no later scene")
        XCTAssertFalse(flow.continueFromGuestList(), "the introduction cannot open the unapproved band scene")
        XCTAssertNil(flow.draft.dateOfBirth, "no stored birth date")
        XCTAssertEqual(flow.draft.birthdayEntry, birthday)
        XCTAssertNil(flow.draft.profile)
        XCTAssertNil(flow.draft.band)
        XCTAssertNil(flow.draft.signal)
        XCTAssertNil(flow.readiness)

        // No state anywhere in the draft or the flow could stand for a verified, visible,
        // discoverable, member, entitled or present guest.
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "present", "checkin", "online",
                     "match", "account", "identity"]
        for label in Self.propertyNames(of: flow) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
    }

    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            [child.label ?? ""] + propertyNames(of: child.value)
        }
    }
}

/// The approved route, through Birthday's gate with the fictional 12 May 1997.
enum GuestListRoute {
    static let today = CivilDate(year: 2026, month: 9, day: 26)!

    static func onPass() -> DemoFlow {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { entry in
            entry.setDay(12)
            entry.setMonth(5)
            entry.setYear(1997)
            entry.commit(today: today)
        }
        flow.continueFromBirthday(today: today)
        return flow
    }

    static func completedPass() -> PassDemo {
        var demo = PassDemo()
        demo.start()
        demo.finish()
        return demo
    }

    static func onGuestList() -> DemoFlow {
        var flow = onPass()
        flow.continueFromCompletedPass(completedPass())
        return flow
    }
}
