import UIKit
import XCTest

/// The Places correction (after build 6ab8639c): the adaptive ticket footer, one-stage back
/// gestures and where a stage starts.
///
/// Skipped unless the test runner's environment has `PROXIMEET_PLACES_REVIEW=1`. Real taps and
/// real edge swipes. Every test here starts from a DEBUG fixture (`-ProximeetFixture places…`, a
/// direct launch through the same Birthday gate, Pass, Guest List card, Wristband and Signal) and
/// its captures end in "fixture". The real onboarding → Signal → Places entry is Signal's own
/// recorded-route test (`SignalReviewTests.testWalkthroughRealJourney`), run beside these.
///
/// The footer is checked as drawn, not only as labelled: the schedule's and View place's frames
/// never meet, both stay inside the ticket's column, the schedule's ink stays inside its frame, the
/// gap a stacked footer leaves is clear, the button's dark face is drawn where it is, and the ticket
/// (its paper) continues below the button. The approved 440-pt footer is checked to the point.
@MainActor
final class PlacesCorrectionTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_PLACES_REVIEW"

    private struct VenueFacts {
        let category: String
        let key: String
        let name: String
        let schedule: String
        /// The schedule's natural width at the default text size (Manrope SemiBold 14, from the
        /// bundled font's advance widths). Side by side needs it + 8 + 140 (View place) within the
        /// column (the width − 64, at most 376, less 40): on 440 pt every footer fits; on 390 pt
        /// (a 286-pt column) only Fieldwork's, 293.4, does not.
        let naturalWidth: CGFloat
    }

    private static let venues = [
        VenueFacts(category: "now", key: "common-ground", name: "Common Ground", schedule: "Today · 6–10 pm", naturalWidth: 105.1),
        VenueFacts(category: "later", key: "afterglow", name: "Afterglow", schedule: "Tonight · 9–11 pm", naturalWidth: 113.2),
        VenueFacts(category: "upcoming", key: "fieldwork", name: "Fieldwork", schedule: "Saturday · 10 am–1 pm", naturalWidth: 145.4),
    ]

    private static func venue(_ category: String) -> VenueFacts {
        venues.first { $0.category == category } ?? venues[0]
    }

    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    /// 44 pt, less floating-point error, for every 44-pt target check: build 6ab88011 measured a
    /// 44-pt tab as 43.99999999999997, 4 ULPs below 44, once a fractional scroll offset had moved it.
    /// 1e-6 pt is far above that error and far below anything that can be drawn.
    private static let minimumTarget: CGFloat = 44 - 1e-6

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Places review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("PLACES_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded correction walkthrough

    /// Direct launch (fixture `places`, Social, Chat first, Upcoming), recorded on the smaller
    /// iPhone: Fieldwork's View place starts below the fold; the page scrolls until the whole
    /// button shows above the Back area; a real tap on it opens Fieldwork's detail at its
    /// beginning. A back swipe that is not completed leaves the detail; a completed one returns to
    /// Upcoming with View place in view. Now, View place, Preview check-in: the explanation starts
    /// at its heading; a cancelled swipe, then completed swipes, one stage each: Common Ground's
    /// detail, Now, and Signal, with both choices kept; Continue preview returns to Now.
    func testCorrectionWalkthroughScrollingAndBackGestures() throws {
        print("PLACES_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        let app = launch(fixture: "places", category: "upcoming")
        let places = CorrectionPlaces(app: app)
        let signal = CorrectionSignal(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        print("PLACES_WALKTHROUGH_APP_READY \(Date().timeIntervalSince1970)")
        let restingHeader = places.back.frame.minY
        hold(1.2)
        capture("correction-walkthrough-upcoming-initial", app)

        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app), "View place can be scrolled fully into view.")
        hold(1.0)
        assertViewPlaceUsable(places, app, "Fieldwork, scrolled")
        capture("correction-walkthrough-upcoming-footer-scrolled", app)
        places.viewPlace.tap()
        waitForLabel(places.name, "Fieldwork")
        hold(1.2)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "Fieldwork's detail")
        capture("correction-walkthrough-fieldwork-detail-start", app)

        edgeSwipe(app, completing: false)
        hold(1.0)
        XCTAssertEqual(places.name.label, "Fieldwork", "A swipe that is not completed leaves the detail.")
        XCTAssertFalse(places.headline.exists)
        edgeSwipe(app, completing: true)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(1.2)
        XCTAssertTrue(places.tab("upcoming").isSelected, "The swipe returns to the originating category.")
        assertViewPlaceUsable(places, app, "Back to Upcoming")
        capture("correction-walkthrough-back-to-upcoming", app)

        choose("now", places)
        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app))
        places.viewPlace.tap()
        waitForLabel(places.name, "Common Ground")
        hold(0.8)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(1.2)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "The explanation")
        capture("correction-walkthrough-explanation-start", app)
        edgeSwipe(app, completing: false)
        hold(0.8)
        XCTAssertTrue(places.explanationHeadline.exists, "A swipe that is not completed leaves the explanation.")
        edgeSwipe(app, completing: true)
        waitForLabel(places.name, "Common Ground")
        hold(1.0)
        XCTAssertFalse(places.explanationHeadline.exists)
        edgeSwipe(app, completing: true)
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("now").isSelected)
        hold(1.0)
        edgeSwipe(app, completing: true)
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Social band · Chat first", "Signal, with both choices kept.")
        hold(1.2)
        capture("correction-walkthrough-back-to-signal", app)
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("now").isSelected, "Places reopens at the category it was left on.")
        hold(1.2)
    }

    // MARK: - The footer

    /// Direct launch (fixture `places`, Social, Chat first) at the default text size: each venue's
    /// footer on this phone. On 440 pt every schedule sits beside View place, as approved (the
    /// button 140 × 44 at (248, 754)); on 390 pt Fieldwork's schedule stacks above it and the
    /// others stay side by side. Fieldwork's View place, scrolled fully into view, is tapped and
    /// opens its detail at the beginning.
    func testFootersAtNormalTextFitOrStack() throws {
        let app = launch(fixture: "places")
        let places = CorrectionPlaces(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        let restingHeader = places.back.frame.minY
        let width = Int(app.frame.width.rounded())
        let column = min(376, app.frame.width - 64) - 40
        for venue in Self.venues {
            choose(venue.category, places)
            XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app, clearance: 12),
                          "\(venue.name): View place reachable.")
            hold(0.5)
            let stacked = venue.naturalWidth + 8 + 140 > column
            checkFooter(app, places, venue, "\(venue.name), default text, \(width) pt", expectStacked: stacked)
            if width == 440 {
                checkApprovedFooter(places, venue)
            }
            capture("correction-footer-\(venue.key)-normal-\(width)pt-fixture", app)
        }
        // A real tap on the visible button.
        assertViewPlaceUsable(places, app, "Fieldwork, default text")
        places.viewPlace.tap()
        waitForLabel(places.name, "Fieldwork")
        hold(0.6)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "Fieldwork's detail after View place")
        capture("correction-footer-fieldwork-opened-normal-\(width)pt-fixture", app)
    }

    /// Direct launch at the largest accessibility text size: every footer stacks, with the whole
    /// schedule above View place and nothing covered; each ticket grows and scrolls. Fieldwork's
    /// View place is tapped; its detail opens at the beginning, and Back to places returns to
    /// Upcoming with View place in view.
    func testFootersAtLargestTextStackAndStayReadable() throws {
        let app = launch(fixture: "places", extra: Self.largestText)
        let places = CorrectionPlaces(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        let restingHeader = places.back.frame.minY
        XCTAssertGreaterThan(places.headline.frame.height, 112 + 10, "The largest text size must be applied.")
        let width = Int(app.frame.width.rounded())
        for venue in Self.venues {
            XCTAssertTrue(scrollIntoView(places.tab(venue.category), bar: places.secondary, app))
            choose(venue.category, places)
            XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app, clearance: 12),
                          "\(venue.name): View place reachable.")
            hold(0.5)
            checkFooter(app, places, venue, "\(venue.name), largest text, \(width) pt", expectStacked: true)
            capture("correction-footer-\(venue.key)-largest-\(width)pt-fixture", app)
        }
        assertViewPlaceUsable(places, app, "Fieldwork, largest text")
        places.viewPlace.tap()
        waitForLabel(places.name, "Fieldwork")
        hold(0.6)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "Fieldwork's detail at the largest text")
        capture("correction-footer-fieldwork-opened-largest-\(width)pt-fixture", app)
        XCTAssertTrue(places.detailSecondary.isHittable)
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.6)
        XCTAssertTrue(places.tab("upcoming").isSelected, "Back to places keeps Upcoming.")
        assertViewPlaceUsable(places, app, "Back to Upcoming at the largest text")
        capture("correction-footer-back-to-upcoming-largest-\(width)pt-fixture", app)
    }

    // MARK: - Where a stage starts

    /// Direct launch at the largest text size, Now: browsing is scrolled down to View place; the
    /// detail it opens starts at its beginning (the header and the venue), not at browsing's
    /// offset; its last line is reachable. Preview check-in: the explanation starts at its heading;
    /// its privacy and demo lines are reachable. Back to place: the detail from its beginning. Back
    /// to places: Now, with View place in view. Explore other places: Now from the top.
    func testDetailAndExplanationStartAtTheirBeginning() throws {
        let app = launch(fixture: "places", extra: Self.largestText)
        let places = CorrectionPlaces(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        let restingHeader = places.back.frame.minY
        let width = Int(app.frame.width.rounded())
        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app))
        hold(0.5)
        XCTAssertLessThan(places.back.frame.minY, restingHeader - 40, "Browsing is scrolled before View place.")
        capture("correction-entry-browse-scrolled-\(width)pt-largest-fixture", app)
        places.viewPlace.tap()
        waitForLabel(places.name, "Common Ground")
        hold(0.8)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "Common Ground's detail")
        capture("correction-entry-detail-start-\(width)pt-largest-fixture", app)
        XCTAssertTrue(scrollIntoView(places.lastLine, bar: places.primary, app), "The detail's last line is reachable.")
        XCTAssertEqual(places.lastLine.label, "Sample session · not a reservation")
        capture("correction-entry-detail-end-\(width)pt-largest-fixture", app)

        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(0.8)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "The explanation")
        capture("correction-entry-explanation-start-\(width)pt-largest-fixture", app)
        for element in [places.presence, places.demoLine] {
            XCTAssertTrue(scrollIntoView(element, bar: places.explore, app), "\(element.identifier) is reachable.")
        }
        XCTAssertEqual(places.presence.label, "You stay private until both checks pass.")
        XCTAssertEqual(places.demoLine.label, "Demo · no location or camera used.")
        capture("correction-entry-explanation-end-\(width)pt-largest-fixture", app)

        places.backToPlace.tap()
        waitForLabel(places.name, "Common Ground")
        hold(0.6)
        assertStartsAtBeginning(places, restingHeader: restingHeader, "Common Ground's detail, back from the explanation")
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.6)
        XCTAssertTrue(places.tab("now").isSelected)
        assertViewPlaceUsable(places, app, "Back to Now")
        capture("correction-entry-back-to-now-\(width)pt-largest-fixture", app)

        places.viewPlace.tap()
        waitForLabel(places.name, "Common Ground")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.explore.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.6)
        XCTAssertTrue(places.tab("now").isSelected)
        XCTAssertEqual(places.back.frame.minY, restingHeader, accuracy: 1.5, "Explore other places shows Now from the top.")
    }

    // MARK: - Back, by control and by gesture

    /// Direct launch (fixture `places`, Social, Chat first, Later) at the default text size.
    /// Every stage's header Back, bottom Back and a real edge swipe are checked separately and land
    /// on the same place: Afterglow's detail → Later; the explanation → Common Ground's detail;
    /// browsing → Signal (both choices kept; Continue preview reopens the category left). A swipe
    /// that is not completed, and a swipe that starts mid-screen, change nothing. After changing the
    /// band to Dating through Signal and the Wristband, Common Ground's detail says "Not available
    /// for Dating", and each completed swipe goes back exactly one stage. A double tap on the header
    /// Back stops one stage up. Last, with the app's Reduce Motion preview flag, a swipe from a detail
    /// still goes back one stage and an uncompleted one still changes nothing.
    ///
    /// On browsing, a detail and the explanation there is exactly one `places.screen` container, and
    /// the stage's headline (or venue name), its header Back and its bottom actions are found by
    /// queries scoped to it: the container that owns Places' VoiceOver escape action is an ancestor
    /// of the stage's elements. That is the structure escape relies on, not escape itself: XCUITest
    /// cannot perform VoiceOver's escape, and VoiceOver does not run in the Simulator.
    func testBackGesturesMatchTheBackControls() throws {
        let app = launch(fixture: "places", category: "later")
        let places = CorrectionPlaces(app: app)
        let signal = CorrectionSignal(app: app)
        let band = CorrectionWristband(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        assertInsideScreen(app, ["places.headline", "places.back", "places.viewPlace", "places.secondary"], "Browsing")

        // A detail: a cancelled swipe, a mid-screen swipe, then a completed swipe.
        openDetail(places, app, "Afterglow")
        assertInsideScreen(app, ["place.name", "places.back", "place.primary", "place.secondary"], "Afterglow's detail")
        edgeSwipe(app, completing: false)
        hold(0.6)
        XCTAssertEqual(places.name.label, "Afterglow", "Not completed: still Afterglow's detail.")
        XCTAssertEqual(places.back.frame.minX, 24, accuracy: 1.5, "Not completed: the screen is back in place.")
        midScreenSwipe(app)
        hold(0.6)
        XCTAssertEqual(places.name.label, "Afterglow", "A swipe from mid-screen does not leave the detail.")
        XCTAssertFalse(signal.headline.exists, "No swipe skips Places to Signal.")
        capture("correction-gesture-detail-after-cancel-fixture", app)
        edgeSwipe(app, completing: true)
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("later").isSelected, "Swipe from a detail: its category, Later.")
        capture("correction-gesture-detail-to-later-fixture", app)

        // The same destination by the header's Back and by Back to places.
        openDetail(places, app, "Afterglow")
        places.back.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("later").isSelected, "Header Back from a detail: Later.")
        openDetail(places, app, "Afterglow")
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("later").isSelected, "Back to places: Later.")

        // The explanation: a cancelled swipe, then a completed one; then the header Back and Back
        // to place; then Explore other places.
        choose("now", places)
        openDetail(places, app, "Common Ground")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        assertInsideScreen(app, ["explanation.headline", "places.back", "explanation.primary", "explanation.secondary"],
                           "The explanation")
        edgeSwipe(app, completing: false)
        hold(0.6)
        XCTAssertTrue(places.explanationHeadline.exists, "Not completed: still the explanation.")
        midScreenSwipe(app)
        hold(0.6)
        XCTAssertTrue(places.explanationHeadline.exists, "A swipe from mid-screen does not leave the explanation.")
        edgeSwipe(app, completing: true)
        waitForLabel(places.name, "Common Ground")
        XCTAssertFalse(places.explanationHeadline.exists)
        XCTAssertFalse(places.headline.exists, "Swipe from the explanation: Common Ground's detail, not browsing.")
        capture("correction-gesture-explanation-to-detail-fixture", app)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.back.doubleTap()
        waitForLabel(places.name, "Common Ground")
        hold(0.8)
        XCTAssertFalse(places.headline.exists, "A double tap on the header Back from the explanation stops at the detail.")
        XCTAssertFalse(places.explanationHeadline.exists)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.backToPlace.tap()
        waitForLabel(places.name, "Common Ground")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.explore.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("now").isSelected, "Explore other places: Now.")

        // Browsing: a cancelled swipe, then a completed one to the actual Signal; the category
        // left is the one Continue preview reopens.
        choose("upcoming", places)
        edgeSwipe(app, completing: false)
        hold(0.6)
        XCTAssertTrue(places.headline.exists, "Not completed: still browsing.")
        XCTAssertTrue(places.tab("upcoming").isSelected)
        edgeSwipe(app, completing: true)
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Social band · Chat first", "Swipe from browsing: Signal, both kept.")
        XCTAssertTrue(signal.row("chatFirst").isSelected)
        capture("correction-gesture-browse-to-signal-fixture", app)
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("upcoming").isSelected, "Continue preview reopens Upcoming.")
        places.secondary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        places.back.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")

        // A changed band after gesture navigation: eligibility is recomputed; one stage per swipe.
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("dating").tap()
        XCTAssertTrue(waitFor(band.tile("dating"), selected: true))
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Dating band · Chat first", "The approach is kept.")
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertTrue(places.tab("upcoming").isSelected)
        choose("now", places)
        openDetail(places, app, "Common Ground")
        XCTAssertEqual(places.primary.label, "Not available for Dating")
        XCTAssertFalse(places.primary.isEnabled)
        XCTAssertEqual(places.lastLine.label, "Your Dating band doesn’t match this session.")
        capture("correction-gesture-dating-common-ground-fixture", app)
        edgeSwipe(app, completing: true)
        waitForLabel(places.headline, "Find your kind of place.")
        XCTAssertFalse(signal.headline.exists, "One swipe, one stage: browsing, not Signal.")
        edgeSwipe(app, completing: true)
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Dating band · Chat first")
        assertNothingConferred(app)
        app.terminate()

        // The app's Reduce Motion preview: the swipe still goes back one stage, and a swipe that is
        // not completed still changes nothing.
        let reduced = launch(fixture: "place-detail", category: "later", extra: ["-ProximeetReduceMotionPreview", "YES"])
        let still = CorrectionPlaces(app: reduced)
        waitForLabel(still.name, "Afterglow")
        edgeSwipe(reduced, completing: false)
        hold(0.6)
        XCTAssertEqual(still.name.label, "Afterglow", "Reduce Motion, not completed: still the detail.")
        edgeSwipe(reduced, completing: true)
        waitForLabel(still.headline, "Find your kind of place.")
        XCTAssertTrue(still.tab("later").isSelected, "Reduce Motion, completed: Later.")
        capture("correction-gesture-reduce-motion-to-later-fixture", reduced)
    }

    // MARK: - Scroll diagnosis

    /// Diagnosis only, never required (its manifest kind is "extra"): how drags scroll Places at the
    /// largest text on this phone. It records and does not judge, so it passes whenever the app
    /// launches and each stage opens. Browsing (fixture `places`, Now) and Common Ground's detail
    /// (fixture `place-detail`, Now) are launched fresh, at their top, for each pattern of five drags
    /// from y 217 up to 102 (press 0.05 s, slow, held 0.2 s before release):
    /// - "edge-fast", the old helper's: 0.96 of the width across, the next drag at once;
    /// - "edge-spaced", the same with 1.5 s between one drag's release and the next;
    /// - "column-spaced", in the page's column on a point that is not a control, chosen as
    ///   `scrollTouchPoint` chooses it (browsing's ticket only when nothing else is free), from the
    ///   same height when it can, 0.7 s apart;
    /// - last, on the detail, "column-spaced-keep-pop": the same with `-ProximeetPlacesKeepContentPop
    ///   YES`, the DEBUG switch that leaves iOS 26's swipe-from-anywhere pop on in a detail.
    /// For every drag the header's Back (it scrolls with the content) is read before and after, and a
    /// `PLACES_PROBE` line printed: its gap is the time since the previous release (for the first
    /// drag, since the stage showed). One note per stage, and a screenshot after each pattern.
    func testScrollDiagnosticProbe() throws {
        let started = Date()
        for stage in ["browse", "detail"] {
            var lines: [String] = []
            for pattern in ProbePattern.allCases {
                lines += probeScrolling(stage, pattern.rawValue, pattern)
            }
            if stage == "detail" {
                lines += probeScrolling(stage, "column-spaced-keep-pop", .columnSpaced,
                                        extra: ["-ProximeetPlacesKeepContentPop", "YES"])
            }
            attachNote("Scroll probe, \(stage), largest text:\n" + lines.joined(separator: "\n"))
        }
        print("PLACES_PROBE_DONE \(Self.pt(CGFloat(Date().timeIntervalSince(started)))) s")
    }

    private enum ProbePattern: String, CaseIterable {
        case edgeFast = "edge-fast"
        case edgeSpaced = "edge-spaced"
        case columnSpaced = "column-spaced"
    }

    /// One pattern: a fresh launch at the largest text, five drags, a line for each (printed and
    /// returned) and a screenshot. Reads with `snapshot()`, so a Back that has gone is recorded, not
    /// failed.
    private func probeScrolling(_ stage: String, _ label: String, _ pattern: ProbePattern,
                                extra: [String] = []) -> [String] {
        let detail = stage == "detail"
        let app = launch(fixture: detail ? "place-detail" : "places", category: "now", extra: Self.largestText + extra)
        let places = CorrectionPlaces(app: app)
        if detail {
            waitForLabel(places.name, "Common Ground")
        } else {
            waitForLabel(places.headline, "Find your kind of place.")
        }
        var lifted = Date()
        waitQuietly(0.5)
        let barID = detail ? "place.primary" : "places.secondary"
        let width = app.frame.width
        let content = min(376, width - 64), column = (width - content) / 2 + content / 2
        let pause: TimeInterval
        switch pattern {
        case .edgeFast: pause = 0
        case .edgeSpaced: pause = 1.5
        case .columnSpaced: pause = 0.7
        }
        var lines = ["\(label), \(Int(width.rounded())) pt\(extra.isEmpty ? "" : ", " + extra.joined(separator: " ")):"]
        var previous: [CGPoint] = []
        func header() -> CGFloat? {
            try? places.back.snapshot().frame.minY
        }
        func text(_ value: CGFloat?) -> String {
            value.map { Self.pt($0) } ?? "gone"
        }
        for drag in 1...5 {
            var x = width * 0.96, y0: CGFloat = 217, tier = "edge"
            if pattern == .columnSpaced {
                x = column
                tier = "column middle: nothing free"
                if let look = try? scrollLook(places.back, barID: barID, app), let bar = look.bar,
                   let touch = scrollTouchPoint(look, travel: 115, fingerUp: true, bandTop: 72, bandBottom: bar.minY - 13 - 10,
                                                awayFrom: previous, around: 217) {
                    x = touch.point.x
                    y0 = touch.point.y
                    tier = touch.tier
                }
            }
            let quiet = Date().timeIntervalSince(lifted)
            if quiet < pause {
                waitQuietly(pause - quiet)
            }
            let before = header()
            let gap = Date().timeIntervalSince(lifted)
            let y1 = y0 - 115
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: x, dy: y0))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: y1)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            lifted = Date()
            previous = [CGPoint(x: x, y: y0), CGPoint(x: x, y: y1)]
            let after = header()
            var moved = "n/a"
            if let before, let after {
                moved = Self.pt(before - after)
            }
            let entry = "PLACES_PROBE \(stage) \(label) drag \(drag) x=\(Self.pt(x)) y=\(Self.pt(y0))→\(Self.pt(y1)) "
                + "gapBefore=\(Self.pt(CGFloat(gap))) headerBefore=\(text(before)) headerAfter=\(text(after)) moved=\(moved)"
            print(entry)
            lines.append(entry + (pattern == .columnSpaced ? " (\(tier))" : ""))
        }
        capture("probe-\(stage)-\(label)-\(Int(width.rounded()))pt-largest-fixture", app)
        return lines
    }

    // MARK: - Route helpers

    private func launch(fixture: String, band: String = "social", approach: String = "chatFirst", category: String? = nil,
                        extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ProximeetFixture", fixture, "-ProximeetFixtureBand", band, "-ProximeetFixtureSignal", approach]
        if let category { arguments += ["-ProximeetFixtureCategory", category] }
        app.launchArguments = arguments + extra
        app.launch()
        return app
    }

    /// A category's tab, selected once the model has it and its venue's ticket shows.
    private func choose(_ category: String, _ places: CorrectionPlaces) {
        places.tab(category).tap()
        XCTAssertTrue(waitFor(places.tab(category), selected: true), "\(category) is selected.")
        waitForLabel(places.ticketName, Self.venue(category).name)
    }

    /// View place, the button itself, brought fully into view first.
    private func openDetail(_ places: CorrectionPlaces, _ app: XCUIApplication, _ name: String) {
        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app))
        places.viewPlace.tap()
        waitForLabel(places.name, name)
    }

    /// A swipe in from the leading edge, 45 % of the way down: completed (three quarters of the
    /// width, fast) or not (a fifth of the width, slowly, held, released without momentum).
    private func edgeSwipe(_ app: XCUIApplication, completing: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 2, dy: app.frame.height * 0.45))
        if completing {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.75, dy: 0)),
                        withVelocity: .fast, thenHoldForDuration: 0.05)
        } else {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.2, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.6)
        }
    }

    /// A rightward swipe that starts mid-screen (from 35 % of the width), fast.
    private func midScreenSwipe(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: app.frame.width * 0.35, dy: app.frame.height * 0.45))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.6, dy: 0)),
                    withVelocity: .fast, thenHoldForDuration: 0.05)
    }

    // MARK: - Assertions

    /// Exactly one `places.screen` (the container that owns Places' VoiceOver escape action), and
    /// each of `identifiers` found by a query scoped to it, so the container is their ancestor. The
    /// structure escape relies on, not escape itself, which XCUITest cannot perform.
    private func assertInsideScreen(_ app: XCUIApplication, _ identifiers: [String], _ state: String) {
        let containers = app.descendants(matching: .any).matching(identifier: "places.screen")
        XCTAssertEqual(containers.count, 1, "\(state): exactly one places.screen container.")
        let screen = containers.firstMatch
        for identifier in identifiers {
            XCTAssertTrue(screen.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists,
                          "\(state): \(identifier) is inside places.screen.")
        }
    }

    /// A stage that has just opened starts at its beginning: the header is where it rests on a
    /// screen that has not scrolled, and its Back can be tapped.
    private func assertStartsAtBeginning(_ places: CorrectionPlaces, restingHeader: CGFloat, _ state: String) {
        XCTAssertEqual(places.back.frame.minY, restingHeader, accuracy: 1.5,
                       "\(state) starts at its beginning (header at \(places.back.frame.minY), resting \(restingHeader)).")
        XCTAssertTrue(places.back.isHittable, "\(state): the header's Back is on screen.")
    }

    /// View place is entirely on screen, between the status bar and the fixed Back area, and can be
    /// tapped; its dark face is drawn where its frame is.
    private func assertViewPlaceUsable(_ places: CorrectionPlaces, _ app: XCUIApplication, _ state: String) {
        let button = places.viewPlace.frame
        let barTop = places.secondary.frame.minY - 13
        XCTAssertTrue(places.viewPlace.isHittable, "\(state): View place can be tapped.")
        XCTAssertGreaterThanOrEqual(button.minY, 44, "\(state): View place is below the status bar.")
        XCTAssertLessThanOrEqual(button.maxY, barTop + 1, "\(state): View place clears the Back area (bar top \(barTop)).")
        XCTAssertEqual(places.viewPlace.label, "View place")
        softly {
            guard let shot = CorrectionScreen(app) else { return }
            let face = shot.fraction(in: button.insetBy(dx: 5, dy: 5), where: Self.ink)
            XCTAssertGreaterThanOrEqual(face, 0.55, "\(state): View place's dark face is drawn at its frame (\(face)).")
        }
    }

    /// The footer as laid out and as drawn. Frames: the schedule reads the venue's schedule; both it
    /// and View place stay inside the ticket's column; they never meet; side by side they share a
    /// top with the button on the right; stacked, the button is below the whole schedule with a clear
    /// gap. Pixels: the schedule's ink lies within its frame; a stacked gap is ivory, uncrossed by
    /// ink; the button's face is dark; the ticket's paper continues below the button.
    private func checkFooter(_ app: XCUIApplication, _ places: CorrectionPlaces, _ venue: VenueFacts, _ state: String,
                             expectStacked: Bool) {
        let width = app.frame.width
        let content = min(376, width - 64), margin = (width - content) / 2
        let columnLeft = margin + 20, columnRight = margin + content - 20
        let schedule = places.ticketSchedule.frame, button = places.viewPlace.frame
        XCTAssertEqual(places.ticketSchedule.label, venue.schedule, "\(state): the whole schedule is the schedule's text.")
        attachNote("\(state): schedule \(NSCoder.string(for: schedule)); View place \(NSCoder.string(for: button)); "
                   + "column \(columnLeft)-\(columnRight).")
        softly {
            XCTAssertGreaterThanOrEqual(schedule.minX, columnLeft - 1, "\(state): the schedule starts in the column.")
            XCTAssertLessThanOrEqual(schedule.maxX, columnRight + 1, "\(state): the schedule does not run past the column.")
            XCTAssertGreaterThanOrEqual(button.minX, columnLeft - 1, "\(state): View place starts in the column.")
            XCTAssertLessThanOrEqual(button.maxX, columnRight + 1, "\(state): View place ends in the column.")
            XCTAssertGreaterThanOrEqual(button.height, Self.minimumTarget, "\(state): View place is at least 44 pt tall.")
            XCTAssertGreaterThanOrEqual(button.width, 139, "\(state): View place is at least 140 pt wide.")
            XCTAssertFalse(schedule.intersects(button), "\(state): View place covers part of the schedule.")
            let stacked = button.minY >= schedule.maxY - 0.5
            XCTAssertEqual(stacked, expectStacked, "\(state): expected \(expectStacked ? "a stacked" : "a side-by-side") footer.")
            if stacked {
                XCTAssertGreaterThanOrEqual(button.minY - schedule.maxY, 8, "\(state): a clear gap above View place.")
                XCTAssertEqual(button.minX, columnLeft, accuracy: 1, "\(state): stacked, View place starts at the column.")
            } else {
                XCTAssertLessThanOrEqual(abs(button.minY - schedule.minY), 4, "\(state): side by side, they share a top.")
                XCTAssertEqual(button.maxX, columnRight, accuracy: 1, "\(state): side by side, View place is at the right.")
                XCTAssertGreaterThanOrEqual(button.minX - schedule.maxX, 7, "\(state): side by side, 8 pt apart.")
            }
            guard let shot = CorrectionScreen(app) else { return }
            // The schedule's ink lies within its frame (the drawn text is the measured text).
            let band = CGRect(x: columnLeft, y: schedule.minY - 6, width: columnRight - columnLeft, height: schedule.height + 12)
            let excluding = stacked ? band : CGRect(x: columnLeft, y: band.minY, width: button.minX - 2 - columnLeft, height: band.height)
            if let ink = shot.inkRows(in: excluding, where: Self.ink) {
                XCTAssertGreaterThanOrEqual(ink.top, schedule.minY - 1.5, "\(state): schedule ink above its frame.")
                XCTAssertLessThanOrEqual(ink.bottom, schedule.maxY + 1.5, "\(state): schedule ink below its frame.")
            } else {
                XCTFail("\(state): the schedule is not drawn.")
            }
            if stacked {
                let gap = CGRect(x: columnLeft, y: schedule.maxY + 1, width: columnRight - columnLeft, height: button.minY - schedule.maxY - 2)
                let crossed = shot.fraction(in: gap, where: Self.ink)
                XCTAssertLessThanOrEqual(crossed, 0.002, "\(state): ink crosses the gap above View place (\(crossed)).")
            }
            let face = shot.fraction(in: button.insetBy(dx: 5, dy: 5), where: Self.ink)
            XCTAssertGreaterThanOrEqual(face, 0.55, "\(state): View place's dark face is drawn at its frame (\(face)).")
            // The paper below the button, only where the fixed Back bar does not cover it (the
            // footer tests scroll 12 pt of it into view first).
            let barTop = places.secondary.frame.minY - 13
            let paperTop = button.maxY + 2, paperBottom = min(button.maxY + 10, barTop - 1)
            if paperBottom - paperTop >= 3 {
                let paper = shot.fraction(in: CGRect(x: columnLeft, y: paperTop, width: 40, height: paperBottom - paperTop),
                                          where: Self.ivory)
                XCTAssertGreaterThanOrEqual(paper, 0.95, "\(state): the ticket's paper continues below View place (\(paper)).")
            } else {
                XCTFail("\(state): View place ends \(barTop - button.maxY) pt above the Back area; its paper cannot be seen.")
            }
        }
    }

    /// The approved 440-pt footer, to the point: View place 140 × 44 at (248, 754); the schedule's
    /// line at (52, 754).
    private func checkApprovedFooter(_ places: CorrectionPlaces, _ venue: VenueFacts) {
        softly {
            let button = places.viewPlace.frame, schedule = places.ticketSchedule.frame
            XCTAssertEqual(button.minX, 248, accuracy: 1, "\(venue.name): View place x \(button.minX), approved 248.")
            XCTAssertEqual(button.minY, 754, accuracy: 1, "\(venue.name): View place y \(button.minY), approved 754.")
            XCTAssertEqual(button.width, 140, accuracy: 1, "\(venue.name): View place width \(button.width), approved 140.")
            XCTAssertEqual(button.height, 44, accuracy: 1, "\(venue.name): View place height \(button.height), approved 44.")
            XCTAssertEqual(schedule.minX, 52, accuracy: 1, "\(venue.name): schedule x \(schedule.minX), approved 52.")
            XCTAssertEqual(schedule.minY, 754, accuracy: 3, "\(venue.name): schedule line top \(schedule.minY), approved 754.")
        }
    }

    private func assertNothingConferred(_ app: XCUIApplication) {
        let words = ["verified", "access granted", "checked in", "check-in complete", "you're visible", "you’re visible",
                     "now visible", "nearby", "matched", "online now", "member", "discoverable", "wave sent",
                     "chat open", "message sent", "booked", "reserved", "confirmed", "people here", "guests here"]
        let predicate = NSPredicate(format: words.map { _ in "label CONTAINS[c] %@" }.joined(separator: " OR "), argumentArray: words)
        XCTAssertEqual(app.descendants(matching: .any).matching(predicate).count, 0)
        XCTAssertEqual(app.alerts.count, 0, "No prompt appeared in the app.")
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0,
                       "No system permission prompt appeared.")
    }

    // MARK: - Waiting and input

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        if element.exists && element.label == label {
            return
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(element.identifier) should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 15), .completed, "Expected “\(label)”, found “\(element.label)”.")
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        if element.exists && element.isSelected == selected {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    // MARK: - Scrolling

    /// Brings `element` between the status bar (62) and the top of the fixed action bar (`bar` is its
    /// top action, 13 pt below the bar's top), with `clearance` more below it. An element taller than
    /// that space counts once its top is in view. Both edges allow 1 pt. Returns whether it did; when
    /// it did not, it has already failed the test at the caller's line.
    ///
    /// Short, momentum-free drags (press 0.05 s, slow, held 0.2 s before release), each touching down
    /// in the page's column on nothing that is a control (`scrollTouchPoint`), never nearer than
    /// 44 pt to either screen edge: the leading edge is Places' back swipe, the trailing edge the
    /// scroll indicator (build 6ab88011's largest-text scrolls stalled with drags 16 pt from it; the
    /// cause is unverified). The page is never expected to move further than would carry the
    /// element's top past the far side of the range: the finger travels at most that plus what the
    /// last drag lost before the scroll view took it. A drag that loses less than the last one can
    /// overshoot a narrow range; the next drag corrects it from the other side. Each drag aims 16 pt
    /// inside the near side (the middle of a narrower range) and is at least 20 pt where the range
    /// allows, well past what a tap allows for.
    ///
    /// After every drag the frames are read again once the target has settled (`snapshot()`: one
    /// round trip for the whole screen). The page must move the right way by a quarter of the drag
    /// (at least 2 pt). A movement the wrong way, a sideways one (the back swipe), a changed screen,
    /// or two drags in a row that do not move the page end it at once, with the screen, every drag
    /// and every frame attached: "Scroll PRODUCT" when the page has reached its end (the stage's last
    /// line is above the bar) or its start with the element still out of range, "Scroll HARNESS" for
    /// everything else. Every drag prints a `PLACES_SCROLL` line to the log.
    private func scrollIntoView(_ element: XCUIElement, bar: XCUIElement, _ app: XCUIApplication, clearance: CGFloat = 0,
                                file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let top: CGFloat = 62, longest: CGFloat = 115, shortest: CGFloat = 20, confirming: CGFloat = 60
        let started = Date()
        var name = "the element"
        var trace: [String] = []
        let barID: String
        var now: ScrollLook
        do {
            let id = try element.snapshot().identifier
            name = id.isEmpty ? name : id
            barID = try bar.snapshot().identifier
            now = try settledScrollLook(element, barID: barID, app)
        } catch {
            // `name` stays "the element" when the element itself is missing: an unresolved
            // XCUIElement's description would be a query of its own.
            return scrollFailed(.harness("\(name) or its bar is not on screen: \(error.localizedDescription)"),
                                name, nil, trace, app, file: file, line: line)
        }
        trace.append("start: \(name) \(Self.rect(now.target)); bar \(barID) \(Self.rect(now.bar)); "
                     + "clearance \(Self.pt(clearance)); screen \(Self.rect(now.screen))")
        var loss: CGFloat = 0
        var stalls = 0, overshoots = 0, drags = 0, budget = 0
        var previous: [CGPoint] = []
        var lifted = Date.distantPast
        while true {
            guard let barFrame = now.bar else {
                return scrollFailed(.harness("\(barID) is not on screen: the screen changed"), name, now, trace, app,
                                    file: file, line: line)
            }
            let frame = now.target, barTop = barFrame.minY - 13, bottom = barTop - clearance
            let fits = (bottom - top) - frame.height > 2
            let lowestTop = fits ? bottom + 1 - frame.height : bottom - 44, highestTop = top - 1
            let low = frame.minY > lowestTop, high = frame.minY < highestTop
            if !low && !high {
                print("PLACES_SCROLL_DONE \(name): \(drags) drags, \(Self.pt(CGFloat(Date().timeIntervalSince(started)))) s")
                return true
            }
            guard lowestTop >= highestTop else {
                return scrollFailed(.harness("no top counts: only \(Self.pt(bottom - top)) pt lie between the status bar "
                                             + "and the bar (its top \(Self.pt(barTop)), clearance \(Self.pt(clearance)))"),
                                    name, now, trace, app, file: file, line: line)
            }
            // The whole drag stays 10 pt clear of the status bar line and of the bar.
            let bandTop = top + 10, bandBottom = barTop - 10, room = bandBottom - bandTop - 16
            let inset = min(16, (lowestTop - highestTop) / 2)
            let distance = low ? frame.minY - (lowestTop - inset) : (highestTop + inset) - frame.minY
            // The most the page may move before the element's top passes the far side of the range.
            let farthest = low ? frame.minY - highestTop - 1 : lowestTop - frame.minY - 1
            // The page lags the finger by what the last drag lost, so the finger may travel that much
            // past `farthest`; the page itself still stops short of the far side. (Build 6ab8639c's
            // P11 on the 390-pt phone: a window of about 7 pt, and drags losing 7 to 9.5 pt.)
            let reach = farthest + loss
            var travel = min(longest, distance + loss, reach, room)
            if stalls > 0 {
                // After a drag that did not move the page: long enough to clear any loss this helper
                // allows (24, the cap on `loss`), so the next verdict does not rest on a drag the
                // scroll view could have absorbed; an overshoot is corrected by the next drag, from
                // the other side.
                travel = max(travel, min(confirming, farthest + 24, room))
            }
            if travel < shortest {
                travel = min(shortest, reach, room)
            }
            guard travel >= 2 else {
                return scrollFailed(.harness("no room for a drag: band \(Self.pt(bandTop))–\(Self.pt(bandBottom)), the far "
                                             + "side of the range \(Self.pt(farthest)) pt away"),
                                    name, now, trace, app, file: file, line: line)
            }
            if budget == 0 {
                // A drag that counts moves the page at least a quarter of `longest`; six to spare.
                budget = Int((distance / (longest / 4)).rounded(.up)) + 6
            }
            guard let touch = scrollTouchPoint(now, travel: travel, fingerUp: low, bandTop: bandTop, bandBottom: bandBottom,
                                               awayFrom: previous) else {
                return scrollFailed(.harness("no touch-down point in the column between y \(Self.pt(bandTop)) and "
                                             + "\(Self.pt(bandBottom)) keeps 12 pt from every control"),
                                    name, now, trace, app, file: file, line: line)
            }
            // A second touch soon after and near the first can count as a repeated tap, which the
            // window's RepeatTapSwallower takes, cancelling the scroll: 0.7 s between them, at least.
            let quiet = Date().timeIntervalSince(lifted)
            if quiet < 0.7 {
                waitQuietly(0.7 - quiet)
            }
            let lift = CGPoint(x: touch.point.x, y: touch.point.y + (low ? -travel : travel))
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: touch.point.x, dy: touch.point.y))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: lift.x, dy: lift.y)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            lifted = Date()
            drags += 1
            previous = [touch.point, lift]
            let after: ScrollLook
            do {
                after = try settledScrollLook(element, barID: barID, app)
            } catch {
                trace.append("drag \(drags) \(touch.tier) \(Self.point(touch.point)) → \(Self.point(lift)): \(name) is gone")
                return scrollFailed(.harness("after drag \(drags) \(name) cannot be read: the drag changed the screen"),
                                    name, now, trace, app, file: file, line: line)
            }
            let moved = low ? frame.minY - after.target.minY : after.target.minY - frame.minY
            let sideways = after.target.minX - frame.minX
            var page: CGFloat?
            if let before = now.header, let later = after.header {
                page = low ? before.minY - later.minY : later.minY - before.minY
            }
            let enough = max(2, travel / 4)
            let entry = "drag \(drags) \(low ? "up" : "down") \(touch.tier) \(Self.point(touch.point)) → "
                + "\(Self.point(lift)), travel \(Self.pt(travel)): top \(Self.pt(frame.minY)) → "
                + "\(Self.pt(after.target.minY)), moved \(Self.pt(moved)), header moved \(page.map { Self.pt($0) } ?? "n/a"), "
                + "sideways \(Self.pt(sideways)); range \(Self.pt(highestTop))–\(Self.pt(lowestTop)); last line "
                + "\(after.endID) \(Self.rect(after.end)); bar \(Self.rect(after.bar)); look \(Self.pt(CGFloat(after.seconds))) s"
            trace.append(entry)
            print("PLACES_SCROLL \(name) \(entry)")
            func fail(_ verdict: ScrollVerdict) -> Bool {
                scrollFailed(verdict, name, after, trace, app, file: file, line: line)
            }
            if after.bar == nil {
                return fail(.harness("\(barID) went away with drag \(drags): the drag changed the screen"))
            }
            if abs(sideways) > 1 {
                return fail(.harness("drag \(drags) moved the page sideways by \(Self.pt(sideways)) pt: the back swipe took it"))
            }
            if moved <= -2 {
                return fail(.harness("drag \(drags) moved the page the wrong way, by \(Self.pt(-moved)) pt"))
            }
            if let page, page >= enough, moved < enough {
                return fail(.harness("drag \(drags) moved the page \(Self.pt(page)) pt but \(name) \(Self.pt(moved)) pt: "
                                     + "it does not scroll with the page"))
            }
            if moved > travel + 4 {
                overshoots += 1
                if overshoots >= 2 {
                    return fail(.harness("twice a drag moved the page further than the finger (\(Self.pt(moved)) pt for "
                                         + "\(Self.pt(travel))): the drags are not momentum-free"))
                }
            }
            if moved >= enough {
                stalls = 0
                loss = max(0, min(24, travel - moved))
            } else {
                stalls += 1
                if stalls >= 2 {
                    let afterTop = (after.bar ?? barFrame).minY - 13
                    if low, let end = after.end, end.maxY <= afterTop - 9 {
                        return fail(.product("the content has ended: two drags did not move it, its last line (\(after.endID)) "
                                             + "ends at \(Self.pt(end.maxY)), above the bar's top \(Self.pt(afterTop)), and "
                                             + "\(name)'s top is \(Self.pt(after.target.minY)), below \(Self.pt(lowestTop))"))
                    }
                    if high, let header = after.header, let scroller = after.scroller, header.minY >= scroller.minY + 1 {
                        return fail(.product("the page is at its start: two drags did not move it, the header's Back is at "
                                             + "\(Self.pt(header.minY)), and \(name)'s top is \(Self.pt(after.target.minY)), "
                                             + "above \(Self.pt(highestTop))"))
                    }
                    return fail(.harness("two drags in a row did not move the page (the last moved \(Self.pt(moved)) pt of "
                                         + "\(Self.pt(travel))) and it has not reached its \(low ? "end" : "start"): last line "
                                         + "\(after.endID) \(Self.rect(after.end)), bar top \(Self.pt(afterTop))"))
                }
            }
            if drags >= budget {
                return fail(.harness("\(drags) drags (the limit the starting distance allows) have not brought \(name) "
                                     + "into range: top \(Self.pt(after.target.minY)), range "
                                     + "\(Self.pt(highestTop))–\(Self.pt(lowestTop))"))
            }
            now = after
        }
    }

    /// Where a drag touches down: in the page's column (a half, a quarter or three quarters across
    /// it: 81 pt or more from either screen edge on a 390-pt iPhone, and never nearer than 44), at a
    /// height from which the whole drag stays in the band (nearest `preferred` when given, otherwise
    /// the band's middle first), and 12 pt or more from every control. "clear" also keeps 8 pt off
    /// browsing's ticket, which opens its detail when tapped; only when no such point exists (the
    /// largest text, with the ticket filling the page) is the ticket's paper used, as "card". A point
    /// 60 pt or more from the last drag's touch-down and lift is preferred.
    private func scrollTouchPoint(_ look: ScrollLook, travel: CGFloat, fingerUp: Bool, bandTop: CGFloat,
                                  bandBottom: CGFloat, awayFrom previous: [CGPoint],
                                  around preferred: CGFloat? = nil) -> (point: CGPoint, tier: String)? {
        let width = look.screen.width
        let content = min(376, width - 64), margin = (width - content) / 2
        let fractions: [CGFloat] = [0.5, 0.25, 0.75]
        let xs = fractions.map { margin + content * $0 }.filter { $0 >= 44 && $0 <= width - 44 }
        // Touch-down heights from which the drag's lift stays in the band, nearest the start first.
        let lowest = fingerUp ? bandTop + travel : bandTop
        let highest = fingerUp ? bandBottom : bandBottom - travel
        guard lowest <= highest else { return nil }
        let start = preferred.map { min(max($0, lowest), highest) } ?? (lowest + highest) / 2
        let reach = max(start - lowest, highest - start)
        var ys: [CGFloat] = []
        var offset: CGFloat = 0
        while offset <= reach + 8 {
            for y in [start - offset, start + offset] where y >= lowest && y <= highest && !ys.contains(y) {
                ys.append(y)
            }
            offset += 8
        }
        let controls = look.controls.map { $0.insetBy(dx: -12, dy: -12) }
        let cards = look.cards.map { $0.insetBy(dx: -8, dy: -8) }
        let tiers: [(String, [CGRect])] = [("clear", controls + cards), ("card", controls)]
        for (tier, avoided) in tiers where tier == "clear" || !cards.isEmpty {
            for spaced in [true, false] {
                for y in ys {
                    for x in xs {
                        let point = CGPoint(x: x, y: y)
                        if avoided.contains(where: { $0.contains(point) }) {
                            continue
                        }
                        let near = previous.contains { mark in
                            let dx = mark.x - x, dy = mark.y - y
                            return (dx * dx + dy * dy).squareRoot() < 60
                        }
                        if spaced && near {
                            continue
                        }
                        return (point, tier)
                    }
                }
            }
        }
        return nil
    }

    /// Reads the screen once the target has stopped moving (two reads 0.15 s apart within 0.5 pt;
    /// at most five more), so a rubber band or a revealing scroll is never measured half-way.
    private func settledScrollLook(_ element: XCUIElement, barID: String, _ app: XCUIApplication) throws -> ScrollLook {
        var last = try element.snapshot().frame
        for _ in 0..<5 {
            waitQuietly(0.15)
            let next = try element.snapshot().frame
            if abs(next.minY - last.minY) <= 0.5 && abs(next.minX - last.minX) <= 0.5 {
                break
            }
            last = next
        }
        return try scrollLook(element, barID: barID, app)
    }

    /// The target from its own snapshot; everything else from one snapshot of the whole app.
    private func scrollLook(_ element: XCUIElement, barID: String, _ app: XCUIApplication) throws -> ScrollLook {
        let started = Date()
        let target = try element.snapshot()
        let root = try app.snapshot()
        var look = ScrollLook(target: target.frame, screen: root.frame)
        var stack: [any XCUIElementSnapshot] = [root]
        while let node = stack.popLast() {
            stack.append(contentsOf: node.children.reversed())
            let id = node.identifier, frame = node.frame, type = node.elementType
            // A container (the screen, the tabs, a ticket) is never a control, whatever its type.
            let control = !Self.scrollContainers.contains(id) && Self.scrollControlTypes.contains(type)
            if id == barID && look.bar == nil {
                look.bar = frame
            }
            if id == "places.back" && look.header == nil {
                look.header = frame
            }
            if Self.scrollLastLines.contains(id) && frame.maxY > (look.end?.maxY ?? -CGFloat.greatestFiniteMagnitude) {
                look.end = frame
                look.endID = id
            }
            if type == .scrollView && look.scroller == nil {
                look.scroller = frame
            }
            if control {
                look.controls.append(frame)
            }
            if Self.scrollCards.contains(id) {
                look.cards.append(frame)
            }
            if control || !id.isEmpty {
                look.inventory.append("\(id.isEmpty ? "“\(node.label)”" : id)\(control ? " (control)" : "") \(Self.rect(frame))")
            }
        }
        look.seconds = Date().timeIntervalSince(started)
        return look
    }

    /// Attaches the reason, the last frames, every drag and every element, and the screen, then fails
    /// with "Scroll PRODUCT: …" or "Scroll HARNESS: …" at the caller's line.
    private func scrollFailed(_ verdict: ScrollVerdict, _ name: String, _ look: ScrollLook?, _ trace: [String],
                              _ app: XCUIApplication, file: StaticString, line: UInt) -> Bool {
        let kind: String, reason: String
        switch verdict {
        case .product(let text):
            kind = "PRODUCT"
            reason = text
        case .harness(let text):
            kind = "HARNESS"
            reason = text
        }
        var lines = ["scrollIntoView \(kind) \(name): \(reason)"]
        if let look {
            lines.append("last look: target \(Self.rect(look.target)); bar \(Self.rect(look.bar)); header Back "
                         + "\(Self.rect(look.header)); last line \(look.endID) \(Self.rect(look.end)); scroll view "
                         + "\(Self.rect(look.scroller)); screen \(Self.rect(look.screen)); snapshot \(Self.pt(CGFloat(look.seconds))) s")
        }
        lines += trace
        if let look {
            lines.append("elements: " + look.inventory.joined(separator: "; "))
        }
        print("PLACES_SCROLL_FAILED " + lines.joined(separator: " | "))
        attachNote(lines.joined(separator: "\n"))
        capture("scroll-\(kind.lowercased())-\(name)", app)
        XCTFail("Scroll \(kind): \(name): \(reason)", file: file, line: line)
        return false
    }

    /// Waits without asserting anything: a waiter with no delegate, on an expectation nobody fulfils.
    /// Not `hold`, which `PROXIMEET_SHORT_HOLDS` shortens.
    private func waitQuietly(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "quiet")], timeout: seconds)
    }

    private static func pt(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func rect(_ rect: CGRect?) -> String {
        rect.map { NSCoder.string(for: $0) } ?? "none"
    }

    private static func point(_ point: CGPoint) -> String {
        "(\(pt(point.x)), \(pt(point.y)))"
    }

    /// One reading for `scrollIntoView`: every `XCUIElement.frame` read is a query of its own, and a
    /// snapshot brings every frame back in one.
    private struct ScrollLook {
        var target: CGRect
        var screen: CGRect
        /// The bar's top action (the fixed bar starts 13 pt above it).
        var bar: CGRect?
        /// The header's Back: the first thing in the scroll content, moving with it.
        var header: CGRect?
        /// The stage's last line; the content ends 11 pt below it (15 or 23 on a detail).
        var end: CGRect?
        var endID = ""
        var scroller: CGRect?
        /// Buttons (Back, the tabs, View place, the bar's actions) and any other control.
        var controls: [CGRect] = []
        /// Tappable content that is not a control: browsing's ticket opens its detail when tapped.
        var cards: [CGRect] = []
        var inventory: [String] = []
        var seconds: TimeInterval = 0
    }

    private enum ScrollVerdict {
        /// The page is at its end (or start) with the element still out of range.
        case product(String)
        /// The drags did not move the page as asked, the screen changed, nowhere was safe to touch, or
        /// no top would count (the bar leaves no room).
        case harness(String)
    }

    private static let scrollControlTypes: Set<XCUIElement.ElementType> = [
        .button, .link, .`switch`, .toggle, .slider, .stepper, .textField, .secureTextField, .searchField, .textView,
        .segmentedControl, .pickerWheel, .datePicker, .cell, .tab, .key,
    ]
    /// Containers that hold controls but are not one: the screen (VoiceOver's escape), the tabs and
    /// the two tickets.
    private static let scrollContainers: Set<String> = ["places.screen", "places.tabs", "places.ticket", "place.ticket"]
    /// Each stage's last line: browsing's boundary line, a detail's boundary line, the explanation's demo line.
    private static let scrollLastLines: Set<String> = ["places.boundary", "place.boundary", "explanation.demo"]
    /// Tappable, not a control: browsing's ticket (`VenueTicket.onTapGesture`).
    private static let scrollCards: Set<String> = ["places.ticket"]

    // MARK: - Captures and holds

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

    /// With `PROXIMEET_SHORT_HOLDS=1` (unrecorded runs), a hold is at most 0.6 s.
    private func hold(_ seconds: TimeInterval) {
        let short = ProcessInfo.processInfo.environment["PROXIMEET_SHORT_HOLDS"] == "1"
        let duration = short ? min(seconds, 0.6) : seconds
        let done = expectation(description: "Hold so the recording shows this state")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { done.fulfill() }
        wait(for: [done], timeout: duration + 1)
    }

    private func softly(_ checks: () -> Void) {
        continueAfterFailure = true
        checks()
        continueAfterFailure = false
    }

    private static let ivory: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) >= 232 && max(r, g, b) - min(r, g, b) <= 14 }
    private static let ink: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 60 }
}

