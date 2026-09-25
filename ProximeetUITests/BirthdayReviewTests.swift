import XCTest

/// Runtime review of the approved Birthday (chapter 02), driven through the real route:
/// Welcome → More options → "Continue the demo (no account)" → Birthday.
///
/// Skipped unless the test runner's environment has `PROXIMEET_BIRTHDAY_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1` to xcodebuild), so other runs of the UI test
/// target are unchanged. Real taps and wheel adjustments only; no fixture skips a step.
@MainActor
final class BirthdayReviewTests: XCTestCase {
    private static let reviewFlag = "PROXIMEET_BIRTHDAY_REVIEW"
    private static let emptyGuidance = "Select your day, month and year."
    private static let adultGuidance = "Check your date before continuing."
    private static let underageGuidance = "You need to be 18 or older"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Birthday review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        // Evidence for birthday_review.sh that the flag reached this runner process.
        print("BIRTHDAY_REVIEW_FLAG_SEEN \(name)")
    }

    /// The recorded walkthrough: the demo route, wheel entry of an adult date, Continue's
    /// notice, correction to an under-18 date, Back to a settled Welcome, and the draft kept
    /// on return.
    func testWalkthroughEntryCorrectionContinueBack() throws {
        let app = launchWelcome()
        hold(2.0) // Welcome's pose study settles
        openBirthday(app)

        let screen = BirthdayElements(app: app)
        XCTAssertEqual(screen.wheelValues, ["Not set", "Not set", "Not set"], "The date must start unset.")
        XCTAssertFalse(screen.continueButton.isEnabled, "Continue must start disabled.")
        XCTAssertEqual(screen.guidance.label, Self.emptyGuidance)
        capture("birthday-empty", app)
        hold(0.8)

        screen.wheel(0).adjust(toPickerWheelValue: "12")
        screen.wheel(1).adjust(toPickerWheelValue: "May")
        XCTAssertFalse(screen.continueButton.isEnabled, "A partial date must not enable Continue.")
        screen.wheel(2).adjust(toPickerWheelValue: "1997")
        waitFor(screen.continueButton, enabled: true, "Continue should enable for 12 May 1997.")
        XCTAssertEqual(screen.guidance.label, Self.adultGuidance)
        capture("birthday-adult", app)
        hold(0.8)

        screen.continueButton.tap()
        let notice = app.alerts["Pass is next."]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Continue should show the Pass-pending notice.")
        XCTAssertTrue(notice.staticTexts["This prototype stops here for now."].exists)
        capture("birthday-pass-notice", app)
        hold(0.8)
        notice.buttons["OK"].tap()
        waitForAbsence(notice)
        XCTAssertTrue(screen.headline.exists, "Continue must stay on Birthday.")

        screen.wheel(2).adjust(toPickerWheelValue: "2012")
        waitFor(screen.continueButton, enabled: false, "Correcting to 2012 must disable Continue.")
        XCTAssertTrue(screen.guidance.label.contains(Self.underageGuidance), "Under-18 guidance: \(screen.guidance.label)")
        capture("birthday-under18", app)
        hold(0.8)

        screen.backButton.tap()
        let welcomeButton = app.buttons["welcome.continueWithApple"]
        XCTAssertTrue(welcomeButton.waitForExistence(timeout: 5), "Back should return to Welcome.")
        waitForAbsence(screen.headline)
        hold(0.5)
        capture("back-to-welcome", app)
        hold(0.8)

        openBirthday(app)
        XCTAssertEqual(screen.wheelValues, ["12", "May", "2012"], "The draft should be kept within the demo run.")
        XCTAssertFalse(screen.continueButton.isEnabled)
        XCTAssertTrue(screen.guidance.label.contains(Self.underageGuidance))
        capture("birthday-returned-draft-kept", app)
        hold(0.8)
    }

    /// Typed entry: components carry over from the wheels, typing disables Continue until
    /// Done, Done dismisses the keyboard and checks the date, the wheels show the typed date,
    /// and an impossible date is refused with guidance.
    func testTypedEntryPreservesComponentsAndKeyboard() throws {
        let app = launchWelcome()
        openBirthday(app)
        let screen = BirthdayElements(app: app)

        screen.wheel(0).adjust(toPickerWheelValue: "12")
        XCTAssertFalse(screen.continueButton.isEnabled)
        screen.enterDateLink.tap()

        let day = screen.field("day"), month = screen.field("month"), year = screen.field("year")
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Typed entry should show labelled fields.")
        XCTAssertEqual(day.value as? String, "12", "The wheel's day must carry over to typed entry.")

        month.tap()
        month.typeText("5")
        year.tap()
        year.typeText("1997")
        XCTAssertFalse(screen.continueButton.isEnabled, "Typing must keep Continue disabled until Done.")
        capture("birthday-typed-keyboard", app)

        submitTyped(app, from: year)
        waitFor(screen.continueButton, enabled: true, "Done should check 12/5/1997 and enable Continue.")
        XCTAssertEqual(screen.guidance.label, Self.adultGuidance)
        capture("birthday-typed-adult", app)

        screen.useWheelsLink.tap()
        XCTAssertEqual(screen.wheelValues, ["12", "May", "1997"], "Wheels should show the typed date.")

        screen.enterDateLink.tap()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        replace(day, with: "31")
        replace(month, with: "4")
        XCTAssertFalse(screen.continueButton.isEnabled)
        submitTyped(app, from: month)
        waitFor(screen.continueButton, enabled: false, "31 April must not enable Continue.")
        XCTAssertTrue(screen.guidance.label.contains("That date doesn’t exist"), "Impossible-date guidance: \(screen.guidance.label)")
        capture("birthday-typed-impossible", app)

        replace(day, with: "12")
        replace(month, with: "5")
        replace(year, with: "2090")
        submitTyped(app, from: year)
        XCTAssertFalse(screen.continueButton.isEnabled)
        XCTAssertTrue(screen.guidance.label.contains("That date is in the future"), "Future-date guidance: \(screen.guidance.label)")
        capture("birthday-typed-future", app)
    }

    // MARK: - Helpers

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10))
        return app
    }

    private func openBirthday(_ app: XCUIApplication) {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 5), "More options should offer the demo.")
        demo.tap()
        XCTAssertTrue(BirthdayElements(app: app).headline.waitForExistence(timeout: 5), "Birthday should open.")
    }

    /// Submits typed entry with the keyboard toolbar's Done and checks that the keyboard is
    /// gone. The toolbar is shown with the software keyboard (and above a hardware keyboard);
    /// only if it is absent does return submit instead. The path used is recorded.
    private func submitTyped(_ app: XCUIApplication, from field: XCUIElement) {
        let keyboardWasShown = app.keyboards.firstMatch.exists
        let done = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "birthday.keyboardDone", "Done")
        ).firstMatch
        if done.waitForExistence(timeout: 3) {
            done.tap()
            waitForAbsence(app.keyboards.firstMatch)
            XCTAssertFalse(app.keyboards.firstMatch.exists, "Done should dismiss the keyboard.")
            waitForAbsence(done)
            XCTAssertFalse(done.exists, "Done should end typed entry's editing.")
            attachNote(keyboardWasShown
                ? "Submitted with the keyboard's Done; software keyboard dismissed."
                : "Submitted with the toolbar's Done; no software keyboard was shown (hardware keyboard).")
        } else {
            field.typeText("\n")
            attachNote("No Done button found; submitted with return. Keyboard shown: \(keyboardWasShown).")
        }
    }

    /// Clears a typed field and enters `text`. The tap lands at the trailing edge so the caret
    /// is after the existing digits.
    private func replace(_ field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(text)
    }

    private func waitFor(_ element: XCUIElement, enabled: Bool, _ message: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, message)
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

    private func hold(_ seconds: TimeInterval) {
        let done = expectation(description: "Hold so the recording shows this state")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 1)
    }
}

/// Birthday's accessible elements, by identifier.
@MainActor
private struct BirthdayElements {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["birthday.headline"] }
    var guidance: XCUIElement { app.staticTexts["birthday.guidance"] }
    var continueButton: XCUIElement { app.buttons["birthday.continue"] }
    var backButton: XCUIElement { app.buttons["birthday.back"] }
    var enterDateLink: XCUIElement { app.buttons["birthday.enterDate"] }
    var useWheelsLink: XCUIElement { app.buttons["birthday.useWheels"] }

    func wheel(_ index: Int) -> XCUIElement { app.pickerWheels.element(boundBy: index) }
    func field(_ id: String) -> XCUIElement { app.textFields["birthday.field.\(id)"] }

    var wheelValues: [String] {
        (0..<3).map { (wheel($0).value as? String) ?? "?" }
    }
}
