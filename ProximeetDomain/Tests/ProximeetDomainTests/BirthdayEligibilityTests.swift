import Foundation
import XCTest
import ProximeetDomain

final class BirthdayEligibilityTests: XCTestCase {
    private let check = BirthdayEligibility(referenceDate: Fixture.date(2026, 9, 24), calendar: Fixture.utc)

    func testExactEighteenthBirthdayIsEligible() {
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(2008, 9, 24)), .eligible)
    }

    func testDayBeforeEighteenthBirthdayIsUnderage() {
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(2008, 9, 25)), .underMinimumAge)
    }

    func testClearlyAdultAndClearlyUnderage() {
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(1970, 1, 1)), .eligible)
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(2015, 6, 1)), .underMinimumAge)
    }

    func testFutureDateIsRejected() {
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(2026, 9, 25)), .futureDate)
        XCTAssertEqual(check.evaluate(dateOfBirth: Fixture.date(2090, 1, 1)), .futureDate)
    }

    func testBornEarlierTodayIsUnderageNotFuture() {
        let reference = BirthdayEligibility(referenceDate: Fixture.date(2026, 9, 24, hour: 8), calendar: Fixture.utc)
        XCTAssertEqual(reference.evaluate(dateOfBirth: Fixture.date(2026, 9, 24, hour: 23)), .underMinimumAge)
    }

    func testTimeOfDayNeverDecidesTheResult() {
        let earlyMorning = BirthdayEligibility(
            referenceDate: Fixture.date(2026, 9, 24, hour: 0, minute: 0),
            calendar: Fixture.utc
        )
        XCTAssertEqual(earlyMorning.evaluate(dateOfBirth: Fixture.date(2008, 9, 24, hour: 23, minute: 59)), .eligible)

        let lateEvening = BirthdayEligibility(
            referenceDate: Fixture.date(2026, 9, 23, hour: 23, minute: 59),
            calendar: Fixture.utc
        )
        XCTAssertEqual(lateEvening.evaluate(dateOfBirth: Fixture.date(2008, 9, 24, hour: 0, minute: 0)), .underMinimumAge)
    }

    /// Documented rule: a 29 February birthday reaches 18 on 1 March, because 18 years
    /// after a leap year is never itself a leap year in the Gregorian calendar.
    func testLeapDayBirthdayBecomesEligibleOnFirstOfMarch() {
        let leapDay = Fixture.date(2008, 2, 29)
        let onTwentyEighth = BirthdayEligibility(referenceDate: Fixture.date(2026, 2, 28), calendar: Fixture.utc)
        let onFirstOfMarch = BirthdayEligibility(referenceDate: Fixture.date(2026, 3, 1), calendar: Fixture.utc)

        XCTAssertEqual(onTwentyEighth.evaluate(dateOfBirth: leapDay), .underMinimumAge)
        XCTAssertEqual(onFirstOfMarch.evaluate(dateOfBirth: leapDay), .eligible)
    }

    func testTwentyEighthOfFebruaryBirthdayIsUnaffectedByLeapRule() {
        let onTwentyEighth = BirthdayEligibility(referenceDate: Fixture.date(2026, 2, 28), calendar: Fixture.utc)
        XCTAssertEqual(onTwentyEighth.evaluate(dateOfBirth: Fixture.date(2008, 2, 28)), .eligible)
    }

    func testInjectedReferenceDateDecidesNotTheClock() {
        let in1990 = BirthdayEligibility(referenceDate: Fixture.date(1990, 6, 1), calendar: Fixture.utc)
        // Adult by the real clock, but not on the injected date.
        XCTAssertEqual(in1990.evaluate(dateOfBirth: Fixture.date(1980, 1, 1)), .underMinimumAge)
        XCTAssertEqual(in1990.evaluate(dateOfBirth: Fixture.date(1972, 5, 31)), .eligible)
        // In the past by the real clock, but in the future of the injected date.
        XCTAssertEqual(in1990.evaluate(dateOfBirth: Fixture.date(2000, 1, 1)), .futureDate)
    }

    func testInjectedTimeZoneDecidesWhichDayAnInstantIsOn() {
        let reference = Fixture.date(2026, 9, 24, hour: 5)   // 15:00 on the 24th at UTC+10
        let birth = Fixture.date(2008, 9, 24, hour: 20)      // 06:00 on the 25th at UTC+10

        let inUTC = BirthdayEligibility(referenceDate: reference, calendar: Fixture.utc)
        let inUTCPlus10 = BirthdayEligibility(
            referenceDate: reference,
            calendar: Fixture.calendar(secondsFromGMT: 10 * 3600)
        )

        XCTAssertEqual(inUTC.evaluate(dateOfBirth: birth), .eligible)
        XCTAssertEqual(inUTCPlus10.evaluate(dateOfBirth: birth), .underMinimumAge)
    }

    func testNonGregorianCalendarIsNormalisedToGregorian() {
        for identifier in [Calendar.Identifier.japanese, .buddhist] {
            let eligibility = BirthdayEligibility(
                referenceDate: Fixture.date(2026, 9, 24),
                calendar: Fixture.calendar(identifier, secondsFromGMT: 0)
            )
            XCTAssertEqual(eligibility.calendar.identifier, .gregorian, "\(identifier)")
            XCTAssertEqual(eligibility.calendar.timeZone.secondsFromGMT(), 0, "\(identifier)")
            XCTAssertEqual(eligibility.evaluate(dateOfBirth: Fixture.date(2008, 9, 24)), .eligible, "\(identifier)")
            XCTAssertEqual(eligibility.evaluate(dateOfBirth: Fixture.date(2008, 9, 25)), .underMinimumAge, "\(identifier)")
            XCTAssertEqual(eligibility.evaluate(dateOfBirth: Fixture.date(2026, 9, 25)), .futureDate, "\(identifier)")
        }
    }
}
