import Foundation

/// Chapter 09, the approved Wave: a bounded, local, explicitly fictional invitation demo opened from an
/// eligible same-intent Room profile ("Preview Wave demo"). It lives inside the Room run that opened it
/// (`RoomRun.wave`), so the run's identity, its phase, its one blocked set and its Leave are shared, not
/// copied.
///
/// Nothing here is a real Wave: no delivery, notification, receipt, conversation, chat, Keep, quota,
/// timer or clock. There is one viewer (`WaveParticipant.viewer`) throughout; the counterpart is the one
/// sample of the viewer's own intent (Social → Maya, Business → Jules, Activity → Sam, Dating → Riley).
/// Each explicit start creates a
/// fresh immutable invitation identity; nothing turns an outgoing invitation into an incoming one, and no
/// closed invitation ever becomes pending or accepted again. The run keeps every closed one, append-only, in
/// `RoomRun.closedInvitations` for as long as the run exists (in memory only).
public enum WaveCopy {
    // Chrome
    public static let brand = "Proximeet"
    public static let composeBrand = "Private invitation"

    // Menu (74:568)
    public static let menuHeadline = ["Every hello", "needs a choice."]
    public static func roleExplanation(viewer: String) -> String { "You are \(viewer) in both examples." }
    public static let menuBoundary = "Choose a new, independent demo.\nNo invitation is sent to anyone."
    /// Once the counterpart is blocked the three choices stay, with their own labels, disabled; this one
    /// generic line takes the boundary's place. It names nobody (founder decision, 30 September 2026).
    public static let menuBlocked = "Connection blocked.\nNew examples are unavailable in this demo."
    /// VoiceOver's hint on each disabled choice.
    public static let startBlockedHint = "Unavailable. Connection blocked."
    /// The menu's visible Back (the 75:119 chrome pattern): to the Room that opened the Wave.
    public static let menuBackHint = "Returns to the Room. Nothing is sent."
    public static let startOutgoing = "Start outgoing example"
    public static let startIncoming = "Start incoming example"
    public static let showNoAllowance = "Show no-allowance example"
    public static let leave = "Leave and disappear"

    // Venue ticket
    public static let session = "Demo session · until 10 pm"
    /// "[Viewer] · [Intent] · [Approach]": the viewer's own actual values, never the counterpart's.
    public static func viewerPreference(viewer: String, intent: BandIntent, approach: ApproachSignal) -> String {
        "\(viewer) · \(intent.title) · \(approach.title)"
    }

    // Active invitation screens
    public static func stateContext(_ direction: WaveDirection, viewer: String) -> String {
        "\(direction == .outgoing ? "OUTGOING" : "INCOMING") · YOU ARE \(viewer.uppercased())"
    }
    /// The name a participant is written with: the actual Guest List name for `.viewer`, a sample's own
    /// name otherwise. The viewer is recognised by participant identity alone, never by comparing names, so
    /// a guest who typed "Maya" meeting the sample Maya keeps the name exactly as typed (founder decision,
    /// 30 September 2026).
    public static func name(of participant: WaveParticipant, viewer: String) -> String {
        switch participant {
        case .viewer: return viewer
        case .sample(let actor): return actor.name
        }
    }

    /// "ALEX → MAYA · OUTGOING", "MAYA → ALEX · INCOMING" and "MAYA + ALEX · INCOMING DEMO": the sender,
    /// then the recipient, from the invitation's own participants. Nil off the four active screens, and nil
    /// when the participants are malformed or disagree with the screen's direction.
    public static func directionLine(_ screen: WaveScreen, sender: WaveParticipant, recipient: WaveParticipant,
                                     viewer: String) -> String? {
        guard let outgoing = direction(screen, sender: sender, recipient: recipient) else { return nil }
        let from = name(of: sender, viewer: viewer).uppercased()
        let to = name(of: recipient, viewer: viewer).uppercased()
        switch screen {
        case .outgoingConfirm, .outgoingPending: return outgoing ? "\(from) → \(to) · OUTGOING" : nil
        case .incomingReview: return outgoing ? nil : "\(from) → \(to) · INCOMING"
        case .incomingAccepted: return outgoing ? nil : "\(from) + \(to) · INCOMING DEMO"
        default: return nil
        }
    }

