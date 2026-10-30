import UIKit
import XCTest

/// Runtime review of the approved Places (chapter 07). The real route: Welcome → More options →
/// "Continue the demo (no account)" → Birthday → Continue → Pass → Try the demo → Finish preview →
/// Continue preview → Guest List (typed) → Preview my card → Continue preview → Wristband (a chosen
/// intent) → Continue preview → Signal (a chosen approach) → Continue preview → Places.
///
/// Skipped unless the test runner's environment has `PROXIMEET_PLACES_REVIEW=1` (pass
/// `TEST_RUNNER_PROXIMEET_PLACES_REVIEW=1` to xcodebuild). Real taps and typing. Tests that start
/// from a DEBUG fixture (`-ProximeetFixture places…`, a direct launch) say so in their comments and
/// their captures end in "fixture"; the fixtures reach Places through the same Birthday gate,
/// completed Pass, Guest List card, Wristband and Signal. Every venue, host, schedule, name and
/// opener is fictional; the snapshot is a fixed Thursday, 8 pm, and nothing reads a clock.
///
/// The frames checked on the 440 × 956 iPhone are the approved Figma frames (handoff
/// `LAYOUT_SPEC.json`, 58:480–58:486); the rendered checks read the screenshot's pixels, since an
/// accessibility frame does not prove anything was drawn.
@MainActor
final class PlacesReviewTests: XCTestCase {
    nonisolated private static let reviewFlag = "PROXIMEET_PLACES_REVIEW"
    private static let intents = ["social", "dating", "business", "activity"]
    private static let titles = ["social": "Social", "dating": "Dating", "business": "Business", "activity": "Activity"]
    private static let categories = ["now", "later", "upcoming"]
    private static let categoryTitles = ["now": "Now", "later": "Later", "upcoming": "Upcoming"]
    private static let alexCard = "Alex. Always up for coffee and a good story. Interests: Coffee, Live music, Outdoors"

    /// The fixed fictional catalog as approved, written out here rather than read from the app.
    private struct VenueFacts {
        let category: String
        let key: String
        let name: String
        let kind: String
        let schedule: String
        let host: String
        let brief: String
        let permitted: [String]
        /// The future session's label; nil for the one session open in the snapshot.
        let opens: String?
        /// Chip widths 72 / 96 / 84 / 72; 8 apart in pairs, 4 apart in the approved four-intent row.
        let chipsWidth: CGFloat
    }

    private static let venues = [
        VenueFacts(category: "now", key: "common-ground", name: "Common Ground", kind: "Fictional venue · Café",
                   schedule: "Today · 6–10 pm", host: "Host · Common Ground team",
                   brief: "Coffee, small tables, and room for an unhurried conversation.",
                   permitted: ["social", "business", "activity", "dating"], opens: nil, chipsWidth: 336),
        VenueFacts(category: "later", key: "afterglow", name: "Afterglow", kind: "Fictional venue · Listening lounge",
                   schedule: "Tonight · 9–11 pm", host: "Host · Afterglow hosts",
                   brief: "A warm listening room for records, conversation, and a little curiosity.",
                   permitted: ["social", "dating"], opens: "Opens at 9 pm", chipsWidth: 152),
        VenueFacts(category: "upcoming", key: "fieldwork", name: "Fieldwork", kind: "Fictional venue · Creative workshop",
                   schedule: "Saturday · 10 am–1 pm", host: "Host · Fieldwork studio",
                   brief: "A shared table for making, learning, and meeting through a small project.",
                   permitted: ["activity", "business"], opens: "Opens Saturday", chipsWidth: 188),
    ]

    private static func venue(_ category: String) -> VenueFacts {
        venues.first { $0.category == category } ?? venues[0]
    }

    /// What the approved copy says for an intent at a category's venue: the detail's primary label
    /// and whether it is enabled, the browse line and the detail's last line. A mismatch comes
    /// before a future label; all four intents now match the open Common Ground demo.
    private static func expected(_ category: String, _ intent: String) -> (primary: String, enabled: Bool, browse: String, detail: String) {
        let venue = venue(category)
        let title = titles[intent] ?? intent
        let mismatch = "Your \(title) band doesn’t match this session."
        guard venue.permitted.contains(intent) else {
            return ("Not available for \(title)", false, mismatch, mismatch)
        }
        return (venue.opens ?? "Preview check-in", venue.opens == nil, "Your profile stays private until check-in.",
                "Sample session · not a reservation")
    }

    /// 44 pt, less floating-point error, for every 44-pt target check: build 6ab88011 measured a
    /// 44-pt tab as 43.99999999999997, 4 ULPs below 44, once a fractional scroll offset had moved it.
    /// 1e-6 pt is far above that error and far below anything that can be drawn.
    private static let minimumTarget: CGFloat = 44 - 1e-6

    private static func intentsLine(_ venue: VenueFacts) -> String {
        venue.permitted.map { titles[$0] ?? $0 }.joined(separator: " and ")
    }

