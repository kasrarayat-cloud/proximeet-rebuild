import XCTest

/// Runtime review of the approved Welcome (chapter 01) for docs/verification/welcome-mac-review.md:
/// measured geometry, both honest notices, the Reduce Motion preview and the largest text size.
///
/// Skipped unless the test runner's environment has `PROXIMEET_WELCOME_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1` in xcodebuild's environment), so runs of the whole
/// UI test target, such as the Band/Signal interaction reel, are unchanged. It observes the app
/// only through the accessibility tree and screenshots and adds nothing to the app.
@MainActor
final class WelcomeReviewTests: XCTestCase {
    private static let reviewFlag = "PROXIMEET_WELCOME_REVIEW"
    /// The approved canvas (LAYOUT_SPEC.json), which is the iPhone 17 Pro Max screen in points.
    private static let canvas = CGSize(width: 440, height: 956)
    private static let tolerance: CGFloat = 1.5

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Welcome review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        // Evidence for welcome_review.sh that the flag reached this runner process.
        print("WELCOME_REVIEW_FLAG_SEEN \(name)")
    }

    /// Settled layout at the default text size, measured against LAYOUT_SPEC.json on a
    /// 440 × 956 point screen and recorded (never asserted against the spec) on any other.
    func testDefaultGeometry() throws {
        let app = launch()
        let welcome = WelcomeElements(app: app)
        XCTAssertTrue(welcome.continueWithApple.waitForExistence(timeout: 10))
        hold(2.0) // the 1.4 s pose study has finished
        let geometry = welcome.geometry(scenario: "default")
        attach(geometry, name: "geometry-default")
        capture("welcome-default-settled", app)
        // The accessibility hierarchy, for the manual VoiceOver-order review.
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "accessibility-tree-default"
        tree.lifetime = .keepAlways
        add(tree)
        assertOrderedWithoutOverlap(welcome)

        let window = app.windows.firstMatch.frame
        guard window.size == Self.canvas else {
            // Counted as skipped, never as passed: the spec positions were not measured.
            throw XCTSkip("Window is \(window.size), not the 440 × 956 reference; geometry recorded, spec positions not asserted.")
        }
        // Rows from LAYOUT_SPEC.json. Text is measured by its own frame: glyphs are centred in
        // each Figma line box, so a text's midpoint is the box's midpoint.
        assertNear(welcome.continueWithApple.frame, CGRect(x: 32, y: 772, width: 376, height: 60), "Continue with Apple")
        assertNear(welcome.moreOptions.frame, CGRect(x: 32, y: 844, width: 376, height: 44), "More options")
        // The headline's two 59 pt line boxes span 570–688 (centre 629). Its accessibility frame is
        // the union of the glyph frames, which overflow the tight line boxes by half of (Manrope's
        // natural line − 59 pt) at the top and bottom: 1.366 em at 56 pt, from the font's hhea
        // metrics (ascender 2132 + descender 600 over 2000 units). The test runner cannot load the
        // app's fonts, so the metric is written here. Measured on iPhone 17 Pro Max in Codemagic
        // build 6ab6ad8cd78992b5db88f79d: minY 561.17, height 135.67.
        let overflow: CGFloat = (1.366 * 56 - 59) / 2
        assertNear(welcome.headline.frame.minX, 32, "headline x")
        assertNear(welcome.headline.frame.midY, 629, "headline centre (570 + 118 / 2)")
        assertNear(welcome.headline.frame.minY, 570 - overflow, "headline glyph top (570 − overflow)")
        assertNear(welcome.headline.frame.height, 118 + 2 * overflow, "headline glyph extent (2 × 59 + overflow)")
        assertNear(welcome.supporting.frame.minX, 32, "supporting line x")
        assertNear(welcome.supporting.frame.midY, 716.5, "supporting line centre (704 + 25 / 2)")
        assertNear(welcome.eligibility.frame.midX, 220, "18+ only centre x")
        assertNear(welcome.eligibility.frame.midY, 921, "18+ only centre (913 + 16 / 2)")
        assertNear(welcome.brand.frame.minX, 48, "wordmark x")
        // The status-area assumption: the brand row is at max(top inset + 2, 64). A row centre
        // of 80 means the top inset is at most 62 pt. A lower row means a larger inset, and
        // this measures it.
        let brandRowTop = welcome.brand.frame.midY - 16
        if abs(brandRowTop - 64) > Self.tolerance {
            XCTFail("Brand row top is \(brandRowTop), not 64: the top safe-area inset is about \(brandRowTop - 2) pt, over the 62 pt assumed.")
        }
    }

    /// Both controls answer with a native notice, change nothing and navigate nowhere.
    func testHonestNotices() throws {
        let launched = Date()
        let app = launch()
        let welcome = WelcomeElements(app: app)
        XCTAssertTrue(welcome.continueWithApple.waitForExistence(timeout: 10))
        // Tapped as soon as XCTest allows. XCTest waits for the app to go idle first, so this
        // does not prove a tap during the pose study; that is a manual check. The elapsed time
        // is recorded for information only.
        welcome.continueWithApple.tap()
        attachNote(String(format: "Continue with Apple tapped %.2f s after launch() began.", Date().timeIntervalSince(launched)))
        assertNotice(
            app,
            title: "Apple sign-in isn’t connected",
            message: "This prototype doesn’t connect to Apple yet. Nothing was sent or saved.",
            capture: "notice-continue-with-apple"
        )
        assertStillOnWelcome(app, welcome)

        welcome.moreOptions.tap()
        assertNotice(
            app,
            title: "More options aren’t available",
            message: "This prototype doesn’t include other sign-in methods yet.",
            capture: "notice-more-options"
        )
        assertStillOnWelcome(app, welcome)
    }

    /// The app-level Reduce Motion preview (not the system setting). The screenshot is taken
    /// as soon as Welcome exists; analyze_welcome_review.py checks the hero pose in the
    /// simctl captures, which are timed more tightly.
    func testReduceMotionPreviewLaunch() throws {
        let app = launch(extra: ["-ProximeetReduceMotionPreview", "YES"])
        let welcome = WelcomeElements(app: app)
        XCTAssertTrue(welcome.continueWithApple.waitForExistence(timeout: 10))
        capture("reduce-motion-preview-first-look", app)
        attach(welcome.geometry(scenario: "reduce-motion-preview"), name: "geometry-reduce-motion-preview")
        assertOrderedWithoutOverlap(welcome)
    }

    /// The largest accessibility text size: every element present, inside the width, in order
    /// without overlap, and reachable by scrolling.
    ///
    /// `-UIPreferredContentSizeCategoryName` is a widely used but undocumented UIKit launch
    /// argument. If it does not enlarge the text, this test skips (it never passes on the default
    /// size), and the simctl content_size capture remains the large-text evidence.
    func testLargestTextSize() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let welcome = WelcomeElements(app: app)
        XCTAssertTrue(welcome.continueWithApple.waitForExistence(timeout: 10))
        hold(2.0)
        guard welcome.headline.frame.height > 118 + 10 else {
            // No largest-text geometry or screenshot is attached on this path, so nothing at
            // the default size can be mistaken for large-text evidence.
            attachNote("The launch argument did not enlarge the text (headline height \(welcome.headline.frame.height)).")
            throw XCTSkip("Largest text size not applied by the launch argument; see the simctl capture.")
        }
        attach(welcome.geometry(scenario: "largest-text"), name: "geometry-largest-text")
        capture("largest-text-top", app)
        assertOrderedWithoutOverlap(welcome)
        let width = app.windows.firstMatch.frame.width
        for (name, element) in welcome.all {
            XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(name) starts off screen")
            XCTAssertLessThanOrEqual(element.frame.maxX, width + 0.5, "\(name) runs past the right edge")
        }
        XCTAssertGreaterThanOrEqual(welcome.continueWithApple.frame.height, 44)
        XCTAssertGreaterThanOrEqual(welcome.moreOptions.frame.height, 44)
        var swipes = 0
        while !welcome.eligibility.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(welcome.moreOptions.isHittable || welcome.eligibility.isHittable,
                      "The lower controls must be reachable by scrolling.")
        attachNote("Swipes needed to reach “18+ only”: \(swipes).")
        capture("largest-text-bottom", app)
        welcome.moreOptions.tap()
        XCTAssertTrue(app.alerts["More options aren’t available"].waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons["OK"].tap()
    }

    // MARK: - Helpers

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"] + extra
        app.launch()
        return app
    }

    private func assertNotice(_ app: XCUIApplication, title: String, message: String, capture name: String) {
        let alert = app.alerts[title]
        guard alert.waitForExistence(timeout: 5) else {
            // Keep the evidence: what was on screen and what the accessibility tree held.
            capture(name + "-missing", app)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = name + "-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
            XCTFail("No alert titled “\(title)”.")
            return
        }
        XCTAssertTrue(alert.staticTexts[message].exists, "The notice does not say “\(message)”.")
        XCTAssertEqual(alert.buttons.count, 1, "The notice should offer only OK.")
        capture(name, app)
        alert.buttons["OK"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "The notice did not dismiss.")
    }

    private func assertStillOnWelcome(_ app: XCUIApplication, _ welcome: WelcomeElements) {
        XCTAssertTrue(welcome.continueWithApple.isHittable, "Welcome is no longer showing.")
        XCTAssertFalse(app.navigationBars.firstMatch.exists, "A notice must not navigate anywhere.")
    }

    private func assertOrderedWithoutOverlap(_ welcome: WelcomeElements) {
        let rows = welcome.all
        for index in rows.indices.dropLast() {
            let (upperName, upper) = rows[index]
            let (lowerName, lower) = rows[index + 1]
            XCTAssertTrue(upper.exists && lower.exists, "\(upperName) or \(lowerName) is missing")
            XCTAssertLessThanOrEqual(upper.frame.maxY, lower.frame.minY + 0.5,
                                     "\(upperName) overlaps \(lowerName)")
        }
    }

    private func assertNear(_ actual: CGFloat, _ expected: CGFloat, _ what: String) {
        XCTAssertLessThanOrEqual(abs(actual - expected), Self.tolerance, "\(what): \(actual), expected \(expected)")
    }

    private func assertNear(_ actual: CGRect, _ expected: CGRect, _ what: String) {
        assertNear(actual.minX, expected.minX, "\(what) x")
        assertNear(actual.minY, expected.minY, "\(what) y")
        assertNear(actual.width, expected.width, "\(what) width")
        assertNear(actual.height, expected.height, "\(what) height")
    }

    private func attach(_ object: [String: Any], name: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            XCTFail("Could not encode \(name)")
            return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name + ".json"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also in the log, so the geometry survives even if attachment export is unavailable.
        print("WELCOME_REVIEW_JSON \(name) " + (String(data: data, encoding: .utf8) ?? "{}")
            .replacingOccurrences(of: "\n", with: " "))
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
        let done = expectation(description: "Hold for the decorative motion")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 1)
    }
}