    public static func directionLine(_ invitation: WaveInvitation, on screen: WaveScreen, viewer: String) -> String? {
        directionLine(screen, sender: invitation.sender, recipient: invitation.recipient, viewer: viewer)
    }

    /// The direction line as VoiceOver reads it, in sentence case, sender before recipient. Whichever
    /// participant is `.viewer` is read as "you", with the actual name after it ("From you (Maya) to Maya.
    /// Outgoing."): "you" comes from the participant's identity, never from a name.
    public static func directionSpoken(_ screen: WaveScreen, sender: WaveParticipant, recipient: WaveParticipant,
                                       viewer: String) -> String? {
        guard let outgoing = direction(screen, sender: sender, recipient: recipient) else { return nil }
        func spoken(_ participant: WaveParticipant) -> String {
            participant == .viewer ? "you (\(viewer))" : name(of: participant, viewer: viewer)
        }
        let from = spoken(sender), to = spoken(recipient)
        switch screen {
        case .outgoingConfirm, .outgoingPending: return outgoing ? "From \(from) to \(to). Outgoing." : nil
        case .incomingReview: return outgoing ? nil : "From \(from) to \(to). Incoming."
        case .incomingAccepted: return outgoing ? nil : "\(from) and \(to). Incoming demo."
        default: return nil
        }
    }

    public static func directionSpoken(_ invitation: WaveInvitation, on screen: WaveScreen, viewer: String) -> String? {
        directionSpoken(screen, sender: invitation.sender, recipient: invitation.recipient, viewer: viewer)
    }

    /// Outgoing (true) or incoming (false) from who sent it, or nil for a malformed pair.
    private static func direction(_ screen: WaveScreen, sender: WaveParticipant, recipient: WaveParticipant) -> Bool? {
        guard sender != recipient, (sender == .viewer) != (recipient == .viewer) else { return nil }
        return sender == .viewer
    }
    public static func invitationTitle(_ screen: WaveScreen, counterpart: RoomActor) -> String? {
        switch screen {
        case .outgoingConfirm:
            switch counterpart.intent {
            case .business: return "An idea worth sharing."
            case .social: return "A little company."
            case .activity: return "A plan to join."
            case .dating: return "A spark to explore."
            }
        case .outgoingPending: return "Waiting for \(counterpart.name)."
        case .incomingReview: return "An invitation for you."
        case .incomingAccepted: return "You both said yes."
        default: return nil
        }
    }
    public static func invitationPurpose(_ screen: WaveScreen, counterpart: RoomActor) -> String? {
        switch screen {
        case .outgoingConfirm:
            switch counterpart.intent {
            case .business: return "A private hello about ideas and opportunities."
            case .social: return "A private hello for coffee and conversation."
            case .activity: return "A private hello for a walk, workout, or game."
            case .dating: return "A private hello to see if the interest is mutual."
            }
        case .outgoingPending: return "Only \(counterpart.name) can accept.\nYou can withdraw at any time."
        case .incomingReview: return "Accept only if you want to.\nNo explanation needed to decline."
        case .incomingAccepted: return "A temporary private chat\ncan open next."
        default: return nil
        }
    }
    /// The recipient keeps the choice, separately from the intent-specific invitation wording.
    public static func recipientChoice(counterpart: RoomActor) -> String {
        "\(counterpart.name) chooses whether to accept."
    }
    public static func boundary(_ screen: WaveScreen) -> String? {
        switch screen {
        case .outgoingConfirm: return "Wave allowance available in this demo.\nNothing is sent."
        case .outgoingPending: return "This is your outgoing invitation.\nNothing is sent."
        case .incomingReview: return "A separate incoming example.\nNothing is sent."
        case .incomingAccepted: return "Both agreed to a temporary chat in this demo.\nChat and Keep come next."
        default: return nil
        }
    }
    public static let demoCases = "Demo cases"
    public static let send = "Send private invitation"
    public static let withdraw = "Withdraw Wave"
    public static let accept = "Accept Wave"
    public static let decline = "Decline Wave"
    public static let aboutPrivateChat = "About private chat"

