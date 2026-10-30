import UIKit
import XCTest

/// Runtime review of the approved Wave (chapter 09): a bounded, local, explicitly fictional invitation
/// demo, opened from an eligible same-intent Room profile by "Preview Wave demo" (the menu, Figma 74:568)
/// and living inside the Room run that opened it. Two separate examples per start: outgoing (the viewer
/// sends, 74:569 → 74:570 → 74:571) and incoming (the viewer alone may accept, 74:572 → 74:574 / 74:573 /
/// 74:579), six closed screens, the Wave's own ended screen (74:578), seven overlays (74:580–74:586) and
/// four report variants (75:627 / 75:637 / 75:647 / 75:657).
///
/// Skipped unless the test runner's environment has `PROXIMEET_WAVE_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_WAVE_REVIEW=1` to xcodebuild; the Wave test plans set it). Real taps and real
/// edge swipes. The one recorded journey starts at Welcome with a typed, long Guest List name and its
/// captures start "wave-journey-"; every other test starts from a DEBUG fixture (`-ProximeetFixture
/// wave-… | room-populated`, a direct launch that reaches its state through the app's own Room and Wave
/// transitions, `DebugFixtures.WaveFixture`) and its captures end in "-fixture".
///
/// What the Wave must never do is checked in the accessibility tree as well as on screen: an outgoing
/// example never offers Accept and an incoming one offers it only while pending; nothing returns a sent
/// invitation to its compose; a closed, blocked or ended screen names nobody; a block is the Room's own
/// (the same central set its People and notes filter by); Leave ends the Room and the Wave at once; under
/// an overlay nothing of the Wave page, the Room or Places is left in the tree, and no touch on an overlay
/// reaches a control beneath it. The founder's decisions of 30 September 2026 are checked too. The menu
/// wears the confirmation's chrome (75:119), and its visible Back returns to the still-valid Room that
/// opened it, as the edge swipe does. Once the counterpart is blocked, the menu keeps its three choices
/// with their own labels, disabled, beside one generic line that names nobody. The spoken direction line
/// says "you" for the viewer's identity, never for a matching name. Every copy string is the
/// approved `WaveCopy`, written out here (`WaveText`) rather than read from the app, with the reference
/// fixture's "Alex" and "Maya" replaced by the actual Guest List name and the actual counterpart (Maya for
/// Social, Jules for Business). The pixel checks run on the 440 × 956 iPhone at the default text size
/// only, where the approved board (`wave-review.png`) fixes what is drawn where.
@MainActor
final class WaveReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_WAVE_REVIEW"
    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    private static let reduceMotionPreview = ["-ProximeetReduceMotionPreview", "YES"]

    /// 44 pt, less floating-point error, for every 44-pt target check (Room build 6ab88011 measured a
    /// 44-pt Places tab as 43.99999999999997 once a fractional scroll offset had moved it).
    private static let minimumTarget: CGFloat = 44 - 1e-6

    /// The recorded journey's typed Guest List name: long and hyphenated, so the upper-case role lines
    /// ("OUTGOING · YOU ARE ALEXANDRIA-JOSEPHINE") have to wrap, and nothing of the reference "Alex" can
    /// pass for it. The fixtures' own example name is "Alex" (`PreviewFixtures.exampleIntroduction`).
    private static let typedName = "Alexandria-Josephine"

    /// Set by the recorded walkthrough alone: its holds stay full even with `PROXIMEET_SHORT_HOLDS=1`
    /// (a test plan gives every test in it one environment). XCTest makes a new instance for every test
    /// method, so this never leaks into another test.
    private var fullHolds = false

    /// When the last deliberate tap or swipe was made: the next one waits until 0.8 s have passed, so the
    /// window's repeat-tap guard (`RepeatTapGuard`) never reads two separate choices on the same spot
    /// (Send then Withdraw, Withdraw then Back to demo menu, all 376 × 56 at y 744) as one double tap.
    private var lastTap = Date.distantPast

    override func setUpWithError() throws {
        try RunBudget.begin(self)
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Wave review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("WAVE_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough (full journey)

    /// Full journey, recorded: the real route from Welcome with a typed, long name ("Alexandria-
    /// Josephine"), Social and Chat first; Places at Now; Common Ground's detail and explanation; Preview
    /// room demo, Enter room demo, Show populated example; Maya's profile, where the recording's trim
    /// starts (`WAVE_WALKTHROUGH_START`). Preview Wave demo: the menu, with the typed name in its role
    /// line. Outgoing: Start outgoing example, Send demo Wave (pending: no Accept anywhere, no Back to the
    /// compose), Withdraw Wave (closed, naming nobody), Back to demo menu. Incoming: Start incoming example,
    /// Accept Wave (the 800-ms join: "You both said yes."), About private chat and its Back (the same
    /// accepted result). Leave and disappear: the Wave's own ended screen (74:578), not the Room's.
    /// Return to Places: browsing at Now. Back: Signal with the same intent and approach, so the Wave
    /// never wrote the draft.
    ///
    /// Full holds whatever `PROXIMEET_SHORT_HOLDS` says (see `fullHolds`): this is the recorded run.
    func testRealJourneyFromTheRoomProfileThroughTheWaveAndBack() throws {
        fullHolds = true
        let app = launchWelcome()
        hold(0.8)
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = WaveGuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText(Self.typedName)
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText("Up for coffee.")
        tapKeyboardDone(app)
        guest.coffee.tap()
        hold(0.4)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(0.4)
        tapDistinctPrimary(guest.primary, label: "Continue preview")
        let band = WaveWristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("social").tap()
        XCTAssertTrue(waitFor(band.tile("social"), selected: true))
        hold(0.4)
        band.primary.tap()
        let signal = WaveSignal(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.row("chatFirst").tap()
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true))
        waitForLabel(signal.summary, "Social band · Chat first")
        hold(0.6)
        signal.primary.tap()

        // Places at Now, Common Ground's detail, its explanation, and the Room's two deliberate gates.
        let places = WavePlaces(app: app)
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
        hold(0.6)
        let room = WaveRoomUI(app: app)
        enterPopulatedRoom(places, room)
        hold(0.8)

        // Maya's profile: the one sample of the guest's own intent. The recording's trim starts here.
        let viewer = WaveViewer(name: Self.typedName, band: "social", approach: "chatFirst")
        openProfile(WaveCounterpart.maya, room)
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo, "The same-intent profile offers the Wave.")
        print("WAVE_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        hold(1.5)
        capture("wave-journey-01-maya-profile", app)

        // Preview Wave demo: the menu, for the typed name; nothing started.
        let ui = WaveUI(app: app)
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Journey menu")
        hold(1.5)
        capture("wave-journey-02-demo-menu", app)

        // Outgoing: the confirmation, then one Send.
        tapQuietly(ui.startOutgoing, app)
        waitForScreen(.outConfirm, ui)
        assertScreen(.outConfirm, viewer, ui, "Journey outgoing confirmation")
        hold(1.5)
        capture("wave-journey-03-out-confirm", app)
        tapQuietly(ui.send, app)
        waitForScreen(.outPending, ui)
        assertScreen(.outPending, viewer, ui, "Journey outgoing pending")
        XCTAssertFalse(ui.back.exists, "Pending has no Back: never back to the compose it replaced.")
        XCTAssertFalse(ui.send.exists, "Nothing sends twice.")
        hold(1.5)
        capture("wave-journey-04-out-pending", app)

        // Withdraw Wave: closed, naming nobody; Back to demo menu.
        tapQuietly(ui.withdraw, app)
        waitForScreen(.outWithdrawn, ui)
        assertScreen(.outWithdrawn, viewer, ui, "Journey outgoing withdrawn")
        hold(1.5)
        capture("wave-journey-05-out-withdrawn", app)
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Journey menu again")
        hold(1.2)
        capture("wave-journey-06-demo-menu-again", app)

        // Incoming: review, then the recipient's Accept and the ring join.
        tapQuietly(ui.startIncoming, app)
        waitForScreen(.inReview, ui)
        assertScreen(.inReview, viewer, ui, "Journey incoming review")
        hold(1.5)
        capture("wave-journey-07-in-review", app)
        tapQuietly(ui.accept, app)
        waitForScreen(.inAccepted, ui)
        waitQuietly(0.9)
        assertScreen(.inAccepted, viewer, ui, "Journey accepted")
        hold(1.5)
        capture("wave-journey-08-in-accepted", app)

        // About private chat: information only; its Back restores the same accepted result.
        tapQuietly(ui.aboutChat, app)
        waitForOverlay(.chatInfo, viewer, ui)
        assertOverlay(.chatInfo, over: .inAccepted, viewer, ui, "Journey chat information")
        hold(1.5)
        capture("wave-journey-09-chat-info", app)
        tapQuietly(ui.inPanel(WaveOverlayKind.chatInfo.container(viewer.counterpart), "wavePanel.back"), app)
        XCTAssertTrue(waitForAbsence(ui.element(WaveOverlayKind.chatInfo.container(viewer.counterpart))),
                      "Back closes the chat information.")
        waitForScreen(.inAccepted, ui)
        assertScreen(.inAccepted, viewer, ui, "Journey accepted, after the chat information")
        hold(0.8)

        // Leave and disappear: the Wave's own ended screen.
        tapQuietly(ui.leave, app)
        waitForScreen(.sessionEnded, ui)
        assertScreen(.sessionEnded, viewer, ui, "Journey ended")
        hold(1.5)
        capture("wave-journey-10-session-ended", app)

        // Return to Places: browsing at Now. Back: Signal, the draft intact.
        tapQuietly(ui.returnToPlaces, app)
        assertPlacesNow(places, "Journey Return to Places")
        hold(1.2)
        capture("wave-journey-11-places-now", app)
        XCTAssertEqual(places.secondary.label, "Back")
        tapQuietly(places.secondary, app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        waitForLabel(signal.summary, "Social band · Chat first")
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true), "The approach is kept: the Wave never wrote the draft.")
        hold(1.2)
        capture("wave-journey-12-back-to-signal", app)
        print("WAVE_WALKTHROUGH_END \(Date().timeIntervalSince1970)")
    }

    // MARK: - Business: Jules, and the re-entry

    /// Direct launch (fixture `room-populated`, Business, Okay to say hello, Jules's profile): the
    /// Business counterpart is Jules. Preview Wave demo; Start incoming example ("JULES → ALEX"; the
    /// invitation shows Jules's own "Business · Okay to say hello", the ticket the guest's); Accept; Demo
    /// cases over the accepted example; Show expired example invalidates even an accepted Wave ("Wave
    /// unavailable.", naming nobody); Back to demo menu; the menu's visible Back (44 × 44, hittable) to
    /// Jules's profile with the Room run still active, and Preview Wave demo again: a fresh menu; Start
    /// outgoing example and its chrome Back (the unsent confirmation is discarded to the menu); Leave: the
    /// Wave's ended screen; Return to Places at
    /// Now. Then the whole approved sequence again (View place, Preview check-in, Preview room demo: the
    /// entry, not the ended run; Enter room demo: waiting; Show populated example; Jules's profile) is the
    /// only way back to a Wave: a new menu, nothing of the old example.
    func testBusinessJulesJourneyAndReentry() throws {
        let viewer = WaveViewer(name: "Alex", band: "business", approach: "okayToSayHello")
        let app = launchRoom(viewer, profile: "jules")
        let room = WaveRoomUI(app: app)
        let ui = WaveUI(app: app)
        let places = WavePlaces(app: app)
        waitForLabel(room.profileName, "Jules")
        settle()
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo, "Jules shares the Business intent.")
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Business menu")
        capture("wave-business-demo-menu-fixture", app)

        tapQuietly(ui.startIncoming, app)
        waitForScreen(.inReview, ui)
        assertScreen(.inReview, viewer, ui, "Business review")
        capture("wave-business-in-review-fixture", app)
        tapQuietly(ui.accept, app)
        waitForScreen(.inAccepted, ui)
        waitQuietly(0.9)
        assertScreen(.inAccepted, viewer, ui, "Business accepted")
        capture("wave-business-in-accepted-fixture", app)

        tapQuietly(ui.demoCases, app)
        waitForOverlay(.conditions, viewer, ui)
        assertOverlay(.conditions, over: .inAccepted, viewer, ui, "Business conditions over the accepted example")
        capture("wave-business-conditions-accepted-fixture", app)
        tapQuietly(ui.inPanel(WaveOverlayKind.conditions.container(viewer.counterpart), "wavePanel.showExpired"), app)
        waitForScreen(.unavailable, ui)
        assertScreen(.unavailable, viewer, ui, "Business: an accepted example, expired")
        capture("wave-business-unavailable-fixture", app)

        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)

        // The menu's visible Back (75:119): Jules's profile, the Room run still active. Preview Wave demo
        // again opens a fresh menu: the closed example stays closed and nothing of it comes back.
        assertMenuBack(ui, "Business menu, after the expired example")
        tapQuietly(ui.back, app)
        XCTAssertTrue(waitForAbsence(ui.screen(.menu)), "The menu's Back closes the Wave.")
        waitForLabel(room.profileName, "Jules")
        XCTAssertTrue(room.element("room.screen").exists, "The menu's Back: the Room, still showing.")
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo,
                       "The menu's Back: Jules's profile, the Room run still active.")
        assertIdentifiers(absent: ["wave.", "wavePanel."], readTree(app), "After the menu's Back: no Wave")
        capture("wave-business-menu-back-to-profile-fixture", app)
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Business: Preview Wave demo again, after the menu's Back")

        tapQuietly(ui.startOutgoing, app)
        waitForScreen(.outConfirm, ui)
        assertScreen(.outConfirm, viewer, ui, "Business outgoing confirmation")
        capture("wave-business-out-confirm-fixture", app)
        tapQuietly(ui.back, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Business menu, after the confirmation's Back")

        tapQuietly(ui.leave, app)
        waitForScreen(.sessionEnded, ui)
        assertScreen(.sessionEnded, viewer, ui, "Business ended")
        capture("wave-business-session-ended-fixture", app)
        tapQuietly(ui.returnToPlaces, app)
        assertPlacesNow(places, "Business Return to Places")

        // Re-entry: the whole approved sequence, and a new run.
        tapQuietly(places.viewPlace, app)
        waitForLabel(places.placeName, "Common Ground")
        XCTAssertEqual(places.placePrimary.label, "Preview check-in")
        tapQuietly(places.placePrimary, app)
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        enterPopulatedRoom(places, room)
        openProfile(WaveCounterpart.jules, room)
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo)
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Business re-entry: a new menu")
        capture("wave-business-reentry-menu-fixture", app)
    }

    // MARK: - Both approaches for each intent

    /// Direct launches (fixture `wave-out-confirm` with `-ProximeetFixtureName`), Social ("Rowan") and
    /// Business ("Priya"), each with Chat first and with Okay to say hello. The venue ticket always shows
    /// the guest's own "[Name] · [Intent] · [Approach]"; the invitation always shows the counterpart's own
    /// intent and approach (Maya "Social · Chat first", Jules "Business · Okay to say hello"), so with
    /// different approaches nothing claims they match. Then the chrome's Back (the unsent example goes)
    /// and Start incoming example: the same two lines on the incoming review. Once per intent the
    /// counterpart's safety and its report preview are opened too (Jules's for Business).
    func testBothApproachesForEachIntent() throws {
        for (band, name) in [("social", "Rowan"), ("business", "Priya")] {
            for approach in ["chatFirst", "okayToSayHello"] {
                let viewer = WaveViewer(name: name, band: band, approach: approach)
                let key = "\(band)-\(approach)"
                let app = launchWave(WaveFixture(key: key, screen: .outConfirm, viewer: viewer))
                let ui = WaveUI(app: app)
                waitForScreen(.outConfirm, ui, timeout: 20)
                assertScreen(.outConfirm, viewer, ui, "\(key), outgoing confirmation")
                XCTAssertEqual(ui.venuePreference.label, viewer.preference, "\(key): the ticket is the guest's own.")
                XCTAssertEqual(ui.preference.label, viewer.counterpart.preferenceAccessibilityLabel,
                               "\(key): the spoken preference identifies the counterpart and their own values.")
                capture("wave-approach-\(key)-out-confirm-fixture", app)

                if approach == "chatFirst" {
                    checkCounterpartSafetyAndReport(over: .outConfirm, viewer, ui, key)
                }

                tapQuietly(ui.back, app)
                waitForScreen(.menu, ui)
                assertScreen(.menu, viewer, ui, "\(key), menu")
                tapQuietly(ui.startIncoming, app)
                waitForScreen(.inReview, ui)
                assertScreen(.inReview, viewer, ui, "\(key), incoming review")
                capture("wave-approach-\(key)-in-review-fixture", app)
                app.terminate()
            }
        }
    }

    /// The counterpart's safety from the chrome's shield, its unsent report (nothing selected, then a
    /// reason), Close preview (the safety again, a new preview unselected), Back: the same screen, with
    /// the invitation unchanged.
    private func checkCounterpartSafetyAndReport(over screen: WaveScreenKey, _ viewer: WaveViewer, _ ui: WaveUI,
                                                 _ key: String) {
        let app = ui.app
        let counterpart = viewer.counterpart
        let safety = WaveOverlayKind.counterpartSafety.container(counterpart)
        let report = WaveOverlayKind.report(nil).container(counterpart)
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, viewer, ui)
        assertOverlay(.counterpartSafety, over: screen, viewer, ui, "\(key), \(counterpart.name)'s safety")
        capture("wave-approach-\(key)-\(counterpart.key)-safety-fixture", app)
        tapQuietly(ui.inPanel(safety, "wavePanel.previewReport"), app)
        waitForOverlay(.report(nil), viewer, ui)
        assertOverlay(.report(nil), over: screen, viewer, ui, "\(key), report \(counterpart.name), new")
        selectReason("somethingElse", ui)
        assertOverlay(.report("somethingElse"), over: screen, viewer, ui, "\(key), report \(counterpart.name), a reason")
        capture("wave-approach-\(key)-report-\(counterpart.key)-fixture", app)
        tapQuietly(ui.inPanel(report, "wavePanel.closePreview"), app)
        XCTAssertTrue(waitForAbsence(ui.element(report)), "\(key): Close preview closes the report.")
        waitForOverlay(.counterpartSafety, viewer, ui)
        tapQuietly(ui.inPanel(safety, "wavePanel.previewReport"), app)
        waitForOverlay(.report(nil), viewer, ui)
        assertOverlay(.report(nil), over: screen, viewer, ui, "\(key), report \(counterpart.name), reopened: a new preview")
        tapQuietly(ui.inPanel(report, "wavePanel.closePreview"), app)
        XCTAssertTrue(waitForAbsence(ui.element(report)))
        waitForOverlay(.counterpartSafety, viewer, ui)
        tapQuietly(ui.inPanel(safety, "wavePanel.back"), app)
        XCTAssertTrue(waitForAbsence(ui.element(safety)), "\(key): Back closes \(counterpart.name)'s safety.")
        waitForScreen(screen, ui)
        assertScreen(screen, viewer, ui, "\(key), back from \(counterpart.name)'s safety")
    }

    // MARK: - The approved screens and overlays

    /// Direct launches at the default text size, run on the iPhone 17 Pro Max: the 12 approved screens
    /// (74:568–74:579), the menu once Maya is blocked (`wave-menu-blocked-…`: its three choices disabled
    /// beside the generic line, founder decision of 30 September 2026), the 7 overlays (global safety over
    /// the menu, Maya's safety and her report over the incoming review, the chat information and Demo
    /// cases over the accepted example, Demo cases over
    /// the outgoing pending and over the incoming review) and the four report variants (75:627 none, from
    /// the report launch; 75:637, 75:647 and 75:657, each its own launch). Each is checked (copy, who is
    /// named, the controls, the column) before it is captured as `wave-<state>-<width>pt-fixture`. Under
    /// every overlay one snapshot holds nothing of the Wave page, the Room or Places, checked softly so one
    /// leak still leaves every capture taken.
    func testCaptureApprovedScreensAndOverlays() throws {
        // The full capture matrix exceeded 900 s on the rented Mac. The local invocation raises
        // XCTest’s maximum to 1800 s; RunBudget still caps this at the whole-run time remaining.
        RunBudget.allow(1800, self)
        var shown: [String] = []
        for fixture in Self.approvedCaptures {
            let app = launchWave(fixture)
            let ui = WaveUI(app: app)
            XCTAssertTrue(readyElement(fixture, ui).waitForExistence(timeout: 20), "\(fixture.key) shows.")
            settle()
            if fixture.screen == .inAccepted {
                waitQuietly(0.6)
            }
            let width = Int(app.frame.width.rounded())
            let state = "\(fixture.key), \(width) pt"
            if let overlay = fixture.overlay {
                assertOverlay(overlay, over: fixture.screen, fixture.viewer, ui, state, softIsolation: true)
            } else {
                assertScreen(fixture.screen, fixture.viewer, ui, state, menuBlocked: fixture.menuBlocked)
            }
            softlyColumn(fixture, ui, state)
            capture("wave-\(fixture.key)-\(width)pt-fixture", app)
            if fixture.key == "report-maya" {
                capture("wave-report-reason-none-\(width)pt-fixture", app)
            }
            shown.append("wave-\(fixture.key)-\(width)pt-fixture")
            app.terminate()
        }
        attachNote("Captured \(shown.count) fixture launches: " + shown.joined(separator: ", ") + ".")
    }

    // MARK: - Duplicate and stale actions

    /// Direct launches. A double tap on Send demo Wave is one send: pending, never withdrawn by the second
    /// touch landing on Withdraw (same place, 376 × 56 at y 744). After Send there is no Back, no Send and
    /// no confirmation, and a completed back swipe changes nothing. A double tap on Accept Wave is one
    /// acceptance and opens nothing. Accept after "Show sender withdrawn" and after "Show expired
    /// example": Accept is gone from the tree, and a tap where it was cannot accept (it lands on the closed
    /// screen, or on whatever control now sits there). A back swipe on the incoming review changes
    /// nothing. On the same launch, with Maya's report open over her safety, a real tap where her Block
    /// was reaches nothing beneath the report: the report stays open, the review stays, nobody is blocked,
    /// and her safety offers Block again once the report closes. On the unsent confirmation both its
    /// visible Back and a back swipe return to the menu, and a double tap on its Back stops at the menu.
    func testDuplicateAndStaleActionsChangeNothing() throws {
        let viewer = WaveViewer.alex

        // Send, twice at once.
        var app = launchWave(WaveFixture(key: "out-confirm", screen: .outConfirm))
        var ui = WaveUI(app: app)
        waitForScreen(.outConfirm, ui, timeout: 20)
        bringIntoView(ui.send, app)
        ui.send.doubleTap()
        lastTap = Date()
        waitForScreen(.outPending, ui)
        waitQuietly(0.6)
        assertScreen(.outPending, viewer, ui, "After a double tap on Send")
        XCTAssertFalse(ui.screen(.outWithdrawn).exists, "The second touch did not withdraw it.")
        capture("wave-stale-double-send-fixture", app)
        // The compose is gone for good.
        XCTAssertFalse(ui.back.exists, "Pending has no Back.")
        XCTAssertFalse(ui.send.exists, "Nothing sends twice.")
        edgeSwipe(app, completing: true)
        waitQuietly(0.6)
        XCTAssertTrue(ui.screen(.outPending).exists, "A completed back swipe on pending changes nothing.")
        XCTAssertFalse(ui.screen(.outConfirm).exists, "Never back to the compose.")
        assertScreen(.outPending, viewer, ui, "Pending, after a back swipe")
        app.terminate()

        // Accept, twice at once.
        app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
        ui = WaveUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        bringIntoView(ui.accept, app)
        ui.accept.doubleTap()
        lastTap = Date()
        waitForScreen(.inAccepted, ui)
        waitQuietly(1.0)
        assertScreen(.inAccepted, viewer, ui, "After a double tap on Accept")
        capture("wave-stale-double-accept-fixture", app)
        edgeSwipe(app, completing: true)
        waitQuietly(0.6)
        assertScreen(.inAccepted, viewer, ui, "Accepted, after a back swipe (no Back there)")
        app.terminate()

        // Accept after the sender withdrew, and after the example expired.
        for (condition, closed) in [("wavePanel.showSenderWithdrawn", WaveScreenKey.inWithdrawn),
                                    ("wavePanel.showExpired", WaveScreenKey.unavailable)] {
            app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
            ui = WaveUI(app: app)
            waitForScreen(.inReview, ui, timeout: 20)
            bringIntoView(ui.accept, app)
            let acceptFrame = ui.accept.frame
            let where_ = CGPoint(x: acceptFrame.midX, y: acceptFrame.midY)
            tapQuietly(ui.demoCases, app)
            waitForOverlay(.conditions, viewer, ui)
            tapQuietly(ui.inPanel(WaveOverlayKind.conditions.container(viewer.counterpart), condition), app)
            waitForScreen(closed, ui)
            assertScreen(closed, viewer, ui, "Accept after \(condition)")
            let after = staleTap(at: where_, ui)
            XCTAssertNotEqual(after, .inAccepted, "A tap where Accept was, after \(condition), accepts nothing.")
            XCTAssertTrue(after == closed || after == .menu,
                          "After \(condition), a tap where Accept was leaves \(closed.rawValue) (or meets Back to demo "
                          + "menu); it shows \(after?.rawValue ?? "no Wave screen").")
            attachNote("A tap at \(Self.point(where_)), where Accept was, after \(condition): "
                       + "\(after?.rawValue ?? "no Wave screen").")
            capture("wave-stale-accept-after-\(closed.rawValue)-fixture", app)
            app.terminate()
        }

        // The incoming review: no Back, so a back swipe (cancelled or completed) changes nothing.
        app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
        ui = WaveUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        edgeSwipe(app, completing: false)
        waitQuietly(0.6)
        edgeSwipe(app, completing: true)
        waitQuietly(0.6)
        assertScreen(.inReview, viewer, ui, "Review, after both back swipes")

        // The same launch: the report preview takes every touch aimed below it (founder decision, 30
        // September 2026). Maya's Block is measured on her safety, the report opened over it, and a real tap
        // lands where Block was: it reaches nothing underneath, so nothing is blocked and the review stays.
        let safety = WaveOverlayKind.counterpartSafety.container(viewer.counterpart)
        let report = WaveOverlayKind.report(nil).container(viewer.counterpart)
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, viewer, ui)
        let block = ui.inPanel(safety, "wavePanel.block")
        bringIntoView(block, app)
        let blockFrame = block.frame
        let blockPoint = CGPoint(x: blockFrame.midX, y: blockFrame.midY)
        tapQuietly(ui.inPanel(safety, "wavePanel.previewReport"), app)
        waitForOverlay(.report(nil), viewer, ui)
        assertOverlay(.report(nil), over: .inReview, viewer, ui, "Maya's report, before a tap where her Block was")
        let reportFrame = ui.element(report).frame
        let under = staleTap(at: blockPoint, ui)
        XCTAssertTrue(ui.element(report).exists, "A tap where Block was, under the report: the report is still open.")
        XCTAssertEqual(under, .inReview, "A tap where Block was, under the report, changes the Wave screen to "
                       + "\(under?.rawValue ?? "no Wave screen"): it must stay the review, with nobody blocked.")
        let nodes = readTree(app)
        XCTAssertFalse(nodes.contains { $0.identifier == safety || $0.identifier == "wavePanel.block" },
                       "Under the report, Maya's safety and its Block are not in the tree at all.")
        let selected = WaveText.reasons.first { ui.inPanel(report, "wave.report.reason.\($0.0)").isSelected }
        attachNote("A tap at \(Self.point(blockPoint)), where Block was, with the report open (card "
                   + "\(Self.rect(reportFrame))): it landed on \(reportFrame.contains(blockPoint) ? "the report card" : "the dim")"
                   + " and \(selected.map { "selected “\($0.1)”, the report's own control there" } ?? "changed nothing").")
        capture("wave-stale-block-under-report-fixture", app)
        tapQuietly(ui.inPanel(report, "wavePanel.closePreview"), app)
        XCTAssertTrue(waitForAbsence(ui.element(report)), "Close preview closes the report.")
        waitForOverlay(.counterpartSafety, viewer, ui)
        assertButton(ui.inPanel(safety, "wavePanel.block"), "Block Maya in demo", "Maya's safety, after the tap under her report")
        tapQuietly(ui.inPanel(safety, "wavePanel.back"), app)
        XCTAssertTrue(waitForAbsence(ui.element(safety)), "Back closes Maya's safety.")
        waitForScreen(.inReview, ui)
        assertScreen(.inReview, viewer, ui, "The review after a tap under the report: Maya is not blocked")
        app.terminate()

        // The unsent confirmation: its visible Back, and a back swipe, each return to the menu.
        app = launchWave(WaveFixture(key: "out-confirm", screen: .outConfirm))
        ui = WaveUI(app: app)
        waitForScreen(.outConfirm, ui, timeout: 20)
        assertButton(ui.back, WaveText.back, "The confirmation's chrome Back")
        tapQuietly(ui.back, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "The confirmation's Back")
        tapQuietly(ui.startOutgoing, app)
        waitForScreen(.outConfirm, ui)
        edgeSwipe(app, completing: true)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "A back swipe from the confirmation")
        // A double tap on the confirmation's Back: the menu's Back now sits in the same place, and the
        // second touch of a rapid multi-tap is swallowed (RepeatTapGuard), so it stops at the menu and never
        // leaves the Wave. Two deliberate, separate taps would leave it, as a stacked Back does.
        tapQuietly(ui.startOutgoing, app)
        waitForScreen(.outConfirm, ui)
        bringIntoView(ui.back, app)
        ui.back.doubleTap()
        lastTap = Date()
        waitForScreen(.menu, ui)
        waitQuietly(0.6)
        assertScreen(.menu, viewer, ui, "After a double tap on the confirmation's Back")
        XCTAssertFalse(app.buttons["roomProfile.action"].exists, "The second touch did not leave the Wave.")
    }

    // MARK: - Roles never change

    /// Direct launch (fixture `wave-menu`), then only real taps. Outgoing: no Accept on the confirmation,
    /// under its counterpart's safety, once pending, under its Demo cases (which offers only the expired
    /// example) or once withdrawn. Incoming: Accept while pending; none once declined; a new start is a new
    /// pending example with Accept again; none once accepted, under Demo cases (no "Show sender withdrawn"
    /// after acceptance) or once expired. The no-allowance example offers neither Send nor Accept and
    /// states no number. Then a second launch (fixture `wave-in-review`, `-ProximeetFixtureName Maya`): a
    /// guest named like the counterpart is still the recipient, and the spoken direction line says "you" by
    /// identity with the typed name kept: "From Maya to you (Maya). Incoming.", then, accepted, "Maya and
    /// you (Maya). Incoming demo."
    func testRolesNeverChange() throws {
        let viewer = WaveViewer.alex
        let app = launchWave(WaveFixture(key: "demo-menu", screen: .menu))
        let ui = WaveUI(app: app)
        waitForScreen(.menu, ui, timeout: 20)

        // Outgoing: the viewer is the sender throughout.
        tapQuietly(ui.startOutgoing, app)
        waitForScreen(.outConfirm, ui)
        assertScreen(.outConfirm, viewer, ui, "Outgoing confirmation")
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, viewer, ui)
        assertOverlay(.counterpartSafety, over: .outConfirm, viewer, ui, "Maya's safety over the confirmation")
        tapQuietly(ui.inPanel(WaveOverlayKind.counterpartSafety.container(viewer.counterpart), "wavePanel.back"), app)
        waitForScreen(.outConfirm, ui)
        XCTAssertTrue(waitForAbsence(ui.element(WaveOverlayKind.counterpartSafety.container(viewer.counterpart))))
        tapQuietly(ui.send, app)
        waitForScreen(.outPending, ui)
        assertScreen(.outPending, viewer, ui, "Outgoing pending")
        tapQuietly(ui.demoCases, app)
        waitForOverlay(.conditions, viewer, ui)
        assertOverlay(.conditions, over: .outPending, viewer, ui, "Demo cases over the outgoing pending")
        tapQuietly(ui.inPanel(WaveOverlayKind.conditions.container(viewer.counterpart), "wavePanel.back"), app)
        XCTAssertTrue(waitForAbsence(ui.element(WaveOverlayKind.conditions.container(viewer.counterpart))))
        waitForScreen(.outPending, ui)
        tapQuietly(ui.withdraw, app)
        waitForScreen(.outWithdrawn, ui)
        assertScreen(.outWithdrawn, viewer, ui, "Outgoing withdrawn")
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)

        // Incoming: the viewer is the recipient; Accept only while pending.
        tapQuietly(ui.startIncoming, app)
        waitForScreen(.inReview, ui)
        assertScreen(.inReview, viewer, ui, "Incoming review")
        tapQuietly(ui.decline, app)
        waitForScreen(.inDeclined, ui)
        assertScreen(.inDeclined, viewer, ui, "Incoming declined")
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        tapQuietly(ui.startIncoming, app)
        waitForScreen(.inReview, ui)
        assertScreen(.inReview, viewer, ui, "A new incoming example, pending again")
        tapQuietly(ui.accept, app)
        waitForScreen(.inAccepted, ui)
        waitQuietly(0.9)
        assertScreen(.inAccepted, viewer, ui, "Incoming accepted")
        tapQuietly(ui.demoCases, app)
        waitForOverlay(.conditions, viewer, ui)
        assertOverlay(.conditions, over: .inAccepted, viewer, ui, "Demo cases over the accepted example")
        tapQuietly(ui.inPanel(WaveOverlayKind.conditions.container(viewer.counterpart), "wavePanel.showExpired"), app)
        waitForScreen(.unavailable, ui)
        assertScreen(.unavailable, viewer, ui, "The accepted example, expired")
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)

        // No allowance: no Send, no Accept, no number.
        tapQuietly(ui.noAllowance, app)
        waitForScreen(.allowanceUnavailable, ui)
        assertScreen(.allowanceUnavailable, viewer, ui, "The no-allowance example")
        capture("wave-roles-allowance-unavailable-fixture", app)
        app.terminate()

        // A guest who typed the counterpart's own name (Social, "Maya", meeting the sample Maya): "you" is
        // the viewer's identity, never a matching name, and the actual Guest List name is kept as typed.
        // The review reads "From Maya to you (Maya). Incoming."; accepted, "Maya and you (Maya). Incoming demo."
        let namesake = WaveViewer(name: "Maya", band: "social", approach: "chatFirst")
        let named = launchWave(WaveFixture(key: "in-review-namesake", screen: .inReview, viewer: namesake))
        let namedUI = WaveUI(app: named)
        waitForScreen(.inReview, namedUI, timeout: 20)
        assertScreen(.inReview, namesake, namedUI, "A guest named Maya: the incoming review")
        capture("wave-roles-namesake-in-review-fixture", named)
        tapQuietly(namedUI.accept, named)
        waitForScreen(.inAccepted, namedUI)
        waitQuietly(0.9)
        assertScreen(.inAccepted, namesake, namedUI, "A guest named Maya: accepted")
    }

    // MARK: - Interrupted acceptance

    /// Direct launches (fixture `wave-in-review`). Accept Wave, then Leave and disappear at once (its
    /// point read before Accept, so the second tap needs no lookup): the Wave's ended screen, never the
    /// joined result, and nothing of Maya or the invitation left in the tree. Accept Wave, then the shield
    /// and Block Maya in demo as fast as the panel allows: the generic blocked screen, never joined; and
    /// the menu after it offers no new start (its three choices disabled, naming nobody). Each note says
    /// how long after Accept the interruption came
    /// (the join is 800 ms), because an XCUITest tap may wait for the app to settle.
    func testInterruptedAcceptanceNeverEndsJoined() throws {
        let viewer = WaveViewer.alex

        // Accept, then Leave.
        var app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
        var ui = WaveUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        bringIntoView(ui.accept, app)
        let leaveFrame = ui.leave.frame
        let leavePoint = CGPoint(x: leaveFrame.midX, y: leaveFrame.midY)
        waitQuietly(0.8)
        ui.accept.tap()
        let accepted = Date()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: leavePoint.x, dy: leavePoint.y)).tap()
        let leaveGap = Date().timeIntervalSince(accepted)
        lastTap = Date()
        waitForScreen(.sessionEnded, ui, timeout: 15)
        assertScreen(.sessionEnded, viewer, ui, "Accept, then Leave at once")
        XCTAssertFalse(ui.screen(.inAccepted).exists, "Leave outranks the join.")
        attachNote(String(format: "Accept, then Leave: the Leave tap returned %.0f ms after Accept's (the join is 800 ms), "
                          + "so it came %@ the ring motion.", leaveGap * 1000, leaveGap < 0.8 ? "during" : "after"))
        capture("wave-interrupted-accept-leave-fixture", app)
        tapQuietly(ui.returnToPlaces, app)
        assertPlacesNow(WavePlaces(app: app), "Accept, then Leave, then Return to Places")
        app.terminate()

        // Accept, then Block.
        app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
        ui = WaveUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        bringIntoView(ui.accept, app)
        let shieldFrame = ui.safety.frame
        let shieldPoint = CGPoint(x: shieldFrame.midX, y: shieldFrame.midY)
        waitQuietly(0.8)
        ui.accept.tap()
        let tapped = Date()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: shieldPoint.x, dy: shieldPoint.y)).tap()
        let safety = WaveOverlayKind.counterpartSafety.container(viewer.counterpart)
        XCTAssertTrue(ui.element(safety).waitForExistence(timeout: 10), "The shield opens Maya's safety.")
        let block = ui.inPanel(safety, "wavePanel.block")
        XCTAssertTrue(block.waitForExistence(timeout: 5))
        block.tap()
        let blockGap = Date().timeIntervalSince(tapped)
        lastTap = Date()
        waitForScreen(.blocked, ui, timeout: 15)
        assertScreen(.blocked, viewer, ui, "Accept, then Block at once")
        XCTAssertFalse(ui.screen(.inAccepted).exists, "Block outranks the join.")
        attachNote(String(format: "Accept, then Block: the Block tap returned %.0f ms after Accept's (the join is 800 ms).",
                          blockGap * 1000))
        capture("wave-interrupted-accept-block-fixture", app)
        // Back to demo menu: no new start after the block. The three choices stay, disabled, beside one
        // generic line naming nobody, so nothing restores Maya.
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "The menu after Accept, then Block", menuBlocked: true)
    }

    // MARK: - Blocks, in both orders

    /// Business guest (Okay to say hello). Wave first (fixture `room-populated`, Jules's profile, then
    /// real taps): Preview Wave demo, Start incoming example, the shield, Block Jules in demo: "Connection
    /// blocked." naming nobody. Back to demo menu: the three choices keep their three distinct labels and
    /// are disabled, one generic "Connection blocked." line takes the boundary's place, nothing in the tree
    /// names Jules or Maya, and a real tap on each disabled choice changes nothing. The menu's visible Back
    /// returns to the Room's filtered People, the
    /// profile that opened the Wave being gone: Jules's card and his public note are gone, Maya remains,
    /// the host notes stay. Room first (a fresh launch): Jules blocked from his Room profile's safety,
    /// and the same People and Room notes; the Wave can no longer be reached for him (no card, no
    /// profile), and Maya, another intent, offers Back to people only. As a fixture, `wave-menu` with
    /// `-ProximeetRoomBlocked jules` stays on the filtered People with no Wave. Mixed order for a Social
    /// guest: Jules blocked in the Room first, then Maya from her Wave: both kept, the filtered empty card
    /// (that menu's outer Back taken by an edge swipe, the same Back's other path).
    func testBlocksInBothOrdersUseTheOneRoomSet() throws {
        let viewer = WaveViewer(name: "Alex", band: "business", approach: "okayToSayHello")

        // Wave first.
        var app = launchRoom(viewer, profile: "jules")
        var room = WaveRoomUI(app: app)
        var ui = WaveUI(app: app)
        waitForLabel(room.profileName, "Jules")
        settle()
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        tapQuietly(ui.startIncoming, app)
        waitForScreen(.inReview, ui)
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, viewer, ui)
        assertOverlay(.counterpartSafety, over: .inReview, viewer, ui, "Jules's safety over his invitation")
        let julesSafety = WaveOverlayKind.counterpartSafety.container(viewer.counterpart)
        assertButton(ui.inPanel(julesSafety, "wavePanel.block"), "Block Jules in demo", "Jules's safety")
        tapQuietly(ui.inPanel(julesSafety, "wavePanel.block"), app)
        waitForScreen(.blocked, ui)
        assertScreen(.blocked, viewer, ui, "Wave first: Jules blocked")
        capture("wave-blocks-wave-first-blocked-fixture", app)

        // Back to demo menu: the three choices keep their own labels, disabled, beside one generic line
        // that names nobody, and a real tap on each (by coordinate, as a finger would land) starts nothing.
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "Wave first: the menu after the block", menuBlocked: true)
        capture("wave-blocks-wave-first-menu-blocked-fixture", app)
        var taps: [String] = []
        for (id, label) in WaveText.menuChoices {
            guard reveal(id, app) else { continue }
            let choice = ui.element(id)
            XCTAssertFalse(choice.isEnabled, "Wave first: “\(label)” is disabled after the block.")
            let frame = choice.frame
            let point = CGPoint(x: frame.midX, y: frame.midY)
            let shown = staleTap(at: point, ui)
            XCTAssertEqual(shown, .menu, "Wave first: a tap on the disabled “\(label)” starts nothing; the Wave shows "
                           + "\(shown?.rawValue ?? "no Wave screen").")
            XCTAssertTrue(ui.menuBlocked.exists, "Wave first: after a tap on “\(label)”, still the blocked menu.")
            taps.append("“\(label)” at \(Self.point(point)): \(shown?.rawValue ?? "no Wave screen")")
        }
        assertScreen(.menu, viewer, ui, "Wave first: the blocked menu, after a tap on each disabled choice", menuBlocked: true)
        attachNote("Wave first, a tap on each disabled choice of the blocked menu: " + taps.joined(separator: "; ") + ".")

        // The menu's visible Back: the Room's filtered People, the profile that opened the Wave being gone.
        tapQuietly(ui.back, app)
        XCTAssertTrue(room.peopleFraming.waitForExistence(timeout: 10), "The menu's visible Back: the Room's filtered People.")
        XCTAssertTrue(waitForAbsence(ui.screen(.menu)))
        settle()
        assertRoomPeople(room, blocked: ["jules"], "Wave first, back in the Room")
        capture("wave-blocks-wave-first-people-fixture", app)
        let waveFirst = roomFingerprint(room, blocked: ["jules"], "Wave first")
        openProfile(WaveCounterpart.maya, room)
        XCTAssertEqual(room.profileAction.label, WaveText.backToPeople, "Maya is another intent: no Wave for her.")
        app.terminate()

        // Room first.
        app = launchRoom(viewer)
        room = WaveRoomUI(app: app)
        ui = WaveUI(app: app)
        XCTAssertTrue(room.card("jules").waitForExistence(timeout: 20))
        settle()
        openProfile(WaveCounterpart.jules, room)
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo)
        tapQuietly(room.profileSafety, app)
        let roomSafety = "roomPanel.actorSafety.jules"
        XCTAssertTrue(room.element(roomSafety).waitForExistence(timeout: 10), "Jules's Room safety opens.")
        settle()
        let roomBlock = room.inPanel(roomSafety, "roomPanel.block")
        XCTAssertEqual(roomBlock.label, "Block Jules in demo")
        tapQuietly(roomBlock, app)
        waitForLabel(room.boundary, WaveText.blockedBoundary)
        settle()
        assertRoomPeople(room, blocked: ["jules"], "Room first: Jules blocked")
        let roomFirst = roomFingerprint(room, blocked: ["jules"], "Room first")
        XCTAssertEqual(roomFirst, waveFirst, "Both orders end in the same People and Room notes: one central set.")
        attachNote("Wave first: \(waveFirst). Room first: \(roomFirst).")
        XCTAssertFalse(room.card("jules").exists, "No card, so no profile and no Preview Wave demo for Jules.")
        assertIdentifiers(absent: ["wave.", "roomProfile."], readTree(app), "Room first: nothing reaches Jules's Wave")
        openProfile(WaveCounterpart.maya, room)
        XCTAssertEqual(room.profileAction.label, WaveText.backToPeople)
        capture("wave-blocks-room-first-maya-profile-fixture", app)
        app.terminate()

        // Room first, as a fixture: the Wave fixture stops on the filtered People.
        app = launchWave(WaveFixture(key: "demo-menu-jules-blocked", screen: .menu, viewer: viewer, roomBlocked: "jules"))
        room = WaveRoomUI(app: app)
        XCTAssertTrue(room.peopleFraming.waitForExistence(timeout: 20), "A counterpart blocked first leaves the fixture on People.")
        settle()
        assertRoomPeople(room, blocked: ["jules"], "Fixture: Jules blocked in the Room first")
        app.terminate()

        // Mixed order, Social guest: Jules (another intent) in the Room first, then Maya from her Wave.
        let social = WaveViewer.alex
        app = launchWave(WaveFixture(key: "in-review-jules-blocked", screen: .inReview, viewer: social, roomBlocked: "jules"))
        room = WaveRoomUI(app: app)
        ui = WaveUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        assertScreen(.inReview, social, ui, "Maya's invitation, Jules already blocked in the Room")
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, social, ui)
        tapQuietly(ui.inPanel(WaveOverlayKind.counterpartSafety.container(social.counterpart), "wavePanel.block"), app)
        waitForScreen(.blocked, ui)
        assertScreen(.blocked, social, ui, "Mixed order: Maya blocked from her Wave")
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, social, ui, "Mixed order: the menu after Maya's block", menuBlocked: true)
        edgeSwipe(app, completing: true)
        XCTAssertTrue(room.peopleFraming.waitForExistence(timeout: 10))
        settle()
        assertRoomPeople(room, blocked: ["maya", "jules"], "Mixed order: both blocked, both kept")
        _ = roomFingerprint(room, blocked: ["maya", "jules"], "Mixed order")
        capture("wave-blocks-mixed-order-people-fixture", app)
    }

    // MARK: - Leave

    /// Direct launches, one per context a Leave is offered in: the eleven Wave screens that have one and
    /// the seven overlays (the counterpart's safety and report as Jules's, for a Business guest). Each
    /// time the visible "Leave and disappear" ends the Room run and the Wave at once, with no question:
    /// the Wave's own ended screen (74:578, never the Room's 66:114), naming nobody, with no invitation,
    /// panel, sample or Room element anywhere in the tree. Return to Places then lands on browsing at Now.
    func testLeaveFromEveryWaveContext() throws {
        var table: [String] = []
        let runStarted = ProcessInfo.processInfo.systemUptime
        for (index, fixture) in Self.leaveContexts.enumerated() {
            let contextStarted = ProcessInfo.processInfo.systemUptime
            func recordElapsed(_ phase: String) {
                let now = ProcessInfo.processInfo.systemUptime
                let note = String(format: "Leave context %d/18 %@: %@; context %.3f s; test %.3f s",
                                  index + 1, fixture.key, phase, now - contextStarted, now - runStarted)
                print(note)
                let attachment = XCTAttachment(string: note)
                attachment.name = "wave-leave-\(fixture.key)-\(phase)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            recordElapsed("started")
            let app = launchWave(fixture)
            let ui = WaveUI(app: app)
            XCTAssertTrue(readyElement(fixture, ui).waitForExistence(timeout: 20), "\(fixture.key) shows.")
            settle()
            let leave: XCUIElement
            if let overlay = fixture.overlay {
                assertOverlay(overlay, over: fixture.screen, fixture.viewer, ui, "Leave from \(fixture.key), before", reuseSnapshot: true)
                leave = ui.inPanel(overlay.container(fixture.viewer.counterpart), "wavePanel.leave")
            } else {
                assertScreen(fixture.screen, fixture.viewer, ui, "Leave from \(fixture.key), before", reuseSnapshot: true)
                leave = ui.leave
            }
            recordElapsed("checked-before-leave")
            XCTAssertEqual(leave.label, WaveText.leave, "\(fixture.key): the visible Leave.")
            tapQuietly(leave, app)
            waitForScreen(.sessionEnded, ui, timeout: 15)
            assertScreen(.sessionEnded, fixture.viewer, ui, "Left from \(fixture.key)", reuseSnapshot: true)
            recordElapsed("checked-ended")
            capture("wave-leave-from-\(fixture.key)-fixture", app)
            tapQuietly(ui.returnToPlaces, app)
            assertPlacesNow(WavePlaces(app: app), "Return to Places after leaving from \(fixture.key)")
            table.append("\(fixture.key): the Wave's ended screen, then Places at Now")
            app.terminate()
            recordElapsed("completed")
        }
        attachNote("Leave and disappear, per Wave context: " + table.joined(separator: "; ") + ".")
    }

    // MARK: - Back gestures

    /// Real edge swipes (the Places back gesture, which routes the Room's outer Back, and through it the
    /// Wave's): the swipe follows the visible Back only. The
    /// menu: its visible Back (founder decision, 30 September 2026) returns to the Room profile that opened
    /// it; from the menu opened again, a cancelled swipe stays and a completed one lands on the same profile,
    /// element for element. The unsent confirmation: the menu. Each of the six closed screens: the menu
    /// (the blocked one's with its generic blocked line). Pending, review and
    /// accepted (no Back in the design): nothing. Overlays close one level at a time: a report to its
    /// caller's safety, the safety to the screen; the global safety to the menu, then the menu to the
    /// profile; Demo cases to its screen; the chat information to the accepted example. The ended screen:
    /// a cancelled swipe stays, a completed one opens Places at Now. A menu whose counterpart is blocked:
    /// the Room's filtered People.
    func testEdgeSwipesFollowTheVisibleBack() throws {
        let viewer = WaveViewer.alex

        // The menu → the Room profile that opened it: first by the menu's visible Back, then, from a menu
        // opened again, by the swipe, which must land exactly where the Back did.
        var app = launchRoom(viewer, profile: "maya")
        var room = WaveRoomUI(app: app)
        var ui = WaveUI(app: app)
        waitForLabel(room.profileName, "Maya")
        settle()
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        tapQuietly(ui.back, app)
        XCTAssertTrue(waitForAbsence(ui.screen(.menu)), "The menu's visible Back closes the menu.")
        waitForLabel(room.profileName, "Maya")
        let byBack = profileDestination(room, "The menu's visible Back")
        tapQuietly(room.profileAction, app)
        waitForScreen(.menu, ui)
        edgeSwipe(app, completing: false)
        waitQuietly(0.6)
        XCTAssertTrue(ui.screen(.menu).exists, "Not completed: still the menu.")
        edgeSwipe(app, completing: true)
        XCTAssertTrue(waitForAbsence(ui.screen(.menu)), "A completed swipe closes the menu.")
        waitForLabel(room.profileName, "Maya")
        XCTAssertEqual(room.profileAction.label, WaveText.previewWaveDemo, "Maya's profile, as it was.")
        let bySwipe = profileDestination(room, "A completed swipe on the menu")
        XCTAssertEqual(bySwipe, byBack, "The swipe lands where the menu's visible Back does.")
        attachNote("The menu's Back and its swipe both land on: \(byBack).")
        capture("wave-gesture-menu-to-profile-fixture", app)
        app.terminate()

        // The unsent confirmation → the menu.
        app = launchWave(WaveFixture(key: "out-confirm", screen: .outConfirm))
        ui = WaveUI(app: app)
        waitForScreen(.outConfirm, ui, timeout: 20)
        edgeSwipe(app, completing: false)
        waitQuietly(0.6)
        XCTAssertTrue(ui.screen(.outConfirm).exists, "Not completed: still the confirmation.")
        edgeSwipe(app, completing: true)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "A swipe from the confirmation")
        app.terminate()

        // Each closed screen → the menu.
        for closed in WaveScreenKey.allCases where closed.isClosed {
            app = launchWave(WaveFixture(key: closed.rawValue, screen: closed))
            ui = WaveUI(app: app)
            waitForScreen(closed, ui, timeout: 20)
            edgeSwipe(app, completing: true)
            waitForScreen(.menu, ui)
            XCTAssertFalse(ui.screen(closed).exists, "\(closed.rawValue): a completed swipe returns to the menu.")
            assertText(ui.menuRole, WaveText.role(viewer.name), "The menu, after a swipe from \(closed.rawValue)")
            XCTAssertEqual(ui.menuBlocked.exists, closed == .blocked,
                           "\(closed.rawValue): the menu's generic blocked line shows only once the counterpart is blocked.")
            app.terminate()
        }

        // Pending, review and accepted → nothing.
        for active in [WaveScreenKey.outPending, .inReview, .inAccepted] {
            app = launchWave(WaveFixture(key: active.rawValue, screen: active))
            ui = WaveUI(app: app)
            waitForScreen(active, ui, timeout: 20)
            edgeSwipe(app, completing: true)
            waitQuietly(0.6)
            assertScreen(active, viewer, ui, "\(active.rawValue), after a completed swipe: unchanged")
            app.terminate()
        }

        // A report over its caller's safety over the review: one level per swipe, then nothing.
        app = launchWave(WaveFixture(key: "report-maya", screen: .inReview, overlay: .report("harassment")))
        ui = WaveUI(app: app)
        let report = WaveOverlayKind.report(nil).container(viewer.counterpart)
        let safety = WaveOverlayKind.counterpartSafety.container(viewer.counterpart)
        XCTAssertTrue(ui.element(report).waitForExistence(timeout: 20))
        settle()
        edgeSwipe(app, completing: true)
        XCTAssertTrue(waitForAbsence(ui.element(report)), "A swipe closes the report.")
        waitForOverlay(.counterpartSafety, viewer, ui)
        assertOverlay(.counterpartSafety, over: .inReview, viewer, ui, "Maya's safety, after a swipe from her report")
        edgeSwipe(app, completing: false)
        waitQuietly(0.6)
        XCTAssertTrue(ui.element(safety).exists, "Not completed: still Maya's safety.")
        edgeSwipe(app, completing: true)
        XCTAssertTrue(waitForAbsence(ui.element(safety)), "A swipe closes Maya's safety.")
        waitForScreen(.inReview, ui)
        edgeSwipe(app, completing: true)
        waitQuietly(0.6)
        assertScreen(.inReview, viewer, ui, "The review, after the overlays and one more swipe")
        app.terminate()

        // The global safety over the menu → the menu → the profile.
        app = launchWave(WaveFixture(key: "global-safety", screen: .menu, overlay: .globalSafety))
        ui = WaveUI(app: app)
        room = WaveRoomUI(app: app)
        XCTAssertTrue(ui.element(WaveOverlayKind.globalSafety.container(viewer.counterpart)).waitForExistence(timeout: 20))
        settle()
        edgeSwipe(app, completing: true)
        XCTAssertTrue(waitForAbsence(ui.element(WaveOverlayKind.globalSafety.container(viewer.counterpart))))
        waitForScreen(.menu, ui)
        edgeSwipe(app, completing: true)
        waitForLabel(room.profileName, "Maya")
        app.terminate()

        // Demo cases → its screen; the chat information → the accepted example.
        for (screen, overlay) in [(WaveScreenKey.outPending, WaveOverlayKind.conditions), (.inAccepted, .chatInfo)] {
            app = launchWave(WaveFixture(key: "\(screen.rawValue)-\(overlay.fixture)", screen: screen, overlay: overlay))
            ui = WaveUI(app: app)
            XCTAssertTrue(ui.element(overlay.container(viewer.counterpart)).waitForExistence(timeout: 20))
            settle()
            edgeSwipe(app, completing: true)
            XCTAssertTrue(waitForAbsence(ui.element(overlay.container(viewer.counterpart))), "A swipe closes \(overlay.fixture).")
            waitForScreen(screen, ui)
            assertScreen(screen, viewer, ui, "\(screen.rawValue), after a swipe from \(overlay.fixture)")
            app.terminate()
        }

        // The ended screen → Places at Now.
        app = launchWave(WaveFixture(key: "session-ended", screen: .sessionEnded))
        ui = WaveUI(app: app)
        waitForScreen(.sessionEnded, ui, timeout: 20)
        edgeSwipe(app, completing: false)
        waitQuietly(0.6)
        XCTAssertTrue(ui.screen(.sessionEnded).exists, "Not completed: still the ended screen.")
        edgeSwipe(app, completing: true)
        assertPlacesNow(WavePlaces(app: app), "A completed swipe from the Wave's ended screen")
        capture("wave-gesture-ended-to-places-fixture", app)
        app.terminate()

        // A menu whose counterpart is blocked → the filtered People.
        app = launchWave(WaveFixture(key: "in-review", screen: .inReview))
        ui = WaveUI(app: app)
        room = WaveRoomUI(app: app)
        waitForScreen(.inReview, ui, timeout: 20)
        tapQuietly(ui.safety, app)
        waitForOverlay(.counterpartSafety, viewer, ui)
        tapQuietly(ui.inPanel(safety, "wavePanel.block"), app)
        waitForScreen(.blocked, ui)
        tapQuietly(ui.backToMenu, app)
        waitForScreen(.menu, ui)
        assertScreen(.menu, viewer, ui, "A blocked counterpart's menu, before the swipe", menuBlocked: true)
        edgeSwipe(app, completing: true)
        XCTAssertTrue(room.peopleFraming.waitForExistence(timeout: 10), "A blocked counterpart's menu: the filtered People.")
        settle()
        assertRoomPeople(room, blocked: ["maya"], "After a swipe from a blocked counterpart's menu")
        capture("wave-gesture-blocked-menu-to-people-fixture", app)
    }

    // MARK: - Largest text

    /// Direct launches at the largest accessibility text size, on whichever iPhone runs it (the captures
    /// name its width), each with the long Guest List name "Alexandria-Josephine"
    /// (`-ProximeetFixtureName`): all twelve Wave screens and the blocked menu, checked by
    /// `checkAtLargestText` (every text grows, never a fixed or clipped box: at least 1.3 times its Figma
    /// box and 30 pt, and stays in its column; every button, Leave and the menu's 44 × 44 Back included,
    /// can be brought into view below the status bar and above the bar, tapped, and is at least 44 pt
    /// tall; the first element at rest sits below the status bar). On the blocked menu the generic
    /// "Connection blocked." line grows like any text, and the three disabled choices are brought into
    /// view and measured (present, disabled, at least 44 pt tall) but never tapped. The
    /// six closed screens share one layout, so the closed paper's two lines are checked on the withdrawn
    /// and ended screens and every closed screen's own headline, explanation and buttons on all six. Then
    /// two real Leaves at the largest text, each a fresh launch: from the incoming review's bar and from
    /// inside the report preview, each revealed, proved hittable and tapped, to the Wave's ended screen,
    /// Return to Places at Now, and Back to Signal with the fixture's band and approach. Rows W11a on the
    /// iPhone 17 Pro Max and W14a on the smaller iPhone; the seven overlays are
    /// `testLargestTextKeepsWavePanelsReachable`'s (W11b, W14b). The two were one test until its estimate,
    /// at Xcode Cloud's measured pace, passed the plans' 1,200-s maximum; no check was dropped.
    ///
    /// Time, estimated (nothing of this has run yet): the Room's six largest-text checks took 229-322 s in
    /// builds 6abc1b80-6abc3ebe, 45 texts and buttons between them. Split, as a fit and not a measurement,
    /// into about 12-16 s a launch and 3.5-5 s a text or button, these thirteen launches and 102 texts and
    /// buttons (the blocked menu's launch and nine items, and the menu's Back, came with the founder's
    /// decisions of 30 September 2026) take about 515-720 s (38-54 s a check, the Room's own spread, gives
    /// about the same), and the two Leaves about 60-90 s: about 575-810 s at Codemagic's pace, and up to
    /// about 955 s at Xcode Cloud's measured 1.04-1.18 times. That is past the plans' 900-s default, so
    /// this test asks for their 1,200-s maximum, which a Wave plan's compute budget may lower (`RunBudget`).
    /// The screens run first and the Leaves last, each soft, so a slow run still reports every check it
    /// reached.
    func testLargestTextKeepsWaveScreensReachable() throws {
        // The test plans cap tests at 900 s unless a test asks for more (their maximum is 1,200 s); this
        // one's upper estimate at Xcode Cloud's pace is about 955 s. Under a Wave plan it gets no more than
        // what is left of that run's compute budget.
        RunBudget.allow(1200, self)
        let viewer = Self.largestViewer
        checkAtLargestText(Self.largestScreenChecks(viewer))
        softly {
            proveLeaveAtLargestText(WaveFixture(key: "in-review", screen: .inReview, viewer: viewer), viewer)
        }
        softly {
            proveLeaveAtLargestText(WaveFixture(key: "report-maya-harassment", screen: .inReview,
                                                overlay: .report("harassment"), viewer: viewer), viewer)
        }
    }

    /// Direct launches at the largest accessibility text size, as `testLargestTextKeepsWaveScreensReachable`
    /// (the same viewer, the same `checkAtLargestText`): all seven overlays, the report with a reason
    /// (harassment) selected. In each, from the top: every text grows and stays inside its overlay, and
    /// every button, Leave included, can be brought into view in the overlay's own viewport, tapped, and
    /// is at least 44 pt tall; the overlay's label sits below the status bar; nothing of the Wave page,
    /// the Room or Places is left in the tree under it. The Leave from inside the report preview is tapped
    /// for real by the screens test. Rows W11b on the iPhone 17 Pro Max and W14b on the smaller iPhone.
    ///
    /// Time, estimated (nothing of this has run yet), on the same fit as the screens test: seven launches
    /// and 44 texts and buttons, about 240-330 s (266-378 s at 38-54 s a check): about 240-380 s at
    /// Codemagic's pace, and up to about 450 s at Xcode Cloud's 1.18 times. Well inside the plans' 900-s
    /// default, so it asks for no more.
    func testLargestTextKeepsWavePanelsReachable() throws {
        checkAtLargestText(Self.largestPanelChecks(Self.largestViewer))
    }

    /// The viewer every largest-text launch uses: the long typed name, Social and Chat first.
    private static var largestViewer: WaveViewer {
        WaveViewer(name: typedName, band: "social", approach: "chatFirst")
    }

    /// Runs each largest-text check on its own fresh launch, in order, each soft: the fixture shows; a
    /// capture; under an overlay nothing of the Wave page, the Room or Places in the tree; the first
    /// element at rest below the status bar; every text grown and inside its column or overlay, and
    /// every button brought into view, hittable and at least 44 pt, from the top down; a closing capture.
    /// The blocked menu additionally records paired captures and proves Leave from that scrolled state.
    private func checkAtLargestText(_ checks: [WaveLargestCheck]) {
        for check in checks {
            let app = launchWave(check.fixture, extra: Self.largestText)
            let ui = WaveUI(app: app)
            guard readyElement(check.fixture, ui).waitForExistence(timeout: 20) else {
                softly { XCTFail("\(check.name): the fixture shows at the largest text.") }
                app.terminate()
                continue
            }
            hold(0.8)
            if check.fixture.screen == .inAccepted {
                waitQuietly(0.6)
            }
            let width = Int(app.frame.width.rounded())
            let state = "\(check.name), largest text, \(width) pt"
            capture("wave-\(check.name)-largest-\(width)pt-fixture", app)
            softly {
                let nodes = readTree(app)
                if let panel = check.panel {
                    assertUnderlayAbsent(panel, nodes, state)
                }
                assertBelowStatusBar(check.panel == nil ? "wave.brand" : "wavePanel.label", nodes, app, state)
                let bounds = horizontalBounds(check.panel, ui)
                for item in check.items {
                    switch item {
                    case .text(let id, let figma):
                        assertUnclipped(id, grownFrom: figma, within: bounds, ui, state)
                        if check.fixture.screen == .inAccepted, check.panel == nil,
                           id == "wave.invitation.purpose" {
                            assertAcceptedPurposePrecedesPreference(ui, state)
                        }
                    case .button(let id):
                        assertReachableButton(id, ui, state)
                    case .disabledButton(let id, let label):
                        assertReachableDisabledButton(id, label, ui, state)
                    }
                }
            }
            capture("wave-\(check.name)-largest-end-\(width)pt-fixture", app)
            if check.fixture.menuBlocked {
                softly { proveBlockedMenuLeaveAfterScroll(ui, state, width: width) }
            }
            app.terminate()
        }
    }

    /// Build 8's blocked-menu end still had a blank Leave area while its recording showed Leave.
    /// Keep that exact scrolled state alive, retain both capture APIs with geometry for visual review,
    /// then prove the visible action works there. Hittability and a successful tap do not by themselves
    /// settle whether the label was drawn; the paired stills and the recording remain review evidence.
    private func proveBlockedMenuLeaveAfterScroll(_ ui: WaveUI, _ state: String, width: Int) {
        let app = ui.app
        waitQuietly(0.8)
        XCTAssertTrue(ui.menuBlocked.exists, "\(state): the blocked menu remains active before the Leave review.")
        assertButton(ui.leave, WaveText.leave, state)
        attachNote("\(state): paired captures before Leave, with the app kept running. "
                   + "wave.leave frame=\(Self.rect(ui.leave.frame)), enabled=\(ui.leave.isEnabled), "
                   + "hittable=\(ui.leave.isHittable), label=\(String(reflecting: ui.leave.label)). "
                   + "Snapshot presence and hittability are not proof of rendered text.")
        capture("wave-demo-menu-blocked-largest-settled-app-\(width)pt-fixture", app)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "wave-demo-menu-blocked-largest-settled-screen-\(width)pt-fixture"
        screen.lifetime = .keepAlways
        add(screen)
        waitQuietly(0.8)
        guard revealThenTap("wave.leave", in: nil, ui, state) else { return }
        guard ui.screen(.sessionEnded).waitForExistence(timeout: 15) else {
            XCTFail("\(state): Leave from the scrolled blocked menu ends the Wave.")
            return
        }
        XCTAssertFalse(ui.menuBlocked.exists, "\(state): the blocked menu is gone after Leave.")
        XCTAssertEqual(app.alerts.count, 0, "\(state): Leave asks nothing.")
        assertButton(ui.returnToPlaces, WaveText.returnToPlaces, "\(state): ended")
        capture("wave-demo-menu-blocked-largest-left-\(width)pt-fixture", app)
    }

    /// A Leave at the largest text, on a fresh launch: revealed (in its panel's own viewport, or above
    /// the bar), proved hittable and tapped; the Wave's ended screen; Return to Places, revealed: Places
    /// at Now; Back, revealed: Signal with the fixture's band and approach still selected.
    private func proveLeaveAtLargestText(_ fixture: WaveFixture, _ viewer: WaveViewer) {
        let app = launchWave(fixture, extra: Self.largestText)
        defer { app.terminate() }
        let ui = WaveUI(app: app)
        let places = WavePlaces(app: app)
        let signal = WaveSignal(app: app)
        let width = Int(app.frame.width.rounded())
        let state = "\(fixture.key), largest text, \(width) pt, Leave"
        guard readyElement(fixture, ui).waitForExistence(timeout: 20) else {
            XCTFail("\(state): the fixture shows.")
            return
        }
        settle()
        let panel = fixture.overlay.map { $0.container(viewer.counterpart) }
        guard revealThenTap(panel == nil ? "wave.leave" : "wavePanel.leave", in: panel, ui, state) else { return }
        guard ui.screen(.sessionEnded).waitForExistence(timeout: 15) else {
            XCTFail("\(state): Leave and disappear ends the run at once: the Wave's ended screen.")
            return
        }
        settle()
        assertScreen(.sessionEnded, viewer, ui, "\(state): ended")
        capture("wave-\(fixture.key)-largest-left-\(width)pt-fixture", app)
        guard revealThenTap("wave.returnToPlaces", in: nil, ui, state) else { return }
        guard places.headline.waitForExistence(timeout: 15) else {
            XCTFail("\(state): Return to Places opens Places.")
            return
        }
        assertPlacesNow(places, "\(state): Return to Places")
        capture("wave-\(fixture.key)-largest-left-return-to-places-\(width)pt-fixture", app)
        XCTAssertEqual(places.secondary.label, "Back", "\(state): browsing's Back.")
        guard revealThenTap("places.secondary", in: nil, ui, state) else { return }
        guard signal.headline.waitForExistence(timeout: 15) else {
            XCTFail("\(state): Back from browsing opens Signal.")
            return
        }
        waitForLabel(signal.headline, "A hello, on your terms.")
        waitForLabel(signal.summary, "\(viewer.intentTitle) band · \(viewer.approachTitle)")
        XCTAssertTrue(waitFor(signal.row(viewer.approach), selected: true), "\(state): the approach is kept.")
        capture("wave-\(fixture.key)-largest-left-back-to-signal-\(width)pt-fixture", app)
    }

    // MARK: - Reduce Motion

    /// Direct launches (fixture `wave-in-review`) on the 440 × 956 iPhone. With the app-level preview
    /// flag `-ProximeetReduceMotionPreview YES` (not the system setting): Accept shows the accepted
    /// result with the same words and no sampled frame shows a ring part-way through its 800-ms move.
    /// The 29 October design reserves rings for Dating, on a 376 × 220 artwork canvas. The probes below
    /// follow its separate/accepted ring geometry; all original anchor, sweep and final-pose assertions
    /// remain. Default motion is attached as an observational control because sampling can miss a move.
    func testReduceMotionPreviewAcceptJoinsWithoutAMove() throws {
        let viewer = WaveViewer(name: "Alex", band: "dating", approach: "chatFirst")
        let reduced = sampleAccept(extra: Self.reduceMotionPreview, viewer, "Reduce Motion")
        let control = sampleAccept(extra: [], viewer, "default motion")
        attachNote("Reduce Motion: \(reduced.map { $0.summary } ?? "no sample"). Default motion (control): "
                   + "\(control.map { $0.summary } ?? "no sample").")
        softly {
            guard let reduced else {
                XCTFail("Reduce Motion: Accept was not sampled.")
                return
            }
            guard let pixels = reduced.pixels else {
                attachNote("Reduce Motion: pixel checks need the 440 × 956 iPhone at the default text size; this run "
                           + "checked the accepted words only.")
                return
            }
            XCTAssertGreaterThan(pixels.separateBefore, 0.5, "Reduce Motion: the anchor, the separate first ring's rim "
                                 + "before Accept (\(pixels.separateBefore)).")
            guard pixels.separateBefore > 0.5 else { return }
            XCTAssertLessThan(pixels.sweepBefore, 0.05, "Nothing is drawn in the sweep before Accept (\(pixels.sweepBefore)).")
            for (index, frame) in pixels.frames.enumerated() {
                XCTAssertLessThan(frame.sweep, 0.05, "Reduce Motion: frame \(index + 1), \(Int(frame.after * 1000)) ms after "
                                  + "Accept, shows a ring part-way through a move (\(frame.sweep) of the sweep).")
            }
            XCTAssertGreaterThan(pixels.joinedAfter, 0.5, "Reduce Motion: the joined first ring is drawn (\(pixels.joinedAfter)).")
            XCTAssertLessThan(pixels.separateAfter, 0.05, "Reduce Motion: the separate pose is gone (\(pixels.separateAfter)).")
            XCTAssertLessThan(pixels.sweepAfter, 0.05, "Nothing is drawn in the sweep once joined (\(pixels.sweepAfter)).")
        }
    }

    /// Launches the incoming review (with `extra`), proves the anchor, taps Accept, reads four frames at
    /// once and one settled frame, and checks the accepted result's words.
    private func sampleAccept(extra: [String], _ viewer: WaveViewer, _ name: String) -> AcceptSample? {
        let app = launchWave(WaveFixture(key: "in-review", screen: .inReview, viewer: viewer), extra: extra)
        defer { app.terminate() }
        let ui = WaveUI(app: app)
        guard waitForScreen(.inReview, ui, timeout: 20) else { return nil }
        hold(0.8)
        bringIntoView(ui.accept, app)
        let exact = app.frame.size == CGSize(width: 440, height: 956)
        let origin = exact ? ringsOrigin(ui) : nil
        let width = app.frame.width
        var sample = AcceptSample(name: name)
        var pixels: AcceptPixels?
        if let origin, let before = WaveRenderedScreen(XCUIScreen.main.screenshot(), pointWidth: width) {
            pixels = AcceptPixels(
                separateBefore: before.fraction(in: RingProbe.separateOnly.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal),
                sweepBefore: before.fraction(in: RingProbe.sweep.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal)
            )
        }
        waitQuietly(0.8)
        ui.accept.tap()
        let tapped = Date()
        lastTap = tapped
        if let origin, pixels != nil {
            for _ in 0..<4 {
                let shot = XCUIScreen.main.screenshot()
                let after = Date().timeIntervalSince(tapped)
                if let frame = WaveRenderedScreen(shot, pointWidth: width) {
                    pixels?.frames.append(AcceptFrame(
                        after: after,
                        sweep: frame.fraction(in: RingProbe.sweep.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal)
                    ))
                }
            }
        }
        guard waitForScreen(.inAccepted, ui, timeout: 5) else { return nil }
        waitQuietly(1.2)
        assertScreen(.inAccepted, viewer, ui, "\(name), accepted: the same words")
        if let origin, let settled = WaveRenderedScreen(XCUIScreen.main.screenshot(), pointWidth: width) {
            pixels?.joinedAfter = settled.fraction(in: RingProbe.joinedOnly.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal)
            pixels?.separateAfter = settled.fraction(in: RingProbe.separateOnly.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal)
            pixels?.sweepAfter = settled.fraction(in: RingProbe.sweep.offsetBy(dx: origin.x, dy: origin.y), where: Self.metal)
        }
        capture("wave-accept-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(Int(width.rounded()))pt-fixture", app)
        // App-scoped captures can omit system-composited chrome/footer in this simulator. Pair the
        // existing capture with the full screen at the same settled state; neither substitutes for pixels.
        let fullScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fullScreen.name = "wave-accept-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-full-screen"
        fullScreen.lifetime = .keepAlways
        add(fullScreen)
        sample.pixels = pixels
        return sample
    }

    /// Native XCTest reports the union of painted artwork and the slip, not the full 376 × 220
    /// layout canvas. Probes below are calibrated relative to that measured invitation frame. If only
    /// the slip is exposed, its preceding 220-pt art slot supplies the fallback. Other widths do not
    /// use these unscaled geometry probes. Before/final anchors must satisfy the independent checks.
    private func ringsOrigin(_ ui: WaveUI) -> CGPoint? {
        let card = ui.invitation
        guard card.exists else { return nil }
        let frame = card.frame
        guard abs(frame.width - 376) <= 1.5 else { return nil }
        return CGPoint(x: frame.minX, y: frame.height >= 250 ? frame.minY : frame.minY - 220)
    }

    /// Anything brighter than the #050606 ground: the darkest rim stop is #333D40.
    private static let metal: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) >= 48 }

    // MARK: - Refused entry

    /// The current four-intent Common Ground catalog supersedes its old Dating/Activity refusal.
    /// Future sessions still cannot open a Room or Wave, and a different-intent profile still refuses.
    func testIneligibleAndOtherIntentNeverReachTheWave() throws {
        for (band, category, venue, disabled) in [
            ("dating", "later", "Afterglow", "Opens at 9 pm"),
            ("activity", "upcoming", "Fieldwork", "Opens Saturday"),
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-ProximeetFixture", "place-detail", "-ProximeetFixtureBand", band,
                                   "-ProximeetFixtureSignal", "okayToSayHello",
                                   "-ProximeetFixtureCategory", category]
            app.launch()
            let places = WavePlaces(app: app)
            waitForLabel(places.placeName, venue)
            settle()
            XCTAssertEqual(places.placePrimary.label, disabled)
            XCTAssertFalse(places.placePrimary.isEnabled, "\(band): the future session is disabled.")
            assertIdentifiers(absent: ["room", "wave"], readTree(app), "\(band): no Room, no Wave")
            capture("wave-refused-future-\(band)-fixture", app)
            app.terminate()
        }
        for (band, other) in [("social", WaveCounterpart.jules), ("business", WaveCounterpart.maya),
                              ("activity", WaveCounterpart.riley), ("dating", WaveCounterpart.sam)] {
            let viewer = WaveViewer(name: "Alex", band: band, approach: "chatFirst")
            let app = launchRoom(viewer, profile: other.key)
            let room = WaveRoomUI(app: app)
            waitForLabel(room.profileName, other.name)
            settle()
            XCTAssertEqual(room.profileAction.label, WaveText.backToPeople, "\(band): \(other.name) is another intent.")
            tapQuietly(room.profileAction, app)
            XCTAssertTrue(room.card(other.key).waitForExistence(timeout: 10), "\(band): Back to people returns to People.")
            settle()
            assertIdentifiers(absent: ["wave."], readTree(app), "\(band): another intent opens no Wave")
            app.terminate()
        }
    }

    // MARK: - Fixture tables

    /// The 12 screens, the blocked menu, the 7 overlays and the three selected report variants, each a
    /// direct launch (Social, Chat first, "Alex").
    private static var approvedCaptures: [WaveFixture] {
        var fixtures = WaveScreenKey.allCases.map { WaveFixture(key: $0.rawValue, screen: $0) }
        fixtures += [
            blockedMenuFixture(key: "menu-blocked"),
            WaveFixture(key: "global-safety", screen: .menu, overlay: .globalSafety),
            WaveFixture(key: "maya-safety", screen: .inReview, overlay: .counterpartSafety),
            WaveFixture(key: "report-maya", screen: .inReview, overlay: .report(nil)),
            WaveFixture(key: "chat-info", screen: .inAccepted, overlay: .chatInfo),
            WaveFixture(key: "conditions-out", screen: .outPending, overlay: .conditions),
            WaveFixture(key: "conditions-in", screen: .inReview, overlay: .conditions),
            WaveFixture(key: "conditions-accepted", screen: .inAccepted, overlay: .conditions),
            WaveFixture(key: "report-reason-attention", screen: .inReview, overlay: .report("unwantedAttention")),
            WaveFixture(key: "report-reason-harassment", screen: .inReview, overlay: .report("harassment")),
            WaveFixture(key: "report-reason-other", screen: .inReview, overlay: .report("somethingElse")),
        ]
        return fixtures
    }

    /// Every Wave context a Leave is offered in: the 11 screens and the 7 overlays.
    private static var leaveContexts: [WaveFixture] {
        let business = WaveViewer(name: "Alex", band: "business", approach: "okayToSayHello")
        var fixtures = WaveScreenKey.allCases.filter { $0 != .sessionEnded }.map { WaveFixture(key: $0.rawValue, screen: $0) }
        fixtures += [
            WaveFixture(key: "global-safety", screen: .menu, overlay: .globalSafety),
            WaveFixture(key: "jules-safety", screen: .outPending, overlay: .counterpartSafety, viewer: business),
            WaveFixture(key: "report-jules-harassment", screen: .inAccepted, overlay: .report("harassment"), viewer: business),
            WaveFixture(key: "chat-info", screen: .inAccepted, overlay: .chatInfo),
            WaveFixture(key: "conditions-out", screen: .outPending, overlay: .conditions),
            WaveFixture(key: "conditions-in", screen: .inReview, overlay: .conditions),
            WaveFixture(key: "conditions-accepted", screen: .inAccepted, overlay: .conditions),
        ]
        return fixtures
    }

    /// The largest-text screen checks: each screen's texts (with the height of its Figma box, which the
    /// text must outgrow) and its buttons, in one list from the top of the screen down, so the reveals run
    /// one way. Twelve screens and the blocked menu, 102 texts and buttons.
    private static func largestScreenChecks(_ viewer: WaveViewer) -> [WaveLargestCheck] {
        let ticket: [WaveLargestItem] = [.text("wave.venue.preference", 22), .text("wave.invitation.context", 24)]
        let slip: [WaveLargestItem] = [
            .text("wave.invitation.direction", 22), .text("wave.invitation.title", 40),
            .text("wave.invitation.purpose", 48), .text("wave.invitation.preference", 22), .text("wave.boundary", 52),
        ]
        let paper: [WaveLargestItem] = [.text("wave.closed.label", 24), .text("wave.closed.choice", 22)]
        let closedWords: [WaveLargestItem] = [
            .text("wave.closed.headline", 112), .text("wave.closed.explanation", 76),
        ]
        func fixture(_ screen: WaveScreenKey) -> WaveFixture {
            largestFixture(screen, viewer: viewer)
        }
        var checks: [WaveLargestCheck] = [
            WaveLargestCheck(name: "demo-menu", fixture: fixture(.menu), items: [
                .button("wave.back"), .button("wave.safety"), .text("wave.menu.headline", 112), .text("wave.menu.role", 26),
                .text("wave.menu.boundary", 52), .button("wave.menu.startOutgoing"), .button("wave.menu.startIncoming"),
                .button("wave.menu.noAllowance"), .button("wave.leave"),
            ]),
            // The menu once the counterpart is blocked: the generic line in the boundary's box (52), and the
            // three choices, disabled, measured but never tapped.
            WaveLargestCheck(name: "demo-menu-blocked", fixture: blockedMenuFixture(viewer: viewer), items: [
                .button("wave.back"), .button("wave.safety"), .text("wave.menu.headline", 112), .text("wave.menu.role", 26),
                .text("wave.menu.blocked", 52),
            ] + WaveText.menuChoices.map { WaveLargestItem.disabledButton($0.0, $0.1) } + [.button("wave.leave")]),
            WaveLargestCheck(name: "out-confirm", fixture: fixture(.outConfirm),
                             items: [.button("wave.back"), .button("wave.safety")] + ticket + slip
                                + [.button("wave.send"), .button("wave.leave")]),
            WaveLargestCheck(name: "out-pending", fixture: fixture(.outPending),
                             items: [.button("wave.safety")] + ticket + [.button("wave.demoCases")] + slip
                                + [.button("wave.withdraw"), .button("wave.leave")]),
            WaveLargestCheck(name: "in-review", fixture: fixture(.inReview),
                             items: [.button("wave.safety")] + ticket + [.button("wave.demoCases")] + slip
                                + [.button("wave.accept"), .button("wave.decline"), .button("wave.leave")]),
            WaveLargestCheck(name: "in-accepted", fixture: fixture(.inAccepted),
                             items: [.button("wave.safety")] + ticket + [.button("wave.demoCases")] + slip
                                + [.button("wave.aboutChat"), .button("wave.leave")]),
        ]
        for closed in WaveScreenKey.allCases where closed.isClosed {
            let words = closed == .outWithdrawn ? paper + closedWords + [.text("wave.closed.boundary", 24)] : closedWords
            checks.append(WaveLargestCheck(name: closed.rawValue, fixture: fixture(closed),
                                           items: [.button("wave.safety")] + words
                                            + [.button("wave.backToMenu"), .button("wave.leave")]))
        }
        checks.append(WaveLargestCheck(name: "session-ended", fixture: fixture(.sessionEnded),
                                       items: paper + closedWords + [.text("wave.closed.boundary", 24),
                                                                      .button("wave.returnToPlaces")]))
        return checks
    }

    /// The largest-text overlay checks, as `largestScreenChecks`: each overlay's texts and buttons from
    /// the top down, over the screen that opens it, and the container they must stay inside. Seven
    /// overlays, 44 texts and buttons.
    private static func largestPanelChecks(_ viewer: WaveViewer) -> [WaveLargestCheck] {
        let panelTexts: (CGFloat, CGFloat) -> [WaveLargestItem] = { title, explanation in
            [.text("wavePanel.label", 22), .text("wavePanel.title", title), .text("wavePanel.explanation", explanation)]
        }
        let overlays: [(String, WaveScreenKey, WaveOverlayKind, [WaveLargestItem])] = [
            ("global-safety", .menu, .globalSafety,
             panelTexts(82, 106) + [.button("wavePanel.close"), .button("wavePanel.leave")]),
            ("maya-safety", .inReview, .counterpartSafety,
             panelTexts(44, 80) + [.button("wavePanel.block"), .button("wavePanel.previewReport"),
                                   .button("wavePanel.back"), .button("wavePanel.leave")]),
            ("report-maya-harassment", .inReview, .report("harassment"),
             panelTexts(44, 58) + [.button("wave.report.reason.unwantedAttention"), .button("wave.report.reason.harassment"),
                                   .button("wave.report.reason.somethingElse"), .button("wavePanel.closePreview"),
                                   .button("wavePanel.leave")]),
            ("chat-info", .inAccepted, .chatInfo,
             panelTexts(82, 112) + [.button("wavePanel.back"), .button("wavePanel.leave")]),
            ("conditions-out", .outPending, .conditions,
             panelTexts(82, 74) + [.button("wavePanel.showExpired"), .button("wavePanel.back"), .button("wavePanel.leave")]),
            ("conditions-in", .inReview, .conditions,
             panelTexts(82, 74) + [.button("wavePanel.showExpired"), .button("wavePanel.showSenderWithdrawn"),
                                   .button("wavePanel.back"), .button("wavePanel.leave")]),
            ("conditions-accepted", .inAccepted, .conditions,
             panelTexts(82, 74) + [.button("wavePanel.showExpired"), .button("wavePanel.back"), .button("wavePanel.leave")]),
        ]
        return overlays.map { name, screen, overlay, items in
            var check = WaveLargestCheck(name: name, fixture: largestFixture(screen, overlay, viewer: viewer), items: items)
            check.fixture.key = name
            check.panel = overlay.container(viewer.counterpart)
            return check
        }
    }

    /// A largest-text fixture: `screen`, with `overlay` over it if given, for `viewer`, keyed by the screen.
    private static func largestFixture(_ screen: WaveScreenKey, _ overlay: WaveOverlayKind? = nil,
                                       viewer: WaveViewer) -> WaveFixture {
        WaveFixture(key: screen.rawValue, screen: screen, overlay: overlay, viewer: viewer)
    }

    /// The menu once the counterpart is blocked (fixture `wave-blocked`, then `-ProximeetWaveAfterBlock
    /// menu`: Back to demo menu), for `viewer`.
    private static func blockedMenuFixture(key: String = "demo-menu-blocked", viewer: WaveViewer = .alex) -> WaveFixture {
        WaveFixture(key: key, screen: .menu, viewer: viewer, afterBlock: "menu")
    }

    // MARK: - Launching

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 15))
        return app
    }

    /// A Wave fixture (`DebugFixtures.WaveFixture`).
    private func launchWave(_ fixture: WaveFixture, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = fixture.arguments + extra
        app.launch()
        lastTap = Date.distantPast
        return app
    }

    /// The Room's populated example (fixture `room-populated`) for `viewer`, a profile open if given.
    private func launchRoom(_ viewer: WaveViewer, profile: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ProximeetFixture", "room-populated", "-ProximeetFixtureBand", viewer.band,
                         "-ProximeetFixtureSignal", viewer.approach]
        if let profile {
            arguments += ["-ProximeetRoomProfile", profile]
        }
        app.launchArguments = arguments + extra
        app.launch()
        lastTap = Date.distantPast
        return app
    }

    /// Welcome → Birthday with 12 May 1997 → Continue → Pass → Try the demo → Finish preview.
    private func openCompletedPass(_ app: XCUIApplication) -> WavePass {
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
        let pass = WavePass(app: app)
        waitForLabel(pass.headline, "Your next chapter.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        tapDistinctPrimary(pass.primary, label: "Finish preview")
        waitForLabel(pass.headline, "Demo complete.")
        return pass
    }

    /// A new choice on the same physical button, not the second touch of a rapid double tap (Pass and
    /// Guest List swallow UIKit repeat taps): the far-side tap `PassReviewTests` and `RoomReviewTests` use.
    private func tapDistinctPrimary(_ element: XCUIElement, label: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel(element, label)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@ AND isEnabled == true AND isHittable == true", label),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
                       "The intended primary action must be enabled and hittable before its single tap.",
                       file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
    }

    /// From Common Ground's explanation: Preview room demo (the entry, 66:112), Enter room demo (waiting,
    /// 66:113) and Show populated example (People, 66:115), each through its real control.
    private func enterPopulatedRoom(_ places: WavePlaces, _ room: WaveRoomUI,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(places.explanationPrimary.label, "Preview room demo", file: file, line: line)
        tapQuietly(places.explanationPrimary, room.app, file: file, line: line)
        waitForText(room.entryHeadline, "Come in.\nStay yourself.", file: file, line: line)
        settle()
        tapQuietly(room.enter, room.app, file: file, line: line)
        waitForText(room.waitingHeadline, "A little privacy.\nBefore a hello.", file: file, line: line)
        XCTAssertTrue(waitForAbsence(room.entryHeadline), "Enter room demo replaces the entry.", file: file, line: line)
        settle()
        assertIdentifiers(absent: ["wave."], readTree(room.app), "Waiting: no Wave", file: file, line: line)
        tapQuietly(room.showPopulated, room.app, file: file, line: line)
        XCTAssertTrue(room.card("maya").waitForExistence(timeout: 10), "Show populated example reveals the samples.",
                      file: file, line: line)
        settle()
    }

    /// A sample's card on People, brought into view and tapped: its profile.
    private func openProfile(_ sample: WaveCounterpart, _ room: WaveRoomUI, file: StaticString = #filePath, line: UInt = #line) {
        tapQuietly(room.card(sample.key), room.app, file: file, line: line)
        waitForLabel(room.profileName, sample.name, file: file, line: line)
        settle()
    }

    /// A report reason, selected.
    private func selectReason(_ key: String, _ ui: WaveUI, file: StaticString = #filePath, line: UInt = #line) {
        let row = ui.reason(key)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(key) is offered.", file: file, line: line)
        tapQuietly(row, ui.app, file: file, line: line)
        // The selected trait alone, as on Room's reasons: a value would make VoiceOver say "Selected" twice.
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed, "\(key) is selected.", file: file, line: line)
        settle()
    }

    /// Where a guest's tap lands now on a spot where a control used to be: a real tap there, 0.8 s after
    /// the last, then the Wave screen shown (nil when none is).
    private func staleTap(at point: CGPoint, _ ui: WaveUI) -> WaveScreenKey? {
        let quiet = Date().timeIntervalSince(lastTap)
        if quiet < 0.8 {
            waitQuietly(0.8 - quiet)
        }
        ui.app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        lastTap = Date()
        waitQuietly(1.0)
        let shown = readTree(ui.app).compactMap { node -> WaveScreenKey? in
            guard node.identifier.hasPrefix("wave.screen.") else { return nil }
            return WaveScreenKey(rawValue: String(node.identifier.dropFirst("wave.screen.".count)))
        }
        return shown.first
    }

    /// One deliberate tap: at least 0.8 s after the last tap or swipe, so the window's repeat-tap guard
    /// never takes it for the second touch of a double tap, and brought into view first when it cannot be
    /// tapped where it is.
    private func tapQuietly(_ element: XCUIElement, _ app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "The control is showing.", file: file, line: line)
        // Always measured, never trusted to isHittable: a button partly under the bar (a long name pushes
        // Withdraw and About private chat down at the default size) can report hittable while its centre
        // lies on Leave. `reveal` returns at once when the control is already clear.
        reveal(element.identifier, app, file: file, line: line)
        let quiet = Date().timeIntervalSince(lastTap)
        if quiet < 0.8 {
            waitQuietly(0.8 - quiet)
        }
        element.tap()
        lastTap = Date()
    }

    /// Brings a control into view without tapping it (for a double tap, or a point read before a tap).
    private func bringIntoView(_ element: XCUIElement, _ app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "The control is showing.", file: file, line: line)
        reveal(element.identifier, app, file: file, line: line)
        XCTAssertTrue(element.isHittable, "The control can be tapped where it is.", file: file, line: line)
    }

    /// A swipe in from the leading edge, 45 % of the way down: completed (three quarters of the width,
    /// fast) or not (a fifth of the width, slowly, held, released without momentum), as
    /// `PlacesCorrectionTests` and `RoomReviewTests` swipe. Each starts 0.8 s after anything before it, so
    /// the window's repeat-tap guard never reads its touch as a second tap.
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
        lastTap = Date()
    }

    // MARK: - What each state shows

    /// The element that shows once a fixture is ready: its overlay's container, the blocked menu's generic
    /// line, or its screen's.
    private func readyElement(_ fixture: WaveFixture, _ ui: WaveUI) -> XCUIElement {
        if let overlay = fixture.overlay {
            return ui.element(overlay.container(fixture.viewer.counterpart))
        }
        // The blocked menu's fixture passes through the menu before the block: only its generic line says
        // the fixture has arrived.
        return fixture.menuBlocked ? ui.menuBlocked : ui.screen(fixture.screen)
    }

    @discardableResult
    private func waitForScreen(_ screen: WaveScreenKey, _ ui: WaveUI, timeout: TimeInterval = 10,
                               file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let shown = ui.screen(screen).waitForExistence(timeout: timeout)
        XCTAssertTrue(shown, "\(screen.rawValue) (\(screen.figma)) shows.", file: file, line: line)
        settle()
        return shown
    }

    private func waitForOverlay(_ overlay: WaveOverlayKind, _ viewer: WaveViewer, _ ui: WaveUI,
                                file: StaticString = #filePath, line: UInt = #line) {
        let panel = overlay.container(viewer.counterpart)
        XCTAssertTrue(ui.element(panel).waitForExistence(timeout: 10), "\(panel) opens.", file: file, line: line)
        settle()
    }

    /// Everything one Wave screen shows for `viewer`, with no overlay open, from one snapshot where the
    /// claim is about the whole tree: exactly this screen; its chrome (75:111; the menu's and the
    /// confirmation's 75:119 with Back and "Wave"; the ended screen's 75:130 with no Safety); Leave (or,
    /// once ended, only Return to Places); the ring snapshot structure (manual accessibility gate below); no overlay;
    /// nothing of the Room page or Places below the Wave; and the screen's own words, controls and people.
    /// `menuBlocked`: the menu once its counterpart is blocked (three disabled choices, one generic line).
    // Callers finish their live readiness/transition checks first. This helper performs no actions;
    // its fresh tree is shared only by static assertions in this invocation. Animation sampling is live.
    private func assertScreen(_ screen: WaveScreenKey, _ viewer: WaveViewer, _ ui: WaveUI, _ state: String,
                              menuBlocked: Bool = false, reuseSnapshot: Bool = true,
                              file: StaticString = #filePath, line: UInt = #line) {
        let nodes = readTree(ui.app, checkingRings: (screen: screen, state: state), file: file, line: line)
        let ui = WaveAssertionUI(live: ui, nodes: reuseSnapshot ? nodes : nil)
        let ids = Set(nodes.map { $0.identifier })
        let screens = nodes.map { $0.identifier }.filter { $0.hasPrefix("wave.screen.") }
        XCTAssertEqual(screens, ["wave.screen.\(screen.rawValue)"], "\(state): exactly this screen (\(screen.figma)).",
                       file: file, line: line)
        assertText(ui.brand, (screen.hasBack || screen.isActive) ? WaveText.composeBrand : WaveText.brand, state, file: file, line: line)
        assertTextIgnoringCase(ui.demoBadge, WaveText.demoBadge, state, file: file, line: line)
        if screen == .sessionEnded {
            XCTAssertFalse(ids.contains("wave.safety"), "\(state): the ended chrome (75:130) has no Safety.", file: file, line: line)
        } else {
            assertIconButton(ui.safety, containing: "safety", state, file: file, line: line)
        }
        if screen.hasBack {
            assertIconButton(ui.back, containing: "back", state, file: file, line: line)
        } else {
            XCTAssertFalse(ids.contains("wave.back"), "\(state): only the menu and the unsent confirmation have a Back "
                           + "(75:119).", file: file, line: line)
        }
        if screen == .sessionEnded {
            XCTAssertFalse(ids.contains("wave.leave"), "\(state): the ended screen has no Leave.", file: file, line: line)
            assertButton(ui.returnToPlaces, WaveText.returnToPlaces, state, file: file, line: line)
            XCTAssertEqual(ui.app.alerts.count, 0, "\(state): Leave asks nothing.", file: file, line: line)
        } else {
            assertButton(ui.leave, WaveText.leave, state, file: file, line: line)
            XCTAssertFalse(ids.contains("wave.returnToPlaces"), "\(state): Return to Places only once ended.", file: file, line: line)
        }
        assertIdentifiers(absent: ["wavePanel."], nodes, "\(state): no overlay", file: file, line: line)
        assertIdentifiers(absent: Self.belowTheWave, nodes, except: Self.containers,
                          "\(state): the Wave replaces the Room page; nothing of it or of Places is left", file: file, line: line)
        if screen == .menu {
            assertMenu(viewer, ui, nodes, blocked: menuBlocked, state, file: file, line: line)
        } else if screen.isActive {
            assertInvitation(screen, viewer, ui, nodes, state, file: file, line: line)
        } else {
            assertClosed(screen, ui, nodes, state, file: file, line: line)
        }
    }

    /// The menu (74:568): the approved headline, the role line with the actual Guest List name, its
    /// visible Back ("Back", to the Room that opened it), the boundary and the three explicit choices;
    /// nothing started and nobody but the viewer named anywhere in the tree. Once the counterpart is
    /// blocked (`blocked`): the three choices keep their three distinct labels and are disabled, and the
    /// one generic "Connection blocked." line takes the boundary's place.
    private func assertMenu(_ viewer: WaveViewer, _ ui: WaveAssertionUI, _ nodes: [WaveNode], blocked: Bool, _ state: String,
                            file: StaticString, line: UInt) {
        let ids = Set(nodes.map { $0.identifier })
        assertText(ui.menuHeadline, WaveText.menuHeadline, state, file: file, line: line)
        assertText(ui.menuRole, WaveText.role(viewer.name), state, file: file, line: line)
        assertButton(ui.back, WaveText.back, "\(state): the menu's visible Back", file: file, line: line)
        if blocked {
            assertText(ui.menuBlocked, WaveText.menuBlocked, state, file: file, line: line)
            XCTAssertFalse(ids.contains("wave.menu.boundary"), "\(state): the generic blocked line takes the boundary's "
                           + "place.", file: file, line: line)
            for (id, label) in WaveText.menuChoices {
                assertDisabledChoice(ui.element(id), label, state, file: file, line: line)
            }
            let labels = WaveText.menuChoices.compactMap { choice in nodes.first { $0.identifier == choice.0 }?.label }
            XCTAssertEqual(Set(labels).count, WaveText.menuChoices.count,
                           "\(state): the disabled choices keep three distinct labels: \(labels).", file: file, line: line)
        } else {
            assertText(ui.menuBoundary, WaveText.menuBoundary, state, file: file, line: line)
            XCTAssertFalse(ids.contains("wave.menu.blocked"), "\(state): nobody is blocked, so no blocked line.",
                           file: file, line: line)
            assertButton(ui.startOutgoing, WaveText.startOutgoing, state, file: file, line: line)
            assertButton(ui.startIncoming, WaveText.startIncoming, state, file: file, line: line)
            assertButton(ui.noAllowance, WaveText.showNoAllowance, state, file: file, line: line)
        }
        assertIdentifiers(absent: ["wave.invitation", "wave.venue", "wave.closed.", "wave.backToMenu", "wave.demoCases"]
                          + Self.invitationActions, nodes, "\(state): the menu starts nothing", file: file, line: line)
        let leaks = sampleLeaks(nodes, of: WaveCounterpart.all)
        XCTAssertTrue(leaks.isEmpty, "\(state): the menu names only the viewer. " + leaks.joined(separator: "; "),
                      file: file, line: line)
    }

    /// An active invitation (74:569 / 74:570 / 74:572 / 74:574): the ticket with the viewer's own values,
    /// the state and direction lines (read in sentence case, lead decision 8; the direction line spoken
    /// exactly as `WaveText.direction`, sender first, "you" by the viewer's identity with the Guest List
    /// name after it), the approved title, purpose and boundary for the actual counterpart, the
    /// counterpart's own intent and approach on the invitation, Demo cases where the design has it, and
    /// exactly this screen's actions:
    /// Accept only on the recipient's pending review, anywhere in the tree.
    private func assertInvitation(_ screen: WaveScreenKey, _ viewer: WaveViewer, _ ui: WaveAssertionUI, _ nodes: [WaveNode],
                                  _ state: String, file: StaticString, line: UInt) {
        let counterpart = viewer.counterpart
        XCTAssertTrue(ui.venue.exists, "\(state): the venue ticket.", file: file, line: line)
        assertText(ui.venuePreference, viewer.preference, state, file: file, line: line)
        let direction = screen.isOutgoing ? "outgoing" : "incoming"
        assertMentions(ui.context, [direction, viewer.name], state, file: file, line: line)
        // The spoken direction line, exactly (founder decision, 30 September 2026): sender before recipient,
        // "you" for the viewer's identity with the actual name after it, so a swapped sender and recipient, or
        // a "you" chosen by matching names, cannot pass.
        if ui.direction.exists {
            XCTAssertEqual(ui.direction.label, WaveText.direction(screen, viewer: viewer.name, counterpart: counterpart.name),
                           "\(state): the spoken direction line.", file: file, line: line)
        } else {
            XCTFail("\(state): the direction line is not showing.", file: file, line: line)
        }
        softly {
            if ui.venue.exists {
                let label = ui.venue.label
                XCTAssertTrue(label.contains(WaveText.venueName) && label.contains(viewer.preference),
                              "\(state): the ticket reads as one element with the venue and the guest's line: “\(label)”.",
                              file: file, line: line)
            }
            for element in [ui.context, ui.direction] where element.exists {
                XCTAssertNotEqual(element.label, element.label.uppercased(),
                                  "\(state): \(element.identifier) is read in sentence case: “\(element.label)”.",
                                  file: file, line: line)
            }
        }
        assertText(ui.title, WaveText.title(screen, counterpart), state, file: file, line: line)
        assertText(ui.purpose, WaveText.purpose(screen, counterpart), state, file: file, line: line)
        assertText(ui.element("wave.intent.\(viewer.band)"), viewer.intentTitle, state, file: file, line: line)
        if screen == .outConfirm {
            assertText(ui.element("wave.invitation.consent"), "\(counterpart.name) chooses whether to accept.",
                       state, file: file, line: line)
        }
        assertText(ui.preference, counterpart.preferenceAccessibilityLabel,
                   "\(state): counterpart’s spoken preference", file: file, line: line)
        assertText(ui.boundary, WaveText.boundary(screen), state, file: file, line: line)
        if screen.hasDemoCases {
            assertButton(ui.demoCases, WaveText.demoCases, state, file: file, line: line)
        } else {
            XCTAssertFalse(ui.demoCases.exists, "\(state): the confirmation has no Demo cases.", file: file, line: line)
        }
        let offered: [String: String]
        switch screen {
        case .outConfirm: offered = ["wave.send": WaveText.send]
        case .outPending: offered = ["wave.withdraw": WaveText.withdraw]
        case .inReview: offered = ["wave.accept": WaveText.accept, "wave.decline": WaveText.decline]
        default: offered = ["wave.aboutChat": WaveText.aboutChat]
        }
        for id in Self.invitationActions {
            if let label = offered[id] {
                assertButton(ui.element(id), label, state, file: file, line: line)
            } else {
                XCTAssertFalse(nodes.contains { $0.identifier == id }, "\(state): \(id) is not offered here.", file: file, line: line)
            }
        }
        let accepts = nodes.filter { $0.identifier == "wave.accept" || ($0.type == .button && $0.label == WaveText.accept) }
        XCTAssertEqual(accepts.count, screen == .inReview ? 1 : 0,
                       "\(state): Accept only on the recipient's pending review, anywhere in the tree.", file: file, line: line)
        assertIdentifiers(absent: ["wave.menu.", "wave.closed.", "wave.backToMenu"], nodes, state, file: file, line: line)
        let leaks = sampleLeaks(nodes, of: [viewer.other])
        XCTAssertTrue(leaks.isEmpty, "\(state): only \(counterpart.name) is named. " + leaks.joined(separator: "; "),
                      file: file, line: line)
    }

    /// A closed screen (74:571, 74:573, 74:575, 74:576, 74:577, 74:579) or the ended one (74:578): the
    /// closed paper, the approved headline and explanation, the closure line, Back to demo menu (none
    /// once ended); no invitation, ticket, action or anybody's identity anywhere in the tree, and on the
    /// no-allowance example no number at all.
    private func assertClosed(_ screen: WaveScreenKey, _ ui: WaveAssertionUI, _ nodes: [WaveNode], _ state: String,
                              file: StaticString, line: UInt) {
        assertTextIgnoringCase(ui.closedLabel, WaveText.closedLabel, state, file: file, line: line)
        assertText(ui.closedChoice, WaveText.closedChoice, state, file: file, line: line)
        assertText(ui.closedHeadline, WaveText.closedHeadline(screen), state, file: file, line: line)
        assertText(ui.closedExplanation, WaveText.closedExplanation(screen), state, file: file, line: line)
        assertText(ui.closedBoundary, WaveText.closedBoundary, state, file: file, line: line)
        if screen.isClosed {
            assertButton(ui.backToMenu, WaveText.backToMenu, state, file: file, line: line)
        } else {
            XCTAssertFalse(ui.backToMenu.exists, "\(state): once ended there is no way back into the Wave.", file: file, line: line)
        }
        assertIdentifiers(absent: ["wave.invitation", "wave.venue", "wave.menu.", "wave.demoCases"] + Self.invitationActions,
                          nodes, "\(state): nothing of an invitation", file: file, line: line)
        let leaks = sampleLeaks(nodes, of: WaveCounterpart.all)
        XCTAssertTrue(leaks.isEmpty, "\(state): a closed screen names nobody. " + leaks.joined(separator: "; "),
                      file: file, line: line)
        if screen == .allowanceUnavailable {
            // iOS exposes its scroll position as unnamed Other nodes, not product allowance copy.
            // Keep these nodes in every other check and retain their exact evidence here.
            let scrollMetadata = nodes.filter(Self.matchesSystemScrollMetadata)
            if !scrollMetadata.isEmpty {
                let note = XCTAttachment(string: state + "\n" + scrollMetadata.map {
                    "id=\(String(reflecting: $0.identifier)) type=\($0.type) "
                    + "label=\(String(reflecting: $0.label)) value=\(String(reflecting: $0.value))"
                }.joined(separator: "\n"))
                note.name = "wave-system-scroll-metadata"
                note.lifetime = .keepAlways
                add(note)
            }
            let numbers = nodes.filter {
                $0.label.rangeOfCharacter(from: .decimalDigits) != nil && !Self.matchesSystemScrollMetadata($0)
            }
            XCTAssertTrue(numbers.isEmpty, "\(state): no numeric allowance in app content: "
                          + numbers.map {
                              "id=\(String(reflecting: $0.identifier)) type=\($0.type) "
                              + "label=\(String(reflecting: $0.label)) value=\(String(reflecting: $0.value))"
                          }.joined(separator: "; "), file: file, line: line)
        }
    }

    /// Narrow classifier for the exact English iOS scroll-position metadata observed in native snapshots.
    /// Never excludes named app content, readable text/button roles, or other numeric labels/values.
    private static func matchesSystemScrollMetadata(_ node: WaveNode) -> Bool {
        node.type == .other && node.identifier.isEmpty
            && node.label.range(of: "^Vertical scroll bar, [1-9][0-9]* pages?$", options: .regularExpression) != nil
            && node.value.range(of: "^(?:0|[1-9][0-9]?|100)%$", options: .regularExpression) != nil
    }

    /// An overlay over `screen`: its container and label, its approved words, exactly its own controls
    /// (so nothing submits, and the chat information is information only), its Leave, the selected
    /// reason, only the counterpart named where it is theirs, and, in the same snapshot, nothing of the
    /// Wave page, the Room or Places outside it (soft when `softIsolation`, so a capture run takes every
    /// capture).
    private func assertOverlay(_ overlay: WaveOverlayKind, over screen: WaveScreenKey, _ viewer: WaveViewer, _ ui: WaveUI,
                               _ state: String, softIsolation: Bool = false, reuseSnapshot: Bool = true,
                               file: StaticString = #filePath, line: UInt = #line) {
        let counterpart = viewer.counterpart
        let panel = overlay.container(counterpart)
        let nodes = readTree(ui.app, file: file, line: line)
        let ui = WaveAssertionUI(live: ui, nodes: reuseSnapshot ? nodes : nil)
        XCTAssertTrue(nodes.contains { $0.identifier == panel }, "\(state): \(panel) is showing.", file: file, line: line)
        let screens = nodes.map { $0.identifier }.filter { $0.hasPrefix("wave.screen.") }
        XCTAssertTrue(screens.allSatisfy { $0 == "wave.screen.\(screen.rawValue)" },
                      "\(state): the overlay's caller is \(screen.rawValue): \(screens).", file: file, line: line)
        let label = overlay == .conditions ? WaveText.controlsLabel : WaveText.previewLabel
        assertTextIgnoringCase(ui.inPanel(panel, "wavePanel.label"), label, state, file: file, line: line)
        var controls: Set<String> = ["wavePanel.leave"]
        switch overlay {
        case .globalSafety:
            assertText(ui.inPanel(panel, "wavePanel.title"), WaveText.safetyTitle, state, file: file, line: line)
            assertText(ui.inPanel(panel, "wavePanel.explanation"), WaveText.safetyExplanation, state, file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.close"), WaveText.close, state, file: file, line: line)
            controls.insert("wavePanel.close")
        case .counterpartSafety:
            assertText(ui.inPanel(panel, "wavePanel.title"), "\(counterpart.name) · safety", state, file: file, line: line)
            assertText(ui.inPanel(panel, "wavePanel.explanation"), WaveText.counterpartSafetyExplanation, state,
                       file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.block"), "Block \(counterpart.name) in demo", state, file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.previewReport"), WaveText.previewReport, state, file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.back"), WaveText.back, state, file: file, line: line)
            controls.formUnion(["wavePanel.block", "wavePanel.previewReport", "wavePanel.back"])
        case .report(let selected):
            assertText(ui.inPanel(panel, "wavePanel.title"), "Report \(counterpart.name)", state, file: file, line: line)
            assertText(ui.inPanel(panel, "wavePanel.explanation"), WaveText.reportExplanation, state, file: file, line: line)
            for (key, title) in WaveText.reasons {
                let row = ui.inPanel(panel, "wave.report.reason.\(key)")
                guard row.exists else {
                    XCTFail("\(state): “\(title)” is missing.", file: file, line: line)
                    continue
                }
                XCTAssertEqual(row.label, title, "\(state): the approved reason.", file: file, line: line)
                let isSelected = row.isSelected
                XCTAssertEqual(isSelected, key == selected, "\(state): “\(title)” selected \(isSelected), expected "
                               + "\(key == selected).", file: file, line: line)
                XCTAssertGreaterThanOrEqual(row.frame.height, Self.minimumTarget, file: file, line: line)
                controls.insert("wave.report.reason.\(key)")
            }
            assertButton(ui.inPanel(panel, "wavePanel.closePreview"), WaveText.closePreview, state, file: file, line: line)
            controls.insert("wavePanel.closePreview")
        case .chatInfo:
            assertText(ui.inPanel(panel, "wavePanel.title"), WaveText.chatTitle, state, file: file, line: line)
            assertText(ui.inPanel(panel, "wavePanel.explanation"), WaveText.chatExplanation, state, file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.back"), WaveText.back, state, file: file, line: line)
            controls.insert("wavePanel.back")
            let composers = nodes.filter { [.textField, .textView, .secureTextField].contains($0.type) }
            XCTAssertTrue(composers.isEmpty, "\(state): information only, no composer.", file: file, line: line)
        case .conditions:
            assertText(ui.inPanel(panel, "wavePanel.title"), WaveText.conditionsTitle, state, file: file, line: line)
            assertText(ui.inPanel(panel, "wavePanel.explanation"), WaveText.conditionsExplanation, state, file: file, line: line)
            assertButton(ui.inPanel(panel, "wavePanel.showExpired"), WaveText.showExpired, state, file: file, line: line)
            controls.insert("wavePanel.showExpired")
            if screen == .inReview {
                assertButton(ui.inPanel(panel, "wavePanel.showSenderWithdrawn"), WaveText.showSenderWithdrawn, state,
                             file: file, line: line)
                controls.insert("wavePanel.showSenderWithdrawn")
            }
            assertButton(ui.inPanel(panel, "wavePanel.back"), WaveText.back, state, file: file, line: line)
            controls.insert("wavePanel.back")
        }
        assertButton(ui.inPanel(panel, "wavePanel.leave"), WaveText.leave, state, file: file, line: line)
        let inside = nodes.filter { $0.panel == panel }
        let buttons = Set(inside.filter { $0.type == .button }.map { $0.identifier })
        XCTAssertEqual(buttons, controls, "\(state): exactly the overlay's own controls.", file: file, line: line)
        assertNothingSubmits(inside, state, file: file, line: line)
        let named: [WaveCounterpart]
        switch overlay {
        case .counterpartSafety, .report: named = [viewer.other]
        default: named = WaveCounterpart.all
        }
        let leaks = sampleLeaks(inside, of: named)
        XCTAssertTrue(leaks.isEmpty, "\(state): nobody else is named. " + leaks.joined(separator: "; "), file: file, line: line)
        if softIsolation {
            softly {
                assertUnderlayAbsent(panel, nodes, state, file: file, line: line)
            }
        } else {
            assertUnderlayAbsent(panel, nodes, state, file: file, line: line)
        }
    }

    /// While an overlay shows, in one snapshot: nothing outside it that is a Wave page, Room or Places
    /// element (by identifier) or anything readable or tappable (a text, a button, a field), except the
    /// containers that hold the overlay itself (`wave.screen.*`, `room.screen`, `places.screen`). Every
    /// offender is named.
    private func assertUnderlayAbsent(_ panel: String, _ nodes: [WaveNode], _ state: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(nodes.contains { $0.identifier == panel }, "\(state): \(panel) is showing.", file: file, line: line)
        let offenders = nodes.filter { node in
            guard node.panel != panel, !Self.containers.contains(node.identifier),
                  !node.identifier.hasPrefix("wave.screen.")
            else { return false }
            if !node.identifier.isEmpty && Self.underlay.contains(where: { node.identifier.hasPrefix($0) }) {
                return true
            }
            return Self.readable.contains(node.type) && !node.label.isEmpty
        }
        XCTAssertTrue(offenders.isEmpty, "\(state): under \(panel), nothing of the Wave page, the Room or Places is in the "
                      + "tree; still there: " + offenders.map { "\(Self.named($0.identifier)) “\($0.label)”" }.joined(separator: ", "),
                      file: file, line: line)
    }

    /// The Room's People after blocks: the unblocked samples' cards, the blocked ones absent from the whole
    /// tree, the blocked boundary, the filtered empty card only when both are blocked, and no Wave.
    private func assertRoomPeople(_ room: WaveRoomUI, blocked: Set<String>, _ state: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitFor(room.tab("people"), selected: true), "\(state): People is selected.", file: file, line: line)
        for sample in WaveCounterpart.all {
            XCTAssertEqual(room.card(sample.key).exists, !blocked.contains(sample.key),
                           "\(state): \(sample.name)'s card \(blocked.contains(sample.key) ? "is gone" : "stays").",
                           file: file, line: line)
        }
        assertText(room.boundary, blocked.isEmpty ? WaveText.unblockedBoundary : WaveText.blockedBoundary, state,
                   file: file, line: line)
        XCTAssertEqual(room.empty.exists, blocked.count == WaveCounterpart.all.count,
                       "\(state): the filtered empty card only with both blocked.", file: file, line: line)
        let nodes = readTree(room.app, file: file, line: line)
        assertIdentifiers(absent: ["wave.", "wavePanel."], nodes, "\(state): the Wave is closed", file: file, line: line)
        let leaks = sampleLeaks(nodes, of: WaveCounterpart.all.filter { blocked.contains($0.key) })
        XCTAssertTrue(leaks.isEmpty, "\(state): a blocked sample is absent everywhere. " + leaks.joined(separator: "; "),
                      file: file, line: line)
    }

    /// What the Room shows after the blocks, as one line to compare two orders by: People's cards,
    /// boundary and empty card, then Room notes' notes and boundary (the host's note and icebreaker
    /// always, Jules's public note only while he is visible). Leaves People selected.
    private func roomFingerprint(_ room: WaveRoomUI, blocked: Set<String>, _ state: String,
                                 file: StaticString = #filePath, line: UInt = #line) -> String {
        let people = readTree(room.app, file: file, line: line).filter { node in
            node.identifier.hasPrefix("room.card.") || node.identifier == "room.empty" || node.identifier == "room.boundary"
        }.map { $0.identifier == "room.boundary" ? "room.boundary “\($0.label)”" : $0.identifier }.sorted()
        selectTab("notes", room, file: file, line: line)
        XCTAssertTrue(room.hostNote.exists, "\(state): the host's note stays.", file: file, line: line)
        XCTAssertTrue(room.icebreaker.exists, "\(state): the icebreaker stays.", file: file, line: line)
        let julesBlocked = blocked.contains(WaveCounterpart.jules.key)
        XCTAssertEqual(room.julesNote.exists, !julesBlocked,
                       "\(state): Jules's public note \(julesBlocked ? "is gone with him" : "stays").", file: file, line: line)
        XCTAssertEqual(room.hiddenNotesBoundary.exists, julesBlocked, file: file, line: line)
        let notes = readTree(room.app, file: file, line: line).filter { node in
            node.identifier.hasPrefix("room.note") && !node.identifier.hasPrefix("room.notesFraming")
        }.map { $0.identifier }.sorted()
        capture("wave-blocks-\(state.lowercased().replacingOccurrences(of: " ", with: "-"))-notes-fixture", room.app)
        selectTab("people", room, file: file, line: line)
        return "People: " + people.joined(separator: ", ") + "; Room notes: " + notes.joined(separator: ", ")
    }

    /// Where a Back from the menu landed, as one line to compare two ways back by: every `roomProfile.*`
    /// element and its words, with no Wave left in the tree.
    private func profileDestination(_ room: WaveRoomUI, _ state: String,
                                    file: StaticString = #filePath, line: UInt = #line) -> String {
        let nodes = readTree(room.app, file: file, line: line)
        assertIdentifiers(absent: ["wave.", "wavePanel."], nodes, "\(state): the Wave is closed", file: file, line: line)
        let profile = nodes.filter { $0.identifier.hasPrefix("roomProfile.") }
            .map { "\($0.identifier) “\(Self.normalized($0.label))”" }.sorted()
        XCTAssertFalse(profile.isEmpty, "\(state): the Room profile is showing.", file: file, line: line)
        return profile.joined(separator: ", ")
    }

    /// People or Room notes, selected once the model has it and its content shows alone.
    private func selectTab(_ key: String, _ room: WaveRoomUI, file: StaticString = #filePath, line: UInt = #line) {
        let tab = room.tab(key)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "The \(key) tab is showing.", file: file, line: line)
        tapQuietly(tab, room.app, file: file, line: line)
        XCTAssertTrue(waitFor(tab, selected: true), "\(key) is selected.", file: file, line: line)
        let shown = key == "notes" ? room.notesFraming : room.peopleFraming
        XCTAssertTrue(shown.waitForExistence(timeout: 10), "\(key)'s content shows.", file: file, line: line)
        settle()
    }

    /// Places browsing at Now, with no Room and no Wave left in the tree.
    private func assertPlacesNow(_ places: WavePlaces, _ state: String, file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel(places.headline, "Find your kind of place.", file: file, line: line)
        XCTAssertTrue(waitFor(places.tab("now"), selected: true), "\(state): Places browsing at Now.", file: file, line: line)
        waitForLabel(places.ticketName, "Common Ground", file: file, line: line)
        XCTAssertTrue(waitForAbsence(places.element("room.screen")), "\(state): no Room is showing.", file: file, line: line)
        XCTAssertFalse(places.explanationHeadline.exists, "\(state): browsing, not the explanation.", file: file, line: line)
        assertIdentifiers(absent: ["room", "wave"], readTree(places.app, file: file, line: line), state, file: file, line: line)
    }

    /// The column on any width (min(376, width − 64), centred): the screen's full-width buttons, and an
    /// overlay's card (376 wide on the 440-pt iPhone) with its 24-pt inset Leave.
    private func softlyColumn(_ fixture: WaveFixture, _ ui: WaveUI, _ state: String) {
        let width = ui.app.frame.width
        let column = min(376, width - 64), margin = (width - column) / 2
        softly {
            let ui = WaveAssertionUI(live: ui, nodes: readTree(ui.app))
            if let overlay = fixture.overlay {
                let panel = ui.element(overlay.container(fixture.viewer.counterpart))
                XCTAssertEqual(panel.frame.minX, margin, accuracy: 1.5, "\(state): the overlay starts at the column.")
                XCTAssertEqual(panel.frame.width, column, accuracy: 1.5, "\(state): the overlay is the column's width.")
                let leave = ui.inPanel(overlay.container(fixture.viewer.counterpart), "wavePanel.leave")
                XCTAssertEqual(leave.frame.width, column - 48, accuracy: 1.5, "\(state): the overlay's Leave is inset 24 pt.")
                return
            }
            var wide = [ui.leave, ui.returnToPlaces, ui.backToMenu, ui.startOutgoing, ui.startIncoming, ui.noAllowance,
                        ui.send, ui.withdraw, ui.accept, ui.decline, ui.aboutChat]
            wide = wide.filter { $0.exists }
            for element in wide {
                XCTAssertEqual(element.frame.minX, margin, accuracy: 1.5, "\(state): \(element.identifier) starts at the column.")
                XCTAssertEqual(element.frame.width, column, accuracy: 1.5, "\(state): \(element.identifier) spans the column.")
            }
        }
    }

    // MARK: - The tree

    /// Every element of the app in one snapshot (one round trip), with its words, frame, selection and
    /// the overlay container it sits in (the nearest `wavePanel.*` above it, or itself).
    private func readTree(_ app: XCUIApplication,
                          checkingRings ringCheck: (screen: WaveScreenKey, state: String)? = nil,
                          file: StaticString = #filePath, line: UInt = #line) -> [WaveNode] {
        let root: any XCUIElementSnapshot
        do {
            root = try app.snapshot()
        } catch {
            XCTFail("The accessibility tree could not be read: \(error.localizedDescription)", file: file, line: line)
            return []
        }
        var nodes: [WaveNode] = []
        var rings: [any XCUIElementSnapshot] = []
        var stack: [WaveTreeEntry] = [WaveTreeEntry(node: root, panel: nil, depth: 0)]
        while let entry = stack.popLast() {
            let node = entry.node
            if node.identifier == "wave.rings" || node.identifier.hasPrefix("wave.artwork.") { rings.append(node) }
            let panel = Self.isPanelContainer(node.identifier) ? node.identifier : entry.panel
            for child in node.children.reversed() {
                stack.append(WaveTreeEntry(node: child, panel: panel, depth: entry.depth + 1))
            }
            nodes.append(WaveNode(identifier: node.identifier, label: node.label, value: (node.value as? String) ?? "",
                                  type: node.elementType, frame: node.frame, panel: panel,
                                  isEnabled: node.isEnabled, isSelected: node.isSelected, depth: entry.depth,
                                  title: node.title, placeholderValue: node.placeholderValue ?? ""))
        }
        if let ringCheck {
            let issues = ringSnapshotIssues(rings, on: ringCheck.screen)
            if !rings.isEmpty {
                recordRingsSnapshot(root, app, ringCheck.state)
            }
            XCTAssertTrue(issues.isEmpty,
                          "\(ringCheck.state): unexpected decorative-artwork snapshot structure: "
                          + issues.joined(separator: "; "), file: file, line: line)
        }
        return nodes
    }

    /// Structural XCTest check only. Manual Inspector/VoiceOver traversal remains a separate gate:
    /// an empty automation container does not prove exclusion from accessibility focus or speech.
    /// Inspector skipped the separate menu rings and accepted joined rings on 1 October 2026.
    private func ringSnapshotIssues(_ rings: [any XCUIElementSnapshot], on screen: WaveScreenKey) -> [String] {
        guard screen == .menu || screen.isActive else {
            return rings.isEmpty ? [] : ["rings present on a screen without rings"]
        }
        var issues: [String] = []
        if rings.count > 1 { issues.append("expected at most one ring node, found \(rings.count)") }
        for ring in rings {
            if ring.elementType != .other { issues.append("non-Other role") }
            if !ring.children.isEmpty { issues.append("ring has children") }
            if !ring.label.isEmpty { issues.append("nonempty label") }
            if !ring.title.isEmpty { issues.append("nonempty title") }
            let emptyValue = ring.value == nil || (ring.value as? String)?.isEmpty == true
            if !emptyValue { issues.append("nonempty or non-string value") }
            if ring.isSelected { issues.append("selected ring node") }
        }
        return issues
    }

    /// Evidence from the same snapshot used by assertScreen's structural check. Presence can be
    /// permitted, so this is not a failure or a VoiceOver result. Preserve exact properties and
    /// descendants for comparison; the historical strict-absence failure remains in its original bundle.
    private func recordRingsSnapshot(_ root: any XCUIElementSnapshot, _ app: XCUIApplication, _ state: String) {
        var details = ["\(state): Decorative artwork snapshot structure used by assertScreen.",
                       "This is XCTest snapshot evidence, not a VoiceOver focus or speech result."]
        var stack: [(node: any XCUIElementSnapshot, depth: Int, inRings: Bool)] = [(root, 0, false)]
        while let entry = stack.popLast() {
            let node = entry.node
            let inRings = entry.inRings || node.identifier == "wave.rings" || node.identifier.hasPrefix("wave.artwork.")
            if inRings {
                details.append(String(repeating: "  ", count: entry.depth)
                               + "role=\(node.elementType) identifier=\(String(reflecting: node.identifier)) "
                               + "label=\(String(reflecting: node.label)) title=\(String(reflecting: node.title)) "
                               + "value=\(String(reflecting: node.value)) selected=\(node.isSelected) "
                               + "frame=\(Self.rect(node.frame)) children=\(node.children.count)")
            }
            for child in node.children.reversed() {
                stack.append((child, entry.depth + 1, inRings))
            }
        }
        details.append("Exact snapshot dictionary (structural evidence only):")
        details.append(String(reflecting: root.dictionaryRepresentation))
        let attachment = XCTAttachment(string: details.joined(separator: "\n"))
        attachment.name = "wave-rings-structural-snapshot"
        attachment.lifetime = .keepAlways
        add(attachment)
        capture("wave-rings-structural-screen", app)
    }

    /// Where a sample could show up: its name (any case, so the upper-case Wave lines count) or initials
    /// in any words, its introduction, quote, approach line or public note, an interest, and any
    /// identifier that is its own (`….maya`, `….jules.…`).
    private func sampleLeaks(_ nodes: [WaveNode], of samples: [WaveCounterpart]) -> [String] {
        var found: [String] = []
        for node in nodes {
            let texts = [node.label, node.value].filter { !$0.isEmpty }
            let place = Self.named(node.identifier)
            for sample in samples {
                for text in texts {
                    let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    if words.contains(where: { $0.caseInsensitiveCompare(sample.name) == .orderedSame }) || words.contains(sample.initials)
                        || sample.interests.contains(text) || sample.texts.contains(where: { text.contains($0) }) {
                        found.append("\(place) “\(text)” shows \(sample.name)")
                    }
                }
                if node.identifier.hasSuffix(".\(sample.key)") || node.identifier.contains(".\(sample.key).") {
                    found.append("\(node.identifier) is \(sample.name)'s")
                }
            }
        }
        return found
    }

    /// Nothing inside an overlay is named Send, Submit or Sent and no control offers to send or submit
    /// anything (a report is a local, unsent preview: 74:582). Identifiers are read word by word
    /// (`wavePanel.showSenderWithdrawn` is "show sender withdrawn", not a send).
    private func assertNothingSubmits(_ nodes: [WaveNode], _ state: String, file: StaticString = #filePath, line: UInt = #line) {
        let verbs: Set<String> = ["send", "sent", "submit", "submitted", "submits"]
        let offending = nodes.filter { node in
            let words = Set(node.label.lowercased().components(separatedBy: CharacterSet.letters.inverted))
            let named = node.label.range(of: "^(send|submit|sent)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            let control = node.type == .button && !words.isDisjoint(with: verbs)
            return named || control || !Self.identifierWords(node.identifier).isDisjoint(with: verbs)
        }
        XCTAssertTrue(offending.isEmpty, "\(state): nothing is sent or submitted. "
                      + offending.map { "\($0.identifier) “\($0.label)”" }.joined(separator: "; "), file: file, line: line)
    }

    /// An identifier's words, lower case: split at every non-letter and before every capital
    /// ("wavePanel.showSenderWithdrawn" → wave, panel, show, sender, withdrawn).
    private static func identifierWords(_ identifier: String) -> Set<String> {
        var words: Set<String> = []
        var current = ""
        for character in identifier {
            if !character.isLetter || character.isUppercase {
                if !current.isEmpty {
                    words.insert(current.lowercased())
                }
                current = character.isLetter ? String(character) : ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            words.insert(current.lowercased())
        }
        return words
    }

    private func assertIdentifiers(absent prefixes: [String], _ nodes: [WaveNode], except: Set<String> = [], _ state: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let present = nodes.filter { node in
            !except.contains(node.identifier) && prefixes.contains { node.identifier.hasPrefix($0) }
        }.map { $0.identifier }
        XCTAssertTrue(present.isEmpty, "\(state): these should not exist: " + present.joined(separator: ", "),
                      file: file, line: line)
    }

    /// The Room page, the Room's own panels and screens, and Places (browsing, a detail, the explanation),
    /// by prefix: none of it may be in the tree while the Wave shows (`RoomReviewTests.underlay`'s list,
    /// with the Room's panels and ended screen, which the Wave replaces too).
    private static let belowTheWave = [
        "room.", "roomProfile.", "roomPanel.", "roomEntry.", "roomWaiting.", "roomEnded.", "places.", "place.",
        "explanation.",
    ]

    /// What may not be under an overlay: the Wave page and any other overlay, and everything below the Wave.
    private static let underlay = ["wave.", "wavePanel."] + belowTheWave

    /// The containers that hold the Wave (and so its overlays): RoomView's root and Places' screen, which
    /// draws the Room as an overlay inside the container it names.
    private static let containers: Set<String> = ["room.screen", "places.screen"]

    /// Element types a person reads or taps.
    private static let readable: Set<XCUIElement.ElementType> = [
        .button, .staticText, .link, .textField, .secureTextField, .textView, .image, .cell, .switch, .toggle, .slider,
    ]

    /// The controls only an active invitation has.
    private static let invitationActions = ["wave.send", "wave.withdraw", "wave.accept", "wave.decline", "wave.aboutChat"]

    /// An overlay's container (`WaveView.panelIdentifier`), as opposed to a control inside one.
    private static func isPanelContainer(_ identifier: String) -> Bool {
        identifier == "wavePanel.globalSafety" || identifier == "wavePanel.chatInfo" || identifier == "wavePanel.conditions"
            || identifier.hasPrefix("wavePanel.counterpartSafety.") || identifier.hasPrefix("wavePanel.report.")
    }

    private static func isPlaces(_ identifier: String) -> Bool {
        identifier.hasPrefix("places.") || identifier.hasPrefix("place.") || identifier.hasPrefix("explanation.")
    }

    private static func named(_ identifier: String) -> String {
        identifier.isEmpty ? "an element with no identifier" : identifier
    }

    // MARK: - Words and controls

    /// Compares with every run of white space (a line break included) read as one space: a headline is
    /// one element whose lines are joined.
    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func assertText(_ element: any WaveElementReading, _ expected: String, _ state: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let snapshot: WaveElementProperties
        do {
            snapshot = try element.waveProperties()
        } catch {
            XCTFail("\(state): could not verify “\(expected)” is showing: \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(Self.normalized(snapshot.label), Self.normalized(expected), "\(state): the approved words.",
                       file: file, line: line)
    }

    /// An upper-case line of the design (a label, the DEMO badge): the approved words in any case, since
    /// VoiceOver may read it in sentence case.
    private func assertTextIgnoringCase(_ element: any WaveElementReading, _ expected: String, _ state: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let snapshot: WaveElementProperties
        do {
            snapshot = try element.waveProperties()
        } catch {
            XCTFail("\(state): could not verify “\(expected)” is showing: \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(Self.normalized(snapshot.label).lowercased(), Self.normalized(expected).lowercased(),
                       "\(state): the approved words.", file: file, line: line)
    }

    /// A line whose visible words are upper case and whose spoken words are the app's own sentence
    /// (lead decision 8): it must name each of `words`, in any case.
    private func assertMentions(_ element: any WaveElementReading, _ words: [String], _ state: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else {
            XCTFail("\(state): the line naming \(words) is not showing.", file: file, line: line)
            return
        }
        let label = element.label
        for word in words {
            XCTAssertNotNil(label.range(of: word, options: .caseInsensitive),
                            "\(state): \(element.identifier) names “\(word)”: “\(label)”.", file: file, line: line)
        }
    }

    private func assertButton(_ element: any WaveElementReading, _ label: String, _ state: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let snapshot: WaveElementProperties
        do {
            snapshot = try element.waveProperties()
        } catch {
            XCTFail("\(state): could not verify “\(label)” is offered: \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(snapshot.label, label, "\(state): the approved label.", file: file, line: line)
        XCTAssertTrue(snapshot.isEnabled, "\(state): “\(label)” is enabled.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(snapshot.frame.height, Self.minimumTarget, "\(state): “\(label)” is 44 pt tall or more.",
                                    file: file, line: line)
    }

    /// A choice that is shown but disabled (the blocked menu's): its own label, not enabled, and still at
    /// least 44 pt tall. Never tapped here.
    private func assertDisabledChoice(_ element: any WaveElementReading, _ label: String, _ state: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let snapshot: WaveElementProperties
        do {
            snapshot = try element.waveProperties()
        } catch {
            XCTFail("\(state): could not verify “\(label)” is shown: \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(snapshot.label, label, "\(state): the choice keeps its own label.", file: file, line: line)
        XCTAssertFalse(snapshot.isEnabled, "\(state): “\(label)” is disabled.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(snapshot.frame.height, Self.minimumTarget, "\(state): “\(label)” is 44 pt tall or more.",
                                    file: file, line: line)
    }

    /// The menu's visible Back (75:119): shown, named "Back", enabled, at least 44 × 44, and hittable where it is.
    private func assertMenuBack(_ ui: WaveUI, _ state: String, file: StaticString = #filePath, line: UInt = #line) {
        assertButton(ui.back, WaveText.back, "\(state): the menu's visible Back", file: file, line: line)
        assertIconButton(ui.back, containing: "back", state, file: file, line: line)
        XCTAssertTrue(ui.back.isHittable, "\(state): the menu's Back can be tapped where it is.", file: file, line: line)
    }

    /// A 44 × 44 chrome icon (the shield, the Back chevron), named for what it does.
    private func assertIconButton(_ element: any WaveElementReading, containing word: String, _ state: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let snapshot: WaveElementProperties
        do {
            snapshot = try element.waveProperties()
        } catch {
            XCTFail("\(state): could not verify the chrome's \(word) is offered: \(error)", file: file, line: line)
            return
        }
        XCTAssertNotNil(snapshot.label.range(of: word, options: .caseInsensitive),
                        "\(state): the chrome's \(word) is named for it: “\(snapshot.label)”.", file: file, line: line)
        XCTAssertTrue(snapshot.isEnabled, "\(state): the chrome's \(word) is enabled.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(snapshot.frame.width, Self.minimumTarget, "\(state): \(word) is 44 pt wide.",
                                    file: file, line: line)
        XCTAssertGreaterThanOrEqual(snapshot.frame.height, Self.minimumTarget, "\(state): \(word) is 44 pt tall.",
                                    file: file, line: line)
    }

    // MARK: - Largest text

    /// The first element at rest (the chrome's brand, or an overlay's label) lies below the status bar
    /// (62 pt on the 956-pt iPhone, 47 on the 844-pt one).
    private func assertBelowStatusBar(_ identifier: String, _ nodes: [WaveNode], _ app: XCUIApplication, _ state: String) {
        guard let node = nodes.first(where: { $0.identifier == identifier }) else {
            XCTFail("\(state): \(identifier) is in the tree.")
            return
        }
        let statusBar: CGFloat = app.frame.height >= 900 ? 62 : 47
        XCTAssertGreaterThanOrEqual(node.frame.minY, statusBar - 1, "\(state): \(identifier) starts below the status bar "
                                    + "(\(Self.rect(node.frame))).")
    }

    /// The horizontal extent texts must stay inside: the overlay's, or the column's.
    private func horizontalBounds(_ container: String?, _ ui: WaveUI) -> ClosedRange<CGFloat> {
        if let container {
            let frame = ui.element(container).frame
            return frame.minX...frame.maxX
        }
        let width = ui.app.frame.width
        let margin = (width - min(376, width - 64)) / 2
        return margin...(width - margin)
    }

    /// Build 9 Small passed the individual growth/reachability checks while these two rendered text
    /// frames overlapped by 106 pt. Read both from the same settled snapshot after revealing purpose,
    /// before another scroll: independent boxes can be tall enough and still collide with each other.
    private func assertAcceptedPurposePrecedesPreference(_ ui: WaveUI, _ state: String) {
        let nodes = readTree(ui.app)
        let purposes = nodes.filter { $0.identifier == "wave.invitation.purpose" && $0.type == .staticText }
        let preferences = nodes.filter { $0.identifier == "wave.invitation.preference" && $0.type == .staticText }
        guard purposes.count == 1, preferences.count == 1,
              let purpose = purposes.first, let preference = preferences.first else {
            XCTFail("\(state): one purpose and one preference text must exist in the same snapshot.")
            return
        }
        let upper = purpose.frame, lower = preference.frame
        guard upper.minY.isFinite, upper.maxY.isFinite, lower.minY.isFinite, lower.maxY.isFinite,
              upper.height > 0, lower.height > 0 else {
            XCTFail("\(state): invitation text frames must have finite, positive heights.")
            return
        }
        let gap = lower.minY - upper.maxY
        attachNote("\(state): accepted-card text separation in one snapshot: purpose=\(Self.rect(upper)); "
                   + "preference=\(Self.rect(lower)); vertical gap=\(Self.pt(gap)) pt.")
        XCTAssertGreaterThanOrEqual(gap, -1,
                                   "\(state): purpose ends above preference; text must not overlap "
                                   + "(purpose \(Self.rect(upper)), preference \(Self.rect(lower))).")
        if gap < -1 {
            capture("wave-in-accepted-largest-text-overlap-\(Int(ui.app.frame.width.rounded()))pt-fixture", ui.app)
        }
    }

    /// A text, brought into view: its words, a box grown well past its Figma height (at least 1.3 times
    /// it, and 30 pt: a box that did not grow is fixed or clipped), inside its column or overlay.
    /// A fresh reading after reveal (and after the live hittability check for an enabled button).
    /// No reading escapes the current item; the next reveal always measures its own settled state.
    // These callers use app.descendants(.any).matching(identifier:).firstMatch, never a scoped query.
    // Keep the same fresh-read boundary, but resolve the first descendant in one app snapshot using
    // the identifying properties and preorder already audited by WaveAssertionElement.
    private func readElementForAssertion(_ identifier: String, _ app: XCUIApplication, _ state: String,
                                         file: StaticString = #filePath, line: UInt = #line) -> (any XCUIElementSnapshot)? {
        do {
            let root = try app.snapshot()
            var stack: [any XCUIElementSnapshot] = Array(root.children.reversed())
            while let node = stack.popLast() {
                if [node.identifier, node.title, node.label, (node.value as? String) ?? "",
                    node.placeholderValue ?? ""].contains(identifier) {
                    return node
                }
                stack.append(contentsOf: node.children.reversed())
            }
            throw WaveSnapshotLookupError.missingElement(identifier: identifier, panel: nil)
        } catch {
            XCTFail("\(state): could not read settled element properties: \(error)", file: file, line: line)
            return nil
        }
    }

    private func assertUnclipped(_ id: String, grownFrom figma: CGFloat, within bounds: ClosedRange<CGFloat>,
                                 _ ui: WaveUI, _ state: String) {
        guard reveal(id, ui.app) else { return }
        guard let element = readElementForAssertion(id, ui.app, state) else { return }
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

    /// A disabled choice (the blocked menu's), brought into view but never tapped: its own label, disabled,
    /// at least 44 pt tall and on screen. Whether a disabled control reports itself hittable is not asked.
    private func assertReachableDisabledButton(_ id: String, _ label: String, _ ui: WaveUI, _ state: String) {
        guard reveal(id, ui.app) else { return }
        guard let button = readElementForAssertion(id, ui.app, state) else { return }
        XCTAssertEqual(button.label, label, "\(state): \(id) keeps its own label.")
        XCTAssertFalse(button.isEnabled, "\(state): \(id) is disabled.")
        XCTAssertGreaterThanOrEqual(button.frame.height, Self.minimumTarget, "\(state): \(id) is \(Self.pt(button.frame.height)) pt tall.")
        XCTAssertLessThanOrEqual(button.frame.maxY, ui.app.frame.maxY, "\(state): \(id) is on screen.")
    }

    /// A button, brought into view: it can be tapped and is at least 44 pt tall.
    private func assertReachableButton(_ id: String, _ ui: WaveUI, _ state: String) {
        guard reveal(id, ui.app) else { return }
        let button = ui.element(id)
        XCTAssertTrue(button.isHittable, "\(state): \(id) can be tapped once in view.")
        guard let button = readElementForAssertion(id, ui.app, state) else { return }
        XCTAssertGreaterThanOrEqual(button.frame.height, Self.minimumTarget, "\(state): \(id) is \(Self.pt(button.frame.height)) pt tall.")
        XCTAssertLessThanOrEqual(button.frame.maxY, ui.app.frame.maxY, "\(state): \(id) is on screen.")
    }

    // MARK: - Scrolling

    /// Brings the control `identifier` into view (found inside `panel`'s container when one is given),
    /// proves it can be tapped where it now is, and only then taps it. Returns false, having failed at
    /// the caller's line, when it could not be brought into view or is not hittable there.
    @discardableResult
    private func revealThenTap(_ identifier: String, in panel: String?, _ ui: WaveUI, _ state: String,
                               file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard reveal(identifier, ui.app, file: file, line: line) else { return false }
        let control = panel.map { ui.inPanel($0, identifier) } ?? ui.element(identifier)
        let hittable = control.isHittable
        XCTAssertTrue(hittable, "\(state): \(identifier) can be tapped once in view (\(Self.rect(control.frame))).",
                      file: file, line: line)
        guard hittable else { return false }
        let quiet = Date().timeIntervalSince(lastTap)
        if quiet < 0.8 {
            waitQuietly(0.8 - quiet)
        }
        control.tap()
        lastTap = Date()
        return true
    }

    /// `RoomReviewTests.reveal`, for the Wave: brings the element with `identifier` into its active
    /// viewport, clear of what really covers that viewport; an element taller than the space counts once
    /// its top is in view. An element in no scroll view only has to be on screen; so does one of the bar's
    /// own (`barIdentifiers`) while it is on screen, wherever the tree places it (the bar is the page
    /// scroll view's bottom inset, `WaveView.page`). Returns whether it did; when it did not, it has
    /// already failed the test at the caller's line with every look and drag attached: "Scroll PRODUCT"
    /// when two drags in a row did not move the page, "Scroll HARNESS" for everything else.
    ///
    /// The viewport is the element's scroll view, cut to the space between the status bar (62 on the
    /// 956-pt iPhone, 47 on the 844-pt one) and the screen's bottom less the home indicator's 20 pt. In
    /// an overlay only that overlay's own elements outside its scroll view cover it (it has none: the
    /// whole card scrolls); never the dimmed page, the Room or Places beneath. On a Wave page the bar
    /// covers it from its ground's top: its first element's top less the bar's top padding
    /// (`WaveView.barTop`: 13 pt, 10 under the incoming review; 13 is used, the stricter).
    ///
    /// Short, momentum-free drags (press 0.05 s, slow, held 0.2 s before release), each touching down
    /// inside the element's scroll view on nothing that is a control of the element's own layer (10 pt
    /// clear), never within 40 pt of the leading screen edge (the back swipe). The usual points also
    /// avoid the trailing 40 pt; a page-only fallback uses the trailing gutter, 16 pt inside the screen
    /// and scroll view. Drags start 0.7 s after the last. Every look and drag prints a `WAVE_SCROLL` line.
    @discardableResult
    private func reveal(_ identifier: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var trace: [String] = []
        var lifted = Date.distantPast
        var lastTouch: CGPoint?
        var lastTop: CGFloat?
        var direction: CGFloat = 0
        var stalls = 0
        for attempt in 0..<40 {
            let look: WaveRevealLook
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
            let onScreen = frame.minY >= 0 && frame.maxY <= screen.maxY
            let fixed = look.scroller == nil || (Self.barIdentifiers.contains(identifier) && onScreen)
            let statusBar: CGFloat = screen.height >= 900 ? 62 : 47
            let top: CGFloat = fixed ? 0 : max(statusBar, look.scroller?.minY ?? statusBar)
            var bottom: CGFloat = fixed
                ? screen.maxY - 8
                : min(look.scroller?.maxY ?? screen.maxY, screen.maxY - Self.homeIndicatorMargin)
            if !fixed, let bar = look.barTop {
                bottom = min(bottom, bar)
            }
            let fits = frame.height <= bottom - top - 2
            let low = fits ? frame.maxY > bottom + 1 : frame.minY > bottom - 44
            let high = frame.minY < top - 1
            let barText = look.barTop.map { Self.pt($0) } ?? "none"
            let layer = look.panel.map { "in overlay \($0)" } ?? "on the page"
            let lookLine = "look \(attempt + 1): \(Self.rect(frame)) \(layer); range \(Self.pt(top))–\(Self.pt(bottom)); "
                + "scroll view \(Self.rect(look.scroller)); bar top \(barText), set by \(look.barSource)"
            trace.append(lookLine)
            print("WAVE_SCROLL \(identifier) \(lookLine)")
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
            var travel = min(max(distance, 24), room, 360)
            var found = revealTouch(look, scroller: scroller, travel: travel, fingerUp: low, bandTop: bandTop,
                                    bandBottom: bandBottom, awayFrom: lastTouch)
            while found == nil && travel > 24 {
                travel = max(24, (travel / 2).rounded())
                found = revealTouch(look, scroller: scroller, travel: travel, fingerUp: low, bandTop: bandTop,
                                    bandBottom: bandBottom, awayFrom: lastTouch)
            }
            guard let start = found else {
                return revealFailed("HARNESS", identifier, "no touch-down point in the scroll view keeps 10 pt from every control",
                                    trace, app, file: file, line: line)
            }
            let end = CGPoint(x: start.x, y: start.y + (low ? -travel : travel))
            let quiet = min(Date().timeIntervalSince(lifted), Date().timeIntervalSince(lastTap))
            if quiet < 0.7 {
                waitQuietly(0.7 - quiet)
            }
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: start.x, dy: start.y))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            lifted = Date()
            lastTap = lifted
            lastTouch = start
            lastTop = frame.minY
            direction = low ? 1 : -1
            let entry = "drag \(attempt + 1) \(low ? "up" : "down") \(Self.point(start)) → \(Self.point(end))"
            trace.append(entry)
            print("WAVE_SCROLL \(identifier) \(entry)")
        }
        return revealFailed("HARNESS", identifier, "40 looks did not bring it into view", trace, app, file: file, line: line)
    }

    /// Reads the tree once the target has stopped moving (two reads 0.15 s apart within 0.5 pt, at most
    /// four more), so a rubber band is never measured half-way.
    private func settledRevealLook(_ identifier: String, _ app: XCUIApplication, settle: Bool) throws -> WaveRevealLook {
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

    /// One snapshot of the whole app: the target; the nearest scroll view and the nearest overlay
    /// container above it; the edge of what covers the lower part of its viewport, and which element set
    /// it; and the controls of its layer. In an overlay: only that overlay's own elements outside the
    /// target's scroll view, in its lower half. On a Wave page: the bar's own elements wherever the tree
    /// places them, or anything else outside every scroll view in the lower half, never an overlay's or
    /// a Places element (Places lies under the Room and the Wave, not in front of them), less the bar's
    /// top padding.
    private func revealLook(_ identifier: String, _ app: XCUIApplication) throws -> WaveRevealLook {
        let root = try app.snapshot()
        var look = WaveRevealLook()
        look.screen = root.frame
        var placed: [WaveRevealPlaced] = []
        var stack: [WaveRevealEntry] = [WaveRevealEntry(node: root, scroller: nil, panel: nil)]
        while let entry = stack.popLast() {
            let node = entry.node
            let panel = Self.isPanelContainer(node.identifier) ? node.identifier : entry.panel
            if !look.found && node.identifier == identifier {
                look.found = true
                look.target = node.frame
                look.scroller = entry.scroller
                look.panel = panel
            }
            placed.append(WaveRevealPlaced(frame: node.frame, scroller: entry.scroller, panel: panel, identifier: node.identifier,
                                           control: Self.controlTypes.contains(node.elementType)))
            let inner: CGRect? = node.elementType == .scrollView ? node.frame : entry.scroller
            for child in node.children.reversed() {
                stack.append(WaveRevealEntry(node: child, scroller: inner, panel: panel))
            }
        }
        look.controls = placed.filter { $0.control && $0.panel == look.panel }.map { $0.frame }
        guard look.found, let scroller = look.scroller else { return look }
        let screenBottom = look.screen.maxY
        let onScreenAcross = { (item: WaveRevealPlaced) -> Bool in
            item.frame.minY < screenBottom && item.frame.height > 0
                && item.frame.maxX > scroller.minX && item.frame.minX < scroller.maxX && item.identifier != identifier
        }
        let lowerHalf = { (item: WaveRevealPlaced) -> Bool in
            item.frame.minY >= scroller.midY && onScreenAcross(item)
        }
        if let panel = look.panel {
            let covering = placed.filter { item in
                let sameScroller = item.scroller.map { Self.sameFrame($0, scroller) } ?? false
                return item.panel == panel && item.identifier != panel && !sameScroller && lowerHalf(item)
            }
            if let first = covering.min(by: { $0.frame.minY < $1.frame.minY }) {
                look.barTop = first.frame.minY
                look.barSource = "\(Self.named(first.identifier)) \(Self.rect(first.frame)) in overlay \(panel)"
            }
        } else {
            let bar = placed.filter { item in
                guard item.panel == nil, !Self.isPlaces(item.identifier) else { return false }
                if Self.barIdentifiers.contains(item.identifier) {
                    return onScreenAcross(item)
                }
                return item.scroller == nil && lowerHalf(item)
            }
            // The incoming review's bar pads 10 above Leave and its content ends flush (the approved 74:572
            // layout); every other screen pads 13. With 13 on the review, its last control (Decline) could never
            // come clear of the edge at the largest text.
            let padding = placed.contains { $0.identifier == "wave.screen.in-review" }
                ? Self.reviewBarTopPadding : Self.barTopPadding
            if let first = bar.min(by: { $0.frame.minY < $1.frame.minY }) {
                look.barTop = first.frame.minY - padding
                look.barSource = "\(Self.named(first.identifier)) \(Self.rect(first.frame)) on the page, less the bar's "
                    + "\(Self.pt(padding))-pt top padding"
            }
        }
        return look
    }

    private static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1 && abs(a.width - b.width) <= 1
            && abs(a.height - b.height) <= 1
    }

    /// `WaveView.barTop`: 13 pt above Leave or Return to Places, and 10 under the incoming review.
    private static let barTopPadding: CGFloat = 13
    private static let reviewBarTopPadding: CGFloat = 10

    /// Kept clear above the screen's bottom edge, for the home indicator.
    private static let homeIndicatorMargin: CGFloat = 20

    /// What the Wave keeps in the bar below its scrolling content (`WaveView.actionBar`): never scrolled.
    private static let barIdentifiers: Set<String> = ["wave.leave", "wave.returnToPlaces"]

    /// Where a drag touches down: first search the existing middle/column candidates, 40 pt clear of
    /// both screen edges. If they are all occupied, a page (never an overlay) may use the trailing gutter,
    /// 16 pt inside both the screen and scroll view; PlacesEdgeBack owns only the leading edge. All
    /// candidates stay at least 40 pt from that leading edge, keep the whole drag in the vertical band,
    /// remain 10 pt clear of every control of the target's layer, and prefer 60 pt from the last touch.
    private func revealTouch(_ look: WaveRevealLook, scroller: CGRect, travel: CGFloat, fingerUp: Bool, bandTop: CGFloat,
                             bandBottom: CGFloat, awayFrom previous: CGPoint?) -> CGPoint? {
        let fractions: [CGFloat] = [0.5, 0.33, 0.67]
        var xs = fractions.map { scroller.minX + scroller.width * $0 }
        let screenWidth = look.screen.width
        let margin = (screenWidth - min(376, screenWidth - 64)) / 2
        xs += [margin + 12, screenWidth - margin - 12]
        xs = xs.filter { $0 >= 40 && $0 <= screenWidth - 40 }
        var searches = [xs]
        if look.panel == nil {
            let trailingX = min(look.screen.maxX, scroller.maxX) - 16
            if trailingX >= max(look.screen.minX + 40, scroller.minX + 16) {
                searches.append([trailingX])
            }
        }
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
        for candidates in searches {
            for spaced in [true, false] {
                for y in ys {
                    for x in candidates {
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
        }
        return nil
    }

    /// Attaches the reason, every look and drag, and the screen, then fails with "Scroll PRODUCT: …" or
    /// "Scroll HARNESS: …" at the caller's line.
    private func revealFailed(_ kind: String, _ identifier: String, _ reason: String, _ trace: [String],
                              _ app: XCUIApplication, file: StaticString, line: UInt) -> Bool {
        let lines = ["reveal \(kind) \(identifier): \(reason)"] + trace
        print("WAVE_SCROLL_FAILED " + lines.joined(separator: " | "))
        attachNote(lines.joined(separator: "\n"))
        capture("wave-scroll-\(kind.lowercased())-\(identifier)", app)
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

    private func waitFor(_ element: XCUIElement, enabled: Bool) -> Bool {
        if element.exists && element.isEnabled == enabled {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)),
                                                    object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        if element.exists && element.isSelected == selected {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)),
                                                    object: element)
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
    /// shortened by `PROXIMEET_SHORT_HOLDS`. (After Accept, the 800-ms join is waited for separately.)
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

    /// With `PROXIMEET_SHORT_HOLDS=1` (unrecorded runs), a hold is at most 0.6 s: longer than any 240-ms
    /// dissolve it waits for. Never in the recorded walkthrough (`fullHolds`).
    private func hold(_ seconds: TimeInterval) {
        let short = !fullHolds && ProcessInfo.processInfo.environment["PROXIMEET_SHORT_HOLDS"] == "1"
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
}

// MARK: - Fixtures and facts

/// The approved Wave copy (`WaveCopy`, Figma 74:568–74:586), written out, with the counterpart's name
/// where the reference says "Maya" and the viewer's where it says "Alex"; lines joined by a space where
/// a headline reads as one element (the comparison reads any line break as a space).
private enum WaveText {
    static let brand = "Proximeet"
    static let composeBrand = "Private invitation"
    static let demoBadge = "Demo"
    static let menuHeadline = "Every hello\nneeds a choice."
    static func role(_ name: String) -> String { "You are \(name) in both examples." }
    static let menuBoundary = "Choose a new, independent demo.\nNo invitation is sent to anyone."
    /// `WaveCopy.menuBlocked`: in the boundary's place once the counterpart is blocked; it names nobody.
    static let menuBlocked = "Connection blocked.\nNew examples are unavailable in this demo."
    static let startOutgoing = "Start outgoing example"
    static let startIncoming = "Start incoming example"
    static let showNoAllowance = "Show no-allowance example"
    /// The menu's three choices, top down: identifier and label.
    static let menuChoices = [
        ("wave.menu.startOutgoing", startOutgoing),
        ("wave.menu.startIncoming", startIncoming),
        ("wave.menu.noAllowance", showNoAllowance),
    ]
    static let leave = "Leave and disappear"
    static let venueName = "Common Ground"
    static let demoCases = "Demo cases"
    static let send = "Send private invitation"
    static let withdraw = "Withdraw Wave"
    static let accept = "Accept Wave"
    static let decline = "Decline Wave"
    static let aboutChat = "About private chat"
    static let back = "Back"

    /// The direction line as VoiceOver reads it (`WaveCopy.directionSpoken`): the sender, then the
    /// recipient, with "you" for the viewer's identity and the Guest List name, trimmed, after it.
    static func direction(_ screen: WaveScreenKey, viewer: String, counterpart: String) -> String {
        let you = "you (\(viewer.trimmingCharacters(in: .whitespacesAndNewlines)))"
        switch screen {
        case .outConfirm, .outPending: return "From \(you) to \(counterpart). Outgoing."
        case .inReview: return "From \(counterpart) to \(you). Incoming."
        default: return "\(counterpart) and \(you). Incoming demo."
        }
    }

    static func title(_ screen: WaveScreenKey, _ counterpart: WaveCounterpart) -> String {
        switch screen {
        case .outConfirm:
            switch counterpart.key {
            case "jules": return "An idea worth sharing."
            case "sam": return "A plan to join."
            case "riley": return "A spark to explore."
            default: return "A little company."
            }
        case .outPending: return "Waiting for \(counterpart.name)."
        case .inReview: return "An invitation for you."
        default: return "You both said yes."
        }
    }

    static func purpose(_ screen: WaveScreenKey, _ counterpart: WaveCounterpart) -> String {
        switch screen {
        case .outConfirm:
            switch counterpart.key {
            case "jules": return "A private hello about ideas and opportunities."
            case "sam": return "A private hello for a walk, workout, or game."
            case "riley": return "A private hello to see if the interest is mutual."
            default: return "A private hello for coffee and conversation."
            }
        case .outPending: return "Only \(counterpart.name) can accept.\nYou can withdraw at any time."
        case .inReview: return "Accept only if you want to.\nNo explanation needed to decline."
        default: return "A temporary private chat\ncan open next."
        }
    }

    static func boundary(_ screen: WaveScreenKey) -> String {
        switch screen {
        case .outConfirm: return "Wave allowance available in this demo.\nNothing is sent."
        case .outPending: return "This is your outgoing invitation.\nNothing is sent."
        case .inReview: return "A separate incoming example.\nNothing is sent."
        default: return "Both agreed to a temporary chat in this demo.\nChat and Keep come next."
        }
    }

    static let closedLabel = "AN INVITATION"
    static let closedChoice = "There is always room to choose."
    static let closedBoundary = "Demo state · no active invitation."
    static let backToMenu = "Back to demo menu"
    static let returnToPlaces = "Return to Places"

    static func closedHeadline(_ screen: WaveScreenKey) -> String {
        switch screen {
        case .outWithdrawn: return "Wave\nwithdrawn."
        case .inDeclined: return "Your choice.\nNo pressure."
        case .unavailable: return "Wave\nunavailable."
        case .blocked: return "Connection\nblocked."
        case .allowanceUnavailable: return "No Wave\nallowance."
        case .inWithdrawn: return "Invitation\nwithdrawn."
        default: return "You’ve left\nthe room."
        }
    }

    static func closedExplanation(_ screen: WaveScreenKey) -> String {
        switch screen {
        case .outWithdrawn: return "This outgoing example is closed.\nIt cannot open a chat."
        case .inDeclined: return "This incoming Wave is declined and closed.\nNo explanation needed."
        case .unavailable: return "This example expired or the session\nis no longer eligible."
        case .blocked: return "The other person’s sample card and invitation\nare hidden in this demo."
        case .allowanceUnavailable: return "No Wave allowance in this example.\nThis demo does not define a production quota."
        case .inWithdrawn: return "The sender withdrew this invitation.\nAccept is no longer available."
        default: return "The demo session is ended.\nNo active invitation or chat remains."
        }
    }

    static let previewLabel = "DEMO PREVIEW"
    static let controlsLabel = "DEMO REVIEW CONTROLS"
    static let safetyTitle = "Your choice\ncomes first."
    static let safetyExplanation = "You can leave at any time. Demo reports stay local, and no invitation is sent to anyone."
    static let close = "Close"
    static let counterpartSafetyExplanation =
        "Blocking hides this fictional person’s card and invitation from the current example."
    static let previewReport = "Preview report"
    static let reportExplanation = "Choose a sample reason.\nExample only — nothing is submitted."
    static let closePreview = "Close preview"
    static let reasons = [
        ("unwantedAttention", "Unwanted attention"),
        ("harassment", "Harassment or harmful content"),
        ("somethingElse", "Something else"),
    ]
    static let chatTitle = "A private chat.\nBy mutual choice."
    static let chatExplanation = "Both people have agreed in this incoming demo. Private Chat and Keep are the next chapter."
    static let conditionsTitle = "Try a closed\nexample."
    static let conditionsExplanation = "These controls choose static demo conditions. No timer or real session is running."
    static let showExpired = "Show expired example"
    static let showSenderWithdrawn = "Show sender withdrawn"

    // The Room around the Wave (`RoomCopy`).
    static let previewWaveDemo = "Preview Wave demo"
    static let backToPeople = "Back to people"
    static let unblockedBoundary = "Fictional cards. Nothing is sent."
    static let blockedBoundary = "Your demo blocks remain applied."
}

/// The twelve approved screens (`WaveScreen`'s raw values, which name `wave.screen.<raw>`).
private enum WaveScreenKey: String, CaseIterable {
    case menu = "demo-menu"
    case outConfirm = "out-confirm"
    case outPending = "out-pending"
    case outWithdrawn = "out-withdrawn"
    case inReview = "in-review"
    case inDeclined = "in-declined"
    case inAccepted = "in-accepted"
    case unavailable
    case blocked
    case allowanceUnavailable = "allowance-unavailable"
    case sessionEnded = "session-ended"
    case inWithdrawn = "in-withdrawn"

    var figma: String {
        switch self {
        case .menu: return "74:568"
        case .outConfirm: return "74:569"
        case .outPending: return "74:570"
        case .outWithdrawn: return "74:571"
        case .inReview: return "74:572"
        case .inDeclined: return "74:573"
        case .inAccepted: return "74:574"
        case .unavailable: return "74:575"
        case .blocked: return "74:576"
        case .allowanceUnavailable: return "74:577"
        case .sessionEnded: return "74:578"
        case .inWithdrawn: return "74:579"
        }
    }

    /// Its DEBUG fixture (`-ProximeetFixture`).
    var fixture: String { self == .menu ? "wave-menu" : "wave-\(rawValue)" }

    /// An active invitation, with the counterpart on screen.
    var isActive: Bool { [.outConfirm, .outPending, .inReview, .inAccepted].contains(self) }

    /// The closed screens with Back to demo menu (not the ended one).
    var isClosed: Bool { [.outWithdrawn, .inDeclined, .unavailable, .blocked, .allowanceUnavailable, .inWithdrawn].contains(self) }

    var isOutgoing: Bool { [.outConfirm, .outPending, .outWithdrawn].contains(self) }

    /// The 75:119 chrome (Back and "Wave"): the unsent confirmation and, by the founder's decision of 30
    /// September 2026, the menu, whose Back returns to the Room.
    var hasBack: Bool { self == .menu || self == .outConfirm }

    /// "Demo cases" (75:363 / 75:402 / 75:444): pending, review and accepted only.
    var hasDemoCases: Bool { [.outPending, .inReview, .inAccepted].contains(self) }
}

/// The Wave's overlays, as `-ProximeetWavePanel` names them.
private enum WaveOverlayKind: Equatable {
    case globalSafety
    case counterpartSafety
    /// The report preview, with its selected reason's key (none when nil).
    case report(String?)
    case chatInfo
    case conditions

    var fixture: String {
        switch self {
        case .globalSafety: return "global-safety"
        case .counterpartSafety: return "safety"
        case .report: return "report"
        case .chatInfo: return "chat-info"
        case .conditions: return "conditions"
        }
    }

    /// Its container's identifier (`WaveView.panelIdentifier`).
    func container(_ counterpart: WaveCounterpart) -> String {
        switch self {
        case .globalSafety: return "wavePanel.globalSafety"
        case .counterpartSafety: return "wavePanel.counterpartSafety.\(counterpart.key)"
        case .report: return "wavePanel.report.\(counterpart.key)"
        case .chatInfo: return "wavePanel.chatInfo"
        case .conditions: return "wavePanel.conditions"
        }
    }
}

/// A fictional sample as approved (`RoomActor`), as the Wave names it.
private struct WaveCounterpart: Sendable {
    let key: String
    let name: String
    let initials: String
    /// "[Intent] · [Approach]": the sample's own values, which the invitation's preference line shows
    /// (contract `counterpartMapping`).
    let preference: String
    /// Spoken ownership is additional context; the visible preference string above remains unchanged.
    var preferenceAccessibilityLabel: String { "\(name)’s intent and approach: \(preference)" }
    let interests: [String]
    /// The sample's own words anywhere in the Room (introduction, quote, approach line, public note).
    let texts: [String]

    static let maya = WaveCounterpart(
        key: "maya", name: "Maya", initials: "ML", preference: "Social · Chat first",
        interests: ["Coffee", "Bookshops", "Detours"],
        texts: ["Coffee, bookshops, and a good detour.", "Tell me about a place you’d go back to.",
                "Prefers a Wave and a chat before meeting."]
    )
    static let jules = WaveCounterpart(
        key: "jules", name: "Jules", initials: "JR", preference: "Business · Okay to say hello",
        interests: ["Design", "Ideas", "Small business"],
        texts: ["Design, ideas, and small businesses.", "Always curious about what people are building.",
                "Open to a brief hello. No pressure to continue.", "One good question can change an evening."]
    )
    static let sam = WaveCounterpart(
        key: "sam", name: "Sam", initials: "SP", preference: "Activity · Chat first",
        interests: ["Walking", "Outdoors", "Games"],
        texts: ["Walks, fresh air, and a reason to get outside.", "A good route is even better with company."]
    )
    static let riley = WaveCounterpart(
        key: "riley", name: "Riley", initials: "RK", preference: "Dating · Chat first",
        interests: ["Coffee", "Music", "Conversation"],
        texts: ["Good conversation and a little curiosity.", "Happy to take things one hello at a time."]
    )
    // Existing Social/Business cross-leak checks use their own two-person room. New four-intent
    // tests inspect their actual counterpart separately, avoiding shared-interest false positives.
    static let all = [maya, jules]
}

/// The actual guest: the Guest List name and the typed intent and approach.
private struct WaveViewer: Sendable {
    var name: String
    var band: String
    var approach: String

    static let alex = WaveViewer(name: "Alex", band: "social", approach: "chatFirst")

    /// The one sample of the guest's own intent: Maya for Social, Jules for Business.
    var counterpart: WaveCounterpart {
        switch band {
        case "business": return .jules
        case "activity": return .sam
        case "dating": return .riley
        default: return .maya
        }
    }
    var other: WaveCounterpart {
        switch band {
        case "business": return .maya
        case "activity": return .riley
        case "dating": return .sam
        default: return .jules
        }
    }

    var intentTitle: String {
        ["social": "Social", "dating": "Dating", "business": "Business", "activity": "Activity"][band] ?? band
    }

    var approachTitle: String {
        ["chatFirst": "Chat first", "okayToSayHello": "Okay to say hello"][approach] ?? approach
    }

    /// The venue ticket's line (75:138): "[Name] · [Intent] · [Approach]", the guest's own values.
    var preference: String { "\(name) · \(intentTitle) · \(approachTitle)" }
}

/// One Wave fixture launch (`DebugFixtures.WaveFixture`): the screen reached from the menu through the
/// Wave's own controls, with any Room blocks first, then the overlay and its reason.
private struct WaveFixture {
    var key: String
    var screen: WaveScreenKey
    var overlay: WaveOverlayKind? = nil
    var viewer = WaveViewer.alex
    var roomBlocked: String? = nil
    /// `-ProximeetWaveAfterBlock` (with the `wave-blocked` fixture): "menu" presses Back to demo menu and
    /// stops on the menu whose choices are disabled; `screen` is then the menu.
    var afterBlock: String? = nil

    /// The menu once its counterpart is blocked.
    var menuBlocked: Bool { afterBlock == "menu" }

    var arguments: [String] {
        let launched = afterBlock == nil ? screen : .blocked
        var arguments = ["-ProximeetFixture", launched.fixture, "-ProximeetFixtureBand", viewer.band,
                         "-ProximeetFixtureSignal", viewer.approach]
        if viewer.name != "Alex" {
            arguments += ["-ProximeetFixtureName", viewer.name]
        }
        if let roomBlocked {
            arguments += ["-ProximeetRoomBlocked", roomBlocked]
        }
        if let afterBlock {
            arguments += ["-ProximeetWaveAfterBlock", afterBlock]
        }
        if let overlay {
            arguments += ["-ProximeetWavePanel", overlay.fixture]
            if case .report(let reason?) = overlay {
                arguments += ["-ProximeetWaveReason", reason]
            }
        }
        return arguments
    }
}

/// One item of a largest-text check: a text (with its Figma box height, which it must outgrow), a button,
/// or a disabled button with its label (measured, never tapped).
private enum WaveLargestItem {
    case text(String, CGFloat)
    case button(String)
    case disabledButton(String, String)
}

/// One largest-text state and its items from the top down, and the overlay they sit in, if any.
private struct WaveLargestCheck {
    var name: String
    var fixture: WaveFixture
    var panel: String? = nil
    var items: [WaveLargestItem]
}

/// One element of a tree snapshot, with the overlay container it sits in.
private struct WaveNode {
    let identifier: String
    let label: String
    let value: String
    let type: XCUIElement.ElementType
    let frame: CGRect
    let panel: String?
    let isEnabled: Bool
    let isSelected: Bool
    let depth: Int
    let title: String
    let placeholderValue: String

    /// XCTest's matching(identifier:) accepts any of these identifying properties.
    func matchesIdentifier(_ query: String) -> Bool {
        [identifier, title, label, value, placeholderValue].contains(query)
    }
}

@MainActor
private struct WaveTreeEntry {
    let node: any XCUIElementSnapshot
    let panel: String?
    let depth: Int
}

/// One reading for `reveal`.
private struct WaveRevealLook {
    var found = false
    var target = CGRect.zero
    var screen = CGRect.zero
    var scroller: CGRect?
    var panel: String?
    var barTop: CGFloat?
    var barSource = "none"
    var controls: [CGRect] = []
}

private struct WaveRevealPlaced {
    let frame: CGRect
    let scroller: CGRect?
    let panel: String?
    let identifier: String
    let control: Bool
}

@MainActor
private struct WaveRevealEntry {
    let node: any XCUIElementSnapshot
    let scroller: CGRect?
    let panel: String?
}

/// Probes relative to the measured invitation-frame origin, not the invisible layout-canvas origin.
/// Native retained before/accepted frames on 29 October measured separate=0.8/0, sweep=0/0 and
/// joined=0/1 with these rectangles (max RGB >= 48). The earlier x105 joined rectangle read only
/// 0.228 in the test because it crossed the shadow. Its failed result remains retained. These probes
/// keep the original independent anchor, no-sweep and final-pose thresholds.
private enum RingProbe {
    static let separateOnly = CGRect(x: 54, y: 108, width: 5, height: 6)
    static let joinedOnly = CGRect(x: 113, y: 108, width: 6, height: 6)
    static let sweep = CGRect(x: 81, y: 107, width: 8, height: 8)
}

private struct AcceptFrame {
    /// Seconds after the Accept tap returned.
    let after: TimeInterval
    let sweep: Double
}

private struct AcceptPixels {
    var separateBefore: Double
    var sweepBefore: Double
    var frames: [AcceptFrame] = []
    var joinedAfter: Double = 0
    var separateAfter: Double = 1
    var sweepAfter: Double = 1
}

private struct AcceptSample {
    let name: String
    var pixels: AcceptPixels? = nil

    var summary: String {
        guard let pixels else { return "\(name): no pixel reading (not the 440 × 956 iPhone, or no anchor)" }
        let frames = pixels.frames.map { String(format: "%.0f ms %.3f", $0.after * 1000, $0.sweep) }.joined(separator: ", ")
        return String(format: "%@: before, separate rim %.3f, sweep %.3f; after Accept, sweep [%@]; settled, joined rim %.3f, "
                      + "separate rim %.3f, sweep %.3f", name, pixels.separateBefore, pixels.sweepBefore, frames,
                      pixels.joinedAfter, pixels.separateAfter, pixels.sweepAfter)
    }
}

// MARK: - Screens

/// Static assertion readings are scoped to one settled state. A nil tree keeps the original live
/// query path; Leave opts into a fresh tree inside assertScreen/assertOverlay, never across a tap.
@MainActor
private protocol WaveElementReading {
    var identifier: String { get }
    var exists: Bool { get }
    var label: String { get }
    var frame: CGRect { get }
    var isSelected: Bool { get }
    func waveProperties() throws -> WaveElementProperties
}

private struct WaveElementProperties {
    let label: String
    let isEnabled: Bool
    let frame: CGRect
}

extension XCUIElement: WaveElementReading {
    fileprivate func waveProperties() throws -> WaveElementProperties {
        let snapshot = try self.snapshot()
        return WaveElementProperties(label: snapshot.label, isEnabled: snapshot.isEnabled, frame: snapshot.frame)
    }
}

private enum WaveSnapshotLookupError: Error {
    case missingElement(identifier: String, panel: String?)
}

@MainActor
private struct WaveAssertionElement: WaveElementReading {
    let ui: WaveUI
    let queryIdentifier: String
    let panel: String?
    let nodes: [WaveNode]?

    private var live: XCUIElement {
        if let panel { return ui.inPanel(panel, queryIdentifier) }
        return ui.element(queryIdentifier)
    }

    private var node: WaveNode? {
        guard let nodes else { return nil }
        guard let panel else { return nodes.dropFirst().first { $0.matchesIdentifier(queryIdentifier) } }
        // Match the live query: descendants of the first matching container, including nested panels.
        // A later container with the same identifier cannot supply a missing child of the first one.
        guard let container = nodes.dropFirst().firstIndex(where: { $0.matchesIdentifier(panel) }) else { return nil }
        let depth = nodes[container].depth
        return nodes.dropFirst(container + 1).prefix { $0.depth > depth }
            .first { $0.matchesIdentifier(queryIdentifier) }
    }

    var identifier: String { nodes == nil ? live.identifier : node?.identifier ?? "" }
    var exists: Bool { nodes == nil ? live.exists : node != nil }
    var label: String { nodes == nil ? live.label : node?.label ?? "" }
    var frame: CGRect { nodes == nil ? live.frame : node?.frame ?? .zero }
    var isSelected: Bool { nodes == nil ? live.isSelected : node?.isSelected ?? false }

    func waveProperties() throws -> WaveElementProperties {
        guard nodes != nil else { return try live.waveProperties() }
        guard let node else {
            throw WaveSnapshotLookupError.missingElement(identifier: queryIdentifier, panel: panel)
        }
        return WaveElementProperties(label: node.label, isEnabled: node.isEnabled, frame: node.frame)
    }
}

@MainActor
private struct WaveAssertionUI {
    let live: WaveUI
    let nodes: [WaveNode]?
    var app: XCUIApplication { live.app }

    func element(_ identifier: String) -> WaveAssertionElement {
        WaveAssertionElement(ui: live, queryIdentifier: identifier, panel: nil, nodes: nodes)
    }

    func inPanel(_ panel: String, _ identifier: String) -> WaveAssertionElement {
        WaveAssertionElement(ui: live, queryIdentifier: identifier, panel: panel, nodes: nodes)
    }

    var brand: WaveAssertionElement { element("wave.brand") }
    var back: WaveAssertionElement { element("wave.back") }
    var demoBadge: WaveAssertionElement { element("wave.demoBadge") }
    var safety: WaveAssertionElement { element("wave.safety") }
    var venue: WaveAssertionElement { element("wave.venue") }
    var venuePreference: WaveAssertionElement { element("wave.venue.preference") }
    var menuHeadline: WaveAssertionElement { element("wave.menu.headline") }
    var menuRole: WaveAssertionElement { element("wave.menu.role") }
    var menuBoundary: WaveAssertionElement { element("wave.menu.boundary") }
    var menuBlocked: WaveAssertionElement { element("wave.menu.blocked") }
    var startOutgoing: WaveAssertionElement { element("wave.menu.startOutgoing") }
    var startIncoming: WaveAssertionElement { element("wave.menu.startIncoming") }
    var noAllowance: WaveAssertionElement { element("wave.menu.noAllowance") }
    var invitation: WaveAssertionElement { element("wave.invitation") }
    var context: WaveAssertionElement { element("wave.invitation.context") }
    var direction: WaveAssertionElement { element("wave.invitation.direction") }
    var title: WaveAssertionElement { element("wave.invitation.title") }
    var purpose: WaveAssertionElement { element("wave.invitation.purpose") }
    var preference: WaveAssertionElement { element("wave.invitation.preference") }
    var boundary: WaveAssertionElement { element("wave.boundary") }
    var demoCases: WaveAssertionElement { element("wave.demoCases") }
    var send: WaveAssertionElement { element("wave.send") }
    var withdraw: WaveAssertionElement { element("wave.withdraw") }
    var accept: WaveAssertionElement { element("wave.accept") }
    var decline: WaveAssertionElement { element("wave.decline") }
    var aboutChat: WaveAssertionElement { element("wave.aboutChat") }
    var closedLabel: WaveAssertionElement { element("wave.closed.label") }
    var closedHeadline: WaveAssertionElement { element("wave.closed.headline") }
    var closedExplanation: WaveAssertionElement { element("wave.closed.explanation") }
    var closedChoice: WaveAssertionElement { element("wave.closed.choice") }
    var closedBoundary: WaveAssertionElement { element("wave.closed.boundary") }
    var backToMenu: WaveAssertionElement { element("wave.backToMenu") }
    var returnToPlaces: WaveAssertionElement { element("wave.returnToPlaces") }
    var leave: WaveAssertionElement { element("wave.leave") }
}

/// The Wave's elements, by identifier (`wave.*`, `wavePanel.*`, `wave.report.reason.*`).
@MainActor
private struct WaveUI {
    let app: XCUIApplication

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// An element inside one overlay, found by a query scoped to that overlay's container.
    func inPanel(_ panel: String, _ identifier: String) -> XCUIElement {
        element(panel).descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func screen(_ screen: WaveScreenKey) -> XCUIElement { element("wave.screen.\(screen.rawValue)") }

    var brand: XCUIElement { element("wave.brand") }
    var back: XCUIElement { element("wave.back") }
    var demoBadge: XCUIElement { element("wave.demoBadge") }
    var safety: XCUIElement { element("wave.safety") }
    var venue: XCUIElement { element("wave.venue") }
    var venuePreference: XCUIElement { element("wave.venue.preference") }

    var menuHeadline: XCUIElement { element("wave.menu.headline") }
    var menuRole: XCUIElement { element("wave.menu.role") }
    var menuBoundary: XCUIElement { element("wave.menu.boundary") }
    var menuBlocked: XCUIElement { element("wave.menu.blocked") }
    var startOutgoing: XCUIElement { element("wave.menu.startOutgoing") }
    var startIncoming: XCUIElement { element("wave.menu.startIncoming") }
    var noAllowance: XCUIElement { element("wave.menu.noAllowance") }

    var invitation: XCUIElement { element("wave.invitation") }
    var context: XCUIElement { element("wave.invitation.context") }
    var direction: XCUIElement { element("wave.invitation.direction") }
    var title: XCUIElement { element("wave.invitation.title") }
    var purpose: XCUIElement { element("wave.invitation.purpose") }
    var preference: XCUIElement { element("wave.invitation.preference") }
    var boundary: XCUIElement { element("wave.boundary") }
    var demoCases: XCUIElement { element("wave.demoCases") }
    var send: XCUIElement { element("wave.send") }
    var withdraw: XCUIElement { element("wave.withdraw") }
    var accept: XCUIElement { element("wave.accept") }
    var decline: XCUIElement { element("wave.decline") }
    var aboutChat: XCUIElement { element("wave.aboutChat") }

    var closedLabel: XCUIElement { element("wave.closed.label") }
    var closedHeadline: XCUIElement { element("wave.closed.headline") }
    var closedExplanation: XCUIElement { element("wave.closed.explanation") }
    var closedChoice: XCUIElement { element("wave.closed.choice") }
    var closedBoundary: XCUIElement { element("wave.closed.boundary") }
    var backToMenu: XCUIElement { element("wave.backToMenu") }
    var returnToPlaces: XCUIElement { element("wave.returnToPlaces") }
    var leave: XCUIElement { element("wave.leave") }

    func reason(_ key: String) -> XCUIElement { element("wave.report.reason.\(key)") }
}

/// The Room's elements the Wave tests need (`room.*`, `roomEntry.*`, `roomWaiting.*`, `roomProfile.*`,
/// `roomPanel.*`).
@MainActor
private struct WaveRoomUI {
    let app: XCUIApplication

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func inPanel(_ panel: String, _ identifier: String) -> XCUIElement {
        element(panel).descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var entryHeadline: XCUIElement { element("roomEntry.headline") }
    var enter: XCUIElement { element("roomEntry.enter") }
    var waitingHeadline: XCUIElement { element("roomWaiting.headline") }
    var showPopulated: XCUIElement { element("roomWaiting.showPopulated") }

    func tab(_ key: String) -> XCUIElement { element("room.tab.\(key)") }
    var peopleFraming: XCUIElement { element("room.peopleFraming") }
    var notesFraming: XCUIElement { element("room.notesFraming") }
    func card(_ actor: String) -> XCUIElement { element("room.card.\(actor)") }
    var boundary: XCUIElement { element("room.boundary") }
    var empty: XCUIElement { element("room.empty") }
    var hostNote: XCUIElement { element("room.note.host") }
    var icebreaker: XCUIElement { element("room.note.icebreaker") }
    var julesNote: XCUIElement { element("room.note.public.jules") }
    var hiddenNotesBoundary: XCUIElement { element("room.notes.hiddenBoundary") }

    var profileName: XCUIElement { element("roomProfile.name") }
    var profileSafety: XCUIElement { element("roomProfile.safety") }
    var profileAction: XCUIElement { element("roomProfile.action") }
}

/// Places' elements the Wave tests need: browsing (`places.*`), a detail (`place.*`) and the explanation
/// (`explanation.*`).
@MainActor
private struct WavePlaces {
    let app: XCUIApplication

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var headline: XCUIElement { element("places.headline") }
    var secondary: XCUIElement { app.buttons["places.secondary"] }
    func tab(_ category: String) -> XCUIElement { app.buttons["places.tab.\(category)"] }
    var ticketName: XCUIElement { element("places.ticket.name") }
    var viewPlace: XCUIElement { app.buttons["places.viewPlace"] }
    var placeName: XCUIElement { element("place.name") }
    var placePrimary: XCUIElement { app.buttons["place.primary"] }
    var explanationHeadline: XCUIElement { element("explanation.headline") }
    var explanationPrimary: XCUIElement { app.buttons["explanation.primary"] }
}

@MainActor
private struct WaveSignal {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.headline").firstMatch }
    var summary: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.summary").firstMatch }
    var primary: XCUIElement { app.buttons["signal.primary"] }

    func row(_ approach: String) -> XCUIElement { app.buttons["signal.approach.\(approach)"] }
}

@MainActor
private struct WaveWristband {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch }
    var primary: XCUIElement { app.buttons["wristband.primary"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

@MainActor
private struct WaveGuestList {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.headline").firstMatch }
    var name: XCUIElement { app.textFields["guestList.name"] }
    var opener: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.opener").firstMatch }
    var coffee: XCUIElement { app.buttons["guestList.interest.coffee"] }
    var primary: XCUIElement { app.buttons["guestList.primary"] }
}

@MainActor
private struct WavePass {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
}

/// One screenshot's pixels, addressed in points (`RoomReviewTests.RenderedScreen`, from any screenshot:
/// here the device screen's, which needs no element lookup, so frames can follow a tap closely).
@MainActor
private struct WaveRenderedScreen {
    private let pixels: [UInt8]
    private let width: Int
    private let height: Int
    private let scale: CGFloat

    init?(_ screenshot: XCUIScreenshot, pointWidth: CGFloat) {
        guard let image = screenshot.image.cgImage, pointWidth > 0 else {
            XCTFail("No screenshot to check what is drawn.")
            return nil
        }
        width = image.width
        height = image.height
        scale = CGFloat(image.width) / pointWidth
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
