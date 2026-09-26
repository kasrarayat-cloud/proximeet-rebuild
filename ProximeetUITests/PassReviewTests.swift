import UIKit
import XCTest

/// Runtime review of the approved Pass (chapter 03), driven through the real route:
/// Welcome → More options → "Continue the demo (no account)" → Birthday (a real wheel date) →
/// Continue → Pass.
///
/// Skipped unless the test runner's environment has `PROXIMEET_PASS_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_PASS_REVIEW=1` to xcodebuild). Real taps and wheel adjustments; the
/// only fixture used is the Reduce Motion preview test's starting screen, and it says so.
@MainActor
final class PassReviewTests: XCTestCase {
    private static let reviewFlag = "PROXIMEET_PASS_REVIEW"
    private static let claim = "No age or identity verification is performed."

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Pass review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("PASS_REVIEW_FLAG_SEEN \(name)")
    }

    /// The recorded walkthrough: into Pass from a real Birthday date, Try the demo, Finish
    /// preview at once, the end-of-preview message dismissed, Leave demo back to Birthday with
    /// the date kept, re-entry at the intro, Cancel, and Back.
    func testWalkthroughStartFinishEndpointLeaveReentryCancelBack() throws {
        print("PASS_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        let app = launchWelcome()
        hold(1.5)
        let birthday = openBirthday(app)
        enterAdultDate(birthday)
        hold(0.8)

        birthday.continueButton.tap()
        let pass = PassElements(app: app)
        waitForStage(pass, "Your next chapter.")
        hold(0.8)
        capture("pass-intro", app)
        assertStage(pass, headline: "Your next chapter.", support: "Preview the age-check experience.",
                    primary: "Try the demo", exit: "Leave demo")
        let intro = softlyMeasured(app, "Intro", anchors: Self.introAnchors)

        pass.primary.tap()
        waitForStage(pass, "Demo in progress.")
        XCTAssertTrue(pass.primary.isEnabled, "Finish preview must be available at once.")
        XCTAssertEqual(pass.primary.label, "Finish preview")
        hold(0.8)
        capture("pass-progress", app)
        assertStage(pass, headline: "Demo in progress.", support: "You control this preview.",
                    primary: "Finish preview", exit: "Cancel")
        let progress = softlyMeasured(app, "Progress", anchors: Self.progressAnchors)
        softly {
            if let before = intro.eighteen, let after = progress.eighteen {
                XCTAssertEqual(before - after, 6, accuracy: 0.7, "The card text lifts 6 pt in progress (18+ top \(before) → \(after)).")
            }
            if let before = intro.paper, let after = progress.paper {
                XCTAssertEqual(before - after, 6, accuracy: 0.7, "The pass art lifts 6 pt with its text (paper top \(before) → \(after)).")
            }
        }

        pass.primary.tap()
        waitForStage(pass, "Demo complete.")
        hold(0.8)
        capture("pass-complete", app)
        assertStage(pass, headline: "Demo complete.", support: "You have finished the demo.",
                    primary: "Continue preview", exit: "Leave demo")
        _ = softlyMeasured(app, "Complete", anchors: Self.introAnchors)

        pass.primary.tap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "Continue preview shows the end-of-preview message.")
        XCTAssertTrue(end.buttons["OK"].exists)
        hold(0.6)
        capture("pass-endpoint", app)
        end.buttons["OK"].tap()
        waitForAbsence(end)
        XCTAssertEqual(pass.headline.label, "Demo complete.", "Dismissing the message stays on complete.")
        hold(0.8)

        pass.exit.tap()
        XCTAssertTrue(birthday.headline.waitForExistence(timeout: 5), "Leave demo returns to Birthday.")
        waitForAbsence(pass.headline)
        XCTAssertEqual(birthday.wheelValues, ["12", "May", "1997"], "Birthday keeps its date.")
        XCTAssertTrue(birthday.continueButton.isEnabled)
        hold(0.8)
        capture("pass-left-birthday-kept", app)

        birthday.continueButton.tap()
        waitForStage(pass, "Your next chapter.")
        hold(0.8)
        capture("pass-reentry-intro", app)
        XCTAssertEqual(pass.primary.label, "Try the demo", "Re-entry starts at the intro.")

        pass.primary.tap()
        waitForStage(pass, "Demo in progress.")
        hold(0.8)
        pass.exit.tap()
        waitForStage(pass, "Your next chapter.")
        XCTAssertTrue(pass.back.exists, "Cancel stays on Pass.")
        hold(0.8)
        capture("pass-cancelled-intro", app)

        pass.back.tap()
        XCTAssertTrue(birthday.headline.waitForExistence(timeout: 5), "Back returns to Birthday.")
        waitForAbsence(pass.headline)
        XCTAssertEqual(birthday.wheelValues, ["12", "May", "1997"])
        hold(1.0)
        capture("pass-back-birthday", app)
    }

    /// The gate, rapid taps, waiting and background/resume, and the absence of any verified or
    /// provider state.
    func testGateRapidTapsWaitingAndResumeNeverAdvanceOnTheirOwn() throws {
        let app = launchWelcome()
        let birthday = openBirthday(app)
        let pass = PassElements(app: app)

        // The Birthday gate: an under-18 or partial date cannot open Pass.
        birthday.wheel(0).adjust(toPickerWheelValue: "12")
        birthday.wheel(1).adjust(toPickerWheelValue: "May")
        XCTAssertFalse(birthday.continueButton.isEnabled, "A partial date cannot continue.")
        birthday.wheel(2).adjust(toPickerWheelValue: "2012")
        waitFor(birthday.continueButton, enabled: false, "An under-18 date cannot continue.")
        birthday.continueButton.tap()
        hold(0.6)
        XCTAssertFalse(pass.headline.exists, "An under-18 date must not open Pass.")
        capture("pass-gate-under18", app)

        // A rapid double tap on Continue opens Pass once, at the intro.
        birthday.wheel(2).adjust(toPickerWheelValue: "1997")
        waitFor(birthday.continueButton, enabled: true, "12 May 1997 can continue.")
        hold(0.8)
        birthday.continueButton.doubleTap()
        waitForStage(pass, "Your next chapter.")
        hold(1.0)
        XCTAssertEqual(pass.headline.label, "Your next chapter.", "A double tap on Continue must not also start the demo.")

        // Waiting never advances.
        hold(3.0)
        XCTAssertEqual(pass.headline.label, "Your next chapter.", "Nothing advances the intro on its own.")

        // A rapid double tap on Try the demo starts it once; it does not also finish it.
        pass.primary.doubleTap()
        waitForStage(pass, "Demo in progress.")
        hold(1.0)
        XCTAssertEqual(pass.headline.label, "Demo in progress.", "A double tap must not skip to complete.")
        capture("pass-after-double-tap", app)

        hold(3.0)
        XCTAssertEqual(pass.headline.label, "Demo in progress.", "Waiting never completes the demo.")

        // Background and resume never complete it either.
        XCUIDevice.shared.press(.home)
        hold(2.0)
        app.activate()
        XCTAssertTrue(pass.headline.waitForExistence(timeout: 10))
        hold(1.0)
        XCTAssertEqual(pass.headline.label, "Demo in progress.", "Background and resume never complete the demo.")
        capture("pass-after-resume", app)

        // Finish preview works at once, from a separate tap (at the far side of the button, so
        // it is a new tap, not a repeat).
        pass.primary.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
        waitForStage(pass, "Demo complete.")

        // Nothing claims verification, and nothing asked for a camera, a document or a provider.
        let claims = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'verified' OR label CONTAINS[c] 'access granted'")
        )
        XCTAssertEqual(claims.count, 0, "No verified or access-granted wording anywhere.")
        XCTAssertEqual(pass.claim.label, Self.claim)
        XCTAssertEqual(app.alerts.count, 0, "No permission or provider prompt appeared.")

        // A rapid double tap on Back returns to Birthday once; it does not also leave Birthday.
        pass.back.doubleTap()
        XCTAssertTrue(birthday.headline.waitForExistence(timeout: 5))
        hold(1.0)
        XCTAssertTrue(birthday.headline.exists, "A double tap on Back must stop at Birthday.")
        XCTAssertFalse(app.buttons["welcome.continueWithApple"].exists, "A double tap on Back must not reach Welcome.")
        XCTAssertEqual(birthday.wheelValues, ["12", "May", "1997"])
        capture("pass-after-double-back", app)
    }

    /// The app-level Reduce Motion preview (`-ProximeetReduceMotionPreview YES`, not the system
    /// setting): the pass stays put when the demo starts. Starts from the DEBUG fixture that
    /// opens Pass through Birthday's gate with 12 May 1997.
    func testReduceMotionPreviewKeepsThePassStationary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "pass", "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        let pass = PassElements(app: app)
        waitForStage(pass, "Your next chapter.")
        hold(1.0)
        capture("pass-reduce-motion-preview-intro", app)
        let before = softlyMeasured(app, "Reduce Motion intro", anchors: Self.introAnchors)
        pass.primary.tap()
        waitForStage(pass, "Demo in progress.")
        hold(1.0)
        capture("pass-reduce-motion-preview-progress", app)
        let after = softlyMeasured(app, "Reduce Motion progress", anchors: [])
        softly {
            if let top = before.eighteen, let moved = after.eighteen {
                XCTAssertEqual(top, moved, accuracy: 0.34, "Reduce Motion keeps the card text stationary (18+ top \(top) → \(moved)).")
            }
            if let top = before.paper, let moved = after.paper {
                XCTAssertEqual(top, moved, accuracy: 0.34, "Reduce Motion keeps the pass art stationary (paper top \(top) → \(moved)).")
            }
        }
    }

    // MARK: - Route helpers

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 10))
        return app
    }

    private func openBirthday(_ app: XCUIApplication) -> BirthdayScreen {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 5), "More options should offer the demo.")
        demo.tap()
        let birthday = BirthdayScreen(app: app)
        XCTAssertTrue(birthday.headline.waitForExistence(timeout: 5), "Birthday should open.")
        return birthday
    }

    private func enterAdultDate(_ birthday: BirthdayScreen) {
        birthday.wheel(0).adjust(toPickerWheelValue: "12")
        birthday.wheel(1).adjust(toPickerWheelValue: "May")
        birthday.wheel(2).adjust(toPickerWheelValue: "1997")
        waitFor(birthday.continueButton, enabled: true, "12 May 1997 should enable Continue.")
    }

    private func waitForStage(_ pass: PassElements, _ headline: String) {
        XCTAssertTrue(pass.headline.waitForExistence(timeout: 5), "Pass should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", headline), object: pass.headline)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 5), .completed, "Expected “\(headline)”, found “\(pass.headline.label)”.")
    }

    private func assertStage(_ pass: PassElements, headline: String, support: String, primary: String, exit: String) {
        XCTAssertEqual(pass.headline.label, headline)
        XCTAssertEqual(pass.support.label, support)
        XCTAssertEqual(pass.primary.label, primary)
        XCTAssertEqual(pass.exit.label, exit)
        XCTAssertEqual(pass.claim.label, Self.claim, "The no-verification sentence is on every stage.")
        XCTAssertEqual(pass.card.label, "Demo pass, 18 plus")
        XCTAssertTrue(pass.back.isHittable, "Back is always available.")
        XCTAssertGreaterThanOrEqual(pass.back.frame.height, 44)
        XCTAssertGreaterThanOrEqual(pass.exit.frame.height, 44)
        XCTAssertGreaterThanOrEqual(pass.primary.frame.height, 60)
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
    // points at 440 × 956. Expected values were measured the same way on the approved board
    // (docs/design/pass-approved/reference/pass-review.png: frames at x 24 / 390 / 756, y 123,
    // scale 0.75, so about ±0.7 pt). Where the board's downsampling trims a glyph edge, the
    // value is the glyph's own extent on Figma's line box instead: the "18+" '8' is 66 pt tall
    // (Manrope ExtraBold −30…1470 units at 88, baseline 528.7), the claim ends at the 'p'
    // descender of "is performed." (784.8; Birthday's two-line guidance, same top, drew
    // 745.3–784.7), and PROXIMEET sits on its baseline at 650.1.

    private static let white: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 200 }
    private static let grey: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 120 }
    private static let black: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 50 }
    private static let teal: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 60 && g > 60 && g < 140 && b > 70 }
    private static let cyan: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 120 && g > 150 && b > 160 }

    /// The intro and complete stages (the pass at rest: Figma 330).
    private static let introAnchors: [Anchor] = [
        Anchor("Back arrow", CGRect(x: 34, y: 55, width: 24, height: 60), white, top: 80.0, bottom: 92.0),
        Anchor("Wordmark", CGRect(x: 84, y: 55, width: 166, height: 60), white, top: 78.7),
        Anchor("DEMO label", CGRect(x: 318, y: 60, width: 84, height: 52), cyan, top: 80.0, bottom: 92.0),
        Anchor("Support", CGRect(x: 32, y: 285, width: 368, height: 35), grey, top: 294.7),
        Anchor("Pass paper top", CGRect(x: 100, y: 380, width: 30, height: 60), white, top: 407.0),
        Anchor("18+", CGRect(x: 140, y: 440, width: 160, height: 120), black, top: 464.2, bottom: 530.2),
        Anchor("DEMO PASS", CGRect(x: 120, y: 545, width: 200, height: 55), teal, top: 562.7, bottom: 580.0),
        Anchor("PROXIMEET", CGRect(x: 130, y: 615, width: 180, height: 55), black, top: 638.7, bottom: 650.0),
        Anchor("Claim", CGRect(x: 32, y: 735, width: 368, height: 65), grey, top: 745.3, bottom: 784.8),
        Anchor("Primary", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812.0, bottom: 872.0),
        Anchor("Exit label", CGRect(x: 120, y: 880, width: 200, height: 45), white, top: 897.3),
    ]

    /// In progress the pass is lifted 6 pt (Figma 324); everything else stays.
    private static let progressAnchors: [Anchor] = [
        Anchor("DEMO label", CGRect(x: 318, y: 60, width: 84, height: 52), cyan, top: 80.0, bottom: 92.0),
        Anchor("Pass paper top", CGRect(x: 100, y: 380, width: 30, height: 60), white, top: 401.0),
        Anchor("18+", CGRect(x: 140, y: 440, width: 160, height: 120), black, top: 458.2, bottom: 524.2),
        Anchor("DEMO PASS", CGRect(x: 120, y: 540, width: 200, height: 55), teal, top: 556.7, bottom: 574.0),
        Anchor("PROXIMEET", CGRect(x: 130, y: 610, width: 180, height: 55), black, top: 632.7, bottom: 644.0),
        Anchor("Claim", CGRect(x: 32, y: 735, width: 368, height: 65), grey, top: 745.3, bottom: 784.8),
        Anchor("Primary", CGRect(x: 60, y: 800, width: 320, height: 80), white, top: 812.0, bottom: 872.0),
    ]

    /// Checks `anchors` on the current screen and returns the drawn tops of the card's "18+"
    /// (native text) and of the paper (artwork), for the lift and Reduce Motion comparisons.
    private func softlyMeasured(_ app: XCUIApplication, _ state: String, anchors: [Anchor]) -> PassTops {
        var eighteenTop: CGFloat?
        var paperTop: CGFloat?
        softly {
            XCTAssertEqual(app.frame.size, CGSize(width: 440, height: 956), "Anchors are measured at 440 × 956.")
            guard let shot = RenderedScreen(app) else { return }
            // From 440: the clip's dark underside reaches 430.7 on the board.
            eighteenTop = shot.inkRows(in: CGRect(x: 140, y: 440, width: 160, height: 120), where: Self.black)?.top
            paperTop = shot.inkRows(in: CGRect(x: 100, y: 380, width: 30, height: 60), where: Self.white)?.top
            var lines: [String] = []
            for anchor in anchors {
                guard let ink = shot.inkRows(in: anchor.box, where: anchor.test) else {
                    XCTFail("\(state): \(anchor.name) is not drawn in \(anchor.box).")
                    continue
                }
                lines.append(String(format: "%@ %.1f-%.1f", anchor.name, ink.top, ink.bottom))
                if let top = anchor.top {
                    XCTAssertEqual(ink.top, top, accuracy: 1.0, "\(state): \(anchor.name) top drawn at \(ink.top), approved \(top).")
                }
                if let bottom = anchor.bottom {
                    XCTAssertEqual(ink.bottom, bottom, accuracy: 1.0, "\(state): \(anchor.name) bottom drawn at \(ink.bottom), approved \(bottom).")
                }
            }
            attachNote("\(state): rendered anchors (points): " + lines.joined(separator: "; ") + ".")
        }
        return PassTops(eighteen: eighteenTop, paper: paperTop)
    }
}

