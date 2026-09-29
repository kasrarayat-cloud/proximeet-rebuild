import UIKit
import XCTest

/// Runtime review of the approved Room (chapter 08): a local, explicitly fictional demo of what a
/// venue room could feel like, opened only from Common Ground's check-in explanation. The real route:
/// Welcome → More options → "Continue the demo (no account)" → Birthday → Pass → Guest List (typed) →
/// Wristband → Signal → Continue preview → Places (Now) → View place → Preview check-in → the
/// explanation → Preview room demo (the entry, Figma 66:112) → Enter room demo (waiting, 66:113) →
/// Show populated example (People, 66:115).
///
/// Skipped unless the test runner's environment has `PROXIMEET_ROOM_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_ROOM_REVIEW=1` to xcodebuild). Real taps and real edge swipes. The one
/// recorded journey starts at Welcome and its captures start "room-journey-"; every other test starts
/// from a DEBUG fixture (`-ProximeetFixture room-entry | room-waiting | room-populated | room-ended`, a
/// direct launch that reaches the Room through the app's own transitions: the explanation, Preview
/// room demo, Enter room demo, Show populated example, and blocks through each sample's safety) and
/// its captures end in "-fixture".
///
/// What the Room must never do is checked in the accessibility tree as well as on screen: waiting and
/// ended show no sample person, initials, note or count; a blocked sample is absent everywhere, not
/// merely transparent; nothing is sent, submitted or confirmed; nothing but the two deliberate gates
/// moves a run forward. Every copy string is the approved `RoomCopy` (and `RoomActor`), written out
/// here rather than read from the app. The pixel checks run on the 440 × 956 iPhone at the default
/// text size only, where the approved board (`room-review.png`) fixes what is drawn where.
@MainActor
final class RoomReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_ROOM_REVIEW"
    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    private static let reduceMotionPreview = ["-ProximeetReduceMotionPreview", "YES"]
    private static let intentTitles = ["social": "Social", "dating": "Dating", "business": "Business", "activity": "Activity"]
    private static let approachTitles = ["chatFirst": "Chat first", "okayToSayHello": "Okay to say hello"]

    /// 44 pt, less floating-point error, for every 44-pt target check (build 6ab88011 measured a
    /// 44-pt Places tab as 43.99999999999997 once a fractional scroll offset had moved it).
    private static let minimumTarget: CGFloat = 44 - 1e-6

    /// The two fictional samples as approved (`RoomActor`; cards 67:146 / 67:170, profiles 67:154 /
    /// 67:178). Jules's own approach line reuses Signal's approved summary of "Okay to say hello".
    private static let maya = SampleActor(
        key: "maya", name: "Maya", initials: "ML", intent: "social", line: "Social · Chat first",
        introduction: "Coffee, bookshops, and a good detour.", quote: "Tell me about a place you’d go back to.",
        interests: ["Coffee", "Bookshops", "Detours"], approach: "Prefers a Wave and a chat before meeting.",
        note: nil
    )
    private static let jules = SampleActor(
        key: "jules", name: "Jules", initials: "JR", intent: "business", line: "Business · Okay to say hello",
        introduction: "Design, ideas, and small businesses.", quote: "Always curious about what people are building.",
        interests: ["Design", "Ideas", "Small business"], approach: "Open to a brief hello. No pressure to continue.",
        note: "One good question can change an evening."
    )
    private static let actors = [maya, jules]

    /// The three sample reasons of an unsent report (component set 67:856) and the variant each
    /// selection draws (67:826 Attention, 67:836 Harassment, 67:846 Other; 67:816 is none).
    private static let reasons = [
        ReportReason(key: "unwantedAttention", title: "Unwanted attention", variant: "attention"),
        ReportReason(key: "harassment", title: "Harassment or harmful content", variant: "harassment"),
        ReportReason(key: "somethingElse", title: "Something else", variant: "other"),
    ]

    private static func actor(_ key: String) -> SampleActor {
        key == jules.key ? jules : maya
    }

    /// "[Intent] · [Approach]": the actual guest's line on the venue ticket.
    private static func preference(_ band: String, _ approach: String) -> String {
        "\(intentTitles[band] ?? band) · \(approachTitles[approach] ?? approach)"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Room review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("ROOM_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough (full journey)

    /// Full journey, recorded: the real route from Welcome with a typed introduction, Social and
    /// Chat first; Places at Now; Common Ground's detail and its explanation, where the recording's trim
    /// starts (`ROOM_WALKTHROUGH_START`). Preview room demo: the entry, with the actual preference and
    /// nothing started. Enter room demo: waiting, with no sample anywhere in the tree. Show populated
    /// example: People; Room notes; Maya's profile; How Waves work and Back to profile; Maya's safety;
    /// Preview report, a reason, Close preview (her safety again) and Back (her profile); Block Maya in
    /// demo: the filtered People; Leave and disappear: the ended screen; Return to Places: browsing at
    /// Now; Back: Signal with the same intent and approach, so the draft was never touched.
    func testRealJourneyFromTheExplanationThroughTheRoomAndBack() throws {
        let app = launchWelcome()
        hold(0.8)
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = RoomGuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Alex")
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText("Up for coffee.")
        tapKeyboardDone(app)
        guest.coffee.tap()
        hold(0.4)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(0.4)
        guest.primary.tap()
        let band = RoomWristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("social").tap()
        XCTAssertTrue(waitFor(band.tile("social"), selected: true))
        hold(0.4)
        band.primary.tap()
        let signal = RoomSignal(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.row("chatFirst").tap()
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true))
        waitForLabel(signal.summary, "Social band · Chat first")
        hold(0.6)
        signal.primary.tap()

        // Places at Now, Common Ground's detail, its explanation.
        let places = RoomPlaces(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(waitFor(places.tab("now"), selected: true), "Places opens at Now.")
        waitForLabel(places.ticketName, "Common Ground")
        hold(0.6)
        places.viewPlace.tap()
        waitForLabel(places.placeName, "Common Ground")
        XCTAssertEqual(places.placePrimary.label, "Preview check-in")
        hold(0.6)
        places.placePrimary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        XCTAssertEqual(places.explanationPrimary.label, "Preview room demo", "The explanation's primary opens the Room demo.")
        // The recording's trim starts here, with the explanation showing and nothing tapped yet.
        print("ROOM_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        hold(1.5)
        capture("room-journey-01-explanation", app)

        // Preview room demo: the entry, with the actual preference; nothing started.
        let room = RoomUI(app: app)
        let preference = "Social · Chat first"
        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        XCTAssertTrue(waitForAbsence(places.explanationHeadline), "The explanation below is hidden from accessibility.")
        settle()
        assertEntry(room, preference: preference, "Journey entry")
        hold(1.5)
        capture("room-journey-02-entry", app)

        // Enter room demo: waiting, and no sample anywhere.
        enterRoom(room)
        assertWaiting(room, preference: preference, "Journey waiting")
        hold(1.8)
        capture("room-journey-03-waiting", app)

        // Show populated example: People.
        room.showPopulated.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10), "The labelled demo control reveals the sample.")
        settle()
        assertPeople(room, blocked: [], "Journey People")
        hold(1.5)
        capture("room-journey-04-people", app)

        // Room notes, then People again.
        selectTab("notes", room)
        assertNotes(room, blocked: [], "Journey Room notes")
        hold(1.5)
        capture("room-journey-05-room-notes", app)
        selectTab("people", room)
        hold(0.6)

        // Maya's profile; How Waves work; Back to profile.
        openProfile(Self.maya, room)
        assertProfile(room, Self.maya, userIntent: "social", "Journey Maya")
        hold(1.5)
        capture("room-journey-06-maya-profile", app)
        room.profileAction.tap()
        waitForPanel(Panel.waveInfo, room)
        assertWaveInfo(room, "Journey Wave information")
        hold(1.5)
        capture("room-journey-07-wave-info", app)
        room.inPanel(Panel.waveInfo, "roomPanel.backToProfile").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.waveInfo)), "Back to profile closes the Wave information.")
        waitForLabel(room.profileName, "Maya")
        hold(0.8)

        // Maya's safety; Preview report; a reason; Close preview (her safety); Back (her profile).
        room.profileSafety.tap()
        let safety = Panel.actorSafety("maya")
        waitForPanel(safety, room)
        assertActorSafety(room, Self.maya, "Journey Maya's safety")
        hold(1.2)
        capture("room-journey-08-maya-safety", app)
        room.inPanel(safety, "roomPanel.previewReport").tap()
        let report = Panel.report("maya")
        waitForPanel(report, room)
        assertReport(room, Self.maya, selected: nil, "Journey report, new")
        hold(1.2)
        capture("room-journey-09-report", app)
        selectReason("harassment", room)
        assertReport(room, Self.maya, selected: "harassment", "Journey report, a reason")
        hold(1.2)
        capture("room-journey-10-report-reason", app)
        room.inPanel(report, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(report)), "Close preview closes the report.")
        waitForPanel(safety, room)
        hold(0.8)
        room.inPanel(safety, "roomPanel.back").tap()
        XCTAssertTrue(waitForAbsence(room.element(safety)), "Back closes Maya's safety.")
        waitForLabel(room.profileName, "Maya")
        hold(0.8)

        // Block Maya in demo: the filtered People.
        block(Self.maya, from: .profile, room)
        assertPeople(room, blocked: ["maya"], "Journey, Maya blocked")
        hold(1.5)
        capture("room-journey-11-people-maya-blocked", app)

        // Leave and disappear: the ended screen.
        room.leave.tap()
        assertEnded(room, "Journey ended")
        hold(1.5)
        capture("room-journey-12-ended", app)

        // Return to Places: browsing at Now. Back: Signal, the draft intact.
        room.returnToPlaces.tap()
        assertPlacesNow(places, room, "Journey Return to Places")
        hold(1.2)
        capture("room-journey-13-places-now", app)
        XCTAssertEqual(places.secondary.label, "Back")
        places.secondary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        waitForLabel(signal.summary, "Social band · Chat first")
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true), "The approach is kept: the Room never wrote the draft.")
        hold(1.2)
        capture("room-journey-14-back-to-signal", app)
        print("ROOM_WALKTHROUGH_END \(Date().timeIntervalSince1970)")
    }

    // MARK: - The two deliberate gates

    /// Direct launch (fixture `place-explanation`, Social, Chat first). Preview room demo opens the
    /// entry and starts nothing (no waiting, tabs, cards, Safety or Leave); its Back returns to the
    /// explanation; opened again it is still the entry. Enter room demo: waiting. Then nothing but
    /// "Show populated example" reveals the sample: not three seconds of waiting, not taps on the
    /// envelope and the texts, not the global safety opened and closed, and not the app sent to the
    /// background and resumed.
    func testEntryNeedsBothDeliberateGates() throws {
        let app = launch(fixture: "place-explanation")
        let places = RoomPlaces(app: app)
        let room = RoomUI(app: app)
        let preference = "Social · Chat first"
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        XCTAssertEqual(places.explanationPrimary.label, "Preview room demo")
        XCTAssertFalse(room.screen.exists, "No Room before Preview room demo.")

        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        settle()
        assertEntry(room, preference: preference, "The entry, opened")
        capture("room-gates-entry-fixture", app)

        room.entryBack.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        XCTAssertTrue(waitForAbsence(room.screen), "The entry's Back closes the Room.")
        XCTAssertEqual(places.explanationPrimary.label, "Preview room demo", "The explanation is still eligible.")
        capture("room-gates-entry-back-to-explanation-fixture", app)

        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        settle()
        assertEntry(room, preference: preference, "The entry, opened again")

        enterRoom(room)
        assertWaiting(room, preference: preference, "Waiting, just entered")

        // Time: nothing moves on its own.
        waitQuietly(3)
        assertStillWaiting(room, "Waiting, three seconds later")

        // Taps on everything that is not the demo control.
        for element in [room.envelope, room.waitingHeadline, room.waitingExplanation, room.demoControl] {
            XCTAssertTrue(element.exists)
            element.tap()
            waitQuietly(0.5)
        }
        settle()
        assertStillWaiting(room, "Waiting, after taps on the envelope and the texts")

        // The global safety, opened and closed.
        room.safety.tap()
        waitForPanel(Panel.globalSafety, room)
        assertGlobalSafety(room, "Waiting's safety")
        room.inPanel(Panel.globalSafety, "roomPanel.close").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.globalSafety)), "Close returns to waiting.")
        settle()
        assertStillWaiting(room, "Waiting, after Safety and Close")

        // The background, and back.
        XCUIDevice.shared.press(.home)
        waitQuietly(2)
        app.activate()
        XCTAssertTrue(room.waitingHeadline.waitForExistence(timeout: 15), "Waiting is showing after the resume.")
        settle()
        assertStillWaiting(room, "Waiting, after the background and a resume")
        capture("room-gates-waiting-after-resume-fixture", app)

        // Only the labelled demo control reveals the sample.
        XCTAssertEqual(room.showPopulated.label, RoomText.showPopulated)
        room.showPopulated.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10), "Show populated example reveals the sample.")
        settle()
        assertPeople(room, blocked: [], "People, from the demo control")
        capture("room-gates-populated-fixture", app)
    }

    // MARK: - Compatibility with the actual intent

    /// Direct launches (fixture `room-populated`, Social; once with Chat first and once with Okay to
    /// say hello). The venue ticket carries the actual preference. Maya shares the Social intent: her
    /// profile's line is her own approach and its action is How Waves work, whose information panel
    /// (66:134) returns to her profile. Jules is Business: his profile says "Waves stay within your
    /// selected intent." and its action is Back to people. The approach never changes either action.
    func testSocialCompatibilityAndBothApproaches() throws {
        for approach in ["chatFirst", "okayToSayHello"] {
            let app = launchRoom(.populated, band: "social", approach: approach)
            let room = RoomUI(app: app)
            let key = "social-\(approach)"
            XCTAssertTrue(room.card("maya").waitForExistence(timeout: 15), "\(key): the populated example.")
            settle()
            assertVenue(room, preference: Self.preference("social", approach), key)
            assertPeople(room, blocked: [], "\(key), People")
            checkSameIntent(Self.maya, room, userIntent: "social", named: key)
            checkOtherIntent(Self.jules, room, userIntent: "social", named: key)
            app.terminate()
        }
    }

    /// Direct launch (fixture `room-populated`, Business, Okay to say hello): the mirror image. Jules
    /// shares the Business intent: How Waves work, and his line "Open to a brief hello. No pressure to
    /// continue."; Maya is Social: Back to people, and the same-intent explanation.
    func testBusinessCompatibility() throws {
        let app = launchRoom(.populated, band: "business", approach: "okayToSayHello")
        let room = RoomUI(app: app)
        let key = "business-okayToSayHello"
        XCTAssertTrue(room.card("jules").waitForExistence(timeout: 15), "\(key): the populated example.")
        settle()
        assertVenue(room, preference: "Business · Okay to say hello", key)
        assertPeople(room, blocked: [], "\(key), People")
        checkSameIntent(Self.jules, room, userIntent: "business", named: key)
        checkOtherIntent(Self.maya, room, userIntent: "business", named: key)
    }

    // MARK: - Notes and blocks

    /// Direct launches (fixture `room-populated`, Social, Chat first), blocking through the real
    /// controls. First Maya (her profile's Safety) then Jules (the "…" on his public note); then, after
    /// a relaunch, Jules (his profile's Safety) then Maya. After each block: the filtered People
    /// (66:119 / 66:122 / 66:125) and Room notes (66:120 / 66:123 / 66:126), with the blocked sample
    /// absent from the tree and from the screen, the host notes kept, the right boundary lines, and,
    /// with both blocked, "No sample introductions to show." and never a claim that the room is empty.
    /// The blocks survive the tabs, a profile's Back, a closed report preview and the global safety.
    func testNotesFilteringAndBothBlockOrders() throws {
        var app = launchRoom(.populated)
        var room = RoomUI(app: app)
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 15))
        settle()
        assertPeople(room, blocked: [], "Before any block")
        selectTab("notes", room)
        assertNotes(room, blocked: [], "Room notes before any block")
        selectTab("people", room)

        block(Self.maya, from: .profile, room)
        assertAfterBlock(room, blocked: ["maya"], named: "maya-first")
        assertBlocksSurvive(room, blocked: ["maya"], "Maya blocked")
        block(Self.jules, from: .note, room)
        assertAfterBlock(room, blocked: ["maya", "jules"], named: "maya-then-jules")
        assertBlocksSurvive(room, blocked: ["maya", "jules"], "Maya, then Jules blocked")
        app.terminate()

        app = launchRoom(.populated)
        room = RoomUI(app: app)
        XCTAssertTrue(room.card("jules").waitForExistence(timeout: 15))
        settle()
        block(Self.jules, from: .profile, room)
        assertAfterBlock(room, blocked: ["jules"], named: "jules-first")
        assertBlocksSurvive(room, blocked: ["jules"], "Jules blocked")
        block(Self.maya, from: .profile, room)
        assertAfterBlock(room, blocked: ["maya", "jules"], named: "jules-then-maya")
        assertBlocksSurvive(room, blocked: ["maya", "jules"], "Jules, then Maya blocked")
    }

    // MARK: - The unsent report

    /// Direct launch (fixture `room-populated`, Social, Chat first). Maya's report preview (66:132)
    /// opens with nothing selected; a reason is selected, another replaces it, the selected one again
    /// changes nothing and there is no deselect; a tap on the dim does nothing. Close preview returns to
    /// Maya's safety and a new preview starts unselected; Back returns to her profile. Jules's report
    /// starts unselected, and Maya's again after that. From Room notes, the note's safety and its report
    /// return to Room notes. Nothing anywhere is named Send, Submit or Sent.
    func testReportPreviewIsLocalAndRestoresItsCaller() throws {
        let app = launchRoom(.populated)
        let room = RoomUI(app: app)
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 15))
        settle()

        openProfile(Self.maya, room)
        room.profileSafety.tap()
        let mayaSafety = Panel.actorSafety("maya")
        waitForPanel(mayaSafety, room)
        room.inPanel(mayaSafety, "roomPanel.previewReport").tap()
        let mayaReport = Panel.report("maya")
        waitForPanel(mayaReport, room)
        assertReport(room, Self.maya, selected: nil, "Maya's report, new")

        selectReason("unwantedAttention", room)
        assertReport(room, Self.maya, selected: "unwantedAttention", "Maya's report, a reason")
        selectReason("harassment", room)
        assertReport(room, Self.maya, selected: "harassment", "Maya's report, another reason replaces it")
        room.reason("harassment").tap()
        settle()
        assertReport(room, Self.maya, selected: "harassment", "Maya's report, the selected reason again: no change, no deselect")
        capture("room-report-local-selected-fixture", app)

        tapDim(outside: room.element(mayaReport), app)
        settle()
        XCTAssertTrue(room.element(mayaReport).exists, "A tap on the dim does nothing: the report stays.")
        XCTAssertFalse(room.endedStatus.exists, "A tap on the dim reaches nothing below it.")
        assertReport(room, Self.maya, selected: "harassment", "Maya's report, after a tap on the dim")

        room.inPanel(mayaReport, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(mayaReport)), "Close preview closes the report.")
        waitForPanel(mayaSafety, room)
        assertActorSafety(room, Self.maya, "Close preview: Maya's safety")
        room.inPanel(mayaSafety, "roomPanel.previewReport").tap()
        waitForPanel(mayaReport, room)
        assertReport(room, Self.maya, selected: nil, "Maya's report, reopened: a new preview")
        room.inPanel(mayaReport, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(mayaReport)))
        waitForPanel(mayaSafety, room)
        room.inPanel(mayaSafety, "roomPanel.back").tap()
        XCTAssertTrue(waitForAbsence(room.element(mayaSafety)), "Back closes Maya's safety.")
        assertProfile(room, Self.maya, userIntent: "social", "Back: Maya's profile")
        room.profileBack.tap()
        XCTAssertTrue(room.card("jules").waitForExistence(timeout: 10))
        settle()

        // Another sample's report starts unselected.
        openProfile(Self.jules, room)
        room.profileSafety.tap()
        let julesSafety = Panel.actorSafety("jules")
        waitForPanel(julesSafety, room)
        room.inPanel(julesSafety, "roomPanel.previewReport").tap()
        let julesReport = Panel.report("jules")
        waitForPanel(julesReport, room)
        assertReport(room, Self.jules, selected: nil, "Jules's report, new")
        selectReason("somethingElse", room)
        assertReport(room, Self.jules, selected: "somethingElse", "Jules's report, a reason")
        room.inPanel(julesReport, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(julesReport)))
        waitForPanel(julesSafety, room)
        room.inPanel(julesSafety, "roomPanel.back").tap()
        XCTAssertTrue(waitForAbsence(room.element(julesSafety)))
        assertProfile(room, Self.jules, userIntent: "social", "Back: Jules's profile")
        room.profileBack.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10))
        settle()

        // Maya's again: the earlier selection was local to its preview.
        openProfile(Self.maya, room)
        room.profileSafety.tap()
        waitForPanel(mayaSafety, room)
        room.inPanel(mayaSafety, "roomPanel.previewReport").tap()
        waitForPanel(mayaReport, room)
        assertReport(room, Self.maya, selected: nil, "Maya's report, after Jules's")
        room.inPanel(mayaReport, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(mayaReport)))
        waitForPanel(mayaSafety, room)
        room.inPanel(mayaSafety, "roomPanel.back").tap()
        XCTAssertTrue(waitForAbsence(room.element(mayaSafety)))
        waitForLabel(room.profileName, "Maya")
        room.profileBack.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10))
        settle()

        // From Room notes: the note's safety, its report, and back to Room notes.
        selectTab("notes", room)
        tapRevealed(room.julesNoteMore, room)
        waitForPanel(julesSafety, room)
        assertActorSafety(room, Self.jules, "Jules's note safety")
        room.inPanel(julesSafety, "roomPanel.previewReport").tap()
        waitForPanel(julesReport, room)
        assertReport(room, Self.jules, selected: nil, "Jules's report from his note, new")
        selectReason("unwantedAttention", room)
        capture("room-report-from-note-fixture", app)
        room.inPanel(julesReport, "roomPanel.closePreview").tap()
        XCTAssertTrue(waitForAbsence(room.element(julesReport)))
        waitForPanel(julesSafety, room)
        room.inPanel(julesSafety, "roomPanel.back").tap()
        XCTAssertTrue(waitForAbsence(room.element(julesSafety)), "Back closes the note's safety.")
        XCTAssertTrue(waitFor(room.tab("notes"), selected: true), "The note's safety returns to Room notes.")
        settle()
        assertNotes(room, blocked: [], "Room notes, after the note's report")
        assertNothingSubmits(readTree(app), "After every report preview")
    }

    // MARK: - Leave

    /// Direct launches, one per context: waiting, waiting's global safety, People, People's global
    /// safety, Room notes, a profile, Wave information, an actor's safety, a report preview with a
    /// reason, and a public note's safety. Each time the visible "Leave and disappear" ends the run at
    /// once, with no confirmation: the ended screen (66:114) and no sample, note, profile or panel
    /// anywhere in the tree. Return to Places then lands on browsing at Now.
    func testLeaveFromEveryContext() throws {
        var table: [String] = []
        for context in Self.leaveContexts {
            let app = launchRoom(context)
            let room = RoomUI(app: app)
            let places = RoomPlaces(app: app)
            XCTAssertTrue(readyElement(context.shown, room).waitForExistence(timeout: 15), "\(context.key) shows.")
            settle()
            assertShown(context.shown, room, "Leave from \(context.key), before")
            let leave = leaveButton(for: context.shown, room)
            XCTAssertEqual(leave.label, RoomText.leave, "\(context.key): the visible Leave.")
            leave.tap()
            assertEnded(room, "Left from \(context.key)")
            capture("room-leave-from-\(context.key)-fixture", app)
            room.returnToPlaces.tap()
            assertPlacesNow(places, room, "Return to Places after leaving from \(context.key)")
            table.append("\(context.key): ended, then Places at Now")
            app.terminate()
        }
        attachNote("Leave and disappear, per context: " + table.joined(separator: "; ") + ".")
    }

    // MARK: - Back gestures

    /// Real edge swipes (the Places back gesture, which the Room routes as its outer Back). From the
    /// entry (fixture `place-explanation`, then Preview room demo): a cancelled swipe stays, a completed
    /// one returns to the explanation. From waiting: a cancelled swipe changes nothing, a completed one
    /// is the terminal Leave (the ended screen). From the ended screen: a cancelled swipe stays, a
    /// completed one goes to Places at Now, never back into a run. From a profile (fixture): People.
    /// From an actor's report and safety (fixture): one level each, the safety to its profile, then
    /// People, then the terminal Leave.
    func testBackGesturesInTheRoom() throws {
        let app = launch(fixture: "place-explanation")
        let places = RoomPlaces(app: app)
        let room = RoomUI(app: app)
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        settle()
        edgeSwipe(app, completing: false)
        hold(0.6)
        XCTAssertTrue(room.entryHeadline.exists, "Not completed: still the entry.")
        edgeSwipe(app, completing: true)
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        XCTAssertTrue(waitForAbsence(room.screen), "A completed swipe from the entry returns to the explanation.")
        capture("room-gesture-entry-to-explanation-fixture", app)

        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        enterRoom(room)
        edgeSwipe(app, completing: false)
        hold(0.6)
        assertStillWaiting(room, "Waiting, after a cancelled swipe")
        XCTAssertFalse(room.endedStatus.exists, "A cancelled swipe does not leave.")
        capture("room-gesture-waiting-cancelled-fixture", app)
        edgeSwipe(app, completing: true)
        assertEnded(room, "Ended, by a completed swipe from waiting")
        capture("room-gesture-waiting-to-ended-fixture", app)

        edgeSwipe(app, completing: false)
        hold(0.6)
        XCTAssertTrue(room.endedStatus.exists, "Not completed: still the ended screen.")
        edgeSwipe(app, completing: true)
        assertPlacesNow(places, room, "A completed swipe from the ended screen")
        capture("room-gesture-ended-to-places-fixture", app)
        app.terminate()

        // A profile: back to People, the run still active.
        let profiled = launchRoom(RoomState(key: "maya-0", stage: "room-populated", profile: "maya",
                                            shown: .profile(actor: "maya", blocked: [])))
        let profile = RoomUI(app: profiled)
        waitForLabel(profile.profileName, "Maya")
        settle()
        edgeSwipe(profiled, completing: false)
        hold(0.6)
        XCTAssertTrue(profile.profileCard.exists, "Not completed: still Maya's profile.")
        edgeSwipe(profiled, completing: true)
        XCTAssertTrue(profile.card("maya").waitForExistence(timeout: 10), "A completed swipe from a profile: People.")
        XCTAssertTrue(waitForAbsence(profile.profileCard))
        XCTAssertTrue(waitFor(profile.tab("people"), selected: true))
        settle()
        assertPeople(profile, blocked: [], "People, after a swipe from Maya's profile")
        capture("room-gesture-profile-to-people-fixture", profiled)
        profiled.terminate()

        // A report over an actor's safety over a profile: one level per swipe, out to the terminal Leave.
        let nested = launchRoom(RoomState(key: "report-jules", stage: "room-populated", profile: "jules", panel: "report",
                                          shown: .report(actor: "jules", reason: nil)))
        let stack = RoomUI(app: nested)
        let report = Panel.report("jules"), safety = Panel.actorSafety("jules")
        XCTAssertTrue(stack.element(report).waitForExistence(timeout: 15))
        settle()
        edgeSwipe(nested, completing: true)
        XCTAssertTrue(waitForAbsence(stack.element(report)), "A swipe closes the report.")
        waitForPanel(safety, stack)
        assertActorSafety(stack, Self.jules, "Jules's safety, after a swipe from his report")
        edgeSwipe(nested, completing: false)
        hold(0.6)
        XCTAssertTrue(stack.element(safety).exists, "Not completed: still Jules's safety.")
        edgeSwipe(nested, completing: true)
        XCTAssertTrue(waitForAbsence(stack.element(safety)), "A completed swipe from an actor's safety closes it.")
        assertProfile(stack, Self.jules, userIntent: "social", "Jules's profile, after a swipe from his safety")
        capture("room-gesture-safety-to-profile-fixture", nested)
        edgeSwipe(nested, completing: true)
        XCTAssertTrue(stack.card("jules").waitForExistence(timeout: 10), "Then People.")
        settle()
        edgeSwipe(nested, completing: true)
        assertEnded(stack, "Ended, by a completed swipe from People")
    }

    // MARK: - Terminal re-entry

    /// Direct launch (fixture `room-populated` with both samples blocked, Social, Chat first). Leave;
    /// Return to Places (Now); View place; Preview check-in; Preview room demo: the entry, not the
    /// ended run; Enter room demo: a new run in waiting, not populated; Show populated example: both
    /// cards, the unblocked boundary and Jules's note again. Nothing of the ended run survives.
    func testTerminalReentryResetsTheDemo() throws {
        let app = launchRoom(RoomState(key: "people-3", stage: "room-populated", blocked: "maya-jules",
                                       shown: .people(blocked: ["maya", "jules"])))
        let room = RoomUI(app: app)
        let places = RoomPlaces(app: app)
        XCTAssertTrue(room.empty.waitForExistence(timeout: 15), "Both samples blocked.")
        settle()
        assertPeople(room, blocked: ["maya", "jules"], "Both blocked")
        room.leave.tap()
        assertEnded(room, "Ended with both blocked")
        // Return to Places sits 10 pt from where Leave was: a pause, so the two taps never count as a
        // double tap for the repeat-tap guard.
        hold(0.6)
        room.returnToPlaces.tap()
        assertPlacesNow(places, room, "Return to Places")

        places.viewPlace.tap()
        waitForLabel(places.placeName, "Common Ground")
        XCTAssertEqual(places.placePrimary.label, "Preview check-in")
        places.placePrimary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.explanationPrimary.tap()
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        settle()
        assertEntry(room, preference: "Social · Chat first", "Re-entry: the entry, not the ended run")
        enterRoom(room)
        assertWaiting(room, preference: "Social · Chat first", "Re-entry: a new run, waiting")
        capture("room-reentry-waiting-fixture", app)
        room.showPopulated.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10), "The new run's populated example.")
        settle()
        assertPeople(room, blocked: [], "Re-entry: no blocks carried over")
        capture("room-reentry-people-fixture", app)
        selectTab("notes", room)
        assertNotes(room, blocked: [], "Re-entry: Jules's note is back")
    }

    // MARK: - Refused entry

    /// Direct launches. The Room fixture `room-waiting` with Dating and with Activity (Okay to say
    /// hello): the app refuses at the explanation's own guard, so Common Ground's detail shows with its
    /// primary disabled ("Not available for …"), a tap on it opens nothing, and no Room element exists.
    /// A deeper stale route (`room-populated` with a profile and its Wave information, Dating) is
    /// refused the same way. Without an approach there is no Room fixture at all: the app opens at
    /// Welcome.
    func testIneligibleAndStaleEntryIsRefused() throws {
        for band in ["dating", "activity"] {
            let app = launchRoom(.waiting, band: band, approach: "okayToSayHello")
            let places = RoomPlaces(app: app)
            let title = Self.intentTitles[band] ?? band
            waitForLabel(places.placeName, "Common Ground")
            settle()
            XCTAssertEqual(places.placePrimary.label, "Not available for \(title)")
            XCTAssertFalse(places.placePrimary.isEnabled, "\(title): the primary is disabled.")
            XCTAssertEqual(places.placeBoundary.label, "Your \(title) band doesn’t match this session.")
            XCTAssertFalse(places.explanationHeadline.exists, "\(title): the explanation is never shown.")
            assertNoRoom(app, "\(title), a waiting fixture")
            places.placePrimary.tap()
            hold(0.6)
            XCTAssertFalse(places.explanationHeadline.exists, "\(title): the disabled action opens nothing.")
            assertNoRoom(app, "\(title), after a tap on the disabled action")
            capture("room-refused-\(band)-common-ground-fixture", app)
            app.terminate()
        }

        let deep = launchRoom(RoomState(key: "wave-info", stage: "room-populated", profile: "maya", panel: "wave-info",
                                        shown: .waveInfo), band: "dating", approach: "chatFirst")
        let refused = RoomPlaces(app: deep)
        waitForLabel(refused.placeName, "Common Ground")
        settle()
        XCTAssertEqual(refused.placePrimary.label, "Not available for Dating")
        assertNoRoom(deep, "Dating, a stale profile and Wave information")
        deep.terminate()

        let missing = XCUIApplication()
        missing.launchArguments = ["-ProximeetFixture", "room-waiting", "-ProximeetFixtureBand", "social"]
        missing.launch()
        XCTAssertTrue(missing.buttons["welcome.moreOptions"].waitForExistence(timeout: 15),
                      "No approach, no Room fixture: the app opens at Welcome.")
        assertNoRoom(missing, "Social without an approach")
    }

    // MARK: - The approved states and overlays

    /// Direct launches at the default text size, run on the iPhone 17 Pro Max: the 15 approved screens
    /// (entry, waiting, ended, People and Room notes for each of the four block sets, the four profile
    /// states), the 8 overlays (global safety, the four actor safeties, both reports, Wave information)
    /// and the four report selections (67:816 none, from the report-maya launch; 67:826, 67:836 and
    /// 67:846, each its own launch). Each is checked (copy, the samples shown or absent, the column)
    /// before it is captured as `room-<state>-<width>pt-fixture`.
    func testCaptureApprovedStatesAndOverlays() throws {
        var shown: [String] = []
        for state in Self.approvedStates {
            let app = launchRoom(state)
            let room = RoomUI(app: app)
            XCTAssertTrue(readyElement(state.shown, room).waitForExistence(timeout: 15), "\(state.key) shows.")
            settle()
            let width = Int(app.frame.width.rounded())
            assertShown(state.shown, room, "\(state.key), \(width) pt")
            softlyColumn(room, state.shown, "\(state.key), \(width) pt")
            capture("room-\(state.key)-\(width)pt-fixture", app)
            if state.key == "report-maya" {
                capture("room-report-reason-none-\(width)pt-fixture", app)
            }
            shown.append("room-\(state.key)-\(width)pt-fixture")
            app.terminate()
        }
        attachNote("Captured \(shown.count) fixture launches: " + shown.joined(separator: ", ") + ".")
    }

    // MARK: - Largest text

    /// Direct launches at the largest accessibility text size, on whichever iPhone runs it (the
    /// captures name its width): the entry, a long profile (Jules for a Business guest, the longest
    /// approach line), Room notes, an actor's safety, a report with a reason selected and the Wave
    /// information. Every text grows (never a fixed or clipped box) and stays in its column or panel;
    /// every button, Leave included, can be brought into view and tapped, and is at least 44 pt tall.
    func testLargestTextKeepsRoomReachable() throws {
        for check in Self.largestChecks {
            let app = launchRoom(check.state, band: check.band, approach: check.approach, extra: Self.largestText)
            let room = RoomUI(app: app)
            XCTAssertTrue(readyElement(check.state.shown, room).waitForExistence(timeout: 15), "\(check.name) shows.")
            hold(0.8)
            let width = Int(app.frame.width.rounded())
            let state = "\(check.name), largest text, \(width) pt"
            capture("room-\(check.name)-largest-\(width)pt-fixture", app)
            softly {
                let bounds = horizontalBounds(check.container, room)
                for text in check.texts {
                    assertUnclipped(text.id, grownFrom: text.figma, within: bounds, room, state)
                }
                for id in check.buttons {
                    assertReachableButton(id, room, state)
                }
            }
            capture("room-\(check.name)-largest-end-\(width)pt-fixture", app)
            app.terminate()
        }
    }

    // MARK: - Reduce Motion

    /// Direct launch (fixture `room-entry`, Social, Chat first) with the app-level preview flag
    /// `-ProximeetReduceMotionPreview YES` (not the system setting). Enter room demo lands directly in
    /// waiting: the model at once, and no frame just after the tap shows the ivory ticket part-way
    /// between the entry (y 410) and the header (y 128), which a plain crossfade never draws (read at
    /// x 38–66, y 306–386 on the 440-pt iPhone: ground on both screens). Then the tabs and the profiles
    /// still change: Show populated example, Room notes, People, Maya's profile and Back, Jules's
    /// profile and Back to people, Maya's Wave information and Back to profile.
    func testReduceMotionPreviewRoom() throws {
        let app = launchRoom(.entry, extra: Self.reduceMotionPreview)
        let room = RoomUI(app: app)
        waitForText(room.entryHeadline, RoomText.entryHeadline)
        hold(0.8)
        let exact = app.frame.size == CGSize(width: 440, height: 956)
        let sweep = CGRect(x: 38, y: 306, width: 28, height: 80)
        let before = exact ? RenderedScreen(app)?.fraction(in: sweep, where: Self.ivory) : nil
        room.enter.tap()
        var early: [Double] = []
        if exact {
            for _ in 0..<3 {
                if let shot = RenderedScreen(app) {
                    early.append(shot.fraction(in: sweep, where: Self.ivory))
                }
            }
        }
        XCTAssertTrue(room.waitingHeadline.waitForExistence(timeout: 5), "Reduce Motion: Enter room demo lands in waiting at once.")
        XCTAssertTrue(waitForAbsence(room.entryHeadline), "The entry is gone.")
        hold(1.0)
        let settled = exact ? RenderedScreen(app)?.fraction(in: sweep, where: Self.ivory) : nil
        let width = Int(app.frame.width.rounded())
        capture("room-reduce-motion-waiting-\(width)pt-fixture", app)
        assertWaiting(room, preference: "Social · Chat first", "Reduce Motion, waiting")
        let samples = early.map { String(format: "%.3f", $0) }.joined(separator: ", ")
        let entryText = before.map { String(format: "%.3f", $0) } ?? "unread"
        let settledText = settled.map { String(format: "%.3f", $0) } ?? "unread"
        attachNote("Reduce Motion preview, ivory in x 38–66, y 306–386: entry \(entryText); just after Enter room demo "
                   + "[\(samples)]; settled \(settledText).")
        softly {
            if let before {
                XCTAssertLessThan(before, 0.05, "The entry draws nothing ivory in the sweep (\(before)).")
            }
            for (index, sample) in early.enumerated() {
                XCTAssertLessThan(sample, 0.05, "Reduce Motion: frame \(index + 1) after Enter room demo shows the ivory "
                                  + "ticket part-way through a move (\(sample) of the sweep).")
            }
            if let settled {
                XCTAssertLessThan(settled, 0.05, "Waiting draws nothing ivory in the sweep (\(settled)).")
            }
        }

        room.showPopulated.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10))
        settle()
        assertPeople(room, blocked: [], "Reduce Motion, People")
        selectTab("notes", room)
        assertNotes(room, blocked: [], "Reduce Motion, Room notes")
        selectTab("people", room)
        openProfile(Self.maya, room)
        assertProfile(room, Self.maya, userIntent: "social", "Reduce Motion, Maya")
        room.profileBack.tap()
        XCTAssertTrue(room.card("jules").waitForExistence(timeout: 10))
        settle()
        openProfile(Self.jules, room)
        assertProfile(room, Self.jules, userIntent: "social", "Reduce Motion, Jules")
        room.profileAction.tap()
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10), "Back to people, under Reduce Motion.")
        settle()
        openProfile(Self.maya, room)
        room.profileAction.tap()
        waitForPanel(Panel.waveInfo, room)
        assertWaveInfo(room, "Reduce Motion, Wave information")
        room.inPanel(Panel.waveInfo, "roomPanel.backToProfile").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.waveInfo)))
        waitForLabel(room.profileName, "Maya")
        capture("room-reduce-motion-profile-fixture", app)
    }

    // MARK: - Fixture tables

    /// The 15 approved screens, the 8 overlays and the three selected report variants, each a direct
    /// launch. The blocks are applied in the order named, through each sample's profile safety.
    private static var approvedStates: [RoomState] {
        [
            RoomState(key: "entry", stage: "room-entry", shown: .entry),
            RoomState(key: "waiting", stage: "room-waiting", shown: .waiting),
            RoomState(key: "ended", stage: "room-ended", shown: .ended),
            RoomState(key: "people-0", stage: "room-populated", shown: .people(blocked: [])),
            RoomState(key: "people-1", stage: "room-populated", blocked: "maya", shown: .people(blocked: ["maya"])),
            RoomState(key: "people-2", stage: "room-populated", blocked: "jules", shown: .people(blocked: ["jules"])),
            RoomState(key: "people-3", stage: "room-populated", blocked: "maya-jules", shown: .people(blocked: ["maya", "jules"])),
            RoomState(key: "notes-0", stage: "room-populated", tab: "notes", shown: .notes(blocked: [])),
            RoomState(key: "notes-1", stage: "room-populated", blocked: "maya", tab: "notes", shown: .notes(blocked: ["maya"])),
            RoomState(key: "notes-2", stage: "room-populated", blocked: "jules", tab: "notes", shown: .notes(blocked: ["jules"])),
            RoomState(key: "notes-3", stage: "room-populated", blocked: "maya-jules", tab: "notes",
                      shown: .notes(blocked: ["maya", "jules"])),
            RoomState(key: "maya-0", stage: "room-populated", profile: "maya", shown: .profile(actor: "maya", blocked: [])),
            RoomState(key: "maya-2", stage: "room-populated", blocked: "jules", profile: "maya",
                      shown: .profile(actor: "maya", blocked: ["jules"])),
            RoomState(key: "jules-0", stage: "room-populated", profile: "jules", shown: .profile(actor: "jules", blocked: [])),
            RoomState(key: "jules-1", stage: "room-populated", blocked: "maya", profile: "jules",
                      shown: .profile(actor: "jules", blocked: ["maya"])),
            RoomState(key: "global-safety", stage: "room-populated", panel: "global-safety", shown: .globalSafety),
            RoomState(key: "maya-safety-0", stage: "room-populated", profile: "maya", panel: "actor-safety",
                      shown: .actorSafety(actor: "maya", blocked: [])),
            RoomState(key: "maya-safety-2", stage: "room-populated", blocked: "jules", profile: "maya", panel: "actor-safety",
                      shown: .actorSafety(actor: "maya", blocked: ["jules"])),
            RoomState(key: "jules-safety-0", stage: "room-populated", profile: "jules", panel: "actor-safety",
                      shown: .actorSafety(actor: "jules", blocked: [])),
            RoomState(key: "jules-safety-1", stage: "room-populated", blocked: "maya", profile: "jules", panel: "actor-safety",
                      shown: .actorSafety(actor: "jules", blocked: ["maya"])),
            RoomState(key: "report-maya", stage: "room-populated", profile: "maya", panel: "report",
                      shown: .report(actor: "maya", reason: nil)),
            RoomState(key: "report-jules", stage: "room-populated", profile: "jules", panel: "report",
                      shown: .report(actor: "jules", reason: nil)),
            RoomState(key: "wave-info", stage: "room-populated", profile: "maya", panel: "wave-info", shown: .waveInfo),
            RoomState(key: "report-reason-attention", stage: "room-populated", profile: "maya", panel: "report",
                      reason: "unwantedAttention", shown: .report(actor: "maya", reason: "unwantedAttention")),
            RoomState(key: "report-reason-harassment", stage: "room-populated", profile: "maya", panel: "report",
                      reason: "harassment", shown: .report(actor: "maya", reason: "harassment")),
            RoomState(key: "report-reason-other", stage: "room-populated", profile: "maya", panel: "report",
                      reason: "somethingElse", shown: .report(actor: "maya", reason: "somethingElse")),
        ]
    }

    /// Every context a Leave is offered in.
    private static var leaveContexts: [RoomState] {
        [
            RoomState(key: "waiting", stage: "room-waiting", shown: .waiting),
            RoomState(key: "waiting-global-safety", stage: "room-waiting", panel: "global-safety", shown: .globalSafety),
            RoomState(key: "people", stage: "room-populated", shown: .people(blocked: [])),
            RoomState(key: "people-global-safety", stage: "room-populated", panel: "global-safety", shown: .globalSafety),
            RoomState(key: "room-notes", stage: "room-populated", tab: "notes", shown: .notes(blocked: [])),
            RoomState(key: "profile", stage: "room-populated", profile: "maya", shown: .profile(actor: "maya", blocked: [])),
            RoomState(key: "wave-info", stage: "room-populated", profile: "maya", panel: "wave-info", shown: .waveInfo),
            RoomState(key: "actor-safety", stage: "room-populated", profile: "jules", panel: "actor-safety",
                      shown: .actorSafety(actor: "jules", blocked: [])),
            RoomState(key: "report", stage: "room-populated", profile: "maya", panel: "report", reason: "harassment",
                      shown: .report(actor: "maya", reason: "harassment")),
            RoomState(key: "note-safety", stage: "room-populated", tab: "notes", panel: "actor-safety",
                      shown: .actorSafety(actor: "jules", blocked: [])),
        ]
    }

    /// The largest-text states, each with its texts (and the height of its Figma box, which the text
    /// must outgrow) and its buttons, top to bottom.
    private static var largestChecks: [LargestCheck] {
        [
            LargestCheck(
                name: "entry", state: .entry,
                texts: [("roomEntry.headline", 112), ("roomEntry.support", 26), ("roomEntry.venue", 0),
                        ("roomEntry.boundary", 48)],
                buttons: ["roomEntry.enter", "roomEntry.back"]
            ),
            LargestCheck(
                name: "jules-profile-business",
                state: RoomState(key: "jules-0", stage: "room-populated", profile: "jules",
                                 shown: .profile(actor: "jules", blocked: [])),
                band: "business", approach: "okayToSayHello",
                texts: [("roomProfile.label", 22), ("roomProfile.name", 40), ("roomProfile.line", 21),
                        ("roomProfile.about", 96), ("roomProfile.interests", 28), ("roomProfile.boundary", 46)],
                buttons: ["roomProfile.back", "roomProfile.safety", "roomProfile.action", "room.leave"]
            ),
            LargestCheck(
                name: "notes-0",
                state: RoomState(key: "notes-0", stage: "room-populated", tab: "notes", shown: .notes(blocked: [])),
                texts: [("room.notesFraming", 22), ("room.note.host", 112), ("room.note.icebreaker", 122),
                        ("room.note.public.jules", 116)],
                buttons: ["room.safety", "room.tab.people", "room.tab.notes", "room.note.public.jules.more", "room.leave"]
            ),
            LargestCheck(
                name: "jules-safety-0",
                state: RoomState(key: "jules-safety-0", stage: "room-populated", profile: "jules", panel: "actor-safety",
                                 shown: .actorSafety(actor: "jules", blocked: [])),
                container: Panel.actorSafety("jules"),
                texts: [("roomPanel.label", 22), ("roomPanel.title", 44), ("roomPanel.explanation", 80)],
                buttons: ["roomPanel.block", "roomPanel.previewReport", "roomPanel.back", "roomPanel.leave"]
            ),
            LargestCheck(
                name: "report-maya-harassment",
                state: RoomState(key: "report-maya", stage: "room-populated", profile: "maya", panel: "report",
                                 reason: "harassment", shown: .report(actor: "maya", reason: "harassment")),
                container: Panel.report("maya"),
                texts: [("roomPanel.label", 22), ("roomPanel.title", 44), ("roomPanel.explanation", 58)],
                buttons: ["room.report.reason.unwantedAttention", "room.report.reason.harassment",
                          "room.report.reason.somethingElse", "roomPanel.closePreview", "roomPanel.leave"]
            ),
            LargestCheck(
                name: "wave-info",
                state: RoomState(key: "wave-info", stage: "room-populated", profile: "maya", panel: "wave-info",
                                 shown: .waveInfo),
                container: Panel.waveInfo,
                texts: [("roomPanel.label", 22), ("roomPanel.title", 82), ("roomPanel.explanation", 72),
                        ("roomPanel.scope", 52)],
                buttons: ["roomPanel.backToProfile", "roomPanel.leave"]
            ),
        ]
    }

    // MARK: - Route helpers

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 15))
        return app
    }

    /// A Places fixture (the explanation, for the entry tests), Social and Chat first unless given.
    private func launch(fixture: String, band: String = "social", approach: String = "chatFirst",
                        extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", fixture, "-ProximeetFixtureBand", band,
                               "-ProximeetFixtureSignal", approach] + extra
        app.launch()
        return app
    }

    /// A Room fixture, Social and Chat first unless given.
    private func launchRoom(_ state: RoomState, band: String = "social", approach: String = "chatFirst",
                            extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = state.arguments + ["-ProximeetFixtureBand", band, "-ProximeetFixtureSignal", approach] + extra
        app.launch()
        return app
    }

    /// Welcome → Birthday with 12 May 1997 → Continue → Pass → Try the demo → Finish preview.
    private func openCompletedPass(_ app: XCUIApplication) -> RoomPass {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 10), "More options should offer the demo.")
        demo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["birthday.headline"].waitForExistence(timeout: 15), "Birthday should open.")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "12")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "May")
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: true), "12 May 1997 should enable Continue.")
        proceed.tap()
        let pass = RoomPass(app: app)
        waitForLabel(pass.headline, "Your next chapter.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo complete.")
        return pass
    }

    /// Enter room demo: waiting, once the 500-ms move from the entry has finished (the entry's own
    /// words fade out during it, so nothing is read while both are in the tree).
    private func enterRoom(_ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(room.enter.label, RoomText.enter, file: file, line: line)
        room.enter.tap()
        waitForText(room.waitingHeadline, RoomText.waitingHeadline, file: file, line: line)
        XCTAssertTrue(waitForAbsence(room.entryHeadline), "Enter room demo replaces the entry.", file: file, line: line)
        settle()
    }

    /// People or Room notes, selected once the model has it and its content shows alone.
    private func selectTab(_ key: String, _ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        let tab = room.tab(key)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "The \(key) tab is showing.", file: file, line: line)
        tab.tap()
        XCTAssertTrue(waitFor(tab, selected: true), "\(key) is selected.", file: file, line: line)
        let shown = key == "notes" ? room.notesFraming : room.peopleFraming
        let hidden = key == "notes" ? room.peopleFraming : room.notesFraming
        XCTAssertTrue(shown.waitForExistence(timeout: 10), "\(key)'s content shows.", file: file, line: line)
        XCTAssertTrue(waitForAbsence(hidden), "The other tab's content is gone.", file: file, line: line)
        settle()
    }

    /// A sample's card on People, brought into view and tapped: its profile.
    private func openProfile(_ actor: SampleActor, _ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        tapRevealed(room.card(actor.key), room, file: file, line: line)
        waitForLabel(room.profileName, actor.name)
        settle()
    }

    private enum BlockRoute {
        /// The profile's Safety.
        case profile
        /// The "…" on the public note (Jules's; Maya wrote none).
        case note
    }

    /// "Block [Name] in demo" through a real control: the sample's safety opened from its profile or
    /// from its public note. The block lands on the filtered People at once, with the panel, the
    /// profile and the sample gone together (the model changes with animations disabled).
    private func block(_ actor: SampleActor, from route: BlockRoute, _ room: RoomUI,
                       file: StaticString = #filePath, line: UInt = #line) {
        switch route {
        case .profile:
            let open = room.profileName.exists && room.profileName.label == actor.name
            if !open {
                openProfile(actor, room, file: file, line: line)
            }
            room.profileSafety.tap()
        case .note:
            XCTAssertNotNil(actor.note, "\(actor.name) wrote no public note.", file: file, line: line)
            if !room.tab("notes").isSelected {
                selectTab("notes", room, file: file, line: line)
            }
            tapRevealed(room.julesNoteMore, room, file: file, line: line)
        }
        let panel = Panel.actorSafety(actor.key)
        waitForPanel(panel, room, file: file, line: line)
        let button = room.inPanel(panel, "roomPanel.block")
        XCTAssertEqual(button.label, "Block \(actor.name) in demo", file: file, line: line)
        button.tap()
        waitForLabel(room.boundary, RoomText.blockedBoundary)
        XCTAssertTrue(waitFor(room.tab("people"), selected: true), "A block lands on the filtered People.", file: file, line: line)
        XCTAssertFalse(room.element(panel).exists, "The safety closed with the block.", file: file, line: line)
        XCTAssertFalse(room.profileCard.exists, "No profile is left open.", file: file, line: line)
        XCTAssertFalse(room.card(actor.key).exists, "\(actor.name)'s card is gone at once.", file: file, line: line)
    }

    /// A report reason, selected.
    private func selectReason(_ key: String, _ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        let row = room.reason(key)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(key) is offered.", file: file, line: line)
        row.tap()
        XCTAssertTrue(waitFor(row, selected: true), "\(key) is selected.", file: file, line: line)
        settle()
    }

    /// A tap on the dimmed caller, where the screen below has its Leave (below a centred panel) or
    /// its chrome (above one), so a tap that got through would show.
    private func tapDim(outside panel: XCUIElement, _ app: XCUIApplication) {
        let frame = panel.frame
        let height = app.frame.height
        let below = height - frame.maxY > 60
        let y = below ? (frame.maxY + height) / 2 : max(40, frame.minY / 2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: app.frame.width / 2, dy: y)).tap()
    }

    /// A swipe in from the leading edge, 45 % of the way down: completed (three quarters of the width,
    /// fast) or not (a fifth of the width, slowly, held, released without momentum), as
    /// `PlacesCorrectionTests` swipes. Each starts 0.8 s after anything before it, so the window's
    /// repeat-tap guard never reads its touch as a second tap.
    private func edgeSwipe(_ app: XCUIApplication, completing: Bool) {
        waitQuietly(0.8)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 2, dy: app.frame.height * 0.45))
        if completing {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.75, dy: 0)),
                        withVelocity: .fast, thenHoldForDuration: 0.05)
        } else {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.2, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.6)
        }
    }

    // MARK: - What each state shows

    /// The element that shows once a state is ready.
    private func readyElement(_ shown: Shown, _ room: RoomUI) -> XCUIElement {
        switch shown {
        case .entry: return room.entryHeadline
        case .waiting: return room.waitingHeadline
        case .ended: return room.endedStatus
        case .people: return room.peopleFraming
        case .notes: return room.notesFraming
        case .profile: return room.profileName
        case .globalSafety: return room.element(Panel.globalSafety)
        case .actorSafety(let actor, _): return room.element(Panel.actorSafety(actor))
        case .report(let actor, _): return room.element(Panel.report(actor))
        case .waveInfo: return room.element(Panel.waveInfo)
        }
    }

    /// The panel a state shows, if any.
    private func panelID(_ shown: Shown) -> String? {
        switch shown {
        case .globalSafety: return Panel.globalSafety
        case .actorSafety(let actor, _): return Panel.actorSafety(actor)
        case .report(let actor, _): return Panel.report(actor)
        case .waveInfo: return Panel.waveInfo
        default: return nil
        }
    }

    /// The "Leave and disappear" a guest sees: the panel's own while one is open (the screen below is
    /// hidden from accessibility then), otherwise the screen's.
    private func leaveButton(for shown: Shown, _ room: RoomUI) -> XCUIElement {
        if let panel = panelID(shown) {
            return room.inPanel(panel, "roomPanel.leave")
        }
        return room.leave
    }

    /// Everything a state shows, for the actual guest (Social · Chat first unless given).
    private func assertShown(_ shown: Shown, _ room: RoomUI, userIntent: String = "social",
                             preference: String = "Social · Chat first", _ state: String) {
        switch shown {
        case .entry:
            assertEntry(room, preference: preference, state)
        case .waiting:
            assertWaiting(room, preference: preference, state)
        case .ended:
            assertEnded(room, state)
        case .people(let blocked):
            assertPeople(room, blocked: blocked, state)
        case .notes(let blocked):
            assertNotes(room, blocked: blocked, state)
        case .profile(let actor, let blocked):
            assertProfile(room, Self.actor(actor), userIntent: userIntent, state)
            assertVenue(room, preference: preference, state)
            assertSampleAbsent(room, blocked, state)
        case .globalSafety:
            assertGlobalSafety(room, state)
        case .actorSafety(let actor, let blocked):
            assertActorSafety(room, Self.actor(actor), state)
            assertSampleAbsent(room, blocked, state)
        case .report(let actor, let reason):
            assertReport(room, Self.actor(actor), selected: reason, state)
        case .waveInfo:
            assertWaveInfo(room, state)
        }
    }

    /// The entry (66:112): the approved words, the large venue ticket with the actual preference, and
    /// only Enter room demo and Back; no run, so no Safety, Leave, tabs or sample.
    private func assertEntry(_ room: RoomUI, preference: String, _ state: String) {
        assertText(room.entryHeadline, RoomText.entryHeadline, state)
        assertText(room.entrySupport, RoomText.entrySupport, state)
        assertText(room.entryVenue, "Common Ground. \(RoomText.entrySession). \(preference)", state)
        assertText(room.entryPreference, preference, state)
        assertText(room.entryBoundary, RoomText.entryBoundary, state)
        assertButton(room.enter, RoomText.enter, state)
        assertButton(room.entryBack, RoomText.entryBack, state)
        assertText(room.brand, "Proximeet", state)
        assertText(room.demoBadge, "Demo", state)
        let nodes = readTree(room.app)
        assertIdentifiers(absent: ["room.leave", "room.safety", "roomWaiting.", "roomEnded.", "roomPanel."], nodes, state)
        let leaks = sampleLeaks(nodes, of: Self.actors, hostNotes: true, structure: true)
        XCTAssertTrue(leaks.isEmpty, "\(state): the entry shows no sample. " + leaks.joined(separator: "; "))
    }

    /// Waiting (66:113): the sealed envelope, the approved words, the labelled demo control, Safety and
    /// Leave; no sample name, initials, note, count, tab or card anywhere in the tree.
    private func assertWaiting(_ room: RoomUI, preference: String, _ state: String) {
        assertText(room.envelope, RoomText.envelope, state)
        assertText(room.waitingHeadline, RoomText.waitingHeadline, state)
        assertText(room.waitingExplanation, RoomText.waitingExplanation, state)
        assertText(room.demoControl, RoomText.demoControl, state)
        assertButton(room.showPopulated, RoomText.showPopulated, state)
        assertButton(room.leave, RoomText.leave, state)
        assertChrome(room, state)
        assertVenue(room, preference: preference, state)
        let nodes = readTree(room.app)
        assertIdentifiers(absent: ["roomEntry.", "roomEnded.", "roomPanel."], nodes, state)
        let leaks = sampleLeaks(nodes, of: Self.actors, hostNotes: true, structure: true)
        XCTAssertTrue(leaks.isEmpty, "\(state): waiting shows no sample. " + leaks.joined(separator: "; "))
    }

    /// Still waiting: the demo control is there and nothing of the sample is.
    private func assertStillWaiting(_ room: RoomUI, _ state: String) {
        XCTAssertTrue(room.waitingHeadline.exists, "\(state): still waiting.")
        XCTAssertTrue(room.showPopulated.exists, "\(state): the demo control is still offered.")
        let nodes = readTree(room.app)
        let leaks = sampleLeaks(nodes, of: Self.actors, hostNotes: true, structure: true)
        XCTAssertTrue(leaks.isEmpty, "\(state): nothing revealed the sample. " + leaks.joined(separator: "; "))
    }

    /// The ended screen (66:114): the closed envelope, the approved words and Return to Places; no
    /// Leave, Safety, sample, note or panel. Leave asked nothing.
    private func assertEnded(_ room: RoomUI, _ state: String, file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel(room.endedStatus, RoomText.endedStatus)
        XCTAssertTrue(room.endedEnvelope.exists, "\(state): the closed envelope.", file: file, line: line)
        assertText(room.endedHeadline, RoomText.endedHeadline, state, file: file, line: line)
        assertText(room.endedExplanation, RoomText.endedExplanation, state, file: file, line: line)
        assertButton(room.returnToPlaces, RoomText.returnToPlaces, state, file: file, line: line)
        let nodes = readTree(room.app)
        assertIdentifiers(absent: ["room.leave", "room.safety", "roomEntry.", "roomWaiting.", "roomPanel."], nodes, state,
                          file: file, line: line)
        let leaks = sampleLeaks(nodes, of: Self.actors, hostNotes: true, structure: true)
        XCTAssertTrue(leaks.isEmpty, "\(state): the ended screen shows no sample. " + leaks.joined(separator: "; "),
                      file: file, line: line)
        XCTAssertEqual(room.app.alerts.count, 0, "\(state): Leave asks nothing.", file: file, line: line)
    }

    /// People (66:115 / 66:119 / 66:122 / 66:125): People selected, the framing, one card per visible
    /// sample (its own name, line and introduction), the boundary line for the blocks, and, with both
    /// blocked, the filtered empty card, never a claim that the room is empty. Blocked samples are absent
    /// from the tree and, on the 440-pt iPhone, from the screen.
    private func assertPeople(_ room: RoomUI, blocked: Set<String>, _ state: String) {
        XCTAssertTrue(waitFor(room.tab("people"), selected: true), "\(state): People is selected.")
        assertTabs(room, selected: "people", state)
        assertText(room.peopleFraming, RoomText.peopleFraming, state)
        for actor in Self.actors {
            let card = room.card(actor.key)
            if blocked.contains(actor.key) {
                XCTAssertFalse(card.exists, "\(state): \(actor.name)'s card is absent.")
            } else if card.exists {
                XCTAssertEqual(card.label, "\(actor.name). \(actor.line). \(actor.introduction) View card",
                               "\(state): \(actor.name)'s card reads its own words once.")
                XCTAssertGreaterThanOrEqual(card.frame.height, Self.minimumTarget)
            } else {
                XCTFail("\(state): \(actor.name)'s card is missing.")
            }
        }
        assertText(room.boundary, blocked.isEmpty ? RoomText.unblockedBoundary : RoomText.blockedBoundary, state)
        if blocked.count == Self.actors.count {
            XCTAssertTrue(room.empty.exists, "\(state): the filtered empty card.")
            assertText(room.emptyTitle, RoomText.emptyTitle, state)
            assertText(room.emptyExplanation, RoomText.emptyExplanation, state)
        } else {
            XCTAssertFalse(room.empty.exists, "\(state): no empty card while a sample shows.")
        }
        assertButton(room.leave, RoomText.leave, state)
        assertChrome(room, state)
        let nodes = readTree(room.app)
        assertNoEmptyClaim(nodes, state)
        assertSampleAbsent(nodes, blocked, state)
        softlyCardsDrawn(room.app, cards: Self.actors.count - blocked.count, state)
    }

    /// Room notes (66:116 / 66:120 / 66:123 / 66:126): Room notes selected, the framing, the host's note
    /// and icebreaker whatever is blocked, Jules's public note with its "…" only while he is visible, and
    /// "Blocked sample notes stay hidden." only while he is blocked. No cards here.
    private func assertNotes(_ room: RoomUI, blocked: Set<String>, _ state: String) {
        XCTAssertTrue(waitFor(room.tab("notes"), selected: true), "\(state): Room notes is selected.")
        assertTabs(room, selected: "notes", state)
        assertText(room.notesFraming, RoomText.notesFraming, state)
        if room.hostNote.exists {
            let host = room.hostNote.label
            XCTAssertTrue(host.contains(RoomText.hostMessage) && host.localizedCaseInsensitiveContains(RoomText.hostLabel),
                          "\(state): the host's note, one element: “\(host)”.")
        } else {
            XCTFail("\(state): the host's note stays.")
        }
        if room.icebreaker.exists {
            let icebreaker = room.icebreaker.label
            XCTAssertTrue(icebreaker.contains(RoomText.icebreaker)
                          && icebreaker.localizedCaseInsensitiveContains(RoomText.icebreakerLabel),
                          "\(state): the icebreaker, one element: “\(icebreaker)”.")
        } else {
            XCTFail("\(state): the icebreaker stays.")
        }
        if blocked.contains(Self.jules.key) {
            XCTAssertFalse(room.julesNote.exists, "\(state): Jules's note is absent.")
            XCTAssertFalse(room.julesNoteMore.exists, "\(state): its safety control is absent.")
            assertText(room.hiddenNotesBoundary, RoomText.hiddenNotesBoundary, state)
        } else {
            assertText(room.julesNote, "Jules · public sample note. One good question can change an evening.", state)
            if room.julesNoteMore.exists {
                XCTAssertEqual(room.julesNoteMore.label.replacingOccurrences(of: "’", with: "'"), "Safety for Jules's note")
                XCTAssertGreaterThanOrEqual(room.julesNoteMore.frame.height, Self.minimumTarget)
                XCTAssertGreaterThanOrEqual(room.julesNoteMore.frame.width, Self.minimumTarget)
            } else {
                XCTFail("\(state): the note's safety control is missing.")
            }
            XCTAssertFalse(room.hiddenNotesBoundary.exists, "\(state): nothing is hidden while Jules shows.")
        }
        assertButton(room.leave, RoomText.leave, state)
        assertChrome(room, state)
        let nodes = readTree(room.app)
        assertIdentifiers(absent: ["room.card.", "room.empty", "roomProfile."], nodes, state)
        assertNoEmptyClaim(nodes, state)
        assertSampleAbsent(nodes, blocked, state)
        softlyNoteDrawn(room.app, present: !blocked.contains(Self.jules.key), state)
    }

    /// A fictional profile (66:117 / 66:124 / 66:118 / 66:121): the profile chrome, the sample's own
    /// words and line, and, for the actual guest, How Waves work with the sample's own approach when
    /// the intents match, otherwise Back to people with the same-intent explanation. No tabs or cards.
    private func assertProfile(_ room: RoomUI, _ actor: SampleActor, userIntent: String, _ state: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel(room.profileName, actor.name)
        assertText(room.profileTitle, RoomText.profileTitle, state, file: file, line: line)
        assertButton(room.profileBack, "Back", state, file: file, line: line)
        assertButton(room.profileSafety, "Safety", state, file: file, line: line)
        XCTAssertGreaterThanOrEqual(room.profileBack.frame.width, Self.minimumTarget, file: file, line: line)
        XCTAssertGreaterThanOrEqual(room.profileSafety.frame.width, Self.minimumTarget, file: file, line: line)
        XCTAssertFalse(room.safety.exists, "\(state): a profile's Safety is its sample's.", file: file, line: line)
        XCTAssertTrue(room.profileCard.exists, "\(state): the profile card.", file: file, line: line)
        assertText(room.profileLabel, RoomText.profileLabel, state, file: file, line: line)
        assertText(room.profileLine, actor.line, state, file: file, line: line)
        assertText(room.profileAbout, actor.introduction + "\n" + actor.quote, state, file: file, line: line)
        assertText(room.profileInterests, "Interests: " + actor.interests.joined(separator: ", "), state, file: file, line: line)
        let same = actor.intent == userIntent
        assertText(room.profileBoundary, same ? actor.approach : RoomText.sameIntent, state, file: file, line: line)
        assertButton(room.profileAction, same ? RoomText.howWavesWork : RoomText.backToPeople, state, file: file, line: line)
        assertButton(room.leave, RoomText.leave, state, file: file, line: line)
        XCTAssertFalse(room.tabs.exists, "\(state): the profile replaces the tabs.", file: file, line: line)
        for other in Self.actors {
            XCTAssertFalse(room.card(other.key).exists, "\(state): no card on a profile.", file: file, line: line)
        }
    }

    /// The compact venue ticket on waiting, People, Room notes and the profiles.
    private func assertVenue(_ room: RoomUI, preference: String, _ state: String) {
        assertText(room.venue, "Common Ground. \(RoomText.compactSession). \(preference)", state)
        assertText(room.venuePreference, preference, state)
    }

    /// The root chrome: Proximeet, the Demo badge and the Safety shield.
    private func assertChrome(_ room: RoomUI, _ state: String) {
        assertText(room.brand, "Proximeet", state)
        assertText(room.demoBadge, "Demo", state)
        assertButton(room.safety, "Safety", state)
        if room.safety.exists {
            XCTAssertGreaterThanOrEqual(room.safety.frame.width, Self.minimumTarget, "\(state): Safety is 44 pt wide.")
        }
    }

    private func assertTabs(_ room: RoomUI, selected: String, _ state: String) {
        assertText(room.tabs, RoomText.tabs, state)
        for (key, title) in [("people", RoomText.peopleTab), ("notes", RoomText.notesTab)] {
            let tab = room.tab(key)
            guard tab.exists else {
                XCTFail("\(state): the \(title) tab is missing.")
                continue
            }
            XCTAssertEqual(tab.label, title)
            XCTAssertEqual(tab.isSelected, key == selected, "\(state): \(title) selected \(tab.isSelected).")
            XCTAssertGreaterThanOrEqual(tab.frame.height, Self.minimumTarget)
        }
    }

    /// What every panel carries: its container, "DEMO PREVIEW" and its own Leave; the screen below is
    /// hidden from accessibility while it shows.
    private func assertPanel(_ room: RoomUI, _ panel: String, _ state: String) {
        XCTAssertTrue(room.element(panel).exists, "\(state): \(panel) is showing.")
        assertText(room.inPanel(panel, "roomPanel.label"), RoomText.overlayLabel, state)
        assertButton(room.inPanel(panel, "roomPanel.leave"), RoomText.leave, state)
        XCTAssertFalse(room.leave.exists, "\(state): the screen below is hidden while a panel shows.")
    }

    /// The global safety (66:127).
    private func assertGlobalSafety(_ room: RoomUI, _ state: String) {
        let panel = Panel.globalSafety
        assertPanel(room, panel, state)
        assertText(room.inPanel(panel, "roomPanel.title"), RoomText.safetyTitle, state)
        assertText(room.inPanel(panel, "roomPanel.explanation"), RoomText.safetyExplanation, state)
        assertButton(room.inPanel(panel, "roomPanel.close"), RoomText.close, state)
        XCTAssertFalse(room.inPanel(panel, "roomPanel.block").exists, "\(state): nothing to block here.")
    }

    /// A sample's safety (66:128–66:131).
    private func assertActorSafety(_ room: RoomUI, _ actor: SampleActor, _ state: String) {
        let panel = Panel.actorSafety(actor.key)
        assertPanel(room, panel, state)
        assertText(room.inPanel(panel, "roomPanel.title"), "\(actor.name) · safety", state)
        assertText(room.inPanel(panel, "roomPanel.explanation"), RoomText.actorSafetyExplanation, state)
        assertButton(room.inPanel(panel, "roomPanel.block"), "Block \(actor.name) in demo", state)
        assertButton(room.inPanel(panel, "roomPanel.previewReport"), RoomText.previewReport, state)
        assertButton(room.inPanel(panel, "roomPanel.back"), RoomText.actorSafetyBack, state)
    }

    /// An unsent report preview (66:132 / 66:133) with exactly `selected` chosen (none when nil).
    private func assertReport(_ room: RoomUI, _ actor: SampleActor, selected: String?, _ state: String) {
        let panel = Panel.report(actor.key)
        assertPanel(room, panel, state)
        assertText(room.inPanel(panel, "roomPanel.title"), "Report \(actor.name)", state)
        assertText(room.inPanel(panel, "roomPanel.explanation"), RoomText.reportExplanation, state)
        for reason in Self.reasons {
            let row = room.reason(reason.key)
            guard row.exists else {
                XCTFail("\(state): “\(reason.title)” is missing.")
                continue
            }
            XCTAssertEqual(row.label, reason.title)
            XCTAssertEqual(row.isSelected, reason.key == selected,
                           "\(state): “\(reason.title)” selected \(row.isSelected), expected \(reason.key == selected).")
            XCTAssertGreaterThanOrEqual(row.frame.height, Self.minimumTarget)
        }
        assertButton(room.inPanel(panel, "roomPanel.closePreview"), RoomText.closePreview, state)
        XCTAssertFalse(room.inPanel(panel, "roomPanel.block").exists, "\(state): a report blocks nothing.")
        assertNothingSubmits(readTree(room.app), state)
    }

    /// The Wave information (66:134): information only, with Back to profile.
    private func assertWaveInfo(_ room: RoomUI, _ state: String) {
        let panel = Panel.waveInfo
        assertPanel(room, panel, state)
        assertText(room.inPanel(panel, "roomPanel.title"), RoomText.waveTitle, state)
        assertText(room.inPanel(panel, "roomPanel.explanation"), RoomText.waveExplanation, state)
        assertText(room.inPanel(panel, "roomPanel.scope"), RoomText.waveScope, state)
        assertButton(room.inPanel(panel, "roomPanel.backToProfile"), RoomText.backToProfile, state)
        assertNothingSubmits(readTree(room.app), state)
    }

    /// Places browsing at Now, with no Room left and no run showing.
    private func assertPlacesNow(_ places: RoomPlaces, _ room: RoomUI, _ state: String) {
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(waitFor(places.tab("now"), selected: true), "\(state): Places browsing at Now.")
        waitForLabel(places.ticketName, "Common Ground")
        XCTAssertTrue(waitForAbsence(room.screen), "\(state): no Room is showing.")
        XCTAssertFalse(places.explanationHeadline.exists, "\(state): browsing, not the explanation.")
        let nodes = readTree(places.app)
        assertIdentifiers(absent: ["room"], nodes, state)
    }

    /// No Room element at all (every Room identifier starts with "room").
    private func assertNoRoom(_ app: XCUIApplication, _ state: String) {
        assertIdentifiers(absent: ["room"], readTree(app), state)
    }

    /// Checks the filtered People, then Room notes, then People again, after a block.
    private func assertAfterBlock(_ room: RoomUI, blocked: Set<String>, named key: String) {
        let state = "Blocked \(blocked.sorted().joined(separator: " and ")) (\(key))"
        assertPeople(room, blocked: blocked, "\(state), People")
        capture("room-blocks-\(key)-people-fixture", room.app)
        selectTab("notes", room)
        assertNotes(room, blocked: blocked, "\(state), Room notes")
        capture("room-blocks-\(key)-notes-fixture", room.app)
        selectTab("people", room)
        assertPeople(room, blocked: blocked, "\(state), People again")
    }

    /// The blocks stay applied through everything that is not Leave: the tabs, the global safety opened
    /// and closed from People and from Room notes, and, while a sample is still visible, its profile and
    /// Back, and its report preview (a reason selected) closed back to the profile and People.
    private func assertBlocksSurvive(_ room: RoomUI, blocked: Set<String>, _ state: String) {
        selectTab("notes", room)
        assertNotes(room, blocked: blocked, "\(state), Room notes")
        selectTab("people", room)
        assertPeople(room, blocked: blocked, "\(state), after the tabs")

        room.safety.tap()
        waitForPanel(Panel.globalSafety, room)
        room.inPanel(Panel.globalSafety, "roomPanel.close").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.globalSafety)))
        settle()
        assertPeople(room, blocked: blocked, "\(state), after the global safety")

        if let visible = Self.actors.first(where: { !blocked.contains($0.key) }) {
            openProfile(visible, room)
            assertSampleAbsent(room, blocked, "\(state), \(visible.name)'s profile")
            room.profileBack.tap()
            XCTAssertTrue(room.card(visible.key).waitForExistence(timeout: 10))
            settle()
            assertPeople(room, blocked: blocked, "\(state), after a profile's Back")

            openProfile(visible, room)
            room.profileSafety.tap()
            let safety = Panel.actorSafety(visible.key)
            waitForPanel(safety, room)
            room.inPanel(safety, "roomPanel.previewReport").tap()
            let report = Panel.report(visible.key)
            waitForPanel(report, room)
            selectReason("somethingElse", room)
            assertSampleAbsent(room, blocked, "\(state), \(visible.name)'s report")
            room.inPanel(report, "roomPanel.closePreview").tap()
            XCTAssertTrue(waitForAbsence(room.element(report)))
            waitForPanel(safety, room)
            room.inPanel(safety, "roomPanel.back").tap()
            XCTAssertTrue(waitForAbsence(room.element(safety)))
            waitForLabel(room.profileName, visible.name)
            room.profileBack.tap()
            XCTAssertTrue(room.card(visible.key).waitForExistence(timeout: 10))
            settle()
            assertPeople(room, blocked: blocked, "\(state), after a closed report preview")
        }

        selectTab("notes", room)
        room.safety.tap()
        waitForPanel(Panel.globalSafety, room)
        room.inPanel(Panel.globalSafety, "roomPanel.close").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.globalSafety)))
        XCTAssertTrue(waitFor(room.tab("notes"), selected: true), "\(state): Close returns to Room notes.")
        settle()
        assertNotes(room, blocked: blocked, "\(state), Room notes after the global safety")
        selectTab("people", room)
    }

    /// A same-intent sample: How Waves work, its information panel, Back to profile, then the profile's
    /// Back to People.
    private func checkSameIntent(_ actor: SampleActor, _ room: RoomUI, userIntent: String, named key: String) {
        let state = "\(key): \(actor.name)"
        openProfile(actor, room)
        assertProfile(room, actor, userIntent: userIntent, state)
        XCTAssertEqual(room.profileAction.label, RoomText.howWavesWork, "\(state): the same intent offers How Waves work.")
        capture("room-compat-\(key)-\(actor.key)-profile-fixture", room.app)
        room.profileAction.tap()
        waitForPanel(Panel.waveInfo, room)
        assertWaveInfo(room, "\(state), Wave information")
        capture("room-compat-\(key)-\(actor.key)-wave-info-fixture", room.app)
        room.inPanel(Panel.waveInfo, "roomPanel.backToProfile").tap()
        XCTAssertTrue(waitForAbsence(room.element(Panel.waveInfo)), "\(state): Back to profile closes the Wave information.")
        assertProfile(room, actor, userIntent: userIntent, "\(state), back on the profile")
        room.profileBack.tap()
        XCTAssertTrue(room.card(actor.key).waitForExistence(timeout: 10), "\(state): the profile's Back returns to People.")
        XCTAssertTrue(waitFor(room.tab("people"), selected: true))
        settle()
    }

    /// Another intent's sample: Back to people and the same-intent explanation; no Wave information.
    private func checkOtherIntent(_ actor: SampleActor, _ room: RoomUI, userIntent: String, named key: String) {
        let state = "\(key): \(actor.name)"
        openProfile(actor, room)
        assertProfile(room, actor, userIntent: userIntent, state)
        XCTAssertEqual(room.profileAction.label, RoomText.backToPeople, "\(state): another intent offers Back to people.")
        assertText(room.profileBoundary, RoomText.sameIntent, state)
        capture("room-compat-\(key)-\(actor.key)-profile-fixture", room.app)
        room.profileAction.tap()
        XCTAssertTrue(room.card(actor.key).waitForExistence(timeout: 10), "\(state): Back to people returns to People.")
        XCTAssertTrue(waitFor(room.tab("people"), selected: true))
        XCTAssertTrue(waitForAbsence(room.profileCard))
        XCTAssertFalse(room.element(Panel.waveInfo).exists, "\(state): no Wave information for another intent.")
        settle()
        assertPeople(room, blocked: [], "\(state), People again")
    }

    // MARK: - The tree

    /// Every element of the app in one snapshot (one round trip), with its words.
    private func readTree(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> [RoomNode] {
        let root: any XCUIElementSnapshot
        do {
            root = try app.snapshot()
        } catch {
            XCTFail("The accessibility tree could not be read: \(error.localizedDescription)", file: file, line: line)
            return []
        }
        var nodes: [RoomNode] = []
        var stack: [any XCUIElementSnapshot] = [root]
        while let node = stack.popLast() {
            stack.append(contentsOf: node.children.reversed())
            let value = (node.value as? String) ?? ""
            nodes.append(RoomNode(identifier: node.identifier, label: node.label, value: value, type: node.elementType))
        }
        return nodes
    }

    /// Where a sample could show up in the tree: its name or initials in any words, its introduction,
    /// quote, approach line, public note or an interest, and its card, note, safety or report
    /// identifiers. With `hostNotes`, the host's note and icebreaker too; with `structure`, anything of
    /// the populated example (tabs, cards, notes, profiles, sample panels) and any count of people.
    private func sampleLeaks(_ nodes: [RoomNode], of actors: [SampleActor], hostNotes: Bool, structure: Bool) -> [String] {
        var found: [String] = []
        for node in nodes {
            let texts = [node.label, node.value].filter { !$0.isEmpty }
            let place = node.identifier.isEmpty ? "an element" : node.identifier
            for actor in actors {
                var samples = [actor.introduction, actor.quote, actor.approach]
                if let note = actor.note {
                    samples.append(note)
                }
                for text in texts {
                    let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    if text.contains(actor.name) || words.contains(actor.initials) || actor.interests.contains(text)
                        || samples.contains(where: { text.contains($0) }) {
                        found.append("\(place) “\(text)” shows \(actor.name)")
                    }
                }
                for prefix in ["room.card.\(actor.key)", "room.note.public.\(actor.key)", Panel.actorSafety(actor.key),
                               Panel.report(actor.key)] where node.identifier.hasPrefix(prefix) {
                    found.append("\(node.identifier) is \(actor.name)'s")
                }
            }
            if hostNotes {
                for text in texts where text.contains(RoomText.hostMessage) || text.contains(RoomText.icebreaker)
                    || text.localizedCaseInsensitiveContains("host note") || text.localizedCaseInsensitiveContains("icebreaker") {
                    found.append("\(place) “\(text)” is a room note")
                }
            }
            if structure {
                for prefix in Self.sampleStructure where node.identifier.hasPrefix(prefix) {
                    found.append("\(node.identifier) belongs to the populated example")
                }
                for text in texts where Self.mentionsCount(text) {
                    found.append("\(place) “\(text)” counts people")
                }
            }
        }
        return found
    }

    /// Identifiers that only the populated example (or a sample's panel) has.
    private static let sampleStructure = [
        "room.tabs", "room.tab.", "room.card.", "room.note", "room.peopleFraming", "room.empty", "room.boundary",
        "roomProfile.", "roomPanel.actorSafety", "roomPanel.report", "roomPanel.waveInfo", "room.report.reason",
    ]

    private static func mentionsCount(_ text: String) -> Bool {
        text.range(of: "\\b[0-9]+\\s+(people|person|persons|guests?|others?|members?|here)\\b",
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The blocked samples are absent from the whole tree.
    private func assertSampleAbsent(_ nodes: [RoomNode], _ blocked: Set<String>, _ state: String) {
        let hidden = Self.actors.filter { blocked.contains($0.key) }
        guard !hidden.isEmpty else { return }
        let leaks = sampleLeaks(nodes, of: hidden, hostNotes: false, structure: false)
        XCTAssertTrue(leaks.isEmpty, "\(state): a blocked sample is absent, not hidden. " + leaks.joined(separator: "; "))
    }

    private func assertSampleAbsent(_ room: RoomUI, _ blocked: Set<String>, _ state: String) {
        guard !blocked.isEmpty else { return }
        assertSampleAbsent(readTree(room.app), blocked, state)
    }

    /// Filtered, never empty: nothing says the venue or the room is empty or that nobody is there.
    private func assertNoEmptyClaim(_ nodes: [RoomNode], _ state: String) {
        let claims = nodes.filter { node in
            let text = node.label.lowercased()
            return text.contains("empty") || text.contains("no one") || text.contains("nobody") || text.contains("no people")
        }
        XCTAssertTrue(claims.isEmpty, "\(state): nothing claims the room is empty. "
                      + claims.map { "“\($0.label)”" }.joined(separator: "; "))
    }

    /// Nothing is named Send, Submit or Sent, and no control offers to send or submit anything.
    private func assertNothingSubmits(_ nodes: [RoomNode], _ state: String) {
        let offending = nodes.filter { node in
            let words = Set(node.label.lowercased().components(separatedBy: CharacterSet.letters.inverted))
            let named = node.label.range(of: "^(send|submit|sent)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            let control = node.type == .button && !words.isDisjoint(with: ["send", "sent", "submit", "submitted", "submits"])
            let identifier = node.identifier.lowercased()
            return named || control || identifier.contains("send") || identifier.contains("submit")
        }
        XCTAssertTrue(offending.isEmpty, "\(state): nothing is sent or submitted. "
                      + offending.map { "\($0.identifier) “\($0.label)”" }.joined(separator: "; "))
    }

    private func assertIdentifiers(absent prefixes: [String], _ nodes: [RoomNode], _ state: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let present = nodes.filter { node in prefixes.contains { node.identifier.hasPrefix($0) } }.map { $0.identifier }
        XCTAssertTrue(present.isEmpty, "\(state): these should not exist: " + present.joined(separator: ", "),
                      file: file, line: line)
    }

    // MARK: - Words and controls

    /// Compares with every run of white space (a line break included) read as one space: a headline is
    /// one element whose lines are joined.
    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func assertText(_ element: XCUIElement, _ expected: String, _ state: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else {
            XCTFail("\(state): “\(expected)” is not showing.", file: file, line: line)
            return
        }
        XCTAssertEqual(Self.normalized(element.label), Self.normalized(expected), "\(state): the approved words.",
                       file: file, line: line)
    }

    private func assertButton(_ element: XCUIElement, _ label: String, _ state: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else {
            XCTFail("\(state): “\(label)” is not offered.", file: file, line: line)
            return
        }
        XCTAssertEqual(element.label, label, "\(state): the approved label.", file: file, line: line)
        XCTAssertTrue(element.isEnabled, "\(state): “\(label)” is enabled.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, Self.minimumTarget, "\(state): “\(label)” is 44 pt tall or more.",
                                    file: file, line: line)
    }

    /// The column on any width (min(376, width − 64), centred): the screen's full-width buttons and a
    /// panel (376 wide on the 440-pt iPhone) and its 24-pt inset buttons.
    private func softlyColumn(_ room: RoomUI, _ shown: Shown, _ state: String) {
        let width = room.app.frame.width
        let column = min(376, width - 64), margin = (width - column) / 2
        softly {
            var wide: [XCUIElement] = []
            switch shown {
            case .entry: wide = [room.enter, room.entryBack]
            case .waiting: wide = [room.showPopulated, room.leave]
            case .ended: wide = [room.returnToPlaces]
            case .people, .notes: wide = [room.leave]
            case .profile: wide = [room.profileAction, room.leave]
            case .globalSafety, .actorSafety, .report, .waveInfo: wide = []
            }
            for element in wide where element.exists {
                XCTAssertEqual(element.frame.minX, margin, accuracy: 1.5, "\(state): \(element.identifier) starts at the column.")
                XCTAssertEqual(element.frame.width, column, accuracy: 1.5, "\(state): \(element.identifier) spans the column.")
            }
            if let id = panelID(shown) {
                let panel = room.element(id)
                XCTAssertEqual(panel.frame.minX, margin, accuracy: 1.5, "\(state): the panel starts at the column.")
                XCTAssertEqual(panel.frame.width, column, accuracy: 1.5, "\(state): the panel is the column's width.")
                let leave = room.inPanel(id, "roomPanel.leave")
                XCTAssertEqual(leave.frame.width, column - 48, accuracy: 1.5, "\(state): the panel's Leave is inset 24 pt.")
            }
        }
    }

    // MARK: - Largest text

    /// The horizontal extent texts must stay inside: the panel's, or the column's.
    private func horizontalBounds(_ container: String?, _ room: RoomUI) -> ClosedRange<CGFloat> {
        if let container {
            let frame = room.element(container).frame
            return frame.minX...frame.maxX
        }
        let width = room.app.frame.width
        let margin = (width - min(376, width - 64)) / 2
        return margin...(width - margin)
    }

    /// A text, brought into view: its words, a box grown well past its Figma height (at least 1.3 times
    /// it, and 30 pt: a box that did not grow is fixed or clipped), inside its column or panel.
    private func assertUnclipped(_ id: String, grownFrom figma: CGFloat, within bounds: ClosedRange<CGFloat>,
                                 _ room: RoomUI, _ state: String) {
        guard reveal(id, room.app) else { return }
        let element = room.element(id)
        let frame = element.frame
        XCTAssertFalse(element.label.isEmpty, "\(state): \(id) has its words.")
        if figma > 0 {
            let least = max(30, figma * 1.3)
            XCTAssertGreaterThanOrEqual(frame.height, least, "\(state): \(id) is \(Self.pt(frame.height)) pt tall, from a "
                                        + "\(Self.pt(figma))-pt Figma box: it did not grow with the text (fixed or clipped).")
        }
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.lowerBound - 1, "\(state): \(id) starts inside its column (\(Self.rect(frame))).")
        XCTAssertLessThanOrEqual(frame.maxX, bounds.upperBound + 1, "\(state): \(id) ends inside its column (\(Self.rect(frame))).")
    }

    /// A button, brought into view: it can be tapped and is at least 44 pt tall.
    private func assertReachableButton(_ id: String, _ room: RoomUI, _ state: String) {
        guard reveal(id, room.app) else { return }
        let button = room.element(id)
        XCTAssertTrue(button.isHittable, "\(state): \(id) can be tapped once in view.")
        XCTAssertGreaterThanOrEqual(button.frame.height, Self.minimumTarget,
                                    "\(state): \(id) is \(Self.pt(button.frame.height)) pt tall.")
        XCTAssertLessThanOrEqual(button.frame.maxY, room.app.frame.maxY, "\(state): \(id) is on screen.")
    }

    // MARK: - Scrolling

    /// Taps an element, first bringing it into view if it cannot be tapped where it is.
    private func tapRevealed(_ element: XCUIElement, _ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "The control is showing.", file: file, line: line)
        if !element.isHittable {
            reveal(element.identifier, room.app, file: file, line: line)
        }
        element.tap()
    }

    /// Brings the element with `identifier` between the top of the screen (the status bar, 62) and the
    /// top of any fixed bar below its scroll view (the buttons outside that scroll view in its lower
    /// half: the Room's bottom actions), 4 pt clear; an element taller than that counts once its top is
    /// in view. An element in no scroll view must already be there. Returns whether it did; when it did
    /// not, it has already failed the test at the caller's line, with the screen, every drag and every
    /// look attached: "Scroll PRODUCT" when two drags in a row did not move the page (its end, with the
    /// element still out of view), "Scroll HARNESS" for everything else.
    ///
    /// Short, momentum-free drags (press 0.05 s, slow, held 0.2 s before release), each touching down
    /// inside the element's scroll view on nothing that is a control (10 pt clear), never within 40 pt of
    /// either screen edge (the leading edge is the Room's back swipe), and 0.7 s after the last, so the
    /// window's repeat-tap guard never takes one for a second tap. Every drag prints a `ROOM_SCROLL` line.
    @discardableResult
    private func reveal(_ identifier: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var trace: [String] = []
        var lifted = Date.distantPast
        var lastTouch: CGPoint?
        var lastTop: CGFloat?
        var direction: CGFloat = 0
        var stalls = 0
        for attempt in 0..<15 {
            let look: RevealLook
            do {
                look = try settledRevealLook(identifier, app, settle: attempt > 0)
            } catch {
                return revealFailed("HARNESS", identifier, "the tree could not be read: \(error.localizedDescription)",
                                    trace, app, file: file, line: line)
            }
            guard look.found else {
                return revealFailed("PRODUCT", identifier, "it is not in the accessibility tree", trace, app, file: file, line: line)
            }
            let frame = look.target
            if let lastTop, direction != 0 {
                let moved = (lastTop - frame.minY) * direction
                trace.append("moved \(Self.pt(moved))")
                if moved < -2 {
                    return revealFailed("HARNESS", identifier, "the last drag moved the page the wrong way", trace, app,
                                        file: file, line: line)
                }
                stalls = moved < 2 ? stalls + 1 : 0
                if stalls >= 2 {
                    return revealFailed("PRODUCT", identifier, "two drags in a row did not move it: the page has reached its "
                                        + "end with it at \(Self.rect(frame))", trace, app, file: file, line: line)
                }
            }
            let screen = look.screen
            // The bar's own elements (and anything in no scroll view) never move: they only have to be
            // on screen. Everything else has to come between the status bar and the bar.
            let fixed = look.scroller == nil || Self.barIdentifiers.contains(identifier)
            let top: CGFloat = fixed ? 0 : max(62, look.scroller?.minY ?? 62)
            var bottom: CGFloat = fixed ? screen.maxY - 8 : min(look.scroller?.maxY ?? screen.maxY, screen.maxY - 20)
            if !fixed, let bar = look.barTop {
                bottom = min(bottom, bar - 4)
            }
            let fits = frame.height <= bottom - top - 2
            let low = fits ? frame.maxY > bottom + 1 : frame.minY > bottom - 44
            let high = frame.minY < top - 1
            let barText = look.barTop.map { Self.pt($0) } ?? "none"
            trace.append("look \(attempt + 1): \(Self.rect(frame)); range \(Self.pt(top))–\(Self.pt(bottom)); scroll view "
                         + "\(Self.rect(look.scroller)); bar top \(barText)")
            if !low && !high {
                return true
            }
            guard let scroller = look.scroller, !fixed else {
                return revealFailed("PRODUCT", identifier, "it lies outside \(Self.pt(top))–\(Self.pt(bottom)) and does not "
                                    + "scroll", trace, app, file: file, line: line)
            }
            let bandTop = top + 12, bandBottom = bottom - 12
            let room = bandBottom - bandTop
            guard room >= 40 else {
                return revealFailed("HARNESS", identifier, "only \(Self.pt(room)) pt to drag in", trace, app, file: file, line: line)
            }
            var distance: CGFloat
            if low {
                distance = fits ? frame.maxY - bottom + 16 : frame.minY - (bottom - 60)
                distance = min(distance, frame.minY - top - 1)
            } else {
                distance = top - frame.minY + 16
                if fits {
                    distance = min(distance, bottom - frame.maxY - 1)
                }
            }
            let travel = min(max(distance, 24), room, 150)
            guard let start = revealTouch(look, scroller: scroller, travel: travel, fingerUp: low, bandTop: bandTop,
                                          bandBottom: bandBottom, awayFrom: lastTouch) else {
                return revealFailed("HARNESS", identifier, "no touch-down point in the scroll view keeps 10 pt from every control",
                                    trace, app, file: file, line: line)
            }
            let end = CGPoint(x: start.x, y: start.y + (low ? -travel : travel))
            let quiet = Date().timeIntervalSince(lifted)
            if quiet < 0.7 {
                waitQuietly(0.7 - quiet)
            }
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: start.x, dy: start.y))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            lifted = Date()
            lastTouch = start
            lastTop = frame.minY
            direction = low ? 1 : -1
            let entry = "drag \(attempt + 1) \(low ? "up" : "down") \(Self.point(start)) → \(Self.point(end))"
            trace.append(entry)
            print("ROOM_SCROLL \(identifier) \(entry)")
        }
        return revealFailed("HARNESS", identifier, "15 looks did not bring it into view", trace, app, file: file, line: line)
    }

    /// Reads the tree once the target has stopped moving (two reads 0.15 s apart within 0.5 pt, at most
    /// four more), so a rubber band is never measured half-way.
    private func settledRevealLook(_ identifier: String, _ app: XCUIApplication, settle: Bool) throws -> RevealLook {
        var look = try revealLook(identifier, app)
        guard settle else { return look }
        for _ in 0..<4 {
            waitQuietly(0.15)
            let next = try revealLook(identifier, app)
            if abs(next.target.minY - look.target.minY) <= 0.5 {
                return next
            }
            look = next
        }
        return look
    }

    /// One snapshot of the whole app: the target, the scroll view that holds it, the top of any fixed
    /// bar below that scroll view, and every control. The bar is whatever lies in the lower half of the
    /// scroll view's extent but outside it (the Room's `.safeAreaInset` actions, and People's boundary
    /// line above Leave), together with the elements the Room keeps in that bar, wherever the tree
    /// places them.
    private func revealLook(_ identifier: String, _ app: XCUIApplication) throws -> RevealLook {
        let root = try app.snapshot()
        var look = RevealLook()
        look.screen = root.frame
        var placed: [RevealPlaced] = []
        var stack: [RevealEntry] = [RevealEntry(node: root, scroller: nil)]
        while let entry = stack.popLast() {
            let node = entry.node
            if !look.found && node.identifier == identifier {
                look.found = true
                look.target = node.frame
                look.scroller = entry.scroller
            }
            if Self.controlTypes.contains(node.elementType) {
                look.controls.append(node.frame)
            }
            placed.append(RevealPlaced(frame: node.frame, scroller: entry.scroller, identifier: node.identifier))
            let inner: CGRect? = node.elementType == .scrollView ? node.frame : entry.scroller
            for child in node.children.reversed() {
                stack.append(RevealEntry(node: child, scroller: inner))
            }
        }
        if let scroller = look.scroller {
            let screenBottom = look.screen.maxY
            let fixed = placed.filter { item in
                let barred = item.scroller != scroller || Self.barIdentifiers.contains(item.identifier)
                let below = item.frame.minY >= scroller.midY && item.frame.minY < screenBottom && item.frame.height > 0
                let across = item.frame.maxX > scroller.minX && item.frame.minX < scroller.maxX
                return barred && below && across && item.identifier != identifier
            }
            look.barTop = fixed.map { $0.frame.minY }.min()
        }
        return look
    }

    /// What the Room keeps in the bar below its scrolling content (`RoomView.actionBar`): never scrolled.
    private static let barIdentifiers: Set<String> = [
        "room.leave", "room.boundary", "roomEntry.enter", "roomEntry.back", "roomEnded.returnToPlaces",
    ]

    /// Where a drag touches down: inside the scroll view (across its middle, a third in, or 12 pt into
    /// either side margin of the column), never within 40 pt of a screen edge, at a height from which
    /// the whole drag stays in the band (nearest its middle first), 10 pt or more from every control,
    /// and preferably 60 pt or more from the last drag's touch-down.
    private func revealTouch(_ look: RevealLook, scroller: CGRect, travel: CGFloat, fingerUp: Bool, bandTop: CGFloat,
                             bandBottom: CGFloat, awayFrom previous: CGPoint?) -> CGPoint? {
        let fractions: [CGFloat] = [0.5, 0.33, 0.67]
        var xs = fractions.map { scroller.minX + scroller.width * $0 }
        // Both Room scroll views span the screen, so "12 pt in from the scroll view's side" is always
        // within 40 pt of an edge and never used. 12 pt into the column's side margin (x 44 on any
        // phone) is: in a panel that is its 24-pt inset beside the buttons, the only ground left once a
        // tall panel at the largest text shows nothing but buttons and their 6-16 pt gaps.
        let screenWidth = look.screen.width
        let margin = (screenWidth - min(376, screenWidth - 64)) / 2
        xs += [margin + 12, screenWidth - margin - 12]
        xs = xs.filter { $0 >= 40 && $0 <= screenWidth - 40 }
        let lowest = fingerUp ? bandTop + travel : bandTop
        let highest = fingerUp ? bandBottom : bandBottom - travel
        guard lowest <= highest else { return nil }
        let middle = (lowest + highest) / 2
        var ys: [CGFloat] = []
        var offset: CGFloat = 0
        while offset <= (highest - lowest) / 2 + 8 {
            for y in [middle - offset, middle + offset] where y >= lowest && y <= highest && !ys.contains(y) {
                ys.append(y)
            }
            offset += 8
        }
        let avoided = look.controls.map { $0.insetBy(dx: -10, dy: -10) }
        for spaced in [true, false] {
            for y in ys {
                for x in xs {
                    let point = CGPoint(x: x, y: y)
                    if avoided.contains(where: { $0.contains(point) }) {
                        continue
                    }
                    if spaced, let previous {
                        let dx = previous.x - x, dy = previous.y - y
                        if (dx * dx + dy * dy).squareRoot() < 60 {
                            continue
                        }
                    }
                    return point
                }
            }
        }
        return nil
    }

    /// Attaches the reason, every look and drag, and the screen, then fails with "Scroll PRODUCT: …" or
    /// "Scroll HARNESS: …" at the caller's line.
    private func revealFailed(_ kind: String, _ identifier: String, _ reason: String, _ trace: [String],
                              _ app: XCUIApplication, file: StaticString, line: UInt) -> Bool {
        let lines = ["reveal \(kind) \(identifier): \(reason)"] + trace
        print("ROOM_SCROLL_FAILED " + lines.joined(separator: " | "))
        attachNote(lines.joined(separator: "\n"))
        capture("room-scroll-\(kind.lowercased())-\(identifier)", app)
        XCTFail("Scroll \(kind): \(identifier): \(reason)", file: file, line: line)
        return false
    }

    private static let controlTypes: Set<XCUIElement.ElementType> = [
        .button, .link, .`switch`, .toggle, .slider, .stepper, .textField, .secureTextField, .searchField, .textView,
        .segmentedControl, .pickerWheel, .datePicker, .cell, .tab, .key,
    ]

    // MARK: - Waiting and input

    /// Returns at once when the label is already shown; otherwise waits up to 15 s for it.
    private func waitForLabel(_ element: XCUIElement, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        if element.exists && element.label == label {
            return
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(label) should be showing.", file: file, line: line)
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 15), .completed,
                       "Expected “\(label)”, found “\(element.exists ? element.label : "nothing")”.", file: file, line: line)
    }

    /// Waits up to 15 s for the element to show `expected`, compared as `normalized` compares.
    private func waitForText(_ element: XCUIElement, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let wanted = Self.normalized(expected)
        XCTAssertTrue(element.waitForExistence(timeout: 15), "“\(wanted)” should be showing.", file: file, line: line)
        let deadline = Date().addingTimeInterval(15)
        var shown = element.exists ? Self.normalized(element.label) : ""
        while shown != wanted && Date() < deadline {
            waitQuietly(0.25)
            shown = element.exists ? Self.normalized(element.label) : ""
        }
        XCTAssertEqual(shown, wanted, "The approved words.", file: file, line: line)
    }

    private func waitForPanel(_ panel: String, _ room: RoomUI, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(room.element(panel).waitForExistence(timeout: 10), "\(panel) opens.", file: file, line: line)
        settle()
    }

    private func waitFor(_ element: XCUIElement, enabled: Bool) -> Bool {
        if element.exists && element.isEnabled == enabled {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        if element.exists && element.isSelected == selected {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitForFocus(_ field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter.wait(for: [focused], timeout: 10) == .completed
    }

    @discardableResult
    private func waitForAbsence(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        if !element.exists {
            return true
        }
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    private func tapKeyboardDone(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "guestList.keyboardDone", "Done")).firstMatch
        if done.waitForExistence(timeout: 10) {
            done.tap()
            waitForAbsence(app.keyboards.firstMatch)
        } else {
            XCTFail("Done is offered above the keyboard.")
        }
    }

    /// Long enough for a 240-ms dissolve to finish, so nothing is read half-way through one. Not
    /// shortened by `PROXIMEET_SHORT_HOLDS`.
    private func settle() {
        waitQuietly(0.4)
    }

    /// Waits without asserting anything: a waiter with no delegate, on an expectation nobody fulfils.
    /// Not `hold`, which `PROXIMEET_SHORT_HOLDS` shortens.
    private func waitQuietly(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "quiet")], timeout: seconds)
    }

    private static func pt(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func rect(_ rect: CGRect?) -> String {
        rect.map { NSCoder.string(for: $0) } ?? "none"
    }

    private static func point(_ point: CGPoint) -> String {
        "(\(pt(point.x)), \(pt(point.y)))"
    }

    // MARK: - Captures and holds

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachNote(_ note: String) {
        let attachment = XCTAttachment(string: note)
        attachment.name = "note"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// With `PROXIMEET_SHORT_HOLDS=1` (unrecorded runs), a hold is at most 0.6 s: longer than any
    /// 500 ms movement it waits for.
    private func hold(_ seconds: TimeInterval) {
        let short = ProcessInfo.processInfo.environment["PROXIMEET_SHORT_HOLDS"] == "1"
        let duration = short ? min(seconds, 0.6) : seconds
        let done = expectation(description: "Hold so the recording shows this state")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { done.fulfill() }
        wait(for: [done], timeout: duration + 1)
    }

    private func softly(_ checks: () -> Void) {
        continueAfterFailure = true
        checks()
        continueAfterFailure = false
    }

    // MARK: - What is drawn on screen
    //
    // In points at 440 × 956 and the default text size, from the approved board: People's two cards
    // of ivory paper (#F6F7F2) at y 391–561 and 577–747 (66:115), read at x 360–390, right of every
    // name, line and initials disc; with one sample blocked the remaining card moves to the first slot
    // and the second is ground (66:119, 66:122); with both blocked the first slot is the #111415 empty
    // card (66:125). Room notes' Jules note is a #111415 card at y 657–773 (66:116), read at x 36–46,
    // left of its words; blocked, that is ground, and the centred boundary line never reaches x 46.

    private static let ivory: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) >= 232 && max(r, g, b) - min(r, g, b) <= 14 }
    private static let ground: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) <= 16 }
    private static let tileFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 12 && r <= 24 && g >= 15 && g <= 28 && b >= 16 && b <= 30 }

    /// The visible samples' cards are drawn, and a blocked sample's slot is not.
    private func softlyCardsDrawn(_ app: XCUIApplication, cards: Int, _ state: String) {
        guard app.frame.size == CGSize(width: 440, height: 956) else { return }
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let first = shot.fraction(in: CGRect(x: 360, y: 412, width: 30, height: 70), where: Self.ivory)
            let second = shot.fraction(in: CGRect(x: 360, y: 598, width: 30, height: 70), where: Self.ivory)
            attachNote(String(format: "%@: card paper drawn in the first slot %.2f, the second %.2f.", state, first, second))
            if cards >= 1 {
                XCTAssertGreaterThan(first, 0.9, "\(state): the first card is drawn (\(first)).")
            } else {
                XCTAssertLessThan(first, 0.05, "\(state): no card is drawn with both samples blocked (\(first)).")
            }
            if cards >= 2 {
                XCTAssertGreaterThan(second, 0.9, "\(state): the second card is drawn (\(second)).")
            } else {
                XCTAssertLessThan(second, 0.05, "\(state): nothing is drawn where a blocked sample's card was (\(second)).")
            }
        }
    }

    /// Jules's public note is drawn while he is visible, and nothing is drawn there once he is blocked.
    private func softlyNoteDrawn(_ app: XCUIApplication, present: Bool, _ state: String) {
        guard app.frame.size == CGSize(width: 440, height: 956) else { return }
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let area = CGRect(x: 36, y: 690, width: 10, height: 55)
            let card = shot.fraction(in: area, where: Self.tileFill)
            let empty = shot.fraction(in: area, where: Self.ground)
            attachNote(String(format: "%@: Jules's note card drawn %.2f, ground %.2f.", state, card, empty))
            if present {
                XCTAssertGreaterThan(card, 0.9, "\(state): Jules's note is drawn (\(card)).")
            } else {
                XCTAssertGreaterThan(empty, 0.9, "\(state): nothing is drawn where Jules's note was (\(empty)).")
            }
        }
    }
}

