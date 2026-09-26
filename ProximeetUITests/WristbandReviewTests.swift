import UIKit
import XCTest

/// Runtime review of the approved Wristband (chapter 05), driven through the real route:
/// Welcome → More options → "Continue the demo (no account)" → Birthday → Continue → Pass → Try
/// the demo → Finish preview → Continue preview → Guest List (typed) → Preview my card →
/// Continue preview → Wristband.
///
/// Skipped unless the test runner's environment has `PROXIMEET_WRISTBAND_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_WRISTBAND_REVIEW=1` to xcodebuild). Real taps and typing. Tests that
/// start from a DEBUG fixture (`-ProximeetFixture wristband…`) say so; the fixtures reach the
/// Wristband through the same Birthday gate, completed Pass and Guest List card. Every name and
/// opener here is fictional test data.
@MainActor
final class WristbandReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_WRISTBAND_REVIEW"
    private static let privacy = "Choosing a band doesn’t make you visible."
    private static let intents = ["social", "dating", "business", "activity"]
    private static let titles = ["social": "Social", "dating": "Dating", "business": "Business", "activity": "Activity"]
    private static let hints = ["social": "People & moments", "dating": "Romantic connection",
                                "business": "Ideas & work", "activity": "Do something"]
    private static let explanations = ["social": "Meet people. Share a moment.", "dating": "Explore a romantic connection.",
                                       "business": "Exchange ideas and opportunities.", "activity": "Find someone to do things with."]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Wristband review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("WRISTBAND_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough

    /// The real route with a typed introduction; the empty Wristband; each of the four choices;
    /// the chosen tile again (nothing changes); Back to the actual Guest List card; editing the
    /// introduction and returning with the intent kept; the bottom Back and re-entry; and
    /// Continue preview's "End of this preview." with OK, staying on the choice.
    func testWalkthroughRouteChoicesBackReentryEndpoint() throws {
        print("WRISTBAND_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
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
        XCTAssertTrue(waitForFocus(guest.opener), "Return on the name moves to the opener.")
        guest.opener.typeText("Up for coffee.")
        tapKeyboardDone(app)
        guest.coffee.tap()
        hold(0.6)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, "Alex. Up for coffee. Interests: Coffee")
        hold(0.8)

        guest.primary.tap()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(1.0)
        capture("wristband-empty", app)
        assertState(band, selected: nil)
        softlyMeasured(app, "Empty", anchors: Self.commonAnchors + Self.emptyAnchors(), heroIntents: nil)

        for intent in Self.intents {
            band.tile(intent).tap()
            XCTAssertTrue(waitFor(band.tile(intent), selected: true), "\(intent) is selected at once.")
            hold(0.9)
            capture("wristband-\(intent)", app)
            assertState(band, selected: intent)
            softlyMeasured(app, Self.titles[intent] ?? intent, anchors: Self.commonAnchors + Self.selectedAnchors(intent), heroIntents: [intent])
        }

        // The chosen tile again: nothing changes, nothing clears.
        band.tile("activity").tap()
        hold(0.6)
        assertState(band, selected: "activity")

        // Back to the actual Guest List card, with the typed introduction.
        band.back.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, "Alex. Up for coffee. Interests: Coffee", "Back returns to the actual card.")
        hold(0.8)
        capture("wristband-back-card", app)

        // Edit the introduction and come forward again: the new words, the same intent.
        guest.secondary.tap()
        waitForLabel(guest.headline, "A little about you.")
        guest.opener.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap()
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText(" Or tea.")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, "Alex. Up for coffee. Or tea. Interests: Coffee", "The edit shows on the card.")
        hold(0.6)
        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.8)
        assertState(band, selected: "activity")
        capture("wristband-reentry-kept", app)

        // The bottom Back, then re-entry.
        band.secondary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(0.5)
        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        assertState(band, selected: "activity")
        hold(0.6)

        band.primary.tap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "Continue preview shows the end-of-preview message.")
        hold(0.8)
        capture("wristband-endpoint", app)
        end.buttons["OK"].tap()
        waitForAbsence(end)
        assertState(band, selected: "activity")
        hold(1.0)
    }

    // MARK: - Every change between intents

    /// Starts from the DEBUG fixture `wristband` (unselected, reached through the card). All
    /// twelve changes from one intent to another, in one sequence, and the selected tile again:
    /// each time exactly one tile is selected and checked, and the summary, the hero band and
    /// Continue preview all match it.
    func testEveryChangeBetweenIntentsKeepsEverythingInAgreement() throws {
        let app = launch(fixture: "wristband")
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.6)
        assertState(band, selected: nil)
        softlyMeasured(app, "Empty (fixture)", anchors: Self.commonAnchors + Self.emptyAnchors(), heroIntents: nil)

        // A tile's size never depends on the selection, so choosing cannot rearrange the grid.
        let frames = Self.intents.map { band.tile($0).frame }
        // From nothing to Social, then every ordered pair once (an Euler circuit of the twelve).
        let taps = ["social", "dating", "social", "business", "social", "activity", "dating",
                    "business", "dating", "activity", "business", "activity", "social"]
        for (step, intent) in taps.enumerated() {
            band.tile(intent).tap()
            XCTAssertTrue(waitFor(band.tile(intent), selected: true), "Step \(step): \(intent) is selected.")
            hold(0.5)
            assertState(band, selected: intent)
            XCTAssertEqual(Self.intents.map { band.tile($0).frame }, frames, "Step \(step): no tile moved or changed size.")
            softly {
                guard let shot = RenderedScreen(app) else { return }
                XCTAssertEqual(Self.heroIntent(shot), intent, "Step \(step): the hero shows the \(intent) band.")
                for other in Self.intents {
                    XCTAssertEqual(Self.checkDrawn(shot, other, band.tile(other).frame), other == intent,
                                   "Step \(step): \(other)'s check is drawn only when it is chosen.")
                }
            }
            if intent == "business" || intent == "activity", step >= 10 {
                softlyMeasured(app, "\(Self.titles[intent] ?? intent) (fixture)",
                               anchors: Self.commonAnchors + Self.selectedAnchors(intent), heroIntents: [intent])
            }
        }
        band.tile("social").tap()
        hold(0.5)
        assertState(band, selected: "social")
        capture("wristband-after-all-changes", app)
    }

    /// Starts from the DEBUG fixture `wristband`. Taps in quick succession (as fast as XCUITest
    /// delivers them) always leave the last requested choice, displayed consistently.
    func testRapidChangesLeaveTheLastChoice() throws {
        let app = launch(fixture: "wristband")
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        for sequence in [["social", "dating", "business", "activity"], ["dating", "activity", "dating"], ["business", "social"]] {
            for intent in sequence {
                band.tile(intent).tap()
            }
            let last = sequence[sequence.count - 1]
            XCTAssertTrue(waitFor(band.tile(last), selected: true))
            hold(0.6)
            assertState(band, selected: last)
            softly {
                guard let shot = RenderedScreen(app) else { return }
                XCTAssertEqual(Self.heroIntent(shot), last, "The hero shows the last choice.")
            }
        }
        capture("wristband-after-rapid-changes", app)

        // The app supports portrait only (UISupportedInterfaceOrientations): turning the device
        // leaves the screen, and the choice, as they were.
        XCUIDevice.shared.orientation = .landscapeLeft
        hold(1.2)
        softly {
            XCTAssertGreaterThan(app.frame.height, app.frame.width, "The interface stays in portrait.")
            assertState(band, selected: "social")
        }
        capture("wristband-device-turned-portrait-only", app)
        XCUIDevice.shared.orientation = .portrait
        hold(0.6)
    }

    // MARK: - Endpoint, duplicate taps and Back

    /// Starts from the DEBUG fixture `wristband-business`. A double tap on Continue preview shows
    /// one message; OK stays on Business. A double tap on either Back stops at the Guest List card;
    /// re-entry keeps Business. Nothing claims verification, visibility or consent.
    func testEndpointDuplicateTapsAndBack() throws {
        let app = launch(fixture: "wristband-business")
        let band = Wristband(app: app)
        let guest = GuestList(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        assertState(band, selected: "business")
        assertNothingConferred(app, allowingAlert: false)

        band.primary.doubleTap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        hold(0.8)
        XCTAssertEqual(app.alerts.count, 1, "A double tap shows one message.")
        end.buttons["OK"].tap()
        waitForAbsence(end)
        XCTAssertEqual(app.alerts.count, 0)
        assertState(band, selected: "business")

        band.back.doubleTap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(1.0)
        XCTAssertEqual(guest.headline.label, "Your first hello.", "A double tap on Back stops at the card.")
        capture("wristband-after-double-back", app)

        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        assertState(band, selected: "business")
        band.secondary.doubleTap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(1.0)
        XCTAssertEqual(guest.headline.label, "Your first hello.", "A double tap on the bottom Back stops at the card.")
        assertNothingConferred(app, allowingAlert: false)
    }

    // MARK: - Memory only

    /// Starts from the DEBUG fixture `wristband-dating`, then relaunches without one and walks
    /// the real route: the new run's Wristband is unselected.
    func testRelaunchStartsUnselected() throws {
        var app = launch(fixture: "wristband-dating")
        var band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        assertState(band, selected: "dating")

        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10), "A fresh launch starts at Welcome.")
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        XCTAssertEqual(guest.name.value as? String, "What should we call you?", "The introduction is empty again.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Sam")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.primary.tap()
        band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.6)
        assertState(band, selected: nil)
        capture("wristband-after-relaunch-empty", app)
    }

    // MARK: - Reduce Motion and largest text

    /// Starts from the DEBUG fixture `wristband` with the app-level preview flag
    /// `-ProximeetReduceMotionPreview YES` (not the system setting): a change shows the new band
    /// in place, with nothing moving. The standard path is also an in-place dissolve (220 ms rather
    /// than 120 ms), so this shows the Reduce Motion outcome, not that the flag shortened it.
    func testReduceMotionPreviewChangesWithoutMovement() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "wristband", "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.6)
        band.tile("dating").tap()
        hold(0.2)
        let early = RenderedScreen(app).map { ($0.inkRows(in: Self.heroBox, where: Self.notGround), Self.heroIntent($0)) }
        hold(1.0)
        capture("wristband-reduce-motion-preview-dating", app)
        let settled = RenderedScreen(app).map { ($0.inkRows(in: Self.heroBox, where: Self.notGround), Self.heroIntent($0)) }
        softly {
            XCTAssertEqual(settled?.1, "dating")
            XCTAssertEqual(early?.1, "dating", "Reduce Motion: the new band is already in place.")
            if let a = early?.0, let b = settled?.0 {
                XCTAssertEqual(a.top, b.top, accuracy: 0.34, "Nothing moves.")
                XCTAssertEqual(a.bottom, b.bottom, accuracy: 0.34, "Nothing moves.")
            }
        }
        attachNote("Reduce Motion preview: band rows \(String(describing: early?.0)) at 0.2 s, \(String(describing: settled?.0)) at 1.2 s.")
    }

    /// Starts from the DEBUG fixture `wristband-social` at the largest accessibility text size:
    /// DEMO is drawn whole, the choices become one column, and every choice, the helper, the
    /// privacy sentence and both actions are reachable by scrolling. Nothing is shrunk.
    func testLargestTextKeepsEveryChoiceReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ProximeetFixture", "wristband-social",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(1.2)
        XCTAssertGreaterThan(band.headline.frame.height, 112 + 10, "The largest text size must be applied.")
        attachNote("Largest text: headline \(NSCoder.string(for: band.headline.frame)).")
        softly {
            // Two approved lines of 56 pt grown to about 99 pt each would be about 198 pt; wrapping
            // between words rather than shrinking makes it taller.
            XCTAssertGreaterThan(band.headline.frame.height, 300, "The headline wraps rather than shrinks.")
        }
        capture("wristband-largest-text-top", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let clusters = shot.inkColumns(in: CGRect(x: 200, y: 50, width: 240, height: 110), where: Self.cyan)
            let tallest = clusters.map { $0.height }.max() ?? 0
            attachNote("Largest text: DEMO glyph clusters: " + clusters.map { String(format: "%.1f-%.1f h %.1f", $0.minX, $0.maxX, $0.height) }.joined(separator: ", "))
            XCTAssertGreaterThanOrEqual(clusters.count, 4, "DEMO should be drawn as its letters.")
            XCTAssertFalse(clusters.contains { $0.height < tallest * 0.5 }, "DEMO is truncated: an ellipsis is drawn.")
        }
        XCTAssertTrue(band.back.isHittable)
        var tileFrames: [CGRect] = []
        for element in [band.summary, band.explanation] + Self.intents.map(band.tile) + [band.privacy] {
            XCTAssertTrue(scrollIntoView(element, band, app), "\(element.identifier) is reachable by scrolling.")
            if element.elementType == .button {
                XCTAssertGreaterThanOrEqual(element.frame.height, 44)
                XCTAssertGreaterThanOrEqual(element.frame.minX, 31, "\(element.identifier) stays inside the column.")
                XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.width - 31, "\(element.identifier) stays inside the column.")
                tileFrames.append(element.frame)
            }
        }
        XCTAssertEqual(tileFrames.count, 4)
        XCTAssertEqual(Set(tileFrames.map { Int($0.minX.rounded()) }).count, 1, "At the largest size the choices are one column.")
        XCTAssertEqual(band.summary.label, "Social · Selected")
        XCTAssertTrue(band.primary.isHittable && band.secondary.isHittable, "Both actions stay on screen.")
        hold(0.6)
        capture("wristband-largest-text-choices", app)
        band.tile("activity").tap()
        XCTAssertTrue(waitFor(band.tile("activity"), selected: true))
        XCTAssertEqual(band.summary.label, "Activity · Selected")
        XCTAssertTrue(scrollIntoView(band.privacy, band, app))
        capture("wristband-largest-text-bottom", app)
    }

    // MARK: - Route helpers

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10))
        return app
    }

    private func launch(fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", fixture]
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

    /// Exactly `selected` (or no) tile is selected; the summary, the explanation and Continue
    /// preview agree with it; DEMO and the privacy sentence are on the screen; targets are 44 pt.
    private func assertState(_ band: Wristband, selected: String?) {
        XCTAssertEqual(band.headline.label, "Choose your kind of hello.")
        XCTAssertEqual(band.support.label, "One intent for this moment.")
        XCTAssertEqual(band.demoBadge.label, "Demo")
        XCTAssertEqual(band.privacy.label, Self.privacy)
        for intent in Self.intents {
            let tile = band.tile(intent)
            XCTAssertEqual(tile.label, Self.titles[intent], "Tiles keep their order and names.")
            XCTAssertEqual(tile.isSelected, intent == selected, "\(intent) selected: \(tile.isSelected)")
            XCTAssertTrue(tile.isEnabled, "All four choices stay available.")
            XCTAssertGreaterThanOrEqual(tile.frame.height, 44)
        }
        if let selected {
            XCTAssertEqual(band.summary.label, "\(Self.titles[selected] ?? selected) · Selected")
            XCTAssertEqual(band.explanation.label, Self.explanations[selected])
            XCTAssertTrue(band.primary.isEnabled, "Continue preview is enabled once an intent is chosen.")
        } else {
            XCTAssertEqual(band.summary.label, "Your moment. Your choice.")
            XCTAssertEqual(band.explanation.label, "Pick the band that fits right now.")
            XCTAssertFalse(band.primary.isEnabled, "Continue preview waits for a choice.")
        }
        XCTAssertEqual(band.primary.label, "Continue preview")
        XCTAssertGreaterThanOrEqual(band.primary.frame.height, 60)
        XCTAssertGreaterThanOrEqual(band.secondary.frame.height, 44)
        XCTAssertGreaterThanOrEqual(band.back.frame.height, 44)
        XCTAssertGreaterThanOrEqual(band.back.frame.width, 44)
    }

    private func assertNothingConferred(_ app: XCUIApplication, allowingAlert: Bool) {
        let words = ["verified", "access granted", "checked in", "check in", "you're visible", "you’re visible",
                     "now visible", "nearby", "matched", "online now", "member", "discoverable", "can message",
                     "can approach", "location"]
        let predicate = NSPredicate(format: words.map { _ in "label CONTAINS[c] %@" }.joined(separator: " OR "), argumentArray: words)
        XCTAssertEqual(app.descendants(matching: .any).matching(predicate).count, 0, "No verified, visible, present, member or consent wording.")
        if !allowingAlert {
            XCTAssertEqual(app.alerts.count, 0, "No permission or provider prompt appeared.")
        }
        XCTAssertFalse(app.descendants(matching: .any)["signal.confirm"].exists, "No later chapter is reached.")
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

    /// The toolbar's Done above the keyboard (on iOS 26 a floating button, not a toolbar row).
    private func tapKeyboardDone(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "guestList.keyboardDone", "Done")).firstMatch
        if done.waitForExistence(timeout: 5) {
            done.tap()
            waitForAbsence(app.keyboards.firstMatch)
        } else {
            XCTFail("Done is offered above the keyboard.")
        }
    }

    /// Scrolls with short, momentum-free drags in the page margin until `element` lies between the
    /// status bar and the top of the action bar (hittability alone counts an element hidden behind
    /// the opaque bar).
    private func scrollIntoView(_ element: XCUIElement, _ band: Wristband, _ app: XCUIApplication) -> Bool {
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.3))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55))
        for _ in 0..<14 {
            let frame = element.frame, top: CGFloat = 62, bottom = band.primary.frame.minY - 13
            let low = frame.maxY > bottom, high = frame.minY < top
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

    private func hold(_ seconds: TimeInterval) {
        let done = expectation(description: "Hold so the recording shows this state")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 1)
    }

    /// Rendered-screen checks record every failure (the test still fails) without stopping the
    /// walkthrough, so one miscalibrated check cannot cost the later states' evidence.
    private func softly(_ checks: () -> Void) {
        continueAfterFailure = true
        checks()
        continueAfterFailure = false
    }

    // MARK: - What is drawn on screen
    //
    // Accessibility values do not prove anything was drawn, so these read the screenshot, in points
    // at 440 × 956. The approved board (docs/design/wristband-approved/reference/wristband-review.png)
    // is at 1× with the empty, Social and Dating frames at x 40 / 520 / 1000, y 186. Text anchors
    // are the glyphs' own extents on Figma's line boxes from the bundled Manrope outlines (they
    // agree with the board's rows); Business and Activity, which the board does not show, come
    // from `LAYOUT_SPEC.json` the same way. The bands' rows come from the original artworks with
    // the approved crop, and agree with the board.

    private static let white: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 200 }
    private static let grey: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 120 }
    private static let black: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 50 }
    private static let cyan: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 120 && g > 150 && b > 160 }
    private static let notGround: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) > 45 }
    /// #111415, an unselected tile; #242A2B, a selected one.
    private static let tileFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 12 && r <= 24 && g >= 15 && g <= 28 && b >= 16 && b <= 30 }
    private static let selectedFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 30 && r <= 42 && g >= 38 && g <= 48 && b >= 38 && b <= 50 }
    private static let disabledFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 25 && r <= 40 && g >= 30 && g <= 45 && b >= 30 && b <= 45 }
    private static let disabledText: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 95 && r < 135 && g > 105 && g < 145 && b > 100 && b < 140 }

    /// The intent colours (#F2877F, #C689ED, #5CA7FF, #EFC16B): summary, border, check and icon.
    private static func intentColour(_ intent: String) -> (UInt8, UInt8, UInt8) -> Bool {
        switch intent {
        case "social": return { r, g, b in r > 200 && g > 100 && g < 170 && b > 90 && b < 160 }
        case "dating": return { r, g, b in r > 170 && r < 225 && g > 110 && g < 165 && b > 205 }
        case "business": return { r, g, b in r < 130 && g > 140 && g < 200 && b > 225 }
        default: return { r, g, b in r > 210 && g > 170 && g < 215 && b > 80 && b < 140 }
        }
    }

    private static let heroBox = CGRect(x: 32, y: 328, width: 376, height: 200)

    /// The rendered hero's mean colour, nearest to one band's (computed from the original
    /// artwork, cropped and fitted, over #050606): coral, orchid, blue or amber.
    private static let heroMeans: [String: (Double, Double, Double)] = [
        "social": (133.9, 62.3, 53.7), "dating": (76.7, 42.3, 82.1),
        "business": (23.7, 48.1, 92.1), "activity": (126.9, 85.2, 33.1),
    ]
    private static let quadrantMeans: [String: (Double, Double, Double)] = [
        "social": (147.3, 68.1, 58.7), "dating": (84.1, 46.0, 90.0),
        "business": (25.9, 52.5, 101.1), "activity": (139.7, 93.6, 36.1),
    ]

    private static func nearest(_ colour: (Double, Double, Double), in means: [String: (Double, Double, Double)]) -> (String, Double) {
        means.map { key, value -> (String, Double) in
            let d = ((colour.0 - value.0) * (colour.0 - value.0) + (colour.1 - value.1) * (colour.1 - value.1)
                     + (colour.2 - value.2) * (colour.2 - value.2)).squareRoot()
            return (key, d)
        }.min { $0.1 < $1.1 }!
    }

    /// Which single band the hero shows, or nil when it is not one band clearly.
    private static func heroIntent(_ shot: RenderedScreen) -> String? {
        let (intent, distance) = nearest(shot.meanColour(in: heroBox), in: heroMeans)
        return distance < 30 ? intent : nil
    }

    /// Whether `intent`'s check is drawn in its tile: a 14 pt disc in its colour at the tile's
    /// top right (Figma 178.5, 621.5 in a tile at 32, 602).
    private static func checkDrawn(_ shot: RenderedScreen, _ intent: String, _ tile: CGRect) -> Bool {
        let disc = CGRect(x: tile.minX + 147.5, y: tile.minY + 20.5, width: 14, height: 14).insetBy(dx: 3, dy: 3)
        return shot.inkRows(in: disc, where: intentColour(intent)) != nil
    }

    private static let tileOrigins: [String: CGPoint] = [
        "social": CGPoint(x: 32, y: 602), "dating": CGPoint(x: 226, y: 602),
        "business": CGPoint(x: 32, y: 692), "activity": CGPoint(x: 226, y: 692),
    ]

    private static let commonAnchors: [Anchor] = [
        Anchor("Back arrow", CGRect(x: 34, y: 60, width: 24, height: 50), white, top: 79.7, bottom: 92.4),
        Anchor("Wordmark", CGRect(x: 84, y: 60, width: 160, height: 50), white, top: 78.31, bottom: 94.76),
        Anchor("DEMO", CGRect(x: 295, y: 76, width: 110, height: 20), cyan, top: 82.13, bottom: 90.38),
        Anchor("Headline", CGRect(x: 32, y: 145, width: 376, height: 120), white, top: 159.10, bottom: 251.10),
        Anchor("Support", CGRect(x: 32, y: 275, width: 376, height: 26), grey, top: 281.02, bottom: 293.77),
        Anchor("Privacy", CGRect(x: 32, y: 780, width: 376, height: 22), grey, top: 784.07, bottom: 797.93),
        Anchor("Back label", CGRect(x: 120, y: 890, width: 200, height: 30), white, top: 899.61, bottom: 911.37),
    ]

    private static func emptyAnchors() -> [Anchor] {
        var anchors = [
            Anchor("Bands", heroBox, notGround, top: 331.0, bottom: 513.0, tolerance: 1.5),
            Anchor("Summary", CGRect(x: 32, y: 538, width: 376, height: 24), white, top: 542.75, bottom: 556.16),
            Anchor("Explanation", CGRect(x: 32, y: 566, width: 376, height: 20), grey, top: 570.07, bottom: 583.93),
            Anchor("Continue preview (disabled)", CGRect(x: 60, y: 800, width: 320, height: 80), disabledFill, top: 812, bottom: 872),
            Anchor("Continue preview label (disabled)", CGRect(x: 100, y: 825, width: 240, height: 35), disabledText, top: 834.66, bottom: 852.21),
        ]
        for intent in intents {
            anchors += tileAnchors(intent, selected: false)
        }
        return anchors
    }

    private static func selectedAnchors(_ chosen: String) -> [Anchor] {
        let summaryBottom = ["social": 556.16, "dating": 560.48, "business": 556.16, "activity": 560.21][chosen] ?? 556.16
        let explanationTop = ["social": 570.07, "dating": 570.07, "business": 570.21, "activity": 570.21][chosen] ?? 570.07
        let explanationBottom = ["social": 583.72, "dating": 583.72, "business": 583.93, "activity": 583.93][chosen] ?? 583.93
        var anchors = [
            Anchor("Band", heroBox, notGround, top: 344.0, bottom: 513.0, tolerance: 1.5),
            Anchor("Summary", CGRect(x: 32, y: 538, width: 376, height: 26), intentColour(chosen), top: 542.66, bottom: summaryBottom),
            Anchor("Explanation", CGRect(x: 32, y: 566, width: 376, height: 20), grey, top: explanationTop, bottom: explanationBottom),
            Anchor("Continue preview", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812, bottom: 872),
            Anchor("Continue preview label", CGRect(x: 100, y: 825, width: 240, height: 35), black, top: 834.66, bottom: 852.21),
        ]
        for intent in intents {
            anchors += tileAnchors(intent, selected: intent == chosen)
        }
        return anchors
    }

    /// A tile: its fill (#111415, or #242A2B inside a 1.5 pt border in the intent's colour when
    /// selected), its name (SemiBold 16/24), its icon and, when selected, its check. Figma moves a
    /// selected tile's content 1.5 pt in.
    private static func tileAnchors(_ intent: String, selected: Bool) -> [Anchor] {
        let origin = tileOrigins[intent] ?? .zero
        let shift: CGFloat = selected ? 1.5 : 0
        let row2 = origin.y > 650
        let nameTop: CGFloat = (row2 ? 712.45 : (intent == "social" ? 622.37 : 622.45)) + shift
        let nameBottom: CGFloat = (row2 ? (intent == "business" ? 724.37 : 727.97) : (intent == "social" ? 634.37 : 638.21)) + shift
        let title = titles[intent] ?? intent
        var anchors = [
            Anchor("\(title) tile", CGRect(x: origin.x, y: origin.y - 4, width: 182, height: 86), selected ? selectedFill : tileFill,
                   top: origin.y + (selected ? 1.5 : 0), bottom: origin.y + 78 - (selected ? 1.5 : 0)),
            Anchor("\(title) name", CGRect(x: origin.x + 44, y: origin.y + 10, width: 95, height: 30), white, top: nameTop, bottom: nameBottom),
            Anchor("\(title) icon", CGRect(x: origin.x + 12, y: origin.y + 12, width: 30, height: 30), intentColour(intent)),
        ]
        if selected {
            anchors.append(Anchor("\(title) border", CGRect(x: origin.x, y: origin.y + 20, width: 3, height: 40), intentColour(intent)))
            anchors.append(Anchor("\(title) check", CGRect(x: origin.x + 144, y: origin.y + 17, width: 22, height: 22), intentColour(intent),
                                  top: origin.y + 20.5, bottom: origin.y + 34.5))
        }
        return anchors
    }

    /// Checks `anchors` on the current screen; `heroIntents` nil checks the four equal bands, one
    /// per quadrant; otherwise the one band shown.
    private func softlyMeasured(_ app: XCUIApplication, _ state: String, anchors: [Anchor], heroIntents: [String]?) {
        softly {
            XCTAssertEqual(app.frame.size, CGSize(width: 440, height: 956), "Anchors are measured at 440 × 956.")
            guard let shot = RenderedScreen(app) else { return }
            var lines: [String] = []
            for anchor in anchors {
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
            if let heroIntents {
                XCTAssertEqual(Self.heroIntent(shot), heroIntents.first, "\(state): the hero shows the chosen band.")
            } else {
                for (index, intent) in Self.intents.enumerated() {
                    let quadrant = CGRect(x: 32 + CGFloat(index % 2) * 194, y: 328 + CGFloat(index / 2) * 100, width: 182, height: 88)
                    let (found, distance) = Self.nearest(shot.meanColour(in: quadrant), in: Self.quadrantMeans)
                    XCTAssertEqual(found, intent, "\(state): the \(intent) band is in its place (distance \(distance)).")
                }
            }
            attachNote("\(state): rendered anchors (points): " + lines.joined(separator: "; ") + ".")
        }
    }
}

/// The Wristband's elements, by identifier.
@MainActor
private struct Wristband {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var headline: XCUIElement { element("wristband.headline") }
    var support: XCUIElement { element("wristband.support") }
    var summary: XCUIElement { element("wristband.summary") }
    var explanation: XCUIElement { element("wristband.explanation") }
    var privacy: XCUIElement { element("wristband.privacy") }
    var demoBadge: XCUIElement { element("wristband.demoBadge") }
    var primary: XCUIElement { app.buttons["wristband.primary"] }
    var secondary: XCUIElement { app.buttons["wristband.secondary"] }
    var back: XCUIElement { app.buttons["wristband.back"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

/// The Guest List's elements used on the route.
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
}

@MainActor
private struct PassScreen {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
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

    /// The first and last pixel rows in `rect` (points) holding a pixel that passes `test`, in
    /// points (the bottom is the lower edge of the last row).
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

    /// Runs of adjacent pixel columns in `rect` holding a pixel that passes `test` (a letter each,
    /// for widely set type), with each run's vertical ink extent, in points.
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

    /// The mean colour of `rect` (points), sampled every other pixel.
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