/// Birthday's controls, by identifier.
@MainActor
private struct BirthdayScreen {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["birthday.headline"] }
    var continueButton: XCUIElement { app.buttons["birthday.continue"] }

    func wheel(_ index: Int) -> XCUIElement { app.pickerWheels.element(boundBy: index) }

    var wheelValues: [String] {
        (0..<3).map { (wheel($0).value as? String) ?? "?" }
    }
}

/// Pass's elements, by identifier.
@MainActor
private struct PassElements {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var support: XCUIElement { app.staticTexts["pass.support"] }
    var claim: XCUIElement { app.staticTexts["pass.claim"] }
    var card: XCUIElement { app.descendants(matching: .any)["pass.card"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
    var exit: XCUIElement { app.buttons["pass.exit"] }
    var back: XCUIElement { app.buttons["pass.back"] }
}

private struct PassTops {
    let eighteen: CGFloat?
    let paper: CGFloat?
}

private struct Anchor {
    let name: String
    let box: CGRect
    let test: (UInt8, UInt8, UInt8) -> Bool
    let top: CGFloat?
    let bottom: CGFloat?

    init(_ name: String, _ box: CGRect, _ test: @escaping (UInt8, UInt8, UInt8) -> Bool, top: CGFloat? = nil, bottom: CGFloat? = nil) {
        self.name = name
        self.box = box
        self.test = test
        self.top = top
        self.bottom = bottom
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

    /// The first and last pixel rows in `rect` (points) holding a pixel that passes `test`, in
    /// points (the bottom is the lower edge of the last row).
    func inkRows(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> (top: CGFloat, bottom: CGFloat)? {
        let x0 = max(0, Int((rect.minX * scale).rounded())), x1 = min(width, Int((rect.maxX * scale).rounded()))
        let y0 = max(0, Int((rect.minY * scale).rounded())), y1 = min(height, Int((rect.maxY * scale).rounded()))
        guard x0 < x1, y0 < y1 else { return nil }
        var first: Int?
        var last: Int?
        for y in y0..<y1 {
            var hit = false
            for x in x0..<x1 {
                let index = (y * width + x) * 4
                if test(pixels[index], pixels[index + 1], pixels[index + 2]) {
                    hit = true
                    break
                }
            }
            if hit {
                if first == nil { first = y }
                last = y
            }
        }
        guard let first, let last else { return nil }
        return (CGFloat(first) / scale, CGFloat(last + 1) / scale)
    }
}
