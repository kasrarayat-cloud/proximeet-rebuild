import Foundation
import XCTest
import ProximeetDomain

final class DemoFlowTests: XCTestCase {

    // MARK: - Start and gating

    func testStartsAtWelcomeWithNothingEntered() {
        let flow = DemoFlow()
        XCTAssertEqual(flow.currentScene, .welcome)
        XCTAssertEqual(flow.path, [])
        XCTAssertEqual(flow.draft, DemoDraft())
        XCTAssertNil(flow.readiness)
    }

    func testFullJourneyVisitsEverySceneInOrder() {
        let flow = Fixture.flow(at: .readyForCheckIn)
        XCTAssertEqual(flow.path, [.birthday, .demoPass, .guestList, .band, .signal, .readyForCheckIn])
    }

    func testForwardActionsAreRejectedOutsideTheirScene() {
        var flow = DemoFlow()
        let before = flow

        XCTAssertNil(flow.submitBirthday(Fixture.adultBirthday, using: Fixture.eligibility))
        XCTAssertFalse(flow.continueFromPass())
        XCTAssertEqual(flow.saveProfile(firstName: Fixture.firstName, interests: Fixture.interests), .unavailable)
        XCTAssertFalse(flow.continueFromGuestList())
        XCTAssertFalse(flow.selectBand(.social))
        XCTAssertFalse(flow.confirmBand())
        XCTAssertFalse(flow.selectSignal(.okayToSayHello))
        XCTAssertFalse(flow.confirmSignal())
        XCTAssertEqual(flow, before, "Rejected actions must not change any state")

        var atBand = Fixture.flow(at: .band)
        let bandBefore = atBand
        XCTAssertFalse(atBand.selectSignal(.okayToSayHello))
        XCTAssertFalse(atBand.confirmSignal())
        XCTAssertEqual(atBand.saveProfile(firstName: "Other", interests: ["A", "B", "C"]), .unavailable)
        XCTAssertEqual(atBand, bandBefore)
    }

    func testBirthdayMustBeSubmittedAndEligibleToReachThePass() {
        var flow = Fixture.flow(at: .birthday)
        XCTAssertFalse(flow.continueFromPass(), "No birthday entered yet")

        XCTAssertEqual(flow.submitBirthday(Fixture.futureBirthday, using: Fixture.eligibility), .futureDate)
        XCTAssertEqual(flow.path, [.birthday])
        XCTAssertNil(flow.draft.dateOfBirth)

        XCTAssertEqual(flow.submitBirthday(Fixture.underageBirthday, using: Fixture.eligibility), .underMinimumAge)
        XCTAssertEqual(flow.path, [.birthday])
        XCTAssertNil(flow.draft.dateOfBirth)

        let eighteenToday = Fixture.date(2008, 9, 24)
        XCTAssertEqual(flow.submitBirthday(eighteenToday, using: Fixture.eligibility), .eligible)
        XCTAssertEqual(flow.currentScene, .demoPass)
        XCTAssertEqual(flow.draft.dateOfBirth, eighteenToday)
    }

    func testUnderageResultAfterEarlierAcceptanceClearsTheWholeDraft() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        XCTAssertTrue(flow.returnTo(.birthday))