// MARK: - Fixtures and facts

/// The approved Room copy (`RoomCopy`), written out; lines joined by a space where a headline reads as
/// one element (the comparison reads any line break as a space).
private enum RoomText {
    static let entryHeadline = "Come in.\nStay yourself."
    static let entrySupport = "Try the Room with fictional people."
    static let entrySession = "Fictional venue · demo until 10 pm"
    static let entryBoundary = "This demo does not verify a venue visit\nor make you visible."
    static let enter = "Enter room demo"
    static let entryBack = "Back"
    static let compactSession = "Demo session · until 10 pm"
    static let envelope = "Introductions. A little privacy comes first."
    static let waitingHeadline = "A little privacy.\nBefore a hello."
    static let waitingExplanation = "Introductions appear only when a venue session has enough people checked in."
    static let demoControl = "DEMO CONTROL"
    static let showPopulated = "Show populated example"
    static let leave = "Leave and disappear"
    static let tabs = "Room sections"
    static let peopleTab = "People"
    static let notesTab = "Room notes"
    static let peopleFraming = "SAMPLE INTRODUCTIONS"
    static let notesFraming = "READ-ONLY DEMO NOTES"
    static let unblockedBoundary = "Fictional cards. Nothing is sent."
    static let blockedBoundary = "Your demo blocks remain applied."
    static let emptyTitle = "No sample introductions\nto show."
    static let emptyExplanation = "Your demo blocks are still applied."
    static let hiddenNotesBoundary = "Blocked sample notes stay hidden."
    static let hostLabel = "HOST NOTE · COMMON GROUND"
    static let hostMessage = "Keep it kind. A hello is always optional."
    static let icebreakerLabel = "A SMALL ICEBREAKER"
    static let icebreaker = "What’s a small place that feels like home?"
    static let profileTitle = "Room"
    static let profileLabel = "FICTIONAL PROFILE"
    static let howWavesWork = "How Waves work"
    static let backToPeople = "Back to people"
    static let sameIntent = "Waves stay within your selected intent."
    static let overlayLabel = "DEMO PREVIEW"
    static let safetyTitle = "Your space.\nYour choice."
    static let safetyExplanation =
        "Open a sample card to block or preview a report. Blocking hides its introduction and public notes in this demo."
    static let close = "Close"
    static let actorSafetyExplanation = "Blocking hides this fictional person’s card and public notes from the current demo."
    static let previewReport = "Preview report"
    static let actorSafetyBack = "Back"
    static let reportExplanation = "Choose a sample reason.\nExample only — nothing is submitted."
    static let closePreview = "Close preview"
    static let waveTitle = "A Wave is\nan invitation."
    static let waveExplanation = "Chat opens only after the other person accepts."
    static let waveScope = "Sending Waves comes in the next preview."
    static let backToProfile = "Back to profile"
    static let endedStatus = "DEMO SESSION ENDED"
    static let endedHeadline = "You’ve left\nthe room."
    static let endedExplanation = "Sample cards and notes are now hidden.\nA new demo requires an explicit restart."
    static let returnToPlaces = "Return to Places"
}

