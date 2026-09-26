import UIKit
import XCTest

/// Runtime review of the approved Signal (chapter 06), with the integration checks of its
/// assignment. The real route: Welcome → More options → "Continue the demo (no account)" →
/// Birthday → Continue → Pass → Try the demo → Finish preview → Continue preview → Guest List
/// (typed) → Preview my card → Continue preview → Wristband (a chosen intent) → Continue preview →
/// Signal.
///
/// Skipped unless the test runner's environment has `PROXIMEET_SIGNAL_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_SIGNAL_REVIEW=1` to xcodebuild). Real taps and typing. Tests that start
/// from a DEBUG fixture (`-ProximeetFixture signal…`, a direct launch) say so in their names'
/// comments and their captures say "fixture"; the fixtures reach Signal through the same Birthday
/// gate, completed Pass, Guest List card and Wristband. Every name and opener is fictional.
@MainActor
final class SignalReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_SIGNAL_REVIEW"
    private static let privacy = "You stay private until venue check-in."
    private static let intents = ["social", "dating", "business", "activity"]
    private static let titles = ["social": "Social", "dating": "Dating", "business": "Business", "activity": "Activity"]
    private static let approaches = ["chatFirst", "okayToSayHello"]
    private static let approachTitles = ["chatFirst": "Chat first", "okayToSayHello": "Okay to say hello"]
    private static let approachSummaries = ["chatFirst": "Start with a Wave. Chat after you both agree.",
                                            "okayToSayHello": "Open to a brief hello. No pressure to continue."]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Signal review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("SIGNAL_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough (full journey)

    /// Full journey, recorded: the real route with a typed introduction and Social; the empty
    /// Signal; Chat first (the first choice: the tag moves to the band); Okay to say hello (the
    /// icon dissolves); the active row again (nothing changes); Back to the Wristband, Dating,
    /// Continue preview (Dating's band, Okay to say hello kept, attached at once); Back to the
    /// card, Edit introduction, a change to the opener, the card, the Wristband (Dating kept),
    /// Signal (both kept); and "End of this preview." with OK, staying on the choice.
    func testWalkthroughRealJourney() throws {
        print("SIGNAL_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        let app = launchWelcome()
        hold(1.0)
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Alex")
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText("Up for coffee.")
        tapKeyboardDone(app)
        guest.coffee.tap()
        hold(0.6)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(0.6)
        guest.primary.tap()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("social").tap()
        XCTAssertTrue(waitFor(band.tile("social"), selected: true))
        hold(0.8)
        band.primary.tap()

        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(1.0)
        capture("signal-journey-social-none", app)
        assertState(signal, intent: "social", approach: nil)
        softlyMeasured(app, "Journey Social, none", intent: "social", approach: nil)

        signal.row("chatFirst").tap()
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true), "Chat first is selected at once.")
        hold(1.2)
        capture("signal-journey-social-chat", app)
        assertState(signal, intent: "social", approach: "chatFirst")
        softlyMeasured(app, "Journey Social, Chat first", intent: "social", approach: "chatFirst")

        signal.row("okayToSayHello").tap()
        XCTAssertTrue(waitFor(signal.row("okayToSayHello"), selected: true))
        hold(1.0)
        capture("signal-journey-social-hello", app)
        assertState(signal, intent: "social", approach: "okayToSayHello")

        // The active row again: nothing changes and nothing replays.
        signal.row("okayToSayHello").tap()
        hold(0.6)
        assertState(signal, intent: "social", approach: "okayToSayHello")

        // Back to the actual Wristband, a different intent, and forward: the approach is kept.
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertTrue(band.tile("social").isSelected, "Back returns to the actual Wristband, Social still chosen.")
        hold(0.8)
        band.tile("dating").tap()
        XCTAssertTrue(waitFor(band.tile("dating"), selected: true))
        hold(0.6)
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        softly {
            // Attached at once on re-entry: the first-choice movement does not replay.
            guard let shot = RenderedScreen(app) else { return }
            XCTAssertEqual(Self.pose(shot), "attached", "Re-entry shows the attached tag at once.")
        }
        hold(1.0)
        capture("signal-journey-dating-hello-kept", app)
        assertState(signal, intent: "dating", approach: "okayToSayHello")
        softlyMeasured(app, "Journey Dating, Okay to say hello", intent: "dating", approach: "okayToSayHello")

        // Earlier, the Guest List: both values survive an edit of the introduction.
        signal.secondary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.back.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, "Alex. Up for coffee. Interests: Coffee")
        guest.secondary.tap()
        waitForLabel(guest.headline, "A little about you.")
        guest.opener.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap()
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText(" Or tea.")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, "Alex. Up for coffee. Or tea. Interests: Coffee", "The edit shows on the card.")
        hold(0.8)
        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertTrue(band.tile("dating").isSelected, "The intent is kept through the edit.")
        hold(0.6)
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(0.8)
        assertState(signal, intent: "dating", approach: "okayToSayHello")
        capture("signal-journey-after-edit-kept", app)

        signal.primary.tap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "Continue preview shows the end-of-preview message.")
        hold(0.8)
        capture("signal-journey-endpoint", app)
        end.buttons["OK"].tap()
        waitForAbsence(end)
        assertState(signal, intent: "dating", approach: "okayToSayHello")
        hold(1.0)
    }

    // MARK: - All twelve states

    /// Direct launch (the DEBUG fixture `signal`, once per intent): each intent unselected, then
    /// Chat first, then Okay to say hello, each checked on the rendered screen: the carried band,
    /// the resting or attached tag, the icon on the tag, the rows, the summary and Continue.
    func testAllTwelveStates() throws {
        for intent in Self.intents {
            let app = launch(fixture: "signal", band: intent)
            let signal = SignalScreen(app: app)
            waitForLabel(signal.headline, "A hello, on your terms.")
            hold(0.8)
            assertState(signal, intent: intent, approach: nil)
            capture("signal-\(intent)-none-fixture", app)
            softlyMeasured(app, "\(Self.titles[intent] ?? intent), none", intent: intent, approach: nil)
            for approach in Self.approaches {
                signal.row(approach).tap()
                XCTAssertTrue(waitFor(signal.row(approach), selected: true))
                hold(0.9)
                assertState(signal, intent: intent, approach: approach)
                capture("signal-\(intent)-\(approach == "chatFirst" ? "chat" : "hello")-fixture", app)
                softlyMeasured(app, "\(Self.titles[intent] ?? intent), \(Self.approachTitles[approach] ?? approach)",
                               intent: intent, approach: approach)
            }
            app.terminate()
        }
    }

    // MARK: - Changes, no-ops, re-entry and interruption

    /// Direct launch (fixture `signal`, Business): both first choices (each from a fresh screen),
    /// both directions of change, the active row as a no-op, and re-entry without replaying the
    /// first-choice movement.
    func testFirstChoicesChangesNoOpsAndReentry() throws {
        for first in Self.approaches {
            let app = launch(fixture: "signal", band: "business")
            let signal = SignalScreen(app: app)
            waitForLabel(signal.headline, "A hello, on your terms.")
            hold(0.5)
            softly {
                guard let shot = RenderedScreen(app) else { return }
                XCTAssertEqual(Self.pose(shot), "resting", "No approach: the tag rests beside the band.")
            }
            signal.row(first).tap()
            XCTAssertTrue(waitFor(signal.row(first), selected: true))
            hold(0.9)
            assertState(signal, intent: "business", approach: first)
            let other = first == "chatFirst" ? "okayToSayHello" : "chatFirst"
            signal.row(other).tap()
            XCTAssertTrue(waitFor(signal.row(other), selected: true), "\(first) → \(other)")
            hold(0.6)
            assertState(signal, intent: "business", approach: other)
            let before = RenderedScreen(app).map(Self.poseMeasure)
            signal.row(other).tap()
            hold(0.3)
            assertState(signal, intent: "business", approach: other)
            let after = RenderedScreen(app).map(Self.poseMeasure)
            softly {
                XCTAssertEqual(before?.right ?? -1, after?.right ?? -2, accuracy: 300, "The active row moves nothing.")
                XCTAssertEqual(before?.bottom ?? -1, after?.bottom ?? -2, accuracy: 0.34, "The active row moves nothing.")
            }
            // Re-entry: Back, then forward: attached at once, the approach kept.
            signal.back.tap()
            let band = Wristband(app: app)
            waitForLabel(band.headline, "Choose your kind of hello.")
            band.primary.tap()
            waitForLabel(signal.headline, "A hello, on your terms.")
            softly {
                guard let shot = RenderedScreen(app) else { return }
                XCTAssertEqual(Self.pose(shot), "attached", "Re-entry does not replay the first-choice movement.")
            }
            assertState(signal, intent: "business", approach: other)
            if first == "chatFirst" {
                hold(0.5)
                capture("signal-reentry-attached-fixture", app)
            }
            app.terminate()
        }
    }

    /// Direct launch (fixture `signal`, Activity, then Dating and Social): rapid changes leave the
    /// last choice; Continue preview during a change, Back during the first movement, and the app
    /// sent to the background during the first movement and resumed, each leave the model and the
    /// drawn state consistent: the attached tag with the chosen icon, the summary and Continue.
    func testRapidChangesAndInterruptionsStayConsistent() throws {
        let app = launch(fixture: "signal", band: "activity")
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        for approach in ["chatFirst", "okayToSayHello", "chatFirst", "okayToSayHello"] {
            signal.row(approach).tap()
        }
        XCTAssertTrue(waitFor(signal.row("okayToSayHello"), selected: true))
        hold(0.9)
        assertState(signal, intent: "activity", approach: "okayToSayHello")
        softly {
            guard let shot = RenderedScreen(app) else { return }
            XCTAssertEqual(Self.pose(shot), "attached")
            XCTAssertEqual(Self.glyph(shot), "okayToSayHello", "The icon matches the last choice.")
        }
        capture("signal-after-rapid-changes-fixture", app)

        // Continue preview during a change: one message, the choice unchanged.
        signal.row("chatFirst").tap()
        signal.primary.tap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 1)
        end.buttons["OK"].tap()
        waitForAbsence(end)
        hold(0.6)
        assertState(signal, intent: "activity", approach: "chatFirst")
        softly {
            guard let shot = RenderedScreen(app) else { return }
            XCTAssertEqual(Self.pose(shot), "attached")
            XCTAssertEqual(Self.glyph(shot), "chatFirst")
        }
        app.terminate()

        // Back during the first movement: the Wristband, then forward: attached, Chat first.
        let fresh = launch(fixture: "signal", band: "dating")
        let again = SignalScreen(app: fresh)
        waitForLabel(again.headline, "A hello, on your terms.")
        again.row("chatFirst").tap()
        again.back.tap()
        let band = Wristband(app: fresh)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.6)
        band.primary.tap()
        waitForLabel(again.headline, "A hello, on your terms.")
        hold(0.4)
        assertState(again, intent: "dating", approach: "chatFirst")
        softly {
            guard let shot = RenderedScreen(fresh) else { return }
            XCTAssertEqual(Self.pose(shot), "attached")
            XCTAssertEqual(Self.glyph(shot), "chatFirst")
        }
        capture("signal-after-back-during-movement-fixture", fresh)
        fresh.terminate()

        // The app sent to the background during the first movement, then resumed: attached,
        // Okay to say hello, nothing lost or replayed.
        let resumed = launch(fixture: "signal", band: "social")
        let third = SignalScreen(app: resumed)
        waitForLabel(third.headline, "A hello, on your terms.")
        third.row("okayToSayHello").tap()
        XCUIDevice.shared.press(.home)
        hold(2.0)
        resumed.activate()
        XCTAssertTrue(third.headline.waitForExistence(timeout: 10), "Signal is showing again after resume.")
        hold(0.6)
        assertState(third, intent: "social", approach: "okayToSayHello")
        softly {
            guard let shot = RenderedScreen(resumed) else { return }
            XCTAssertEqual(Self.pose(shot), "attached", "After resume the tag is attached.")
            XCTAssertEqual(Self.glyph(shot), "okayToSayHello", "After resume the icon matches the choice.")
        }
        capture("signal-after-background-resume-fixture", resumed)
    }

    // MARK: - Endpoint and duplicate taps

    /// Direct launch (fixture `signal-selected`, Business, Chat first): a double tap on Continue
    /// preview shows one message and stays; a double tap on either Back stops at the Wristband;
    /// re-entry keeps both values; nothing claims a Wave, chat, match, verification or visibility.
    func testEndpointDuplicateTapsAndBack() throws {
        let app = launch(fixture: "signal-selected", band: "business", approach: "chatFirst")
        let signal = SignalScreen(app: app)
        let band = Wristband(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        assertState(signal, intent: "business", approach: "chatFirst")
        assertNothingConferred(app)

        signal.primary.doubleTap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        hold(0.8)
        XCTAssertEqual(app.alerts.count, 1, "A double tap shows one message.")
        capture("signal-endpoint-fixture", app)
        end.buttons["OK"].tap()
        waitForAbsence(end)
        assertState(signal, intent: "business", approach: "chatFirst")

        signal.back.doubleTap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(1.0)
        XCTAssertEqual(band.headline.label, "Choose your kind of hello.", "A double tap on Back stops at the Wristband.")
        XCTAssertTrue(band.tile("business").isSelected)
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        assertState(signal, intent: "business", approach: "chatFirst")
        signal.secondary.doubleTap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(1.0)
        XCTAssertEqual(band.headline.label, "Choose your kind of hello.", "A double tap on the bottom Back stops at the Wristband.")
        assertNothingConferred(app)
    }

    /// Direct launch (fixture `wristband`, no intent): Continue preview is disabled and Signal
    /// never opens without an intent.
    func testMissingIntentKeepsSignalClosed() throws {
        let app = launch(fixture: "wristband")
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertFalse(band.primary.isEnabled, "No intent, no Continue preview.")
        band.primary.tap()
        hold(0.8)
        XCTAssertFalse(app.descendants(matching: .any)["signal.headline"].exists, "Signal did not open.")
        XCTAssertEqual(band.headline.label, "Choose your kind of hello.")
    }

    // MARK: - Memory only

    /// Direct launch (fixture `signal-selected`, Dating, Okay to say hello), then a relaunch
    /// without one and the real route: the new run's Signal has no approach.
    func testRelaunchStartsWithoutAnApproach() throws {
        var app = launch(fixture: "signal-selected", band: "dating", approach: "okayToSayHello")
        var signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        assertState(signal, intent: "dating", approach: "okayToSayHello")

        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10), "A fresh launch starts at Welcome.")
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Sam")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.primary.tap()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertFalse(band.tile("dating").isSelected, "No intent after a relaunch.")
        band.tile("business").tap()
        band.primary.tap()
        signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(0.6)
        assertState(signal, intent: "business", approach: nil)
        capture("signal-after-relaunch-none", app)
    }

    // MARK: - Reduce Motion and largest text

    /// Direct launch (fixture `signal`, Activity) with the app-level preview flag
    /// `-ProximeetReduceMotionPreview YES` (not the system setting): the first choice shows the
    /// attached tag at once.
    func testReduceMotionPreviewAttachesAtOnce() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "signal", "-ProximeetFixtureBand", "activity",
                               "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(0.6)
        signal.row("chatFirst").tap()
        let early = RenderedScreen(app).map(Self.poseMeasure)
        hold(1.0)
        let settled = RenderedScreen(app).map(Self.poseMeasure)
        capture("signal-reduce-motion-preview-activity-chat-fixture", app)
        attachNote("Reduce Motion preview: right-box steel \(String(describing: early?.right)) → \(String(describing: settled?.right)); "
                   + "centre-box bottom \(String(describing: early?.bottom)) → \(String(describing: settled?.bottom)).")
        softly {
            XCTAssertEqual(early.map(Self.poseName), "attached", "Reduce Motion: attached immediately after the tap.")
            XCTAssertEqual(settled.map(Self.poseName), "attached")
        }
    }

    /// Direct launch (fixture `signal-selected`, Social, Chat first) at the largest accessibility
    /// text size: DEMO is drawn whole, the headline wraps, the rows grow with their words, and
    /// both choices, the summary, the privacy line and both actions stay reachable. Run on the
    /// iPhone 17 Pro Max and on the smaller iPhone; the captures name the width.
    func testLargestTextKeepsEveryChoiceReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ProximeetFixture", "signal-selected", "-ProximeetFixtureBand", "social", "-ProximeetFixtureSignal", "chatFirst",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(1.2)
        XCTAssertGreaterThan(signal.headline.frame.height, 112 + 10, "The largest text size must be applied.")
        let width = Int(app.frame.width.rounded())
        attachNote("Largest text, \(width) pt wide: headline \(NSCoder.string(for: signal.headline.frame)).")
        capture("signal-largest-text-top-\(width)pt-fixture", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let clusters = shot.inkColumns(in: CGRect(x: app.frame.width - 240, y: 50, width: 240, height: 110), where: Self.cyan)
            let tallest = clusters.map { $0.height }.max() ?? 0
            XCTAssertGreaterThanOrEqual(clusters.count, 4, "DEMO should be drawn as its letters.")
            XCTAssertFalse(clusters.contains { $0.height < tallest * 0.5 }, "DEMO is truncated: an ellipsis is drawn.")
            XCTAssertGreaterThan(signal.headline.frame.height, 300, "The headline wraps rather than shrinks.")
        }
        XCTAssertTrue(signal.back.isHittable)
        for element in [signal.summary, signal.privacy, signal.row("chatFirst"), signal.row("okayToSayHello")] {
            XCTAssertTrue(scrollIntoView(element, signal, app), "\(element.identifier) is reachable by scrolling.")
            if element.elementType == .button {
                XCTAssertGreaterThan(element.frame.height, 84, "\(element.identifier) grows with its words.")
                XCTAssertGreaterThanOrEqual(element.frame.minX, 31)
                XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.width - 31)
            }
        }
        XCTAssertTrue(signal.primary.isHittable && signal.secondary.isHittable, "Both actions stay on screen.")
        capture("signal-largest-text-choices-\(width)pt-fixture", app)
        signal.row("okayToSayHello").tap()
        XCTAssertTrue(waitFor(signal.row("okayToSayHello"), selected: true))
        XCTAssertEqual(signal.summary.label, "Social band · Okay to say hello")
        XCTAssertTrue(scrollIntoView(signal.row("okayToSayHello"), signal, app))
        capture("signal-largest-text-bottom-\(width)pt-fixture", app)
    }

    // MARK: - Integration: the Birthday gate on the way back (full journey)

    /// Full journey: adult birthday → Pass → Guest List → Wristband (Activity) → Signal (Chat
    /// first), then Back through each chapter to Birthday; an under-18 date blocks Continue and
    /// every forward route while the drafts stay in memory; the corrected date needs an explicit
    /// Continue and opens the Pass at its intro (not Signal); the Pass must be completed again;
    /// the introduction, the intent and the approach are then all still there.
    func testAgeGateReturnJourneyBlocksForwardRoutesAndKeepsTheDrafts() throws {
        let app = launchWelcome()
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Alex")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.primary.tap()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("activity").tap()
        band.primary.tap()
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.row("chatFirst").tap()
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true))
        hold(0.6)

        // Back through each chapter to Birthday.
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.back.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.back.tap()
        waitForLabel(guest.headline, "A little about you.")
        guest.secondary.tap()
        waitForLabel(pass.headline, "Demo complete.")
        pass.back.tap()
        let birthdayHeadline = app.descendants(matching: .any)["birthday.headline"]
        XCTAssertTrue(birthdayHeadline.waitForExistence(timeout: 5), "Back through every chapter reaches Birthday.")

        // An under-18 date: Continue is disabled and nothing moves forward.
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "2012")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: false), "An under-18 date disables Continue.")
        hold(0.8)
        capture("age-gate-return-under18-journey", app)
        proceed.tap()
        hold(0.8)
        XCTAssertTrue(birthdayHeadline.exists, "Still on Birthday.")
        XCTAssertFalse(pass.headline.exists, "No Pass opened.")
        XCTAssertFalse(signal.headline.exists, "No later chapter opened.")

        // Corrected: an explicit Continue, and the Pass from its intro.
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        XCTAssertTrue(waitFor(proceed, enabled: true))
        hold(0.6)
        XCTAssertTrue(birthdayHeadline.exists, "A corrected date moves nothing by itself.")
        proceed.tap()
        waitForLabel(pass.headline, "Your next chapter.")
        XCTAssertFalse(signal.headline.exists, "The Pass intro, not Signal.")
        capture("age-gate-return-pass-intro-journey", app)
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo complete.")
        pass.primary.tap()
        waitForLabel(guest.headline, "A little about you.")
        XCTAssertEqual(guest.name.value as? String, "Alex", "The introduction was kept in memory.")
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertTrue(band.tile("activity").isSelected, "The intent was kept.")
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        assertState(signal, intent: "activity", approach: "chatFirst")
        hold(0.6)
        capture("age-gate-return-signal-kept-journey", app)
    }

    // MARK: - Route helpers

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10))
        return app
    }

    private func launch(fixture: String, band: String? = nil, approach: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ProximeetFixture", fixture]
        if let band { arguments += ["-ProximeetFixtureBand", band] }
        if let approach { arguments += ["-ProximeetFixtureSignal", approach] }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Welcome → Birthday with 12 May 1997 → Continue → Pass → Try the demo → Finish preview.
    private func openCompletedPass(_ app: XCUIApplication) -> PassScreen {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 5), "More options should offer the demo.")
        demo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["birthday.headline"].waitForExistence(timeout: 5), "Birthday should open.")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "12")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "May")
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: true), "12 May 1997 should enable Continue.")
        proceed.tap()
        let pass = PassScreen(app: app)
        waitForLabel(pass.headline, "Your next chapter.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo complete.")
        return pass
    }

    // MARK: - Assertions

    /// The approach (or none) is shown consistently: exactly its row selected, the summary, and
    /// Continue preview; the fixed copy, DEMO, the privacy line and target sizes on every state.
    private func assertState(_ signal: SignalScreen, intent: String, approach: String?) {
        XCTAssertEqual(signal.headline.label, "A hello, on your terms.")
        XCTAssertEqual(signal.support.label, "Let people know how to begin.")
        XCTAssertEqual(signal.demoBadge.label, "Demo")
        XCTAssertEqual(signal.privacy.label, Self.privacy)
        let title = Self.titles[intent] ?? intent
        XCTAssertEqual(signal.summary.label, "\(title) band · \(approach.flatMap { Self.approachTitles[$0] } ?? "Choose your approach")")
        for option in Self.approaches {
            let row = signal.row(option)
            XCTAssertEqual(row.label, "\(Self.approachTitles[option] ?? option). \(Self.approachSummaries[option] ?? "")")
            XCTAssertEqual(row.isSelected, option == approach, "\(option) selected: \(row.isSelected)")
            XCTAssertTrue(row.isEnabled, "Both choices stay available.")
            XCTAssertGreaterThanOrEqual(row.frame.height, 84)
        }
        XCTAssertEqual(signal.primary.label, "Continue preview")
        XCTAssertEqual(signal.primary.isEnabled, approach != nil, "Continue preview needs an approach.")
        XCTAssertGreaterThanOrEqual(signal.primary.frame.height, 60)
        XCTAssertGreaterThanOrEqual(signal.secondary.frame.height, 44)
        XCTAssertGreaterThanOrEqual(signal.back.frame.height, 44)
        XCTAssertGreaterThanOrEqual(signal.back.frame.width, 44)
    }

    private func assertNothingConferred(_ app: XCUIApplication) {
        let words = ["verified", "access granted", "checked in", "you're visible", "you’re visible", "now visible",
                     "nearby", "matched", "match", "online now", "member", "discoverable", "wave sent", "wave accepted",
                     "chat open", "message sent", "location"]
        let predicate = NSPredicate(format: words.map { _ in "label CONTAINS[c] %@" }.joined(separator: " OR "), argumentArray: words)
        XCTAssertEqual(app.descendants(matching: .any).matching(predicate).count, 0,
                       "No verified, visible, matched, Wave, chat or member wording.")
        XCTAssertEqual(app.alerts.count, 0, "No permission or provider prompt appeared.")
    }

    // MARK: - Waiting and input

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 6), "\(element.identifier) should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 6), .completed, "Expected “\(label)”, found “\(element.label)”.")
    }

    private func waitFor(_ element: XCUIElement, enabled: Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitForFocus(_ field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter.wait(for: [focused], timeout: 5) == .completed
    }

    private func waitForAbsence(_ element: XCUIElement) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        _ = XCTWaiter.wait(for: [gone], timeout: 5)
    }

    private func tapKeyboardDone(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "guestList.keyboardDone", "Done")).firstMatch
        if done.waitForExistence(timeout: 5) {
            done.tap()
            waitForAbsence(app.keyboards.firstMatch)
        } else {
            XCTFail("Done is offered above the keyboard.")
        }
    }

    /// Short, momentum-free drags in the page margin until `element` lies between the status bar
    /// and the top of the action bar. The last row ends exactly at the bar's top when the page is
    /// scrolled to its end, so both edges allow 1 pt; each drag (about 115 pt on the reference
    /// phone) is shorter than a row's slack, so it cannot step over the window and back.
    private func scrollIntoView(_ element: XCUIElement, _ signal: SignalScreen, _ app: XCUIApplication) -> Bool {
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.30))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.42))
        for _ in 0..<28 {
            let frame = element.frame, top: CGFloat = 62, bottom = signal.primary.frame.minY - 13
            let low = frame.maxY > bottom + 1, high = frame.minY < top - 1
            if !low && !high {
                return true
            }
            if low {
                lower.press(forDuration: 0.05, thenDragTo: upper, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                upper.press(forDuration: 0.05, thenDragTo: lower, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
        }
        return false
    }

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
    // Accessibility values do not prove anything was drawn, so these read the screenshot, in points
    // at 440 × 956. The approved board (docs/design/signal-approved/reference/signal-review.png) is
    // at 1× with its frames at x 40 / 520 / 1000, y 172 (Social: none, Chat first, Okay to say
    // hello); every anchor below agrees with it to within its 1-pt pixels. Text anchors are the
    // glyphs' own extents on Figma's line boxes from the bundled Manrope outlines. The tag's poses,
    // the icons' ink and the bands' colours come from the original artworks and paths.

    private static let white: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 200 }
    private static let grey: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 120 }
    private static let black: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 50 }
    private static let cyan: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 120 && g > 150 && b > 160 }
    private static let notGround: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) > 45 }
    /// Low-saturation mid-to-light grey: the tag's (and the clasp's) steel.
    private static let steel: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in
        let high = max(r, g, b), low = min(r, g, b)
        let mean = (Int(r) + Int(g) + Int(b)) / 3
        return Int(high) - Int(low) < 18 && mean > 90 && mean < 245
    }
    private static let glyphInk: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 110 }
    /// #111415, an unselected row; #242A2B, a selected one.
    private static let tileFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 12 && r <= 24 && g >= 15 && g <= 28 && b >= 16 && b <= 30 }
    private static let selectedFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 30 && r <= 42 && g >= 38 && g <= 48 && b >= 38 && b <= 50 }
    private static let disabledFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 25 && r <= 40 && g >= 30 && g <= 45 && b >= 30 && b <= 45 }
    private static let disabledText: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 95 && r < 135 && g > 105 && g < 145 && b > 100 && b < 140 }

    /// The band's left third (hero x 8…128, which the tag never covers), mean colour over #050606,
    /// from the original artwork with the approved crop (the board's Social: 173.0, 75.9, 64.1).
    private static let bandMeans: [String: (Double, Double, Double)] = [
        "social": (174.1, 76.3, 64.4), "dating": (94.5, 46.2, 102.1),
        "business": (19.9, 54.1, 115.9), "activity": (164.8, 108.2, 34.8),
    ]
    private static let bandBox = CGRect(x: 40, y: 346, width: 120, height: 161)

    /// The tag's resting region (right of the band) and the attached region (under the clasp).
    private static let restingBox = CGRect(x: 300, y: 440, width: 110, height: 100)
    private static let attachedBox = CGRect(x: 170, y: 440, width: 100, height: 100)
    /// The attached tag's icon: 25 × 25 at tag-local 31.5, 31, the tag at hero 144, 129.
    private static let glyphBox = CGRect(x: 207.5, y: 486, width: 25, height: 25)

    /// 5 × 5 ink fractions of the two approved tag icons, rasterised from their paths.
    private static let glyphSignatures: [String: [[Double]]] = [
        "chatFirst": [[0.0, 0.172, 0.367, 0.27, 0.0], [0.102, 0.355, 0.05, 0.175, 0.282],
                      [0.292, 0.312, 0.517, 0.15, 0.365], [0.258, 0.24, 0.105, 0.273, 0.223],
                      [0.26, 0.305, 0.338, 0.155, 0.0]],
        "okayToSayHello": [[0.133, 0.147, 0.407, 0.133, 0.0], [0.263, 0.367, 0.655, 0.585, 0.092],
                           [0.21, 0.57, 0.403, 0.372, 0.35], [0.07, 0.403, 0.0, 0.035, 0.328],
                           [0.0, 0.18, 0.372, 0.4, 0.04]],
    ]

    /// Steel pixels (at 3×) right of the band, and the lowest steel row under the clasp.
    private static func poseMeasure(_ shot: RenderedScreen) -> (right: Double, bottom: Double) {
        let right = Double(shot.count(in: restingBox, where: steel))
        let bottom = Double(shot.inkRows(in: attachedBox, where: steel)?.bottom ?? 0)
        return (right, bottom)
    }

    /// "resting" (the board's resting tag: ~34 000 steel pixels at 3× beside the band, and the
    /// clasp's steel ends at y 510), "attached" (none beside it; the tag's steel reaches y 522), or
    /// "moving" in between.
    private static func poseName(_ measure: (right: Double, bottom: Double)) -> String {
        if measure.right > 9000 && measure.bottom < 514 { return "resting" }
        if measure.right < 1500 && measure.bottom > 517 { return "attached" }
        return "moving"
    }

    private static func pose(_ shot: RenderedScreen) -> String {
        poseName(poseMeasure(shot))
    }

    /// Which approved icon the attached tag shows, by its ink signature, or nil when unclear.
    private static func glyph(_ shot: RenderedScreen) -> String? {
        let grid = shot.inkGrid(in: glyphBox, cells: 5, where: glyphInk)
        let total = grid.flatMap { $0 }.reduce(0, +)
        guard total > 2.5 else { return nil }
        let scored = glyphSignatures.map { key, signature -> (String, Double) in
            var distance = 0.0
            for r in 0..<5 { for c in 0..<5 { distance += abs(grid[r][c] - signature[r][c]) } }
            return (key, distance)
        }.sorted { $0.1 < $1.1 }
        guard let best = scored.first, scored.count > 1, best.1 + 1.0 < scored[1].1 else { return nil }
        return best.0
    }

    private static func bandIntent(_ shot: RenderedScreen) -> String? {
        let mean = shot.meanColour(in: bandBox)
        let scored = bandMeans.map { key, value -> (String, Double) in
            let d = ((mean.0 - value.0) * (mean.0 - value.0) + (mean.1 - value.1) * (mean.1 - value.1)
                     + (mean.2 - value.2) * (mean.2 - value.2)).squareRoot()
            return (key, d)
        }.min { $0.1 < $1.1 }
        guard let scored, scored.1 < 30 else { return nil }
        return scored.0
    }

    private static let commonAnchors: [Anchor] = [
        Anchor("Back arrow", CGRect(x: 34, y: 60, width: 24, height: 50), white, top: 79.7, bottom: 92.4),
        Anchor("Wordmark", CGRect(x: 84, y: 60, width: 160, height: 50), white, top: 78.31, bottom: 94.76),
        Anchor("DEMO", CGRect(x: 295, y: 76, width: 110, height: 20), cyan, top: 82.13, bottom: 90.38),
        Anchor("Headline", CGRect(x: 32, y: 145, width: 376, height: 125), white, top: 159.10, bottom: 261.90, tolerance: 1.5),
        Anchor("Support", CGRect(x: 32, y: 272, width: 376, height: 30), grey, top: 281.02, bottom: 297.85),
        Anchor("Privacy", CGRect(x: 32, y: 574, width: 376, height: 20), grey, top: 577.07, bottom: 590.72),
        Anchor("Chat first name", CGRect(x: 85, y: 611, width: 200, height: 24), white, top: 617.02, bottom: 629.77),
        Anchor("Okay to say hello name", CGRect(x: 85, y: 707, width: 200, height: 24), white, top: 713.02, bottom: 729.59),
        Anchor("Chat first explanation", CGRect(x: 85, y: 637, width: 270, height: 44), grey, top: 642.07),
        Anchor("Okay to say hello explanation", CGRect(x: 85, y: 733, width: 270, height: 44), grey, top: 738.07),
        Anchor("Chat first symbol", CGRect(x: 44, y: 626, width: 36, height: 36), white, top: 633.0, bottom: 655.0, tolerance: 1.5),
        Anchor("Okay to say hello symbol", CGRect(x: 44, y: 722, width: 36, height: 36), white, top: 728.0, bottom: 752.0, tolerance: 1.5),
        Anchor("Back label", CGRect(x: 120, y: 890, width: 200, height: 30), white, top: 899.61, bottom: 911.37),
    ]

    private static func stateAnchors(intent: String, approach: String?) -> [Anchor] {
        let title = "\(titles[intent] ?? intent) band · \(approach.flatMap { approachTitles[$0] } ?? "Choose your approach")"
        let summaryBottom: CGFloat = title.contains("g") && intent == "dating" ? 568.57
            : (title.contains { "gpyjq".contains($0) } ? 568.35 : 564.97)
        var anchors = commonAnchors + [
            Anchor("Summary", CGRect(x: 32, y: 547, width: 376, height: 24), white, top: 553.72, bottom: summaryBottom),
        ]
        for (option, y) in [("chatFirst", 602.0), ("okayToSayHello", 698.0)] {
            let selected = option == approach
            anchors.append(Anchor("\(approachTitles[option] ?? option) row", CGRect(x: 32, y: y - 4, width: 376, height: 92),
                                  selected ? selectedFill : tileFill,
                                  top: selected ? y + 2 : y, bottom: selected ? y + 82 : y + 84))
            // The radio: the disc's left half is light when selected, the row's fill when not.
            let disc = CGRect(x: 369.5, y: y + 38, width: 6, height: 4)
            anchors.append(Anchor("\(approachTitles[option] ?? option) radio \(selected ? "filled" : "empty")", disc,
                                  selected ? white : tileFill))
        }
        if approach == nil {
            anchors.append(Anchor("Continue preview (disabled)", CGRect(x: 60, y: 800, width: 320, height: 80), disabledFill,
                                  top: 812, bottom: 872))
            anchors.append(Anchor("Continue preview label (disabled)", CGRect(x: 100, y: 825, width: 240, height: 35),
                                  disabledText, top: 834.66, bottom: 852.21))
        } else {
            anchors.append(Anchor("Continue preview", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812, bottom: 872))
            anchors.append(Anchor("Continue preview label", CGRect(x: 100, y: 825, width: 240, height: 35), black,
                                  top: 834.66, bottom: 852.21))
        }
        return anchors
    }

    /// Checks the anchors, the carried band, the tag's pose and its icon on the current screen.
    private func softlyMeasured(_ app: XCUIApplication, _ state: String, intent: String, approach: String?) {
        softly {
            XCTAssertEqual(app.frame.size, CGSize(width: 440, height: 956), "Anchors are measured at 440 × 956.")
            guard let shot = RenderedScreen(app) else { return }
            var lines: [String] = []
            for anchor in Self.stateAnchors(intent: intent, approach: approach) {
                guard let ink = shot.inkRows(in: anchor.box, where: anchor.test) else {
                    XCTFail("\(state): \(anchor.name) is not drawn in \(anchor.box).")
                    continue
                }
                lines.append(String(format: "%@ %.2f-%.2f", anchor.name, ink.top, ink.bottom))
                if let top = anchor.top {
                    XCTAssertEqual(ink.top, top, accuracy: anchor.tolerance, "\(state): \(anchor.name) top drawn at \(ink.top), approved \(top).")
                }
                if let bottom = anchor.bottom {
                    XCTAssertEqual(ink.bottom, bottom, accuracy: anchor.tolerance, "\(state): \(anchor.name) bottom drawn at \(ink.bottom), approved \(bottom).")
                }
            }
            let measure = Self.poseMeasure(shot)
            let pose = Self.poseName(measure)
            XCTAssertEqual(pose, approach == nil ? "resting" : "attached", "\(state): the tag's pose.")
            XCTAssertEqual(Self.bandIntent(shot), intent, "\(state): the carried band is drawn.")
            if let approach {
                XCTAssertEqual(Self.glyph(shot), approach, "\(state): the tag shows this approach's icon.")
            }
            lines.append(String(format: "pose %@ (right steel %.0f, clasp-box bottom %.2f); band %@; icon %@",
                                pose, measure.right, measure.bottom, Self.bandIntent(shot) ?? "unclear",
                                Self.glyph(shot) ?? "none"))
            attachNote("\(state): rendered anchors (points): " + lines.joined(separator: "; ") + ".")
        }
    }
}

