import XCTest
@testable import ProximeetDomain

/// The approved four-intent private-invitation presentation. These are local fictional examples;
/// the new artwork and copy do not send anything or bypass the existing recipient and session guards.
final class PrivateInvitationTests: XCTestCase {
    private let newPairs: [(BandIntent, RoomActor, RoomActor)] = [
        (.activity, .sam, .riley), (.dating, .riley, .sam),
    ]

    func testFourInvitationsHaveTheirApprovedDistinctCopy() {
        let approved: [(RoomActor, String, String)] = [
            (.jules, "An idea worth sharing.", "A private hello about ideas and opportunities."),
            (.maya, "Good company starts here.", "A private hello for coffee and conversation."),
            (.sam, "Make a plan. Move together.", "A private hello for a walk, workout, or game."),
            (.riley, "A little chemistry.", "A private hello to see if the interest is mutual."),
        ]
        XCTAssertEqual(WaveCopy.composeBrand, "Private invitation")
        XCTAssertEqual(WaveCopy.send, "Send private invitation")
        XCTAssertEqual(Set(approved.map { $0.1 }).count, 4)
        for (actor, title, purpose) in approved {
            XCTAssertEqual(WaveCopy.invitationTitle(.outgoingConfirm, counterpart: actor), title)
            XCTAssertEqual(WaveCopy.invitationPurpose(.outgoingConfirm, counterpart: actor), purpose)
            XCTAssertEqual(WaveCopy.recipientChoice(counterpart: actor), "\(actor.name) chooses whether to accept.")
            XCTAssertEqual(WaveCopy.invitationTitle(.outgoingPending, counterpart: actor), "Waiting for \(actor.name).")
            XCTAssertEqual(WaveCopy.invitationPurpose(.outgoingPending, counterpart: actor),
                           "Only \(actor.name) can accept.\nYou can withdraw at any time.")
            XCTAssertEqual(WaveCopy.invitationPurpose(.incomingReview, counterpart: actor),
                           "Accept only if you want to.\nNo explanation needed to decline.")
        }
    }

    func testActivityAndDatingEnterThroughTheRealGatesAndKeepTheirOwnPeople() {
        for (intent, same, other) in newPairs {
            for approach in ApproachSignal.allCases {
                let flow = RoomFixture.onExplanation(intent, approach: approach)
                XCTAssertEqual(flow.currentScene, .placeExplanation)
                var preview = RoomPreview.open(after: flow)
                XCTAssertNotNil(preview)
                XCTAssertNil(preview?.run, "opening the explanation starts no run")
                XCTAssertEqual(preview?.enter(as: RoomRunID(42)), true)
                guard var run = preview?.run else { return XCTFail("no room for \(intent)") }
                XCTAssertEqual(run.phase, .waiting)
                XCTAssertEqual(run.visiblePeople, [], "no sample before the explicit populate control")
                XCTAssertTrue(run.showPopulatedExample())
                XCTAssertEqual(run.intent, intent)
                XCTAssertEqual(run.approach, approach)
                XCTAssertEqual(run.visiblePeople, [.sam, .riley])
                XCTAssertEqual(run.visibleNoteAuthors, [], "Jules's note is not part of this sample room")
                for absent in [RoomActor.maya, .jules] {
                    XCTAssertFalse(run.showsSample(absent))
                    XCTAssertFalse(run.openProfile(absent), "no stale route to another sample group")
                    XCTAssertFalse(run.openActorSafety(absent))
                }
                XCTAssertTrue(run.openProfile(other))
                XCTAssertEqual(run.profileAction(for: other), .backToPeople)
                XCTAssertFalse(run.openWaveDemo(viewerName: "Alex"), "another intent cannot invite")
                XCTAssertTrue(run.backToPeople())
                XCTAssertTrue(run.openProfile(same))
                XCTAssertTrue(run.openWaveDemo(viewerName: "Alex"))
                XCTAssertEqual(run.wave?.counterpart, same)
                XCTAssertEqual(run.wave?.intent, intent)
                XCTAssertNil(run.wave?.invitation, "the menu does not create an invitation")
                XCTAssertTrue(run.isConsistent)
            }
        }
        XCTAssertEqual(RoomFixture.populated(.social).visiblePeople, [.maya, .jules])
        XCTAssertEqual(RoomFixture.populated(.business).visibleNoteAuthors, [.jules])
    }

