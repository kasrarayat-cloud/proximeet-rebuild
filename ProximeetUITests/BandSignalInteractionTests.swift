import XCTest

/// Drives real SwiftUI controls and the real domain transitions. The DEBUG fixture only
/// skips unrelated onboarding setup; no test-only selection or animation API is used.
@MainActor
final class BandSignalInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBandSignalInteraction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "band"]
        app.launch()
        let confirmBand = app.buttons["band.confirm"]
        XCTAssertTrue(confirmBand.waitForExistence(timeout: 10))
        XCTAssertFalse(confirmBand.isEnabled, "A displayed cyan preview must not silently select Social.")
        try waitForModel(app)
        capture("01-band-unselected", app)

        for intent in ["social", "dating", "business", "activity"] {
            let choice = app.buttons["intent.\(intent)"]
            choice.tap()
            XCTAssertEqual(choice.value as? String, "Selected")
            XCTAssertTrue(confirmBand.isEnabled)
            for other in ["social", "dating", "business", "activity"] where other != intent {
                XCTAssertEqual(app.buttons["intent.\(other)"].value as? String, "Not selected")
            }
            capture("02-band-\(intent)", app)
        }
        app.buttons["intent.social"].tap()
        confirmBand.tap()

        let confirmSignal = app.buttons["signal.confirm"]
        XCTAssertTrue(confirmSignal.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmSignal.isEnabled)
        try waitForModel(app)
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Social band"))
        capture("03-signal-empty", app)

        for signal in ["comeSayHi", "chatFirst", "withMyCrew", "justLooking"] {
            let choice = app.buttons["signal.\(signal)"]
            choice.tap()
            XCTAssertEqual(choice.value as? String, "Selected")
            XCTAssertTrue(confirmSignal.isEnabled)
            for other in ["comeSayHi", "chatFirst", "withMyCrew", "justLooking"] where other != signal {
                XCTAssertEqual(app.buttons["signal.\(other)"].value as? String, "Not selected")
            }
            // Snapshot attachment after the decorative seat; state was asserted above.
            holdForCapture(0.7)
            capture("04-signal-\(signal)", app)
        }

        // Reselection while the plate is travelling must replace the draft immediately.
        app.buttons["signal.chatFirst"].tap()
        app.buttons["signal.comeSayHi"].tap()
        XCTAssertEqual(app.buttons["signal.comeSayHi"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["signal.chatFirst"].value as? String, "Not selected")
        app.buttons["signal.chatFirst"].tap()
        XCTAssertEqual(app.buttons["signal.chatFirst"].value as? String, "Selected")
        holdForCapture(0.7)
        capture("05-chat-first-reselected", app)
        confirmSignal.tap()
        XCTAssertTrue(app.buttons["Change signal"].waitForExistence(timeout: 5))
        try waitForModel(app)
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Social band"))
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Chat first"))
        capture("06-ready", app)
    }

    func testReducedMotionStillUpdatesImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "band", "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["intent.activity"].waitForExistence(timeout: 10))
        app.buttons["intent.activity"].tap()
        XCTAssertEqual(app.buttons["intent.activity"].value as? String, "Selected")
        app.buttons["band.confirm"].tap()
        XCTAssertTrue(app.buttons["signal.withMyCrew"].waitForExistence(timeout: 5))
        app.buttons["signal.withMyCrew"].tap()
        XCTAssertEqual(app.buttons["signal.withMyCrew"].value as? String, "Selected")
        app.buttons["signal.justLooking"].tap()
        XCTAssertEqual(app.buttons["signal.justLooking"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["signal.confirm"].isEnabled)
        try waitForModel(app)
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Activity band"))
        capture("07-reduced-motion-signal", app)
        app.buttons["signal.confirm"].tap()
        XCTAssertTrue(app.buttons["Change signal"].waitForExistence(timeout: 5))
        try waitForModel(app)
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Activity band"))
        XCTAssertTrue(app.otherElements["signature.hero"].label.contains("Just looking"))
        capture("08-reduced-motion-ready", app)
    }

    private func waitForModel(_ app: XCUIApplication) throws {
        let hero = app.otherElements["signature.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let ready = NSPredicate(format: "value == %@", "3D model ready")
        let expectation = XCTNSPredicateExpectation(predicate: ready, object: hero)
        // Build 3 rendered the model while a slow simulator AX snapshot still reported
        // loading. Keep the readiness contract, but bound cold-start sampling separately
        // from the complete interaction test's execution allowance.
        let result = XCTWaiter.wait(for: [expectation], timeout: 90)
        if result != .completed {
            capture("model-readiness-failure", app)
            let diagnostics = XCTAttachment(string: hero.debugDescription)
            diagnostics.name = "model-readiness-accessibility"
            diagnostics.lifetime = .keepAlways
            add(diagnostics)
            XCTFail("The actual bundled USDZ must load; observed hero value: \(String(describing: hero.value)). A loading or fallback view does not pass.")
        }
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func holdForCapture(_ seconds: TimeInterval) {
        let settled = expectation(description: "Decorative render frame settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        wait(for: [settled], timeout: seconds + 1)
    }
}