/// Places' elements, by identifier.
@MainActor
private struct CorrectionPlaces {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var back: XCUIElement { app.buttons["places.back"] }
    var headline: XCUIElement { element("places.headline") }
    var secondary: XCUIElement { app.buttons["places.secondary"] }
    func tab(_ category: String) -> XCUIElement { app.buttons["places.tab.\(category)"] }

    var ticketName: XCUIElement { element("places.ticket.name") }
    var ticketSchedule: XCUIElement { element("places.ticket.schedule") }
    var viewPlace: XCUIElement { app.buttons["places.viewPlace"] }

    var name: XCUIElement { element("place.name") }
    var lastLine: XCUIElement { element("place.boundary") }
    var primary: XCUIElement { app.buttons["place.primary"] }
    var detailSecondary: XCUIElement { app.buttons["place.secondary"] }

    var explanationHeadline: XCUIElement { element("explanation.headline") }
    var presence: XCUIElement { element("explanation.presence") }
    var demoLine: XCUIElement { element("explanation.demo") }
    var explore: XCUIElement { app.buttons["explanation.primary"] }
    var backToPlace: XCUIElement { app.buttons["explanation.secondary"] }
}

@MainActor
private struct CorrectionSignal {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.headline").firstMatch }
    var summary: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.summary").firstMatch }
    var primary: XCUIElement { app.buttons["signal.primary"] }
    var back: XCUIElement { app.buttons["signal.back"] }

    func row(_ approach: String) -> XCUIElement { app.buttons["signal.approach.\(approach)"] }
}

@MainActor
private struct CorrectionWristband {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch }
    var primary: XCUIElement { app.buttons["wristband.primary"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

/// One screenshot's pixels, addressed in points.
@MainActor
private struct CorrectionScreen {
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

    /// The fraction of pixels in `rect` passing `test`.
    func fraction(in rect: CGRect, where test: (UInt8, UInt8, UInt8) -> Bool) -> Double {
        guard let range = pixelRange(rect) else { return 0 }
        var total = 0, passing = 0
        for y in range.y0..<range.y1 {
            for x in range.x0..<range.x1 {
                total += 1
                if passes(x, y, test) { passing += 1 }
            }
        }
        return total > 0 ? Double(passing) / Double(total) : 0
    }
}