/// A fictional sample as approved (`RoomActor`).
private struct SampleActor {
    let key: String
    let name: String
    let initials: String
    let intent: String
    /// "[Intent] · [Approach]", the sample's own.
    let line: String
    let introduction: String
    let quote: String
    let interests: [String]
    /// The sample's own approach, as its profile says it to a same-intent guest.
    let approach: String
    /// The public sample note (Jules's only).
    let note: String?
}

private struct ReportReason {
    let key: String
    let title: String
    let variant: String
}

/// The panel containers' identifiers.
private enum Panel {
    static let globalSafety = "roomPanel.globalSafety"
    static let waveInfo = "roomPanel.waveInfo"

    static func actorSafety(_ actor: String) -> String { "roomPanel.actorSafety.\(actor)" }
    static func report(_ actor: String) -> String { "roomPanel.report.\(actor)" }
}

/// What a Room state shows, for its checks.
private enum Shown {
    case entry
    case waiting
    case ended
    case people(blocked: Set<String>)
    case notes(blocked: Set<String>)
    case profile(actor: String, blocked: Set<String>)
    case globalSafety
    case actorSafety(actor: String, blocked: Set<String>)
    case report(actor: String, reason: String?)
    case waveInfo
}

/// One Room fixture launch (`DebugFixtures.RoomFixture`): the stage, then the blocks in the order
/// given, the tab, the profile, the panel and the report's reason, applied as a guest applies them.
private struct RoomState {
    var key: String
    var stage: String
    var blocked: String? = nil
    var tab: String? = nil
    var profile: String? = nil
    var panel: String? = nil
    var reason: String? = nil
    var shown: Shown

