import Foundation
import XCTest
import ProximeetDomain

/// The approved Birthday screen's rules, with an injected civil "today" (never the clock).
final class BirthdayEntryTests: XCTestCase {
    private let today = CivilDate(year: 2026, month: 9, day: 25)!

    private func date(_ year: Int, _ month: Int, _ day: Int) -> CivilDate {
        CivilDate(year: year, month: month, day: day)!
    }

    private func entry(_ day: Int?, _ month: Int?, _ year: Int?, committedOn today: CivilDate? = nil) -> BirthdayEntry {
        var entry = BirthdayEntry()
        entry.setDay(day)
        entry.setMonth(month)
        entry.setYear(year)
        entry.commit(today: today ?? self.today)
        return entry
    }

    // MARK: - Strict civil dates

    func testImpossibleDatesAreRejectedNotNormalised() {
        XCTAssertNil(CivilDate(year: 2001, month: 4, day: 31))
        XCTAssertNil(CivilDate(year: 2023, month: 2, day: 29))
        XCTAssertNil(CivilDate(year: 1900, month: 2, day: 29), "1900 is not a leap year")
        XCTAssertNil(CivilDate(year: 2000, month: 2, day: 30))
        XCTAssertNil(CivilDate(year: 2000, month: 13, day: 1))
        XCTAssertNil(CivilDate(year: 2000, month: 0, day: 1))
        XCTAssertNil(CivilDate(year: 2000, month: 1, day: 0))
        XCTAssertNil(CivilDate(year: 2000, month: 1, day: 32))
    }

    func testRealDatesIncludingLeapDaysAreAccepted() {
        XCTAssertNotNil(CivilDate(year: 2024, month: 2, day: 29))
        XCTAssertNotNil(CivilDate(year: 2000, month: 2, day: 29), "2000 is a leap year")
        XCTAssertNotNil(CivilDate(year: 2001, month: 4, day: 30))
        XCTAssertNotNil(CivilDate(year: 1999, month: 12, day: 31))
    }