    override func setUpWithError() throws {
        try RunBudget.begin(self)
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.reviewFlag] == "1",
            "The Places review runs only with TEST_RUNNER_\(Self.reviewFlag)=1."
        )
        print("PLACES_REVIEW_FLAG_SEEN \(name)")
    }

    // MARK: - The recorded walkthrough (full journey)

    /// Full journey, recorded: the real route with a typed introduction, Social and Chat first;
    /// Signal's Continue preview opens Places at Now; Later and Upcoming; Common Ground's detail
    /// (Preview check-in enabled), the explanation, Back to place, the explanation again and
    /// Preview room demo, then the Room's approved way back (Enter room demo, Leave and disappear,
    /// Return to Places: Now); Afterglow's detail (Opens at 9 pm, disabled; a tap does
    /// nothing) and Back to places (Later kept); Fieldwork's (Not available for Social) and the
    /// header Back (Upcoming kept); Back to Signal (both values kept) and Continue preview again
    /// (Upcoming kept); back to the Wristband for Business, forward through Signal (Chat first
    /// kept): Fieldwork now matches (Opens Saturday) and Common Ground opens the explanation.
    func testWalkthroughRealJourney() throws {
        print("PLACES_WALKTHROUGH_START \(Date().timeIntervalSince1970)")
        let app = launchWelcome()
        // The app's first screen: where a compact recording's trim starts.
        print("PLACES_WALKTHROUGH_APP_READY \(Date().timeIntervalSince1970)")
        hold(1.0)
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Alex")
        guest.name.typeText("\n")
        XCTAssertTrue(waitForFocus(guest.opener))
        guest.opener.typeText("Up for coffee.")
        tapKeyboardDone(app)
        guest.coffee.tap()
        hold(0.5)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        hold(0.5)
        tapDistinctPrimary(guest.primary, label: "Continue preview")
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.tile("social").tap()
        XCTAssertTrue(waitFor(band.tile("social"), selected: true))
        hold(0.6)
        band.primary.tap()
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.row("chatFirst").tap()
        XCTAssertTrue(waitFor(signal.row("chatFirst"), selected: true))
        hold(1.0)
        capture("places-journey-signal-social-chat", app)

        // Continue preview: Places, browsing Now.
        signal.primary.tap()
        let places = PlacesScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(1.2)
        assertBrowse(places, category: "now", intent: "social")
        softlyGeometry(app, places, "Journey Now, Social", stage: .browse, category: "now", intent: "social")
        capture("places-journey-now-social", app)
        for category in ["later", "upcoming"] {
            choose(category, places)
            hold(1.0)
            assertBrowse(places, category: category, intent: "social")
            capture("places-journey-\(category)-social", app)
        }

        // Now → Common Ground's detail → the explanation → Back to place → the explanation → Preview
        // room demo → the Room → Return to Places (chapter 08: the explanation's primary no longer
        // returns to browsing itself).
        choose("now", places)
        hold(0.8)
        openDetail(places, category: "now")
        hold(1.2)
        assertDetail(places, category: "now", intent: "social")
        softlyGeometry(app, places, "Journey Common Ground, Social", stage: .detail, category: "now", intent: "social")
        capture("places-journey-detail-common-ground-social", app)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(1.5)
        assertExplanation(places)
        softlyGeometry(app, places, "Journey explanation", stage: .explanation, category: "now", intent: "social")
        capture("places-journey-explanation-social", app)
        places.backToPlace.tap()
        waitForLabel(places.name, "Common Ground")
        hold(0.8)
        assertDetail(places, category: "now", intent: "social")
        capture("places-journey-back-to-place-social", app)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(0.8)
        returnToNowThroughRoom(places)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        assertBrowse(places, category: "now", intent: "social")
        capture("places-journey-explore-now-social", app)

        // Later → Afterglow: a future session; the disabled action does nothing.
        choose("later", places)
        hold(0.6)
        openDetail(places, category: "later")
        hold(1.2)
        assertDetail(places, category: "later", intent: "social")
        capture("places-journey-detail-afterglow-social", app)
        places.primary.tap()
        hold(0.6)
        XCTAssertFalse(places.explanationHeadline.exists, "A disabled Opens at 9 pm opens nothing.")
        assertDetail(places, category: "later", intent: "social")
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        assertBrowse(places, category: "later", intent: "social")

        // Upcoming → Fieldwork: a mismatch, explained before its future label; the header Back.
        choose("upcoming", places)
        hold(0.6)
        openDetail(places, category: "upcoming")
        hold(1.2)
        assertDetail(places, category: "upcoming", intent: "social")
        capture("places-journey-detail-fieldwork-social", app)
        places.back.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        assertBrowse(places, category: "upcoming", intent: "social")

        // Back to Signal: both values kept; Continue preview again: Upcoming kept.
        places.secondary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Social band · Chat first", "Back returns to the actual Signal, both kept.")
        XCTAssertTrue(signal.row("chatFirst").isSelected)
        hold(1.0)
        capture("places-journey-back-to-signal", app)
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(1.0)
        assertBrowse(places, category: "upcoming", intent: "social")
        capture("places-journey-reentry-upcoming-social", app)

        // A band change: back to the Wristband, Business, forward. Everything is recomputed.
        places.back.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        hold(0.6)
        band.tile("business").tap()
        XCTAssertTrue(waitFor(band.tile("business"), selected: true))
        hold(0.6)
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Business band · Chat first", "The approach is kept across the band change.")
        hold(0.8)
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(1.0)
        assertBrowse(places, category: "upcoming", intent: "business")
        capture("places-journey-upcoming-business", app)
        openDetail(places, category: "upcoming")
        hold(1.2)
        assertDetail(places, category: "upcoming", intent: "business")
        capture("places-journey-detail-fieldwork-business", app)
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        choose("now", places)
        hold(0.6)
        openDetail(places, category: "now")
        hold(1.0)
        assertDetail(places, category: "now", intent: "business")
        capture("places-journey-detail-common-ground-business", app)
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(1.2)
        assertExplanation(places)
        capture("places-journey-explanation-business", app)
        returnToNowThroughRoom(places)
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "now", intent: "business")
        assertNothingConferred(app)
        hold(1.2)
    }

    // MARK: - The seven screens

    /// Direct launches (the DEBUG fixtures `places`, `place-detail` and `place-explanation`, Social,
    /// Chat first), one per approved screen: the three categories, the three details and the
    /// explanation. The copy on every screen, the column and the targets on this phone's width;
    /// on the 440-pt iPhone the approved frames and what is drawn. Run on the iPhone 17 Pro Max and
    /// on the smaller iPhone; the captures name the width.
    func testSevenScreensOnThisPhone() throws {
        let screens: [(fixture: String, category: String, key: String, stage: PlacesStage)] = [
            ("places", "now", "01-now", .browse), ("places", "later", "02-later", .browse),
            ("places", "upcoming", "03-upcoming", .browse),
            ("place-detail", "now", "04-common-ground", .detail), ("place-detail", "later", "05-afterglow", .detail),
            ("place-detail", "upcoming", "06-fieldwork", .detail),
            ("place-explanation", "now", "07-check-in-explanation", .explanation),
        ]
        for screen in screens {
            let app = launch(fixture: screen.fixture, band: "social", approach: "chatFirst", category: screen.category)
            let places = PlacesScreen(app: app)
            switch screen.stage {
            case .browse:
                waitForLabel(places.headline, "Find your kind of place.")
                hold(0.8)
                assertBrowse(places, category: screen.category, intent: "social")
            case .detail:
                waitForLabel(places.name, Self.venue(screen.category).name)
                hold(0.8)
                assertDetail(places, category: screen.category, intent: "social")
            case .explanation:
                waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
                hold(0.8)
                assertExplanation(places)
            }
            let width = Int(app.frame.width.rounded())
            softlyGeometry(app, places, "\(screen.key), \(width) pt", stage: screen.stage, category: screen.category,
                           intent: "social")
            capture("places-screen-\(screen.key)-social-\(width)pt-fixture", app)
            softlyReachable(app, places, stage: screen.stage)
            assertNothingConferred(app)
            app.terminate()
        }
    }

    // MARK: - Eligibility

    /// Direct launches (fixture `places`, one per intent, Chat first): every intent at every venue,
    /// the twelve combinations. The browse line, then View place: the detail's primary label,
    /// whether it is enabled, and the last line. Only Social and Business at Common Ground open the
    /// explanation; every other combination stays on its detail when the disabled action is
    /// tapped, and its reason is on screen without a tap (the label and the ticket's last line).
    /// Back to places returns to the same category each time.
    func testEveryIntentAtEveryVenue() throws {
        var table: [String] = []
        for intent in Self.intents {
            let app = launch(fixture: "places", band: intent, approach: "chatFirst")
            let places = PlacesScreen(app: app)
            waitForLabel(places.headline, "Find your kind of place.")
            assertBrowse(places, category: "now", intent: intent)
            for category in Self.categories {
                choose(category, places)
                assertBrowse(places, category: category, intent: intent)
                openDetail(places, category: category)
                hold(0.6)
                assertDetail(places, category: category, intent: intent)
                let expected = Self.expected(category, intent)
                let venue = Self.venue(category)
                capture("places-eligibility-\(venue.key)-\(intent)-fixture", app)
                table.append("\(Self.titles[intent] ?? intent) at \(venue.name): “\(places.primary.label)” "
                             + "\(places.primary.isEnabled ? "enabled" : "disabled"); “\(places.lastLine.label)”")
                places.primary.tap()
                if expected.enabled {
                    waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
                    assertExplanation(places)
                    places.backToPlace.tap()
                    waitForLabel(places.name, venue.name)
                } else {
                    hold(0.5)
                    XCTAssertFalse(places.explanationHeadline.exists, "\(intent) at \(venue.name): nothing opens.")
                    XCTAssertEqual(places.name.label, venue.name, "Still on \(venue.name)'s detail.")
                }
                assertDetail(places, category: category, intent: intent)
                places.detailSecondary.tap()
                waitForLabel(places.headline, "Find your kind of place.")
                assertBrowse(places, category: category, intent: intent)
            }
            app.terminate()
        }
        attachNote("The twelve combinations, as shown: " + table.joined(separator: "; ") + ".")
    }

    // MARK: - Routes, retention and the band

    /// Direct launch (fixture `signal-selected`, Social, Chat first): the first entry opens Now; after
    /// a double tap on Continue preview one Back returns to Signal (the single push is proved by the
    /// domain's SignalRouteTests, since one Back would also leave a doubled Places); Later; its detail and the header Back
    /// (Later kept); "Back to places" (Later kept); the bottom Back to Signal (both kept);
    /// Continue preview (Later kept); Back through the Wristband to the Guest List card (the
    /// introduction kept) and forward again (the intent, the approach and Later kept); the
    /// explanation's header Back and "Back to place" (Common Ground's detail). A double tap on either
    /// Back stops one stage up. Chapter 08: a double tap on Preview room demo opens the Room entry
    /// once and nothing further (no run), the entry's Back returns to the actual explanation, and
    /// Back to place and Back to places return to Now.
    func testBackRoutesKeepTheCategoryAndTheDraft() throws {
        let app = launch(fixture: "signal-selected", band: "social", approach: "chatFirst")
        let signal = SignalScreen(app: app)
        let places = PlacesScreen(app: app)
        let band = Wristband(app: app)
        let guest = GuestList(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")

        signal.primary.doubleTap()
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "now", intent: "social")
        places.back.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(0.6)
        XCTAssertFalse(places.headline.exists, "After a double tap on Continue preview, one Back returns to Signal "
                       + "(the single push itself is proved in the domain: SignalRouteTests "
                       + "testContinuePreviewOpensPlacesOnceAndTheLegacyReadyIsUnreachable).")
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")

        choose("later", places)
        openDetail(places, category: "later")
        places.back.doubleTap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        XCTAssertTrue(places.headline.exists, "A double tap on the header Back stops at browsing.")
        assertBrowse(places, category: "later", intent: "social")
        openDetail(places, category: "later")
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "later", intent: "social")
        capture("places-back-to-places-later-fixture", app)

        places.secondary.doubleTap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        hold(0.8)
        XCTAssertEqual(signal.headline.label, "A hello, on your terms.", "A double tap on Back stops at Signal.")
        XCTAssertEqual(signal.summary.label, "Social band · Chat first")
        XCTAssertTrue(signal.row("chatFirst").isSelected)
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "later", intent: "social")

        // Back to the Guest List card and forward again: everything is kept.
        places.secondary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.back.tap()
        waitForLabel(guest.headline, "Your first hello.")
        XCTAssertEqual(guest.card.label, Self.alexCard, "The introduction is kept.")
        guest.primary.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertTrue(band.tile("social").isSelected, "The intent is kept.")
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Social band · Chat first", "The approach is kept.")
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "later", intent: "social")
        capture("places-reentry-after-card-later-fixture", app)

        // The explanation's two ways back, and Preview room demo.
        choose("now", places)
        openDetail(places, category: "now")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.back.doubleTap()
        waitForLabel(places.name, "Common Ground")
        hold(0.8)
        XCTAssertTrue(places.detailTicket.exists, "A double tap on the explanation's Back stops at the detail.")
        assertDetail(places, category: "now", intent: "social")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        places.backToPlace.tap()
        waitForLabel(places.name, "Common Ground")
        assertDetail(places, category: "now", intent: "social")
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        // The second tap lands where the entry's Enter room demo now is; it must not start a run.
        places.explore.doubleTap()
        waitForLabel(places.roomEnter, "Enter room demo")
        hold(0.8)
        XCTAssertTrue(places.roomEnter.exists, "A double tap on Preview room demo stops at the Room entry.")
        XCTAssertEqual(app.buttons.matching(identifier: "roomEntry.enter").count, 1, "The Room entry opened once.")
        let waiting = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "roomWaiting."))
        XCTAssertEqual(waiting.count, 0, "A double tap on Preview room demo starts no run: no waiting screen.")
        XCTAssertFalse(places.roomLeave.exists, "A double tap on Preview room demo starts no run: no Leave and disappear.")
        // Under the entry the explanation is hidden from accessibility, so its headline showing again
        // below is the entry's Back returning to it, not a headline that never went away.
        XCTAssertFalse(places.explanationHeadline.exists, "Under the Room entry the explanation is hidden from accessibility.")
        places.roomEntryBack.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        waitForAbsence(places.roomEnter)
        XCTAssertFalse(places.roomEnter.exists, "The entry's Back leaves the Room entry.")
        assertExplanation(places)
        places.backToPlace.tap()
        waitForLabel(places.name, "Common Ground")
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        assertBrowse(places, category: "now", intent: "social")
        assertNothingConferred(app)
    }

    /// Direct launch (fixture `places`, Social, Chat first, Upcoming): Fieldwork does not match
    /// Social. Back to the Wristband, Business, forward: the approach is kept and Upcoming is
    /// recomputed (Fieldwork matches; Opens Saturday); Common Ground opens the explanation. Back
    /// again, Activity: Upcoming matches but stays closed; Common Ground permits the preview.
    func testChangingTheBandRecomputesEveryVenue() throws {
        let app = launch(fixture: "places", band: "social", approach: "chatFirst", category: "upcoming")
        let places = PlacesScreen(app: app)
        let signal = SignalScreen(app: app)
        let band = Wristband(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "upcoming", intent: "social")
        capture("places-band-before-social-upcoming-fixture", app)

        for (intent, title) in [("business", "Business"), ("activity", "Activity")] {
            places.secondary.tap()
            waitForLabel(signal.headline, "A hello, on your terms.")
            signal.back.tap()
            waitForLabel(band.headline, "Choose your kind of hello.")
            band.tile(intent).tap()
            XCTAssertTrue(waitFor(band.tile(intent), selected: true))
            band.primary.tap()
            waitForLabel(signal.headline, "A hello, on your terms.")
            XCTAssertEqual(signal.summary.label, "\(title) band · Chat first", "The approach is kept.")
            signal.primary.tap()
            waitForLabel(places.headline, "Find your kind of place.")
            assertBrowse(places, category: "upcoming", intent: intent)
            capture("places-band-\(intent)-upcoming-fixture", app)
            openDetail(places, category: "upcoming")
            assertDetail(places, category: "upcoming", intent: intent)
            places.detailSecondary.tap()
            waitForLabel(places.headline, "Find your kind of place.")
            choose("now", places)
            assertBrowse(places, category: "now", intent: intent)
            openDetail(places, category: "now")
            assertDetail(places, category: "now", intent: intent)
            capture("places-band-\(intent)-common-ground-fixture", app)
            places.primary.tap()
            if Self.expected("now", intent).enabled {
                waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
                returnToNowThroughRoom(places)
            } else {
                hold(0.5)
                XCTAssertFalse(places.explanationHeadline.exists)
                places.detailSecondary.tap()
            }
            waitForLabel(places.headline, "Find your kind of place.")
            choose("upcoming", places)
        }
    }

    /// Direct launches: without an approach (`places` with a band only) or an intent there is no
    /// Places fixture at all: the app opens at Welcome, never with an assumed choice. Signal
    /// without an approach keeps Continue preview disabled and Places closed; the Wristband
    /// without an intent keeps Signal closed. The explanation's own destination is guarded: the
    /// four-intent revision permits Dating and Activity at Common Ground, while future venues remain closed.
    func testMissingChoicesAndIneligibleIntentsNeverOpenIt() throws {
        for arguments in [["-ProximeetFixture", "places", "-ProximeetFixtureBand", "social"],
                          ["-ProximeetFixture", "place-detail", "-ProximeetFixtureSignal", "chatFirst"]] {
            let app = XCUIApplication()
            app.launchArguments = arguments
            app.launch()
            XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 15),
                          "No Places without both choices: \(arguments.joined(separator: " ")) opens Welcome.")
            XCTAssertFalse(PlacesScreen(app: app).headline.exists)
            app.terminate()
        }

        let app = launch(fixture: "signal", band: "dating")
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertFalse(signal.primary.isEnabled, "No approach, no Continue preview.")
        signal.primary.tap()
        hold(0.8)
        XCTAssertFalse(PlacesScreen(app: app).headline.exists, "Places did not open without an approach.")
        app.terminate()

        let wristband = launch(fixture: "wristband")
        let band = Wristband(app: wristband)
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertFalse(band.primary.isEnabled)
        band.primary.tap()
        hold(0.8)
        XCTAssertFalse(SignalScreen(app: wristband).headline.exists)
        XCTAssertFalse(PlacesScreen(app: wristband).headline.exists)
        wristband.terminate()

        // Supersedes the old Common Ground mismatch rows; the same destination guards still run.
        for intent in ["dating", "activity"] {
            let admitted = launch(fixture: "place-explanation", band: intent, approach: "okayToSayHello")
            let places = PlacesScreen(app: admitted)
            waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
            assertExplanation(places)
            capture("places-four-intent-explanation-\(intent)-fixture", admitted)
            admitted.terminate()
        }
        // Both an allowed-but-future session and an intent mismatch must still refuse the action.
        for (intent, category) in [("dating", "later"), ("activity", "upcoming"), ("business", "later")] {
            let guarded = launch(fixture: "place-detail", band: intent, approach: "okayToSayHello", category: category)
            let places = PlacesScreen(app: guarded)
            waitForLabel(places.name, Self.venue(category).name)
            assertDetail(places, category: category, intent: intent)
            XCTAssertFalse(places.primary.isEnabled)
            places.primary.tap()
            hold(0.6)
            XCTAssertFalse(places.explanationHeadline.exists, "\(intent) / \(category): unavailable session stays closed.")
            capture("places-guarded-explanation-\(intent)-\(category)-fixture", guarded)
            guarded.terminate()
        }
    }

    // MARK: - The Birthday gate on the way back

    /// Direct launch (fixture `places`, Activity, Okay to say hello, Later), then Back through
    /// every chapter to Birthday; an under-18 date blocks Continue while the drafts stay in memory;
    /// the corrected date needs an explicit Continue and opens the Pass at its intro, never Places;
    /// completed again, the route forward keeps the introduction, the intent, the approach and
    /// Later.
    func testAgeGateOnTheWayBackBlocksPlaces() throws {
        let app = launch(fixture: "places", band: "activity", approach: "okayToSayHello", category: "later")
        let places = PlacesScreen(app: app)
        let signal = SignalScreen(app: app)
        let band = Wristband(app: app)
        let guest = GuestList(app: app)
        let pass = PassScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "later", intent: "activity")

        places.secondary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        signal.back.tap()
        waitForLabel(band.headline, "Choose your kind of hello.")
        band.back.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.back.tap()
        waitForLabel(guest.headline, "A little about you.")
        guest.secondary.tap()
        XCTAssertTrue(pass.headline.waitForExistence(timeout: 15))
        pass.back.tap()
        let birthdayHeadline = app.descendants(matching: .any)["birthday.headline"]
        XCTAssertTrue(birthdayHeadline.waitForExistence(timeout: 15), "Back through every chapter reaches Birthday.")

        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "2012")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: false), "An under-18 date disables Continue.")
        proceed.tap()
        hold(0.8)
        XCTAssertTrue(birthdayHeadline.exists, "Still on Birthday.")
        XCTAssertFalse(pass.headline.exists)
        XCTAssertFalse(places.headline.exists, "Places is not reachable.")
        capture("places-age-gate-under18-fixture", app)

        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        XCTAssertTrue(waitFor(proceed, enabled: true))
        hold(0.6)
        XCTAssertTrue(birthdayHeadline.exists, "A corrected date moves nothing by itself.")
        proceed.tap()
        waitForLabel(pass.headline, "Your next chapter.")
        XCTAssertFalse(places.headline.exists, "The Pass intro, not Places.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        tapDistinctPrimary(pass.primary, label: "Finish preview")
        waitForLabel(pass.headline, "Demo complete.")
        pass.primary.tap()
        waitForLabel(guest.headline, "A little about you.")
        XCTAssertEqual(guest.name.value as? String, "Alex", "The introduction was kept in memory.")
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        tapDistinctPrimary(guest.primary, label: "Continue preview")
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertTrue(band.tile("activity").isSelected, "The intent was kept.")
        band.primary.tap()
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Activity band · Okay to say hello", "The approach was kept.")
        signal.primary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "later", intent: "activity")
        capture("places-age-gate-forward-again-fixture", app)
    }

    // MARK: - Memory only

    /// Direct launch (fixture `place-detail`, Business, Upcoming), then a relaunch without one and
    /// the real route with Dating and Okay to say hello: Places opens at Now, the new intent's
    /// eligibility, nothing carried over.
    func testRelaunchStartsAtNowWithNothingKept() throws {
        var app = launch(fixture: "place-detail", band: "business", approach: "chatFirst", category: "upcoming")
        var places = PlacesScreen(app: app)
        waitForLabel(places.name, "Fieldwork")
        assertDetail(places, category: "upcoming", intent: "business")

        app.terminate()
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 15), "A fresh launch starts at Welcome.")
        let pass = openCompletedPass(app)
        pass.primary.tap()
        let guest = GuestList(app: app)
        waitForLabel(guest.headline, "A little about you.")
        XCTAssertEqual((guest.name.value as? String) ?? "", guest.name.placeholderValue ?? "", "No name after a relaunch.")
        guest.name.tap()
        XCTAssertTrue(waitForFocus(guest.name))
        guest.name.typeText("Sam")
        tapKeyboardDone(app)
        guest.primary.tap()
        waitForLabel(guest.headline, "Your first hello.")
        guest.primary.tap()
        let band = Wristband(app: app)
        waitForLabel(band.headline, "Choose your kind of hello.")
        XCTAssertFalse(band.tile("business").isSelected, "No intent after a relaunch.")
        band.tile("dating").tap()
        band.primary.tap()
        let signal = SignalScreen(app: app)
        waitForLabel(signal.headline, "A hello, on your terms.")
        XCTAssertEqual(signal.summary.label, "Dating band · Choose your approach", "No approach after a relaunch.")
        signal.row("okayToSayHello").tap()
        XCTAssertTrue(waitFor(signal.row("okayToSayHello"), selected: true))
        signal.primary.tap()
        places = PlacesScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        assertBrowse(places, category: "now", intent: "dating")
        hold(0.6)
        capture("places-after-relaunch-now-dating", app)
    }

    // MARK: - Rapid taps and interrupted motion

    /// Direct launch (fixture `places`, Social, Chat first): four tabs tapped in quick succession
    /// leave the last; View place straight after a tab, Back and Preview check-in straight after
    /// View place, and the app sent to the background straight after View place and resumed, each
    /// leave the model and what is drawn in agreement. Each tap is issued without a hold; XCUITest
    /// may still wait for the app to settle before a tap, so this shows that nothing is lost or
    /// duplicated, not that a tap landed at a given point of a movement.
    func testRapidTapsAndInterruptedMotionReconcile() throws {
        let app = launch(fixture: "places", band: "social", approach: "chatFirst")
        let places = PlacesScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        for category in ["later", "upcoming", "now", "later"] {
            places.tab(category).tap()
        }
        XCTAssertTrue(waitFor(places.tab("later"), selected: true))
        hold(0.6)
        assertBrowse(places, category: "later", intent: "social")
        softlyDrawn(app, "After rapid tabs", stage: .browse, category: "later", intent: "social")
        capture("places-after-rapid-tabs-fixture", app)

        // View place straight after the tab.
        places.tab("upcoming").tap()
        places.viewPlace.tap()
        waitForLabel(places.name, "Fieldwork")
        hold(0.8)
        assertDetail(places, category: "upcoming", intent: "social")
        capture("places-view-place-after-tab-fixture", app)

        // Back straight after View place.
        places.detailSecondary.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        places.tab("now").tap()
        XCTAssertTrue(waitFor(places.tab("now"), selected: true))
        hold(0.5)
        places.viewPlace.tap()
        places.back.tap()
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.8)
        assertBrowse(places, category: "now", intent: "social")
        softlyDrawn(app, "Back straight after View place", stage: .browse, category: "now", intent: "social")
        capture("places-back-after-view-place-fixture", app)

        // Preview check-in straight after View place.
        places.viewPlace.tap()
        places.primary.tap()
        waitForLabel(places.explanationHeadline, "Arrive. Then connect.")
        hold(0.8)
        assertExplanation(places)
        softlyDrawn(app, "Preview check-in straight after View place", stage: .explanation, category: "now", intent: "social")
        returnToNowThroughRoom(places)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.5)

        // The app sent to the background straight after View place, then resumed.
        places.viewPlace.tap()
        XCUIDevice.shared.press(.home)
        hold(2.0)
        app.activate()
        XCTAssertTrue(places.detailTicket.waitForExistence(timeout: 15), "The detail is showing after resume.")
        hold(0.8)
        assertDetail(places, category: "now", intent: "social")
        softlyGeometry(app, places, "Resumed after the background", stage: .detail, category: "now", intent: "social")
        capture("places-after-background-resume-fixture", app)
    }

    // MARK: - Reduce Motion

    /// Direct launch (fixture `places`, Business, Chat first) with the app-level preview flag
    /// `-ProximeetReduceMotionPreview YES` (not the system setting): View place dissolves instead
    /// of expanding. The detail is in the model at once; no frame shows the ticket's top edge
    /// between its browse and detail positions; the settled detail is the approved one.
    func testReduceMotionPreviewReplacesTheExpansion() throws {
        let app = launch(fixture: "places", band: "business", approach: "chatFirst",
                         extra: ["-ProximeetReduceMotionPreview", "YES"])
        let places = PlacesScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(0.6)
        places.viewPlace.tap()
        let early = RenderedScreen(app).map(Self.ticketEdges)
        XCTAssertTrue(places.primary.waitForExistence(timeout: 5), "The detail is in the model at once.")
        hold(1.0)
        let settled = RenderedScreen(app).map(Self.ticketEdges)
        capture("places-reduce-motion-preview-detail-fixture", app)
        assertDetail(places, category: "now", intent: "business")
        attachNote("Reduce Motion preview: sharp ivory edges between y 250 and 455 (not the tabs' rows) at x 60–88, just after the tap "
                   + "\(early.map { "\($0)" } ?? "unread"), settled \(settled.map { "\($0)" } ?? "unread").")
        softly {
            XCTAssertEqual(early ?? [], [], "Reduce Motion: no frame shows the ticket part-way through an expansion.")
            XCTAssertEqual(settled ?? [], [], "Settled: the detail's ticket starts at y 238.")
        }
        softlyDrawn(app, "Reduce Motion, settled", stage: .detail, category: "now", intent: "business")
    }

    // MARK: - Largest text

    /// Direct launches (fixtures `places` and `place-detail`, Social, Chat first) at the largest
    /// accessibility text size: DEMO is drawn whole, the headline wraps, the tabs stack rather
    /// than truncate, the ticket, its line, every part of a detail and of the explanation are
    /// reachable by scrolling, and the actions stay on screen. Run on the iPhone 17 Pro Max and on
    /// the smaller iPhone; the captures name the width.
    func testLargestTextKeepsEveryStageReachable() throws {
        let app = launch(fixture: "places", band: "social", approach: "chatFirst", category: "upcoming",
                         extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let places = PlacesScreen(app: app)
        waitForLabel(places.headline, "Find your kind of place.")
        hold(1.0)
        let width = Int(app.frame.width.rounded())
        XCTAssertGreaterThan(places.headline.frame.height, 112 + 10, "The largest text size must be applied.")
        attachNote("Largest text, \(width) pt wide: headline \(NSCoder.string(for: places.headline.frame)); tabs "
                   + "\(NSCoder.string(for: places.tabs.frame)).")
        capture("places-largest-text-browse-top-\(width)pt-fixture", app)
        softly {
            guard let shot = RenderedScreen(app) else { return }
            let clusters = shot.inkColumns(in: CGRect(x: app.frame.width - 240, y: 50, width: 240, height: 110), where: Self.cyan)
            let tallest = clusters.map { $0.height }.max() ?? 0
            XCTAssertGreaterThanOrEqual(clusters.count, 4, "DEMO should be drawn as its letters.")
            XCTAssertFalse(clusters.contains { $0.height < tallest * 0.5 }, "DEMO is truncated: an ellipsis is drawn.")
            XCTAssertGreaterThan(places.headline.frame.height, 300, "The headline wraps rather than shrinks.")
        }
        XCTAssertTrue(places.back.isHittable)
        let tabs = Self.categories.map { places.tab($0) }
        for tab in tabs {
            XCTAssertTrue(scrollIntoView(tab, bar: places.secondary, app), "\(tab.identifier) is reachable.")
            XCTAssertGreaterThanOrEqual(tab.frame.height, Self.minimumTarget)
        }
        XCTAssertGreaterThan(Set(tabs.map { Int($0.frame.minY.rounded()) }).count, 1, "The tabs stack at this size.")
        for element in [places.viewPlace, places.browseLine] {
            XCTAssertTrue(scrollIntoView(element, bar: places.secondary, app), "\(element.identifier) is reachable.")
        }
        XCTAssertEqual(places.browseLine.label, Self.expected("upcoming", "social").browse)
        XCTAssertTrue(places.secondary.isHittable, "Back stays on screen.")
        capture("places-largest-text-browse-bottom-\(width)pt-fixture", app)
        // View place, the button itself, scrolled fully into view.
        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, app))
        places.viewPlace.tap()
        waitForLabel(places.name, "Fieldwork")
        hold(0.8)
        XCTAssertTrue(places.primary.isHittable && places.detailSecondary.isHittable, "Both actions stay on screen.")
        XCTAssertEqual(places.primary.label, "Not available for Social")
        XCTAssertFalse(places.primary.isEnabled)
        capture("places-largest-text-detail-top-\(width)pt-fixture", app)
        for element in [places.name, places.kind, places.schedule, places.intents, places.host, places.brief,
                        places.rules, places.lastLine] {
            XCTAssertTrue(scrollIntoView(element, bar: places.primary, app), "\(element.identifier) is reachable by scrolling.")
            XCTAssertGreaterThanOrEqual(element.frame.minX, 31)
            XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.width - 31)
        }
        XCTAssertEqual(places.lastLine.label, "Your Social band doesn’t match this session.")
        capture("places-largest-text-detail-bottom-\(width)pt-fixture", app)
        app.terminate()

        let explained = launch(fixture: "place-explanation", band: "social", approach: "chatFirst",
                               extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let explanation = PlacesScreen(app: explained)
        waitForLabel(explanation.explanationHeadline, "Arrive. Then connect.")
        hold(0.8)
        XCTAssertTrue(explanation.explore.isHittable && explanation.backToPlace.isHittable, "Both actions stay on screen.")
        capture("places-largest-text-explanation-top-\(width)pt-fixture", explained)
        for element in [explanation.explanationSupport, explanation.explanationVenue, explanation.step(1),
                        explanation.step(2), explanation.presence, explanation.demoLine] {
            XCTAssertTrue(scrollIntoView(element, bar: explanation.explore, explained), "\(element.identifier) is reachable.")
        }
        capture("places-largest-text-explanation-bottom-\(width)pt-fixture", explained)
    }

    // MARK: - Route helpers

    /// A new choice on the same physical button, not the second touch of a rapid double tap.
    /// Pass/Guest List deliberately swallow UIKit repeat taps. Match PassReviewTests' far-side
    /// tap so this journey makes one distinct input without changing that product protection.
    private func tapDistinctPrimary(_ element: XCUIElement, label: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        waitForLabel(element, label)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@ AND isEnabled == true AND isHittable == true", label),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
                       "The intended primary action must be enabled and hittable before its single tap.",
                       file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
    }

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ProximeetFixture", "welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.moreOptions"].waitForExistence(timeout: 15))
        return app
    }

    private func launch(fixture: String, band: String? = nil, approach: String? = nil, category: String? = nil,
                        extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ProximeetFixture", fixture]
        if let band { arguments += ["-ProximeetFixtureBand", band] }
        if let approach { arguments += ["-ProximeetFixtureSignal", approach] }
        if let category { arguments += ["-ProximeetFixtureCategory", category] }
        app.launchArguments = arguments + extra
        app.launch()
        return app
    }

    /// Welcome → Birthday with 12 May 1997 → Continue → Pass → Try the demo → Finish preview.
    private func openCompletedPass(_ app: XCUIApplication) -> PassScreen {
        app.buttons["welcome.moreOptions"].tap()
        let demo = app.buttons.matching(NSPredicate(format: "label == %@", "Continue the demo (no account)")).firstMatch
        XCTAssertTrue(demo.waitForExistence(timeout: 10), "More options should offer the demo.")
        demo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["birthday.headline"].waitForExistence(timeout: 15), "Birthday should open.")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "12")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "May")
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1997")
        let proceed = app.buttons["birthday.continue"]
        XCTAssertTrue(waitFor(proceed, enabled: true), "12 May 1997 should enable Continue.")
        proceed.tap()
        let pass = PassScreen(app: app)
        waitForLabel(pass.headline, "Your next chapter.")
        pass.primary.tap()
        waitForLabel(pass.headline, "Demo in progress.")
        tapDistinctPrimary(pass.primary, label: "Finish preview")
        waitForLabel(pass.headline, "Demo complete.")
        return pass
    }

    /// A category's tab, selected once the model has it and its venue's ticket shows.
    private func choose(_ category: String, _ places: PlacesScreen) {
        places.tab(category).tap()
        XCTAssertTrue(waitFor(places.tab(category), selected: true), "\(category) is selected.")
        waitForLabel(places.ticketName, Self.venue(category).name)
    }

    /// View place, the button itself, brought fully into view: the category's detail.
    private func openDetail(_ places: PlacesScreen, category: String) {
        XCTAssertTrue(scrollIntoView(places.viewPlace, bar: places.secondary, places.app), "View place is reachable.")
        places.viewPlace.tap()
        waitForLabel(places.name, Self.venue(category).name)
    }

    /// From Common Ground's explanation back to browsing at Now. Chapter 08 made the explanation's
    /// primary "Preview room demo", which opens the Room entry above the explanation instead of
    /// browsing; the approved way on to Places is the Room's whole explicit sequence: Preview room
    /// demo → Enter room demo → Leave and disappear → Return to Places, which is actual browsing at
    /// Now, from the top, with the draft intact (the route Explore other places took). The caller
    /// waits for browsing, as it did after Explore other places.
    private func returnToNowThroughRoom(_ places: PlacesScreen) {
        places.explore.tap()
        waitForLabel(places.roomEnter, "Enter room demo")
        hold(0.6)
        places.roomEnter.tap()
        waitForLabel(places.roomLeave, "Leave and disappear")
        // Entering moves the entry's ticket into the header (500 ms); Leave is tapped once it rests.
        hold(0.6)
        places.roomLeave.tap()
        waitForLabel(places.roomReturnToPlaces, "Return to Places")
        // Return to Places sits 10 pt from where Leave was; a pause keeps the two taps from counting
        // as one double tap, which the repeat-tap guard would swallow.
        hold(0.6)
        places.roomReturnToPlaces.tap()
        // The Room dissolves away above Places; nothing that follows should tap into its fade.
        waitForAbsence(places.roomReturnToPlaces)
    }

    // MARK: - Assertions

    /// Browsing a category: the fixed copy, exactly its tab selected, its venue's ticket as one
    /// action, the line for the actual intent, and the targets.
    private func assertBrowse(_ places: PlacesScreen, category: String, intent: String) {
        let venue = Self.venue(category)
        XCTAssertEqual(places.headline.label, "Find your kind of place.")
        XCTAssertEqual(places.context.label, "Fictional venues · demo Thursday, 8 pm")
        XCTAssertEqual(places.demoBadge.label, "Demo")
        for other in Self.categories {
            let tab = places.tab(other)
            XCTAssertEqual(tab.label, Self.categoryTitles[other] ?? other)
            XCTAssertEqual(tab.isSelected, other == category, "\(other) selected: \(tab.isSelected)")
            XCTAssertGreaterThanOrEqual(tab.frame.height, Self.minimumTarget)
        }
        XCTAssertEqual(places.ticketName.label, venue.name)
        XCTAssertEqual(places.ticketKind.label, venue.kind)
        XCTAssertEqual(places.ticketIntents.label, "For \(Self.intentsLine(venue)) bands")
        XCTAssertEqual(places.ticketSchedule.label, venue.schedule, "The whole schedule.")
        XCTAssertEqual(places.viewPlace.label, "View place", "View place is the ticket's action.")
        XCTAssertGreaterThanOrEqual(places.viewPlace.frame.height, Self.minimumTarget)
        XCTAssertEqual(places.browseLine.label, Self.expected(category, intent).browse)
        XCTAssertFalse(places.detailTicket.exists, "Browsing shows no detail.")
        XCTAssertFalse(places.explanationHeadline.exists)
        XCTAssertEqual(places.secondary.label, "Back")
        XCTAssertGreaterThanOrEqual(places.secondary.frame.height, Self.minimumTarget)
        XCTAssertGreaterThanOrEqual(places.back.frame.height, Self.minimumTarget)
        XCTAssertGreaterThanOrEqual(places.back.frame.width, Self.minimumTarget)
    }

    /// A venue's detail for the actual intent: every line of the ticket, the primary action's
    /// label and state (the reason in its label when disabled) and Back to places.
    private func assertDetail(_ places: PlacesScreen, category: String, intent: String) {
        let venue = Self.venue(category)
        let expected = Self.expected(category, intent)
        XCTAssertEqual(places.name.label, venue.name)
        XCTAssertEqual(places.kind.label, venue.kind)
        XCTAssertEqual(places.schedule.label, venue.schedule)
        XCTAssertEqual(places.intents.label, "For \(Self.intentsLine(venue)) bands")
        XCTAssertEqual(places.host.label, venue.host)
        XCTAssertEqual(places.brief.label, venue.brief)
        let rules = places.rules.label
        XCTAssertTrue(rules.contains("Respect a no.") && rules.contains("Stay within the venue."), "Rules: “\(rules)”.")
        XCTAssertEqual(places.lastLine.label, expected.detail)
        XCTAssertEqual(places.primary.label, expected.primary)
        XCTAssertEqual(places.primary.isEnabled, expected.enabled, "\(intent) at \(venue.name): enabled \(places.primary.isEnabled).")
        XCTAssertGreaterThanOrEqual(places.primary.frame.height, 60)
        XCTAssertEqual(places.detailSecondary.label, "Back to places")
        XCTAssertGreaterThanOrEqual(places.detailSecondary.frame.height, Self.minimumTarget)
        XCTAssertEqual(places.demoBadge.label, "Demo")
        XCTAssertFalse(places.headline.exists, "The detail replaces browsing.")
        XCTAssertFalse(places.explanationHeadline.exists)
    }

    /// Common Ground's explanation: its exact words and both exits; no ticket, no tabs.
    private func assertExplanation(_ places: PlacesScreen) {
        XCTAssertEqual(places.explanationHeadline.label, "Arrive. Then connect.")
        XCTAssertEqual(places.explanationSupport.label, "A place opens when you’re really there.")
        let card = places.explanationVenue.label
        XCTAssertTrue(card.contains("Common Ground") && card.contains("Fictional venue · Today, 6–10 pm"), "Card: “\(card)”.")
        let first = places.step(1).label, second = places.step(2).label
        XCTAssertTrue(first.contains("Confirm you’re here")
                      && first.contains("One location check while the app is open. No background tracking."), "Step 1: “\(first)”.")
        XCTAssertTrue(second.contains("Scan the venue’s code") && second.contains("Scan the rotating QR shown at the venue."),
                      "Step 2: “\(second)”.")
        XCTAssertEqual(places.presence.label, "You stay private until both checks pass.")
        XCTAssertEqual(places.demoLine.label, "Demo · no location or camera used.")
        XCTAssertEqual(places.explore.label, "Preview room demo")
        XCTAssertTrue(places.explore.isEnabled)
        XCTAssertGreaterThanOrEqual(places.explore.frame.height, 60)
        XCTAssertEqual(places.backToPlace.label, "Back to place")
        XCTAssertGreaterThanOrEqual(places.backToPlace.frame.height, Self.minimumTarget)
        XCTAssertEqual(places.demoBadge.label, "Demo")
        XCTAssertFalse(places.detailTicket.exists)
        XCTAssertFalse(places.headline.exists)
    }

    /// Nothing claims a check-in, a booking, visibility, a match, a Wave or a chat, and no
    /// permission or provider prompt appeared (in the app or from the system).
    private func assertNothingConferred(_ app: XCUIApplication) {
        let words = ["verified", "access granted", "checked in", "check-in complete", "you're visible", "you’re visible",
                     "now visible", "nearby", "matched", "online now", "member", "discoverable", "wave sent",
                     "chat open", "message sent", "booked", "reserved", "confirmed", "people here", "guests here"]
        let predicate = NSPredicate(format: words.map { _ in "label CONTAINS[c] %@" }.joined(separator: " OR "), argumentArray: words)
        XCTAssertEqual(app.descendants(matching: .any).matching(predicate).count, 0,
                       "No check-in, booking, visible, matched, Wave or chat wording.")
        XCTAssertEqual(app.alerts.count, 0, "No prompt appeared in the app.")
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0,
                       "No system permission prompt (location, camera, notifications) appeared.")
    }

    // MARK: - Frames

    /// The column and the targets on any width (content min(376, width − 64), centred); on the
    /// 440 × 956 iPhone, the approved Figma frames: boxes to 1 pt, text line tops to 3 pt (a text
    /// element's frame is its glyphs' line box, inside the Figma text box's leading).
    private func softlyGeometry(_ app: XCUIApplication, _ places: PlacesScreen, _ state: String, stage: PlacesStage,
                                category: String, intent: String) {
        softly {
            let width = app.frame.width
            let content = min(376, width - 64), margin = (width - content) / 2
            var lines: [String] = []
            @MainActor func box(_ element: XCUIElement, _ name: String, _ rect: CGRect, tolerance: CGFloat = 1) {
                let frame = element.frame
                lines.append("\(name) \(NSCoder.string(for: frame))")
                XCTAssertEqual(frame.minX, rect.minX, accuracy: tolerance, "\(state): \(name) x \(frame.minX), approved \(rect.minX).")
                XCTAssertEqual(frame.minY, rect.minY, accuracy: tolerance, "\(state): \(name) y \(frame.minY), approved \(rect.minY).")
                XCTAssertEqual(frame.width, rect.width, accuracy: tolerance, "\(state): \(name) width \(frame.width), approved \(rect.width).")
                XCTAssertEqual(frame.height, rect.height, accuracy: tolerance, "\(state): \(name) height \(frame.height), approved \(rect.height).")
            }
            @MainActor func top(_ element: XCUIElement, _ name: String, x: CGFloat?, y: CGFloat) {
                let frame = element.frame
                lines.append("\(name) \(NSCoder.string(for: frame))")
                XCTAssertEqual(frame.minY, y, accuracy: 3, "\(state): \(name) top \(frame.minY), approved line box \(y).")
                if let x {
                    XCTAssertEqual(frame.minX, x, accuracy: 1, "\(state): \(name) x \(frame.minX), approved \(x).")
                }
            }
            // Every width: the header's Back, the column, the targets.
            XCTAssertGreaterThanOrEqual(places.back.frame.width, Self.minimumTarget)
            XCTAssertGreaterThanOrEqual(places.back.frame.height, Self.minimumTarget)
            switch stage {
            case .browse:
                XCTAssertEqual(places.tabs.frame.minX, margin, accuracy: 1, "\(state): the tabs start at the column.")
                XCTAssertEqual(places.tabs.frame.width, content, accuracy: 1, "\(state): the tabs span the column.")
                XCTAssertEqual(places.ticketName.frame.minX, margin + 20, accuracy: 1, "\(state): the ticket's text starts at its column.")
                XCTAssertLessThanOrEqual(places.viewPlace.frame.maxX, margin + content - 19, "\(state): View place stays inside the ticket.")
                XCTAssertEqual(places.secondary.frame.width, content, accuracy: 1)
            case .detail:
                XCTAssertEqual(places.detailTicket.frame.minX, margin, accuracy: 1, "\(state): the ticket starts at the column.")
                XCTAssertEqual(places.detailTicket.frame.width, content, accuracy: 1, "\(state): the ticket spans the column.")
                XCTAssertEqual(places.primary.frame.width, content, accuracy: 1)
                XCTAssertEqual(places.detailSecondary.frame.width, content, accuracy: 1)
            case .explanation:
                XCTAssertEqual(places.explanationVenue.frame.minX, margin, accuracy: 1)
                XCTAssertEqual(places.explanationVenue.frame.width, content, accuracy: 1)
                XCTAssertEqual(places.explore.frame.width, content, accuracy: 1)
                XCTAssertEqual(places.backToPlace.frame.width, content, accuracy: 1)
            }
            guard app.frame.size == CGSize(width: 440, height: 956) else {
                attachNote("\(state): frames (points, \(Int(width)) pt wide): " + lines.joined(separator: "; ") + ".")
                return
            }
            box(places.back, "Back", CGRect(x: 24, y: 64, width: 44, height: 44))
            switch stage {
            case .browse:
                // The headline's accessibility frame is its words' union, not the 376 x 112 box, so
                // only its x is checked here; its drawn glyph rows are checked in softlyDrawn.
                lines.append("Headline \(NSCoder.string(for: places.headline.frame))")
                XCTAssertEqual(places.headline.frame.minX, 32, accuracy: 1, "\(state): Headline x \(places.headline.frame.minX), approved 32.")
                top(places.context, "Snapshot line", x: 32, y: 274)
                box(places.tabs, "Tabs", CGRect(x: 32, y: 316, width: 376, height: 48))
                for (index, key) in Self.categories.enumerated() {
                    box(places.tab(key), "Tab \(key)", CGRect(x: 36 + CGFloat(index) * 124, y: 318, width: 120, height: 44))
                }
                let facts = Self.venue(category)
                top(places.ticketName, "Name", x: 52, y: 626)
                top(places.ticketKind, "Kind", x: 52, y: 670)
                box(places.ticketIntents, "Intent chips", CGRect(x: 52, y: 702, width: facts.chipsWidth, height: 26))
                top(places.ticketSchedule, "Schedule", x: 52, y: 754)
                box(places.viewPlace, "View place", CGRect(x: 248, y: 754, width: 140, height: 44))
                top(places.browseLine, "Browse line", x: nil, y: 837)
                box(places.secondary, "Back (bottom)", CGRect(x: 32, y: 883, width: 376, height: 44))
            case .detail:
                let venue = Self.venue(category)
                let matches = venue.permitted.contains(intent)
                box(places.detailTicket, "Ticket", CGRect(x: 32, y: 146, width: 376, height: 630))
                top(places.name, "Name", x: 52, y: 398)
                top(places.kind, "Kind", x: 52, y: 442)
                top(places.schedule, "Schedule", x: 52, y: 498)
                box(places.intents, "Intent chips", CGRect(x: 52, y: 536, width: venue.chipsWidth, height: 26))
                top(places.host, "Host", x: 52, y: 576)
                top(places.brief, "Description", x: 52, y: 613)
                top(places.rules, "Rules", x: 52, y: 682)
                top(places.lastLine, "Last line", x: 52, y: matches ? 742 : 728)
                box(places.primary, "Primary", CGRect(x: 32, y: 812, width: 376, height: 60))
                box(places.detailSecondary, "Back to places", CGRect(x: 32, y: 883, width: 376, height: 44))
            case .explanation:
                // As on browsing: the headline's x here, its drawn glyph rows in softlyDrawn.
                lines.append("Headline \(NSCoder.string(for: places.explanationHeadline.frame))")
                XCTAssertEqual(places.explanationHeadline.frame.minX, 32, accuracy: 1,
                               "\(state): Headline x \(places.explanationHeadline.frame.minX), approved 32.")
                top(places.explanationSupport, "Support", x: 32, y: 274)
                box(places.explanationVenue, "Venue card", CGRect(x: 32, y: 330, width: 376, height: 88))
                box(places.step(1), "Step 1", CGRect(x: 32, y: 445, width: 376, height: 112))
                box(places.step(2), "Step 2", CGRect(x: 32, y: 573, width: 376, height: 112))
                top(places.presence, "Presence line", x: nil, y: 711)
                top(places.demoLine, "Demo line", x: nil, y: 751)
                box(places.explore, "Preview room demo", CGRect(x: 32, y: 812, width: 376, height: 60))
                box(places.backToPlace, "Back to place", CGRect(x: 32, y: 883, width: 376, height: 44))
            }
            attachNote("\(state): frames (points, 440 × 956): " + lines.joined(separator: "; ") + ".")
        }
        softlyDrawn(app, state, stage: stage, category: category, intent: intent)
    }

    /// On any width: every part of the stage can be brought between the status bar and the
    /// action bar, and the actions are on screen.
    private func softlyReachable(_ app: XCUIApplication, _ places: PlacesScreen, stage: PlacesStage) {
        softly {
            switch stage {
            case .browse:
                for element in [places.viewPlace, places.browseLine] {
                    XCTAssertTrue(scrollIntoView(element, bar: places.secondary, app), "\(element.identifier) is reachable.")
                }
                XCTAssertTrue(places.secondary.isHittable)
            case .detail:
                for element in [places.name, places.intents, places.brief, places.rules, places.lastLine] {
                    XCTAssertTrue(scrollIntoView(element, bar: places.primary, app), "\(element.identifier) is reachable.")
                }
                XCTAssertTrue(places.primary.isHittable && places.detailSecondary.isHittable)
            case .explanation:
                for element in [places.explanationVenue, places.step(2), places.demoLine] {
                    XCTAssertTrue(scrollIntoView(element, bar: places.explore, app), "\(element.identifier) is reachable.")
                }
                XCTAssertTrue(places.explore.isHittable && places.backToPlace.isHittable)
            }
        }
    }

    // MARK: - Waiting and input

    /// Returns at once when the label is already shown; otherwise waits up to 15 s for it. (An
    /// XCTNSPredicateExpectation makes its first check about a second after it starts, so a state
    /// that already holds is read directly rather than polled.)
    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        if element.exists && element.label == label {
            return
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(element.identifier) should be showing.")
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        // Generous: under load a snapshot can take seconds; the wait ends as soon as the label shows.
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 15), .completed, "Expected “\(label)”, found “\(element.label)”.")
    }

    private func waitFor(_ element: XCUIElement, enabled: Bool) -> Bool {
        if element.exists && element.isEnabled == enabled {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitFor(_ element: XCUIElement, selected: Bool) -> Bool {
        if element.exists && element.isSelected == selected {
            return true
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitForFocus(_ field: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter.wait(for: [focused], timeout: 10) == .completed
    }

    private func waitForAbsence(_ element: XCUIElement) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        _ = XCTWaiter.wait(for: [gone], timeout: 10)
    }

    private func tapKeyboardDone(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "guestList.keyboardDone", "Done")).firstMatch
        if done.waitForExistence(timeout: 10) {
            done.tap()
            waitForAbsence(app.keyboards.firstMatch)
        } else {
            XCTFail("Done is offered above the keyboard.")
        }
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

    /// With `PROXIMEET_SHORT_HOLDS=1` (unrecorded runs), a hold is at most 0.6 s: longer than any
    /// 500 ms movement it waits for.
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

    // MARK: - What is drawn on screen
    //
    // In points at 440 × 956, from the approved frames: the headline's white glyphs from y 159 to 261
    // and x 36 to 314 ("Find your / kind of place.") or y 159 to 250 and x 33 to 344 ("Arrive. / Then
    // connect."), as the approved board draws them (docs/design/places-approved/reference/
    // places-review.png, frames at x 40 and 1000, y 172);
    // the ivory ticket (#F6F7F2) from y 466 to 812
    // on browsing and from 238 to 776 on a detail, read at x 60–88, left of every venue's scene and
    // right of the ticket's corner; 26 perforation dashes (6 × 1, every 13 pt from x 50 to 381) at
    // y 739 (browsing) or 480 (a detail), with a ground-coloured notch at each edge; the chips'
    // #050606 capsules; the selected tab's ivory and the others' #111415; the primary action's
    // ivory, or #1F2424 with #737D7A words when disabled; the explanation's ivory card (330–418) and
    // #111415 steps (445–557, 573–685), and its cyan demo line.

    private static let white: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) > 200 }
    private static let ivory: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in min(r, g, b) >= 232 && max(r, g, b) - min(r, g, b) <= 14 }
    private static let ink: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) < 60 }
    private static let ground: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) <= 16 }
    private static let notGround: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in max(r, g, b) > 45 }
    private static let cyan: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r < 120 && g > 150 && b > 160 }
    private static let tileFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 12 && r <= 24 && g >= 15 && g <= 28 && b >= 16 && b <= 30 }
    private static let disabledFill: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r >= 25 && r <= 40 && g >= 30 && g <= 45 && b >= 30 && b <= 45 }
    private static let disabledText: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 95 && r < 135 && g > 105 && g < 145 && b > 100 && b < 140 }

    /// The rows between y 250 and 455 (at x 60–88) where the ivory ticket's top edge is drawn: a
    /// row mostly ivory directly below one mostly not. The tabs' rows (316–364, where the selected
    /// Now tab is ivory while browsing) are skipped. Empty once settled on either layout (the
    /// browse ticket starts at 466, a detail's at 238); a row here is a frame part-way through the
    /// expansion.
    private static func ticketEdges(_ shot: RenderedScreen) -> [Int] {
        var edges: [Int] = []
        var previous = shot.fraction(in: CGRect(x: 60, y: 249, width: 28, height: 1), where: ivory)
        for y in 250...455 {
            if (316...364).contains(y) {
                previous = shot.fraction(in: CGRect(x: 60, y: CGFloat(y), width: 28, height: 1), where: ivory)
                continue
            }
            let row = shot.fraction(in: CGRect(x: 60, y: CGFloat(y), width: 28, height: 1), where: ivory)
            if row > 0.8 && previous < 0.2 {
                edges.append(y)
            }
            previous = row
        }
        return edges
    }

    private func softlyDrawn(_ app: XCUIApplication, _ state: String, stage: PlacesStage, category: String, intent: String) {
        guard app.frame.size == CGSize(width: 440, height: 956) else { return }
        softly {
            guard let shot = RenderedScreen(app) else { return }
            var lines: [String] = []
            @MainActor func edge(_ name: String, _ rect: CGRect, _ test: @escaping (UInt8, UInt8, UInt8) -> Bool,
                      top: CGFloat? = nil, bottom: CGFloat? = nil) {
                guard let rows = shot.inkRows(in: rect, where: test) else {
                    XCTFail("\(state): \(name) is not drawn in \(rect).")
                    return
                }
                lines.append(String(format: "%@ %.2f-%.2f", name, rows.top, rows.bottom))
                if let top {
                    XCTAssertEqual(rows.top, top, accuracy: 1.5, "\(state): \(name) top drawn at \(rows.top), approved \(top).")
                }
                if let bottom {
                    XCTAssertEqual(rows.bottom, bottom, accuracy: 1.5, "\(state): \(name) bottom drawn at \(rows.bottom), approved \(bottom).")
                }
            }
            /// The leftmost and rightmost drawn columns in `rect`, against the board's.
            @MainActor func columns(_ name: String, _ rect: CGRect, _ test: @escaping (UInt8, UInt8, UInt8) -> Bool,
                                    left: CGFloat, right: CGFloat) {
                let ink = shot.inkColumns(in: rect, where: test)
                lines.append(String(format: "%@ columns %.2f-%.2f", name, ink.first?.minX ?? -1, ink.last?.maxX ?? -1))
                XCTAssertEqual(ink.first?.minX ?? -1, left, accuracy: 1.5, "\(state): \(name) left edge drawn at \(ink.first?.minX ?? -1), approved \(left).")
                XCTAssertEqual(ink.last?.maxX ?? -1, right, accuracy: 1.5, "\(state): \(name) right edge drawn at \(ink.last?.maxX ?? -1), approved \(right).")
            }
            @MainActor func filled(_ name: String, _ rect: CGRect, _ test: @escaping (UInt8, UInt8, UInt8) -> Bool, atLeast: Double) {
                let fraction = shot.fraction(in: rect, where: test)
                lines.append(String(format: "%@ %.2f", name, fraction))
                XCTAssertGreaterThanOrEqual(fraction, atLeast, "\(state): \(name) covers \(fraction) of \(rect).")
            }
            @MainActor func perforation(_ y: CGFloat) {
                let dashes = shot.inkColumns(in: CGRect(x: 44, y: y - 2, width: 352, height: 5), where: Self.ink)
                lines.append(String(format: "perforation %d dashes, %.2f-%.2f", dashes.count, dashes.first?.minX ?? -1,
                                    dashes.last?.maxX ?? -1))
                XCTAssertEqual(dashes.count, 26, "\(state): 26 perforation dashes at y \(y).")
                XCTAssertEqual(dashes.first?.minX ?? -1, 50, accuracy: 1, "\(state): the first dash starts at x 50.")
                XCTAssertEqual(dashes.last?.maxX ?? -1, 381, accuracy: 1, "\(state): the last dash ends at x 381.")
                edge("dash row", CGRect(x: 60, y: y - 3, width: 4, height: 7), Self.ink, top: y, bottom: y + 1)
                filled("left notch", CGRect(x: 33, y: y - 3, width: 5, height: 6), Self.ground, atLeast: 0.9)
                filled("right notch", CGRect(x: 402, y: y - 3, width: 5, height: 6), Self.ground, atLeast: 0.9)
            }
            switch stage {
            case .browse:
                edge("headline", CGRect(x: 32, y: 140, width: 376, height: 130), Self.white, top: 159, bottom: 261)
                columns("headline", CGRect(x: 32, y: 140, width: 376, height: 130), Self.white, left: 36, right: 314)
                edge("ticket top", CGRect(x: 60, y: 440, width: 28, height: 60), Self.ivory, top: 466)
                edge("ticket bottom", CGRect(x: 60, y: 780, width: 28, height: 50), Self.ivory, bottom: 812)
                for (index, key) in Self.categories.enumerated() {
                    let fill = CGRect(x: 46 + CGFloat(index) * 124, y: 326, width: 10, height: 8)
                    filled("tab \(key) \(key == category ? "ivory" : "tile")", fill, key == category ? Self.ivory : Self.tileFill,
                           atLeast: 0.95)
                }
                filled("scene", CGRect(x: 150, y: 380, width: 140, height: 80), Self.notGround, atLeast: 0.2)
                filled("first chip", CGRect(x: 56, y: 710, width: 8, height: 10), Self.ink, atLeast: 0.9)
                perforation(739)
                filled("View place", CGRect(x: 256, y: 762, width: 10, height: 28), Self.ink, atLeast: 0.9)
                edge("browse line", CGRect(x: 32, y: 830, width: 376, height: 36), { r, g, b in min(r, g, b) > 120 })
            case .detail:
                let enabled = Self.expected(category, intent).enabled
                edge("ticket top", CGRect(x: 60, y: 212, width: 28, height: 60), Self.ivory, top: 238)
                edge("ticket bottom", CGRect(x: 60, y: 745, width: 28, height: 50), Self.ivory, bottom: 776)
                filled("scene", CGRect(x: 150, y: 152, width: 140, height: 80), Self.notGround, atLeast: 0.2)
                perforation(480)
                filled("first chip", CGRect(x: 56, y: 544, width: 8, height: 10), Self.ink, atLeast: 0.9)
                filled("primary fill", CGRect(x: 46, y: 822, width: 20, height: 10), enabled ? Self.ivory : Self.disabledFill,
                       atLeast: 0.95)
                edge("primary label", CGRect(x: 90, y: 822, width: 260, height: 40), enabled ? Self.ink : Self.disabledText)
            case .explanation:
                edge("headline", CGRect(x: 32, y: 140, width: 376, height: 130), Self.white, top: 159, bottom: 250)
                columns("headline", CGRect(x: 32, y: 140, width: 376, height: 130), Self.white, left: 33, right: 344)
                edge("venue card", CGRect(x: 380, y: 320, width: 7, height: 110), Self.ivory, top: 330, bottom: 418)
                edge("step 1", CGRect(x: 360, y: 440, width: 6, height: 124), Self.tileFill, top: 445, bottom: 557)
                edge("step 2", CGRect(x: 360, y: 568, width: 6, height: 124), Self.tileFill, top: 573, bottom: 685)
                edge("demo line", CGRect(x: 32, y: 745, width: 376, height: 36), Self.cyan)
                filled("primary fill", CGRect(x: 46, y: 822, width: 20, height: 10), Self.ivory, atLeast: 0.95)
            }
            attachNote("\(state): drawn (points): " + lines.joined(separator: "; ") + ".")
        }
    }
}

