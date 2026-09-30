import XCTest
@testable import ProximeetDomain

/// Chapter 09, the approved Wave, inside the Room run that opened it: one viewer, two independent
/// invitation identities, recipient-only acceptance, the shared central blocks, the append-only closed
/// record and the terminal Leave. Every state is reached through the real transitions (`WaveFixture`), and
/// the approved screens, routes and strings are pinned to the handoff's own files: `validation/
/// state-ledger.json` and `LAYOUT_SPEC.json` (re-verified by script against the literal tables below).
final class WaveDemoTests: XCTestCase {

    // MARK: - Entry from the Room

    func testCounterpartFollowsTheActualIntentAndApproachesMayDiffer() {
        for (intent, counterpart) in [(BandIntent.social, RoomActor.maya), (.business, .jules)] {
            for approach in ApproachSignal.allCases {
                let run = WaveFixture.menu(intent, approach: approach)
                XCTAssertEqual(run.wave?.counterpart, counterpart, "\(intent) · \(approach)")
                XCTAssertEqual(run.wave?.intent, intent)
                XCTAssertEqual(run.wave?.approach, approach, "the viewer's own approach, never the counterpart's")
                XCTAssertEqual(run.wave?.screen, .menu)
                XCTAssertNil(run.wave?.invitation, "the menu alone starts nothing")
            }
        }
    }

    func testOpeningTheWavePreservesTheRun() {
        var run = RoomFixture.populated(.business, approach: .okayToSayHello)
        RoomFixture.block(.maya, in: &run)
        XCTAssertTrue(run.openProfile(.jules))
        let before = run
        XCTAssertTrue(run.openWaveDemo(viewerName: "Sam"))
        XCTAssertEqual(run.id, before.id)
        XCTAssertEqual(run.phase, .populated)
        XCTAssertEqual(run.blocked, [.maya], "existing blocks stay applied")
        XCTAssertEqual(run.tab, before.tab)
        XCTAssertEqual(run.route, [.profile(.jules), .waveDemo])
        XCTAssertFalse(run.openWaveDemo(viewerName: "Sam"), "a repeated tap opens nothing more")
        XCTAssertTrue(run.isConsistent)
    }

    func testOpeningIsRefusedOutsideAnEligibleSameIntentProfile() {
        XCTAssertFalse(RoomFixture.waiting(.social).openingWave(), "waiting")
        var people = RoomFixture.populated(.social)
        XCTAssertFalse(people.openWaveDemo(viewerName: "Alex"), "People, no profile")
        var other = RoomFixture.populated(.social)
        other.openProfile(.jules)
        XCTAssertFalse(other.openWaveDemo(viewerName: "Alex"), "another intent keeps Back to people")
        var safety = RoomFixture.populated(.social)
        safety.openProfile(.maya)
        safety.openActorSafety(.maya)
        XCTAssertFalse(safety.openWaveDemo(viewerName: "Alex"), "not under the profile's safety")
        var blank = RoomFixture.populated(.social)
        blank.openProfile(.maya)
        XCTAssertFalse(blank.openWaveDemo(viewerName: "  \n"), "no blank viewer name")
        var blocked = RoomFixture.blocking([.maya], .social)
        XCTAssertFalse(blocked.openProfile(.maya))
        XCTAssertFalse(blocked.openWaveDemo(viewerName: "Alex"), "a Room block before entry keeps the Wave shut")
        var ended = RoomFixture.populated(.social)
        ended.openProfile(.maya)
        ended.leave()
        XCTAssertFalse(ended.openWaveDemo(viewerName: "Alex"))
    }

    func testRoomControlsAreInertUnderTheWave() {
        var run = WaveFixture.menu(.social)
        let before = run
        XCTAssertFalse(run.selectTab(.notes))
        XCTAssertFalse(run.openProfile(.jules))
        XCTAssertFalse(run.backToPeople())
        XCTAssertFalse(run.openGlobalSafety())
        XCTAssertFalse(run.openActorSafety(.maya))
        XCTAssertFalse(run.previewReport())
        XCTAssertFalse(run.selectReportReason(.harassment))
        XCTAssertFalse(run.block(.maya))
        XCTAssertFalse(run.closeLevel(), "a stale Room Close never closes the Wave")
        XCTAssertFalse(run.showPopulatedExample())
        XCTAssertEqual(run, before)
    }

    // MARK: - Identity

    func testExplicitStartsCreateFreshDistinctImmutableIdentities() {
        var run = WaveFixture.menu(.social)
        var seen: [WaveInvitationID] = []
        for step in 0..<6 {
            XCTAssertTrue(run.perform(step.isMultiple(of: 2) ? .startOutgoing : .startIncoming))
            guard let invitation = run.wave?.invitation else { return XCTFail("no invitation") }
            XCTAssertFalse(seen.contains(invitation.id), "fresh identity per explicit start")
            XCTAssertEqual(invitation.roomRunID, run.id)
            XCTAssertEqual(invitation.venue, .commonGround)
            XCTAssertEqual(invitation.intent, .social)
            if step.isMultiple(of: 2) {
                XCTAssertEqual(invitation.sender, .viewer)
                XCTAssertEqual(invitation.recipient, .sample(.maya))
                XCTAssertEqual(invitation.direction, .outgoing)
                XCTAssertEqual(invitation.status, .compose)
                XCTAssertTrue(run.perform(.discardCompose(invitation.id)))
            } else {
                XCTAssertEqual(invitation.sender, .sample(.maya))
                XCTAssertEqual(invitation.recipient, .viewer, "the viewer never switches account")
                XCTAssertEqual(invitation.direction, .incoming)
                XCTAssertEqual(invitation.status, .pending)
                XCTAssertTrue(run.perform(.decline(invitation.id)))
                XCTAssertTrue(run.perform(.backToMenu(from: .incomingDeclined)))
            }
            seen.append(invitation.id)
        }
        XCTAssertEqual(seen.map(\.sequence), Array(1...6))
        XCTAssertEqual(run.waveStarts, 6)
    }

    func testMalformedInvitationsAreRejected() {
        let run = RoomRunID(1)
        let id = WaveInvitationID(run: run, sequence: 1)
        XCTAssertNil(WaveInvitation(id: id, roomRunID: run, sender: .viewer, recipient: .viewer,
                                    venue: .commonGround, intent: .social), "self-addressed")
        XCTAssertNil(WaveInvitation(id: id, roomRunID: run, sender: .sample(.maya), recipient: .sample(.maya),
                                    venue: .commonGround, intent: .social), "self-addressed sample")
        XCTAssertNil(WaveInvitation(id: id, roomRunID: run, sender: .sample(.maya), recipient: .sample(.jules),
                                    venue: .commonGround, intent: .social), "the viewer on neither side")
        XCTAssertNil(WaveInvitation(id: id, roomRunID: RoomRunID(2), sender: .viewer, recipient: .sample(.maya),
                                    venue: .commonGround, intent: .social), "an identity from another run")
    }

    func testEachAcceptanceGuard() {
        let central = WaveCentral(runID: RoomRunID(1), active: true, populated: true, blocked: [], intent: .social,
                                  venue: .commonGround)
        func demo(_ invitation: WaveInvitation?, counterpart: RoomActor = .maya, intent: BandIntent = .social,
                  venue: Venue = .commonGround) -> WaveDemo {
            WaveDemo(counterpart: counterpart, viewerName: "Alex", intent: intent, approach: .chatFirst, venue: venue,
                     example: invitation.map { .invitation($0) } ?? .menu)
        }
        func incoming(run: Int = 1, venue: Venue = .commonGround, intent: BandIntent = .social) -> WaveInvitation? {
            WaveInvitation(id: WaveInvitationID(run: RoomRunID(run), sequence: 1), roomRunID: RoomRunID(run),
                           sender: .sample(.maya), recipient: .viewer, venue: venue, intent: intent)
        }
        let id = WaveInvitationID(run: RoomRunID(1), sequence: 1)
        XCTAssertNil(demo(incoming()).acceptanceRefusal(id, central: central), "a valid pending incoming")
        XCTAssertEqual(demo(incoming()).acceptanceRefusal(WaveInvitationID(run: RoomRunID(1), sequence: 2),
                                                          central: central), .sameWaveID)
        XCTAssertEqual(demo(incoming(run: 2)).acceptanceRefusal(WaveInvitationID(run: RoomRunID(2), sequence: 1),
                                                                central: central), .sameRoomRun)
        let outgoing = WaveInvitation(id: id, roomRunID: RoomRunID(1), sender: .viewer, recipient: .sample(.maya),
                                      venue: .commonGround, intent: .social)
        XCTAssertEqual(demo(outgoing).acceptanceRefusal(id, central: central), .pending, "outgoing is never acceptable")
        let ended = WaveCentral(runID: RoomRunID(1), active: false, populated: false, blocked: [], intent: .social,
                                venue: .commonGround)
        XCTAssertEqual(demo(incoming()).acceptanceRefusal(id, central: ended), .roomPopulatedAndActive)
        XCTAssertEqual(demo(incoming(venue: .afterglow)).acceptanceRefusal(id, central: central), .sameVenue)
        XCTAssertEqual(demo(incoming(intent: .business)).acceptanceRefusal(id, central: central), .sameIntent)
        let blocked = WaveCentral(runID: RoomRunID(1), active: true, populated: true, blocked: [.maya],
                                  intent: .social, venue: .commonGround)
        XCTAssertEqual(demo(incoming()).acceptanceRefusal(id, central: blocked), .noBlockOrInvalidation)
        XCTAssertEqual(demo(incoming(), counterpart: .jules).acceptanceRefusal(id, central: central),
                       .senderDiffersFromRecipient, "the sender must be this Wave's counterpart")
    }

    func testAViewerNamedLikeTheCounterpartKeepsTheirOwnIdentity() {
        var run = WaveFixture.menu(.social, name: "Maya")
        XCTAssertTrue(run.perform(.startIncoming))
        guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
        XCTAssertEqual(run.wave?.invitation?.recipient, .viewer)
        XCTAssertTrue(run.perform(.accept(id)), "identity is the participant, never the display name")
        // The guest named like the counterpart is "YOU" in the direction line, so sender and recipient
        // stay distinct; the context line still names them ("YOU ARE MAYA").
        XCTAssertEqual(WaveCopy.directionLine(.incomingAccepted, viewer: "Maya", counterpart: .maya),
                       "MAYA + YOU · INCOMING DEMO")
        XCTAssertEqual(WaveCopy.directionLine(.incomingReview, viewer: " maya ", counterpart: .maya),
                       "MAYA → YOU · INCOMING")
        XCTAssertEqual(WaveCopy.directionLine(.outgoingPending, viewer: "JULES", counterpart: .jules),
                       "YOU → JULES · OUTGOING")
        XCTAssertEqual(WaveCopy.directionLine(.outgoingPending, viewer: "Mayana", counterpart: .maya),
                       "MAYANA → MAYA · OUTGOING", "only an equal name becomes YOU")
        XCTAssertEqual(WaveCopy.stateContext(.incoming, viewer: "Maya"), "INCOMING · YOU ARE MAYA")
    }

    // MARK: - Outgoing

    func testSendIsOneIdempotentComposeToPendingTransition() {
        var run = WaveFixture.menu(.business)
        run.perform(.startOutgoing)
        guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
        XCTAssertEqual(run.wave?.screen, .outgoingConfirm)
        XCTAssertEqual(run.wave?.allowance, .available)
        XCTAssertTrue(run.perform(.send(id)))
        let pending = run
        XCTAssertFalse(run.perform(.send(id)), "a repeated Send is idempotent")
        XCTAssertEqual(run, pending)
        XCTAssertEqual(run.wave?.screen, .outgoingPending)
        XCTAssertEqual(run.wave?.allowance, .available, "no decrement ledger exists")
    }

    func testPendingNeverReturnsToCompose() {
        var run = WaveFixture.at(.outgoingPending, .social)
        guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
        let pending = run
        XCTAssertFalse(run.perform(.discardCompose(id)))
        XCTAssertEqual(run.outerBack(), .none, "pending has no Back: never a stale compose")
        XCTAssertEqual(run, pending)
        XCTAssertEqual(run.wave?.screen, .outgoingPending)
    }

    func testWithdrawClosesThatIdentityForever() {
        var run = WaveFixture.at(.outgoingPending, .social)
        guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
        XCTAssertTrue(run.perform(.withdraw(id)))
        XCTAssertEqual(run.wave?.screen, .outgoingWithdrawn)
        let closed = run
        for action in WaveFixture.invitationActions(id) {
            XCTAssertFalse(run.perform(action), "\(action)")
        }
        XCTAssertEqual(run, closed)
        XCTAssertTrue(run.perform(.backToMenu(from: .outgoingWithdrawn)))
        XCTAssertTrue(run.perform(.startOutgoing))
        XCTAssertNotEqual(run.wave?.invitation?.id, id, "a new example is a new identity")
    }

    func testNoSenderFacingAcceptAnywhere() {
        for screen in [WaveScreen.outgoingConfirm, .outgoingPending, .outgoingWithdrawn] {
            var run = WaveFixture.at(screen, .social)
            guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
            XCTAssertEqual(run.acceptanceRefusal(id), .pending, "\(screen)")
            XCTAssertFalse(run.perform(.accept(id)), "\(screen)")
            XCTAssertFalse(run.perform(.decline(id)), "\(screen)")
            XCTAssertFalse(screen.conditions.contains(.senderWithdrawn))
        }
    }

    func testNoAllowanceExampleHasNoSendAndNoIdentity() {
        var run = WaveFixture.menu(.social)
        XCTAssertTrue(run.perform(.startOutgoing))
        guard let stale = run.wave?.invitation?.id else { return XCTFail("no invitation") }
        run.perform(.discardCompose(stale))
        XCTAssertTrue(run.perform(.showNoAllowance))
        XCTAssertEqual(run.wave?.screen, .allowanceUnavailable)
        XCTAssertEqual(run.wave?.allowance, .unavailable)
        XCTAssertNil(run.wave?.invitation)
        XCTAssertEqual(run.waveStarts, 1, "no identity issued")
        XCTAssertFalse(run.perform(.send(stale)))
        XCTAssertTrue(run.perform(.backToMenu(from: .allowanceUnavailable)))
    }

    // MARK: - Incoming

    func testOnlyThePendingRecipientAccepts() {
        for intent in [BandIntent.social, .business] {
            var run = WaveFixture.at(.incomingReview, intent)
            guard let id = run.wave?.invitation?.id else { return XCTFail("no invitation") }
            XCTAssertEqual(run.wave?.screen.rings, .separate)
            XCTAssertTrue(run.perform(.accept(id)))
            XCTAssertEqual(run.wave?.screen, .incomingAccepted)
            XCTAssertEqual(run.wave?.screen.rings, .joined, "rings join only after a committed recipient Accept")
            let accepted = run
            XCTAssertFalse(run.perform(.accept(id)), "no second agreement")
            XCTAssertEqual(run, accepted)
        }
    }