    // Closed screens
    public static let closedLabel = "AN INVITATION"
    public static let closedChoice = "There is always room to choose."
    public static let closedBoundary = "Demo state · no active invitation."
    public static let backToMenu = "Back to demo menu"
    public static let returnToPlaces = "Return to Places"
    public static func closedHeadline(_ screen: WaveScreen) -> [String]? {
        switch screen {
        case .outgoingWithdrawn: return ["Wave", "withdrawn."]
        case .incomingDeclined: return ["Your choice.", "No pressure."]
        case .unavailable: return ["Wave", "unavailable."]
        case .blocked: return ["Connection", "blocked."]
        case .allowanceUnavailable: return ["No Wave", "allowance."]
        case .sessionEnded: return ["You’ve left", "the room."]
        case .incomingWithdrawn: return ["Invitation", "withdrawn."]
        default: return nil
        }
    }
    public static func closedExplanation(_ screen: WaveScreen) -> String? {
        switch screen {
        case .outgoingWithdrawn: return "This outgoing example is closed.\nIt cannot open a chat."
        case .incomingDeclined: return "This incoming Wave is declined and closed.\nNo explanation needed."
        case .unavailable: return "This example expired or the session\nis no longer eligible."
        case .blocked: return "The other person’s sample card and invitation\nare hidden in this demo."
        case .allowanceUnavailable: return "No Wave allowance in this example.\nThis demo does not define a production quota."
        case .sessionEnded: return "The demo session is ended.\nNo active invitation or chat remains."
        case .incomingWithdrawn: return "The sender withdrew this invitation.\nAccept is no longer available."
        default: return nil
        }
    }

    // Overlays (74:580–74:586)
    public static let previewLabel = "DEMO PREVIEW"
    public static let controlsLabel = "DEMO REVIEW CONTROLS"
    public static let safetyTitle = ["Your choice", "comes first."]
    public static let safetyExplanation =
        "You can leave at any time. Demo reports stay local, and no invitation is sent to anyone."
    public static let close = "Close"
    public static func counterpartSafetyTitle(_ actor: RoomActor) -> String { "\(actor.name) · safety" }
    public static let counterpartSafetyExplanation =
        "Blocking hides this fictional person’s card and invitation from the current example."
    public static func block(_ actor: RoomActor) -> String { "Block \(actor.name) in demo" }
    public static let previewReport = "Preview report"
    public static let back = "Back"
    public static func reportTitle(_ actor: RoomActor) -> String { "Report \(actor.name)" }
    public static let reportExplanation = "Choose a sample reason.\nExample only — nothing is submitted."
    public static let closePreview = "Close preview"
    public static let chatTitle = ["A private chat.", "By mutual choice."]
    public static let chatExplanation =
        "Both people have agreed in this incoming demo. Private Chat and Keep are the next chapter."
    public static let conditionsTitle = ["Try a closed", "example."]
    public static let conditionsExplanation =
        "These controls choose static demo conditions. No timer or real session is running."
    public static let showExpired = "Show expired example"
    public static let showSenderWithdrawn = "Show sender withdrawn"
}

/// A participant of this demo, by identity. The viewer is one fixed identity for the whole process
/// (`.viewer`): distinct from every sample's (`.sample(actor)`) by construction, and independent of any
/// name (a guest may well be called "Maya"). The samples are the Room's fictional people. The founder
/// accepted the fixed viewer identity for this bounded demo on 30 September 2026, on those conditions and
/// on every invitation re-validating the current Room run (see `WaveDemo.apply`).
public enum WaveParticipant: Hashable, Sendable {
    case viewer
    case sample(RoomActor)
}

public enum WaveDirection: String, Hashable, Sendable {
    case outgoing
    case incoming
}

/// One invitation's state. Compose, pending and accepted are active; everything else is terminal for
/// that identity and never changes again.
public enum WaveStatus: String, CaseIterable, Hashable, Sendable {
    case compose
    case pending
    case accepted
    case withdrawn
    case declined
    case senderWithdrawn
    case unavailable
    case blocked
    case sessionEnded