    static var entry: RoomState { RoomState(key: "entry", stage: "room-entry", shown: .entry) }
    static var waiting: RoomState { RoomState(key: "waiting", stage: "room-waiting", shown: .waiting) }
    static var populated: RoomState { RoomState(key: "people-0", stage: "room-populated", shown: .people(blocked: [])) }

    var arguments: [String] {
        var arguments = ["-ProximeetFixture", stage]
        if let blocked { arguments += ["-ProximeetRoomBlocked", blocked] }
        if let tab { arguments += ["-ProximeetRoomTab", tab] }
        if let profile { arguments += ["-ProximeetRoomProfile", profile] }
        if let panel { arguments += ["-ProximeetRoomPanel", panel] }
        if let reason { arguments += ["-ProximeetRoomReason", reason] }
        return arguments
    }
}

/// One largest-text state: its texts (with the Figma box height each must outgrow; 0 to only reach
/// it) and its buttons, top to bottom, and the panel they sit in, if any.
private struct LargestCheck {
    var name: String
    var state: RoomState
    var band = "social"
    var approach = "chatFirst"
    var container: String? = nil
    var texts: [(id: String, figma: CGFloat)] = []
    var buttons: [String] = []
}

/// One element of a tree snapshot.
private struct RoomNode {
    let identifier: String
    let label: String
    let value: String
    let type: XCUIElement.ElementType
}