    func testDeclineSenderWithdrawnAndExpiredWinOverAStaleAccept() {
        var declined = WaveFixture.at(.incomingReview, .social)
        let a = declined.wave!.invitation!.id
        XCTAssertTrue(declined.perform(.decline(a)))
        XCTAssertFalse(declined.perform(.accept(a)))
        XCTAssertEqual(declined.wave?.screen, .incomingDeclined)

        var withdrawn = WaveFixture.at(.incomingReview, .business)
        let b = withdrawn.wave!.invitation!.id
        XCTAssertTrue(withdrawn.perform(.openConditions(b)))
        XCTAssertFalse(withdrawn.perform(.accept(b)), "not under the demo conditions")
        XCTAssertTrue(withdrawn.perform(.showSenderWithdrawn(b)))
        XCTAssertFalse(withdrawn.perform(.accept(b)))
        XCTAssertEqual(withdrawn.wave?.screen, .incomingWithdrawn)

        for screen in [WaveScreen.outgoingPending, .incomingReview, .incomingAccepted] {
            var run = WaveFixture.at(screen, .social)
            let id = run.wave!.invitation!.id
            XCTAssertTrue(run.perform(.openConditions(id)), "\(screen)")
            XCTAssertTrue(run.perform(.showExpired(id)), "\(screen)")
            XCTAssertEqual(run.wave?.screen, .unavailable)
            XCTAssertEqual(run.wave?.invitation?.status, .unavailable, "retained, terminal")
            XCTAssertFalse(run.perform(.accept(id)))
            XCTAssertFalse(run.perform(.openChatInformation(id)))
            XCTAssertEqual(run.phase, .populated, "the fixed snapshot's Room stays eligible")
        }
    }

    func testChatInformationIsInformationOnlyAndClosesToTheSameAcceptedResult() {
        var run = WaveFixture.at(.incomingAccepted, .social)
        let id = run.wave!.invitation!.id
        let accepted = run
        XCTAssertTrue(run.perform(.openChatInformation(id)))
        XCTAssertEqual(run.wave?.overlay, .chatInformation)
        XCTAssertFalse(run.perform(.closeOverlay(.globalSafety)), "only the overlay on top closes")
        XCTAssertTrue(run.perform(.closeOverlay(.chatInformation)))
        XCTAssertEqual(run, accepted)
        XCTAssertTrue(run.perform(.openChatInformation(id)))
        XCTAssertTrue(run.leave())
        XCTAssertFalse(run.perform(.closeOverlay(.chatInformation)), "closing never restores an ended result")
        XCTAssertEqual(run.wave?.screen, .sessionEnded)
    }

    // MARK: - Blocks

    func testAWaveBlockUsesTheSameCentralSet() {
        for (intent, counterpart, other) in [(BandIntent.social, RoomActor.maya, RoomActor.jules),
                                             (.business, .jules, .maya)] {
            for screen in [WaveScreen.outgoingConfirm, .outgoingPending, .incomingReview, .incomingAccepted] {
                var run = WaveFixture.at(screen, intent)
                XCTAssertTrue(run.perform(.openSafety(from: screen)))
                XCTAssertTrue(run.perform(.previewReport))
                XCTAssertTrue(run.perform(.blockCounterpart), "\(intent) \(screen)")
                XCTAssertEqual(run.blocked, [counterpart])
                XCTAssertEqual(run.wave?.screen, .blocked)
                XCTAssertEqual(run.wave?.invitation?.status, .blocked)
                XCTAssertNil(run.wave?.visibleCounterpart)
                XCTAssertEqual(run.wave?.overlays, [])
                XCTAssertEqual(run.route, [.waveDemo], "no Room level concerns the blocked actor")
                XCTAssertEqual(run.visiblePeople, [other])
                XCTAssertEqual(run.visibleNoteAuthors, counterpart == .jules ? [] : [.jules],
                               "Jules's note goes only with Jules")
                XCTAssertTrue(run.isConsistent)
                XCTAssertFalse(run.perform(.blockCounterpart), "no second block, no undo")
            }
        }
    }

    func testBothBlockOrdersEndTheSame() {
        for intent in [BandIntent.social, .business] {
            let counterpart = WaveFixture.counterpart(intent)
            let other: RoomActor = counterpart == .maya ? .jules : .maya
            // Room first (the other intent's sample), then the Wave's counterpart.
            var roomFirst = WaveFixture.at(.incomingReview, intent, preblock: [other])
            roomFirst.perform(.openSafety(from: .incomingReview))
            roomFirst.perform(.blockCounterpart)
            // The Wave's counterpart first, back to the Room, then the other sample there.
            var waveFirst = WaveFixture.at(.incomingReview, intent)
            waveFirst.perform(.openSafety(from: .incomingReview))
            waveFirst.perform(.blockCounterpart)
            XCTAssertTrue(waveFirst.perform(.backToMenu(from: .blocked)))
            XCTAssertEqual(waveFirst.outerBack(), .closedLevel)
            XCTAssertNil(waveFirst.wave)
            XCTAssertEqual(waveFirst.route, [], "back to the filtered People, never the blocked profile")
            XCTAssertTrue(RoomFixture.block(other, in: &waveFirst))
            XCTAssertEqual(roomFirst.blocked, waveFirst.blocked)
            XCTAssertEqual(roomFirst.visiblePeople, [])
            XCTAssertEqual(waveFirst.visiblePeople, [])
            XCTAssertEqual(roomFirst.visibleNoteAuthors, waveFirst.visibleNoteAuthors)
            XCTAssertTrue(waveFirst.showsNoSampleIntroductions)
        }
    }

    func testNewExamplesNeverUnblockOrRevive() {
        var run = WaveFixture.at(.outgoingPending, .social)
        run.perform(.openSafety(from: .outgoingPending))
        run.perform(.blockCounterpart)
        run.perform(.backToMenu(from: .blocked))
        let starts = run.waveStarts
        for action in [WaveAction.startOutgoing, .startIncoming, .showNoAllowance] {
            var attempt = run
            XCTAssertTrue(attempt.perform(action))
            XCTAssertEqual(attempt.wave?.screen, .blocked, "\(action): the generic blocked state")
            XCTAssertNil(attempt.wave?.invitation)
            XCTAssertEqual(attempt.waveStarts, starts, "no identity issued")
            XCTAssertEqual(attempt.blocked, [.maya])
            XCTAssertNil(attempt.wave?.visibleCounterpart)
        }
    }

    // MARK: - Leave

    func testLeaveEndsRoomAndWaveFromEveryWaveContext() {
        for intent in [BandIntent.social, .business] {
            for screen in WaveScreen.allCases where screen != .sessionEnded {
                for overlay in [nil] + WaveFixture.overlays(on: screen) {
                    var run = WaveFixture.at(screen, intent)
                    if let overlay { XCTAssertTrue(WaveFixture.open(overlay, on: screen, in: &run), "\(screen) \(overlay)") }
                    let blocks = run.blocked
                    XCTAssertTrue(run.leave(), "\(screen)")
                    XCTAssertEqual(run.phase, .ended)
                    XCTAssertEqual(run.route, [])
                    XCTAssertEqual(run.wave?.screen, .sessionEnded)
                    XCTAssertEqual(run.wave?.overlays, [])
                    XCTAssertEqual(run.blocked, blocks, "Leave never clears a block")
                    if let status = run.wave?.invitation?.status { XCTAssertTrue(status.isTerminal) }
                    XCTAssertTrue(run.isConsistent)
                    let ended = run
                    for action in WaveFixture.everyAction(run) { XCTAssertFalse(run.perform(action), "\(action)") }
                    XCTAssertEqual(run.outerBack(), .alreadyEnded)
                    XCTAssertFalse(run.closeWaveDemo())
                    XCTAssertEqual(run, ended)
                }
            }
        }
    }

    func testLeaveFromTheRoomShowsTheRoomsOwnEndedScreen() {
        var run = RoomFixture.populated(.social)
        run.leave()
        XCTAssertNil(run.waveScreen)
        var wave = WaveFixture.menu(.social)
        wave.leave()
        XCTAssertEqual(wave.waveScreen, .sessionEnded)
    }

    func testReturnToPlacesNeedsTheWholeSequenceAgain() {
        var flow = RoomFixture.onExplanation(.business, approach: .chatFirst)
        let draft = flow.draft
        var preview = RoomPreview.open(after: flow)!
        preview.enter(as: RoomRunID(1))
        preview.updateRun(RoomRunID(1)) { $0.showPopulatedExample() && $0.openProfile(.jules)
            && $0.openWaveDemo(viewerName: "Sam") && $0.perform(.startIncoming) }
        preview.updateRun(RoomRunID(1)) { $0.leave() }
        XCTAssertTrue(flow.exploreOtherPlaces(), "Return to Places: actual Places Now")
        XCTAssertEqual(flow.currentScene, .places)
        XCTAssertEqual(flow.placesCategory, .now)
        XCTAssertEqual(flow.draft, draft, "the onboarding draft is intact")
        XCTAssertFalse(preview.isStillValid(for: flow), "the old Room cannot come back")
        flow.openPlaceDetail()
        flow.previewCheckIn()
        var fresh = RoomPreview.open(after: flow)!
        XCTAssertNil(fresh.run)
        fresh.enter(as: RoomRunID(2))
        XCTAssertNil(fresh.run?.wave, "no Wave state carries over")
        XCTAssertFalse(fresh.updateRun(RoomRunID(2)) { $0.openProfile(.jules) }, "waiting first")
    }

    // MARK: - Outer Back, stale callbacks, reports

    func testOuterBackFollowsTheVisibleBackOnly() {
        var run = WaveFixture.at(.outgoingConfirm, .social)
        XCTAssertEqual(run.outerBack(), .closedLevel)
        XCTAssertEqual(run.wave?.screen, .menu, "the confirmation's Back discards the unsent invitation")
        for screen in [WaveScreen.outgoingPending, .incomingReview, .incomingAccepted] {
            var active = WaveFixture.at(screen, .business)
            let before = active
            XCTAssertEqual(active.outerBack(), .none, "\(screen)")
            XCTAssertEqual(active, before)
        }
        var closed = WaveFixture.at(.incomingDeclined, .social)
        XCTAssertEqual(closed.outerBack(), .closedLevel)
        XCTAssertEqual(closed.wave?.screen, .menu)
        XCTAssertEqual(closed.outerBack(), .closedLevel)
        XCTAssertNil(closed.wave)
        XCTAssertEqual(closed.route, [.profile(.maya)], "back to the caller profile")
    }

    func testStaleCallbacksChangeNothing() {
        var run = WaveFixture.at(.outgoingConfirm, .social)
        let old = run.wave!.invitation!.id
        run.perform(.discardCompose(old))
        run.perform(.startIncoming)
        let current = run
        for action in WaveFixture.invitationActions(old) { XCTAssertFalse(run.perform(action), "\(action)") }
        XCTAssertFalse(run.perform(.openSafety(from: .outgoingConfirm)), "drawn for a screen no longer shown")
        XCTAssertFalse(run.perform(.backToMenu(from: .incomingDeclined)))
        XCTAssertEqual(run, current)

        var preview = RoomPreview.open(after: RoomFixture.onExplanation(.social, approach: .chatFirst))!
        preview.enter(as: RoomRunID(5))
        preview.updateRun(RoomRunID(5)) { $0.showPopulatedExample() && $0.openProfile(.maya)
            && $0.openWaveDemo(viewerName: "Alex") && $0.perform(.startIncoming) }
        let id = preview.run!.wave!.invitation!.id
        XCTAssertFalse(preview.updateRun(RoomRunID(4)) { $0.perform(.accept(id)) }, "another run's callback")
        XCTAssertEqual(preview.run?.wave?.screen, .incomingReview)
    }

    func testReportIsLocalUnsentSingleChoiceAndNeverLeaks() {
        var run = WaveFixture.at(.incomingAccepted, .business)
        let accepted = run
        XCTAssertTrue(run.perform(.openSafety(from: .incomingAccepted)))
        XCTAssertTrue(run.perform(.previewReport))
        XCTAssertEqual(run.wave?.overlay, .report(nil), "no initial choice")
        XCTAssertTrue(run.perform(.selectReportReason(.harassment)))
        XCTAssertFalse(run.perform(.selectReportReason(.harassment)), "the selected reason again is a no-op")
        XCTAssertTrue(run.perform(.selectReportReason(.somethingElse)))
        XCTAssertTrue(run.perform(.closeOverlay(.report(nil))))
        XCTAssertEqual(run.wave?.overlay, .counterpartSafety, "back to its caller")
        XCTAssertTrue(run.perform(.previewReport))
        XCTAssertEqual(run.wave?.overlay, .report(nil), "a new preview starts unselected")
        XCTAssertTrue(run.perform(.closeOverlay(.report(nil))))
        XCTAssertTrue(run.perform(.closeOverlay(.counterpartSafety)))
        XCTAssertEqual(run, accepted, "nothing about the invitation or blocks changed")
        XCTAssertEqual(WaveCopy.reportTitle(.jules), "Report Jules")
    }

    func testOverlaysOpenOnlyWhereTheDesignPutsThem() {
        for screen in WaveScreen.allCases where screen != .sessionEnded {
            let run = WaveFixture.at(screen, .social)
            for overlay in [WaveOverlay.globalSafety, .counterpartSafety, .chatInformation, .conditions] {
                var attempt = run
                let opened = WaveFixture.open(overlay, on: screen, in: &attempt)
                XCTAssertEqual(opened, WaveFixture.overlays(on: screen).contains(overlay), "\(screen) \(overlay)")
            }
        }
    }

    // MARK: - Copy and shape

