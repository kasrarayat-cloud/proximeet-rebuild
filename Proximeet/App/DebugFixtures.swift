#if DEBUG
import Foundation
import ProximeetDomain

/// DEBUG-only launch arguments for inspecting scenes directly. Never compiled into Release.
///
///     -ProximeetFixture welcome | birthday | birthday-adult | birthday-under18 | pass |
///                       guest-list | guest-list-filled | guest-list-card | guest-list-name-only |
///                       wristband | wristband-social | wristband-dating | wristband-business |
///                       wristband-activity | signal | signal-selected | places | place-detail |
///                       place-explanation | band | band-selected | ready
///     -ProximeetFixtureBand social | dating | business | activity
///     -ProximeetFixtureSignal chatFirst | okayToSayHello
///     -ProximeetFixtureCategory now | later | upcoming
///
/// `signal` and `signal-selected` open the approved Signal through the same gates as the real
/// route; they need an explicit `-ProximeetFixtureBand` (and `signal-selected` an explicit
/// `-ProximeetFixtureSignal`): no intent or approach is ever assumed. `places`, `place-detail`
/// and `place-explanation` continue from `signal-selected` through Signal's Continue preview (the
/// category, Now unless given, through its tab; the detail through View place; the explanation
/// through Preview check-in, which only an eligible intent at Common Ground opens: otherwise the
/// fixture stays on the detail, as the app would). They need an explicit band and approach too.
///     -ProximeetFixture room-entry | room-waiting | room-populated | room-ended
///     -ProximeetRoomBlocked maya | jules | maya-jules | jules-maya   (the order the blocks are applied)
///     -ProximeetRoomTab people | notes
///     -ProximeetRoomProfile maya | jules
///     -ProximeetRoomPanel global-safety | actor-safety | report
///     -ProximeetRoomReason unwantedAttention | harassment | somethingElse
///
/// The Room fixtures (chapter 08) continue from `place-explanation` (so they need an explicit Social or
/// Business band and an approach) through the app's own transitions: Preview room demo, then, for every
/// stage after the entry, the deliberate Enter room demo, and, for `room-populated`, the labelled Show
/// populated example. Blocks are applied through each actor's profile safety, in the order given; the tab,
/// the profile and the panel are opened as a guest would open them. A step the app would refuse is
/// refused here too (for example an ineligible intent stays on the detail). They are direct launches for
/// captures, never a real journey. (Chapter 09 removed `-ProximeetRoomPanel wave-info` with the Wave
/// information panel 66:134 it opened: the same-intent profile's action now opens the Wave.)
///     -ProximeetFixture wave-menu | wave-out-confirm | wave-out-pending | wave-out-withdrawn |
///                       wave-in-review | wave-in-declined | wave-in-accepted | wave-in-withdrawn |
///                       wave-unavailable | wave-blocked | wave-allowance-unavailable | wave-session-ended
///     -ProximeetWaveFrom out-pending | in-review | in-accepted                  (wave-unavailable; in-review)
///                        out-confirm | out-pending | in-review | in-accepted    (wave-blocked; out-pending)
///                        any other Wave screen's name, demo-menu by default     (wave-session-ended)
///     -ProximeetWaveAfterBlock menu | start-outgoing | start-incoming | no-allowance | room   (wave-blocked)
///     -ProximeetWavePanel global-safety | safety | report | chat-info | conditions
///     -ProximeetWaveReason unwantedAttention | harassment | somethingElse    (with report)
///     -ProximeetFixtureName <text>
///
/// The Wave fixtures (chapter 09) take the Room's own path first (so they too need an explicit Social or
/// Business band and an approach): Preview room demo, Enter room demo, Show populated example and any
/// `-ProximeetRoomBlocked` blocks, then the counterpart's profile (Maya for Social, Jules for Business)
/// and Preview Wave demo, and from the menu exactly the Wave controls a guest would press to reach the
/// named screen. A counterpart blocked in the Room first stays blocked: its card and profile are gone, so
/// the fixture stops on the filtered People, as the app would. `wave-blocked` blocks the counterpart
/// from the counterpart's safety over `-ProximeetWaveFrom`; `-ProximeetWaveAfterBlock` then goes back
/// to the menu and (for the three starts) starts a new example, which shows the generic blocked screen
/// again with no identity, or (`room`) closes the Wave from its menu to the Room's filtered People, where
/// `-ProximeetRoomTab` may then choose Room notes. `-ProximeetWavePanel` opens one overlay on the screen
/// reached, as its chrome, Demo cases or About private chat would (`global-safety` only where the shield
/// opens the global safety, `safety` and `report` only where it opens the counterpart's); an overlay
/// the design does not offer there is refused and the fixture stays on the screen. `wave-session-ended`
/// leaves from `-ProximeetWaveFrom` (the menu by default). A `-ProximeetWaveFrom` or
/// `-ProximeetWaveAfterBlock` value not listed for the stage is refused: the fixture stays on the menu
/// (or on the blocked screen), never on a default the capture did not ask for.
///
/// `-ProximeetFixtureName` gives the fictional Guest List example another name, exactly as written, on
/// every fixture that enters the example (for long names and the largest text sizes); the Wave reads it
/// as the actual Guest List name, like any typed name. A name the Guest List would not preview stops the
/// fixture on the Guest List, as the app would.
///     -ProximeetReduceMotionPreview YES
///     -ProximeetPlacesKeepContentPop YES
///
/// `-ProximeetReduceMotionPreview` is an app-level presentation override for captures; it does not
/// change the system Reduce Motion setting. `-ProximeetPlacesKeepContentPop` is a diagnosis switch
/// for the Places scroll probe, not a product mode: `PlacesEdgeBack` then leaves the navigation
/// stack's swipe-from-anywhere pop (iOS 26) enabled on a detail and the explanation instead of
/// holding it off, so a scroll can be compared with and without it. Without the switch nothing
/// changes; Release builds never read it.
enum DebugLaunch {
    static func session(arguments: [String]) -> DemoSession? {
        guard let name = value(after: "-ProximeetFixture", in: arguments),
              let stage = PreviewFixtures.Stage(rawValue: name)
        else { return nil }
        let band = value(after: "-ProximeetFixtureBand", in: arguments).flatMap(BandIntent.init(rawValue:))
        let signal = value(after: "-ProximeetFixtureSignal", in: arguments).flatMap(ApproachSignal.init(rawValue:))
        let category = value(after: "-ProximeetFixtureCategory", in: arguments).flatMap(PlaceCategory.init(rawValue:))
        let guestName = value(after: "-ProximeetFixtureName", in: arguments)
        if stage == .signal || stage == .signalSelected {
            guard let band, stage == .signal || signal != nil else { return nil }
            return PreviewFixtures.session(at: stage, band: band, signal: signal ?? .chatFirst, name: guestName)
        }
        if PreviewFixtures.Stage.placesStages.contains(stage) {
            guard let band, let signal else { return nil }
            return PreviewFixtures.session(at: stage, band: band, signal: signal, category: category ?? .now, name: guestName)
        }
        if PreviewFixtures.Stage.roomStages.contains(stage) {
            guard let band, let signal else { return nil }
            let session = PreviewFixtures.session(at: .placeExplanation, band: band, signal: signal, name: guestName)
            RoomFixture.apply(stage, to: session, arguments: arguments)
            return session
        }
        if let screen = PreviewFixtures.Stage.waveScreens[stage] {
            guard let band, let signal else { return nil }
            let session = PreviewFixtures.session(at: .placeExplanation, band: band, signal: signal, name: guestName)
            WaveFixture.apply(screen, to: session, arguments: arguments)
            return session
        }
        return PreviewFixtures.session(at: stage, band: band ?? .social, signal: signal ?? .chatFirst, name: guestName)
    }

