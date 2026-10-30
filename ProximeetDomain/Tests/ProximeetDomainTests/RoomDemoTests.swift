import XCTest
@testable import ProximeetDomain

/// Chapter 08, the approved Room: entry gates, privacy waiting, the fictional sample, one blocked set,
/// unsent report previews and the terminal Leave. Everything is a synchronous value change; nothing here
/// reads a clock, stores, sends or grants anything.
final class RoomDemoTests: XCTestCase {

    // MARK: - Eligibility and the two deliberate gates

    func testOnlyAnEligibleExplanationOpensTheEntry() {
        for intent in BandIntent.allCases {
            for approach in ApproachSignal.allCases {
                let flow = RoomFixture.onExplanation(intent, approach: approach)
                let preview = RoomPreview.open(after: flow)
                XCTAssertNotNil(preview, "\(intent) · \(approach)")
                XCTAssertEqual(preview?.intent, intent, "the actual intent, never a default")
                XCTAssertEqual(preview?.approach, approach, "the actual approach, never inferred")
                XCTAssertEqual(preview?.preference, "\(intent.title) · \(approach.title)")
            }
        }
        // Matching a future session still does not open a Room: eligibility is not consent
        // and the four-intent extension does not make unopened sessions available.
        for (intent, category) in [(BandIntent.dating, PlaceCategory.later), (.activity, .upcoming)] {
            var flow = PlacesRoute.onPlaces(intent, approach: .chatFirst)
            flow.choosePlaceCategory(category)
            flow.openPlaceDetail()
            flow.previewCheckIn()
            XCTAssertEqual(flow.currentScene, .placeDetail)
            XCTAssertNil(RoomPreview.open(after: flow), "\(intent)")
        }
    }

    func testNoEntryAwayFromTheExplanation() {
        var flow = PlacesRoute.onSignal(.social, approach: .chatFirst)
        XCTAssertNil(RoomPreview.open(after: flow), "Signal")
        flow.openPlaces()
        XCTAssertNil(RoomPreview.open(after: flow), "browsing")
        flow.openPlaceDetail()
        XCTAssertNil(RoomPreview.open(after: flow), "Common Ground's detail")
        for category in [PlaceCategory.later, .upcoming] {
            var other = PlacesRoute.onPlaces(.social, approach: .chatFirst)
            other.choosePlaceCategory(category)
            other.openPlaceDetail()
            other.previewCheckIn()
            XCTAssertNil(RoomPreview.open(after: other), "\(category): a future venue never unlocks")
        }
        XCTAssertNil(RoomPreview.open(after: DemoFlow()), "a fresh demo")
    }

    func testOpeningTheEntryStartsNoRun() {
        let preview = RoomFixture.entry(.social)
        XCTAssertEqual(preview.stage, .entry)
        XCTAssertNil(preview.run, "the entry screen alone starts nothing")
    }

    func testOnlyEnterStartsARunInWaiting() {
        var preview = RoomFixture.entry(.business, approach: .okayToSayHello)
        XCTAssertTrue(preview.enter(as: RoomRunID(7)))
        guard let run = preview.run else { return XCTFail("no run") }
        XCTAssertEqual(run.id, RoomRunID(7))
        XCTAssertEqual(run.phase, .waiting)
        XCTAssertEqual(run.intent, .business)
        XCTAssertEqual(run.approach, .okayToSayHello)
        XCTAssertEqual(run.blocked, [])
        XCTAssertEqual(run.tab, .people)
        XCTAssertEqual(run.route, [])
        XCTAssertFalse(preview.enter(as: RoomRunID(8)), "a repeated Enter starts nothing")
        XCTAssertEqual(preview.run?.id, RoomRunID(7))
    }

    func testWaitingExposesNoSample() {
        var run = RoomFixture.waiting(.social)
        XCTAssertEqual(run.visiblePeople, [])
        XCTAssertEqual(run.visibleNoteAuthors, [])
        XCTAssertFalse(run.showsHostNotes)
        XCTAssertFalse(run.showsNoSampleIntroductions, "waiting is not an empty room")
        XCTAssertFalse(run.showsHiddenNotesBoundary)
        for actor in RoomActor.allCases {
            XCTAssertFalse(run.showsSample(actor))
            XCTAssertFalse(run.openProfile(actor))
            XCTAssertFalse(run.openActorSafety(actor))
            XCTAssertFalse(run.block(actor))
        }
        XCTAssertFalse(run.selectTab(.notes))
        XCTAssertFalse(run.previewReport())
        XCTAssertFalse(run.openWaveDemo(viewerName: "Alex"))
        XCTAssertEqual(run.phase, .waiting, "nothing but the labelled control reveals the sample")
        XCTAssertTrue(run.isConsistent)
    }

