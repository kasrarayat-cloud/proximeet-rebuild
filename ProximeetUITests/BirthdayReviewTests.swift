import UIKit
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
        softly {
            assertWheelsVisible(app, neighbours: false, "Empty")
            assertNeighboursHidden(app, wheels: [0, 1, 2], "Empty")
            assertWindowEdgesClear(app, "Empty")
        }

        // One component alone: the other two stay unset in the model, the accessibility tree
        // and on screen, and Continue stays off.
        screen.wheel(0).adjust(toPickerWheelValue: "12")
        hold(0.6)
        XCTAssertEqual(screen.wheelValues, ["12", "Not set", "Not set"], "Choosing a day must leave month and year unset.")
        XCTAssertFalse(screen.continueButton.isEnabled, "A day alone must not enable Continue.")
        XCTAssertEqual(screen.guidance.label, Self.emptyGuidance)
        capture("birthday-day-only", app)
        softly {
            assertWheelsVisible(app, neighbours: false, "Day only")
            assertNeighboursVisible(app, wheels: [0], "Day only")
            assertNeighboursHidden(app, wheels: [1, 2], "Day only")
            assertWindowEdgesClear(app, "Day only")
        }
        hold(0.8)

        // A real finger drag. adjust(toPickerWheelValue:) turns wheels by accessibility
        // increments, never by touch, so this is the only step that turns a wheel the way a
        // finger does: the wheel moves, settles and draws its values, and the untouched wheels
        // stay unset and undrawn.
        let lane = screen.wheel(0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        lane.press(forDuration: 0.1, thenDragTo: lane.withOffset(CGVector(dx: 0, dy: -60)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        hold(1.0)
        XCTAssertNotEqual(screen.wheelValues[0], "12", "A finger drag should turn the Day wheel.")
        XCTAssertEqual(Array(screen.wheelValues.dropFirst()), ["Not set", "Not set"], "Turning the day must not set month or year.")
        XCTAssertFalse(screen.continueButton.isEnabled, "A day alone must not enable Continue.")
        capture("birthday-after-day-drag", app)
        softly {
            assertWheelsVisible(app, neighbours: false, "After a Day drag")
            assertNeighboursVisible(app, wheels: [0], "After a Day drag")
            assertNeighboursHidden(app, wheels: [1, 2], "After a Day drag")
            assertWindowEdgesClear(app, "After a Day drag")
        }
        screen.wheel(0).adjust(toPickerWheelValue: "12")
        hold(0.6)
        XCTAssertEqual(screen.wheelValues, ["12", "Not set", "Not set"])

        // A finger that turns the unset Month wheel less than half a row and lets go: the wheel
        // returns to its placeholder, perhaps without didSelectRow, and must again draw the
        // placeholder alone.
        let month = screen.wheel(1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        month.press(forDuration: 0.1, thenDragTo: month.withOffset(CGVector(dx: 0, dy: -20)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        hold(1.0)
        capture("birthday-after-month-release", app)
        softly {
            XCTAssertEqual(screen.wheelValues, ["12", "Not set", "Not set"], "A short Month drag must return to Not set.")
            assertNeighboursHidden(app, wheels: [1, 2], "After a Month drag back")
            assertWindowEdgesClear(app, "After a Month drag back")
        }

        screen.wheel(1).adjust(toPickerWheelValue: "May")
        XCTAssertFalse(screen.continueButton.isEnabled, "A partial date must not enable Continue.")
        screen.wheel(2).adjust(toPickerWheelValue: "1997")
        waitFor(screen.continueButton, enabled: true, "Continue should enable for 12 May 1997.")
        XCTAssertEqual(screen.guidance.label, Self.adultGuidance)
        capture("birthday-adult", app)
        hold(0.8)
        softly {
            assertWheelsVisible(app, neighbours: true, "12 May 1997")
            assertWindowEdgesClear(app, "12 May 1997")
            assertLayoutAnchors(app)
        }

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

    /// Rendered-screen checks record every failure (the test still fails) without stopping the
    /// walkthrough, so one miscalibrated check cannot cost the later states' evidence.
    private func softly(_ checks: () -> Void) {
        continueAfterFailure = true
        checks()
        continueAfterFailure = false
    }

    // MARK: - What is drawn on screen
    //
    // Accessibility strings do not prove that text was drawn (build 6ab6d70f passed every
    // accessibility check with every wheel value invisible), so these read the screenshot.
    // Thresholds are on each pixel's darkest channel. The console's glass is #1F2022 to
    // #262B2D, so under 45 is empty glass.

    /// Each wheel's selected value (or placeholder) must be drawn and, when asked, its previous
    /// value too. In Figma's column bands, build 6ab6df01's wheels lit 2,152 to 4,802 value
    /// pixels above 100 and 723 to 2,620 previous-value pixels above 45; the invisible wheels of
    /// build 6ab6d70f lit none in either band (their peak was 61).
    private func assertWheelsVisible(_ app: XCUIApplication, neighbours: Bool, _ state: String) {
        guard let shot = RenderedScreen(app), let wheels = wheelWindow(app, state) else { return }
        var counts: [String] = []
        for (index, name) in Self.wheelNames.enumerated() {
            let value = shot.lit(wheels.band(index, from: -20, to: 8), above: 100)
            counts.append("\(name) value \(value)")
            XCTAssertGreaterThan(value, 150, "\(state): the \(name) wheel's value is not visible on screen.")
            if neighbours {
                let hint = shot.lit(wheels.band(index, from: -66, to: -38), above: 45)
                counts.append("\(name) previous \(hint)")
                XCTAssertGreaterThan(hint, 60, "\(state): the \(name) wheel's previous value is not visible on screen.")
            }
        }
        attachNote("\(state): lit pixels per wheel band: " + counts.joined(separator: ", ") + ".")
    }

    /// A set wheel's previous and next values are drawn.
    private func assertNeighboursVisible(_ app: XCUIApplication, wheels indices: [Int], _ state: String) {
        guard let shot = RenderedScreen(app), let wheels = wheelWindow(app, state) else { return }
        var counts: [String] = []
        for index in indices {
            let name = Self.wheelNames[index]
            let above = shot.lit(wheels.band(index, from: -66, to: -38), above: 45)
            let below = shot.lit(wheels.band(index, from: 34, to: 62), above: 45)
            counts.append("\(name) previous \(above), next \(below)")
            XCTAssertGreaterThan(above, 60, "\(state): the \(name) wheel's previous value is not drawn.")
            XCTAssertGreaterThan(below, 60, "\(state): the \(name) wheel's next value is not drawn.")
        }
        attachNote("\(state): neighbouring values drawn: " + counts.joined(separator: "; ") + ".")
    }

    /// An unset wheel shows its placeholder alone: nothing is drawn above or below the lane.
    /// Build 6ab6df01 drew "1 Jan 1900" there, faintly (its darkest channel about 55).
    private func assertNeighboursHidden(_ app: XCUIApplication, wheels indices: [Int], _ state: String) {
        guard let shot = RenderedScreen(app), let wheels = wheelWindow(app, state) else { return }
        var counts: [String] = []
        for index in indices {
            let name = Self.wheelNames[index]
            let above = shot.lit(wheels.band(index, from: -75, to: -29), above: 45)
            let below = shot.lit(wheels.band(index, from: 29, to: 75), above: 45)
            counts.append("\(name) above \(above), below \(below)")
            XCTAssertLessThanOrEqual(above, 30, "\(state): the unset \(name) wheel draws a value above its placeholder.")
            XCTAssertLessThanOrEqual(below, 30, "\(state): the unset \(name) wheel draws a value below its placeholder.")
        }
        attachNote("\(state): lit pixels around unset placeholders: " + counts.joined(separator: "; ") + ".")
    }

    /// The date window shows no part-row at its top or bottom edge. Build 6ab6df01 showed the
    /// tops of the row after next between 595.3 and 596, against the window's bottom at 596.
    private func assertWindowEdgesClear(_ app: XCUIApplication, _ state: String) {
        guard let shot = RenderedScreen(app), let wheels = wheelWindow(app, state) else { return }
        let top = shot.lit(wheels.strip(from: -75, to: -69), above: 45)
        let bottom = shot.lit(wheels.strip(from: 69, to: 75), above: 45)
        attachNote("\(state): lit pixels in the window's edge strips: top \(top), bottom \(bottom).")
        XCTAssertLessThanOrEqual(top, 20, "\(state): a part-row shows at the top edge of the date window.")
        XCTAssertLessThanOrEqual(bottom, 20, "\(state): a part-row shows at the bottom edge of the date window.")
    }

    /// Rendered anchors at 440 × 956, in points, for 12 May 1997. Each expected value was
    /// measured on the approved board (docs/design/birthday-approved/reference/
    /// birthday-review.png, frames at 0.75 scale, so about ±0.7 pt) with the same threshold.
    /// For crisp shapes these are the spec's own values (Continue 812-872, Back arrow 80-92).
    private static let anchors: [Anchor] = [
        Anchor("Back arrow", box: CGRect(x: 34, y: 55, width: 24, height: 60), threshold: 200, top: 80.0, bottom: 92.0),
        Anchor("Wordmark", box: CGRect(x: 84, y: 55, width: 116, height: 60), threshold: 200, top: 74.7),
        Anchor("Headline", box: CGRect(x: 32, y: 130, width: 268, height: 160), threshold: 200, top: 164.0, bottom: 277.3),
        Anchor("Eligibility", box: CGRect(x: 32, y: 280, width: 268, height: 65), threshold: 120, top: 294.7),
        // Build 6ab6df01 drew these at 469.7, 517.0 and 565.7: the tolerances catch that.
        Anchor("Previous day", box: CGRect(x: 80, y: 446, width: 85, height: 46), threshold: 60, centre: 468.7, centreAccuracy: 0.75),
        Anchor("Selected day", box: CGRect(x: 80, y: 492, width: 85, height: 58), threshold: 60, centre: 516.0, centreAccuracy: 0.75),
        // The next row alone: the box stops 6 pt above the window's edge, which
        // assertWindowEdgesClear watches.
        Anchor("Next day", box: CGRect(x: 80, y: 550, width: 85, height: 40), threshold: 60, centre: 568.7, centreAccuracy: 1.5),
        Anchor("Enter date instead", box: CGRect(x: 32, y: 670, width: 240, height: 65), threshold: 200, top: 698.7),
        Anchor("Guidance", box: CGRect(x: 32, y: 735, width: 376, height: 65), threshold: 120, top: 745.3),
        Anchor("Continue", box: CGRect(x: 200, y: 790, width: 40, height: 100), threshold: 200, top: 812.0, bottom: 872.0),
    ]

    private func assertLayoutAnchors(_ app: XCUIApplication) {
        XCTAssertEqual(app.frame.size, CGSize(width: 440, height: 956), "Anchors are measured at 440 × 956.")
        guard app.frame.size == CGSize(width: 440, height: 956), let shot = RenderedScreen(app) else { return }
        var lines: [String] = []
        for anchor in Self.anchors {
            guard let ink = shot.inkRows(in: anchor.box, above: anchor.threshold) else {
                XCTFail("\(anchor.name): nothing drawn in \(anchor.box).")
                continue
            }
            lines.append(String(format: "%@ %.1f-%.1f", anchor.name, ink.top, ink.bottom))
            if let top = anchor.top {
                XCTAssertEqual(ink.top, top, accuracy: 1.0, "\(anchor.name): top edge drawn at \(ink.top), approved \(top).")
            }
            if let bottom = anchor.bottom {
                XCTAssertEqual(ink.bottom, bottom, accuracy: 1.0, "\(anchor.name): bottom edge drawn at \(ink.bottom), approved \(bottom).")
            }
            if let centre = anchor.centre {
                let drawn = (ink.top + ink.bottom) / 2
                XCTAssertEqual(drawn, centre, accuracy: anchor.centreAccuracy, "\(anchor.name): centre drawn at \(drawn), approved \(centre).")
            }
        }
        attachNote("Rendered anchors (points): " + lines.joined(separator: "; ") + ".")
    }

    private static let wheelNames = ["Day", "Month", "Year"]

    /// The date window, from the picker's centre (228, 521 at 440 × 956). XCUITest reports
    /// UIPickerView's own frame, 320 × 216 at (68, 413), wider than the clipped 308 × 150 window,
    /// so only its centre is used.
    private func wheelWindow(_ app: XCUIApplication, _ state: String) -> WheelWindow? {
        let identified = app.pickers["birthday.wheels"]
        let frame = (identified.exists ? identified : app.pickers.firstMatch).frame
        guard !frame.isEmpty else {
            XCTFail("\(state): the wheels have no frame.")
            return nil
        }
        return WheelWindow(frame: frame)
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

/// The date window, by offsets from the picker's centre (the lane's centre, 228 × 521 at
/// 440 × 956). Bands follow Figma's "Editable wheel values" columns (Day 78-170, Month 178-278,
/// Year 286-378), which keeps them off the housing's lit bezel at x 50-73 and 384-407.
private struct WheelWindow {
    let frame: CGRect
    private static let columns: [(from: CGFloat, to: CGFloat)] = [(-150, -58), (-50, 50), (58, 150)]

    /// A band across one wheel's column (Day, Month, Year).
    func band(_ index: Int, from top: CGFloat, to bottom: CGFloat) -> CGRect {
        let column = Self.columns[index]
        return CGRect(x: frame.midX + column.from, y: frame.midY + top,
                      width: column.to - column.from, height: bottom - top)
    }

    /// A band across all three columns (x 78-378).
    func strip(from top: CGFloat, to bottom: CGFloat) -> CGRect {
        CGRect(x: frame.midX - 150, y: frame.midY + top, width: 300, height: bottom - top)
    }
}

private struct Anchor {
    let name: String
    let box: CGRect
    let threshold: UInt8
    var top: CGFloat?
    var bottom: CGFloat?
    var centre: CGFloat?
    var centreAccuracy: CGFloat

    init(
        _ name: String, box: CGRect, threshold: UInt8, top: CGFloat? = nil, bottom: CGFloat? = nil,
        centre: CGFloat? = nil, centreAccuracy: CGFloat = 1.5
    ) {
        self.name = name
        self.box = box
        self.threshold = threshold
        self.top = top
        self.bottom = bottom
        self.centre = centre
        self.centreAccuracy = centreAccuracy
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

    /// Whether the pixel at (x, y), in pixels from the top left, has every channel above
    /// `threshold`.
    private func isLit(_ x: Int, _ y: Int, above threshold: UInt8) -> Bool {
        let index = (y * width + x) * 4
        return pixels[index] > threshold && pixels[index + 1] > threshold && pixels[index + 2] > threshold
    }

    private func pixelRange(_ rect: CGRect) -> (xs: Range<Int>, ys: Range<Int>) {
        let x0 = max(0, Int((rect.minX * scale).rounded())), x1 = min(width, Int((rect.maxX * scale).rounded()))
        let y0 = max(0, Int((rect.minY * scale).rounded())), y1 = min(height, Int((rect.maxY * scale).rounded()))
        return (x0..<max(x0, x1), y0..<max(y0, y1))
    }

    /// Pixels in `rect` (points) with every channel above `threshold`.
    func lit(_ rect: CGRect, above threshold: UInt8) -> Int {
        let range = pixelRange(rect)
        var count = 0
        for y in range.ys {
            for x in range.xs where isLit(x, y, above: threshold) {
                count += 1
            }
        }
        return count
    }

    /// The first and last pixel rows in `rect` holding any pixel above `threshold`, in points
    /// (the bottom is the lower edge of the last row).
    func inkRows(in rect: CGRect, above threshold: UInt8) -> (top: CGFloat, bottom: CGFloat)? {
        let range = pixelRange(rect)
        var first: Int?
        var last: Int?
        for y in range.ys where range.xs.contains(where: { isLit($0, y, above: threshold) }) {
            if first == nil { first = y }
            last = y
        }
        guard let first, let last else { return nil }
        return (CGFloat(first) / scale, CGFloat(last + 1) / scale)
    }
}