    public var isTerminal: Bool {
        switch self {
        case .compose, .pending, .accepted: return false
        default: return true
        }
    }
}

/// An invitation's immutable identity: its run and its place in that run's explicit starts. Runs are never
/// reused in a process (`RoomRunID`), and the sequence only grows within a run, so no identity recurs.
public struct WaveInvitationID: Hashable, Sendable, CustomStringConvertible {
    public let run: RoomRunID
    public let sequence: Int

    public var description: String { "wave \(run.value)-\(sequence)" }
}

/// One fictional invitation. Everything but `status` is fixed at creation; `status` changes only through
/// the guarded transitions in this file.
public struct WaveInvitation: Equatable, Sendable {
    public let id: WaveInvitationID
    public let roomRunID: RoomRunID
    public let sender: WaveParticipant
    public let recipient: WaveParticipant
    public let venue: Venue
    public let intent: BandIntent
    public let direction: WaveDirection
    public fileprivate(set) var status: WaveStatus

    /// Well-formed only: sender and recipient differ, exactly one is the viewer, the direction follows
    /// from who sent it, the identity belongs to the run, and it starts at compose (outgoing) or pending
    /// (incoming). Anything else, such as a self-addressed fixture, is rejected.
    init?(id: WaveInvitationID, roomRunID: RoomRunID, sender: WaveParticipant, recipient: WaveParticipant,
          venue: Venue, intent: BandIntent) {
        guard sender != recipient, (sender == .viewer) != (recipient == .viewer), id.run == roomRunID else {
            return nil
        }
        self.id = id
        self.roomRunID = roomRunID
        self.sender = sender
        self.recipient = recipient
        self.venue = venue
        self.intent = intent
        direction = sender == .viewer ? .outgoing : .incoming
        status = direction == .outgoing ? .compose : .pending
    }

    /// The sample on the other side.
    public var counterpart: RoomActor? {
        switch direction == .outgoing ? recipient : sender {
        case .sample(let actor): return actor
        case .viewer: return nil
        }
    }
}

/// The explicitly chosen demo allowance condition: no count, refill, refund, cooldown or timer.
public enum WaveAllowance: Hashable, Sendable {
    case available
    case unavailable
}

/// What the Wave shows below any overlay: the menu (no invitation), one invitation (active or closed), or
/// the no-allowance example (no invitation). Once the counterpart is blocked no start runs: the menu's
/// three choices are disabled with one generic explanation (founder decision, 30 September 2026), so the
/// blocked screen (74:576) is reached only by blocking over an active invitation.
public enum WaveExample: Equatable, Sendable {
    case menu
    case invitation(WaveInvitation)
    case noAllowance
}

/// The Wave's modal layers, bottom to top. Closing one returns to its caller, which is always the level
/// below (or the screen).
public enum WaveOverlay: Hashable, Sendable {
    case globalSafety
    case counterpartSafety
    case report(RoomReportReason?)
    case chatInformation
    case conditions

    var kind: Int {
        switch self {
        case .globalSafety: return 0
        case .counterpartSafety: return 1
        case .report: return 2
        case .chatInformation: return 3
        case .conditions: return 4
        }
    }
}

/// The labelled demo conditions each "Demo cases" overlay offers.
public enum WaveCondition: Hashable, Sendable {
    case expired
    case senderWithdrawn
}

public enum WaveRings: Hashable, Sendable {
    case separate
    case joined
    case absent
}

public enum WaveChrome: Hashable, Sendable {
    /// Brand, DEMO and Safety (75:111).
    case room
    /// Back, "Wave", DEMO and Safety (75:119): the unsent confirmation (Back discards it) and, by the
    /// existing Back pattern used to meet the founder's decision of 30 September 2026, the menu (Back
    /// returns to the Room).
    case back
    /// Brand and DEMO only (75:130): the ended screen.
    case plain
}

