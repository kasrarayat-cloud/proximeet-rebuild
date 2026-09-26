import UIKit
import XCTest

/// Runtime review of the approved Guest List (chapter 04), driven through the real route:
/// Welcome → More options → "Continue the demo (no account)" → Birthday (a real wheel date) →
/// Continue → Pass → Try the demo → Finish preview → Continue preview → Guest List.
///
/// Skipped unless the test runner's environment has `PROXIMEET_GUEST_LIST_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1` to xcodebuild). Real taps, typing and pastes.
/// Tests that start from a DEBUG fixture (`-ProximeetFixture guest-list…`) say so; the fixtures
/// open the Guest List through the same Birthday gate and completed Pass. Every name and opener
/// here is fictional test data.
@MainActor
final class GuestListReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_GUEST_LIST_REVIEW"
    private static let boundary = "This preview doesn’t make you visible to anyone."
    private static let opener = "Always up for coffee and a good story."
    private static let alexCard = "Alex. Always up for coffee and a good story. Interests: Coffee, Live music, Outdoors"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Guest List review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("GUEST_LIST_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough

    /// Into the Guest List from a completed Pass; the empty editor; typing the name, Return to
    /// the opener, typing it, Done; the three interests; Preview my card; Back and Edit
    /// introduction to the editor with everything kept; Back to the complete Pass; re-entry with
    /// the draft; and Continue preview on the card opening the Wristband (chapter 05), whose Back
    /// returns to the card.
    func testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint() throws {
        print("GUEST_LIST_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        let app = launchWelcome()
        hold(1.2)
        let pass = openCompletedPass(app)
        hold(0.6)

        pass.primary.tap()
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        hold(1.0)
        capture("guest-list-empty", app)
        assertEditor(guest, name: "", opener: "", selected: [false, false, false])
        XCTAssertFalse(guest.primary.isEnabled, "Preview my card waits for a name.")
        XCTAssertFalse(guest.nameHelp.exists, "No validation message before the guest does anything.")
        softlyMeasured(app, "Empty editor", anchors: Self.headerAnchors + Self.emptyEditorAnchors + Self.editorFooterAnchors(enabled: false))

        // Typing: the name, Return to the opener, the opener, Done.
        guest.name.tap()
        XCTAssertTrue(waitForKeyboard(app), "The keyboard opens for the name.")
        guest.name.typeText("Alex")
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener), "Return on the name moves to the opener.")
        guest.opener.typeText(Self.opener)
        XCTAssertEqual(guest.count.label, "38 of 120 characters")
        hold(0.8)
        capture("guest-list-keyboard-open", app)
        assertReachableAboveKeyboard(app, guest, field: guest.opener)
        tapKeyboardDone(app)
        XCTAssertTrue(waitForNoKeyboard(app), "Done closes the keyboard.")
        hold(0.6)

        for chip in [guest.coffee, guest.liveMusic, guest.outdoors] {
            chip.tap()
            XCTAssertTrue(waitFor(chip, selected: true), "\(chip.label) is selected.")
        }
        hold(1.0)
        capture("guest-list-filled", app)
        assertEditor(guest, name: "Alex", opener: Self.opener, selected: [true, true, true])
        XCTAssertTrue(guest.primary.isEnabled)
        softlyMeasured(app, "Fictional example", anchors: Self.headerAnchors + Self.filledEditorAnchors + Self.editorFooterAnchors(enabled: true))

        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(1.2)
        capture("guest-list-card", app)
        assertCard(guest, label: Self.alexCard)
        softlyMeasured(app, "Card", anchors: Self.headerAnchors + Self.cardAnchors)

        // Back on the card returns to the editor with the raw draft and the selections.
        guest.back.tap()
        waitForHeadline(guest, "A little about you.")
        assertEditor(guest, name: "Alex", opener: Self.opener, selected: [true, true, true])
        hold(0.8)

        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(0.8)
        guest.secondary.tap()
        waitForHeadline(guest, "A little about you.")
        assertEditor(guest, name: "Alex", opener: Self.opener, selected: [true, true, true])
        hold(0.8)
        capture("guest-list-edit-kept", app)

        // Back on the editor returns to the actual Pass, still complete.
        guest.secondary.tap()
        waitForAbsence(guest.headline)
        waitForPass(pass, "Demo complete.")
        XCTAssertEqual(pass.primary.label, "Continue preview", "Returning does not restart the Pass.")
        hold(1.0)
        capture("guest-list-back-pass-complete", app)

        // Re-entry keeps the draft for this run.
        pass.primary.tap()
        waitForHeadline(guest, "A little about you.")
        assertEditor(guest, name: "Alex", opener: Self.opener, selected: [true, true, true])
        hold(1.0)
        capture("guest-list-reentry-kept", app)

        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(1.0)
        // Continue preview now opens the Wristband (chapter 05); its Back returns to this card.
        guest.primary.tap()
        let wristband = app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch
        XCTAssertTrue(wristband.waitForExistence(timeout: 5), "Continue preview on the card opens the Wristband.")
        XCTAssertEqual(app.alerts.count, 0, "No end-of-preview message on the card any more.")
        hold(0.8)
        capture("guest-list-continue-wristband", app)
        app.buttons["wristband.back"].tap()
        waitForHeadline(guest, "Your first hello.")
        assertCard(guest, label: Self.alexCard)
        hold(1.2)
    }

    // MARK: - Names

    /// Starts from the DEBUG fixture `guest-list` (the empty editor after a completed Pass).
    /// A blank name is refused gently; international, punctuated and long names are kept exactly
    /// as pasted and shown on the card, trimmed only at the edges.
    func testBlankInternationalAndLongNames() throws {
        let app = launch(fixture: "guest-list")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")

        guest.name.tap()
        guest.name.typeText("   ")
        XCTAssertFalse(guest.primary.isEnabled, "Spaces are not a name.")
        XCTAssertTrue(guest.nameHelp.waitForExistence(timeout: 3), "The name's help explains why Preview waits.")
        XCTAssertEqual(guest.nameHelp.label, "Add a name to preview your card.")
        tapKeyboardDone(app)
        hold(0.6)
        capture("guest-list-name-blank", app)

        let names: [(raw: String, shown: String)] = [
            ("  Zoë Ødegård-Nakamura ", "Zoë Ødegård-Nakamura"),
            ("김민지", "김민지"),
            ("محمد سالم", "محمد سالم"),
            ("Siobhán O'Brien, Jr.", "Siobhán O'Brien, Jr."),
            ("Maximiliana Alexandrina Wilhelmina von Hohenzollern-Sigmaringen", "Maximiliana Alexandrina Wilhelmina von Hohenzollern-Sigmaringen"),
        ]
        for (index, name) in names.enumerated() {
            paste(name.raw, into: guest.name, placeholder: "What should we call you?", app)
            XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), name.raw, "The name is kept exactly as pasted.")
            XCTAssertTrue(guest.primary.isEnabled, "\(name.shown) can be previewed.")
            XCTAssertFalse(guest.nameHelp.exists)
            tapKeyboardDoneIfShown(app)
            guest.primary.tap()
            waitForHeadline(guest, "Your first hello.")
            hold(0.8)
            XCTAssertEqual(guest.card.label, name.shown, "The card shows the name, trimmed only at its edges, once.")
            capture("guest-list-name-\(index + 1)", app)
            if index == names.count - 1 {
                // The long name wraps; the paper grows with it and holds every line. Checked with the
                // card's foot scrolled into view above the action bar.
                XCTAssertGreaterThan(guest.card.frame.height, 256.46 + 20, "The card grows for a long name.")
                XCTAssertTrue(scrollIntoView(guest.card, guest, app, footOnly: true), "The long name's card foot is reachable.")
                hold(0.6)
                capture("guest-list-name-5-foot", app)
                softly {
                    guard let shot = RenderedScreen(app) else { return }
                    let card = guest.card.frame
                    let visibleBottom = guest.primary.frame.minY - 25
                    XCTAssertLessThan(card.maxY, visibleBottom, "The card's foot is on screen for this check.")
                    let column = Self.textColumn(of: card).intersection(CGRect(x: 0, y: 70, width: 440, height: max(1, visibleBottom - 70)))
                    let ink = shot.inkRows(in: column, where: Self.black)
                    XCTAssertNotNil(ink, "The long name is drawn on the card.")
                    if let ink {
                        XCTAssertLessThanOrEqual(ink.bottom, card.maxY - 24, "The text ends on the paper, above its holder.")
                    }
                }
            }
            guest.secondary.tap()
            waitForHeadline(guest, "A little about you.")
            XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), name.raw, "Edit introduction keeps the raw name.")
        }
    }

    // MARK: - The opener

    /// Starts from the DEBUG fixture `guest-list`. A pasted opener of 121 user-perceived
    /// characters (emoji, a family sequence, a composed accent, a flag) is kept whole, the count
    /// says 121 / 120, the help explains the limit and Preview waits; deleting one character
    /// restores it. 120 family emoji are within the limit.
    func testOpenerLimitBoundariesAndPreservedPaste() throws {
        let app = launch(fixture: "guest-list")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        guest.name.tap()
        guest.name.typeText("Alex")

        // 15 × 8 characters, then one more: 121.
        let unit = "ab 👩‍👩‍👧‍👦 e\u{0301}🇺🇳 "
        XCTAssertEqual(unit.count, 8)
        let over = String(repeating: unit, count: 15) + "x"
        XCTAssertEqual(over.count, 121)
        paste(over, into: guest.opener, placeholder: "A good hello starts with…", app)
        XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), over, "The paste is kept whole: nothing is cut or rewritten.")
        XCTAssertEqual(guest.count.label, "121 of 120 characters")
        XCTAssertTrue(guest.openerHelp.waitForExistence(timeout: 3), "Over the limit, the help explains why Preview waits.")
        XCTAssertEqual(guest.openerHelp.label, "Keep it to 120 characters to preview your card.")
        XCTAssertFalse(guest.primary.isEnabled)
        hold(0.6)
        capture("guest-list-validation", app)

        guest.opener.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertTrue(waitFor(guest.count, label: "120 of 120 characters"), "Deleting one character reaches the limit.")
        XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), String(over.dropLast()))
        waitForAbsence(guest.openerHelp)
        XCTAssertFalse(guest.openerHelp.exists)
        XCTAssertTrue(guest.primary.isEnabled, "120 characters can be previewed.")

        let families = String(repeating: "👩‍👩‍👧‍👦", count: 120)
        paste(families, into: guest.opener, placeholder: "A good hello starts with…", app)
        XCTAssertEqual(guest.count.label, "120 of 120 characters", "120 family emoji are 120 characters.")
        XCTAssertTrue(guest.primary.isEnabled)
        tapKeyboardDoneIfShown(app)
        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(0.8)
        XCTAssertEqual(guest.card.label, "Alex. " + families)
        capture("guest-list-card-120-emoji", app)
    }

    // MARK: - Interests

    /// Starts from the DEBUG fixture `guest-list`. Each chip toggles on its own; zero to three
    /// selections are valid; the card lists exactly the selected interests in catalog order, with
    /// separators only between them; a name-only card has no rule and no interest line.
    func testInterestsToggleIndependentlyAndOptionalContentIsOmitted() throws {
        let app = launch(fixture: "guest-list")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        guest.name.tap()
        guest.name.typeText("Alex")
        tapKeyboardDone(app)
        XCTAssertTrue(waitForNoKeyboard(app))

        // Name only: no opener, no interests.
        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(1.0)
        XCTAssertEqual(guest.card.label, "Alex")
        capture("guest-list-name-only-card", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let card = guest.card.frame
            let rules = shot.longRuns(in: Self.writingArea(of: card), minimumLength: 200, where: Self.rule)
            XCTAssertEqual(rules, 0, "No rule is drawn without interests.")
            XCTAssertEqual(card.height, 256.46, accuracy: 1.0, "The approved card size holds for a short card.")
        }
        guest.secondary.tap()
        waitForHeadline(guest, "A little about you.")

        let steps: [(tap: [XCUIElement], selected: [Bool], card: String)] = [
            ([guest.coffee, guest.outdoors], [true, false, true], "Alex. Interests: Coffee, Outdoors"),
            ([guest.coffee, guest.liveMusic], [false, true, true], "Alex. Interests: Live music, Outdoors"),
            ([guest.coffee], [true, true, true], "Alex. Interests: Coffee, Live music, Outdoors"),
            ([guest.liveMusic, guest.outdoors], [true, false, false], "Alex. Interests: Coffee"),
            ([guest.coffee], [false, false, false], "Alex"),
        ]
        for (index, step) in steps.enumerated() {
            for chip in step.tap {
                // A separate tap for each chip: not a rapid repeat on the same spot.
                chip.tap()
                hold(0.5)
            }
            let chips = [guest.coffee, guest.liveMusic, guest.outdoors]
            XCTAssertEqual(chips.map(\.isSelected), step.selected, "Step \(index + 1): each chip toggles on its own.")
            XCTAssertTrue(guest.primary.isEnabled, "\(step.selected.filter { $0 }.count) interests are valid.")
            if index == 0 {
                capture("guest-list-two-interests", app)
                softly {
                    // The selected state is drawn with a check mark, not by colour alone.
                    guard let shot = RenderedScreen(app) else { return }
                    for (chip, selected) in zip(chips, step.selected) {
                        let mark = CGRect(x: chip.frame.minX + 6, y: chip.frame.minY + 12, width: 16, height: chip.frame.height - 24)
                        if selected {
                            XCTAssertNotNil(shot.inkRows(in: mark, where: Self.cyan), "\(chip.label): the selected fill.")
                            XCTAssertNotNil(shot.inkRows(in: mark, where: Self.black), "\(chip.label): the check mark is drawn on it.")
                        } else {
                            XCTAssertNil(shot.inkRows(in: mark, where: Self.cyan), "\(chip.label): unselected, no selected fill.")
                        }
                    }
                }
            }
            guest.primary.tap()
            waitForHeadline(guest, "Your first hello.")
            hold(0.6)
            XCTAssertEqual(guest.card.label, step.card, "Step \(index + 1): the card lists exactly the selected interests.")
            if index == 0 {
                capture("guest-list-card-two-interests", app)
            }
            guest.secondary.tap()
            waitForHeadline(guest, "A little about you.")
        }
    }

    // MARK: - Keyboard

    /// Starts from the DEBUG fixture `guest-list`. The focused field and both actions stay above
    /// the keyboard; Return moves Name → Introduction and adds a line in the introduction; Done
    /// closes the keyboard and keeps the labels and the draft; hardware Tab and Shift-Tab move
    /// between the two fields.
    func testKeyboardFocusOrderReachabilityAndDismissal() throws {
        let app = launch(fixture: "guest-list")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")

        guest.name.tap()
        XCTAssertTrue(waitForKeyboard(app))
        XCTAssertTrue(waitForFocus(guest.name))
        assertReachableAboveKeyboard(app, guest, field: guest.name)
        guest.name.typeText("Alex")
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener), "Return on the name moves to the opener.")
        assertReachableAboveKeyboard(app, guest, field: guest.opener)

        guest.opener.typeText("Hi")
        guest.opener.typeText("\n")
        guest.opener.typeText("there")
        XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), "Hi\nthere", "Return adds a line in the introduction.")
        XCTAssertEqual(guest.count.label, "8 of 120 characters")
        hold(0.6)
        capture("guest-list-keyboard-opener", app)

        tapKeyboardDone(app)
        XCTAssertTrue(waitForNoKeyboard(app), "Done closes the keyboard.")
        hold(0.8)
        XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), "Alex", "The draft survives dismissal.")
        XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), "Hi\nthere")
        softly {
            // The persistent labels are still drawn, 8 pt above their fields.
            guard let shot = RenderedScreen(app) else { return }
            for field in [guest.name, guest.opener] {
                let label = CGRect(x: field.frame.minX, y: field.frame.minY - 32, width: 200, height: 24)
                XCTAssertNotNil(shot.inkRows(in: label, where: Self.white), "The label above \(field.identifier) is drawn.")
            }
        }
        capture("guest-list-keyboard-dismissed", app)
    }

    /// Starts from the DEBUG fixture `guest-list-filled`. With the keyboard open, the floating Done
    /// and the editor's Back are separate targets. On build 6ab75905 (iPhone 17 Pro Max) Done lay
    /// at y 569–605 over the bottom-right corner of Back's 376 × 44 target (545–589). Here, for
    /// each field: Done's frame meets neither action, both actions keep their size above the
    /// keyboard, and Done closes the keyboard and stays on the editor with the draft. Then, with
    /// the keyboard open, a tap 3 pt inside the bottom-right corner of Back's target goes back to
    /// the Pass. Run on the iPhone 17 Pro Max and on the smaller iPhone.
    func testKeyboardDoneAndBackStayIndependent() throws {
        let app = launch(fixture: "guest-list-filled")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        let width = Int(app.frame.width.rounded())
        for field in [guest.name, guest.opener] {
            field.tap()
            XCTAssertTrue(waitForKeyboard(app), "The keyboard opens for \(field.identifier).")
            XCTAssertTrue(waitForFocus(field))
            hold(0.8)
            let done = keyboardDoneButton(app)
            XCTAssertTrue(done.waitForExistence(timeout: 5), "Done is offered above the keyboard.")
            let doneFrame = done.frame, back = guest.secondary.frame, primary = guest.primary.frame
            let keyboard = app.keyboards.firstMatch.frame
            attachNote("Keyboard open (\(field.identifier), \(width) pt wide): Done \(NSCoder.string(for: doneFrame)); "
                + "Back \(NSCoder.string(for: back)); Preview my card \(NSCoder.string(for: primary)); "
                + "keyboard \(NSCoder.string(for: keyboard)); field \(NSCoder.string(for: field.frame)).")
            capture("guest-list-keyboard-done-back-\(field.identifier == "guestList.name" ? "name" : "opener")-\(width)pt", app)
            XCTAssertFalse(doneFrame.intersects(back), "Done does not overlap Back's target.")
            XCTAssertFalse(doneFrame.intersects(primary), "Done does not overlap Preview my card.")
            XCTAssertGreaterThanOrEqual(back.height, 44)
            XCTAssertGreaterThanOrEqual(back.width, 44)
            XCTAssertGreaterThanOrEqual(primary.height, 60)
            XCTAssertLessThanOrEqual(back.maxY, keyboard.minY + 1, "The actions stay above the keyboard.")
            XCTAssertTrue(field.isHittable, "\(field.identifier) is visible while focused.")
            XCTAssertLessThanOrEqual(field.frame.maxY, primary.minY, "\(field.identifier) is not behind the actions.")
            done.tap()
            XCTAssertTrue(waitForNoKeyboard(app), "Done closes the keyboard.")
            hold(0.6)
            XCTAssertEqual(guest.headline.label, "A little about you.", "Done does not also go back.")
            XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), "Alex", "Done keeps the draft.")
            XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), Self.opener)
        }

        guest.opener.tap()
        XCTAssertTrue(waitForKeyboard(app))
        hold(0.8)
        let back = guest.secondary.frame
        let done = keyboardDoneButton(app)
        let corner = CGPoint(x: back.maxX - 3, y: back.maxY - 3)
        attachNote("Tap at Back's bottom-right corner \(String(format: "{%.2f, %.2f}", corner.x, corner.y)) with the keyboard open; "
            + "Done \(NSCoder.string(for: done.exists ? done.frame : .null)).")
        XCTAssertFalse(done.exists && done.frame.contains(corner), "Back's corner is not under Done.")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: corner.x, dy: corner.y)).tap()
        let pass = PassElements(app: app)
        XCTAssertTrue(pass.headline.waitForExistence(timeout: 5), "A tap at Back's bottom-right corner goes back to the Pass.")
        waitForAbsence(guest.headline)
        XCTAssertFalse(guest.headline.exists, "The editor has closed.")
        hold(0.6)
        capture("guest-list-keyboard-back-corner-\(width)pt", app)
    }

    /// Starts from the DEBUG fixture `guest-list`. A hardware keyboard: Tab moves from the name to
    /// the introduction, Shift-Tab back, and Tab in the introduction leaves it; no tab character
    /// is typed into either field. Runs in its own xcodebuild pass with the other tests that send
    /// hardware key events, after every test that needs the on-screen keyboard.
    func testHardwareTabAndShiftTabMoveBetweenFields() throws {
        let app = launch(fixture: "guest-list")
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Alex")

        app.typeKey(.tab, modifierFlags: [])
        let tabbed = waitForFocus(guest.opener)
        app.typeKey(.tab, modifierFlags: .shift)
        let shiftTabbed = waitForFocus(guest.name)
        app.typeKey(.tab, modifierFlags: [])
        _ = waitForFocus(guest.opener)
        app.typeKey(.tab, modifierFlags: [])
        hold(0.8)
        let name = fieldText(guest.name, placeholder: "What should we call you?")
        let opener = fieldText(guest.opener, placeholder: "A good hello starts with…")
        attachNote("Hardware keys: Tab name→opener \(tabbed); Shift-Tab opener→name \(shiftTabbed); "
            + "name \(name.debugDescription), opener \(opener.debugDescription).")
        capture("guest-list-hardware-tab", app)
        XCTAssertTrue(tabbed, "Tab moves from the name to the opener.")
        XCTAssertTrue(shiftTabbed, "Shift-Tab moves from the opener back to the name.")
        XCTAssertEqual(name, "Alex", "Tab types nothing into the name.")
        XCTAssertEqual(opener, "", "Tab types nothing into the opener.")
        let left = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == false"), object: guest.opener)
        XCTAssertEqual(XCTWaiter.wait(for: [left], timeout: 3), .completed, "Tab in the opener leaves it.")
    }

    // MARK: - Rapid taps

    /// The real route. A rapid double tap acts once and never skips a route: Continue preview
    /// opens the editor once; Preview my card does not also end the preview; Edit introduction
    /// does not also press Back; Back on the card stops at the editor; Back on the editor stops at
    /// the complete Pass and does not also leave it.
    func testRepeatedTapsNeverDuplicateOrSkipARoute() throws {
        let app = launchWelcome()
        let pass = openCompletedPass(app)
        let guest = GuestListElements(app: app)

        pass.primary.doubleTap()
        waitForHeadline(guest, "A little about you.")
        hold(1.0)
        XCTAssertEqual(guest.headline.label, "A little about you.", "A double tap on Continue preview opens the editor once.")
        guest.name.tap()
        guest.name.typeText("Alex")
        tapKeyboardDone(app)
        XCTAssertTrue(waitForNoKeyboard(app))
        hold(0.6)

        guest.primary.doubleTap()
        waitForHeadline(guest, "Your first hello.")
        hold(1.0)
        XCTAssertFalse(app.descendants(matching: .any)["wristband.headline"].exists, "A double tap on Preview my card does not also open the Wristband.")
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(guest.headline.label, "Your first hello.")

        guest.secondary.doubleTap()
        waitForHeadline(guest, "A little about you.")
        hold(1.0)
        XCTAssertTrue(guest.headline.exists, "A double tap on Edit introduction stops at the editor.")
        XCTAssertFalse(pass.headline.exists && pass.headline.isHittable, "It does not also press the editor's Back.")

        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(0.8)
        guest.back.doubleTap()
        waitForHeadline(guest, "A little about you.")
        hold(1.0)
        XCTAssertTrue(guest.headline.exists, "A double tap on Back on the card stops at the editor.")

        guest.secondary.doubleTap()
        waitForPass(pass, "Demo complete.")
        hold(1.2)
        XCTAssertEqual(pass.headline.label, "Demo complete.", "A double tap on Back stops at the complete Pass.")
        XCTAssertFalse(app.descendants(matching: .any)["birthday.headline"].exists, "It does not also leave the Pass.")
        capture("guest-list-after-double-back", app)

        // A single Back is one step: the Guest List was pushed once.
        pass.primary.tap()
        waitForHeadline(guest, "A little about you.")
        XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), "Alex")
        guest.back.tap()
        waitForPass(pass, "Demo complete.")
    }

    // MARK: - Memory only, and nothing conferred

    /// The draft lasts for the run and no longer: a relaunch through the real route finds the
    /// editor empty. Nothing on any Guest List screen claims verification, visibility, presence
    /// or a later chapter, and no permission is asked. The card's Continue preview opens the
    /// Wristband and its Back returns to the same card.
    func testRelaunchResetsTheDraftAndNothingIsConferred() throws {
        var app = launch(fixture: "guest-list-card")
        var guest = GuestListElements(app: app)
        waitForHeadline(guest, "Your first hello.")
        assertCard(guest, label: Self.alexCard)
        assertNothingConferred(app)
        guest.primary.tap()
        let wristband = app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch
        XCTAssertTrue(wristband.waitForExistence(timeout: 5), "Continue preview on the card opens the Wristband.")
        app.buttons["wristband.back"].tap()
        waitForHeadline(guest, "Your first hello.")
        assertCard(guest, label: Self.alexCard)
        guest.secondary.tap()
        waitForHeadline(guest, "A little about you.")
        assertEditor(guest, name: "Alex", opener: Self.opener, selected: [true, true, true])
        assertNothingConferred(app)

        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10), "A fresh launch starts at Welcome.")
        let pass = openCompletedPass(app)
        pass.primary.tap()
        guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        hold(0.6)
        assertEditor(guest, name: "", opener: "", selected: [false, false, false])
        XCTAssertFalse(guest.primary.isEnabled)
        capture("guest-list-after-relaunch-empty", app)
        assertNothingConferred(app)
    }

    // MARK: - Reduce Motion and largest text

    /// Starts from the DEBUG fixture `guest-list-filled` with the app-level preview flag
    /// `-ProximeetReduceMotionPreview YES` (not the system setting): the card appears in its
    /// place without moving.
    func testReduceMotionPreviewKeepsTheCardStationary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "guest-list-filled", "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        hold(0.8)
        capture("guest-list-reduce-motion-preview-editor", app)
        guest.primary.tap()
        hold(0.2)
        let early = RenderedScreen(app)?.inkRows(in: Self.paperColumn, where: Self.ivory)?.top
        hold(1.0)
        capture("guest-list-reduce-motion-preview-card", app)
        let settled = RenderedScreen(app)?.inkRows(in: Self.paperColumn, where: Self.ivory)?.top
        attachNote("Reduce Motion preview: paper top \(early.map { String(format: "%.2f", $0) } ?? "not drawn") at 0.2 s, \(settled.map { String(format: "%.2f", $0) } ?? "not drawn") at 1.2 s.")
        softly {
            XCTAssertNotNil(settled, "The card is drawn.")
            if let early, let settled {
                XCTAssertEqual(early, settled, accuracy: 0.34, "Reduce Motion keeps the card stationary.")
                XCTAssertEqual(settled, 386.5, accuracy: 1.5, "The card rests at the approved place.")
            }
        }
    }

    /// Starts from the DEBUG fixture `guest-list-filled` at the largest accessibility text size:
    /// the DEMO PROFILE label is drawn whole, the text grows and reflows, every field and action
    /// is reachable by scrolling, and the card grows to hold its text.
    func testLargestTextReflowsAndKeepsEverythingReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ProximeetFixture", "guest-list-filled",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        let guest = GuestListElements(app: app)
        waitForHeadline(guest, "A little about you.")
        hold(1.5)
        XCTAssertGreaterThan(guest.headline.frame.height, 104 + 10, "The largest text size must be applied.")
        capture("guest-list-largest-text-top", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let clusters = shot.inkColumns(in: CGRect(x: 150, y: 50, width: 290, height: 110), where: Self.cyan)
            let tallest = clusters.map { $0.height }.max() ?? 0
            attachNote("Largest text: DEMO PROFILE glyph clusters (points): "
                + clusters.map { String(format: "%.1f-%.1f h %.1f", $0.minX, $0.maxX, $0.height) }.joined(separator: ", ") + ".")
            XCTAssertGreaterThanOrEqual(clusters.count, 8, "DEMO PROFILE should be drawn as its letters.")
            XCTAssertFalse(clusters.contains { $0.height < tallest * 0.5 }, "The DEMO PROFILE label is truncated: an ellipsis is drawn.")
        }
        XCTAssertTrue(guest.back.isHittable, "Back is reachable at the top.")
        XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), "Alex")
        for element in [guest.name, guest.opener, guest.count, guest.coffee, guest.liveMusic, guest.outdoors, guest.boundary] {
            XCTAssertTrue(scrollIntoView(element, guest, app), "\(element.identifier) is reachable by scrolling.")
            XCTAssertGreaterThanOrEqual(element.frame.height, element.elementType == .button ? 44 : 1)
        }
        XCTAssertTrue(guest.primary.isHittable && guest.secondary.isHittable, "Both actions stay on screen.")
        hold(0.8)
        capture("guest-list-largest-text-editor-bottom", app)

        guest.primary.tap()
        waitForHeadline(guest, "Your first hello.")
        hold(1.2)
        capture("guest-list-largest-text-card-top", app)
        XCTAssertEqual(guest.card.label, Self.alexCard)
        XCTAssertGreaterThan(guest.card.frame.height, 256.46 + 40, "The card grows with its text.")
        // Scrolled until the card's foot is on screen, above the actions.
        XCTAssertTrue(scrollIntoView(guest.card, guest, app, footOnly: true), "The card's foot is reachable by scrolling.")
        hold(0.6)
        capture("guest-list-largest-text-card", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let card = guest.card.frame
            let visibleBottom = guest.primary.frame.minY - 25
            XCTAssertLessThan(card.maxY, visibleBottom, "The card's foot is on screen for this check.")
            let column = Self.textColumn(of: card).intersection(CGRect(x: 0, y: 70, width: 440, height: max(1, visibleBottom - 70)))
            if let ink = shot.inkRows(in: column, where: Self.black) {
                XCTAssertLessThanOrEqual(ink.bottom, card.maxY - 24, "The text ends on the paper, above its holder.")
            } else {
                XCTFail("The card's text is not drawn.")
            }
        }
        XCTAssertTrue(scrollIntoView(guest.context, guest, app), "The context line is reachable by scrolling.")
        XCTAssertTrue(scrollIntoView(guest.boundary, guest, app), "The boundary sentence is reachable by scrolling.")
        XCTAssertTrue(guest.primary.isHittable && guest.secondary.isHittable)
        capture("guest-list-largest-text-card-bottom", app)
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
    private func openCompletedPass(_ app: XCUIApplication) -> PassElements {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 5), "More options should offer the demo.")
        demo.tap()
        let birthday = app.descendants(matching: .any)["birthday.headline"]
        XCTAssertTrue(birthday.waitForExistence(timeout: 5), "Birthday should open.")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "12")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "May")
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: true), "12 May 1997 should enable Continue.")
        hold(0.6)
        proceed.tap()
        let pass = PassElements(app: app)
        waitForPass(pass, "Your next chapter.")
        hold(0.6)
        pass.primary.tap()
        waitForPass(pass, "Demo in progress.")
        hold(0.6)
        pass.primary.tap()
        waitForPass(pass, "Demo complete.")
        XCTAssertEqual(pass.primary.label, "Continue preview")
        return pass
    }

    private func waitForPass(_ pass: PassElements, _ headline: String) {
        XCTAssertTrue(pass.headline.waitForExistence(timeout: 5), "Pass should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", headline), object: pass.headline)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 5), .completed, "Expected “\(headline)”, found “\(pass.headline.label)”.")
    }

    private func waitForHeadline(_ guest: GuestListElements, _ headline: String) {
        XCTAssertTrue(guest.headline.waitForExistence(timeout: 5), "The Guest List should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", headline), object: guest.headline)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 5), .completed, "Expected “\(headline)”, found “\(guest.headline.label)”.")
    }

    // MARK: - Assertions

    private func assertEditor(_ guest: GuestListElements, name: String, opener: String, selected: [Bool]) {
        XCTAssertEqual(guest.headline.label, "A little about you.")
        XCTAssertEqual(guest.support.label, "Give your hello a starting point.")
        XCTAssertEqual(fieldText(guest.name, placeholder: "What should we call you?"), name)
        XCTAssertEqual(fieldText(guest.opener, placeholder: "A good hello starts with…"), opener)
        XCTAssertEqual(guest.count.label, "\(opener.count) of 120 characters")
        XCTAssertEqual([guest.coffee, guest.liveMusic, guest.outdoors].map(\.label), ["Coffee", "Live music", "Outdoors"])
        XCTAssertEqual([guest.coffee, guest.liveMusic, guest.outdoors].map(\.isSelected), selected)
        XCTAssertEqual(guest.interestsLabel.label, "Interests, optional, up to 3")
        XCTAssertEqual(guest.primary.label, "Preview my card")
        XCTAssertEqual(guest.secondary.label, "Back")
        assertEveryState(guest)
    }

    private func assertCard(_ guest: GuestListElements, label: String) {
        XCTAssertEqual(guest.headline.label, "Your first hello.")
        XCTAssertEqual(guest.support.label, "A small card. A real starting point.")
        XCTAssertEqual(guest.card.label, label)
        XCTAssertEqual(guest.context.label, "Your introduction, ready to edit.")
        XCTAssertEqual(guest.primary.label, "Continue preview")
        XCTAssertTrue(guest.primary.isEnabled)
        XCTAssertEqual(guest.secondary.label, "Edit introduction")
        assertEveryState(guest)
    }

    /// DEMO PROFILE and the visibility boundary on every state; 44-pt Back and secondary action,
    /// a 60-pt primary action, 44-pt chips.
    private func assertEveryState(_ guest: GuestListElements) {
        XCTAssertEqual(guest.demoBadge.label, "Demo profile")
        XCTAssertEqual(guest.boundary.label, Self.boundary)
        XCTAssertGreaterThanOrEqual(guest.back.frame.height, 44)
        XCTAssertGreaterThanOrEqual(guest.back.frame.width, 44)
        XCTAssertGreaterThanOrEqual(guest.secondary.frame.height, 44)
        XCTAssertGreaterThanOrEqual(guest.primary.frame.height, 60)
        if guest.coffee.exists {
            for chip in [guest.coffee, guest.liveMusic, guest.outdoors] {
                XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
                XCTAssertGreaterThanOrEqual(chip.frame.width, 44)
            }
        }
    }

    private func assertNothingConferred(_ app: XCUIApplication) {
        let words = ["verified", "verification complete", "access granted", "checked in", "check in", "you're visible",
                     "you’re visible", "now visible", "nearby", "matched", "online now", "member", "discoverable"]
        let predicate = NSPredicate(format: words.map { _ in "label CONTAINS[c] %@" }.joined(separator: " OR "), argumentArray: words)
        XCTAssertEqual(app.descendants(matching: .any).matching(predicate).count, 0, "No verified, visible, present or member wording.")
        XCTAssertEqual(app.alerts.count, 0, "No permission or provider prompt appeared.")
        XCTAssertFalse(app.descendants(matching: .any)["wristband.headline"].exists, "No Wristband over the Guest List.")
        XCTAssertFalse(app.descendants(matching: .any)["signal.confirm"].exists, "No later chapter is reached.")
    }

    /// The focused field, both actions and Back are visible and hittable with the keyboard open.
    private func assertReachableAboveKeyboard(_ app: XCUIApplication, _ guest: GuestListElements, field: XCUIElement) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else {
            XCTFail("No keyboard is showing.")
            return
        }
        hold(0.8)
        let done = keyboardDoneButton(app)
        let doneFrame = done.exists ? done.frame : .null
        attachNote(String(format: "Keyboard top %.1f; Done %@; %@ %.1f-%.1f; primary %.1f-%.1f; secondary %.1f-%.1f.",
                          keyboard.frame.minY, NSCoder.string(for: doneFrame), field.identifier, field.frame.minY, field.frame.maxY,
                          guest.primary.frame.minY, guest.primary.frame.maxY, guest.secondary.frame.minY, guest.secondary.frame.maxY))
        XCTAssertTrue(field.isHittable, "\(field.identifier) is visible while focused.")
        XCTAssertLessThanOrEqual(field.frame.maxY, guest.primary.frame.minY, "\(field.identifier) is not behind the actions.")
        XCTAssertGreaterThanOrEqual(field.frame.minY, 44, "\(field.identifier) is not under the status bar.")
        XCTAssertLessThanOrEqual(guest.secondary.frame.maxY, keyboard.frame.minY + 1, "The actions stay above the keyboard.")
        for action in [guest.primary, guest.secondary] {
            let centre = CGPoint(x: action.frame.midX, y: action.frame.midY)
            XCTAssertFalse(doneFrame.contains(centre), "Done does not cover \(action.label).")
        }
        XCTAssertTrue(guest.primary.isHittable, "Preview my card stays reachable.")
        XCTAssertTrue(guest.secondary.isHittable, "Back stays reachable.")
    }

    // MARK: - Fields and keyboard

    /// A text field's text; accessibility reports the placeholder when the field is empty.
    private func fieldText(_ field: XCUIElement, placeholder: String) -> String {
        let value = (field.value as? String) ?? ""
        return value == placeholder ? "" : value
    }

    /// Replaces `field`'s text with `text` through the system pasteboard (a paste, not typing: the
    /// keyboard's own substitutions play no part). The field is emptied with the delete key, then
    /// pasted into from the edit menu, a touch interaction; ⌘V is the fallback. The tests that can
    /// reach the fallback run after every test that needs the on-screen keyboard.
    private func paste(_ text: String, into field: XCUIElement, placeholder: String, _ app: XCUIApplication) {
        UIPasteboard.general.string = text
        let end = field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85))
        end.tap()
        _ = waitForFocus(field)
        // Right-to-left text ends at the left edge, so empty the field from either side.
        let start = field.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.85))
        for (pass, edge) in [end, start].enumerated() {
            let current = fieldText(field, placeholder: placeholder)
            guard !current.isEmpty else { break }
            if pass > 0 {
                edge.tap()
            }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.utf16.count + 2))
        }
        XCTAssertEqual(fieldText(field, placeholder: placeholder), "", "\(field.identifier) is empty before the paste.")
        hold(0.6)
        end.tap()
        let menuPaste = app.menuItems["Paste"]
        if menuPaste.waitForExistence(timeout: 3) {
            menuPaste.tap()
        } else {
            attachNote("No edit-menu Paste appeared; pasted with ⌘V.")
            field.typeKey("v", modifierFlags: .command)
        }
        allowPasteIfAsked(app)
        XCTAssertTrue(valueEquals(field, text), "The paste arrived in \(field.identifier).")
    }

    private func valueEquals(_ field: XCUIElement, _ text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: field)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    /// The edit menu's Paste does not ask; ⌘V might. No waiting when nothing asks.
    private func allowPasteIfAsked(_ app: XCUIApplication) {
        for candidate in [app.buttons["Allow Paste"], XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Paste"]]
        where candidate.exists {
            candidate.tap()
        }
    }

    private func waitForFocus(_ field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter.wait(for: [focused], timeout: 5) == .completed
    }

    private func waitForKeyboard(_ app: XCUIApplication) -> Bool {
        app.keyboards.firstMatch.waitForExistence(timeout: 5)
    }

    private func waitForNoKeyboard(_ app: XCUIApplication) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        return XCTWaiter.wait(for: [gone], timeout: 5) == .completed
    }

    /// The toolbar's Done above the keyboard (on iOS 26 a floating button, not a toolbar row).
    private func keyboardDoneButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "guestList.keyboardDone", "Done")).firstMatch
    }

    private func tapKeyboardDone(_ app: XCUIApplication) {
        let done = keyboardDoneButton(app)
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Done is offered above the keyboard.")
        done.tap()
    }

    private func tapKeyboardDoneIfShown(_ app: XCUIApplication) {
        if app.keyboards.firstMatch.exists {
            tapKeyboardDone(app)
            _ = waitForNoKeyboard(app)
        }
    }

    /// Scrolls with short, momentum-free drags until `element` lies between the status bar and the
    /// top of the action bar: hittability alone counts an element hidden behind the opaque bar.
    /// `footOnly` checks just the lower edge, for an element taller than the visible area.
    private func scrollIntoView(_ element: XCUIElement, _ guest: GuestListElements, _ app: XCUIApplication,
                                footOnly: Bool = false) -> Bool {
        // In the 32-pt margin, left of every field and chip, so a drag never lands on a control.
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.3))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.55))
        for _ in 0..<14 {
            let frame = element.frame, top: CGFloat = 62, bottom = guest.primary.frame.minY - 25
            let low = frame.maxY > bottom, high = footOnly ? frame.maxY < top + 40 : frame.minY < top
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

    private func waitFor(_ element: XCUIElement, enabled: Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitFor(_ element: XCUIElement, label: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    private func waitForAbsence(_ element: XCUIElement) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        _ = XCTWaiter.wait(for: [gone], timeout: 5)
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

    /// With `PROXIMEET_SHORT_HOLDS=1` (the Wristband review, which records none of these tests) a
    /// hold is at most 0.6 s: long enough for every 220 ms change to settle, without the pauses
    /// that only a recording needs.
    private func hold(_ seconds: TimeInterval) {
        let short = ProcessInfo.processInfo.environment["PROXIMEET_SHORT_HOLDS"] == "1"
        let duration = short ? min(seconds, 0.6) : seconds
        let done = expectation(description: "Hold so the recording shows this state")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { done.fulfill() }
        wait(for: [done], timeout: duration + 1)
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
    // Accessibility values do not prove anything was drawn, so these read the screenshot, in
    // points at 440 × 956. The approved board (docs/design/guest-list-approved/reference/
    // guest-list-review.png) is at 1× with its three frames at x 32 / 520 / 1008, y 246. Text
    // anchors are the glyphs' own extents on Figma's line boxes, from the bundled Manrope faces'
    // outlines (they agree with the board's rows to within its 1-pt pixels); the fields, chips,
    // actions and the paper are the board's own rows.

    private static let white: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 200 }
    private static let grey: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 120 }
    private static let black: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 50 }
    private static let cyan: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 120 && g > 150 && b > 160 }
    private static let ivory: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 200 && g > 195 && b > 180 }
    /// #7A8585, the fields' and unselected chips' stroke.
    private static let stroke: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 95 && r < 140 && g > 105 && g < 150 && b > 105 && b < 150 }
    /// #1F2424, the disabled primary action.
    private static let disabledFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 25 && r <= 40 && g >= 30 && g <= 45 && b >= 30 && b <= 45 }
    /// #737D7A, the disabled primary action's label.
    private static let disabledText: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 95 && r < 135 && g > 105 && g < 145 && b > 100 && b < 140 }
    /// The card's rule: #050606 at 20 % on the paper.
    private static let rule: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 215 && min(r, g, b) > 150 }

    private static let paperColumn = CGRect(x: 200, y: 360, width: 2, height: 40)

    /// The card's writing column, from below the clip to 16 pt above the card's foot. The art has
    /// near-black rows only in the holder, 12-13 pt and 1-2 pt above the foot (the same in the
    /// grown card), so black here is text. The text itself ends 32.46 pt above the foot.
    private static func textColumn(of card: CGRect) -> CGRect {
        CGRect(x: card.minX + 37, y: card.minY + 60, width: 303, height: max(1, card.height - 76))
    }

    /// The paper's writing area (69 to 224 pt on the approved card), clear of its edges.
    private static func writingArea(of card: CGRect) -> CGRect {
        CGRect(x: card.minX + 30, y: card.minY + 69, width: card.width - 60, height: 155)
    }

    private static let headerAnchors: [Anchor] = [
        Anchor("Back arrow", CGRect(x: 34, y: 55, width: 24, height: 60), white, top: 80.0, bottom: 92.0),
        Anchor("Wordmark", CGRect(x: 84, y: 55, width: 150, height: 60), white, top: 78.31, bottom: 94.76),
        Anchor("DEMO PROFILE", CGRect(x: 295, y: 76, width: 110, height: 20), cyan, top: 82.13, bottom: 90.38),
        Anchor("Support", CGRect(x: 32, y: 275, width: 376, height: 30), grey, top: 280.37, bottom: 296.21),
    ]

    private static let editorHeadline: [Anchor] = [
        Anchor("Headline", CGRect(x: 32, y: 150, width: 376, height: 118), white, top: 163.02, bottom: 261.66),
        Anchor("Name label", CGRect(x: 32, y: 336, width: 120, height: 28), white, top: 346.61, bottom: 358.37),
        Anchor("Name field", CGRect(x: 20, y: 366, width: 400, height: 70), stroke, top: 372.0, bottom: 428.0),
        Anchor("Introduction label", CGRect(x: 32, y: 440, width: 376, height: 28), white, top: 448.58, bottom: 465.97),
        Anchor("Introduction field", CGRect(x: 20, y: 470, width: 400, height: 100), stroke, top: 476.0, bottom: 564.0),
        Anchor("Interests label", CGRect(x: 32, y: 600, width: 376, height: 30), grey, top: 611.07, bottom: 624.72),
        Anchor("Boundary", CGRect(x: 32, y: 735, width: 376, height: 60), grey, top: 745.53, bottom: 784.97),
        Anchor("Back label", CGRect(x: 120, y: 880, width: 200, height: 45), white, top: 896.61, bottom: 908.37),
    ]

    private static let emptyEditorAnchors: [Anchor] = editorHeadline + [
        Anchor("Name placeholder", CGRect(x: 45, y: 380, width: 300, height: 40), grey, top: 393.66, bottom: 411.21),
        Anchor("Introduction placeholder", CGRect(x: 45, y: 484, width: 340, height: 32), grey, top: 495.02, bottom: 511.85),
        Anchor("Count 0 / 120", CGRect(x: 300, y: 568, width: 110, height: 22), grey, top: 575.78, bottom: 584.78),
        Anchor("Chips", CGRect(x: 20, y: 630, width: 400, height: 56), stroke, top: 636.0, bottom: 680.0),
        Anchor("Coffee label", CGRect(x: 60, y: 640, width: 60, height: 34), white, top: 653.07, bottom: 663.57),
    ]

    private static let filledEditorAnchors: [Anchor] = editorHeadline + [
        Anchor("Name value", CGRect(x: 45, y: 380, width: 300, height: 40), white, top: 393.66, bottom: 407.16),
        Anchor("Introduction value", CGRect(x: 45, y: 484, width: 340, height: 32), white, top: 495.02, bottom: 511.85),
        Anchor("Count 38 / 120", CGRect(x: 300, y: 568, width: 110, height: 22), grey, top: 575.78, bottom: 584.78),
        Anchor("Chips", CGRect(x: 20, y: 630, width: 400, height: 56), cyan, top: 636.0, bottom: 680.0),
        Anchor("Coffee label", CGRect(x: 60, y: 640, width: 60, height: 34), black, top: 653.07, bottom: 663.57),
    ]

    private static func editorFooterAnchors(enabled: Bool) -> [Anchor] {
        enabled
            ? [Anchor("Primary", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812.0, bottom: 872.0),
               Anchor("Primary label", CGRect(x: 100, y: 825, width: 240, height: 35), black, top: 834.75, bottom: 852.21)]
            : [Anchor("Primary (disabled)", CGRect(x: 60, y: 800, width: 320, height: 80), disabledFill, top: 812.0, bottom: 872.0),
               Anchor("Primary label (disabled)", CGRect(x: 100, y: 825, width: 240, height: 35), disabledText, top: 834.75, bottom: 852.21)]
    }

    /// The card of the fictional example (Figma 36:204). Its opener wraps at the 303-pt column
    /// after "good"; Figma breaks it by hand after "coffee", so only the first line is compared.
    private static let cardAnchors: [Anchor] = [
        Anchor("Headline", CGRect(x: 32, y: 150, width: 376, height: 110), white, top: 163.02, bottom: 250.86),
        Anchor("Paper top", paperColumn, ivory, top: 386.5, tolerance: 1.5),
        // The holder lip's highlight (source rows 952-953) is the last ivory row at 3x: 617.5. The 1x
        // board blurs it away (614).
        Anchor("Paper bottom", CGRect(x: 200, y: 590, width: 2, height: 50), ivory, bottom: 617.5, tolerance: 1.5),
        Anchor("Initial disc", CGRect(x: 55, y: 436, width: 56, height: 56), black, top: 442.0, bottom: 486.0),
        Anchor("Initial", CGRect(x: 70, y: 448, width: 26, height: 32), white, top: 455.06, bottom: 469.46),
        Anchor("Name", CGRect(x: 114, y: 436, width: 250, height: 50), black, top: 447.14, bottom: 475.64),
        Anchor("Opener, first line", CGRect(x: 58, y: 500, width: 310, height: 26), black, top: 505.66, bottom: 523.48),
        Anchor("Rule", CGRect(x: 70, y: 556, width: 280, height: 10), rule, top: 561.0, bottom: 562.0),
        Anchor("Interests", CGRect(x: 58, y: 566, width: 320, height: 34), black, top: 578.07, bottom: 588.57),
        Anchor("Context", CGRect(x: 32, y: 655, width: 376, height: 30), grey, top: 664.53, bottom: 679.97),
        Anchor("Boundary", CGRect(x: 32, y: 735, width: 376, height: 60), grey, top: 745.53, bottom: 784.97),
        Anchor("Primary", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812.0, bottom: 872.0),
        Anchor("Primary label", CGRect(x: 100, y: 825, width: 240, height: 35), black, top: 834.66, bottom: 852.21),
        Anchor("Edit introduction label", CGRect(x: 120, y: 880, width: 200, height: 45), white, top: 896.49, bottom: 908.37),
    ]

    private func softlyMeasured(_ app: XCUIApplication, _ state: String, anchors: [Anchor]) {
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
            attachNote("\(state): rendered anchors (points): " + lines.joined(separator: "; ") + ".")
        }
    }
}