    static func prefersReducedMotionPreview(arguments: [String]) -> Bool {
        value(after: "-ProximeetReduceMotionPreview", in: arguments) == "YES"
    }

    static func keepsPlacesContentPop(arguments: [String]) -> Bool {
        value(after: "-ProximeetPlacesKeepContentPop", in: arguments) == "YES"
    }

    /// `-ProximeetPlacesKeepContentPop YES` in this process's launch arguments, read once.
    static let launchKeepsPlacesContentPop = keepsPlacesContentPop(arguments: ProcessInfo.processInfo.arguments)

    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// Explicitly fictional, deterministic data for previews and DEBUG launches. Built only
/// through the public domain transitions, so fixtures can never reach a state the real
/// flow cannot.
enum PreviewFixtures {
    enum Stage: String {
        /// Fresh demo: nothing entered.
        case welcome
        /// The approved Birthday, fresh: DD / MMM / YYYY.
        case birthday
        /// The approved Birthday with 12 May 1997 entered and checked (adult example).
        case birthdayAdult = "birthday-adult"
        /// The approved Birthday with 12 May 2012 entered and checked (under-18 example).
        case birthdayUnder18 = "birthday-under18"
        /// The approved Pass (intro), opened from Birthday's Continue with 12 May 1997.
        case pass
        /// The approved Guest List editor, empty, opened from a completed Pass.
        case guestList = "guest-list"
        /// The editor with the approved fictional Alex example.
        case guestListFilled = "guest-list-filled"
        /// The personal card of the fictional Alex example.
        case guestListCard = "guest-list-card"
        /// The personal card with only the fictional name: no opener, no interests.
        case guestListNameOnly = "guest-list-name-only"
        /// The approved Wristband, unselected, opened from the fictional example's card.
        case wristband
        /// The approved Wristband with one intent chosen.
        case wristbandSocial = "wristband-social"
        case wristbandDating = "wristband-dating"
        case wristbandBusiness = "wristband-business"
        case wristbandActivity = "wristband-activity"
        /// The approved Signal for the given intent, no approach, opened from its Wristband.
        case signal
        /// The approved Signal for the given intent with the given approach chosen.
        case signalSelected = "signal-selected"
        /// The approved Places, browsing the given category (through Signal's Continue preview).
        case places
        /// The given category's venue detail (through View place).
        case placeDetail = "place-detail"
        /// Common Ground's check-in explanation (through Preview check-in; eligible intents only).
        case placeExplanation = "place-explanation"
        /// The Room (chapter 08) above Common Ground's explanation: its entry, a new run in waiting, the
        /// populated example, and the ended run (see `RoomFixture`).
        case roomEntry = "room-entry"
        case roomWaiting = "room-waiting"
        case roomPopulated = "room-populated"
        case roomEnded = "room-ended"
        /// The Wave (chapter 09) above the counterpart's Room profile: its menu and each of its screens,
        /// reached from the menu through the Wave's own controls (see `WaveFixture`).
        case waveMenu = "wave-menu"
        case waveOutgoingConfirm = "wave-out-confirm"
        case waveOutgoingPending = "wave-out-pending"
        case waveOutgoingWithdrawn = "wave-out-withdrawn"
        case waveIncomingReview = "wave-in-review"
        case waveIncomingDeclined = "wave-in-declined"
        case waveIncomingAccepted = "wave-in-accepted"
        case waveIncomingWithdrawn = "wave-in-withdrawn"
        case waveUnavailable = "wave-unavailable"
        case waveBlocked = "wave-blocked"
        case waveAllowanceUnavailable = "wave-allowance-unavailable"
        case waveSessionEnded = "wave-session-ended"
        /// Legacy, unapproved later scenes, reached through the legacy route for their captures.
        case band
        case bandSelected = "band-selected"
        case ready