/// The twelve approved screens (Figma 74:568–74:579), derived from the state each time.
public enum WaveScreen: String, CaseIterable, Hashable, Sendable {
    case menu = "demo-menu"
    case outgoingConfirm = "out-confirm"
    case outgoingPending = "out-pending"
    case outgoingWithdrawn = "out-withdrawn"
    case incomingReview = "in-review"
    case incomingDeclined = "in-declined"
    case incomingAccepted = "in-accepted"
    case unavailable
    case blocked
    case allowanceUnavailable = "allowance-unavailable"
    case sessionEnded = "session-ended"
    case incomingWithdrawn = "in-withdrawn"

    public var figmaNode: String {
        switch self {
        case .menu: return "74:568"
        case .outgoingConfirm: return "74:569"
        case .outgoingPending: return "74:570"
        case .outgoingWithdrawn: return "74:571"
        case .incomingReview: return "74:572"
        case .incomingDeclined: return "74:573"
        case .incomingAccepted: return "74:574"
        case .unavailable: return "74:575"
        case .blocked: return "74:576"
        case .allowanceUnavailable: return "74:577"
        case .sessionEnded: return "74:578"
        case .incomingWithdrawn: return "74:579"
        }
    }

    /// An active invitation with the counterpart's identity on screen.
    public var showsCounterpart: Bool {
        switch self {
        case .outgoingConfirm, .outgoingPending, .incomingReview, .incomingAccepted: return true
        default: return false
        }
    }

    /// The closed screens with "Back to demo menu".
    public var isClosed: Bool {
        switch self {
        case .outgoingWithdrawn, .incomingDeclined, .unavailable, .blocked, .allowanceUnavailable,
             .incomingWithdrawn: return true
        default: return false
        }
    }

    public var rings: WaveRings {
        switch self {
        case .menu, .outgoingConfirm, .outgoingPending, .incomingReview: return .separate
        case .incomingAccepted: return .joined
        default: return .absent
        }
    }

    public var chrome: WaveChrome {
        switch self {
        case .menu, .outgoingConfirm: return .back
        case .sessionEnded: return .plain
        default: return .room
        }
    }

    /// The chrome's shield: the counterpart's safety over an active invitation, global safety over the menu
    /// and the closed screens, none once ended.
    public var safety: WaveOverlay? {
        if showsCounterpart { return .counterpartSafety }
        if self == .menu || isClosed { return .globalSafety }
        return nil
    }

    /// "Demo cases": outgoing pending and accepted offer the expired example; incoming review also offers
    /// sender withdrawn. None elsewhere (the confirmation has no Demo cases control).
    public var conditions: [WaveCondition] {
        switch self {
        case .outgoingPending, .incomingAccepted: return [.expired]
        case .incomingReview: return [.expired, .senderWithdrawn]
        default: return []
        }
    }
}

/// Every Wave control, each carrying what it was drawn for, so a late, repeated or stale tap (from a
/// screen, an overlay or an invitation that is no longer current) changes nothing.
public enum WaveAction: Hashable, Sendable {
    case startOutgoing
    case startIncoming
    case showNoAllowance
    /// The confirmation's chrome Back: discards the unsent invitation; its identity is never reused.
    case discardCompose(WaveInvitationID)
    case send(WaveInvitationID)
    case withdraw(WaveInvitationID)
    case accept(WaveInvitationID)
    case decline(WaveInvitationID)
    case openConditions(WaveInvitationID)
    case showExpired(WaveInvitationID)
    case showSenderWithdrawn(WaveInvitationID)
    case openChatInformation(WaveInvitationID)
    /// "Back to demo menu" on a closed screen.
    case backToMenu(from: WaveScreen)
    /// The chrome's shield, drawn on `from`.
    case openSafety(from: WaveScreen)
    case previewReport
    case selectReportReason(RoomReportReason)
    /// Close / Back / Close preview on the top overlay, which must still be `overlay`'s kind.
    case closeOverlay(WaveOverlay)
    /// "Block [Name] in demo" on the counterpart's safety, carrying the actor and the Room run it was drawn
    /// for: a queued Block affects only that actor in that same, still valid run (founder decision,
    /// 30 September 2026). Applied by `RoomRun`, which owns the blocks.
    case blockCounterpart(RoomActor, run: RoomRunID)
}