private enum PlacesStage {
    case browse
    case detail
    case explanation
}

/// Places' elements, by identifier: browsing (`places.*`), a detail (`place.*`) and the
/// explanation (`explanation.*`).
@MainActor
private struct PlacesScreen {
    let app: XCUIApplication

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    var back: XCUIElement { app.buttons["places.back"] }
    var demoBadge: XCUIElement { element("places.demoBadge") }

    var headline: XCUIElement { element("places.headline") }
    var context: XCUIElement { element("places.context") }
    var tabs: XCUIElement { element("places.tabs") }
    var ticket: XCUIElement { element("places.ticket") }
    var ticketName: XCUIElement { element("places.ticket.name") }
    var ticketKind: XCUIElement { element("places.ticket.kind") }
    var ticketIntents: XCUIElement { element("places.ticket.intents") }
    var ticketSchedule: XCUIElement { element("places.ticket.schedule") }
    var viewPlace: XCUIElement { app.buttons["places.viewPlace"] }
    var browseLine: XCUIElement { element("places.boundary") }
    var secondary: XCUIElement { app.buttons["places.secondary"] }

    func tab(_ category: String) -> XCUIElement { app.buttons["places.tab.\(category)"] }

    var detailTicket: XCUIElement { element("place.ticket") }
    var name: XCUIElement { element("place.name") }
    var kind: XCUIElement { element("place.kind") }
    var schedule: XCUIElement { element("place.schedule") }
    var intents: XCUIElement { element("place.intents") }
    var host: XCUIElement { element("place.host") }
    var brief: XCUIElement { element("place.brief") }
    var rules: XCUIElement { element("place.rules") }
    var lastLine: XCUIElement { element("place.boundary") }
    var primary: XCUIElement { app.buttons["place.primary"] }
    var detailSecondary: XCUIElement { app.buttons["place.secondary"] }