        /// The approved Places stages.
        static let placesStages: Set<Stage> = [.places, .placeDetail, .placeExplanation]
        /// The Room stages.
        static let roomStages: Set<Stage> = [.roomEntry, .roomWaiting, .roomPopulated, .roomEnded]
        /// The Wave stages, each with the approved Wave screen it reaches (all twelve, 74:568–74:579).
        static let waveScreens: [Stage: WaveScreen] = [
            .waveMenu: .menu, .waveOutgoingConfirm: .outgoingConfirm, .waveOutgoingPending: .outgoingPending,
            .waveOutgoingWithdrawn: .outgoingWithdrawn, .waveIncomingReview: .incomingReview,
            .waveIncomingDeclined: .incomingDeclined, .waveIncomingAccepted: .incomingAccepted,
            .waveIncomingWithdrawn: .incomingWithdrawn, .waveUnavailable: .unavailable, .waveBlocked: .blocked,
            .waveAllowanceUnavailable: .allowanceUnavailable, .waveSessionEnded: .sessionEnded,
        ]
    }

    static let firstName = "Alex"
    static let interests = ["Bouldering", "Film photography", "Board games"]

    /// The approved Guest List's fictional example (Figma 36:169). Never a real person's data,
    /// and never used outside previews and DEBUG launches.
    static let exampleIntroduction = GuestIntroduction(
        name: "Alex",
        opener: "Always up for coffee and a good story.",
        interests: GuestIntroduction.Interest.allCases
    )

