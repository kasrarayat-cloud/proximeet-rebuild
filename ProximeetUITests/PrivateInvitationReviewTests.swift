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
               headline: "Good company starts here.", purpose: "A private hello for coffee and conversation."),
        Design(intent: "activity", title: "Activity", person: "Sam",
               headline: "Make a plan. Move together.", purpose: "A private hello for a walk, workout, or game."),
        Design(intent: "dating", title: "Dating", person: "Riley",
               headline: "A little chemistry.", purpose: "A private hello to see if the interest is mutual."),
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
            capture("private-invitation-\(design.intent)-largest-text-initial", app)
            let initialScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            initialScreen.name = "private-invitation-\(design.intent)-largest-text-initial-full-screen"
            initialScreen.lifetime = .keepAlways
            add(initialScreen)
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

    /// The 30 October design has visible decorative motion before any Send or Accept. Compare actual
    /// composited screen pixels (not app-scoped captures, which can omit the SceneKit layer) inside
    /// the artwork only. Three readings avoid mistaking one coincident loop phase for a still object.
    /// Reduced Motion gets the same content and controls, with every sampled pose staying still.
    func testAllFourIdleArtworkMovesAndReducedMotionStaysStill() throws {
        for design in Self.designs {
            for reduced in [false, true] {
                let app = launch("wave-out-confirm", design, extra: reduced
                                 ? ["-ProximeetReduceMotionPreview", "YES"] : [])
                defer { app.terminate() }
                assertScreen("out-confirm", app)
                try XCTSkipUnless(app.frame.size == CGSize(width: 440, height: 956),
                                  "Rendered artwork comparisons require the 440 × 956 review phone.")
                assertComposition(design, try readSnapshot(app))
                let region = try InvitationArtworkPixels.region(in: app)
                RunLoop.current.run(until: Date().addingTimeInterval(1.2))
                var frames: [InvitationArtworkPixels] = []
                for index in 0..<3 {
                    if index > 0 { RunLoop.current.run(until: Date().addingTimeInterval(1.2)) }
                    let shot = XCUIScreen.main.screenshot()
                    let frame = try InvitationArtworkPixels(shot, pointWidth: app.frame.width, region: region)
                    XCTAssertGreaterThan(frame.visibleFraction, 0.02,
                                         "\(design.intent): the actual sculpted artwork must be rendered.")
                    frames.append(frame)
                    let attachment = XCTAttachment(screenshot: shot)
                    attachment.name = "private-invitation-\(design.intent)-\(reduced ? "reduced" : "moving")-idle-\(index)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                let differences = frames.dropFirst().map { frames[0].difference(from: $0) }
                let note = XCTAttachment(string: "intent=\(design.intent), reduced=\(reduced), region=\(region), "
                    + "visible=\(frames.map(\.visibleFraction)), changedRGBOver12=\(differences)")
                note.name = "private-invitation-\(design.intent)-idle-motion-pixels"
                note.lifetime = .keepAlways
                add(note)
                if reduced {
                    for difference in differences {
                        XCTAssertLessThan(difference, 0.001,
                                          "\(design.intent): Reduce Motion must stop decorative movement.")
                    }
                } else {
                    XCTAssertGreaterThan(differences.max() ?? 0, 0.005,
                                         "\(design.intent): artwork must visibly move before Send or Accept.")
                }
                assertScreen("out-confirm", app)
                XCTAssertTrue(element("wave.send", app).exists, "Idle motion never sends an invitation.")
                XCTAssertFalse(element("wave.accept", app).exists, "Idle motion never grants sender acceptance.")
                tap("wave.leave", app)
                assertScreen("session-ended", app)
                assertClosed(app, person: design.person)
                print("PRIVATE_INVITATION_IDLE \(design.intent) reduced=\(reduced) differences=\(differences)")
            }
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
        XCTAssertEqual(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "wave.artwork.")).count, 0,
                       "Closed invitations must remove their decorative scene as well as their words.")
    }

    /// Fourteen looks, as before, but each drag travels only the distance required to reveal the
    /// target. Whole-view swipes overshot a fitting AX XXXL title and alternated up/down. Snapshot
    /// geometry is local to one look; every new drag gets a new snapshot and final hit testing is live.
    @discardableResult
    private func reveal(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        let item = element(id, app)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(id).")
        var previousTop: CGFloat?
        var previousDirection: CGFloat = 0
        var stalled = 0
        for attempt in 0..<14 {
            guard let look = revealLook(id, app) else { break }
            let frame = look.target
            let fixed = look.scroller == nil || id == "wave.leave"
            let top = fixed ? look.screen.minY : max(look.screen.minY + 100, look.scroller?.minY ?? 0)
            let bottom = id != "wave.leave" && look.footer != nil
                ? look.footer!.minY - 8 : look.screen.maxY - 30
            let tall = frame.height > bottom - top
            let visible = frame.maxY > top && frame.minY < bottom
                && (tall || (frame.minY >= top && frame.maxY <= bottom))
            print("PRIVATE_INVITATION_SCROLL \(id) look=\(attempt + 1) target=\(frame) viewport=\(top)...\(bottom)")
            if visible {
                XCTAssertTrue(item.isHittable, "\(id) must remain reachable by scrolling.")
                return item
            }
            guard let scroller = look.scroller, !fixed else { break }
            if let previousTop {
                let progress = (previousTop - frame.minY) * previousDirection
                stalled = progress < 2 ? stalled + 1 : 0
                if stalled >= 2 {
                    XCTFail("\(id) did not move after two measured drags; target=\(frame).")
                    return item
                }
            }
            let fingerUp = frame.minY >= top
            let distance: CGFloat
            if fingerUp {
                distance = tall ? frame.minY - (bottom - 44) : frame.maxY - bottom + 8
            } else {
                distance = top - frame.minY + 8
            }
            let bandTop = max(top, scroller.minY) + 12
            let bandBottom = min(bottom, scroller.maxY) - 12
            guard bandBottom - bandTop >= 40 else {
                XCTFail("\(id) has no safe scroll viewport: \(bandTop)...\(bandBottom).")
                return item
            }
            // The 0.2-s hold before release removes swipe momentum. The 24-pt minimum clears the
            // scroll recognizer's threshold; the target's fitting bounds then stop the next look.
            let travel = min(max(distance, 24), min(280, bandBottom - bandTop))
            let xs = [min(scroller.maxX, look.screen.maxX) - 16, scroller.midX,
                      max(scroller.minX + 48, look.screen.minX + 48)]
            let startRange: ClosedRange<CGFloat> = fingerUp
                ? (bandTop + travel)...bandBottom : bandTop...(bandBottom - travel)
            let ys = [fingerUp ? startRange.upperBound : startRange.lowerBound,
                      (startRange.lowerBound + startRange.upperBound) / 2,
                      fingerUp ? startRange.lowerBound : startRange.upperBound]
            var start: CGPoint?
            for x in xs where start == nil {
                for y in ys {
                    let point = CGPoint(x: x, y: y)
                    guard scroller.contains(point), x > look.screen.minX + 40,
                          !look.controls.contains(where: { $0.insetBy(dx: -10, dy: -10).contains(point) })
                    else { continue }
                    start = point
                    break
                }
            }
            guard let start else {
                XCTFail("\(id) has no safe scroll touch point away from controls.")
                return item
            }
            let end = CGPoint(x: start.x, y: start.y + (fingerUp ? -travel : travel))
            let remaining = 0.7 - Date().timeIntervalSince(lastTap)
            if remaining > 0 { RunLoop.current.run(until: Date().addingTimeInterval(remaining)) }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: start.x, dy: start.y))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            lastTap = Date()
            previousTop = frame.minY
            previousDirection = fingerUp ? 1 : -1
            print("PRIVATE_INVITATION_SCROLL \(id) drag=\(fingerUp ? "up" : "down") distance=\(travel)")
        }
        XCTAssertTrue(item.isHittable, "\(id) must remain reachable by scrolling.")
        return item
    }

    private struct InvitationRevealLook {
        let screen: CGRect
        let target: CGRect
        let scroller: CGRect?
        let footer: CGRect?
        let controls: [CGRect]
    }

    private func revealLook(_ id: String, _ app: XCUIApplication) -> InvitationRevealLook? {
        do {
            let root = try app.snapshot()
            var pending: [(node: any XCUIElementSnapshot, scroller: CGRect?)] = [(root, nil)]
            var target: (frame: CGRect, scroller: CGRect?)?
            var footer: CGRect?
            var controls: [CGRect] = []
            while let entry = pending.popLast() {
                let node = entry.node
                if node.identifier == id && target == nil { target = (node.frame, entry.scroller) }
                if node.identifier == "wave.leave" { footer = node.frame }
                if node.elementType == .button || node.elementType == .link || node.elementType == .textField {
                    controls.append(node.frame)
                }
                let scroller = node.elementType == .scrollView ? node.frame : entry.scroller
                for child in node.children.reversed() { pending.append((child, scroller)) }
            }
            guard let target else {
                XCTFail("Missing \(id) in the fresh scroll snapshot.")
                return nil
            }
            return InvitationRevealLook(screen: root.frame, target: target.frame, scroller: target.scroller,
                                        footer: footer, controls: controls)
        } catch {
            XCTFail("Could not measure \(id) for scrolling: \(error).")
            return nil
        }
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

/// A crop of the device's composited screen, shared by idle-motion and acceptance checks. The scene
/// is deliberately inaccessible, so its bounds come from the adjacent readable direction line and
/// the specified 376 × 220 canvas. No clock, title, control or changing state copy enters the crop.
@MainActor
struct InvitationArtworkPixels {
    private let rgba: [UInt8]
    private let width: Int
    private let height: Int

    static func region(in app: XCUIApplication) throws -> CGRect {
        let direction = app.descendants(matching: .any)
            .matching(identifier: "wave.invitation.direction").firstMatch
        XCTAssertTrue(direction.waitForExistence(timeout: 5), "The invitation direction anchors its artwork.")
        let width = min(376, max(0, app.frame.width - 64))
        let height = 220 * min(1, width / 376)
        let art = CGRect(x: app.frame.midX - width / 2,
                         y: direction.frame.minY - 16 - height, width: width, height: height)
        guard width > 0, app.frame.contains(art), direction.frame.height > 0 else {
            XCTFail("The full invitation artwork must be on screen for pixel comparison: \(art).")
            throw PixelError.invalidRegion
        }
        return art.insetBy(dx: 8, dy: 8)
    }

    init(_ screenshot: XCUIScreenshot, pointWidth: CGFloat, region: CGRect) throws {
        let screen = try XCTUnwrap(screenshot.image.cgImage, "No rendered device screenshot.")
        guard pointWidth > 0 else { throw PixelError.invalidRegion }
        let scale = CGFloat(screen.width) / pointWidth
        let bounds = CGRect(x: region.minX * scale, y: region.minY * scale,
                            width: region.width * scale, height: region.height * scale).integral
        let image = try XCTUnwrap(screen.cropping(to: bounds), "Could not crop the actual artwork pixels.")
        width = image.width
        height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            XCTFail("Could not decode the actual artwork pixels.")
            throw PixelError.decodeFailed
        }
        rgba = buffer
    }

    /// Bright surface pixels distinguish an actual object from an unrendered black SceneKit surface.
    var visibleFraction: Double {
        var visible = 0
        for i in stride(from: 0, to: rgba.count, by: 4) {
            if max(rgba[i], rgba[i + 1], rgba[i + 2]) >= 48 { visible += 1 }
        }
        return Double(visible) / Double(width * height)
    }

    /// RGB deltas greater than 12 ignore tiny antialiasing differences while retaining visible drift.
    func difference(from other: Self, threshold: Int = 12) -> Double {
        guard width == other.width, height == other.height else {
            XCTFail("Artwork crops must have the same geometry.")
            return 1
        }
        var changed = 0
        for i in stride(from: 0, to: rgba.count, by: 4) {
            if (0..<3).contains(where: { abs(Int(rgba[i + $0]) - Int(other.rgba[i + $0])) > threshold }) {
                changed += 1
            }
        }
        return Double(changed) / Double(width * height)
    }

    /// A dissolve stays between the separate and accepted pixel colors. A translated object draws
    /// beyond that envelope. This replaces obsolete ring-coordinate probes with the same no-travel
    /// check for the redesigned petals, while allowing the specified short reduced-motion dissolve.
    func outsideDissolveEnvelope(from before: Self, to after: Self) -> Double {
        guard width == before.width, height == before.height,
              width == after.width, height == after.height else {
            XCTFail("Acceptance crops must have the same geometry.")
            return 1
        }
        var outside = 0
        for i in stride(from: 0, to: rgba.count, by: 4) {
            if (0..<3).contains(where: { component in
                let value = Int(rgba[i + component])
                let low = min(Int(before.rgba[i + component]), Int(after.rgba[i + component])) - 18
                let high = max(Int(before.rgba[i + component]), Int(after.rgba[i + component])) + 18
                return value < low || value > high
            }) { outside += 1 }
        }
        return Double(outside) / Double(width * height)
    }

    private enum PixelError: Error { case invalidRegion, decodeFailed }
}
