import Foundation
import XCTest
import ProximeetDomain

/// The Birthday gate on the way back: after reaching later chapters, a guest who returns to
/// Birthday and enters an ineligible date keeps every in-memory draft, but no forward route opens
/// until an eligible date is continued explicitly, and then only through the Pass's intro.
/// Every name and opener here is fictional test data.
final class AgeGateReturnTests: XCTestCase {
    private static let today = GuestListRoute.today

    /// Adult → Pass → Guest List → Wristband → Signal (Activity, Chat first), then Back to Birthday
    /// through each chapter's own Back.
    private func returnedToBirthday() -> DemoFlow {
        var flow = SignalRoute.onSignal(.activity)
        flow.chooseApproach(.chatFirst)
        XCTAssertTrue(flow.leaveSignal())
        XCTAssertTrue(flow.leaveWristband())
        XCTAssertTrue(flow.leaveGuestList())
        XCTAssertTrue(flow.leavePass())
        XCTAssertEqual(flow.path, [.birthday])
        return flow
    }

    private func assertEveryForwardRouteIsBlocked(_ flow: inout DemoFlow, _ state: String,
                                                  file: StaticString = #filePath, line: UInt = #line) {
        let before = flow
        XCTAssertNotEqual(flow.continueFromBirthday(today: Self.today), .eligible, state, file: file, line: line)
        XCTAssertFalse(flow.continueFromCompletedPass(GuestListRoute.completedPass()), state, file: file, line: line)
        XCTAssertFalse(flow.continueFromPass(), "\(state): the legacy Pass route", file: file, line: line)
        XCTAssertFalse(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)), state,
                       file: file, line: line)
        XCTAssertFalse(flow.continueFromWristband(), state, file: file, line: line)
        XCTAssertFalse(flow.chooseApproach(.okayToSayHello), state, file: file, line: line)
        XCTAssertFalse(flow.continueSignalPreview(), state, file: file, line: line)
        XCTAssertFalse(flow.openPlaces(), "\(state): Places", file: file, line: line)
        XCTAssertFalse(flow.openPlaceDetail(), "\(state): a venue's detail", file: file, line: line)
        XCTAssertFalse(flow.previewCheckIn(), "\(state): the check-in explanation", file: file, line: line)
        for place in [DemoScene.places, .placeDetail, .placeExplanation] {
            XCTAssertFalse(flow.draft.meetsRequirements(for: place), "\(state): \(place)", file: file, line: line)
        }
        for tail in [[DemoScene.demoPass], [.demoPass, .guestList], [.demoPass, .guestList, .band, .signal],
                     [.demoPass, .guestList, .band, .signal, .places, .placeDetail, .placeExplanation]] {
            XCTAssertFalse(flow.adoptNavigationPath([.birthday] + tail), "\(state): a pushed path", file: file, line: line)
        }
        XCTAssertFalse(flow.draft.meetsRequirements(for: .demoPass), state, file: file, line: line)
        XCTAssertEqual(flow.path, [.birthday], state, file: file, line: line)
        XCTAssertEqual(flow.draft.introduction, before.draft.introduction, "\(state): the introduction is kept",
                       file: file, line: line)
        XCTAssertEqual(flow.draft.band, .activity, "\(state): the intent is kept", file: file, line: line)
        XCTAssertEqual(flow.draft.signal, .chatFirst, "\(state): the approach is kept", file: file, line: line)
    }

    func testAnUnder18ReturnBlocksEveryForwardRouteAndKeepsTheDrafts() {
        var flow = returnedToBirthday()
        flow.updateBirthday { $0.setYear(2012); $0.commit(today: Self.today) }
        XCTAssertEqual(flow.draft.birthdayEntry.status, .underMinimumAge)
        assertEveryForwardRouteIsBlocked(&flow, "under 18")
    }

    func testIncompleteImpossibleAndUncommittedReturnsAreBlockedToo() {
        var incomplete = returnedToBirthday()
        incomplete.updateBirthday { $0.setYear(nil); $0.commit(today: Self.today) }
        XCTAssertEqual(incomplete.draft.birthdayEntry.status, .incomplete)
        assertEveryForwardRouteIsBlocked(&incomplete, "incomplete")

        var impossible = returnedToBirthday()
        impossible.updateBirthday { $0.setDay(31); $0.setMonth(2); $0.commit(today: Self.today) }
        XCTAssertEqual(impossible.draft.birthdayEntry.status, .impossible)
        assertEveryForwardRouteIsBlocked(&impossible, "31 February")

        var future = returnedToBirthday()
        future.updateBirthday { $0.setYear(2027); $0.commit(today: Self.today) }
        assertEveryForwardRouteIsBlocked(&future, "a future date")

        var uncommitted = returnedToBirthday()
        uncommitted.updateBirthday { $0.setYear(2012) }
        XCTAssertEqual(uncommitted.draft.birthdayEntry.status, .editing)
        assertEveryForwardRouteIsBlocked(&uncommitted, "an uncommitted edit")
    }

    func testAnOldLegacyAdultDateCannotAuthorizeAChangedEntry() {
        // The legacy date input stores an adult date of birth; the approved entry then changes.
        var flow = DemoFlow()
        flow.begin()
        XCTAssertEqual(flow.submitBirthday(Fixture.adultBirthday, using: Fixture.eligibility), .eligible)
        XCTAssertNotNil(flow.draft.dateOfBirth)
        XCTAssertTrue(flow.leavePass())
        flow.updateBirthday { $0.setDay(12); $0.setMonth(5); $0.setYear(2012); $0.commit(today: Self.today) }
        XCTAssertFalse(flow.draft.meetsRequirements(for: .demoPass), "the old adult date no longer counts")
        XCTAssertNotEqual(flow.continueFromBirthday(today: Self.today), .eligible)
        XCTAssertEqual(flow.path, [.birthday])
    }

    func testCorrectingTheDateNeedsContinueAndTheRealPassIntroRoute() {
        var flow = returnedToBirthday()
        flow.updateBirthday { $0.setYear(2012); $0.commit(today: Self.today) }
        flow.updateBirthday { $0.setYear(1997); $0.commit(today: Self.today) }
        XCTAssertEqual(flow.draft.birthdayEntry.status, .eligible)
        XCTAssertEqual(flow.path, [.birthday], "a corrected date does not move on by itself")

        XCTAssertEqual(flow.continueFromBirthday(today: Self.today), .eligible)
        XCTAssertEqual(flow.path, [.birthday, .demoPass], "the Pass, from its intro; never straight to Signal")
        XCTAssertFalse(flow.continueFromCompletedPass(PassDemo()), "an unfinished Pass demo does not move on")
        XCTAssertFalse(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)))
        XCTAssertFalse(flow.continueFromWristband())

        XCTAssertTrue(flow.continueFromCompletedPass(GuestListRoute.completedPass()))
        XCTAssertEqual(flow.draft.introduction.name, "Alex", "the introduction was kept")
        XCTAssertTrue(flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction)))
        XCTAssertEqual(flow.draft.band, .activity, "the intent was kept")
        XCTAssertTrue(flow.continueFromWristband())
        XCTAssertEqual(flow.draft.signal, .chatFirst, "the approach was kept")
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band, .signal])
    }

    func testRelaunchStillClearsTheDraft() {
        var flow = returnedToBirthday()
        flow.updateBirthday { $0.setYear(2012); $0.commit(today: Self.today) }
        flow.reset()
        XCTAssertEqual(flow, DemoFlow())
    }
}