    /// The approved example under `name` (DEBUG `-ProximeetFixtureName`), exactly as given; the example
    /// itself when there is none.
    static func exampleIntroduction(named name: String?) -> GuestIntroduction {
        var introduction = exampleIntroduction
        if let name {
            introduction.name = name
        }
        return introduction
    }

    static func session(
        at stage: Stage,
        band: BandIntent = .social,
        signal: ApproachSignal = .chatFirst,
        category: PlaceCategory = .now,
        name: String? = nil
    ) -> DemoSession {
        let session = DemoSession(flow: flow(at: stage, band: band, signal: signal, category: category, name: name))
        // The Guest List below a Wristband, Signal or Places fixture shows its card too, as on the
        // real route.
        session.fixtureOpensGuestListCard = [.guestListCard, .guestListNameOnly, .wristband, .wristbandSocial,
                                             .wristbandDating, .wristbandBusiness, .wristbandActivity,
                                             .signal, .signalSelected].contains(stage) || Stage.placesStages.contains(stage)
        return session
    }

    static func flow(at stage: Stage, band: BandIntent, signal: ApproachSignal,
                     category: PlaceCategory = .now, name: String? = nil) -> DemoFlow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        // Midday UTC, so the fixture birthday is 17 May in every time zone within ±11 h.
        let reference = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
        let birthday = calendar.date(from: DateComponents(year: 1995, month: 5, day: 17, hour: 12))
            ?? Date(timeIntervalSince1970: 0)

        var flow = DemoFlow()
        if stage == .welcome { return flow }

        flow.begin()
        switch stage {
        case .birthday:
            return flow
        case .birthdayAdult, .birthdayUnder18, .pass, .guestList, .guestListFilled, .guestListCard, .guestListNameOnly,
             .wristband, .wristbandSocial, .wristbandDating, .wristbandBusiness, .wristbandActivity,
             .signal, .signalSelected, .places, .placeDetail, .placeExplanation:
            // The approved Figma example dates, entered and checked through the domain.
            let today = CivilDate(year: 2026, month: 9, day: 24) ?? CivilDate.day(of: reference, in: calendar.timeZone)
            flow.updateBirthday { entry in
                entry.setDay(12)
                entry.setMonth(5)
                entry.setYear(stage == .birthdayUnder18 ? 2012 : 1997)
                entry.commit(today: today)
            }
            if stage == .birthdayAdult || stage == .birthdayUnder18 { return flow }
            // Through Birthday's own gate, as a guest would reach it.
            _ = flow.continueFromBirthday(today: today)
            if stage == .pass { return flow }
            // Through the Pass's Continue preview, after a completed demo. (The Pass screen below
            // is a new view, so it shows its intro; only the real route leaves it complete.)
            var demo = PassDemo()
            demo.start()
            demo.finish()
            flow.continueFromCompletedPass(demo)
            switch stage {
            case .guestListFilled, .guestListCard:
                flow.editIntroduction { $0 = exampleIntroduction(named: name) }
            case .guestListNameOnly:
                flow.editIntroduction { $0.name = exampleIntroduction(named: name).name }
            case .wristband, .wristbandSocial, .wristbandDating, .wristbandBusiness, .wristbandActivity,
                 .signal, .signalSelected, .places, .placeDetail, .placeExplanation:
                // Through the card's Continue preview, as a guest would reach it.
                flow.editIntroduction { $0 = exampleIntroduction(named: name) }
                var card = GuestListDemo()
                card.preview(flow.draft.introduction)
                flow.continueFromGuestListCard(card)
                let intents: [Stage: BandIntent] = [.wristbandSocial: .social, .wristbandDating: .dating,
                                                    .wristbandBusiness: .business, .wristbandActivity: .activity]
                if let intent = intents[stage] {
                    flow.chooseIntent(intent)
                }
                if stage == .signal || stage == .signalSelected || Stage.placesStages.contains(stage) {
                    // Through the Wristband's Continue preview, with the given intent.
                    flow.chooseIntent(band)
                    flow.continueFromWristband()
                    if stage != .signal {
                        flow.chooseApproach(signal)
                    }
                }
                if Stage.placesStages.contains(stage) {
                    // Through Signal's Continue preview, the category's tab, View place and
                    // Preview check-in: each only where the app itself allows it.
                    flow.openPlaces()
                    flow.choosePlaceCategory(stage == .placeExplanation ? .now : category)
                    if stage != .places {
                        flow.openPlaceDetail()
                    }
                    if stage == .placeExplanation {
                        flow.previewCheckIn()
                    }
                }
            default:
                break
            }
            return flow
        default:
            break
        }
        // Later, unapproved scenes are reached through the legacy route, for their own captures.
        flow.submitBirthday(birthday, using: BirthdayEligibility(referenceDate: reference, calendar: calendar))
        flow.continueFromPass()
        flow.saveProfile(firstName: firstName, interests: interests)
        flow.continueFromGuestList()
        if stage == .band { return flow }