/// The Welcome's accessible elements, found by the approved copy or by identifier. The hero is
/// hidden from VoiceOver by design, so its geometry comes from screenshots instead.
@MainActor
private struct WelcomeElements {
    let app: XCUIApplication

    private func labelled(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    var brand: XCUIElement { labelled("Proximeet") }
    var headline: XCUIElement { labelled("Make room for a hello.") }
    var supporting: XCUIElement { labelled("Real places. New people. Your way.") }
    var continueWithApple: XCUIElement { app.buttons["welcome.continueWithApple"] }
    var moreOptions: XCUIElement { app.buttons["welcome.moreOptions"] }
    var eligibility: XCUIElement { labelled("18+ only") }

    /// Top to bottom, as approved.
    var all: [(String, XCUIElement)] {
        [("brand", brand), ("headline", headline), ("supporting", supporting),
         ("continueWithApple", continueWithApple), ("moreOptions", moreOptions), ("eligibility", eligibility)]
    }

    func geometry(scenario: String) -> [String: Any] {
        let window = app.windows.firstMatch.frame
        var elements: [String: Any] = [:]
        for (name, element) in all {
            let frame = element.frame
            elements[name] = [
                "exists": element.exists,
                "minX": frame.minX, "minY": frame.minY, "width": frame.width, "height": frame.height,
                "midX": frame.midX, "midY": frame.midY,
            ]
        }
        return [
            "scenario": scenario,
            "window": ["width": window.width, "height": window.height],
            "elements": elements,
            "brand_row_top_inferred": brand.frame.midY - 16,
            "note": "Points, screen coordinates. The hero is hidden from accessibility; see the screenshots.",
        ]
    }
}
