import XCTest
import ProximeetDomain

final class GuestProfileTests: XCTestCase {
    private func issues(_ firstName: String, _ interests: [String]) -> [ProfileIssue] {
        switch GuestProfile.validated(firstName: firstName, interests: interests) {
        case .success:
            return []
        case .failure(let error):
            return error.issues
        }
    }

    func testValidProfileIsTrimmedAndWhitespaceCollapsed() throws {
        let profile = try GuestProfile.validated(
            firstName: "  Fixture \n",
            interests: ["\tBouldering ", "Film   photography", " Board\ngames"]
        ).get()

        XCTAssertEqual(profile.firstName, "Fixture")
        XCTAssertEqual(profile.interests, ["Bouldering", "Film photography", "Board games"])
    }

    func testBlankFirstNameIsRejected() {
        XCTAssertEqual(issues("", Fixture.interests), [.firstNameMissing])
        XCTAssertEqual(issues("   \n\t", Fixture.interests), [.firstNameMissing])
    }

    func testInvisibleOnlyValuesCountAsBlank() {
        XCTAssertEqual(issues("\u{200B}\u{FEFF}", Fixture.interests), [.firstNameMissing])
        XCTAssertEqual(issues(Fixture.firstName, ["Jazz", "\u{2060}", "Chess"]), [.interestMissing(index: 1)])
    }

    func testInvisibleCharactersCannotDisguiseADuplicate() {
        XCTAssertEqual(
            issues(Fixture.firstName, ["Jazz", "Ja\u{200B}zz", "Chess"]),
            [.duplicateInterest(index: 1, duplicateOf: 0)]
        )
    }

    func testJoinersInsideVisibleTextAreKept() throws {
        let profile = try GuestProfile.validated(
            firstName: "Fixture",
            interests: ["👩‍💻 Coding", "می‌خواهم", "Chess"]
        ).get()
        XCTAssertEqual(profile.interests[0], "👩‍💻 Coding")
        XCTAssertEqual(profile.interests[1], "می‌خواهم")
    }

    func testFirstNameLengthLimitCountsCharactersAfterTrimming() {
        let atLimit = String(repeating: "a", count: GuestProfile.firstNameCharacterLimit)
        XCTAssertEqual(issues("  \(atLimit)  ", Fixture.interests), [])
        XCTAssertEqual(
            issues(atLimit + "a", Fixture.interests),
            [.firstNameTooLong(limit: GuestProfile.firstNameCharacterLimit)]
        )
    }

    func testExactlyThreeInterestsAreRequired() {
        XCTAssertEqual(
            issues(Fixture.firstName, ["Jazz", "Chess"]),
            [.wrongInterestCount(expected: 3, actual: 2)]
        )
        XCTAssertEqual(
            issues(Fixture.firstName, ["Jazz", "Chess", "Tennis", "Cooking"]),
            [.wrongInterestCount(expected: 3, actual: 4)]
        )
        XCTAssertEqual(
            issues(Fixture.firstName, []),
            [.wrongInterestCount(expected: 3, actual: 0)]
        )
    }

    func testBlankInterestIsRejectedByPosition() {
        XCTAssertEqual(issues(Fixture.firstName, ["Jazz", "  ", "Chess"]), [.interestMissing(index: 1)])
    }

    func testInterestsMustBeDistinctIgnoringCaseAndSpacing() {
        XCTAssertEqual(
            issues(Fixture.firstName, ["Board games", "Jazz", "  board   GAMES "]),
            [.duplicateInterest(index: 2, duplicateOf: 0)]
        )
    }

    func testInterestLengthLimit() {
        let tooLong = String(repeating: "b", count: GuestProfile.interestCharacterLimit + 1)
        XCTAssertEqual(
            issues(Fixture.firstName, ["Jazz", tooLong, "Chess"]),
            [.interestTooLong(index: 1, limit: GuestProfile.interestCharacterLimit)]
        )
    }

    func testAllIssuesAreReportedTogetherInFieldOrder() {
        XCTAssertEqual(
            issues(" ", ["Jazz", "", "jazz"]),
            [.firstNameMissing, .interestMissing(index: 1), .duplicateInterest(index: 2, duplicateOf: 0)]
        )
    }

    func testEveryIssueHasReadableMessage() {
        let all: [ProfileIssue] = [
            .firstNameMissing,
            .firstNameTooLong(limit: 30),
            .wrongInterestCount(expected: 3, actual: 1),
            .interestMissing(index: 0),
            .interestTooLong(index: 2, limit: 30),
            .duplicateInterest(index: 2, duplicateOf: 0),
        ]
        for issue in all {
            XCTAssertFalse(issue.message.isEmpty, "\(issue)")
        }
        XCTAssertEqual(ProfileIssue.interestMissing(index: 0).message, "Enter interest 1.")
    }
}