    var explanationHeadline: XCUIElement { element("explanation.headline") }
    var explanationSupport: XCUIElement { element("explanation.support") }
    var explanationVenue: XCUIElement { element("explanation.venue") }
    var presence: XCUIElement { element("explanation.presence") }
    var demoLine: XCUIElement { element("explanation.demo") }
    /// The explanation's primary. Since chapter 08 it is "Preview room demo" (Figma 67:286, the same
    /// 376 × 60 frame), opening the Room entry above the explanation; the name is kept from when it
    /// was Explore other places.
    var explore: XCUIElement { app.buttons["explanation.primary"] }
    var backToPlace: XCUIElement { app.buttons["explanation.secondary"] }

    func step(_ number: Int) -> XCUIElement { element("explanation.step.\(number)") }

    // Chapter 08: the Room drawn above the explanation, only as far as these checks go through it
    // (the Room contract's identifiers; the Room itself is RoomReviewTests').
    var roomEnter: XCUIElement { app.buttons["roomEntry.enter"] }
    var roomEntryBack: XCUIElement { app.buttons["roomEntry.back"] }
    var roomLeave: XCUIElement { app.buttons["room.leave"] }
    var roomReturnToPlaces: XCUIElement { app.buttons["roomEnded.returnToPlaces"] }
}