/// The contract's acceptance guards, in order; the first one that fails is the refusal.
public enum WaveAcceptanceGuard: Hashable, Sendable, CaseIterable {
    case sameWaveID
    case sameRoomRun
    case pending
    case viewerIsRecipient
    case senderDiffersFromRecipient
    case roomPopulatedAndActive
    case sameVenue
    case sameIntent
    case noBlockOrInvalidation
}

/// The central Room facts every Wave action is checked against, read from the run at action time.
struct WaveCentral {
    let runID: RoomRunID
    let active: Bool
    let populated: Bool
    let blocked: Set<RoomActor>
    let intent: BandIntent
    let venue: Venue
}

/// The Wave demo of one Room run: its counterpart, the viewer's actual name and values (read once, when
/// it opened), the current example and the overlay stack.
public struct WaveDemo: Equatable, Sendable {
    public let counterpart: RoomActor
    /// The actual Guest List display name (card-trimmed). Copy only, never identity.
    public let viewerName: String
    public let intent: BandIntent
    public let approach: ApproachSignal
    public let venue: Venue
    public private(set) var example: WaveExample
    public private(set) var overlays: [WaveOverlay] = []
    public private(set) var allowance: WaveAllowance = .available
    /// Set once by Leave; nothing clears it.
    public private(set) var ended = false

    init(counterpart: RoomActor, viewerName: String, intent: BandIntent, approach: ApproachSignal, venue: Venue,
         example: WaveExample = .menu) {
        self.counterpart = counterpart
        self.viewerName = viewerName
        self.intent = intent
        self.approach = approach
        self.venue = venue
        self.example = example
    }

    // MARK: - What is shown

    public var invitation: WaveInvitation? {
        if case .invitation(let invitation) = example { return invitation }
        return nil
    }

    public var screen: WaveScreen {
        if ended { return .sessionEnded }
        switch example {
        case .menu: return .menu
        case .noAllowance: return .allowanceUnavailable
        case .invitation(let invitation):
            switch (invitation.direction, invitation.status) {
            case (.outgoing, .compose): return .outgoingConfirm
            case (.outgoing, .pending): return .outgoingPending
            case (.outgoing, .withdrawn): return .outgoingWithdrawn
            case (.incoming, .pending): return .incomingReview
            case (.incoming, .accepted): return .incomingAccepted
            case (.incoming, .declined): return .incomingDeclined
            case (.incoming, .senderWithdrawn): return .incomingWithdrawn
            case (_, .blocked): return .blocked
            case (_, .sessionEnded): return .sessionEnded
            default: return .unavailable   // .unavailable, and (fail closed) any malformed pair
            }
        }
    }

    /// The counterpart, only while an active invitation shows them.
    public var visibleCounterpart: RoomActor? { screen.showsCounterpart ? counterpart : nil }

    /// The overlay on top, if any.
    public var overlay: WaveOverlay? { overlays.last }

    // MARK: - Transitions (called by `RoomRun.perform`)