        flow.selectBand(band)
        if stage == .bandSelected { return flow }

        flow.confirmBand()
        flow.selectSignal(signal)
        flow.confirmSignal()
        return flow
    }
}
/// The Room fixtures: every step through the session's own Room transitions, in the order a guest takes.
enum RoomFixture {
    static func apply(_ stage: PreviewFixtures.Stage, to session: DemoSession, arguments: [String]) {
        guard session.previewRoomDemo(), stage != .roomEntry, let id = session.enterRoomDemo() else { return }
        let panel = DebugLaunch.value(after: "-ProximeetRoomPanel", in: arguments)
        switch stage {
        case .roomWaiting:
            if panel == "global-safety" {
                session.updateRoomRun(id) { $0.openGlobalSafety() }
            }
        case .roomEnded:
            session.updateRoomRun(id) { $0.leave() }
        case .roomPopulated:
            session.updateRoomRun(id) { $0.showPopulatedExample() }
            applyBlocks(to: session, run: id, arguments: arguments)
            let tab = DebugLaunch.value(after: "-ProximeetRoomTab", in: arguments).flatMap(RoomTab.init(rawValue:))
            if let tab {
                session.updateRoomRun(id) { $0.selectTab(tab) }
            }
            let profile = DebugLaunch.value(after: "-ProximeetRoomProfile", in: arguments).flatMap(RoomActor.init(rawValue:))
            if let profile {
                session.updateRoomRun(id) { $0.openProfile(profile) }
            }
            // The actor a panel concerns: the open profile's, or Jules's public note on Room notes.
            let actor = profile ?? .jules
            switch panel {
            case "global-safety":
                session.updateRoomRun(id) { $0.openGlobalSafety() }
            case "actor-safety":
                session.updateRoomRun(id) { $0.openActorSafety(actor) }
            case "report":
                session.updateRoomRun(id) { $0.openActorSafety(actor) && $0.previewReport() }
                if let reason = DebugLaunch.value(after: "-ProximeetRoomReason", in: arguments)
                    .flatMap(RoomReportReason.init(rawValue:)) {
                    session.updateRoomRun(id) { $0.selectReportReason(reason) }
                }
            default:
                break
            }
        default:
            break
        }
    }