    func testOnlyTheLabelledControlRevealsTheSample() {
        var run = RoomFixture.waiting(.social)
        XCTAssertTrue(run.openGlobalSafety())
        XCTAssertFalse(run.showPopulatedExample(), "not while safety covers the control")
        XCTAssertTrue(run.closeLevel())
        XCTAssertTrue(run.showPopulatedExample())
        XCTAssertEqual(run.phase, .populated)
        XCTAssertEqual(run.visiblePeople, [.maya, .jules])
        XCTAssertEqual(run.visibleNoteAuthors, [.jules])
        XCTAssertTrue(run.showsHostNotes)
        XCTAssertFalse(run.showPopulatedExample(), "once only")
    }

    // MARK: - People, notes and profiles

    func testTabsShareOneState() {
        var run = RoomFixture.populated(.social)
        XCTAssertFalse(run.selectTab(.people), "the selected tab does nothing")
        XCTAssertTrue(run.selectTab(.notes))
        XCTAssertEqual(run.tab, .notes)
        XCTAssertFalse(run.openProfile(.maya), "cards are on People")
        XCTAssertTrue(run.selectTab(.people))
        XCTAssertTrue(run.openProfile(.maya))
        XCTAssertFalse(run.selectTab(.notes), "not while a profile is open")
    }

    func testCompatibilityFollowsTheActualIntent() {
        let expectations: [(BandIntent, RoomActor, RoomProfileAction, String)] = [
            (.social, .maya, .previewWaveDemo, "Prefers a Wave and a chat before meeting."),
            (.social, .jules, .backToPeople, "Waves stay within your selected intent."),
            (.business, .maya, .backToPeople, "Waves stay within your selected intent."),
            (.business, .jules, .previewWaveDemo, "Open to a brief hello. No pressure to continue."),
        ]
        for (intent, actor, action, boundary) in expectations {
            for approach in ApproachSignal.allCases {
                let run = RoomFixture.populated(intent, approach: approach)
                XCTAssertEqual(run.profileAction(for: actor), action, "\(intent) → \(actor)")
                XCTAssertEqual(run.profileBoundary(for: actor), boundary, "\(intent) → \(actor)")
            }
        }
    }

    func testPreviewWaveDemoOnlyForTheSameIntent() {
        for (intent, same, other) in [(BandIntent.social, RoomActor.maya, RoomActor.jules),
                                      (.business, .jules, .maya)] {
            var run = RoomFixture.populated(intent)
            XCTAssertTrue(run.openProfile(other))
            XCTAssertFalse(run.openWaveDemo(viewerName: "Alex"), "\(intent): no Wave action for another intent")
            XCTAssertTrue(run.backToPeople())
            XCTAssertEqual(run.route, [])
            XCTAssertEqual(run.tab, .people)

            XCTAssertTrue(run.openProfile(same))
            XCTAssertFalse(run.backToPeople(), "\(intent): the same intent has no Back to people action")
            let before = run
            XCTAssertEqual(run.profileAction(for: same).title, "Preview Wave demo")
            XCTAssertTrue(run.openWaveDemo(viewerName: "Alex"))
            XCTAssertEqual(run.route, [.profile(same), .waveDemo])
            XCTAssertFalse(run.closeLevel(), "the Wave closes through its own route, not a Room panel's Close")
            XCTAssertNil(run.panel, "the Wave is not one of the Room's panels")
            XCTAssertEqual(run.profile, same, "it sits above the profile that opened it")
            XCTAssertEqual(run.outerBack(), .closedLevel, "the menu's outer Back returns to its caller")
            XCTAssertEqual(run, before, "closing returns to the same profile and blocks")
        }
    }