    func testNewIntentsStillRequireRecipientAcceptanceAndRejectOldIdentities() {
        for (intent, counterpart, _) in newPairs {
            var run = WaveFixture.menu(intent, name: counterpart.name)
            XCTAssertTrue(run.perform(.startOutgoing))
            guard let outgoing = run.wave?.invitation else { return XCTFail("no outgoing") }
            XCTAssertEqual(outgoing.sender, .viewer)
            XCTAssertEqual(outgoing.recipient, .sample(counterpart))
            XCTAssertFalse(run.perform(.accept(outgoing.id)), "a matching display name does not make the sender a recipient")
            XCTAssertTrue(run.perform(.send(outgoing.id)))
            XCTAssertFalse(run.perform(.accept(outgoing.id)), "a pending outgoing still cannot self-accept")
            XCTAssertTrue(run.perform(.withdraw(outgoing.id)))
            XCTAssertTrue(run.perform(.backToMenu(from: .outgoingWithdrawn)))
            XCTAssertTrue(run.perform(.startIncoming))
            guard let incoming = run.wave?.invitation else { return XCTFail("no incoming") }
            XCTAssertNotEqual(incoming.id, outgoing.id)
            XCTAssertEqual(incoming.sender, .sample(counterpart))
            XCTAssertEqual(incoming.recipient, .viewer)
            let before = run
            XCTAssertFalse(run.perform(.accept(outgoing.id)), "a stale invitation cannot accept the new one")
            XCTAssertEqual(run, before)
            XCTAssertTrue(run.perform(.accept(incoming.id)))
            XCTAssertEqual(run.wave?.screen, .incomingAccepted)
            XCTAssertFalse(run.perform(.accept(incoming.id)), "acceptance commits once")
            XCTAssertEqual(run.closedInvitations.map(\.status), [.withdrawn])
            XCTAssertTrue(run.leave())
            XCTAssertEqual(run.wave?.screen, .sessionEnded)
            XCTAssertEqual(run.visiblePeople, [])
            XCTAssertEqual(run.closedInvitations.map(\.status), [.withdrawn, .sessionEnded])
            XCTAssertFalse(run.perform(.accept(incoming.id)), "Leave wins over a late tap")
            XCTAssertTrue(run.isConsistent)
        }
    }

    func testNewIntentsRespectBlocksAndBothBlockOrders() {
        for (intent, counterpart, other) in newPairs {
            for otherFirst in [false, true] {
                var run = WaveFixture.at(.incomingReview, intent, preblock: otherFirst ? [other] : [])
                guard let invitation = run.wave?.invitation else { return XCTFail("no incoming") }
                XCTAssertTrue(run.perform(.openSafety(from: .incomingReview)))
                XCTAssertTrue(run.perform(.blockCounterpart(counterpart, run: run.id)))
                XCTAssertEqual(run.wave?.screen, .blocked)
                XCTAssertFalse(run.perform(.accept(invitation.id)))
                XCTAssertTrue(run.perform(.backToMenu(from: .blocked)))
                XCTAssertFalse(run.perform(.startIncoming), "a blocked counterpart cannot start again")
                XCTAssertFalse(run.perform(.startOutgoing))
                XCTAssertTrue(run.closeWaveDemo())
                XCTAssertFalse(run.showsSample(counterpart))
                XCTAssertFalse(run.openProfile(counterpart))
                if !otherFirst {
                    XCTAssertEqual(run.visiblePeople, [other])
                    XCTAssertTrue(RoomFixture.block(other, in: &run))
                }
                XCTAssertEqual(run.blocked, [.sam, .riley])
                XCTAssertEqual(run.visiblePeople, [])
                XCTAssertEqual(run.visibleNoteAuthors, [])
                XCTAssertTrue(run.showsNoSampleIntroductions)
                XCTAssertTrue(run.showsHostNotes)
                XCTAssertTrue(run.isConsistent)
            }
        }
    }

    func testNewIntentDeclinesAndSenderWithdrawalsStayClosed() {
        for (intent, _, _) in newPairs {
            for senderWithdraws in [false, true] {
                var run = WaveFixture.at(.incomingReview, intent)
                guard let invitation = run.wave?.invitation else { return XCTFail("no incoming") }
                if senderWithdraws {
                    XCTAssertTrue(run.perform(.openConditions(invitation.id)))
                    XCTAssertTrue(run.perform(.showSenderWithdrawn(invitation.id)))
                    XCTAssertEqual(run.wave?.screen, .incomingWithdrawn)
                } else {
                    XCTAssertTrue(run.perform(.decline(invitation.id)))
                    XCTAssertEqual(run.wave?.screen, .incomingDeclined)
                }
                let closed = run
                XCTAssertFalse(run.perform(.accept(invitation.id)))
                XCTAssertFalse(run.perform(.send(invitation.id)))
                XCTAssertEqual(run, closed, "a terminal invitation never reopens")
                XCTAssertEqual(run.closedInvitations.count, 1)
                XCTAssertEqual(run.closedInvitations.first?.status, senderWithdraws ? .senderWithdrawn : .declined)
                XCTAssertTrue(run.isConsistent)
            }
        }
    }
}