    /// `-ProximeetRoomBlocked`: each actor blocked through their profile's safety, in the order given.
    static func applyBlocks(to session: DemoSession, run id: RoomRunID, arguments: [String]) {
        let blocked: [RoomActor]
        switch DebugLaunch.value(after: "-ProximeetRoomBlocked", in: arguments) {
        case "maya": blocked = [.maya]
        case "jules": blocked = [.jules]
        case "maya-jules": blocked = [.maya, .jules]
        case "jules-maya": blocked = [.jules, .maya]
        default: blocked = []
        }
        for actor in blocked {
            session.updateRoomRun(id) { $0.openProfile(actor) && $0.openActorSafety(actor) && $0.block(actor) }
        }
    }
}

/// The Wave fixtures (chapter 09): the Room's own path to the counterpart's profile, Preview Wave demo,
/// then only the Wave controls a guest would press, each through `DemoSession.performWave` and so through
/// every guard the app itself applies. Nothing sets a Wave state directly; a step the app refuses stops
/// the fixture where the app would stop.
enum WaveFixture {
    static func apply(_ screen: WaveScreen, to session: DemoSession, arguments: [String]) {
        // Preview room demo, Enter room demo, Show populated example and any Room blocks, as for
        // `room-populated`.
        guard session.previewRoomDemo(), let id = session.enterRoomDemo(),
              session.updateRoomRun(id, { $0.showPopulatedExample() }),
              let run = session.room?.run
        else { return }
        RoomFixture.applyBlocks(to: session, run: id, arguments: arguments)
        // The sample of the guest's own intent (Maya for Social, Jules for Business): the one profile whose
        // action is Preview Wave demo. Blocked in the Room first, it has no card, so this stops on People.
        guard let counterpart = RoomActor.allCases.first(where: { run.profileAction(for: $0) == .previewWaveDemo }),
              session.updateRoomRun(id, { $0.openProfile(counterpart) }),
              session.openWaveDemo(id)
        else { return }

        let from = DebugLaunch.value(after: "-ProximeetWaveFrom", in: arguments)
        /// The screen `-ProximeetWaveFrom` names when it is one of `allowed`, `fallback` without the argument,
        /// and nil for any other value (refused: the fixture stays on the menu).
        func origin(_ allowed: Set<WaveScreen>, _ fallback: WaveScreen) -> WaveScreen? {
            guard let from else { return fallback }
            return WaveScreen(rawValue: from).flatMap { allowed.contains($0) ? $0 : nil }
        }
        switch screen {
        case .unavailable:
            // Demo cases → Show expired example, over a pending or accepted invitation.
            guard let start = origin([.outgoingPending, .incomingReview, .incomingAccepted], .incomingReview),
                  reach(start, session: session, run: id), let invitation = session.wave?.invitation?.id,
                  session.performWave(id, .openConditions(invitation))
            else { return }
            session.performWave(id, .showExpired(invitation))
        case .blocked:
            // "Block [Name] in demo" on the counterpart's safety over an active invitation.
            guard let start = origin([.outgoingConfirm, .outgoingPending, .incomingReview, .incomingAccepted],
                                     .outgoingPending),
                  reach(start, session: session, run: id), session.performWave(id, .openSafety(from: start)),
                  session.performWave(id, .blockCounterpart)
            else { return }
            afterBlock(session: session, run: id, arguments: arguments)
        case .sessionEnded:
            // Leave and disappear, from the menu or from the given screen (its overlays, if any, are not
            // opened first: Leave from an overlay ends the same way).
            guard let start = origin(Set(WaveScreen.allCases).subtracting([.sessionEnded]), .menu),
                  reach(start, session: session, run: id)
            else { return }
            session.updateRoomRun(id) { $0.leave() }
        default:
            guard reach(screen, session: session, run: id) else { return }
        }
        openPanel(session: session, run: id, arguments: arguments)
    }