    func testTheApprovedWaveCopyForBothIntents() {
        XCTAssertEqual(WaveCopy.viewerPreference(viewer: "Alex", intent: .social, approach: .okayToSayHello),
                       "Alex · Social · Okay to say hello")
        XCTAssertEqual(RoomActor.maya.line, "Social · Chat first", "the invitation shows the counterpart's own values")
        XCTAssertEqual(WaveCopy.stateContext(.outgoing, viewer: "Alex"), "OUTGOING · YOU ARE ALEX")
        XCTAssertEqual(WaveCopy.directionLine(.outgoingPending, viewer: "Sam", counterpart: .jules),
                       "SAM → JULES · OUTGOING")
        XCTAssertEqual(WaveCopy.directionLine(.incomingReview, viewer: "Alex", counterpart: .maya),
                       "MAYA → ALEX · INCOMING")
        XCTAssertEqual(WaveCopy.invitationTitle(.outgoingPending, counterpart: .jules), "Waiting for Jules.")
        XCTAssertEqual(WaveCopy.invitationPurpose(.outgoingConfirm, counterpart: .jules),
                       "A Wave invites a conversation.\nJules chooses whether to accept.")
        XCTAssertEqual(WaveCopy.block(.jules), "Block Jules in demo")
        XCTAssertEqual(WaveCopy.counterpartSafetyTitle(.jules), "Jules · safety")
        XCTAssertEqual(WaveCopy.roleExplanation(viewer: "Alex"), "You are Alex in both examples.")
        for screen in WaveScreen.allCases {
            for text in [WaveCopy.boundary(screen), WaveCopy.closedExplanation(screen)].compactMap({ $0 }) {
                XCTAssertNil(text.range(of: #"\d"#, options: .regularExpression), "no numeric allowance: \(text)")
            }
        }
    }

    func testNoProductionLikeStateAndNothingPersistable() {
        var run = WaveFixture.at(.incomingAccepted, .social, history: true)
        run.perform(.openChatInformation(run.wave!.invitation!.id))
        XCTAssertFalse(run.closedInvitations.isEmpty, "the closed record is searched too")
        let words = ["verif", "member", "entitle", "presence", "online", "account", "consent", "permission",
                     "location", "camera", "token", "submit", "conversation", "chat", "keep", "message", "quota",
                     "refill", "refund", "cooldown", "remaining", "clock", "date", "time", "deliver",
                     "notif", "push", "receipt", "read", "server"]
        for label in Self.propertyNames(of: run) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
        for type in [WaveDemo.self, WaveInvitation.self, WaveInvitationID.self, WaveStatus.self, WaveExample.self,
                     WaveOverlay.self, WaveParticipant.self, WaveAllowance.self, WaveAction.self, WaveScreen.self,
                     WaveDirection.self, WaveCondition.self, WaveRings.self, WaveChrome.self,
                     WaveAcceptanceGuard.self, RoomRun.self] as [Any.Type] {
            XCTAssertFalse(type is Encodable.Type, "\(type)")
            XCTAssertFalse(type is Decodable.Type, "\(type)")
        }
    }

    /// The Room's own word list (RoomDemoTests) still holds for a run carrying an accepted Wave: the
    /// status names are enum cases, never stored-property labels.
    func testTheRoomWordListStillHoldsWithTheWaveOpen() {
        var run = WaveFixture.at(.incomingAccepted, .business, history: true)
        run.perform(.openSafety(from: .incomingAccepted))
        run.perform(.previewReport)
        run.perform(.selectReportReason(.unwantedAttention))
        let words = ["verif", "visib", "discover", "member", "entitle", "presence", "checkedin", "checkin", "attend",
                     "online", "match", "account", "identity", "consent", "permission", "location", "camera",
                     "scan", "credential", "token", "submit", "sent", "pending", "accept", "clock", "date", "time"]
        for label in Self.propertyNames(of: run) {
            for word in words {
                XCTAssertFalse(label.lowercased().contains(word), "\(label) looks like \(word) state")
            }
        }
    }

    // MARK: - The closed record (lead decision 5)

    /// "Retain immutable IDs/terminal status internally even when the generic screen displays no invitation
    /// details" (CLAUDE_PROMPT.md:68): every invitation that closes stays in the run's record, in order, for
    /// the life of the run; nothing is ever removed, rewritten or reopened.
    func testClosedInvitationsAreRetainedAppendOnlyForTheWholeRun() {
        for intent in [BandIntent.social, .business] {
            let counterpart = WaveFixture.counterpart(intent)
            var run = WaveFixture.menu(intent)
            var previous: [WaveInvitation] = []
            func id() -> WaveInvitationID { run.wave!.invitation!.id }
            func expect(_ statuses: [WaveStatus], _ step: String, line: UInt = #line) {
                XCTAssertEqual(run.closedInvitations.map(\.status), statuses, "\(intent) \(step)", line: line)
                XCTAssertTrue(run.closedInvitations.starts(with: previous), "\(intent) \(step): append-only",
                              line: line)
                XCTAssertTrue(run.isConsistent, "\(intent) \(step)", line: line)
                previous = run.closedInvitations
            }
            run.perform(.startOutgoing)
            run.perform(.send(id()))
            expect([], "pending is still active")
            run.perform(.withdraw(id()))
            expect([.withdrawn], "withdrawn")
            XCTAssertEqual(run.closedInvitations.last, run.wave?.invitation, "the closed screen's own invitation")
            run.perform(.backToMenu(from: .outgoingWithdrawn))
            expect([.withdrawn], "released from its screen, still retained")
            run.perform(.startIncoming)
            run.perform(.decline(id()))
            expect([.withdrawn, .declined], "declined")
            run.perform(.backToMenu(from: .incomingDeclined))
            run.perform(.startIncoming)
            run.perform(.openConditions(id()))
            run.perform(.showSenderWithdrawn(id()))
            expect([.withdrawn, .declined, .senderWithdrawn], "sender withdrawn")
            run.perform(.backToMenu(from: .incomingWithdrawn))
            run.perform(.startOutgoing)
            run.perform(.discardCompose(id()))
            expect([.withdrawn, .declined, .senderWithdrawn], "an unsent confirmation never closed")
            run.perform(.startIncoming)
            let reviewing = run
            for closed in run.closedInvitations {
                for action in WaveFixture.invitationActions(closed.id) {
                    XCTAssertFalse(run.perform(action), "\(intent): a retained \(closed.id) reopens with \(action)")
                }
            }
            XCTAssertEqual(run, reviewing, "no retained identity acts on the current example")
            run.perform(.accept(id()))
            run.perform(.openConditions(id()))
            run.perform(.showExpired(id()))
            expect([.withdrawn, .declined, .senderWithdrawn, .unavailable], "an accepted example expired")
            run.perform(.backToMenu(from: .unavailable))
            run.perform(.showNoAllowance)
            expect([.withdrawn, .declined, .senderWithdrawn, .unavailable], "no allowance: no invitation at all")
            run.perform(.backToMenu(from: .allowanceUnavailable))
            run.perform(.startOutgoing)
            run.perform(.send(id()))
            run.perform(.openSafety(from: .outgoingPending))
            run.perform(.blockCounterpart)
            let closed: [WaveStatus] = [.withdrawn, .declined, .senderWithdrawn, .unavailable, .blocked]
            expect(closed, "blocked")
            run.perform(.backToMenu(from: .blocked))
            run.perform(.startIncoming)
            expect(closed, "a start after the block is the generic blocked state, with no invitation")
            run.perform(.backToMenu(from: .blocked))
            XCTAssertEqual(run.outerBack(), .closedLevel)
            XCTAssertNil(run.wave, "back to the filtered People")
            expect(closed, "the Wave closed; the run keeps its record")
            XCTAssertTrue(run.leave())
            expect(closed, "a Leave from the Room keeps it too")

            XCTAssertEqual(run.closedInvitations.map(\.id.sequence), [1, 2, 3, 5, 6], "the discarded 4th never closed")
            XCTAssertEqual(run.waveStarts, 6)
            XCTAssertEqual(run.closedInvitations.map(\.direction),
                           [.outgoing, .incoming, .incoming, .incoming, .outgoing])
            for invitation in run.closedInvitations {
                XCTAssertEqual(invitation.roomRunID, run.id)
                XCTAssertEqual(invitation.id.run, run.id)
                XCTAssertEqual(invitation.counterpart, counterpart)
                XCTAssertEqual(invitation.venue, .commonGround)
                XCTAssertEqual(invitation.intent, intent)
                XCTAssertEqual(invitation.direction == .outgoing ? invitation.sender : invitation.recipient, .viewer)
            }
        }
        var fresh = RoomFixture.entry(.social)
        fresh.enter(as: RoomRunID(9))
        XCTAssertEqual(fresh.run?.closedInvitations, [], "a new run starts with no record: it lives with its run")
    }

    // MARK: - Repeated taps, frozen screens, Demo cases

    /// A second identical tap is always refused and changes nothing, from every reachable context.
    func testDuplicateTapsAreIdempotent() {
        var exercised: Set<String> = []
        for intent in [BandIntent.social, .business] {
            for (name, context) in WaveFixture.contexts(intent) {
                for action in WaveFixture.everyAction(context) {
                    var run = context
                    guard run.perform(action) else {
                        XCTAssertEqual(run, context, "\(intent) \(name): a refused \(action) changed something")
                        continue
                    }
                    exercised.insert(WaveFixture.kind(action))
                    let once = run
                    XCTAssertFalse(run.perform(action), "\(intent) \(name): \(action) twice")
                    XCTAssertEqual(run, once, "\(intent) \(name): \(action) twice")
                }
                var left = context
                if left.leave() {
                    let once = left
                    XCTAssertFalse(left.leave(), "\(intent) \(name): Leave twice")
                    XCTAssertEqual(left, once)
                }
                var closed = context
                if closed.closeWaveDemo() {
                    let once = closed
                    XCTAssertFalse(closed.closeWaveDemo(), "\(intent) \(name): closing twice")
                    XCTAssertEqual(closed, once)
                }
            }
            var profile = RoomFixture.populated(intent)
            profile.openProfile(WaveFixture.counterpart(intent))
            XCTAssertTrue(profile.openWaveDemo(viewerName: "Alex"))
            let opened = profile
            XCTAssertFalse(profile.openWaveDemo(viewerName: "Alex"), "Preview Wave demo twice")
            XCTAssertEqual(profile, opened)
        }
        XCTAssertEqual(exercised, WaveFixture.allKinds, "every Wave control was tapped twice somewhere")
    }

    /// Under any overlay only that overlay's own controls act (and Leave, tested elsewhere). The screen
    /// below, its invitation and the Room stay exactly as they were, and the outer Back closes one level.
    func testOverlaysFreezeTheScreenBelow() {
        for intent in [BandIntent.social, .business] {
            for (name, context) in WaveFixture.contexts(intent) {
                guard let wave = context.wave, let top = wave.overlay else { continue }
                for action in WaveFixture.everyAction(context) {
                    var run = context
                    if run.perform(action) {
                        XCTAssertTrue(Self.isControl(action, of: top),
                                      "\(intent) \(name): \(action) acted below \(top)")
                    } else {
                        XCTAssertEqual(run, context, "\(intent) \(name): \(action)")
                    }
                }
                var room = context
                XCTAssertFalse(room.closeLevel())
                XCTAssertFalse(room.closeWaveDemo())
                XCTAssertFalse(room.openGlobalSafety())
                XCTAssertFalse(room.selectTab(.notes))
                for actor in RoomActor.allCases {
                    XCTAssertFalse(room.openProfile(actor))
                    XCTAssertFalse(room.openActorSafety(actor))
                    XCTAssertFalse(room.block(actor))
                }
                XCTAssertEqual(room, context, "\(intent) \(name): the Room below is inert")
                var back = context
                XCTAssertEqual(back.outerBack(), .closedLevel, "\(intent) \(name)")
                XCTAssertEqual(back.wave?.screen, wave.screen)
                XCTAssertEqual(back.wave?.invitation, wave.invitation)
                XCTAssertEqual(back.wave?.overlays, Array(wave.overlays.dropLast()), "exactly one level")
            }
        }
    }

    /// The controls each overlay itself offers (74:580–74:586): its Close/Back, the safety's Block and
    /// Preview report, the report's reasons (Block stays possible while its safety is below), and Demo
    /// cases' two labelled conditions.
    private static func isControl(_ action: WaveAction, of top: WaveOverlay) -> Bool {
        switch (top, action) {
        case (_, .closeOverlay(let which)): return which.kind == top.kind
        case (.counterpartSafety, .previewReport), (.counterpartSafety, .blockCounterpart): return true
        case (.report, .selectReportReason), (.report, .blockCounterpart): return true
        case (.conditions, .showExpired), (.conditions, .showSenderWithdrawn): return true
        default: return false
        }
    }

    /// Demo cases is one overlay with three variants, chosen by the screen below: 74:584 over out-pending
    /// (expired), 74:585 over in-review (expired, sender withdrawn), 74:586 over in-accepted (expired).
    func testConditionsVariantPerScreen() {
        let variants: [WaveScreen: (key: String, node: String, conditions: [WaveCondition])] = [
            .outgoingPending: ("conditions-out", "74:584", [.expired]),
            .incomingReview: ("conditions-in", "74:585", [.expired, .senderWithdrawn]),
            .incomingAccepted: ("conditions-accepted", "74:586", [.expired]),
        ]
        for intent in [BandIntent.social, .business] {
            for screen in WaveScreen.allCases {
                XCTAssertEqual(screen.conditions, variants[screen]?.conditions ?? [], "\(screen)")
                var run = WaveFixture.at(screen, intent)
                let before = run
                let id = run.wave?.invitation?.id ?? WaveInvitationID(run: run.id, sequence: 1)
                guard let variant = variants[screen] else {
                    XCTAssertFalse(run.perform(.openConditions(id)), "\(screen) has no Demo cases")
                    XCTAssertEqual(run, before)
                    continue
                }
                XCTAssertEqual(Self.ledgerOverlays[variant.key], variant.node)
                XCTAssertTrue(run.perform(.openConditions(id)), "\(screen)")
                XCTAssertEqual(WaveFixture.contextKey(run), variant.key)
                let open = run
                var withdrawn = open
                let offersWithdrawn = variant.conditions.contains(.senderWithdrawn)
                XCTAssertEqual(withdrawn.perform(.showSenderWithdrawn(id)), offersWithdrawn, "\(screen)")
                XCTAssertEqual(withdrawn.wave?.screen, offersWithdrawn ? .incomingWithdrawn : screen)
                var expired = open
                XCTAssertTrue(expired.perform(.showExpired(id)), "\(screen)")
                XCTAssertEqual(expired.wave?.screen, .unavailable)
                XCTAssertEqual(expired.wave?.invitation?.status, .unavailable)
                XCTAssertEqual(expired.wave?.overlays, [])
                var back = open
                XCTAssertTrue(back.perform(.closeOverlay(.conditions)))
                XCTAssertEqual(back, before, "Back restores the same \(screen)")
            }
        }
    }

    // MARK: - Menu starts, closing, the flow, the ended record, invalidation

    /// The menu's three starts judge the central facts at the moment of each tap, not when the Wave opened.
    func testMenuStartsRecheckEligibilityEachTime() {
        let menu = WaveDemo(counterpart: .maya, viewerName: "Alex", intent: .social, approach: .chatFirst,
                            venue: .commonGround)
        func central(active: Bool = true, populated: Bool = true, blocked: Set<RoomActor> = [],
                     intent: BandIntent = .social, venue: Venue = .commonGround) -> WaveCentral {
            WaveCentral(runID: RoomRunID(1), active: active, populated: populated, blocked: blocked, intent: intent,
                        venue: venue)
        }
        let next = WaveInvitationID(run: RoomRunID(1), sequence: 1)
        let ineligible = [("blocked", central(blocked: [.maya])), ("another intent", central(intent: .business)),
                          ("another venue", central(venue: .afterglow))]
        let inactive = [("ended", central(active: false, populated: false)), ("waiting", central(populated: false))]
        for action in [WaveAction.startOutgoing, .startIncoming, .showNoAllowance] {
            var eligible = menu
            XCTAssertTrue(eligible.apply(action, central: central(), nextID: next), "\(action)")
            XCTAssertNotEqual(eligible.screen, .blocked, "\(action)")
            for (name, facts) in ineligible {
                var attempt = menu
                XCTAssertTrue(attempt.apply(action, central: facts, nextID: next), "\(action) \(name)")
                XCTAssertEqual(attempt.screen, .blocked, "\(action) \(name): the generic blocked state")
                XCTAssertNil(attempt.invitation, "\(action) \(name): no identity")
                XCTAssertNil(attempt.visibleCounterpart)
            }
            for (name, facts) in inactive {
                var attempt = menu
                XCTAssertFalse(attempt.apply(action, central: facts, nextID: next), "\(action) \(name)")
                XCTAssertEqual(attempt, menu)
            }
        }
        // In a run: eligible when the Wave opened, then blocked from an invitation; every later round of
        // starts, however many, finds the block.
        for intent in [BandIntent.social, .business] {
            var run = WaveFixture.menu(intent)
            XCTAssertTrue(run.perform(.startIncoming))
            XCTAssertTrue(run.perform(.openSafety(from: .incomingReview)))
            XCTAssertTrue(run.perform(.blockCounterpart))
            XCTAssertTrue(run.perform(.backToMenu(from: .blocked)))
            let starts = run.waveStarts
            for round in 0..<3 {
                for action in [WaveAction.startOutgoing, .startIncoming, .showNoAllowance] {
                    XCTAssertTrue(run.perform(action), "\(intent) round \(round) \(action)")
                    XCTAssertEqual(run.wave?.screen, .blocked)
                    XCTAssertNil(run.wave?.invitation)
                    XCTAssertEqual(run.wave?.allowance, .available, "\(action): nothing but a start was judged")
                    XCTAssertTrue(run.perform(.backToMenu(from: .blocked)))
                }
            }
            XCTAssertEqual(run.waveStarts, starts, "no identity after the block")
            XCTAssertEqual(run.blocked, [WaveFixture.counterpart(intent)])
            XCTAssertTrue(run.leave())
            for action in [WaveAction.startOutgoing, .startIncoming, .showNoAllowance] {
                XCTAssertFalse(run.perform(action), "\(intent) \(action) after Leave")
            }
        }
    }

    /// Closing the Wave back to its Room caller (the menu's outer Back) happens from the bare menu only,
    /// and changes nothing of the run but the route.
    func testCloseWaveDemoOnlyFromTheMenu() {
        for intent in [BandIntent.social, .business] {
            let counterpart = WaveFixture.counterpart(intent)
            for (name, context) in WaveFixture.contexts(intent) {
                var run = context
                let bareMenu = context.wave?.screen == .menu && context.wave?.overlays == []
                XCTAssertEqual(run.closeWaveDemo(), bareMenu, "\(intent) \(name)")
                guard bareMenu else {
                    XCTAssertEqual(run, context, "\(intent) \(name)")
                    continue
                }
                XCTAssertNil(run.wave)
                XCTAssertEqual(run.id, context.id)
                XCTAssertEqual(run.phase, .populated)
                XCTAssertEqual(run.blocked, context.blocked)
                XCTAssertEqual(run.waveStarts, context.waveStarts)
                XCTAssertEqual(run.closedInvitations, context.closedInvitations)
                XCTAssertEqual(run.tab, .people)
                XCTAssertEqual(run.route, context.blocked.contains(counterpart) ? [] : [.profile(counterpart)],
                               "\(intent) \(name): the caller profile, or the filtered People")
                XCTAssertTrue(run.isConsistent)
            }
        }
        var plain = RoomFixture.populated(.social)
        plain.openProfile(.maya)
        XCTAssertFalse(plain.closeWaveDemo(), "no Wave, nothing to close")
        XCTAssertEqual(plain.acceptanceRefusal(WaveInvitationID(run: plain.id, sequence: 1)), .sameWaveID,
                       "no Wave, no current invitation: the contract's first guard refuses")
        var ended = WaveFixture.menu(.business)
        ended.leave()
        let record = ended
        XCTAssertFalse(ended.closeWaveDemo())
        XCTAssertEqual(ended, record)
    }

    /// The Wave never writes the flow or its draft: the session's flow is untouched by a whole journey, the
    /// Room and Wave values hold no flow state at all, and Return to Places keeps the draft intact.
    func testTheWaveNeverWritesTheFlowOrDraft() {
        for intent in [BandIntent.social, .business] {
            for approach in ApproachSignal.allCases {
                let flow = WaveFixture.explanation(intent, approach: approach, name: "  Sam  ")
                var session = WaveSessionMirror(flow: flow)
                XCTAssertTrue(session.previewRoomDemo())
                guard let run = session.enterRoomDemo() else { return XCTFail("no run") }
                let counterpart = WaveFixture.counterpart(intent)
                XCTAssertTrue(session.updateRoomRun(run) { $0.showPopulatedExample() && $0.openProfile(counterpart) })
                XCTAssertTrue(session.openWaveDemo(run))
                XCTAssertEqual(session.wave?.viewerName, "Sam", "the card's trimmed Guest List name")
                XCTAssertEqual(session.wave?.approach, approach)
                let journey: [(WaveDemo) -> WaveAction] = [
                    { _ in .startOutgoing }, { .send($0.invitation!.id) }, { .openConditions($0.invitation!.id) },
                    { _ in .closeOverlay(.conditions) }, { .withdraw($0.invitation!.id) },
                    { _ in .backToMenu(from: .outgoingWithdrawn) }, { _ in .startIncoming },
                    { .accept($0.invitation!.id) }, { .openChatInformation($0.invitation!.id) },
                    { _ in .closeOverlay(.chatInformation) }, { _ in .openSafety(from: .incomingAccepted) },
                    { _ in .previewReport }, { _ in .selectReportReason(.harassment) },
                    { _ in .closeOverlay(.report(.harassment)) }, { _ in .blockCounterpart },
                    { _ in .backToMenu(from: .blocked) },
                ]
                for step in journey {
                    let action = step(session.wave!)
                    XCTAssertTrue(session.performWave(run, action), "\(intent) \(approach): \(action)")
                    XCTAssertEqual(session.flow, flow, "\(action) wrote to the flow")
                }
                XCTAssertTrue(Self.holdsNoFlowState(session.room as Any), "the Room and Wave copy nothing of the flow")
                XCTAssertEqual(session.roomOuterBack(), .closedLevel, "the menu back to the filtered People")
                XCTAssertTrue(session.updateRoomRun(run) { $0.leave() })
                XCTAssertEqual(session.flow, flow)
                XCTAssertEqual(session.roomOuterBack(), .alreadyEnded, "ended: the outer Back returns to Places")
                XCTAssertNil(session.room)
                XCTAssertEqual(session.flow.currentScene, .places)
                XCTAssertEqual(session.flow.placesCategory, .now)
                XCTAssertEqual(session.flow.draft, flow.draft, "the onboarding draft is intact")
            }
        }
    }

    /// No stored value anywhere inside `value` is flow or draft state.
    private static func holdsNoFlowState(_ value: Any) -> Bool {
        Mirror(reflecting: value).children.allSatisfy { child in
            !(child.value is DemoFlow || child.value is DemoDraft || child.value is GuestIntroduction
              || child.value is IntroductionCard) && holdsNoFlowState(child.value)
        }
    }

    /// Leave keeps a record: terminal statuses stay exactly as they were, an active invitation closes as
    /// session ended (and joins the closed record), the record keeps everything before it, and nothing
    /// in the ended record can be acted on again.
    func testTheEndedRecordKeepsTerminalStatusesAndTheClosedRecord() {
        for intent in [BandIntent.social, .business] {
            let histories = WaveScreen.allCases.map {
                ("\($0.rawValue) with history", WaveFixture.at($0, intent, history: true))
            }
            for (name, context) in WaveFixture.contexts(intent) + histories where context.isActive {
                var run = context
                XCTAssertTrue(run.leave(), "\(intent) \(name)")
                XCTAssertEqual(run.wave?.screen, .sessionEnded)
                XCTAssertEqual(run.wave?.allowance, context.wave?.allowance)
                XCTAssertEqual(run.wave?.counterpart, context.wave?.counterpart)
                if let shown = context.wave?.invitation {
                    guard let ended = run.wave?.invitation else { return XCTFail("\(intent) \(name): no record") }
                    XCTAssertEqual(ended.id, shown.id)
                    XCTAssertEqual(ended.sender, shown.sender)
                    XCTAssertEqual(ended.recipient, shown.recipient)
                    XCTAssertEqual(ended.direction, shown.direction)
                    if shown.status.isTerminal {
                        XCTAssertEqual(ended, shown, "\(intent) \(name): a terminal status is kept")
                        XCTAssertEqual(run.closedInvitations, context.closedInvitations)
                    } else {
                        XCTAssertEqual(ended.status, .sessionEnded, "\(intent) \(name)")
                        XCTAssertEqual(run.closedInvitations, context.closedInvitations + [ended])
                    }
                } else {
                    XCTAssertNil(run.wave?.invitation, "\(intent) \(name)")
                    XCTAssertEqual(run.closedInvitations, context.closedInvitations)
                }
                XCTAssertTrue(run.isConsistent, "\(intent) \(name)")
                let ended = run
                for action in WaveFixture.everyAction(run) {
                    XCTAssertFalse(run.perform(action), "\(intent) \(name): \(action) after Leave")
                }
                XCTAssertFalse(run.closeWaveDemo())
                XCTAssertFalse(run.leave())
                XCTAssertEqual(run.outerBack(), .alreadyEnded)
                XCTAssertEqual(run, ended, "\(intent) \(name): nothing revives")
            }
        }
    }

    /// Callbacks that arrive after the Room preview became invalid (the explanation is gone): the session
    /// drops the Room before the domain is asked, so nothing is accepted, declined, left or revived; and a
    /// later, explicit re-entry is a new run where the old run's callbacks and invitation do nothing.
    func testWaveCallbacksAfterTheRoomPreviewIsInvalidated() {
        let invalidations: [(String, (inout DemoFlow) -> Void)] = [
            ("Back to the place", { $0.backToPlace() }),
            ("Explore other places", { $0.exploreOtherPlaces() }),
            ("a reset", { $0.reset() }),
        ]
        for (name, invalidate) in invalidations {
            var session = WaveSessionMirror(flow: WaveFixture.explanation(.business, approach: .chatFirst, name: "Sam"))
            session.previewRoomDemo()
            guard let run = session.enterRoomDemo() else { return XCTFail("no run") }
            session.updateRoomRun(run) { $0.showPopulatedExample() && $0.openProfile(.jules) }
            XCTAssertTrue(session.openWaveDemo(run))
            XCTAssertTrue(session.performWave(run, .startIncoming))
            let waveID = session.wave!.invitation!.id
            session.changeFlow(invalidate)
            for action in [WaveAction.accept(waveID), .decline(waveID), .openConditions(waveID),
                           .openSafety(from: .incomingReview), .startOutgoing] {
                XCTAssertFalse(session.performWave(run, action), "\(name): \(action)")
            }
            XCTAssertNil(session.room, "\(name): the Room is dropped, and the Wave with it")
            XCTAssertNil(session.wave)
            XCTAssertFalse(session.updateRoomRun(run) { $0.leave() })
            XCTAssertFalse(session.openWaveDemo(run))
            XCTAssertEqual(session.roomOuterBack(), .none)
            XCTAssertFalse(session.returnToPlacesFromRoom())
        }
        var session = WaveSessionMirror(flow: WaveFixture.explanation(.social, approach: .okayToSayHello, name: "Alex"))
        session.previewRoomDemo()
        guard let first = session.enterRoomDemo() else { return XCTFail("no run") }
        session.updateRoomRun(first) { $0.showPopulatedExample() && $0.openProfile(.maya) }
        session.openWaveDemo(first)
        session.performWave(first, .startIncoming)
        let old = session.wave!.invitation!.id
        session.changeFlow { $0.backToPlace() }
        XCTAssertFalse(session.performWave(first, .accept(old)))
        session.changeFlow { $0.previewCheckIn() }
        XCTAssertTrue(session.previewRoomDemo(), "re-entry is the explicit Room sequence again")
        guard let second = session.enterRoomDemo() else { return XCTFail("no second run") }
        XCTAssertNotEqual(first, second)
        XCTAssertNil(session.wave, "no Wave carries over")
        XCTAssertEqual(session.room?.run?.closedInvitations, [])
        XCTAssertFalse(session.performWave(first, .startIncoming), "the old run's callback")
        XCTAssertFalse(session.openWaveDemo(second), "waiting first")
        session.updateRoomRun(second) { $0.showPopulatedExample() && $0.openProfile(.maya) }
        XCTAssertTrue(session.openWaveDemo(second))
        XCTAssertTrue(session.performWave(second, .startIncoming))
        XCTAssertFalse(session.performWave(second, .accept(old)), "an invitation of the old run")
        XCTAssertEqual(session.wave?.screen, .incomingReview)
        XCTAssertNotEqual(session.wave?.invitation?.id, old)
    }

    /// `WaveSessionMirror` is only evidence while it says what the app says: the Room and Wave half of
    /// `DemoSession` is read as source (the app target does not compile on Linux) and its load-bearing
    /// lines are pinned here. Comments and whitespace are ignored.
    ///
    /// A native test runner (Xcode Cloud, a device) carries the built tests, not the repository, which is
    /// why the native plans skip every source-reading test (DomainSourceGuardTests, PlacesBackWiringTests).
    /// This one skips itself there too, and only there: with the package's own sources present, a
    /// missing or rewired DemoSession is a failure.
    func testTheSessionMirrorMatchesTheAppWiring() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ProximeetDomainTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ProximeetDomain
            .deletingLastPathComponent()   // repository root
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("ProximeetDomain/Package.swift").path)
        else { throw XCTSkip("No source tree on this runner; the host `swift test` reads DemoSession.swift.") }
        let url = root.appendingPathComponent("Proximeet/App/DemoSession.swift")
        let code = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[..<comment.lowerBound]
            }
            .joined(separator: "\n")
        func squeezed<S: StringProtocol>(_ text: S) -> String { String(text.filter { !$0.isWhitespace }) }
        func body(_ declaration: String) throws -> String {
            let start = try XCTUnwrap(code.range(of: declaration), "\(declaration) not found in DemoSession")
            let open = try XCTUnwrap(code[start.upperBound...].firstIndex(of: "{"))
            var depth = 0
            var index = open
            while index < code.endIndex {
                if code[index] == "{" { depth += 1 }
                if code[index] == "}" {
                    depth -= 1
                    if depth == 0 { return squeezed(code[open...index]) }
                }
                index = code.index(after: index)
            }
            XCTFail("unbalanced braces after \(declaration)")
            return ""
        }
        XCTAssertTrue(squeezed(code).contains("varwave:WaveDemo?{room?.run?.wave}"))
        let open = try body("func openWaveDemo(_ id: RoomRunID) -> Bool")
        XCTAssertTrue(open.contains("guardletname=flow.draft.introduction.card?.nameelse{returnfalse}"), open)
        XCTAssertTrue(open.contains("updateRoomRun(id){$0.openWaveDemo(viewerName:name)}"), open)
        XCTAssertEqual(try body("func performWave(_ id: RoomRunID, _ action: WaveAction) -> Bool"),
                       "{updateRoomRun(id){$0.perform(action)}}")
        XCTAssertTrue(try body("func updateRoomRun(")
            .hasPrefix("{guardreconcileRoom(),varpreview=roomelse{returnfalse}"))
        let reconcile = try body("func reconcileRoom() -> Bool")
        XCTAssertTrue(reconcile.contains("guardpreview.isStillValid(for:flow)else{room=nil"), reconcile)
        let places = try body("func returnToPlacesFromRoom() -> Bool")
        XCTAssertTrue(places.contains("guardroom?.run?.phase==.endedelse{returnfalse}"), places)
        XCTAssertTrue(places.contains("room=nilreturnflow.exploreOtherPlaces()"), places)
        let outer = try body("func roomOuterBack() -> RoomOuterBack")
        XCTAssertTrue(outer.contains("ifoutcome==.alreadyEnded{returnToPlacesFromRoom()}"), outer)
    }

    // MARK: - The handoff's own tables (validation/state-ledger.json, LAYOUT_SPEC.json)

    /// `validation/state-ledger.json` `states`, verbatim: key, id, phase, direction, fixture waveId, sender,
    /// recipient, rings and visibleActors (the reviewed fixture's names: alex is the viewer, maya the
    /// counterpart). The chrome component and the Safety destination come from `LAYOUT_SPEC.json`: each
    /// screen's chrome instance and its shield's OVERLAY reaction. Re-verified by script.
    private struct LedgerRow {
        let key: String
        let node: String
        let phase: String
        let direction: String?
        let fixtureID: String?
        let sender: String?
        let recipient: String?
        let rings: String
        let visibleActors: [String]
        let chrome: String
        let safety: String?
    }

    private static let ledger: [LedgerRow] = [
        LedgerRow(key: "demo-menu", node: "74:568", phase: "menu", direction: nil, fixtureID: nil, sender: nil,
                  recipient: nil, rings: "separate", visibleActors: ["alex"], chrome: "75:111",
                  safety: "global-safety"),
        LedgerRow(key: "out-confirm", node: "74:569", phase: "compose", direction: "outgoing",
                  fixtureID: "wave-demo-outgoing-01", sender: "alex", recipient: "maya", rings: "separate",
                  visibleActors: ["alex", "maya"], chrome: "75:119", safety: "maya-safety"),
        LedgerRow(key: "out-pending", node: "74:570", phase: "pending", direction: "outgoing",
                  fixtureID: "wave-demo-outgoing-01", sender: "alex", recipient: "maya", rings: "separate",
                  visibleActors: ["alex", "maya"], chrome: "75:111", safety: "maya-safety"),
        LedgerRow(key: "out-withdrawn", node: "74:571", phase: "invalid", direction: "outgoing",
                  fixtureID: "wave-demo-outgoing-01", sender: "alex", recipient: "maya", rings: "absent",
                  visibleActors: [], chrome: "75:111", safety: "global-safety"),
        LedgerRow(key: "in-review", node: "74:572", phase: "pending", direction: "incoming",
                  fixtureID: "wave-demo-incoming-01", sender: "maya", recipient: "alex", rings: "separate",
                  visibleActors: ["alex", "maya"], chrome: "75:111", safety: "maya-safety"),
        LedgerRow(key: "in-declined", node: "74:573", phase: "invalid", direction: "incoming",
                  fixtureID: "wave-demo-incoming-01", sender: "maya", recipient: "alex", rings: "absent",
                  visibleActors: [], chrome: "75:111", safety: "global-safety"),
        LedgerRow(key: "in-accepted", node: "74:574", phase: "accepted", direction: "incoming",
                  fixtureID: "wave-demo-incoming-01", sender: "maya", recipient: "alex", rings: "joined",
                  visibleActors: ["alex", "maya"], chrome: "75:111", safety: "maya-safety"),
        LedgerRow(key: "unavailable", node: "74:575", phase: "invalid", direction: nil, fixtureID: nil, sender: nil,
                  recipient: nil, rings: "absent", visibleActors: [], chrome: "75:111", safety: "global-safety"),
        LedgerRow(key: "blocked", node: "74:576", phase: "blocked", direction: nil, fixtureID: nil, sender: nil,
                  recipient: nil, rings: "absent", visibleActors: [], chrome: "75:111", safety: "global-safety"),
        LedgerRow(key: "allowance-unavailable", node: "74:577", phase: "unavailable", direction: nil, fixtureID: nil,
                  sender: nil, recipient: nil, rings: "absent", visibleActors: [], chrome: "75:111",
                  safety: "global-safety"),
        LedgerRow(key: "session-ended", node: "74:578", phase: "ended", direction: nil, fixtureID: nil, sender: nil,
                  recipient: nil, rings: "absent", visibleActors: [], chrome: "75:130", safety: nil),
        LedgerRow(key: "in-withdrawn", node: "74:579", phase: "invalid", direction: "incoming",
                  fixtureID: "wave-demo-incoming-01", sender: "maya", recipient: "alex", rings: "absent",
                  visibleActors: [], chrome: "75:111", safety: "global-safety"),
    ]

    /// `validation/state-ledger.json` `overlays`, verbatim.
    private static let ledgerOverlays: [String: String] = [
        "global-safety": "74:580", "maya-safety": "74:581", "report-maya": "74:582", "chat-info": "74:583",
        "conditions-out": "74:584", "conditions-in": "74:585", "conditions-accepted": "74:586",
    ]

    func testWaveScreenTablesMatchTheHandoffLedger() {
        XCTAssertEqual(Set(WaveScreen.allCases.map(\.rawValue)), Set(Self.ledger.map(\.key)), "the twelve screens")
        let chrome: [WaveChrome: String] = [.room: "75:111", .back: "75:119", .plain: "75:130"]
        let safety: [WaveOverlay: String] = [.globalSafety: "global-safety", .counterpartSafety: "maya-safety"]
        for intent in [BandIntent.social, .business] {
            let counterpart = WaveFixture.counterpart(intent)
            let names: [String: WaveParticipant] = ["alex": .viewer, "maya": .sample(counterpart)]
            for row in Self.ledger {
                guard let screen = WaveScreen(rawValue: row.key) else { XCTFail("no screen \(row.key)"); continue }
                XCTAssertEqual(screen.figmaNode, row.node, row.key)
                XCTAssertEqual("\(screen.rings)", row.rings, row.key)
                XCTAssertEqual(chrome[screen.chrome], row.chrome, row.key)
                XCTAssertEqual(screen.safety.flatMap { safety[$0] }, row.safety, row.key)
                XCTAssertEqual(screen.showsCounterpart, row.visibleActors.contains("maya"), row.key)
                XCTAssertEqual(screen.isClosed, ["invalid", "blocked", "unavailable"].contains(row.phase), row.key)

                let run = WaveFixture.at(screen, intent)
                guard let wave = run.wave else { XCTFail("\(row.key) has no Wave"); continue }
                // What the screen actually shows: the viewer's name on the menu and in the four active
                // invitations (never on a closed one), and the counterpart only while an invitation is active.
                let viewerShown = screen == .menu
                    || WaveCopy.directionLine(screen, viewer: wave.viewerName, counterpart: counterpart) != nil
                let shown = (viewerShown ? ["alex"] : []) + (wave.visibleCounterpart != nil ? ["maya"] : [])
                XCTAssertEqual(shown, row.visibleActors, "\(intent) \(row.key)")
                let invitation = wave.invitation
                switch row.phase {
                case "menu":
                    XCTAssertNil(invitation, row.key)
                case "compose", "pending", "accepted":
                    XCTAssertEqual(invitation?.status.rawValue, row.phase, row.key)
                case "invalid":
                    XCTAssertTrue([WaveStatus.withdrawn, .declined, .senderWithdrawn, .unavailable]
                        .contains(invitation?.status ?? .compose), row.key)
                case "blocked":
                    XCTAssertEqual(invitation?.status ?? .blocked, .blocked, row.key)
                case "unavailable":
                    XCTAssertNil(invitation, row.key)
                    XCTAssertEqual(wave.allowance, .unavailable, row.key)
                case "ended":
                    XCTAssertTrue(wave.ended, row.key)
                default:
                    XCTFail("unknown ledger phase \(row.phase)")
                }
                if let direction = row.direction, let sender = row.sender, let recipient = row.recipient {
                    XCTAssertEqual(invitation?.direction.rawValue, direction, "\(intent) \(row.key)")
                    XCTAssertEqual(invitation?.sender, names[sender], "\(intent) \(row.key)")
                    XCTAssertEqual(invitation?.recipient, names[recipient], "\(intent) \(row.key)")
                } else {
                    XCTAssertNil(WaveCopy.directionLine(screen, viewer: "Alex", counterpart: counterpart),
                                 "\(row.key) names no direction")
                }
            }
            // One fixture identity per direction: the same ID from its start through every later screen of
            // that example, and a different one for the other direction.
            var run = WaveFixture.menu(intent)
            run.perform(.startOutgoing)
            let outgoing = run.wave!.invitation!.id
            run.perform(.send(outgoing))
            XCTAssertEqual(run.wave?.invitation?.id, outgoing, "out-confirm and out-pending share one ID")
            run.perform(.withdraw(outgoing))
            XCTAssertEqual(run.wave?.invitation?.id, outgoing, "and out-withdrawn")
            run.perform(.backToMenu(from: .outgoingWithdrawn))
            run.perform(.startIncoming)
            let incoming = run.wave!.invitation!.id
            XCTAssertNotEqual(incoming, outgoing, "wave-demo-incoming-01 is not wave-demo-outgoing-01")
            for (screen, reach) in [(WaveScreen.incomingAccepted, [WaveAction.accept(incoming)]),
                                    (.incomingDeclined, [.decline(incoming)]),
                                    (.incomingWithdrawn, [.openConditions(incoming), .showSenderWithdrawn(incoming)])] {
                var branch = run
                for action in reach { branch.perform(action) }
                XCTAssertEqual(branch.wave?.screen, screen)
                XCTAssertEqual(branch.wave?.invitation?.id, incoming, "\(screen) keeps the in-review ID")
            }
        }
        // The seven overlays: each Figma overlay is one reachable domain context.
        var reached: Set<String> = []
        for (_, context) in WaveFixture.contexts(.social) where context.wave?.overlay != nil {
            reached.insert(WaveFixture.contextKey(context))
        }
        XCTAssertEqual(reached, Set(Self.ledgerOverlays.keys))
    }

    /// Every reaction of the approved graph (`LAYOUT_SPEC.json`; `graphEvidence.routeCount` 74 = 41 screen +
    /// 23 overlay + 9 report-variant + 1 integration route) as (from, control node, domain action, to).
    /// "caller" is a CLOSE with no destination: the level below. The integration reference's shortcut
    /// 75:212 → 74:568 is Figma-only and, as the handoff orders, not implemented. Re-verified by script.
    private static let routes: [(from: String, control: String, action: String, to: String)] = [
        ("demo-menu", "I75:276;75:115", "safety", "global-safety"),
        ("demo-menu", "75:295", "startOutgoing", "out-confirm"),
        ("demo-menu", "75:298", "startIncoming", "in-review"),
        ("demo-menu", "75:301", "showNoAllowance", "allowance-unavailable"),
        ("demo-menu", "75:304", "leave", "session-ended"),
        ("out-confirm", "I75:307;75:120", "back", "demo-menu"),
        ("out-confirm", "I75:307;75:126", "safety", "maya-safety"),
        ("out-confirm", "75:341", "send", "out-pending"),
        ("out-confirm", "75:344", "leave", "session-ended"),
        ("out-pending", "I75:347;75:115", "safety", "maya-safety"),
        ("out-pending", "75:363", "demoCases", "conditions-out"),
        ("out-pending", "75:380", "withdraw", "out-withdrawn"),
        ("out-pending", "75:383", "leave", "session-ended"),
        ("out-withdrawn", "I75:467;75:115", "safety", "global-safety"),
        ("out-withdrawn", "75:485", "backToMenu", "demo-menu"),
        ("out-withdrawn", "75:488", "leave", "session-ended"),
        ("in-review", "I75:386;75:115", "safety", "maya-safety"),
        ("in-review", "75:402", "demoCases", "conditions-in"),
        ("in-review", "75:419", "accept", "in-accepted"),
        ("in-review", "75:422", "decline", "in-declined"),
        ("in-review", "75:425", "leave", "session-ended"),
        ("in-declined", "I75:491;75:115", "safety", "global-safety"),
        ("in-declined", "75:509", "backToMenu", "demo-menu"),
        ("in-declined", "75:512", "leave", "session-ended"),
        ("in-accepted", "I75:428;75:115", "safety", "maya-safety"),
        ("in-accepted", "75:444", "demoCases", "conditions-accepted"),
        ("in-accepted", "75:461", "aboutChat", "chat-info"),
        ("in-accepted", "75:464", "leave", "session-ended"),
        ("unavailable", "I75:515;75:115", "safety", "global-safety"),
        ("unavailable", "75:533", "backToMenu", "demo-menu"),
        ("unavailable", "75:536", "leave", "session-ended"),
        ("blocked", "I75:539;75:115", "safety", "global-safety"),
        ("blocked", "75:557", "backToMenu", "demo-menu"),
        ("blocked", "75:560", "leave", "session-ended"),
        ("allowance-unavailable", "I75:563;75:115", "safety", "global-safety"),
        ("allowance-unavailable", "75:581", "backToMenu", "demo-menu"),
        ("allowance-unavailable", "75:584", "leave", "session-ended"),
        ("session-ended", "75:600", "returnToPlaces", "75:212"),
        ("in-withdrawn", "I75:603;75:115", "safety", "global-safety"),
        ("in-withdrawn", "75:621", "backToMenu", "demo-menu"),
        ("in-withdrawn", "75:624", "leave", "session-ended"),
        ("global-safety", "75:680", "close", "caller"),
        ("global-safety", "75:683", "leave", "session-ended"),
        ("maya-safety", "75:689", "block", "blocked"),
        ("maya-safety", "75:692", "previewReport", "report-maya"),
        ("maya-safety", "75:695", "close", "caller"),
        ("maya-safety", "75:698", "leave", "session-ended"),
        ("report-maya", "I75:704;75:628", "reason.unwantedAttention", "75:637"),
        ("report-maya", "I75:704;75:631", "reason.harassment", "75:647"),
        ("report-maya", "I75:704;75:634", "reason.somethingElse", "75:657"),
        ("report-maya", "75:714", "close", "caller"),
        ("report-maya", "75:717", "leave", "session-ended"),
        ("chat-info", "75:723", "close", "caller"),
        ("chat-info", "75:726", "leave", "session-ended"),
        ("conditions-out", "75:732", "showExpired", "unavailable"),
        ("conditions-out", "75:735", "close", "caller"),
        ("conditions-out", "75:738", "leave", "session-ended"),
        ("conditions-in", "75:744", "showExpired", "unavailable"),
        ("conditions-in", "75:747", "showSenderWithdrawn", "in-withdrawn"),
        ("conditions-in", "75:750", "close", "caller"),
        ("conditions-in", "75:753", "leave", "session-ended"),
        ("conditions-accepted", "75:759", "showExpired", "unavailable"),
        ("conditions-accepted", "75:762", "close", "caller"),
        ("conditions-accepted", "75:765", "leave", "session-ended"),
        ("75:627", "75:628", "reason.unwantedAttention", "75:637"),
        ("75:627", "75:631", "reason.harassment", "75:647"),
        ("75:627", "75:634", "reason.somethingElse", "75:657"),
        ("75:637", "75:641", "reason.harassment", "75:647"),
        ("75:637", "75:644", "reason.somethingElse", "75:657"),
        ("75:647", "75:648", "reason.unwantedAttention", "75:637"),
        ("75:647", "75:654", "reason.somethingElse", "75:657"),
        ("75:657", "75:658", "reason.unwantedAttention", "75:637"),
        ("75:657", "75:661", "reason.harassment", "75:647"),
        ("75:212", "75:218", "placesShortcut", "demo-menu"),
    ]

    /// Each approved route is exactly one domain transition, from every context the design draws it on,
    /// for both intents; and the rings join on one edge only, the recipient's Accept (75:419).
    func testEveryApprovedRouteIsOneDomainTransition() {
        XCTAssertEqual(Self.routes.count, 74, "graphEvidence.routeCount")
        for intent in [BandIntent.social, .business] {
            for route in Self.routes {
                if route.action == "placesShortcut" {
                    var places = WaveFixture.explanation(intent, approach: .chatFirst, name: "Alex")
                    places.exploreOtherPlaces()
                    XCTAssertNil(RoomPreview.open(after: places), "Places never opens the Room or the Wave directly")
                    continue
                }
                let starts = Self.contexts(for: route.from, intent)
                XCTAssertFalse(starts.isEmpty, "\(route.from) is reachable")
                for start in starts {
                    var run = start
                    let label = "\(intent) \(route.from) \(route.control) \(route.action)"
                    if route.action == "returnToPlaces" {
                        // The session's Return to Places needs exactly this: an ended run (see
                        // testTheWaveNeverWritesTheFlowOrDraft for the whole way out).
                        XCTAssertEqual(run.phase, .ended, label)
                        XCTAssertEqual(run.outerBack(), .alreadyEnded, label)
                        continue
                    }
                    XCTAssertTrue(Self.follow(route.action, in: &run), label)
                    let expected = route.to == "caller" ? Self.callerKey(of: start) : route.to
                    let reached = expected.hasPrefix("75:") ? WaveFixture.variantKey(run) : WaveFixture.contextKey(run)
                    XCTAssertEqual(reached, expected, label)
                    XCTAssertTrue(run.isConsistent, label)
                    let joined = start.wave?.screen.rings == .separate && run.wave?.screen.rings == .joined
                    XCTAssertEqual(joined, route.control == "75:419", "\(label): the only SMART_ANIMATE edge")
                }
            }
        }
    }

    /// Every context the approved graph draws `key` on: a screen, an overlay over each of its callers, or a
    /// report-reason variant over each counterpart safety.
    private static func contexts(for key: String, _ intent: BandIntent) -> [RoomRun] {
        if let screen = WaveScreen(rawValue: key) { return [WaveFixture.at(screen, intent)] }
        let variants = ["75:627": RoomReportReason?.none, "75:637": .unwantedAttention, "75:647": .harassment,
                        "75:657": .somethingElse]
        let all = WaveFixture.contexts(intent).map(\.run)
        if let reason = variants[key] {
            return all.filter { $0.wave?.overlay == .report(reason) }
        }
        return all.filter { WaveFixture.contextKey($0) == key && WaveFixture.variantKey($0) ?? "75:627" == "75:627" }
    }

    private static func callerKey(of run: RoomRun) -> String {
        guard let wave = run.wave else { return "room" }
        if case .report? = wave.overlay { return "maya-safety" }
        return wave.screen.rawValue
    }

    /// The domain action behind one Figma control, drawn for what `run` shows now.
    private static func follow(_ action: String, in run: inout RoomRun) -> Bool {
        guard let wave = run.wave else { return false }
        let id = wave.invitation?.id ?? WaveInvitationID(run: run.id, sequence: 0)
        switch action {
        case "safety": return run.perform(.openSafety(from: wave.screen))
        case "startOutgoing": return run.perform(.startOutgoing)
        case "startIncoming": return run.perform(.startIncoming)
        case "showNoAllowance": return run.perform(.showNoAllowance)
        case "leave": return run.leave()
        case "back": return run.perform(.discardCompose(id))
        case "send": return run.perform(.send(id))
        case "withdraw": return run.perform(.withdraw(id))
        case "accept": return run.perform(.accept(id))
        case "decline": return run.perform(.decline(id))
        case "demoCases": return run.perform(.openConditions(id))
        case "aboutChat": return run.perform(.openChatInformation(id))
        case "showExpired": return run.perform(.showExpired(id))
        case "showSenderWithdrawn": return run.perform(.showSenderWithdrawn(id))
        case "backToMenu": return run.perform(.backToMenu(from: wave.screen))
        case "block": return run.perform(.blockCounterpart)
        case "previewReport": return run.perform(.previewReport)
        case "close":
            guard let top = wave.overlay else { return false }
            return run.perform(.closeOverlay(top))
        default:
            guard action.hasPrefix("reason."),
                  let reason = RoomReportReason(rawValue: String(action.dropFirst("reason.".count)))
            else { return false }
            return run.perform(.selectReportReason(reason))
        }
    }

    // MARK: - Every approved string

    /// The reviewed fixture's text (viewer Alex · Social · Chat first, counterpart Maya): one row per
    /// distinct approved string of `LAYOUT_SPEC.json` (its 183 text nodes in the twelve screens, seven
    /// overlays and four report variants hold 78 distinct strings), keyed by the string's first node.
    /// "DEMO" (I75:276;75:114) is the only one not here: it is the Room's shared DEMO badge in the app.
    /// Re-verified by script against LAYOUT_SPEC.json, character for character.
    private static let approvedAlexSocial: [(node: String, text: String)] = [
        ("I75:276;75:112", "Proximeet"),
        ("75:285", "Every hello\nneeds a choice."),
        ("75:286", "You are Alex in both examples."),
        ("75:294", "Choose a new, independent demo.\nNo invitation is sent to anyone."),
        ("75:296", "Start outgoing example"),
        ("75:299", "Start incoming example"),
        ("75:302", "Show no-allowance example"),
        ("75:305", "Leave and disappear"),
        ("I75:307;75:123", "Wave"),
        ("I75:320;75:136", "Common Ground"),
        ("I75:320;75:137", "Demo session · until 10 pm"),
        ("I75:320;75:138", "Alex · Social · Chat first"),
        ("75:326", "OUTGOING · YOU ARE ALEX"),
        ("I75:327;75:163", "ALEX → MAYA · OUTGOING"),
        ("I75:327;75:164", "Send a little hello."),
        ("I75:327;75:165", "A Wave invites a conversation.\nMaya chooses whether to accept."),
        ("I75:327;75:166", "Social · Chat first"),
        ("75:340", "Wave allowance available in this demo.\nNothing is sent."),
        ("75:342", "Send demo Wave"),
        ("75:364", "Demo cases"),
        ("I75:366;75:177", "Waiting for Maya."),
        ("I75:366;75:178", "Only Maya can accept.\nYou can withdraw at any time."),
        ("75:379", "This is your outgoing invitation.\nNothing is sent."),
        ("75:381", "Withdraw Wave"),
        ("I75:476;75:210", "AN INVITATION"),
        ("I75:476;75:211", "There is always room to choose."),
        ("75:482", "Wave\nwithdrawn."),
        ("75:483", "This outgoing example is closed.\nIt cannot open a chat."),
        ("75:484", "Demo state · no active invitation."),
        ("75:486", "Back to demo menu"),
        ("75:401", "INCOMING · YOU ARE ALEX"),
        ("I75:405;75:189", "MAYA → ALEX · INCOMING"),
        ("I75:405;75:190", "An invitation for you."),
        ("I75:405;75:191", "Accept only if you want to.\nNo explanation needed to decline."),
        ("75:418", "A separate incoming example.\nNothing is sent."),
        ("75:420", "Accept Wave"),
        ("75:423", "Decline Wave"),
        ("75:506", "Your choice.\nNo pressure."),
        ("75:507", "This incoming Wave is declined and closed.\nNo explanation needed."),
        ("I75:447;75:202", "MAYA + ALEX · INCOMING DEMO"),
        ("I75:447;75:203", "You both said yes."),
        ("I75:447;75:204", "A temporary private chat\ncan open next."),
        ("75:460", "Both agreed to a temporary chat in this demo.\nChat and Keep come next."),
        ("75:462", "About private chat"),
        ("75:530", "Wave\nunavailable."),
        ("75:531", "This example expired or the session\nis no longer eligible."),
        ("75:554", "Connection\nblocked."),
        ("75:555", "The other person’s sample card and invitation\nare hidden in this demo."),
        ("75:578", "No Wave\nallowance."),
        ("75:579", "No Wave allowance in this example.\nThis demo does not define a production quota."),
        ("75:597", "You’ve left\nthe room."),
        ("75:598", "The demo session is ended.\nNo active invitation or chat remains."),
        ("75:601", "Return to Places"),
        ("75:618", "Invitation\nwithdrawn."),
        ("75:619", "The sender withdrew this invitation.\nAccept is no longer available."),
        ("75:677", "DEMO PREVIEW"),
        ("75:678", "Your choice\ncomes first."),
        ("75:679", "You can leave at any time. Demo reports stay local, and no invitation is sent to anyone."),
        ("75:681", "Close"),
        ("75:687", "Maya · safety"),
        ("75:688", "Blocking hides this fictional person’s card and invitation from the current example."),
        ("75:690", "Block Maya in demo"),
        ("75:693", "Preview report"),
        ("75:696", "Back"),
        ("75:702", "Report Maya"),
        ("75:703", "Choose a sample reason.\nExample only — nothing is submitted."),
        ("I75:704;75:629", "Unwanted attention"),
        ("I75:704;75:632", "Harassment or harmful content"),
        ("I75:704;75:635", "Something else"),
        ("75:715", "Close preview"),
        ("75:721", "A private chat.\nBy mutual choice."),
        ("75:722", "Both people have agreed in this incoming demo. Private Chat and Keep are the next chapter."),
        ("75:729", "DEMO REVIEW CONTROLS"),
        ("75:730", "Try a closed\nexample."),
        ("75:731", "These controls choose static demo conditions. No timer or real session is running."),
        ("75:733", "Show expired example"),
        ("75:748", "Show sender withdrawn"),
    ]

    /// The same nodes for Business, whose counterpart is Jules (WAVE_DEMO_CONTRACT `counterpartMapping`), with
    /// a viewer called Sam who chose Chat first while Jules is Okay to say hello: the viewer's own values on
    /// the ticket, the counterpart's own on the invitation, never a claimed shared approach. Only these
    /// nodes differ from the Social table.
    private static let businessSamChanges: [String: String] = [
        "75:286": "You are Sam in both examples.",
        "I75:320;75:138": "Sam · Business · Chat first",
        "75:326": "OUTGOING · YOU ARE SAM",
        "I75:327;75:163": "SAM → JULES · OUTGOING",
        "I75:327;75:165": "A Wave invites a conversation.\nJules chooses whether to accept.",
        "I75:327;75:166": "Business · Okay to say hello",
        "I75:366;75:177": "Waiting for Jules.",
        "I75:366;75:178": "Only Jules can accept.\nYou can withdraw at any time.",
        "75:401": "INCOMING · YOU ARE SAM",
        "I75:405;75:189": "JULES → SAM · INCOMING",
        "I75:447;75:202": "JULES + SAM · INCOMING DEMO",
        "75:687": "Jules · safety",
        "75:690": "Block Jules in demo",
        "75:702": "Report Jules",
    ]

    /// What the domain renders for each of those nodes, from a real Wave of that run.
    private static func rendered(viewer: String, intent: BandIntent, approach: ApproachSignal) -> [String: String] {
        var run = RoomFixture.populated(intent, approach: approach)
        run.openProfile(WaveFixture.counterpart(intent))
        run.openWaveDemo(viewerName: viewer)
        guard let wave = run.wave else { return [:] }
        let name = wave.viewerName
        let them = wave.counterpart
        func lines(_ value: [String]?) -> String? { value?.joined(separator: "\n") }
        let values: [(String, String?)] = [
            ("I75:276;75:112", WaveCopy.brand),
            ("75:285", lines(WaveCopy.menuHeadline)),
            ("75:286", WaveCopy.roleExplanation(viewer: name)),
            ("75:294", WaveCopy.menuBoundary),
            ("75:296", WaveCopy.startOutgoing),
            ("75:299", WaveCopy.startIncoming),
            ("75:302", WaveCopy.showNoAllowance),
            ("75:305", WaveCopy.leave),
            ("I75:307;75:123", WaveCopy.composeBrand),
            ("I75:320;75:136", wave.venue.name),
            ("I75:320;75:137", WaveCopy.session),
            ("I75:320;75:138", WaveCopy.viewerPreference(viewer: name, intent: wave.intent, approach: wave.approach)),
            ("75:326", WaveCopy.stateContext(.outgoing, viewer: name)),
            ("I75:327;75:163", WaveCopy.directionLine(.outgoingConfirm, viewer: name, counterpart: them)),
            ("I75:327;75:164", WaveCopy.invitationTitle(.outgoingConfirm, counterpart: them)),
            ("I75:327;75:165", WaveCopy.invitationPurpose(.outgoingConfirm, counterpart: them)),
            ("I75:327;75:166", them.line),
            ("75:340", WaveCopy.boundary(.outgoingConfirm)),
            ("75:342", WaveCopy.send),
            ("75:364", WaveCopy.demoCases),
            ("I75:366;75:177", WaveCopy.invitationTitle(.outgoingPending, counterpart: them)),
            ("I75:366;75:178", WaveCopy.invitationPurpose(.outgoingPending, counterpart: them)),
            ("75:379", WaveCopy.boundary(.outgoingPending)),
            ("75:381", WaveCopy.withdraw),
            ("I75:476;75:210", WaveCopy.closedLabel),
            ("I75:476;75:211", WaveCopy.closedChoice),
            ("75:482", lines(WaveCopy.closedHeadline(.outgoingWithdrawn))),
            ("75:483", WaveCopy.closedExplanation(.outgoingWithdrawn)),
            ("75:484", WaveCopy.closedBoundary),
            ("75:486", WaveCopy.backToMenu),
            ("75:401", WaveCopy.stateContext(.incoming, viewer: name)),
            ("I75:405;75:189", WaveCopy.directionLine(.incomingReview, viewer: name, counterpart: them)),
            ("I75:405;75:190", WaveCopy.invitationTitle(.incomingReview, counterpart: them)),
            ("I75:405;75:191", WaveCopy.invitationPurpose(.incomingReview, counterpart: them)),
            ("75:418", WaveCopy.boundary(.incomingReview)),
            ("75:420", WaveCopy.accept),
            ("75:423", WaveCopy.decline),
            ("75:506", lines(WaveCopy.closedHeadline(.incomingDeclined))),
            ("75:507", WaveCopy.closedExplanation(.incomingDeclined)),
            ("I75:447;75:202", WaveCopy.directionLine(.incomingAccepted, viewer: name, counterpart: them)),
            ("I75:447;75:203", WaveCopy.invitationTitle(.incomingAccepted, counterpart: them)),
            ("I75:447;75:204", WaveCopy.invitationPurpose(.incomingAccepted, counterpart: them)),
            ("75:460", WaveCopy.boundary(.incomingAccepted)),
            ("75:462", WaveCopy.aboutPrivateChat),
            ("75:530", lines(WaveCopy.closedHeadline(.unavailable))),
            ("75:531", WaveCopy.closedExplanation(.unavailable)),
            ("75:554", lines(WaveCopy.closedHeadline(.blocked))),
            ("75:555", WaveCopy.closedExplanation(.blocked)),
            ("75:578", lines(WaveCopy.closedHeadline(.allowanceUnavailable))),
            ("75:579", WaveCopy.closedExplanation(.allowanceUnavailable)),
            ("75:597", lines(WaveCopy.closedHeadline(.sessionEnded))),
            ("75:598", WaveCopy.closedExplanation(.sessionEnded)),
            ("75:601", WaveCopy.returnToPlaces),
            ("75:618", lines(WaveCopy.closedHeadline(.incomingWithdrawn))),
            ("75:619", WaveCopy.closedExplanation(.incomingWithdrawn)),
            ("75:677", WaveCopy.previewLabel),
            ("75:678", lines(WaveCopy.safetyTitle)),
            ("75:679", WaveCopy.safetyExplanation),
            ("75:681", WaveCopy.close),
            ("75:687", WaveCopy.counterpartSafetyTitle(them)),
            ("75:688", WaveCopy.counterpartSafetyExplanation),
            ("75:690", WaveCopy.block(them)),
            ("75:693", WaveCopy.previewReport),
            ("75:696", WaveCopy.back),
            ("75:702", WaveCopy.reportTitle(them)),
            ("75:703", WaveCopy.reportExplanation),
            ("I75:704;75:629", RoomReportReason.unwantedAttention.title),
            ("I75:704;75:632", RoomReportReason.harassment.title),
            ("I75:704;75:635", RoomReportReason.somethingElse.title),
            ("75:715", WaveCopy.closePreview),
            ("75:721", lines(WaveCopy.chatTitle)),
            ("75:722", WaveCopy.chatExplanation),
            ("75:729", WaveCopy.controlsLabel),
            ("75:730", lines(WaveCopy.conditionsTitle)),
            ("75:731", WaveCopy.conditionsExplanation),
            ("75:733", WaveCopy.showExpired),
            ("75:748", WaveCopy.showSenderWithdrawn),
        ]
        var result: [String: String] = [:]
        for (node, value) in values { result[node] = value ?? "<nil>" }
        return result
    }

    func testEveryApprovedStringExactly() {
        let social = Dictionary(uniqueKeysWithValues: Self.approvedAlexSocial.map { ($0.node, $0.text) })
        XCTAssertEqual(social.count, 77, "78 distinct approved strings, less the app's DEMO badge")
        let business = social.merging(Self.businessSamChanges) { _, new in new }
        XCTAssertEqual(Set(Self.businessSamChanges.keys).subtracting(social.keys), [],
                       "Business changes only known nodes")
        for (name, rendered, approved) in [
            ("Social", Self.rendered(viewer: "Alex", intent: .social, approach: .chatFirst), social),
            ("Business", Self.rendered(viewer: " Sam\n", intent: .business, approach: .chatFirst), business),
        ] {
            XCTAssertEqual(Set(rendered.keys), Set(approved.keys), name)
            for (node, text) in approved {
                XCTAssertEqual(rendered[node], text, "\(name) \(node)")
                if let value = rendered[node] {
                    XCTAssertEqual(value.components(separatedBy: "\n").count, text.components(separatedBy: "\n").count,
                                   "\(name) \(node): line breaks")
                    XCTAssertFalse(value.contains("'"), "\(name) \(node): a typewriter apostrophe")
                }
            }
            let names = name == "Social" ? ["Jules", "JULES", "Sam", "SAM"] : ["Maya", "MAYA", "Alex", "ALEX"]
            for (node, value) in rendered {
                for other in names { XCTAssertFalse(value.contains(other), "\(name) \(node) shows \(other)") }
            }
        }
        // The typographic characters, by scalar: ’ U+2019, — U+2014, → U+2192, · U+00B7.
        let scalars = Set(Self.rendered(viewer: "Alex", intent: .social, approach: .chatFirst).values
            .flatMap(\.unicodeScalars).filter { !$0.isASCII }.map(\.value))
        XCTAssertEqual(scalars, [0x2019, 0x2014, 0x2192, 0x00B7])
        XCTAssertEqual(social["75:597"].map { Array($0.unicodeScalars.map(\.value).prefix(6)) },
                       [0x59, 0x6F, 0x75, 0x2019, 0x76, 0x65], "You’ve")
        // The uppercase lines use the actual name, uppercased as written; the sentence lines keep it as typed.
        XCTAssertEqual(WaveCopy.stateContext(.incoming, viewer: "Zoë"), "INCOMING · YOU ARE ZOË")
        XCTAssertEqual(WaveCopy.directionLine(.incomingAccepted, viewer: "Zoë", counterpart: .jules),
                       "JULES + ZOË · INCOMING DEMO")
        XCTAssertEqual(WaveCopy.roleExplanation(viewer: "Zoë"), "You are Zoë in both examples.")
        // Per-screen copy exists exactly where the design draws it.
        for screen in WaveScreen.allCases {
            XCTAssertEqual(WaveCopy.directionLine(screen, viewer: "Alex", counterpart: .maya) != nil,
                           screen.showsCounterpart, "\(screen)")
            XCTAssertEqual(WaveCopy.invitationTitle(screen, counterpart: .maya) != nil, screen.showsCounterpart)
            XCTAssertEqual(WaveCopy.invitationPurpose(screen, counterpart: .maya) != nil, screen.showsCounterpart)
            XCTAssertEqual(WaveCopy.boundary(screen) != nil, screen.showsCounterpart)
            XCTAssertEqual(WaveCopy.closedHeadline(screen) != nil, screen.isClosed || screen == .sessionEnded)
            XCTAssertEqual(WaveCopy.closedExplanation(screen) != nil, screen.isClosed || screen == .sessionEnded)
        }
        // Shared with the Room where the words are the same; the Wave's own where the design differs.
        XCTAssertEqual(WaveCopy.leave, RoomCopy.leave)
        XCTAssertEqual(WaveCopy.returnToPlaces, RoomCopy.returnToPlaces)
        XCTAssertEqual(WaveCopy.reportExplanation, RoomCopy.reportExplanation)
        XCTAssertEqual(WaveCopy.session, RoomCopy.compactSession)
        XCTAssertNotEqual(WaveCopy.safetyTitle, RoomCopy.safetyTitle, "Wave's own safety title (74:580)")
        XCTAssertNotEqual(WaveCopy.counterpartSafetyExplanation, RoomCopy.actorSafetyExplanation)
    }

    // MARK: - Invariants under any sequence

    func testEveryWaveSequenceStaysConsistent() {
        var generator = WaveSplitMix(seed: 0x57415645)
        var visited: Set<WaveScreen> = []
        var overlaysSeen: Set<Int> = []
        var closedSeen: Set<WaveStatus> = []
        for intent in [BandIntent.social, .business] {
            for approach in ApproachSignal.allCases {
                for sequence in 0..<60 {
                    // Most sequences start on the Wave menu; some start on People and must find it.
                    var run = sequence % 4 == 0 ? RoomFixture.populated(intent, approach: approach)
                        : WaveFixture.menu(intent, approach: approach)
                    var issued: [WaveInvitationID] = []
                    var lastStatus: [WaveInvitationID: WaveStatus] = [:]
                    var retired: Set<WaveInvitationID> = []
                    var previousBlocks = run.blocked
                    var previousCurrent: WaveInvitationID?
                    for _ in 0..<160 {
                        let before = run
                        WaveFixture.randomStep(&run, issued: issued, generator: &generator)
                        XCTAssertTrue(run.isConsistent, "\(run)")
                        XCTAssertTrue(run.closedInvitations.starts(with: before.closedInvitations),
                                      "the closed record is append-only")
                        if before.wave?.screen.rings == .separate, run.wave?.screen.rings == .joined {
                            XCTAssertEqual(before.wave?.screen, .incomingReview, "rings join only by Accept")
                            XCTAssertEqual(run.wave?.screen, .incomingAccepted)
                        }
                        XCTAssertTrue(previousBlocks.isSubset(of: run.blocked), "blocks only grow")
                        previousBlocks = run.blocked
                        if before.phase == .ended { XCTAssertEqual(run, before, "nothing revives an ended run") }
                        let current = run.wave?.invitation
                        if let current {
                            XCTAssertFalse(retired.contains(current.id), "a replaced identity never returns")
                            if !issued.contains(current.id) {
                                XCTAssertGreaterThan(current.id.sequence, issued.last?.sequence ?? 0)
                                issued.append(current.id)
                            }
                            if let old = lastStatus[current.id] {
                                XCTAssertTrue(WaveFixture.isLegal(old, current.status, current.direction),
                                              "\(old) → \(current.status)")
                            }
                            lastStatus[current.id] = current.status
                            if current.status == .accepted {
                                XCTAssertEqual(current.direction, .incoming)
                                XCTAssertEqual(current.recipient, .viewer)
                            }
                        }
                        if let previousCurrent, previousCurrent != current?.id { retired.insert(previousCurrent) }
                        previousCurrent = current?.id
                        closedSeen.formUnion(run.closedInvitations.map(\.status))
                        if let wave = run.wave {
                            visited.insert(wave.screen)
                            if let top = wave.overlay { overlaysSeen.insert(top.kind) }
                            XCTAssertEqual(wave.screen.rings == .joined, wave.screen == .incomingAccepted)
                            if run.blocked.contains(wave.counterpart) { XCTAssertNil(wave.visibleCounterpart) }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(visited, Set(WaveScreen.allCases), "the sequences reach every approved screen")
        XCTAssertEqual(overlaysSeen, [0, 1, 2, 3, 4], "and every overlay")
        XCTAssertEqual(closedSeen, Set(WaveStatus.allCases.filter(\.isTerminal)),
                       "and closes with every terminal status")
    }

    /// Every stored-property label inside `value`, recursively. Unlabelled children (the elements of an
    /// array or a set) are searched too, so the closed record's invitations meet the same words as the
    /// invitation on screen.
    private static func propertyNames(of value: Any) -> [String] {
        Mirror(reflecting: value).children.flatMap { child -> [String] in
            (child.label.map { [$0] } ?? []) + propertyNames(of: child.value)
        }
    }
}

private extension RoomRun {
    func openingWave() -> Bool {
        var copy = self
        return copy.openWaveDemo(viewerName: "Alex")
    }
}

/// Wave states reached only through the real transitions.
enum WaveFixture {
    static func counterpart(_ intent: BandIntent) -> RoomActor { intent == .social ? .maya : .jules }

    static func menu(_ intent: BandIntent, approach: ApproachSignal = .chatFirst, name: String = "Alex",
                     preblock: [RoomActor] = []) -> RoomRun {
        var run = RoomFixture.populated(intent, approach: approach)
        for actor in preblock { RoomFixture.block(actor, in: &run) }
        guard run.openProfile(counterpart(intent)), run.openWaveDemo(viewerName: name) else {
            preconditionFailure("\(intent) cannot open the Wave")
        }
        return run
    }

    /// `history` first closes one outgoing example (sent, then withdrawn) and returns to the menu, so the
    /// state is reached with something already in the run's closed record.
    static func at(_ screen: WaveScreen, _ intent: BandIntent, preblock: [RoomActor] = [],
                   history: Bool = false) -> RoomRun {
        var run = menu(intent, preblock: preblock)
        func id() -> WaveInvitationID { run.wave!.invitation!.id }
        if history {
            run.perform(.startOutgoing); run.perform(.send(id())); run.perform(.withdraw(id()))
            run.perform(.backToMenu(from: .outgoingWithdrawn))
            precondition(run.closedInvitations.count == 1 && run.wave?.screen == .menu, "no history")
        }
        switch screen {
        case .menu: break
        case .outgoingConfirm: run.perform(.startOutgoing)
        case .outgoingPending: run.perform(.startOutgoing); run.perform(.send(id()))
        case .outgoingWithdrawn: run.perform(.startOutgoing); run.perform(.send(id())); run.perform(.withdraw(id()))
        case .incomingReview: run.perform(.startIncoming)
        case .incomingAccepted: run.perform(.startIncoming); run.perform(.accept(id()))
        case .incomingDeclined: run.perform(.startIncoming); run.perform(.decline(id()))
        case .incomingWithdrawn:
            run.perform(.startIncoming); run.perform(.openConditions(id())); run.perform(.showSenderWithdrawn(id()))
        case .unavailable:
            run.perform(.startIncoming); run.perform(.openConditions(id())); run.perform(.showExpired(id()))
        case .blocked:
            run.perform(.startOutgoing); run.perform(.openSafety(from: .outgoingConfirm)); run.perform(.blockCounterpart)
        case .allowanceUnavailable: run.perform(.showNoAllowance)
        case .sessionEnded: run.leave()
        }
        precondition(run.wave?.screen == screen, "\(screen) not reached")
        return run
    }

    /// The overlays the approved design opens on `screen`.
    static func overlays(on screen: WaveScreen) -> [WaveOverlay] {
        var result: [WaveOverlay] = []
        if let safety = screen.safety { result.append(safety) }
        if !screen.conditions.isEmpty { result.append(.conditions) }
        if screen == .incomingAccepted { result.append(.chatInformation) }
        return result
    }

    @discardableResult
    static func open(_ overlay: WaveOverlay, on screen: WaveScreen, in run: inout RoomRun) -> Bool {
        let id = run.wave?.invitation?.id ?? WaveInvitationID(run: run.id, sequence: 0)
        switch overlay {
        case .globalSafety, .counterpartSafety:
            guard screen.safety == overlay else { return false }
            return run.perform(.openSafety(from: screen))
        case .conditions: return run.perform(.openConditions(id))
        case .chatInformation: return run.perform(.openChatInformation(id))
        case .report: return run.perform(.previewReport)
        }
    }

    static func invitationActions(_ id: WaveInvitationID) -> [WaveAction] {
        [.discardCompose(id), .send(id), .withdraw(id), .accept(id), .decline(id), .openConditions(id),
         .showExpired(id), .showSenderWithdrawn(id), .openChatInformation(id)]
    }

    /// Every control a guest could reach for now: the current invitation's, a stale and a foreign one's, the
    /// starts, every reason, every screen handle and every overlay kind.
    static func everyAction(_ run: RoomRun) -> [WaveAction] {
        let id = run.wave?.invitation?.id ?? WaveInvitationID(run: run.id, sequence: 1)
        let stale = WaveInvitationID(run: run.id, sequence: max(id.sequence - 1, 0))
        let foreign = WaveInvitationID(run: RoomRunID(run.id.value + 1000), sequence: id.sequence)
        return invitationActions(id) + invitationActions(stale) + invitationActions(foreign)
            + [.startOutgoing, .startIncoming, .showNoAllowance, .previewReport, .blockCounterpart]
            + RoomReportReason.allCases.map { .selectReportReason($0) }
            + WaveScreen.allCases.flatMap { [WaveAction.backToMenu(from: $0), .openSafety(from: $0)] }
            + allOverlays.map { .closeOverlay($0) }
    }

    /// Every overlay value, including each report selection.
    static let allOverlays: [WaveOverlay] = [.globalSafety, .counterpartSafety, .report(nil), .chatInformation,
                                             .conditions] + RoomReportReason.allCases.map { .report($0) }

    /// The action's control, for coverage: exhaustive, so a new `WaveAction` must be named here.
    static func kind(_ action: WaveAction) -> String {
        switch action {
        case .startOutgoing: return "startOutgoing"
        case .startIncoming: return "startIncoming"
        case .showNoAllowance: return "showNoAllowance"
        case .discardCompose: return "discardCompose"
        case .send: return "send"
        case .withdraw: return "withdraw"
        case .accept: return "accept"
        case .decline: return "decline"
        case .openConditions: return "openConditions"
        case .showExpired: return "showExpired"
        case .showSenderWithdrawn: return "showSenderWithdrawn"
        case .openChatInformation: return "openChatInformation"
        case .backToMenu: return "backToMenu"
        case .openSafety: return "openSafety"
        case .previewReport: return "previewReport"
        case .selectReportReason: return "selectReportReason"
        case .closeOverlay: return "closeOverlay"
        case .blockCounterpart: return "blockCounterpart"
        }
    }

    static let allKinds: Set<String> = [
        "startOutgoing", "startIncoming", "showNoAllowance", "discardCompose", "send", "withdraw", "accept",
        "decline", "openConditions", "showExpired", "showSenderWithdrawn", "openChatInformation", "backToMenu",
        "openSafety", "previewReport", "selectReportReason", "closeOverlay", "blockCounterpart",
    ]

    /// Every reachable Wave context for `intent`, named: each screen bare (the menu also after a block and
    /// with a closed history), each overlay on each screen that opens it, and the report preview unselected
    /// and with each reason.
    static func contexts(_ intent: BandIntent) -> [(name: String, run: RoomRun)] {
        var result: [(String, RoomRun)] = []
        for screen in WaveScreen.allCases {
            let run = at(screen, intent)
            result.append((screen.rawValue, run))
            for overlay in overlays(on: screen) {
                var open = run
                guard WaveFixture.open(overlay, on: screen, in: &open) else {
                    preconditionFailure("\(screen) \(overlay)")
                }
                result.append(("\(screen.rawValue) + \(overlay)", open))
                if overlay == .counterpartSafety {
                    var report = open
                    report.perform(.previewReport)
                    result.append(("\(screen.rawValue) + report", report))
                    for reason in RoomReportReason.allCases {
                        var selected = report
                        selected.perform(.selectReportReason(reason))
                        result.append(("\(screen.rawValue) + report \(reason)", selected))
                    }
                }
            }
        }
        var blockedMenu = at(.blocked, intent)
        blockedMenu.perform(.backToMenu(from: .blocked))
        result.append(("menu after a block", blockedMenu))
        result.append(("menu with history", at(.menu, intent, history: true)))
        return result
    }

    /// The Figma key of what shows: an overlay (the counterpart's safety and report use the reviewed Maya
    /// keys for both intents; the Demo cases variant follows the screen below), otherwise the screen, and
    /// "room" once the Wave has closed back to its Room caller.
    static func contextKey(_ run: RoomRun) -> String {
        guard let wave = run.wave else { return "room" }
        switch wave.overlay {
        case .globalSafety?: return "global-safety"
        case .counterpartSafety?: return "maya-safety"
        case .report?: return "report-maya"
        case .chatInformation?: return "chat-info"
        case .conditions?:
            switch wave.screen {
            case .outgoingPending: return "conditions-out"
            case .incomingReview: return "conditions-in"
            case .incomingAccepted: return "conditions-accepted"
            default: return "conditions-?"
            }
        case nil: return wave.screen.rawValue
        }
    }

    /// The report-reason variant on top, by its Figma node (75:627 none selected, then 75:637/647/657).
    static func variantKey(_ run: RoomRun) -> String? {
        guard case .report(let reason)? = run.wave?.overlay else { return nil }
        switch reason {
        case nil: return "75:627"
        case .unwantedAttention?: return "75:637"
        case .harassment?: return "75:647"
        case .somethingElse?: return "75:657"
        }
    }

    static func isLegal(_ old: WaveStatus, _ new: WaveStatus, _ direction: WaveDirection) -> Bool {
        if old == new { return true }
        if old.isTerminal { return false }
        switch (direction, old) {
        case (.outgoing, .compose): return [.pending, .blocked, .sessionEnded].contains(new)
        case (.outgoing, .pending): return [.withdrawn, .unavailable, .blocked, .sessionEnded].contains(new)
        case (.incoming, .pending):
            return [.accepted, .declined, .senderWithdrawn, .unavailable, .blocked, .sessionEnded].contains(new)
        case (.incoming, .accepted): return [.unavailable, .blocked, .sessionEnded].contains(new)
        default: return false
        }
    }

    static func randomStep(_ run: inout RoomRun, issued: [WaveInvitationID], generator: inout WaveSplitMix) {
        let actor = RoomActor.allCases[Int(generator.next() % 2)]
        let pool = issued + [run.wave?.invitation?.id, WaveInvitationID(run: RoomRunID(99), sequence: 1)]
            .compactMap { $0 }
        // Mostly the handles a guest would hold now; sometimes a stale or foreign one.
        let stale = generator.next() % 4 == 0
        let id = !stale ? (run.wave?.invitation?.id ?? pool[0]) : pool[Int(generator.next() % UInt64(pool.count))]
        let screen = !stale ? (run.wave?.screen ?? .menu)
            : WaveScreen.allCases[Int(generator.next() % UInt64(WaveScreen.allCases.count))]
        let reason = RoomReportReason.allCases[Int(generator.next() % 3)]
        let overlays: [WaveOverlay] = [.globalSafety, .counterpartSafety, .report(nil), .chatInformation, .conditions]
        switch generator.next() % 30 {
        case 0: run.openProfile(actor)
        case 1: run.openWaveDemo(viewerName: "Alex")
        case 2: run.closeWaveDemo()
        case 3: _ = run.outerBack()
        case 4: run.openActorSafety(actor)
        case 5: run.block(actor)
        case 6: run.closeLevel()
        case 7: run.selectTab(generator.next() % 2 == 0 ? .people : .notes)
        case 8: run.perform(.startOutgoing)
        case 9: run.perform(.startIncoming)
        case 10: run.perform(.showNoAllowance)
        case 11: run.perform(.discardCompose(id))
        case 12, 13: run.perform(.send(id))
        case 14: run.perform(.withdraw(id))
        case 15, 16: run.perform(.accept(id))
        case 17: run.perform(.decline(id))
        case 18: run.perform(.openConditions(id))
        case 19: run.perform(.showExpired(id))
        case 20: run.perform(.showSenderWithdrawn(id))
        case 21: run.perform(.openChatInformation(id))
        case 22: run.perform(.backToMenu(from: screen))
        case 23: run.perform(.openSafety(from: screen))
        case 24: run.perform(.previewReport)
        case 25: run.perform(.selectReportReason(reason))
        case 26: run.perform(.closeOverlay(overlays[Int(generator.next() % 5)]))
        case 27: run.perform(.blockCounterpart)
        case 28: run.backToPeople()
        default: if generator.next() % 12 == 0 { run.leave() }
        }
    }
}

/// Deterministic, dependency-free pseudo-random numbers for the sequence test.
struct WaveSplitMix {
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

extension WaveFixture {
    /// Common Ground's check-in explanation reached through the actual flow (the same steps as
    /// `PlacesRoute.onSignal`), with the Guest List name typed as `name`.
    static func explanation(_ intent: BandIntent, approach: ApproachSignal, name: String) -> DemoFlow {
        var flow = DemoFlow()
        flow.begin()
        flow.updateBirthday { entry in
            entry.setDay(12)
            entry.setMonth(5)
            entry.setYear(1997)
            entry.commit(today: GuestListRoute.today)
        }
        _ = flow.continueFromBirthday(today: GuestListRoute.today)
        flow.continueFromCompletedPass(GuestListRoute.completedPass())
        flow.editIntroduction { $0.name = name }
        flow.continueFromGuestListCard(WristbandRoute.card(for: flow.draft.introduction))
        flow.chooseIntent(intent)
        flow.continueFromWristband()
        flow.chooseApproach(approach)
        flow.openPlaces()
        flow.openPlaceDetail()
        flow.previewCheckIn()
        precondition(flow.currentScene == .placeExplanation, "\(intent) cannot reach the explanation")
        return flow
    }
}

/// The Room and Wave half of `DemoSession` (Proximeet/App/DemoSession.swift), mirrored line for line because
/// the app target does not compile on Linux: every Wave control goes through `updateRoomRun`, which first
/// drops a Room whose explanation is gone (`reconcileRoom`), and the viewer's name is read from the draft's
/// Guest List card. `testTheSessionMirrorMatchesTheAppWiring` pins the mirrored lines to the app's source.
struct WaveSessionMirror {
    private(set) var flow: DemoFlow
    private(set) var room: RoomPreview?
    private var roomRunCount = 0

    init(flow: DemoFlow) {
        self.flow = flow
    }

    /// The guest acting on the flow below the Room (Back to the place, Explore, a reset).
    mutating func changeFlow(_ change: (inout DemoFlow) -> Void) {
        change(&flow)
    }

    var wave: WaveDemo? { room?.run?.wave }

    @discardableResult
    mutating func previewRoomDemo() -> Bool {
        guard room == nil, let preview = RoomPreview.open(after: flow) else { return false }
        room = preview
        return true
    }

    @discardableResult
    mutating func enterRoomDemo() -> RoomRunID? {
        guard reconcileRoom(), var preview = room, preview.stage == .entry else { return nil }
        roomRunCount += 1
        let id = RoomRunID(roomRunCount)
        guard preview.enter(as: id) else { return nil }
        room = preview
        return id
    }

    @discardableResult
    mutating func updateRoomRun(_ id: RoomRunID, _ change: (inout RoomRun) -> Bool) -> Bool {
        guard reconcileRoom(), var preview = room else { return false }
        let changed = preview.updateRun(id, change)
        room = preview
        return changed
    }

    @discardableResult
    mutating func returnToPlacesFromRoom() -> Bool {
        guard room?.run?.phase == .ended else { return false }
        room = nil
        return flow.exploreOtherPlaces()
    }

    @discardableResult
    mutating func roomOuterBack() -> RoomOuterBack {
        guard reconcileRoom(), var preview = room else { return .none }
        if preview.stage == .entry {
            room = nil
            return .closedLevel
        }
        let outcome = preview.outerBack()
        room = preview
        if outcome == .alreadyEnded {
            returnToPlacesFromRoom()
        }
        return outcome
    }

    @discardableResult
    mutating func reconcileRoom() -> Bool {
        guard let preview = room else { return false }
        guard preview.isStillValid(for: flow) else {
            room = nil
            return false
        }
        return true
    }

    @discardableResult
    mutating func openWaveDemo(_ id: RoomRunID) -> Bool {
        guard let name = flow.draft.introduction.card?.name else { return false }
        return updateRoomRun(id) { $0.openWaveDemo(viewerName: name) }
    }

    @discardableResult
    mutating func performWave(_ id: RoomRunID, _ action: WaveAction) -> Bool {
        updateRoomRun(id) { $0.perform(action) }
    }
}