    /// Applies one action against the current central facts. `nextID` is the identity a start would use.
    mutating func apply(_ action: WaveAction, central: WaveCentral, nextID: WaveInvitationID) -> Bool {
        guard central.active, central.populated, !ended else { return false }
        let eligible = !central.blocked.contains(counterpart) && counterpart.intent == central.intent
            && intent == central.intent && venue == central.venue
        switch action {
        case .startOutgoing, .startIncoming, .showNoAllowance:
            // Disabled once the counterpart is blocked (or otherwise ineligible): nothing starts, nothing is
            // shown in its place, and no identity is issued.
            guard example == .menu, overlays.isEmpty, eligible else { return false }
            switch action {
            case .showNoAllowance:
                allowance = .unavailable
                example = .noAllowance
                return true
            case .startOutgoing:
                guard let invitation = WaveInvitation(id: nextID, roomRunID: central.runID, sender: .viewer,
                                                      recipient: .sample(counterpart), venue: venue, intent: intent)
                else { return false }
                allowance = .available
                example = .invitation(invitation)
                return true
            default:
                guard let invitation = WaveInvitation(id: nextID, roomRunID: central.runID,
                                                      sender: .sample(counterpart), recipient: .viewer,
                                                      venue: venue, intent: intent)
                else { return false }
                example = .invitation(invitation)
                return true
            }

        case .discardCompose(let id):
            guard overlays.isEmpty, let current = current(id, central), current.direction == .outgoing,
                  current.status == .compose
            else { return false }
            example = .menu
            return true

        case .send(let id):
            guard overlays.isEmpty, eligible, allowance == .available, var current = current(id, central),
                  current.direction == .outgoing, current.sender == .viewer, current.status == .compose
            else { return false }
            current.status = .pending
            example = .invitation(current)
            return true

        case .withdraw(let id):
            guard overlays.isEmpty, var current = current(id, central), current.direction == .outgoing,
                  current.sender == .viewer, current.status == .pending
            else { return false }
            current.status = .withdrawn
            example = .invitation(current)
            return true

        case .accept(let id):
            guard overlays.isEmpty, acceptanceRefusal(id, central: central) == nil, var current = invitation
            else { return false }
            current.status = .accepted
            example = .invitation(current)
            return true

        case .decline(let id):
            guard overlays.isEmpty, var current = current(id, central), current.direction == .incoming,
                  current.recipient == .viewer, current.status == .pending
            else { return false }
            current.status = .declined
            example = .invitation(current)
            return true

        case .openConditions(let id):
            guard overlays.isEmpty, current(id, central) != nil, eligible, !screen.conditions.isEmpty else { return false }
            overlays = [.conditions]
            return true

        case .showExpired(let id):
            guard overlays == [.conditions], var current = current(id, central), screen.conditions.contains(.expired)
            else { return false }
            current.status = .unavailable
            example = .invitation(current)
            overlays = []
            return true

        case .showSenderWithdrawn(let id):
            guard overlays == [.conditions], var current = current(id, central),
                  screen.conditions.contains(.senderWithdrawn), current.direction == .incoming,
                  current.status == .pending
            else { return false }
            current.status = .senderWithdrawn
            example = .invitation(current)
            overlays = []
            return true

        case .openChatInformation(let id):
            guard overlays.isEmpty, eligible, current(id, central) != nil, screen == .incomingAccepted else { return false }
            overlays = [.chatInformation]
            return true

        case .backToMenu(let from):
            guard overlays.isEmpty, screen == from, from.isClosed else { return false }
            example = .menu
            return true

        case .openSafety(let from):
            guard overlays.isEmpty, screen == from, let safety = from.safety else { return false }
            if safety == .counterpartSafety, !eligible { return false }
            overlays = [safety]
            return true

        case .previewReport:
            guard overlays.last == .counterpartSafety, eligible else { return false }
            overlays.append(.report(nil))
            return true

        case .selectReportReason(let reason):
            guard case .report(let selected)? = overlays.last, selected != reason, eligible else { return false }
            overlays[overlays.count - 1] = .report(reason)
            return true

        case .closeOverlay(let which):
            guard let top = overlays.last, top.kind == which.kind else { return false }
            overlays.removeLast()
            if !Self.isValidStack(overlays, on: screen, eligible: eligible) { overlays = [] }
            return true

        case .blockCounterpart:
            return false   // `RoomRun.perform` applies it, with the central block set.
        }
    }

    /// The invitation on screen when it is `id` and belongs to the current Room run: every invitation
    /// control re-validates both, so a handle from another invitation or another run changes nothing.
    private func current(_ id: WaveInvitationID, _ central: WaveCentral) -> WaveInvitation? {
        guard let shown = invitation, shown.id == id, shown.roomRunID == central.runID, shown.id.run == central.runID
        else { return nil }
        return shown
    }