        XCTAssertEqual(flow.submitBirthday(Fixture.underageBirthday, using: Fixture.eligibility), .underMinimumAge)
        XCTAssertEqual(flow.draft, DemoDraft())
        XCTAssertEqual(flow.path, [.birthday])
    }

    func testFutureDateAfterEarlierAcceptanceClearsTheStoredBirthday() {
        var flow = Fixture.flow(at: .band)
        XCTAssertTrue(flow.returnTo(.birthday))

        XCTAssertEqual(flow.submitBirthday(Fixture.futureBirthday, using: Fixture.eligibility), .futureDate)
        XCTAssertNil(flow.draft.dateOfBirth)
        XCTAssertFalse(flow.draft.meetsRequirements(for: .demoPass))
        XCTAssertEqual(flow.path, [.birthday])
    }

    func testGuestListRequiresAValidProfileBeforeContinuing() {
        var flow = Fixture.flow(at: .guestList)
        XCTAssertFalse(flow.continueFromGuestList(), "No profile yet")

        let outcome = flow.saveProfile(firstName: "  ", interests: ["Jazz", "Jazz", ""])
        guard case .invalid(let error) = outcome else {
            return XCTFail("Expected invalid outcome, got \(outcome)")
        }
        XCTAssertEqual(error.issues.first, .firstNameMissing)
        XCTAssertNil(flow.draft.profile)
        XCTAssertFalse(flow.continueFromGuestList())
        XCTAssertEqual(flow.currentScene, .guestList)

        guard case .saved(let profile) = flow.saveProfile(firstName: " Fixture ", interests: Fixture.interests) else {
            return XCTFail("Expected a saved profile")
        }
        XCTAssertEqual(profile.firstName, "Fixture")
        XCTAssertEqual(flow.draft.profile, profile)
        XCTAssertTrue(flow.continueFromGuestList())
        XCTAssertEqual(flow.currentScene, .band)
    }

    func testBandCannotBeConfirmedWithoutASelection() {
        var flow = Fixture.flow(at: .band)
        XCTAssertFalse(flow.confirmBand())
        XCTAssertEqual(flow.currentScene, .band)
    }

    func testSignalCannotBeConfirmedWithoutASelection() {
        var flow = Fixture.flow(at: .signal)
        XCTAssertFalse(flow.confirmSignal())
        XCTAssertEqual(flow.currentScene, .signal)
        XCTAssertNil(flow.readiness)
    }

    // MARK: - Choices

    func testEveryBandAndSignalCombinationSurvivesConfirmation() {
        for band in BandIntent.allCases {
            for signal in ApproachSignal.allCases {
                let flow = Fixture.flow(at: .readyForCheckIn, band: band, signal: signal)
                XCTAssertEqual(flow.readiness?.band, band, "\(band) / \(signal)")
                XCTAssertEqual(flow.readiness?.signal, signal, "\(band) / \(signal)")
            }
        }
        XCTAssertEqual(BandIntent.allCases.count, 4)
        XCTAssertEqual(ApproachSignal.allCases.count, 2)
    }

    func testRepeatedSelectionsKeepOnlyTheLatestChoice() {
        var flow = Fixture.flow(at: .band)
        for band in [BandIntent.social, .dating, .business, .activity, .dating] {
            XCTAssertTrue(flow.selectBand(band))
        }
        XCTAssertEqual(flow.draft.band, .dating)
        XCTAssertTrue(flow.confirmBand())

        for signal in [ApproachSignal.okayToSayHello, .chatFirst, .okayToSayHello] {
            XCTAssertTrue(flow.selectSignal(signal))
        }
        XCTAssertEqual(flow.draft.signal, .okayToSayHello)
        XCTAssertTrue(flow.confirmSignal())

        XCTAssertEqual(flow.readiness?.band, .dating)
        XCTAssertEqual(flow.readiness?.signal, .okayToSayHello)
    }

    func testRepeatedConfirmationDoesNotAdvanceTwice() {
        var flow = Fixture.flow(at: .band)
        flow.selectBand(.business)
        XCTAssertTrue(flow.confirmBand())
        XCTAssertFalse(flow.confirmBand())
        flow.selectSignal(.chatFirst)
        XCTAssertTrue(flow.confirmSignal())
        XCTAssertFalse(flow.confirmSignal())
        XCTAssertFalse(flow.begin())
        XCTAssertEqual(flow.path.count, 6)
    }

    // MARK: - Back navigation and edits

    func testBackNavigationRetainsTheDraftAtEveryStep() {
        var flow = Fixture.flow(at: .readyForCheckIn, band: .activity, signal: .okayToSayHello)
        let completeDraft = flow.draft

        while flow.currentScene != .welcome {
            XCTAssertTrue(flow.goBack())
            XCTAssertEqual(flow.draft, completeDraft, "Draft changed after going back to \(flow.currentScene)")
        }
        XCTAssertFalse(flow.goBack())

        // Going forward again reuses the retained values; nothing needs re-selecting.
        XCTAssertTrue(flow.begin())
        guard let storedBirthday = flow.draft.dateOfBirth else {
            return XCTFail("Birthday was not retained for the birthday screen")
        }
        XCTAssertEqual(flow.submitBirthday(storedBirthday, using: Fixture.eligibility), .eligible)
        XCTAssertTrue(flow.continueFromPass())
        XCTAssertTrue(flow.continueFromGuestList())
        XCTAssertTrue(flow.confirmBand())
        XCTAssertTrue(flow.confirmSignal())
        XCTAssertEqual(flow.readiness?.band, .activity)
        XCTAssertEqual(flow.readiness?.signal, .okayToSayHello)
        XCTAssertEqual(flow.readiness?.profile.firstName, Fixture.firstName)
    }

    func testReturningToAnEarlierSceneWithdrawsReadinessUntilReconfirmed() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        XCTAssertTrue(flow.returnTo(.band))
        XCTAssertEqual(flow.path.last, .band)
        XCTAssertNil(flow.readiness, "Readiness must not be claimed off the ready scene")
        XCTAssertEqual(flow.draft.band, .social, "Existing choice is kept for editing")
        XCTAssertEqual(flow.draft.signal, .chatFirst)

        XCTAssertFalse(flow.returnTo(.readyForCheckIn), "Cannot jump forward to a popped scene")
    }

    func testBandEditAppearsInSummary() {
        var flow = Fixture.flow(at: .readyForCheckIn, band: .social, signal: .okayToSayHello)
        XCTAssertTrue(flow.returnTo(.band))
        XCTAssertTrue(flow.selectBand(.business))
        XCTAssertTrue(flow.confirmBand())
        XCTAssertEqual(flow.draft.signal, .okayToSayHello, "Signal is retained through a band edit")
        XCTAssertTrue(flow.confirmSignal())

        XCTAssertEqual(flow.readiness?.band, .business)
        XCTAssertEqual(flow.readiness?.signal, .okayToSayHello)
    }

    func testSignalEditAppearsInSummary() {
        var flow = Fixture.flow(at: .readyForCheckIn, band: .dating, signal: .okayToSayHello)
        XCTAssertTrue(flow.returnTo(.signal))
        XCTAssertTrue(flow.selectSignal(.chatFirst))
        XCTAssertTrue(flow.confirmSignal())

        XCTAssertEqual(flow.readiness?.band, .dating)
        XCTAssertEqual(flow.readiness?.signal, .chatFirst)
    }

    func testProfileEditOnSummaryAppearsImmediately() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        let outcome = flow.saveProfile(firstName: "Sample", interests: ["Pottery", "Salsa", "Chess"])
        guard case .saved = outcome else { return XCTFail("Expected saved, got \(outcome)") }

        XCTAssertEqual(flow.currentScene, .readyForCheckIn)
        XCTAssertEqual(flow.readiness?.profile.firstName, "Sample")
        XCTAssertEqual(flow.readiness?.profile.interests, ["Pottery", "Salsa", "Chess"])
    }

    func testProfileEditOnGuestListReachesSummary() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        XCTAssertTrue(flow.returnTo(.guestList))
        XCTAssertEqual(flow.saveProfile(firstName: "Sample", interests: ["Pottery", "Salsa", "Chess"]).isSaved, true)
        XCTAssertTrue(flow.continueFromGuestList())
        XCTAssertTrue(flow.confirmBand())
        XCTAssertTrue(flow.confirmSignal())
        XCTAssertEqual(flow.readiness?.profile.firstName, "Sample")
    }

    func testInvalidProfileEditOnSummaryKeepsTheLastValidProfile() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        let valid = flow.readiness?.profile

        let outcome = flow.saveProfile(firstName: "", interests: ["Pottery", "pottery", " "])
        guard case .invalid = outcome else { return XCTFail("Expected invalid, got \(outcome)") }

        XCTAssertEqual(flow.currentScene, .readyForCheckIn)
        XCTAssertEqual(flow.readiness?.profile, valid)
        XCTAssertEqual(flow.readiness?.profile.firstName, Fixture.firstName)
        XCTAssertEqual(flow.readiness?.profile.interests, Fixture.interests)
    }

    func testNavigationCanOnlyPopNeverSkipOrRewrite() {
        var flow = Fixture.flow(at: .guestList)
        let before = flow

        XCTAssertFalse(flow.adoptNavigationPath([.birthday, .demoPass, .guestList, .band]), "Push past validation")
        XCTAssertFalse(flow.adoptNavigationPath([.birthday, .guestList]), "Rewritten history")
        XCTAssertFalse(flow.adoptNavigationPath([.band]), "Unrelated path")
        XCTAssertFalse(flow.returnTo(.signal), "Scene not on the path")
        XCTAssertEqual(flow, before)

        XCTAssertTrue(flow.adoptNavigationPath([.birthday]))
        XCTAssertEqual(flow.currentScene, .birthday)
        XCTAssertEqual(flow.draft, before.draft)

        XCTAssertTrue(flow.returnTo(.welcome))
        XCTAssertEqual(flow.path, [])
        XCTAssertEqual(flow.draft, before.draft)
    }

    // MARK: - Reset

    func testResetFromEverySceneClearsAllPersonalDataAndSelections() {
        for scene in DemoScene.allCases {
            var flow = Fixture.flow(at: scene)
            flow.reset()
            XCTAssertEqual(flow, DemoFlow(), "Reset from \(scene)")
            XCTAssertNil(flow.draft.dateOfBirth)
            XCTAssertNil(flow.draft.profile)
            XCTAssertNil(flow.draft.band)
            XCTAssertNil(flow.draft.signal)
            XCTAssertNil(flow.readiness)
        }
    }

    func testAfterResetEveryStepNeedsFreshInput() {
        var flow = Fixture.flow(at: .readyForCheckIn)
        flow.reset()

        XCTAssertTrue(flow.begin())
        XCTAssertFalse(flow.continueFromPass())
        XCTAssertEqual(flow.submitBirthday(Fixture.adultBirthday, using: Fixture.eligibility), .eligible)
        XCTAssertTrue(flow.continueFromPass())
        XCTAssertFalse(flow.continueFromGuestList(), "Profile must be entered again")
        flow.saveProfile(firstName: Fixture.firstName, interests: Fixture.interests)
        XCTAssertTrue(flow.continueFromGuestList())
        XCTAssertFalse(flow.confirmBand(), "Band must be chosen again")
        flow.selectBand(.social)
        XCTAssertTrue(flow.confirmBand())
        XCTAssertFalse(flow.confirmSignal(), "Signal must be chosen again")
    }

    // MARK: - Honesty and side effects

    func testReadySummaryIsDemoOnlyAndEndsTheJourney() throws {
        var flow = Fixture.flow(at: .readyForCheckIn)
        let summary = try XCTUnwrap(flow.readiness)

        XCTAssertEqual(summary.passMark, .demo)
        XCTAssertEqual(summary.passMark.label, "DEMO")
        XCTAssertEqual(PassMark.allCases, [.demo], "A pass can only ever say DEMO")
        XCTAssertEqual(summary.visibility, .notVisibleToAnyone)
        XCTAssertEqual(summary.visibility.notice, "Demo — not visible to anyone")
        XCTAssertEqual(DraftVisibility.allCases, [.notVisibleToAnyone])
        XCTAssertNil(DemoScene.readyForCheckIn.next, "The legacy summary ends its branch")
        XCTAssertNil(DemoScene.placeExplanation.next, "Places ends at an explanation: no check-in, presence or Room")

        let before = flow
        XCTAssertFalse(flow.begin())
        XCTAssertFalse(flow.continueFromPass())
        XCTAssertFalse(flow.continueFromGuestList())
        XCTAssertFalse(flow.confirmBand())
        XCTAssertFalse(flow.confirmSignal())
        XCTAssertFalse(flow.selectBand(.dating))
        XCTAssertFalse(flow.selectSignal(.okayToSayHello))
        XCTAssertEqual(flow, before)
    }

    func testDraftStateHasNoPersistenceConformance() {
        XCTAssertFalse((DemoFlow.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((DemoFlow.self as Any.Type) is Decodable.Type)
        XCTAssertFalse((DemoDraft.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((DemoDraft.self as Any.Type) is Decodable.Type)
        XCTAssertFalse((GuestProfile.self as Any.Type) is Encodable.Type)
        XCTAssertFalse((ReadyForCheckIn.self as Any.Type) is Encodable.Type)
    }

    func testDomainCopyMakesNoVerificationPresenceOrAccountClaims() {
        var copy: [String] = []
        copy += BandIntent.allCases.flatMap { [$0.title, $0.summary] }
        copy += ApproachSignal.allCases.flatMap { [$0.title, $0.summary] }
        copy += [BirthdayCheck.eligible, .underMinimumAge, .futureDate].map(\.message)
        copy += DraftVisibility.allCases.map(\.notice)
        copy += PassMark.allCases.map(\.label)

        let forbidden = [
            "verified", "verify", "checked in", "nearby", "is here", "live now",
            "can see you", "visible to others", "signed in", "logged in", "account",
        ]
        for text in copy {
            for phrase in forbidden {
                XCTAssertFalse(text.lowercased().contains(phrase), "\"\(text)\" contains \"\(phrase)\"")
            }
        }
    }

    func testTransitionsAreImmediateAndRepeatable() {
        // Each action takes effect synchronously in the same call; there is no pending state.
        var flow = Fixture.flow(at: .band)
        flow.selectBand(.activity)
        XCTAssertEqual(flow.draft.band, .activity)
        XCTAssertTrue(flow.confirmBand())
        XCTAssertEqual(flow.currentScene, .signal)
        flow.selectSignal(.okayToSayHello)
        XCTAssertTrue(flow.confirmSignal())
        XCTAssertEqual(flow.currentScene, .readyForCheckIn)

        // The same inputs always give the same state, whenever they are applied.
        XCTAssertEqual(
            Fixture.flow(at: .readyForCheckIn, band: .activity, signal: .okayToSayHello),
            flow
        )
    }
}

private extension ProfileSaveOutcome {
    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }
}