@MainActor
private struct SignalScreen {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.headline").firstMatch }
    var summary: XCUIElement { app.descendants(matching: .any).matching(identifier: "signal.summary").firstMatch }
    var primary: XCUIElement { app.buttons["signal.primary"] }
    var back: XCUIElement { app.buttons["signal.back"] }

    func row(_ approach: String) -> XCUIElement { app.buttons["signal.approach.\(approach)"] }
}

@MainActor
private struct Wristband {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "wristband.headline").firstMatch }
    var primary: XCUIElement { app.buttons["wristband.primary"] }
    var back: XCUIElement { app.buttons["wristband.back"] }

    func tile(_ intent: String) -> XCUIElement { app.buttons["wristband.intent.\(intent)"] }
}

@MainActor
private struct GuestList {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.headline").firstMatch }
    var name: XCUIElement { app.textFields["guestList.name"] }
    var opener: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.opener").firstMatch }
    var coffee: XCUIElement { app.buttons["guestList.interest.coffee"] }
    var card: XCUIElement { app.descendants(matching: .any).matching(identifier: "guestList.card").firstMatch }
    var primary: XCUIElement { app.buttons["guestList.primary"] }
    var secondary: XCUIElement { app.buttons["guestList.secondary"] }
    var back: XCUIElement { app.buttons["guestList.back"] }
}

@MainActor
private struct PassScreen {
    let app: XCUIApplication

    var headline: XCUIElement { app.descendants(matching: .any)["pass.headline"] }
    var primary: XCUIElement { app.buttons["pass.primary"] }
    var back: XCUIElement { app.buttons["pass.back"] }
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
}
