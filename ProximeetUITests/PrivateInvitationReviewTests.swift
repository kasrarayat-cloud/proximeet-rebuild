import UIKit
import XCTest

/// Focused native regression for the four invitation designs approved on 29 October 2026.
/// Fixtures use the app's ordinary guarded Room/Wave transitions. No delivery or chat is simulated
/// by this test: all invitations remain explicitly fictional local examples.
@MainActor
final class PrivateInvitationReviewTests: XCTestCase {
    private var lastTap = Date.distantPast

    private struct Design {
        let intent: String
        let title: String
        let person: String
        let headline: String
        let purpose: String
    }

    private static let designs = [
        Design(intent: "business", title: "Business", person: "Jules",
               headline: "An idea worth sharing.", purpose: "A private hello about ideas and opportunities."),
        Design(intent: "social", title: "Social", person: "Maya",
               headline: "A little company.", purpose: "A private hello for coffee and conversation."),
        Design(intent: "activity", title: "Activity", person: "Sam",
               headline: "A plan to join.", purpose: "A private hello for a walk, workout, or game."),
        Design(intent: "dating", title: "Dating", person: "Riley",
               headline: "A spark to explore.", purpose: "A private hello to see if the interest is mutual."),
    ]

    override func setUpWithError() throws {
        try RunBudget.begin(self)
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PROXIMEET_WAVE_REVIEW"] == "1",
                          "Run with the Wave native review environment.")
    }

    /// Four independent outgoing invitations: their own category, words and recipient; sending never
    /// grants the sender an Accept action. Withdrawal closes the invitation and removes the person.
    func testAllFourOutgoingDesignsAndWithdrawal() throws {
        for design in Self.designs {
            let started = Date()
            let app = launch("wave-out-confirm", design)
            assertScreen("out-confirm", app)
            let readings = try readSnapshot(app)
            assertComposition(design, readings)
            assertDecoration(readings, intent: design.intent)
            capture("invitation-\(design.intent)", app)

            tap("wave.send", app)
            assertScreen("out-pending", app)
            assertLabel("wave.invitation.title", "Waiting for \(design.person).", app)
            assertLabel("wave.invitation.purpose",
                        "Only \(design.person) can accept.\nYou can withdraw at any time.", app)
            XCTAssertFalse(element("wave.accept", app).exists, "A sender must never accept their own invitation.")
            XCTAssertFalse(element("wave.send", app).exists, "A sent invitation cannot be sent again.")
            tap("wave.withdraw", app)
            assertScreen("out-withdrawn", app)
            assertClosed(app, person: design.person)
            tap("wave.leave", app)
            assertScreen("session-ended", app)
            assertClosed(app, person: design.person)
            app.terminate()
            print("PRIVATE_INVITATION_OUTGOING \(design.intent) elapsed=\(Date().timeIntervalSince(started))")
        }
    }

    /// Only an incoming recipient can Accept. Each intent can accept or decline, and leaving clears
    /// the accepted invitation. This exercises actual controls rather than launch-only state snapshots.
    func testAllFourIncomingConsentAndLeave() throws {
        for design in Self.designs {
            let started = Date()
            let accepted = launch("wave-in-review", design)
            assertScreen("in-review", accepted)
            assertLabel("wave.intent.\(design.intent)", design.title, accepted)
            assertLabel("wave.invitation.direction", "From \(design.person) to you (Alex). Incoming.", accepted)
            assertLabel("wave.invitation.purpose",
                        "Accept only if you want to.\nNo explanation needed to decline.", accepted)
            XCTAssertFalse(element("wave.send", accepted).exists)
            tap("wave.accept", accepted)
            assertScreen("in-accepted", accepted)
            assertLabel("wave.invitation.title", "You both said yes.", accepted)
            XCTAssertFalse(element("wave.accept", accepted).exists, "Acceptance is not repeatable.")
            XCTAssertFalse(element("wave.decline", accepted).exists, "Accepted invitations are no longer pending.")
            assertDecoration(try readSnapshot(accepted), intent: design.intent)
            capture("private-invitation-\(design.intent)-accepted", accepted)
            tap("wave.leave", accepted)
            assertScreen("session-ended", accepted)
            assertClosed(accepted, person: design.person)
            accepted.terminate()

            let declined = launch("wave-in-review", design)
            assertScreen("in-review", declined)
            tap("wave.decline", declined)
            assertScreen("in-declined", declined)
            assertClosed(declined, person: design.person)
            declined.terminate()
            print("PRIVATE_INVITATION_INCOMING \(design.intent) elapsed=\(Date().timeIntervalSince(started))")
        }
    }

    /// Run on the smaller device at Accessibility XXXL. The category and every line can be revealed
    /// without horizontal clipping, controls remain at least 44 pt, and Reduce Motion preserves the
    /// same send/withdraw/leave behavior. The separate pixel test checks the motion itself.
    func testLargestTextAndReducedMotionKeepAllFourReachable() throws {
        for design in Self.designs {
            let app = launch("wave-out-confirm", design, extra: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "-ProximeetReduceMotionPreview", "YES",
            ])
            assertScreen("out-confirm", app)
            assertComposition(design, try readSnapshot(app))
            for id in ["wave.intent.\(design.intent)", "wave.invitation.title", "wave.invitation.purpose", "wave.invitation.consent"] {
                let item = reveal(id, app)
                XCTAssertGreaterThan(item.frame.height, 0, "\(id) has laid-out text.")
                XCTAssertGreaterThanOrEqual(item.frame.minX, app.frame.minX - 1, "\(id) clips at the leading edge.")
                XCTAssertLessThanOrEqual(item.frame.maxX, app.frame.maxX + 1, "\(id) clips at the trailing edge.")
            }
            capture("private-invitation-\(design.intent)-largest-text", app)
            tap("wave.send", app)
            assertScreen("out-pending", app)
            tap("wave.withdraw", app)
            assertScreen("out-withdrawn", app)
            tap("wave.leave", app)
            assertScreen("session-ended", app)
            assertClosed(app, person: design.person)
            app.terminate()
        }
    }

    private func launch(_ fixture: String, _ design: Design, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", fixture, "-ProximeetFixtureBand", design.intent,
                               "-ProximeetFixtureSignal", "chatFirst"] + extra
        app.launch()
        lastTap = .distantPast
        return app
    }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func assertScreen(_ screen: String, _ app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element("wave.screen.\(screen)", app).waitForExistence(timeout: 15),
                      "Expected \(screen).", file: file, line: line)
    }

    private func assertLabel(_ id: String, _ expected: String, _ app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(id).", file: file, line: line)
        XCTAssertEqual(item.label, expected, file: file, line: line)
    }

    /// A fresh snapshot is shared only by static checks in this settled screen. It never crosses a
    /// tap, launch or transition; waits, scrolling, hit testing and every tap remain live queries.
    private func readSnapshot(_ app: XCUIApplication) throws -> [any XCUIElementSnapshot] {
        var remaining: [any XCUIElementSnapshot] = [try app.snapshot()]
        var result: [any XCUIElementSnapshot] = []
        while let node = remaining.popLast() {
            result.append(node)
            remaining.append(contentsOf: node.children.reversed())
        }
        return result
    }

    private func assertSnapshotLabel(_ id: String, _ expected: String, _ nodes: [any XCUIElementSnapshot],
                                     file: StaticString = #filePath, line: UInt = #line) {
        let item = nodes.first { $0.identifier == id }
        XCTAssertTrue(item != nil, "Missing \(id).", file: file, line: line)
        XCTAssertEqual(item?.label, expected, file: file, line: line)
    }

    private func assertComposition(_ design: Design, _ nodes: [any XCUIElementSnapshot]) {
        assertSnapshotLabel("wave.brand", "Private invitation", nodes)
        assertSnapshotLabel("wave.intent.\(design.intent)", design.title, nodes)
        assertSnapshotLabel("wave.demoBadge", "Demo", nodes)
        assertSnapshotLabel("wave.invitation.title", design.headline, nodes)
        assertSnapshotLabel("wave.invitation.purpose", design.purpose, nodes)
        assertSnapshotLabel("wave.invitation.consent", "\(design.person) chooses whether to accept.", nodes)
        assertSnapshotLabel("wave.invitation.direction", "From you (Alex) to \(design.person). Outgoing.", nodes)
        assertSnapshotLabel("wave.send", "Send private invitation", nodes)
        XCTAssertFalse(nodes.contains { $0.identifier == "wave.accept" })
        XCTAssertTrue(nodes.first { $0.identifier == "wave.boundary" }?.label.contains("Nothing is sent.") == true,
                      "The demo boundary stays visible.")
    }

    /// Empty structural containers may appear in XCTest even when hidden from accessibility. They
    /// must have no words, children, control role or selection. Physical VoiceOver remains separate.
    private func assertDecoration(_ nodes: [any XCUIElementSnapshot], intent: String) {
        let found = nodes.filter { $0.identifier.hasPrefix("wave.artwork.") || $0.identifier == "wave.rings" }
        // Record before checking so a child/label failure carries its exact subtree, not merely a line
        // number. This is structural XCTest evidence, not proof of physical VoiceOver focus behavior.
        var details = ["Intent: \(intent). Decorative roots: \(found.count)."]
        for root in found {
            var subtree: [(node: any XCUIElementSnapshot, depth: Int)] = [(root, 0)]
            while let item = subtree.popLast() {
                let node = item.node
                details.append(String(repeating: "  ", count: item.depth)
                               + "role=\(node.elementType) id=\(String(reflecting: node.identifier)) "
                               + "label=\(String(reflecting: node.label)) title=\(String(reflecting: node.title)) "
                               + "value=\(String(reflecting: node.value)) selected=\(node.isSelected) "
                               + "children=\(node.children.count) frame=\(node.frame)")
                for child in node.children.reversed() { subtree.append((child, item.depth + 1)) }
            }
        }
        let diagnostic = XCTAttachment(string: details.joined(separator: "\n"))
        diagnostic.name = "private-invitation-\(intent)-artwork-structure"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertLessThanOrEqual(found.count, 1, "At most one decorative artwork boundary is present.")
        for art in found {
            XCTAssertEqual(art.identifier, "wave.artwork.\(intent)")
            XCTAssertEqual(art.elementType, .other)
            XCTAssertTrue(art.children.isEmpty)
            XCTAssertTrue(art.label.isEmpty)
            XCTAssertTrue(art.title.isEmpty)
            XCTAssertTrue(art.value == nil || (art.value as? String)?.isEmpty == true)
            XCTAssertFalse(art.isSelected)
        }
    }

    private func assertClosed(_ app: XCUIApplication, person: String) {
        for id in ["wave.invitation", "wave.accept", "wave.send", "wave.withdraw", "wave.aboutChat"] {
            XCTAssertFalse(element(id, app).exists, "Closed invitation still exposes \(id).")
        }
        let expression = "(?i).*\\b" + NSRegularExpression.escapedPattern(for: person) + "\\b.*"
        let people = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", expression))
        XCTAssertEqual(people.count, 0, "Closed invitations must remove the counterpart’s identity.")
    }

    @discardableResult
    private func reveal(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(id).")
        let top = app.frame.minY + 100
        let footer = element("wave.leave", app)
        for _ in 0..<14 {
            let frame = item.frame
            let bottom = footer.exists && id != "wave.leave" ? footer.frame.minY - 8 : app.frame.maxY - 30
            if item.isHittable, frame.maxY > top, frame.minY < bottom,
               (frame.height > bottom - top || (frame.minY >= top && frame.maxY <= bottom)) { return item }
            let scroller = app.scrollViews.firstMatch
            guard scroller.exists else { break }
            if frame.minY < top { scroller.swipeDown(velocity: .slow) }
            else { scroller.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(item.isHittable, "\(id) must remain reachable by scrolling.")
        return item
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let item = reveal(id, app)
        XCTAssertTrue(item.isEnabled, "\(id) must be enabled.")
        XCTAssertGreaterThanOrEqual(item.frame.width, 44 - 1e-6, "\(id) target width.")
        XCTAssertGreaterThanOrEqual(item.frame.height, 44 - 1e-6, "\(id) target height.")
        // Honor the app's repeat-tap guard when two distinct actions occupy the same place.
        let remaining = 0.85 - Date().timeIntervalSince(lastTap)
        if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(remaining)) }
        item.tap()
        lastTap = Date()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