/// The Guest List's elements, by identifier.
@MainActor
private struct GuestListElements {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var headline: XCUIElement { element("guestList.headline") }
    var support: XCUIElement { element("guestList.support") }
    var name: XCUIElement { app.textFields["guestList.name"] }
    var opener: XCUIElement { element("guestList.opener") }
    var count: XCUIElement { element("guestList.count") }
    var nameHelp: XCUIElement { element("guestList.nameHelp") }
    var openerHelp: XCUIElement { element("guestList.openerHelp") }
    var interestsLabel: XCUIElement { element("guestList.interestsLabel") }
    var coffee: XCUIElement { app.buttons["guestList.interest.coffee"] }
    var liveMusic: XCUIElement { app.buttons["guestList.interest.liveMusic"] }
    var outdoors: XCUIElement { app.buttons["guestList.interest.outdoors"] }
    var card: XCUIElement { element("guestList.card") }
    var context: XCUIElement { element("guestList.context") }
    var boundary: XCUIElement { element("guestList.boundary") }
    var demoBadge: XCUIElement { element("guestList.demoBadge") }
    var primary: XCUIElement { app.buttons["guestList.primary"] }
    var secondary: XCUIElement { app.buttons["guestList.secondary"] }
    var back: XCUIElement { app.buttons["guestList.back"] }
}

/// Pass's elements, by identifier.
@MainActor
private struct PassElements {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
    var exit: XCUIElement { app.buttons["pass.exit"] }
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

    /// Runs of adjacent pixel columns in `rect` (points) holding a pixel that passes `test` (a
    /// letter each, for widely set type), with each run's vertical ink extent, in points.
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

    /// How many pixel rows in `rect` hold an unbroken horizontal run of at least `minimumLength`
    /// points of pixels passing `test` (a drawn rule).
    func longRuns(in rect: CGRect, minimumLength: CGFloat, where test: (UInt8, UInt8, UInt8) -> Bool) -> Int {
        guard let range = pixelRange(rect) else { return 0 }
        let needed = Int(minimumLength * scale)
        var rows = 0
        for y in range.y0..<range.y1 {
            var run = 0, best = 0
            for x in range.x0..<range.x1 {
                run = passes(x, y, test) ? run + 1 : 0
                best = max(best, run)
            }
            if best >= needed { rows += 1 }
        }
        return rows
    }
}