/// The Signal's elements, by identifier.
@MainActor
private struct SignalScreen {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var headline: XCUIElement { element("signal.headline") }
    var support: XCUIElement { element("signal.support") }
    var summary: XCUIElement { element("signal.summary") }
    var privacy: XCUIElement { element("signal.privacy") }
    var demoBadge: XCUIElement { element("signal.demoBadge") }
    var primary: XCUIElement { app.buttons["signal.primary"] }
    var secondary: XCUIElement { app.buttons["signal.secondary"] }
    var back: XCUIElement { app.buttons["signal.back"] }

    func row(_ approach: String) -> XCUIElement { app.buttons["signal.approach.\(approach)"] }
}

@MainActor
private struct Wristband {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch }
    var primary: XCUIElement { app.buttons["wristband.primary"] }
    var back: XCUIElement { app.buttons["wristband.back"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

@MainActor
private struct GuestList {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.headline").firstMatch }
    var name: XCUIElement { app.textFields["guestList.name"] }
    var opener: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.opener").firstMatch }
    var coffee: XCUIElement { app.buttons["guestList.interest.coffee"] }
    var card: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.card").firstMatch }
    var primary: XCUIElement { app.buttons["guestList.primary"] }
    var secondary: XCUIElement { app.buttons["guestList.secondary"] }
    var back: XCUIElement { app.buttons["guestList.back"] }
}

@MainActor
private struct PassScreen {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
    var back: XCUIElement { app.buttons["pass.back"] }
}

private struct Anchor {
    let name: String
    let box: CGRect
    let test: (UInt8, UInt8, UInt8) -> Bool
    let top: CGFloat?
    let bottom: CGFloat?
    let tolerance: CGFloat

    init(_ name: String, _ box: CGRect, _ test: @escaping (UInt8, UInt8, UInt8) -> Bool,
         top: CGFloat? = nil, bottom: CGFloat? = nil, tolerance: CGFloat = 1.0) {
        self.name = name
        self.box = box
        self.test = test
        self.top = top
        self.bottom = bottom
        self.tolerance = tolerance
    }
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

    private func pixelRange(_ rect: CGRect) -> (x0: Int, x1: Int, y0: Int, y1: Int)? {
        let x0 = max(0, Int((rect.minX * scale).rounded())), x1 = min(width, Int((rect.maxX * scale).rounded()))
        let y0 = max(0, Int((rect.minY * scale).rounded())), y1 = min(height, Int((rect.maxY * scale).rounded()))
        guard x0 < x1, y0 < y1 else { return nil }
        return (x0, x1, y0, y1)
    }

    private func passes(_ x: Int, _ y: Int, _ test: (UInt8, UInt8, UInt8) -> Bool) -> Bool {
        let index = (y * width + x) * 4
        return test(pixels[index], pixels[index + 1], pixels[index + 2])
    }

    func inkRows(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> (top: CGFloat, bottom: CGFloat)? {
        guard let range = pixelRange(rect) else { return nil }
        var first: Int?
        var last: Int?
        for y in range.y0..<range.y1 where (range.x0..<range.x1).contains(where: { passes($0, y, test) }) {
            if first == nil { first = y }
            last = y
        }
        guard let first, let last else { return nil }
        return (CGFloat(first) / scale, CGFloat(last + 1) / scale)
    }

    func count(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> Int {
        guard let range = pixelRange(rect) else { return 0 }
        var total = 0
        for y in range.y0..<range.y1 {
            for x in range.x0..<range.x1 where passes(x, y, test) {
                total += 1
            }
        }
        return total
    }

    /// The fraction of pixels passing `test` in each of `cells` × `cells` equal parts of `rect`.
    func inkGrid(in rect: CGRect, cells: Int, where test: (UInt8, UInt8, UInt8) -> Bool) -> [[Double]] {
        var grid = Array(repeating: Array(repeating: 0.0, count: cells), count: cells)
        guard let range = pixelRange(rect) else { return grid }
        var totals = grid
        let w = Double(range.x1 - range.x0), h = Double(range.y1 - range.y0)
        for y in range.y0..<range.y1 {
            for x in range.x0..<range.x1 {
                let cx = min(cells - 1, Int(Double(x - range.x0) / w * Double(cells)))
                let cy = min(cells - 1, Int(Double(y - range.y0) / h * Double(cells)))
                totals[cy][cx] += 1
                if passes(x, y, test) { grid[cy][cx] += 1 }
            }
        }
        for r in 0..<cells { for c in 0..<cells { grid[r][c] /= max(1, totals[r][c]) } }
        return grid
    }

    func inkColumns(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> [(minX: CGFloat, maxX: CGFloat, height: CGFloat)] {
        guard let range = pixelRange(rect) else { return [] }
        var runs: [(minX: CGFloat, maxX: CGFloat, height: CGFloat)] = []
        var start: Int?
        var top = Int.max, bottom = Int.min
        for x in range.x0...range.x1 {
            var columnTop: Int?, columnBottom: Int?
            if x < range.x1 {
                for y in range.y0..<range.y1 where passes(x, y, test) {
                    if columnTop == nil { columnTop = y }
                    columnBottom = y
                }
            }
            if let columnTop, let columnBottom {
                if start == nil { start = x; top = Int.max; bottom = Int.min }
                top = min(top, columnTop)
                bottom = max(bottom, columnBottom)
            } else if let first = start {
                runs.append((CGFloat(first) / scale, CGFloat(x) / scale, CGFloat(bottom + 1 - top) / scale))
                start = nil
            }
        }
        return runs
    }

    func meanColour(in rect: CGRect) -> (Double, Double, Double) {
        guard let range = pixelRange(rect) else { return (0, 0, 0) }
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for y in stride(from: range.y0, to: range.y1, by: 2) {
            for x in stride(from: range.x0, to: range.x1, by: 2) {
                let index = (y * width + x) * 4
                r += Double(pixels[index])
                g += Double(pixels[index + 1])
                b += Double(pixels[index + 2])
                n += 1
            }
        }
        return n > 0 ? (r / n, g / n, b / n) : (0, 0, 0)
    }
}