    func testLocalCivilDayFollowsTheDeviceTimeZone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let lateUTC = utc.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 23, minute: 30))!
        XCTAssertEqual(CivilDate.day(of: lateUTC, in: TimeZone(secondsFromGMT: 0)!), date(2026, 9, 24))
        XCTAssertEqual(CivilDate.day(of: lateUTC, in: TimeZone(secondsFromGMT: 2 * 3600)!), date(2026, 9, 25))
        XCTAssertEqual(CivilDate.day(of: lateUTC, in: TimeZone(secondsFromGMT: -10 * 3600)!), date(2026, 9, 24))
    }

    // MARK: - Exact eighteenth birthday

    func testExactEighteenthBirthdayIsEligible() {
        XCTAssertEqual(BirthdayEntry.evaluate(date(2008, 9, 25), today: today), .eligible)
    }

    func testDayBeforeEighteenthBirthdayIsUnderage() {
        XCTAssertEqual(BirthdayEntry.evaluate(date(2008, 9, 26), today: today), .underMinimumAge)
    }

    func testDayAfterEighteenthBirthdayIsEligible() {
        XCTAssertEqual(BirthdayEntry.evaluate(date(2008, 9, 24), today: today), .eligible)
    }

    func testYearSubtractionAloneWouldBeWrong() {
        // 2026 - 2008 = 18, yet this birthday is still three months away.
        XCTAssertEqual(BirthdayEntry.evaluate(date(2008, 12, 31), today: today), .underMinimumAge)
    }

    func testFutureDatesAndTodayItself() {
        XCTAssertEqual(BirthdayEntry.evaluate(date(2026, 9, 26), today: today), .future)
        XCTAssertEqual(BirthdayEntry.evaluate(date(2090, 1, 1), today: today), .future)
        XCTAssertEqual(BirthdayEntry.evaluate(today, today: today), .underMinimumAge, "born today is not future")
    }

    // MARK: - 29 February (provisional policy: 1 March in non-leap years)

    func testLeapDayBirthdayTurnsEighteenOnFirstMarchInANonLeapYear() {
        let leapDay = date(2008, 2, 29)
        XCTAssertEqual(BirthdayEntry.evaluate(leapDay, today: date(2026, 2, 28)), .underMinimumAge)
        XCTAssertEqual(BirthdayEntry.evaluate(leapDay, today: date(2026, 3, 1)), .eligible)
        XCTAssertEqual(leapDay.anniversary(adding: 18), date(2026, 3, 1))
    }

    func testLeapDayAnniversaryStaysOnLeapDayInALeapYear() {
        XCTAssertEqual(date(2004, 2, 29).anniversary(adding: 20), date(2024, 2, 29))
    }

    // MARK: - Entry states

    func testStartsEmptyAndCannotContinue() {
        let entry = BirthdayEntry()
        XCTAssertEqual(entry.status, .empty)
        XCTAssertEqual(entry.draft, BirthdayComponents())
        XCTAssertNil(entry.committed)
        XCTAssertFalse(entry.canContinue)
    }

    func testOneComponentLeavesTheOtherTwoUnsetAndNothingCommitted() {
        var entry = BirthdayEntry()
        XCTAssertEqual(entry.draft, BirthdayComponents(day: nil, month: nil, year: nil), "a new entry has no date at all")
        entry.setDay(12)
        XCTAssertEqual(entry.draft, BirthdayComponents(day: 12, month: nil, year: nil), "choosing the day sets nothing else")
        XCTAssertNil(entry.committed)
        XCTAssertEqual(entry.status, .editing)
        XCTAssertFalse(entry.canContinue)
        entry.commit(today: today)
        XCTAssertEqual(entry.draft, BirthdayComponents(day: 12, month: nil, year: nil), "checking fills nothing in")
        XCTAssertNil(entry.committed)
        XCTAssertEqual(entry.status, .incomplete)
        XCTAssertFalse(entry.canContinue)
    }

    func testPartialDatesAreIncompleteAfterCommit() {
        for partial in [entry(12, 5, nil), entry(12, nil, 1997), entry(nil, 5, 1997), entry(12, nil, nil)] {
            XCTAssertEqual(partial.status, .incomplete)
            XCTAssertNil(partial.committed)
            XCTAssertFalse(partial.canContinue)
        }
    }

    func testAprilThirtyFirstIsImpossible() {
        let entry = entry(31, 4, 1990)
        XCTAssertEqual(entry.status, .impossible)
        XCTAssertNil(entry.committed)
        XCTAssertFalse(entry.canContinue)
    }

    func testShortAndEarlyYearsAreRefusedNotGuessed() {
        for year in [97, 1, 1899] {
            let early = entry(12, 5, year)
            XCTAssertEqual(early.status, .yearOutOfRange, "year \(year)")
            XCTAssertNil(early.committed)
            XCTAssertFalse(early.canContinue)
        }
        XCTAssertEqual(entry(1, 1, BirthdayEntry.earliestYear).status, .eligible)
    }

    func testInvalidAndValidLeapDayEntries() {
        XCTAssertEqual(entry(29, 2, 2001).status, .impossible)
        XCTAssertEqual(entry(29, 2, 2000).status, .eligible)
    }

    func testFutureAndUnderageEntriesCannotContinue() {
        XCTAssertEqual(entry(26, 9, 2026).status, .future)
        XCTAssertEqual(entry(12, 5, 2012).status, .underMinimumAge)
        XCTAssertFalse(entry(26, 9, 2026).canContinue)
        XCTAssertFalse(entry(12, 5, 2012).canContinue)
    }

    func testAdultEntryCanContinue() {
        let adult = entry(12, 5, 1997)
        XCTAssertEqual(adult.status, .eligible)
        XCTAssertEqual(adult.committed, date(1997, 5, 12))
        XCTAssertTrue(adult.canContinue)
    }

    // MARK: - Edits invalidate the previous result

    func testAnyEditDisablesContinueUntilTheNextCommit() {
        var entry = entry(12, 5, 1997)
        XCTAssertTrue(entry.canContinue)
        entry.setYear(2012)
        XCTAssertEqual(entry.status, .editing)
        XCTAssertNil(entry.committed, "the earlier adult date must not survive an edit")
        XCTAssertFalse(entry.canContinue)
        entry.commit(today: today)
        XCTAssertEqual(entry.status, .underMinimumAge)
        XCTAssertFalse(entry.canContinue)
    }

    func testEditingAnAdultDateIntoAnIncompleteOneNeverKeepsContinue() {
        var entry = entry(12, 5, 1997)
        entry.setDay(nil)
        XCTAssertFalse(entry.canContinue)
        entry.commit(today: today)
        XCTAssertEqual(entry.status, .incomplete)
        XCTAssertFalse(entry.canContinue)
    }

    func testReenteringTheSameValueKeepsTheResult() {
        var entry = entry(12, 5, 1997)
        entry.setYear(1997)
        XCTAssertEqual(entry.status, .eligible)
    }

    func testClearingEverythingReturnsToEmpty() {
        var entry = entry(12, 5, 1997)
        entry.setDay(nil)
        entry.setMonth(nil)
        entry.setYear(nil)
        XCTAssertEqual(entry.status, .empty)
    }

    // MARK: - Re-evaluation (resume, before Continue)

    func testReevaluationFollowsANewToday() {
        var entry = entry(26, 9, 2008)
        XCTAssertEqual(entry.status, .underMinimumAge)
        entry.reevaluate(today: date(2026, 9, 26))
        XCTAssertEqual(entry.status, .eligible)
    }

    func testReevaluationLeavesADraftBeingEditedAlone() {
        var entry = entry(12, 5, 1997)
        entry.setMonth(6)
        entry.reevaluate(today: today)
        XCTAssertEqual(entry.status, .editing)
        XCTAssertFalse(entry.canContinue)
    }

    // MARK: - Demo flow integration

    func testBirthdayEditsOnlyApplyOnTheBirthdayScene() {
        var flow = DemoFlow()
        XCTAssertFalse(flow.updateBirthday { $0.setDay(12) })
        XCTAssertNil(flow.continueFromBirthday(today: today))
        flow.begin()
        XCTAssertTrue(flow.updateBirthday { $0.setDay(12) })
        XCTAssertEqual(flow.draft.birthdayEntry.draft.day, 12)
    }

    /// Intentionally changed with chapter 03: an eligible Continue now opens the approved Pass
    /// (it used to stay on Birthday with a "Pass is next." notice).
    func testEligibleContinueOpensThePassThroughTheBirthdayGate() {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { entry in
            entry.setDay(12)
            entry.setMonth(5)
            entry.setYear(1997)
            entry.commit(today: today)
        }
        XCTAssertEqual(flow.continueFromBirthday(today: today), .eligible)
        XCTAssertEqual(flow.currentScene, .demoPass)
        XCTAssertNil(flow.draft.dateOfBirth, "no legacy pass state is created")
        XCTAssertNil(flow.continueFromBirthday(today: today), "a repeated Continue cannot push Pass twice")
        XCTAssertEqual(flow.path, [.birthday, .demoPass])
    }

    func testOnlyAnEligibleCommittedDateOpensThePass() {
        let cases: [(BirthdayComponents, BirthdayStatus)] = [
            (BirthdayComponents(day: 12, month: 5, year: 2012), .underMinimumAge),
            (BirthdayComponents(day: 12, month: 5, year: nil), .incomplete),
            (BirthdayComponents(day: 31, month: 4, year: 1997), .impossible),
            (BirthdayComponents(day: 12, month: 5, year: 2090), .future),
            (BirthdayComponents(day: 12, month: 5, year: 97), .yearOutOfRange),
        ]
        for (components, expected) in cases {
            var flow = DemoFlow()
            flow.begin()
            flow.updateBirthday { entry in
                entry.setDay(components.day)
                entry.setMonth(components.month)
                entry.setYear(components.year)
                entry.commit(today: today)
            }
            XCTAssertEqual(flow.continueFromBirthday(today: today), expected)
            XCTAssertEqual(flow.currentScene, .birthday, "\(components) must not open the Pass")
        }
        // An adult date that is still being edited (not committed) cannot continue either.
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { $0.setDay(12); $0.setMonth(5); $0.setYear(1997) }
        XCTAssertEqual(flow.continueFromBirthday(today: today), .editing)
        XCTAssertEqual(flow.currentScene, .birthday)
    }

    func testBackToWelcomeKeepsTheDraftForTheSameRun() {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { $0.setDay(12); $0.setMonth(5) }
        XCTAssertTrue(flow.goBack())
        XCTAssertEqual(flow.currentScene, .welcome)
        XCTAssertTrue(flow.begin())
        XCTAssertEqual(flow.draft.birthdayEntry.draft, BirthdayComponents(day: 12, month: 5, year: nil))
    }

    func testResetClearsTheBirthday() {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { $0.setDay(12) }
        flow.reset()
        XCTAssertEqual(flow.draft.birthdayEntry, BirthdayEntry())
    }
}
