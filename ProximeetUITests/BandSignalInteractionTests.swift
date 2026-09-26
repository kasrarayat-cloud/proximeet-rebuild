import XCTest

/// Real taps across the approved Wristband → Signal interaction (chapters 05 and 06). Ungated, so
/// the original `proximeet-simulator-verification` workflow's interaction reel would record the
/// approved screens (not run in this chapter; `proximeet-signal-review` runs this class). The DEBUG fixture `wristband` only skips the earlier chapters; it reaches the
/// Wristband through the same gates as the real route.
///
/// Updated for the approved flow: the legacy band and signal screens (`band.confirm`,
/// `intent.*`, four `signal.*` choices) and the Ready scene with its 3D hero are no longer
/// reachable from the approved route; Signal's Continue preview ends the preview. Those legacy
/// assertions are retired. The approved screens are covered in full by `WristbandReviewTests` and
/// `SignalReviewTests` (every state, pixels, endpoint, taps, Reduce Motion, largest text).
@MainActor
final class BandSignalInteractionTests: XCTestCase {
    private static let intents = ["social", "dating", "business", "activity"]
    private static let approaches = ["chatFirst", "okayToSayHello"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBandSignalInteraction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "wristband"]
        app.launch()
        let continueBand = app.buttons["wristband.primary"]
        XCTAssertTrue(continueBand.waitForExistence(timeout: 10))
        XCTAssertFalse(continueBand.isEnabled, "No intent is chosen for the guest.")
        holdForCapture(0.7)
        capture("01-band-unselected", app)

        for intent in Self.intents {
            let choice = app.buttons["wristband.intent.\(intent)"]
            choice.tap()
            XCTAssertTrue(choice.isSelected)
            XCTAssertTrue(continueBand.isEnabled)
            for other in Self.intents where other != intent {
                XCTAssertFalse(app.buttons["wristband.intent.\(other)"].isSelected)
            }
            holdForCapture(0.5)
            capture("02-band-\(intent)", app)
        }
        app.buttons["wristband.intent.social"].tap()
        continueBand.tap()

        let continueSignal = app.buttons["signal.primary"]
        XCTAssertTrue(continueSignal.waitForExistence(timeout: 5))
        XCTAssertFalse(continueSignal.isEnabled, "No approach is chosen for the guest.")
        XCTAssertEqual(summary(app), "Social band · Choose your approach", "The chosen intent is carried.")
        holdForCapture(0.7)
        capture("03-signal-empty", app)

        for approach in Self.approaches {
            let choice = app.buttons["signal.approach.\(approach)"]
            choice.tap()
            XCTAssertTrue(choice.isSelected)
            XCTAssertTrue(continueSignal.isEnabled)
            for other in Self.approaches where other != approach {
                XCTAssertFalse(app.buttons["signal.approach.\(other)"].isSelected)
            }
            holdForCapture(0.7)
            capture("04-signal-\(approach)", app)
        }

        // Reselection while the tag is still moving replaces the draft immediately.
        app.buttons["signal.approach.chatFirst"].tap()
        app.buttons["signal.approach.okayToSayHello"].tap()
        XCTAssertTrue(app.buttons["signal.approach.okayToSayHello"].isSelected)
        XCTAssertFalse(app.buttons["signal.approach.chatFirst"].isSelected)
        app.buttons["signal.approach.chatFirst"].tap()
        XCTAssertTrue(app.buttons["signal.approach.chatFirst"].isSelected)
        XCTAssertEqual(summary(app), "Social band · Chat first")
        holdForCapture(0.7)
        capture("05-chat-first-reselected", app)

        continueSignal.tap()
        let end = app.alerts["End of this preview."]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "Signal's Continue preview ends the preview.")
        capture("06-endpoint", app)
        end.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["signal.approach.chatFirst"].isSelected, "The message stays on Signal.")
    }

    /// App-level Reduce Motion preview flag (not the system setting): every change is immediate.
    func testReducedMotionStillUpdatesImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "wristband", "-ProximeetReduceMotionPreview", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["wristband.intent.activity"].waitForExistence(timeout: 10))
        app.buttons["wristband.intent.activity"].tap()
        XCTAssertTrue(app.buttons["wristband.intent.activity"].isSelected)
        app.buttons["wristband.primary"].tap()
        XCTAssertTrue(app.buttons["signal.approach.okayToSayHello"].waitForExistence(timeout: 5))
        app.buttons["signal.approach.okayToSayHello"].tap()
        XCTAssertTrue(app.buttons["signal.approach.okayToSayHello"].isSelected)
        app.buttons["signal.approach.chatFirst"].tap()
        XCTAssertTrue(app.buttons["signal.approach.chatFirst"].isSelected)
        XCTAssertTrue(app.buttons["signal.primary"].isEnabled)
        XCTAssertEqual(summary(app), "Activity band · Chat first")
        capture("07-reduced-motion-signal", app)
        app.buttons["signal.primary"].tap()
        XCTAssertTrue(app.alerts["End of this preview."].waitForExistence(timeout: 5))
        capture("08-reduced-motion-endpoint", app)
    }

    private func summary(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any).matching(identifier: "signal.summary").firstMatch.label
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func holdForCapture(_ seconds: TimeInterval) {
        let settled = expectation(description: "Decorative movement settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { settled.fulfill() }
        wait(for: [settled], timeout: seconds + 1)
    }
}