    /// Chapter 09 retired the Room's Wave-information panel (66:134): "Preview Wave demo" opens the Wave
    /// itself (lead decision 1), so the Room reaches seven panels, not eight. Its copy and its route are
    /// gone from the domain, read as source (comments ignored).
    ///
    /// A native test runner carries the built tests, not the repository (the native plans skip every
    /// source-reading test for that reason), so this skips itself there, and only there.
    func testTheRetiredWaveInformationPanelIsGone() throws {
        let package = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ProximeetDomainTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
        guard FileManager.default.fileExists(atPath: package.appendingPathComponent("Package.swift").path)
        else { throw XCTSkip("No source tree on this runner; the host `swift test` reads the domain sources.") }
        let sources = package.appendingPathComponent("Sources/ProximeetDomain")
        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path).filter { $0.hasSuffix(".swift") }
        XCTAssertTrue(names.contains("RoomDemo.swift"))
        let retired = ["How Waves work", "A Wave is", "Chat opens only after the other person accepts.",
                       "Sending Waves comes in the next preview.", "Back to profile", "waveInfo", "howWavesWork",
                       "openWaveInfo", "backToProfile"]
        for name in names {
            let code = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> Substring in
                    guard let comment = line.range(of: "//") else { return line }
                    return line[..<comment.lowerBound]
                }
                .joined(separator: "\n")
            for text in retired {
                XCTAssertFalse(code.contains(text), "\(name) still carries \(text)")
            }
        }
    }

    // MARK: - Blocks

    func testTheFourBlockSets() {
        for intent in [BandIntent.social, .business] {
            let neither = RoomFixture.populated(intent)
            XCTAssertEqual(neither.visiblePeople, [.maya, .jules])
            XCTAssertEqual(neither.visibleNoteAuthors, [.jules])
            XCTAssertEqual(neither.peopleBoundary, "Fictional cards. Nothing is sent.")
            XCTAssertFalse(neither.showsHiddenNotesBoundary)

            let maya = RoomFixture.blocking([.maya], intent)
            XCTAssertEqual(maya.visiblePeople, [.jules])
            XCTAssertEqual(maya.visibleNoteAuthors, [.jules], "Maya's block leaves Jules's note")
            XCTAssertEqual(maya.peopleBoundary, "Your demo blocks remain applied.")
            XCTAssertFalse(maya.showsHiddenNotesBoundary, "Maya wrote no public note")
            XCTAssertTrue(maya.showsHostNotes)

            let jules = RoomFixture.blocking([.jules], intent)
            XCTAssertEqual(jules.visiblePeople, [.maya])
            XCTAssertEqual(jules.visibleNoteAuthors, [], "Jules's block removes his card, profile and note")
            XCTAssertTrue(jules.showsHiddenNotesBoundary)
            XCTAssertTrue(jules.showsHostNotes, "host content remains")

            let both = RoomFixture.blocking([.maya, .jules], intent)
            XCTAssertEqual(both.visiblePeople, [])
            XCTAssertEqual(both.visibleNoteAuthors, [])
            XCTAssertTrue(both.showsNoSampleIntroductions)
            XCTAssertTrue(both.showsHostNotes)
            XCTAssertTrue(both.showsHiddenNotesBoundary)
            XCTAssertEqual(RoomCopy.emptyTitle.joined(separator: " "), "No sample introductions to show.")
            XCTAssertFalse(RoomCopy.emptyTitle.joined().lowercased().contains("empty"))
        }
    }

    func testBothBlockOrdersEndTheSame() {
        let forward = RoomFixture.blocking([.maya, .jules], .social)
        var backward = RoomFixture.populated(.social)
        XCTAssertTrue(RoomFixture.block(.jules, in: &backward))
        XCTAssertTrue(RoomFixture.block(.maya, in: &backward))
        XCTAssertEqual(forward.blocked, backward.blocked)
        XCTAssertEqual(forward.visiblePeople, backward.visiblePeople)
        XCTAssertEqual(forward.visibleNoteAuthors, backward.visibleNoteAuthors)
        XCTAssertEqual(forward.route, [])
        XCTAssertEqual(backward.route, [])
    }

    func testBlockingClosesEveryLevelAndReturnsToFilteredPeople() {
        // From the profile's safety.
        var run = RoomFixture.populated(.social)
        run.openProfile(.maya)
        run.openActorSafety(.maya)
        XCTAssertTrue(run.block(.maya))
        XCTAssertEqual(run.route, [])
        XCTAssertEqual(run.tab, .people)
        // From the report preview, above that safety.
        run.openProfile(.jules)
        run.openActorSafety(.jules)
        run.previewReport()
        run.selectReportReason(.harassment)
        XCTAssertTrue(run.block(.jules))
        XCTAssertEqual(run.route, [])
        XCTAssertEqual(run.blocked, [.maya, .jules])
        // From Jules's public note on Room notes: People, not notes.
        var notes = RoomFixture.populated(.business)
        notes.selectTab(.notes)
        XCTAssertTrue(notes.openActorSafety(.jules))
        XCTAssertTrue(notes.block(.jules))
        XCTAssertEqual(notes.tab, .people)
        XCTAssertEqual(notes.route, [])
    }

    func testBlocksNeverRegressAndHaveNoUndo() {
        var run = RoomFixture.blocking([.maya], .social)
        let blocked = run.blocked
        // Tabs, Back, closes, report selections and the other actor's block keep Maya blocked.
        run.selectTab(.notes)
        run.openActorSafety(.jules)
        run.previewReport()
        run.selectReportReason(.unwantedAttention)
        run.closeLevel()
        run.closeLevel()
        run.selectTab(.people)
        run.openProfile(.jules)
        run.openActorSafety(.jules)
        run.closeLevel()
        run.closeLevel()
        run.openGlobalSafety()
        run.closeLevel()
        XCTAssertEqual(run.blocked, blocked)
        XCTAssertFalse(run.block(.maya), "blocking twice does nothing")
        XCTAssertFalse(run.openProfile(.maya), "a blocked actor's profile never reopens")
        XCTAssertFalse(run.openActorSafety(.maya))
        XCTAssertEqual(run.blocked, blocked)
    }

    func testBlockNeedsThatActorsSafety() {
        var run = RoomFixture.populated(.social)
        XCTAssertFalse(run.block(.maya), "not from the root")
        run.openProfile(.maya)
        XCTAssertFalse(run.block(.maya), "not from the profile itself")
        run.openActorSafety(.maya)
        XCTAssertFalse(run.block(.jules), "never another actor from Maya's safety")
        XCTAssertTrue(run.block(.maya))
    }

    // MARK: - Unsent report previews

    func testReportSelectionIsLocalOptionalAndUnsent() {
        var run = RoomFixture.populated(.social)
        run.openProfile(.maya)
        run.openActorSafety(.maya)
        XCTAssertTrue(run.previewReport())
        XCTAssertEqual(run.panel, .report(.maya, nil), "nothing selected at first")
        XCTAssertTrue(run.selectReportReason(.unwantedAttention))
        XCTAssertFalse(run.selectReportReason(.unwantedAttention), "the selected reason again is a no-op")
        XCTAssertEqual(run.panel, .report(.maya, .unwantedAttention))
        XCTAssertTrue(run.selectReportReason(.somethingElse), "another reason replaces it")
        XCTAssertEqual(run.panel, .report(.maya, .somethingElse))
        XCTAssertEqual(run.blocked, [], "a report changes no block")
        // Close returns to the actor's safety, then its Back to the calling profile.
        XCTAssertTrue(run.closeLevel())
        XCTAssertEqual(run.route, [.profile(.maya), .actorSafety(.maya)])
        XCTAssertTrue(run.closeLevel())
        XCTAssertEqual(run.route, [.profile(.maya)])
        // A new preview starts with nothing selected: closing discarded the selection.
        run.openActorSafety(.maya)
        run.previewReport()
        XCTAssertEqual(run.panel, .report(.maya, nil))
        // Never carried to another actor.
        run.closeLevel(); run.closeLevel(); run.closeLevel()
        run.openProfile(.jules)
        run.openActorSafety(.jules)
        run.previewReport()
        XCTAssertEqual(run.panel, .report(.jules, nil))
        XCTAssertEqual(RoomReportReason.allCases.map(\.title),
                       ["Unwanted attention", "Harassment or harmful content", "Something else"])
    }

    func testCallersAreRestoredFromNotesToo() {
        var run = RoomFixture.populated(.business)
        run.selectTab(.notes)
        XCTAssertTrue(run.openActorSafety(.jules))
        XCTAssertFalse(run.openActorSafety(.maya), "Maya wrote no public note")
        run.previewReport()
        run.selectReportReason(.harassment)
        run.closeLevel()
        XCTAssertEqual(run.route, [.actorSafety(.jules)])
        run.closeLevel()
        XCTAssertEqual(run.route, [])
        XCTAssertEqual(run.tab, .notes, "back on the notes tab it came from")
        // Global safety returns to its caller's tab too.
        run.openGlobalSafety()
        run.closeLevel()
        XCTAssertEqual(run.tab, .notes)
    }

    // MARK: - Leaving

    func testLeaveEndsTheRunFromEveryContext() {
        let contexts: [(String, (inout RoomRun) -> Void)] = [
            ("waiting", { _ in }),
            ("waiting safety", { $0.openGlobalSafety() }),
            ("people", { $0.showPopulatedExample() }),
            ("notes", { $0.showPopulatedExample(); $0.selectTab(.notes) }),
            ("global safety", { $0.showPopulatedExample(); $0.openGlobalSafety() }),
            ("profile", { $0.showPopulatedExample(); $0.openProfile(.maya) }),
            ("wave menu", { $0.showPopulatedExample(); $0.openProfile(.maya); $0.openWaveDemo(viewerName: "Alex") }),
            ("actor safety", { $0.showPopulatedExample(); $0.openProfile(.jules); $0.openActorSafety(.jules) }),
            ("report", { $0.showPopulatedExample(); $0.openProfile(.jules); $0.openActorSafety(.jules)
                $0.previewReport(); $0.selectReportReason(.somethingElse) }),
            ("note safety", { $0.showPopulatedExample(); $0.selectTab(.notes); $0.openActorSafety(.jules) }),
            ("blocked both", { $0.showPopulatedExample()
                for actor in RoomActor.allCases { $0.openProfile(actor); $0.openActorSafety(actor); $0.block(actor) } }),
        ]
        for (name, reach) in contexts {
            var run = RoomFixture.waiting(.social)
            reach(&run)
            XCTAssertTrue(run.isConsistent, name)
            XCTAssertTrue(run.leave(), name)
            XCTAssertEqual(run.phase, .ended, name)
            XCTAssertEqual(run.route, [], name)
            XCTAssertEqual(run.visiblePeople, [], name)
            XCTAssertEqual(run.visibleNoteAuthors, [], name)
            XCTAssertFalse(run.showsHostNotes, name)
            XCTAssertNil(run.profile, name)
            XCTAssertNil(run.panel, name)
            // Nothing revives an ended run.
            XCTAssertFalse(run.leave(), name)
            XCTAssertFalse(run.showPopulatedExample(), name)
            XCTAssertFalse(run.openGlobalSafety(), name)
            XCTAssertFalse(run.selectTab(.notes), name)
            XCTAssertFalse(run.closeLevel(), name)
            for actor in RoomActor.allCases {
                XCTAssertFalse(run.openProfile(actor), name)
                XCTAssertFalse(run.openActorSafety(actor), name)
                XCTAssertFalse(run.block(actor), name)
            }
            XCTAssertEqual(run.outerBack(), .alreadyEnded, name)
            XCTAssertEqual(run.phase, .ended, name)
        }
    }

    func testOuterBackFollowsTheCallersThenLeavesAtTheRoot() {
        var run = RoomFixture.populated(.social)
        run.openProfile(.maya)
        run.openActorSafety(.maya)
        run.previewReport()
        XCTAssertEqual(run.outerBack(), .closedLevel)
        XCTAssertEqual(run.route, [.profile(.maya), .actorSafety(.maya)])
        XCTAssertEqual(run.outerBack(), .closedLevel)
        XCTAssertEqual(run.outerBack(), .closedLevel)
        XCTAssertEqual(run.route, [])
        XCTAssertEqual(run.phase, .populated)
        XCTAssertEqual(run.outerBack(), .left, "a completed outer Back at the active root leaves")
        XCTAssertEqual(run.phase, .ended)
        var waiting = RoomFixture.waiting(.business)
        XCTAssertEqual(waiting.outerBack(), .left)
        var entry = RoomFixture.entry(.social)
        XCTAssertEqual(entry.outerBack(), .none, "the entry's Back belongs to the explanation")
        XCTAssertNil(entry.run)
    }

    // MARK: - Stale callbacks and invalidation

    func testCallbacksForAnotherRunChangeNothing() {
        var preview = RoomFixture.entry(.social)
        preview.enter(as: RoomRunID(1))
        XCTAssertFalse(preview.updateRun(RoomRunID(0)) { $0.showPopulatedExample() })
        XCTAssertEqual(preview.run?.phase, .waiting)
        XCTAssertTrue(preview.updateRun(RoomRunID(1)) { $0.showPopulatedExample() })
        XCTAssertTrue(preview.updateRun(RoomRunID(1)) { $0.leave() })
        // A late tap captured before Leave, for the same run, is refused by the ended run itself.
        XCTAssertFalse(preview.updateRun(RoomRunID(1)) { $0.openProfile(.maya) })
        XCTAssertEqual(preview.run?.phase, .ended)
        // A fresh sequence is a new preview with a new identity; the old one's callbacks do nothing there.
        var fresh = RoomFixture.entry(.social)
        fresh.enter(as: RoomRunID(2))
        XCTAssertFalse(fresh.updateRun(RoomRunID(1)) { $0.showPopulatedExample() })
        XCTAssertEqual(fresh.run?.phase, .waiting)
        XCTAssertEqual(fresh.run?.blocked, [], "a new Enter resets the fictional blocks")
        var entry = RoomFixture.entry(.social)
        XCTAssertFalse(entry.updateRun(RoomRunID(2)) { $0.leave() }, "no run on the entry screen")
    }

    func testThePreviewIsInvalidOnceTheExplanationIsGone() {
        var flow = RoomFixture.onExplanation(.social, approach: .chatFirst)
        guard let preview = RoomPreview.open(after: flow) else { return XCTFail("no preview") }
        XCTAssertTrue(preview.isStillValid(for: flow))
        var back = flow
        back.backToPlace()
        XCTAssertFalse(preview.isStillValid(for: back))
        flow.exploreOtherPlaces()
        XCTAssertFalse(preview.isStillValid(for: flow))
        var other = RoomFixture.onExplanation(.business, approach: .chatFirst)
        XCTAssertFalse(preview.isStillValid(for: other), "another actual intent")
        other.reset()
        XCTAssertFalse(preview.isStillValid(for: other))
    }

    func testTheFlowAndItsDraftAreNeverTouched() {
        let flow = RoomFixture.onExplanation(.business, approach: .okayToSayHello)
        let before = flow
        var preview = RoomPreview.open(after: flow)
        preview?.enter(as: RoomRunID(1))
        preview?.updateRun(RoomRunID(1)) { $0.showPopulatedExample() }
        preview?.updateRun(RoomRunID(1)) { $0.leave() }
        XCTAssertEqual(flow, before, "the Room writes nothing to the demo flow or its draft")
    }

    // MARK: - Invariants under any sequence

    func testEverySequenceStaysConsistent() {
        var generator = SplitMix(seed: 0x524F4F4D)
        for intent in [BandIntent.social, .business] {
            for _ in 0..<400 {
                var run = RoomFixture.waiting(intent)
                var previousBlocks: Set<RoomActor> = []
                for _ in 0..<40 {
                    let actor = RoomActor.allCases[Int(generator.next() % 2)]
                    switch generator.next() % 13 {
                    case 0: run.showPopulatedExample()
                    case 1: run.selectTab(generator.next() % 2 == 0 ? .people : .notes)
                    case 2: run.openProfile(actor)
                    case 3: run.openGlobalSafety()
                    case 4: run.openActorSafety(actor)
                    case 5: run.previewReport()
                    case 6: run.selectReportReason(RoomReportReason.allCases[Int(generator.next() % 3)])
                    case 7: run.closeLevel()
                    case 8: run.openWaveDemo(viewerName: "Alex")
                    case 9: run.backToPeople()
                    case 10: run.block(actor)
                    case 11: _ = run.outerBack()
                    default: if generator.next() % 5 == 0 { run.leave() }
                    }
                    XCTAssertTrue(run.isConsistent, "\(run)")
                    XCTAssertTrue(previousBlocks.isSubset(of: run.blocked), "blocks only grow")
                    previousBlocks = run.blocked
                    if run.phase != .populated {
                        XCTAssertEqual(run.visiblePeople, [])
                        XCTAssertEqual(run.visibleNoteAuthors, [])
                    }
                    for level in run.route {
                        if let actor = level.actor { XCTAssertFalse(run.blocked.contains(actor)) }
                    }
                }
            }
        }
    }

    // MARK: - Nothing production-like, nothing persistable

    func testNoProductionLikeStateAndNothingPersistable() {
        let run = RoomFixture.blocking([.maya], .social)
        let preview = RoomFixture.entry(.social)
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "checkedin", "checkin", "attend",
                     "online", "match", "account", "identity", "consent", "permission", "location", "camera",
                     "scan", "credential", "token", "submit", "sent", "pending", "accept", "clock", "date", "time"]
        for label in Self.propertyNames(of: run) + Self.propertyNames(of: preview) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
        for type in [RoomRun.self, RoomPreview.self, RoomActor.self, RoomRoute.self, RoomReportReason.self,
                     RoomTab.self, RoomPhase.self, RoomRunID.self] as [Any.Type] {
            XCTAssertFalse(type is Encodable.Type, "\(type)")
            XCTAssertFalse(type is Decodable.Type, "\(type)")
        }
    }

    func testTheApprovedFictionalCopy() {
        XCTAssertEqual(RoomActor.maya.line, "Social · Chat first")
        XCTAssertEqual(RoomActor.jules.line, "Business · Okay to say hello")
        XCTAssertEqual(RoomActor.maya.initials, "ML")
        XCTAssertEqual(RoomActor.jules.initials, "JR")
        XCTAssertEqual(RoomActor.maya.about, "Coffee, bookshops, and a good detour.\nTell me about a place you’d go back to.")
        XCTAssertEqual(RoomActor.jules.about,
                       "Design, ideas, and small businesses.\nAlways curious about what people are building.")
        XCTAssertEqual(RoomActor.maya.interests, ["Coffee", "Bookshops", "Detours"])
        XCTAssertEqual(RoomActor.jules.interests, ["Design", "Ideas", "Small business"])
        XCTAssertNil(RoomActor.maya.publicNote)
        XCTAssertEqual(RoomActor.jules.publicNote, "One good question can change an evening.")
        XCTAssertEqual(RoomCopy.block(.maya), "Block Maya in demo")
        XCTAssertEqual(RoomCopy.actorSafetyTitle(.jules), "Jules · safety")
        XCTAssertEqual(RoomCopy.reportTitle(.maya), "Report Maya")
        XCTAssertEqual(RoomCopy.viewCard, "View card  →")
        for text in [RoomCopy.previewWaveDemo, RoomCopy.reportExplanation] {
            XCTAssertFalse(text.lowercased().contains("sent to"), text)
        }
    }

    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            guard let label = child.label else { return [] }
            return [label] + propertyNames(of: child.value)
        }
    }
}

