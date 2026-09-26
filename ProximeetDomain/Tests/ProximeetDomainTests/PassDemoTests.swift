import Foundation
import XCTest
import ProximeetDomain

/// The approved Pass (chapter 03): a user-controlled preview with three stages. Only the
/// matching explicit action changes the stage; nothing records or verifies anything.
final class PassDemoTests: XCTestCase {
    private let today = CivilDate(year: 2026, month: 9, day: 25)!

    // MARK: - Stages

    func testStartsAtIntro() {
        XCTAssertEqual(PassDemo().stage, .intro)
    }

    func testTryTheDemoThenFinishPreviewIsImmediate() {
        var demo = PassDemo()
        XCTAssertTrue(demo.start())
        XCTAssertEqual(demo.stage, .progress)
        XCTAssertTrue(demo.finish(), "finish is available as soon as progress is shown")
        XCTAssertEqual(demo.stage, .complete)
    }

    func testCancelReturnsToIntroAndCanStartAgain() {
        var demo = PassDemo()
        demo.start()
        XCTAssertTrue(demo.cancel())
        XCTAssertEqual(demo.stage, .intro)
        XCTAssertTrue(demo.start())
        XCTAssertEqual(demo.stage, .progress)
    }

    func testRepeatedOrStaleActionsNeverSkipAStage() {
        var demo = PassDemo()
        XCTAssertFalse(demo.finish(), "finish cannot skip progress")
        XCTAssertFalse(demo.cancel())
        XCTAssertEqual(demo.stage, .intro)

        demo.start()
        XCTAssertFalse(demo.start(), "a second 'Try the demo' does nothing")
        XCTAssertEqual(demo.stage, .progress)

        demo.finish()
        XCTAssertFalse(demo.finish())
        XCTAssertFalse(demo.start())
        XCTAssertFalse(demo.cancel(), "complete has no Cancel; Leave demo exits instead")
        XCTAssertEqual(demo.stage, .complete)
    }

    func testContinuePreviewOnlyEndsTheReviewAndNeverChangesTheStage() {
        var demo = PassDemo()
        XCTAssertFalse(demo.continuePreview())
        demo.start()
        XCTAssertFalse(demo.continuePreview())
        demo.finish()
        XCTAssertTrue(demo.continuePreview())
        XCTAssertEqual(demo.stage, .complete)
    }

    func testANewDemoAlwaysStartsAtIntro() {
        var demo = PassDemo()
        demo.start()
        demo.finish()
        demo = PassDemo()
        XCTAssertEqual(demo.stage, .intro, "re-entry starts at intro")
    }

    func testNotPersistable() {
        XCTAssertFalse((PassDemo.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((PassDemo.self as Any.Type) is Decodable.Type)
    }

    // MARK: - Route

    private func flowOnPass() -> DemoFlow {
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

    func testLeavingThePassReturnsToBirthdayWithItsDraft() {
        var flow = flowOnPass()
        XCTAssertEqual(flow.currentScene, .demoPass)
        let birthday = flow.draft.birthdayEntry
        XCTAssertTrue(flow.leavePass())
        XCTAssertEqual(flow.currentScene, .birthday)
        XCTAssertEqual(flow.draft.birthdayEntry, birthday, "the Birthday draft and its check are kept")
        XCTAssertFalse(flow.leavePass(), "a repeated Back or Leave cannot also leave Birthday")
        XCTAssertEqual(flow.currentScene, .birthday)
    }

    func testReEntryFromBirthdayReachesThePassAgain() {
        var flow = flowOnPass()
        flow.leavePass()
        XCTAssertEqual(flow.continueFromBirthday(today: today), .eligible)
        XCTAssertEqual(flow.currentScene, .demoPass)
    }

    func testThePassChangesNothingElseAndNeverMovesOn() {
        let flow = flowOnPass()
        var demo = PassDemo()
        let before = flow
        demo.start()
        demo.finish()
        _ = demo.continuePreview()
        XCTAssertEqual(flow, before, "the demo holds no link to the draft or the path")
        XCTAssertNil(flow.draft.dateOfBirth, "no stored date, no legacy pass state")
        XCTAssertNil(flow.draft.profile)
        XCTAssertEqual(flow.path, [.birthday, .demoPass], "nothing after the Pass is reached")
    }
}