/// One reading for `reveal`.
private struct RevealLook {
    var found = false
    var target = CGRect.zero
    var screen = CGRect.zero
    /// The scroll view that holds the target, if any.
    var scroller: CGRect?
    /// The top of the fixed bar below that scroll view, if any.
    var barTop: CGFloat?
    var controls: [CGRect] = []
}

/// One element of a reading for `reveal`: where it is, and the scroll view it moves with.
private struct RevealPlaced {
    let frame: CGRect
    let scroller: CGRect?
    let identifier: String
}

@MainActor
private struct RevealEntry {
    let node: any XCUIElementSnapshot
    let scroller: CGRect?
}

// MARK: - Screens

/// The Room's elements, by identifier (the contract's `room.*`, `roomEntry.*`, `roomWaiting.*`,
/// `roomProfile.*`, `roomPanel.*` and `roomEnded.*`).
@MainActor
private struct RoomUI {
    let app: XCUIApplication

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// An element inside one panel, found by a query scoped to that panel's container.
    func inPanel(_ panel: String, _ identifier: String) -> XCUIElement {
        element(panel).descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var screen: XCUIElement { element("room.screen") }
    var brand: XCUIElement { element("room.brand") }
    var demoBadge: XCUIElement { element("room.demoBadge") }
    var safety: XCUIElement { element("room.safety") }
    var leave: XCUIElement { element("room.leave") }
    var venue: XCUIElement { element("room.venue") }
    var venuePreference: XCUIElement { element("room.venue.preference") }

    var entryHeadline: XCUIElement { element("roomEntry.headline") }
    var entrySupport: XCUIElement { element("roomEntry.support") }
    var entryVenue: XCUIElement { element("roomEntry.venue") }
    var entryPreference: XCUIElement { element("roomEntry.preference") }
    var entryBoundary: XCUIElement { element("roomEntry.boundary") }
    var enter: XCUIElement { element("roomEntry.enter") }
    var entryBack: XCUIElement { element("roomEntry.back") }

    var envelope: XCUIElement { element("roomWaiting.envelope") }
    var waitingHeadline: XCUIElement { element("roomWaiting.headline") }
    var waitingExplanation: XCUIElement { element("roomWaiting.explanation") }
    var demoControl: XCUIElement { element("roomWaiting.demoControl") }
    var showPopulated: XCUIElement { element("roomWaiting.showPopulated") }

    var tabs: XCUIElement { element("room.tabs") }
    func tab(_ key: String) -> XCUIElement { element("room.tab.\(key)") }
    var peopleFraming: XCUIElement { element("room.peopleFraming") }
    func card(_ actor: String) -> XCUIElement { element("room.card.\(actor)") }
    var boundary: XCUIElement { element("room.boundary") }
    var empty: XCUIElement { element("room.empty") }
    var emptyTitle: XCUIElement { element("room.empty.title") }
    var emptyExplanation: XCUIElement { element("room.empty.explanation") }

    var notesFraming: XCUIElement { element("room.notesFraming") }
    var hostNote: XCUIElement { element("room.note.host") }
    var icebreaker: XCUIElement { element("room.note.icebreaker") }
    var julesNote: XCUIElement { element("room.note.public.jules") }
    var julesNoteMore: XCUIElement { element("room.note.public.jules.more") }
    var hiddenNotesBoundary: XCUIElement { element("room.notes.hiddenBoundary") }

    var profileBack: XCUIElement { element("roomProfile.back") }
    var profileTitle: XCUIElement { element("roomProfile.title") }
    var profileSafety: XCUIElement { element("roomProfile.safety") }
    var profileCard: XCUIElement { element("roomProfile.card") }
    var profileLabel: XCUIElement { element("roomProfile.label") }
    var profileName: XCUIElement { element("roomProfile.name") }
    var profileLine: XCUIElement { element("roomProfile.line") }
    var profileAbout: XCUIElement { element("roomProfile.about") }
    var profileInterests: XCUIElement { element("roomProfile.interests") }
    var profileBoundary: XCUIElement { element("roomProfile.boundary") }
    var profileAction: XCUIElement { element("roomProfile.action") }

    func reason(_ key: String) -> XCUIElement { element("room.report.reason.\(key)") }

    var endedEnvelope: XCUIElement { element("roomEnded.envelope") }
    var endedStatus: XCUIElement { element("roomEnded.status") }
    var endedHeadline: XCUIElement { element("roomEnded.headline") }
    var endedExplanation: XCUIElement { element("roomEnded.explanation") }
    var returnToPlaces: XCUIElement { element("roomEnded.returnToPlaces") }
}

/// Places' elements the Room tests need: browsing (`places.*`), a detail (`place.*`) and the
/// explanation (`explanation.*`).
@MainActor
private struct RoomPlaces {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var headline: XCUIElement { element("places.headline") }
    var secondary: XCUIElement { app.buttons["places.secondary"] }
    func tab(_ category: String) -> XCUIElement { app.buttons["places.tab.\(category)"] }
    var ticketName: XCUIElement { element("places.ticket.name") }
    var viewPlace: XCUIElement { app.buttons["places.viewPlace"] }
    var placeName: XCUIElement { element("place.name") }
    var placePrimary: XCUIElement { app.buttons["place.primary"] }
    var placeBoundary: XCUIElement { element("place.boundary") }
    var explanationHeadline: XCUIElement { element("explanation.headline") }
    var explanationPrimary: XCUIElement { app.buttons["explanation.primary"] }
}

@MainActor
private struct RoomSignal {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.headline").firstMatch }
    var summary: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.summary").firstMatch }
    var primary: XCUIElement { app.buttons["signal.primary"] }