    /// The first acceptance guard that fails for `id` right now, or `nil` when Accept may commit.
    func acceptanceRefusal(_ id: WaveInvitationID, central: WaveCentral) -> WaveAcceptanceGuard? {
        guard let current = invitation, current.id == id else { return .sameWaveID }
        guard current.roomRunID == central.runID, current.id.run == central.runID else { return .sameRoomRun }
        guard current.status == .pending, current.direction == .incoming else { return .pending }
        guard current.recipient == .viewer else { return .viewerIsRecipient }
        guard current.sender != current.recipient, current.sender == .sample(counterpart) else {
            return .senderDiffersFromRecipient
        }
        guard central.active, central.populated, !ended else { return .roomPopulatedAndActive }
        guard current.venue == central.venue, venue == central.venue else { return .sameVenue }
        guard current.intent == central.intent, counterpart.intent == central.intent, intent == central.intent
        else { return .sameIntent }
        guard !central.blocked.contains(counterpart) else { return .noBlockOrInvalidation }
        return nil
    }

    /// Block: the active invitation (if any) closes as blocked and every overlay goes. The caller has
    /// already added the counterpart to the central set.
    mutating func invalidateForBlock() {
        if var current = invitation, !current.status.isTerminal {
            current.status = .blocked
            example = .invitation(current)
        }
        overlays = []
    }

    /// Leave: every overlay goes, an active invitation closes as session ended, and the Wave shows its
    /// ended screen. Terminal invitations keep their own terminal status.
    mutating func end() {
        if var current = invitation, !current.status.isTerminal {
            current.status = .sessionEnded
            example = .invitation(current)
        }
        overlays = []
        ended = true
    }

    /// What the outer Back (a completed edge swipe, VoiceOver's escape) means here.
    enum OuterBack { case closedOverlay, closedExample, exitToRoom, none }

    mutating func outerBack(central: WaveCentral) -> OuterBack {
        guard !ended else { return .none }
        if let top = overlays.last {
            return apply(.closeOverlay(top), central: central, nextID: WaveInvitationID(run: central.runID, sequence: 0))
                ? .closedOverlay : .none
        }
        if screen == .outgoingConfirm {
            example = .menu   // the unsent invitation is discarded; its identity is never reused
            return .closedExample
        }
        if screen.isClosed {
            example = .menu
            return .closedExample
        }
        if screen == .menu { return .exitToRoom }
        return .none   // pending, review and accepted have no Back: never back to a stale compose
    }

    // MARK: - Consistency

    func isConsistent(central: WaveCentral) -> Bool {
        guard counterpart.intent == intent, intent == central.intent, venue == central.venue else { return false }
        if let current = invitation {
            guard current.roomRunID == central.runID, current.id.run == central.runID,
                  current.sender != current.recipient, (current.sender == .viewer) != (current.recipient == .viewer),
                  current.counterpart == counterpart, current.venue == venue, current.intent == intent
            else { return false }
            let legal: Set<WaveStatus> = current.direction == .outgoing
                ? [.compose, .pending, .withdrawn, .unavailable, .blocked, .sessionEnded]
                : [.pending, .accepted, .declined, .senderWithdrawn, .unavailable, .blocked, .sessionEnded]
            guard legal.contains(current.status) else { return false }
            if central.blocked.contains(counterpart), !current.status.isTerminal { return false }
            if ended, !current.status.isTerminal { return false }
        }
        if ended { return overlays.isEmpty }
        if central.blocked.contains(counterpart), screen.showsCounterpart { return false }
        let eligible = !central.blocked.contains(counterpart)
        return Self.isValidStack(overlays, on: screen, eligible: eligible)
    }

    static func isValidStack(_ stack: [WaveOverlay], on screen: WaveScreen, eligible: Bool) -> Bool {
        guard let first = stack.first else { return true }
        switch first {
        case .globalSafety:
            return stack.count == 1 && screen.safety == .globalSafety
        case .counterpartSafety:
            guard eligible, screen.safety == .counterpartSafety else { return false }
            switch stack.count {
            case 1: return true
            case 2: if case .report = stack[1] { return true } else { return false }
            default: return false
            }
        case .chatInformation:
            return stack.count == 1 && eligible && screen == .incomingAccepted
        case .conditions:
            return stack.count == 1 && eligible && !screen.conditions.isEmpty
        case .report:
            return false
        }
    }
}