    /// From the menu to `screen` through the Wave's own controls, by the default path (`unavailable` from
    /// an incoming review, `blocked` from an outgoing pending invitation); `apply` takes the other paths
    /// `-ProximeetWaveFrom` names. The ended screen is reached by Leave, never from here.
    @discardableResult
    private static func reach(_ screen: WaveScreen, session: DemoSession, run id: RoomRunID) -> Bool {
        /// The current invitation's identity, read afresh at each step (each start issues a new one).
        func current(_ action: (WaveInvitationID) -> WaveAction) -> Bool {
            guard let invitation = session.wave?.invitation?.id else { return false }
            return session.performWave(id, action(invitation))
        }
        let done: Bool
        switch screen {
        case .menu:
            done = true
        case .outgoingConfirm:
            done = session.performWave(id, .startOutgoing)
        case .outgoingPending:
            done = session.performWave(id, .startOutgoing) && current { .send($0) }
        case .outgoingWithdrawn:
            done = session.performWave(id, .startOutgoing) && current { .send($0) } && current { .withdraw($0) }
        case .incomingReview:
            done = session.performWave(id, .startIncoming)
        case .incomingAccepted:
            done = session.performWave(id, .startIncoming) && current { .accept($0) }
        case .incomingDeclined:
            done = session.performWave(id, .startIncoming) && current { .decline($0) }
        case .incomingWithdrawn:
            done = session.performWave(id, .startIncoming) && current { .openConditions($0) }
                && current { .showSenderWithdrawn($0) }
        case .unavailable:
            done = session.performWave(id, .startIncoming) && current { .openConditions($0) }
                && current { .showExpired($0) }
        case .allowanceUnavailable:
            done = session.performWave(id, .showNoAllowance)
        case .blocked:
            done = session.performWave(id, .startOutgoing) && current { .send($0) }
                && session.performWave(id, .openSafety(from: .outgoingPending))
                && session.performWave(id, .blockCounterpart)
        case .sessionEnded:
            done = false
        }
        return done && session.wave?.screen == screen
    }

    /// `-ProximeetWaveAfterBlock`: what the guest does next on the blocked screen (74:576). Back to demo
    /// menu, and then optionally a new start, which the blocked counterpart turns into the same generic
    /// blocked screen with no identity; or `room`, the outer Back from the menu to the Room's filtered
    /// People (the Wave's only way back to the Room), with `-ProximeetRoomTab` after it.
    private static func afterBlock(session: DemoSession, run id: RoomRunID, arguments: [String]) {
        guard let next = DebugLaunch.value(after: "-ProximeetWaveAfterBlock", in: arguments),
              ["menu", "start-outgoing", "start-incoming", "no-allowance", "room"].contains(next),
              session.performWave(id, .backToMenu(from: .blocked))
        else { return }
        switch next {
        case "start-outgoing":
            session.performWave(id, .startOutgoing)
        case "start-incoming":
            session.performWave(id, .startIncoming)
        case "no-allowance":
            session.performWave(id, .showNoAllowance)
        case "room":
            guard session.roomOuterBack() == .closedLevel else { return }
            if let tab = DebugLaunch.value(after: "-ProximeetRoomTab", in: arguments).flatMap(RoomTab.init(rawValue:)) {
                session.updateRoomRun(id) { $0.selectTab(tab) }
            }
        default:
            break
        }
    }

    /// `-ProximeetWavePanel`: one overlay on the screen reached, opened by the control that opens it there.
    private static func openPanel(session: DemoSession, run id: RoomRunID, arguments: [String]) {
        guard let panel = DebugLaunch.value(after: "-ProximeetWavePanel", in: arguments),
              let wave = session.wave
        else { return }
        let screen = wave.screen
        let invitation = wave.invitation?.id
        switch panel {
        case "global-safety":
            guard screen.safety == .globalSafety else { return }
            session.performWave(id, .openSafety(from: screen))
        case "safety":
            guard screen.safety == .counterpartSafety else { return }
            session.performWave(id, .openSafety(from: screen))
        case "report":
            guard screen.safety == .counterpartSafety, session.performWave(id, .openSafety(from: screen)),
                  session.performWave(id, .previewReport)
            else { return }
            if let reason = DebugLaunch.value(after: "-ProximeetWaveReason", in: arguments)
                .flatMap(RoomReportReason.init(rawValue:)) {
                session.performWave(id, .selectReportReason(reason))
            }
        case "chat-info":
            guard let invitation else { return }
            session.performWave(id, .openChatInformation(invitation))
        case "conditions":
            guard let invitation else { return }
            session.performWave(id, .openConditions(invitation))
        default:
            break
        }
    }
}
#endif