    func row(_ approach: String) -> XCUIElement { app.buttons["signal.approach.\(approach)"] }
}

@MainActor
private struct RoomWristband {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch }
    var primary: XCUIElement { app.buttons["wristband.primary"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

@MainActor
private struct RoomGuestList {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.headline").firstMatch }
    var name: XCUIElement { app.textFields["guestList.name"] }
    var opener: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.opener").firstMatch }
    var coffee: XCUIElement { app.buttons["guestList.interest.coffee"] }
    var primary: XCUIElement { app.buttons["guestList.primary"] }
}

@MainActor
private struct RoomPass {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
}

/// One screenshot's pixels, addressed in points.
@MainActor
private struct RenderedScreen {
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int
    private let scale: CGFloat

    init?(_ app: XCUIApplication) {
        guard let image = app.screenshot().image.cgImage, app.frame.width > 0 else {
            XCTFail("No screenshot to check what is drawn.")
            return nil
        }
        width = image.width
        height = image.height
        scale = CGFloat(image.width) / app.frame.width
        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            XCTFail("The screenshot could not be read.")
            return nil
        }
        pixels = buffer
    }

    /// The fraction of pixels in `rect` passing `test`.
    func fraction(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> Double {
        let x0 = max(0, Int((rect.minX * scale).rounded())), x1 = min(width, Int((rect.maxX * scale).rounded()))
        let y0 = max(0, Int((rect.minY * scale).rounded())), y1 = min(height, Int((rect.maxY * scale).rounded()))
        guard x0 < x1, y0 < y1 else { return 0 }
        var total = 0, passing = 0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let index = (y * width + x) * 4
                total += 1
                if test(pixels[index], pixels[index + 1], pixels[index + 2]) {
                    passing += 1
                }
            }
        }
        return total > 0 ? Double(passing) / Double(total) : 0
    }
}