/// Deterministic, dependency-free pseudo-random numbers for the sequence test.
private struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Room states reached only through the real transitions.
enum RoomFixture {
    static func onExplanation(_ intent: BandIntent, approach: ApproachSignal) -> DemoFlow {
        var flow = PlacesRoute.onPlaces(intent, approach: approach)
        flow.openPlaceDetail()
        flow.previewCheckIn()
        return flow
    }

    static func entry(_ intent: BandIntent, approach: ApproachSignal = .chatFirst) -> RoomPreview {
        guard let preview = RoomPreview.open(after: onExplanation(intent, approach: approach)) else {
            preconditionFailure("\(intent) cannot open the Room entry")
        }
        return preview
    }

    static func waiting(_ intent: BandIntent, approach: ApproachSignal = .chatFirst) -> RoomRun {
        var preview = entry(intent, approach: approach)
        preview.enter(as: RoomRunID(1))
        guard let run = preview.run else { preconditionFailure("no run") }
        return run
    }

    static func populated(_ intent: BandIntent, approach: ApproachSignal = .chatFirst) -> RoomRun {
        var run = waiting(intent, approach: approach)
        run.showPopulatedExample()
        return run
    }

    /// Blocks each actor in order, through its profile's safety.
    static func blocking(_ actors: [RoomActor], _ intent: BandIntent) -> RoomRun {
        var run = populated(intent)
        for actor in actors { _ = block(actor, in: &run) }
        return run
    }

    @discardableResult
    static func block(_ actor: RoomActor, in run: inout RoomRun) -> Bool {
        run.openProfile(actor) && run.openActorSafety(actor) && run.block(actor)
    }
}
