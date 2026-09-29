import Foundation

/// Chapter 08, the approved Room: a bounded, local, explicitly fictional demo of what a venue room
/// could feel like, opened only from Common Ground's check-in explanation.
///
/// Nothing here is a live room. No real person, check-in, location, camera, network, server, report
/// or message exists; the two people are fictional samples; the "until 10 pm" label belongs to the
/// fixed Thursday 8 pm snapshot of Places, and no clock is read. The model is separate from `DemoFlow`
/// and `DemoDraft`: it reads the actual intent and approach once, when the preview opens, and never
/// writes to the draft or grants anything. It lives in memory only, so a relaunch restores no run.
///
/// Two deliberate gates, and nothing else, move it forward: "Enter room demo" starts a new run in
/// waiting, and the labelled demo control "Show populated example" reveals the fictional sample. No
/// time, animation completion, navigation, background/resume or redraw stands in for either.
public enum RoomCopy {
    public static let entryHeadline = ["Come in.", "Stay yourself."]
    public static let entrySupport = "Try the Room with fictional people."
    public static let entrySession = "Fictional venue · demo until 10 pm"
    public static let entryBoundary = "This demo does not verify a venue visit\nor make you visible."
    public static let enter = "Enter room demo"
    public static let entryBack = "Back"

    public static let compactSession = "Demo session · until 10 pm"
    public static let envelopeLabel = "INTRODUCTIONS"
    public static let envelopePrivacy = "A little privacy comes first."
    public static let waitingHeadline = ["A little privacy.", "Before a hello."]
    public static let waitingExplanation = "Introductions appear only when a venue session has enough people checked in."
    public static let demoControl = "DEMO CONTROL"
    public static let showPopulated = "Show populated example"
    public static let leave = "Leave and disappear"

    public static let peopleTab = "People"
    public static let notesTab = "Room notes"
    public static let peopleFraming = "SAMPLE INTRODUCTIONS"
    public static let notesFraming = "READ-ONLY DEMO NOTES"
    public static let viewCard = "View card  →"
    public static let unblockedBoundary = "Fictional cards. Nothing is sent."
    public static let blockedBoundary = "Your demo blocks remain applied."
    public static let emptyTitle = ["No sample introductions", "to show."]
    public static let emptyExplanation = "Your demo blocks are still applied."
    public static let hiddenNotesBoundary = "Blocked sample notes stay hidden."

    public static let hostLabel = "HOST NOTE · COMMON GROUND"
    public static let hostMessage = "Keep it kind. A hello is always optional."
    public static let icebreakerLabel = "A SMALL ICEBREAKER"
    public static let icebreaker = "What’s a small place that feels like home?"

    public static let profileTitle = "Room"
    public static let profileLabel = "FICTIONAL PROFILE"
    public static let howWavesWork = "How Waves work"
    public static let backToPeople = "Back to people"
    /// The incompatible actor's last line: Waves stay within the guest's own intent.
    public static let sameIntentExplanation = "Waves stay within your selected intent."

    public static let overlayLabel = "DEMO PREVIEW"
    public static let safetyTitle = ["Your space.", "Your choice."]
    public static let safetyExplanation =
        "Open a sample card to block or preview a report. Blocking hides its introduction and public notes in this demo."
    public static let close = "Close"
    public static let actorSafetyExplanation =
        "Blocking hides this fictional person’s card and public notes from the current demo."
    public static let previewReport = "Preview report"
    public static let actorSafetyBack = "Back"
    public static let reportExplanation = "Choose a sample reason.\nExample only — nothing is submitted."
    public static let closePreview = "Close preview"
    public static let waveTitle = ["A Wave is", "an invitation."]
    public static let waveExplanation = "Chat opens only after the other person accepts."
    public static let waveScope = "Sending Waves comes in the next preview."
    public static let backToProfile = "Back to profile"

    public static let endedStatus = "DEMO SESSION ENDED"
    public static let endedHeadline = ["You’ve left", "the room."]
    public static let endedExplanation = "Sample cards and notes are now hidden.\nA new demo requires an explicit restart."
    public static let returnToPlaces = "Return to Places"

    /// "[Intent] · [Approach]", the actual guest's line on the venue ticket.
    public static func preference(intent: BandIntent, approach: ApproachSignal) -> String {
        "\(intent.title) · \(approach.title)"
    }

    /// "Block [Name] in demo".
    public static func block(_ actor: RoomActor) -> String { "Block \(actor.name) in demo" }
    /// "[Name] · safety".
    public static func actorSafetyTitle(_ actor: RoomActor) -> String { "\(actor.name) · safety" }
    /// "Report [Name]".
    public static func reportTitle(_ actor: RoomActor) -> String { "Report \(actor.name)" }
}

/// The two fictional sample people. Abstract initials, fictional names and words: never a real person,
/// never a count of anyone, and never a privacy threshold. Two cards are two illustrations.
public enum RoomActor: String, CaseIterable, Identifiable, Hashable, Sendable {
    case maya
    case jules

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .maya: return "Maya"
        case .jules: return "Jules"
        }
    }

    public var initials: String {
        switch self {
        case .maya: return "ML"
        case .jules: return "JR"
        }
    }

    /// The sample's own intent and approach: never the guest's, and never changed by the guest's.
    public var intent: BandIntent {
        switch self {
        case .maya: return .social
        case .jules: return .business
        }
    }

    public var approach: ApproachSignal {
        switch self {
        case .maya: return .chatFirst
        case .jules: return .okayToSayHello
        }
    }

    /// "[Intent] · [Approach]" on the card and the profile.
    public var line: String { RoomCopy.preference(intent: intent, approach: approach) }

    /// The card's introduction (the first line of the profile's About).
    public var introduction: String {
        switch self {
        case .maya: return "Coffee, bookshops, and a good detour."
        case .jules: return "Design, ideas, and small businesses."
        }
    }

    /// The profile's second About line.
    public var quote: String {
        switch self {
        case .maya: return "Tell me about a place you’d go back to."
        case .jules: return "Always curious about what people are building."
        }
    }

    public var about: String { "\(introduction)\n\(quote)" }

    public var interests: [String] {
        switch self {
        case .maya: return ["Coffee", "Bookshops", "Detours"]
        case .jules: return ["Design", "Ideas", "Small business"]
        }
    }

    /// The sample's own approach, described in words the earlier chapters approved: Maya's is the
    /// approved profile line; Jules's reuses Signal's approved summary of "Okay to say hello" (the
    /// Room handoff approved no compatible-state line for Jules; a recorded deviation).
    public var approachDescription: String {
        switch approach {
        case .chatFirst: return "Prefers a Wave and a chat before meeting."
        case .okayToSayHello: return ApproachSignal.okayToSayHello.summary
        }
    }

    /// Only Jules wrote a public sample note.
    public var publicNote: String? {
        switch self {
        case .maya: return nil
        case .jules: return "One good question can change an evening."
        }
    }

    /// "[Name] · public sample note".
    public var publicNoteLabel: String { "\(name) · public sample note" }
}

public enum RoomTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case people
    case notes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .people: return RoomCopy.peopleTab
        case .notes: return RoomCopy.notesTab
        }
    }
}

/// The three sample reasons of an unsent report preview. Selecting one is local to its preview.
public enum RoomReportReason: String, CaseIterable, Identifiable, Hashable, Sendable {
    case unwantedAttention
    case harassment
    case somethingElse

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unwantedAttention: return "Unwanted attention"
        case .harassment: return "Harassment or harmful content"
        case .somethingElse: return "Something else"
        }
    }
}

/// A run's phase. Waiting shows no sample information at all; populated shows the fictional sample;
/// ended is terminal for the run.
public enum RoomPhase: Hashable, Sendable {
    case waiting
    case populated
    case ended
}

/// One level of the Room's caller hierarchy, from the root screen outwards: a profile over People, and
/// the panels (global safety, an actor's safety, its unsent report, Wave information). Closing one
/// returns to the level below it, which is always its caller.
public enum RoomRoute: Hashable, Sendable {
    case profile(RoomActor)
    case globalSafety
    case actorSafety(RoomActor)
    /// The unsent report preview for an actor, with its local selection (none at first).
    case report(RoomActor, RoomReportReason?)
    case waveInfo(RoomActor)

    /// The actor this level concerns, if any.
    public var actor: RoomActor? {
        switch self {
        case .profile(let actor), .actorSafety(let actor), .report(let actor, _), .waveInfo(let actor):
            return actor
        case .globalSafety:
            return nil
        }
    }
}

/// Identifies one run. A new "Enter room demo" gets a new identity, so a callback captured for an
/// earlier run (a late tap, a finishing animation, a stale route) never acts on a later one.
public struct RoomRunID: Hashable, Sendable, CustomStringConvertible {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public var description: String { "run \(value)" }
}

/// What a profile's action is for the actual guest: Wave information for a same-intent sample, and
/// "Back to people" for another intent. Information only: nothing is sent, created or accepted.
public enum RoomProfileAction: Hashable, Sendable {
    case howWavesWork
    case backToPeople

    public var title: String {
        switch self {
        case .howWavesWork: return RoomCopy.howWavesWork
        case .backToPeople: return RoomCopy.backToPeople
        }
    }
}

/// What the outer Back asked for (a completed back swipe from the leading edge, or VoiceOver's escape).
public enum RoomOuterBack: Hashable, Sendable {
    /// One level of the caller hierarchy was closed.
    case closedLevel
    /// The run was active at its root: it ended at once, as "Leave and disappear" does.
    case left
    /// The run had already ended: the caller may take the guest to Places (its only way out).
    case alreadyEnded
    /// Nothing changed.
    case none
}

/// One local demo run: its phase, the one blocked-actor set, the selected tab and the caller hierarchy.
/// Everything shown is derived from it; views keep no copies.
///
/// Invariants (kept by every transition and checked by `isConsistent`):
/// - Waiting shows no sample: no people, notes, profiles or actor panels; only global safety may open.
/// - Ended shows nothing and has no route.
/// - No route level concerns a blocked actor, and a profile is only ever the first level.
/// - Blocks only grow within a run; nothing removes one.
public struct RoomRun: Equatable, Sendable {
    public let id: RoomRunID
    /// The actual guest's intent and approach, read when the preview opened.
    public let intent: BandIntent
    public let approach: ApproachSignal
    public private(set) var phase: RoomPhase = .waiting
    public private(set) var blocked: Set<RoomActor> = []
    public private(set) var tab: RoomTab = .people
    public private(set) var route: [RoomRoute] = []

    public init(id: RoomRunID, intent: BandIntent, approach: ApproachSignal) {
        self.id = id
        self.intent = intent
        self.approach = approach
    }

    // MARK: - What is shown

    /// Waiting or populated.
    public var isActive: Bool { phase != .ended }

    /// The sample cards on People, in order: only in the populated example, never a blocked actor.
    public var visiblePeople: [RoomActor] {
        guard phase == .populated else { return [] }
        return RoomActor.allCases.filter { !blocked.contains($0) }
    }

    /// The authors of the public sample notes on Room notes: only Jules, and only while visible.
    public var visibleNoteAuthors: [RoomActor] {
        guard phase == .populated else { return [] }
        return RoomActor.allCases.filter { $0.publicNote != nil && !blocked.contains($0) }
    }

    /// The host announcement and icebreaker: shown on Room notes in the populated example, whatever is
    /// blocked.
    public var showsHostNotes: Bool { phase == .populated }

    /// The line under People's cards: fictional and unsent, or that the demo blocks remain applied.
    public var peopleBoundary: String { blocked.isEmpty ? RoomCopy.unblockedBoundary : RoomCopy.blockedBoundary }

    /// Both samples are blocked: People says there are no sample introductions to show (never that the
    /// venue is empty).
    public var showsNoSampleIntroductions: Bool { phase == .populated && visiblePeople.isEmpty }

    /// A blocked actor had written a public note: Room notes says blocked sample notes stay hidden.
    public var showsHiddenNotesBoundary: Bool {
        phase == .populated && blocked.contains { $0.publicNote != nil }
    }

    /// The profile being shown, if any.
    public var profile: RoomActor? {
        if case .profile(let actor)? = route.first { return actor }
        return nil
    }

    /// The panel on top, if any (never a profile).
    public var panel: RoomRoute? {
        guard let top = route.last else { return nil }
        if case .profile = top { return nil }
        return top
    }

    /// The profile's action for the actual guest: Wave information for the same intent only.
    public func profileAction(for actor: RoomActor) -> RoomProfileAction {
        actor.intent == intent ? .howWavesWork : .backToPeople
    }

    /// The profile's last line: the sample's own approach when its intent is the guest's, otherwise the
    /// approved same-intent explanation.
    public func profileBoundary(for actor: RoomActor) -> String {
        profileAction(for: actor) == .howWavesWork ? actor.approachDescription : RoomCopy.sameIntentExplanation
    }

    /// Whether a sample actor may be shown anywhere right now.
    public func showsSample(_ actor: RoomActor) -> Bool {
        phase == .populated && !blocked.contains(actor)
    }

    /// Every invariant at once; used by tests and as a last line of defence.
    public var isConsistent: Bool {
        switch phase {
        case .ended:
            return route.isEmpty
        case .waiting:
            return route.isEmpty || route == [.globalSafety]
        case .populated:
            return Self.isValidRoute(route, run: self)
        }
    }

    // MARK: - The populated example (the second deliberate gate)

    /// The labelled demo control "Show populated example": only in waiting with nothing open.
    @discardableResult
    public mutating func showPopulatedExample() -> Bool {
        guard phase == .waiting, route.isEmpty else { return false }
        phase = .populated
        tab = .people
        return true
    }

    // MARK: - Tabs, cards and profiles

    /// People or Room notes. Only on the populated root; the selected tab does nothing.
    @discardableResult
    public mutating func selectTab(_ newTab: RoomTab) -> Bool {
        guard phase == .populated, route.isEmpty, tab != newTab else { return false }
        tab = newTab
        return true
    }

    /// A card opens its visible actor's profile, from People.
    @discardableResult
    public mutating func openProfile(_ actor: RoomActor) -> Bool {
        guard phase == .populated, route.isEmpty, tab == .people, showsSample(actor) else { return false }
        route = [.profile(actor)]
        return true
    }

    /// "Back to people" on a profile whose intent is not the guest's: the filtered People.
    @discardableResult
    public mutating func backToPeople() -> Bool {
        guard case .profile(let actor)? = route.last, route.count == 1,
              profileAction(for: actor) == .backToPeople
        else { return false }
        route = []
        tab = .people
        return true
    }

    /// "How Waves work" on a same-intent profile: information only.
    @discardableResult
    public mutating func openWaveInfo() -> Bool {
        guard case .profile(let actor)? = route.last, route.count == 1, showsSample(actor),
              profileAction(for: actor) == .howWavesWork
        else { return false }
        route.append(.waveInfo(actor))
        return true
    }

    // MARK: - Safety

    /// The chrome's Safety on waiting, People or Room notes.
    @discardableResult
    public mutating func openGlobalSafety() -> Bool {
        guard isActive, route.isEmpty else { return false }
        route = [.globalSafety]
        return true
    }

    /// An actor's safety: from that actor's profile (its Safety), or from a visible public note on Room
    /// notes (its "…" control).
    @discardableResult
    public mutating func openActorSafety(_ actor: RoomActor) -> Bool {
        guard showsSample(actor) else { return false }
        if route == [.profile(actor)] {
            route.append(.actorSafety(actor))
            return true
        }
        guard route.isEmpty, tab == .notes, visibleNoteAuthors.contains(actor) else { return false }
        route = [.actorSafety(actor)]
        return true
    }

    /// "Preview report" on an actor's safety: an unsent preview with nothing selected.
    @discardableResult
    public mutating func previewReport() -> Bool {
        guard case .actorSafety(let actor)? = route.last, showsSample(actor) else { return false }
        route.append(.report(actor, nil))
        return true
    }

    /// Selects a sample reason in the open report preview. Another reason replaces it; the selected
    /// one again does nothing. Nothing is submitted, stored or sent.
    @discardableResult
    public mutating func selectReportReason(_ reason: RoomReportReason) -> Bool {
        guard case .report(let actor, let selected)? = route.last, showsSample(actor), selected != reason
        else { return false }
        route[route.count - 1] = .report(actor, reason)
        return true
    }

    /// Close, Back or Close preview on the top level: back to its caller, everything else kept (the
    /// tab, the phase and the blocks). A report preview's selection is discarded with it.
    @discardableResult
    public mutating func closeLevel() -> Bool {
        guard isActive, !route.isEmpty else { return false }
        route.removeLast()
        return true
    }

    /// "Block [Name] in demo" on that actor's safety (or its report preview): the actor joins the
    /// blocked set at once, every level closes, and the filtered People shows. Existing blocks are
    /// never cleared; there is no unblock.
    @discardableResult
    public mutating func block(_ actor: RoomActor) -> Bool {
        guard phase == .populated, !blocked.contains(actor),
              route.contains(.actorSafety(actor))
        else { return false }
        blocked.insert(actor)
        route = []
        tab = .people
        return true
    }

    // MARK: - Leaving

    /// "Leave and disappear", from any level of an active run: ends it at once, with every level
    /// closed and no sample shown. No confirmation and no reason.
    @discardableResult
    public mutating func leave() -> Bool {
        guard isActive else { return false }
        phase = .ended
        route = []
        tab = .people
        return true
    }

    /// The outer Back (a completed back swipe or VoiceOver's escape): one level of the caller
    /// hierarchy when one is open; from the active root, the terminal Leave; once ended, nothing here
    /// (the caller may return to Places).
    @discardableResult
    public mutating func outerBack() -> RoomOuterBack {
        if !isActive { return .alreadyEnded }
        if !route.isEmpty {
            route.removeLast()
            return .closedLevel
        }
        return leave() ? .left : .none
    }

    // MARK: - Private

    private static func isValidRoute(_ route: [RoomRoute], run: RoomRun) -> Bool {
        for level in route {
            if let actor = level.actor, run.blocked.contains(actor) { return false }
        }
        guard let first = route.first else { return true }
        switch first {
        case .globalSafety:
            return route.count == 1
        case .profile(let actor):
            guard run.tab == .people else { return false }
            let rest = Array(route.dropFirst())
            switch rest.first {
            case nil:
                return true
            case .waveInfo(let other)?:
                return other == actor && rest.count == 1 && run.profileAction(for: actor) == .howWavesWork
            case .actorSafety(let other)?:
                return other == actor && isValidReportTail(Array(rest.dropFirst()), actor: actor)
            default:
                return false
            }
        case .actorSafety(let actor):
            // Opened from a public note on Room notes.
            return run.tab == .notes && actor.publicNote != nil
                && isValidReportTail(Array(route.dropFirst()), actor: actor)
        case .report, .waveInfo:
            return false
        }
    }

    private static func isValidReportTail(_ tail: [RoomRoute], actor: RoomActor) -> Bool {
        switch tail.count {
        case 0: return true
        case 1:
            if case .report(let other, _) = tail[0] { return other == actor }
            return false
        default: return false
        }
    }
}

/// The Room preview opened from Common Ground's check-in explanation: first the entry screen, then (only
/// after "Enter room demo") one run. It exists only above an eligible explanation: the actual intent is
/// Social or Business, the only ones Common Ground's open session permits in the fixed snapshot, with the
/// actual approach and the Birthday gate still valid. It never touches the draft.
public struct RoomPreview: Equatable, Sendable {
    public enum Stage: Equatable, Sendable {
        case entry
        case run(RoomRun)
    }

    public let intent: BandIntent
    public let approach: ApproachSignal
    public private(set) var stage: Stage = .entry

    private init(intent: BandIntent, approach: ApproachSignal) {
        self.intent = intent
        self.approach = approach
    }

    /// "Preview room demo" on the explanation: the entry screen, and only for an eligible explanation.
    /// Opening it starts no run and shows no sample.
    public static func open(after flow: DemoFlow) -> RoomPreview? {
        guard allows(flow), let intent = flow.draft.band, let approach = flow.draft.signal else { return nil }
        return RoomPreview(intent: intent, approach: approach)
    }

    /// Whether a Room preview may exist above this flow: Common Ground's explanation is showing and the
    /// actual intent (Social or Business), the approach and every earlier requirement still hold.
    public static func allows(_ flow: DemoFlow) -> Bool {
        guard flow.currentScene == .placeExplanation,
              flow.placeVenue == CheckInExplanation.venue,
              flow.draft.meetsRequirements(for: .placeExplanation),
              let intent = flow.draft.band, flow.draft.signal != nil
        else { return false }
        return PlaceEligibility(venue: CheckInExplanation.venue, intent: intent).canPreviewCheckIn
    }

    /// Still valid above `flow`: allowed, and with the same actual intent and approach it opened with.
    public func isStillValid(for flow: DemoFlow) -> Bool {
        Self.allows(flow) && flow.draft.band == intent && flow.draft.signal == approach
    }

    /// The run, once entered.
    public var run: RoomRun? {
        if case .run(let run) = stage { return run }
        return nil
    }

    /// "[Intent] · [Approach]" for the venue ticket.
    public var preference: String { RoomCopy.preference(intent: intent, approach: approach) }

    /// "Enter room demo" on the entry screen: a new run, in waiting, with no blocks, on People. Only
    /// from the entry screen, so a repeated tap (the run is then showing) starts nothing.
    @discardableResult
    public mutating func enter(as id: RoomRunID) -> Bool {
        guard stage == .entry else { return false }
        stage = .run(RoomRun(id: id, intent: intent, approach: approach))
        return true
    }

    /// Applies one run transition, only to the current run: a callback captured for another run (or
    /// with no run showing) changes nothing.
    @discardableResult
    public mutating func updateRun(_ id: RoomRunID, _ change: (inout RoomRun) -> Bool) -> Bool {
        guard case .run(var run) = stage, run.id == id else { return false }
        let changed = change(&run)
        stage = .run(run)
        return changed
    }

    /// The outer Back on the Room: from the entry screen it closes the preview (back to the explanation);
    /// in a run, `RoomRun.outerBack()`.
    public mutating func outerBack() -> RoomOuterBack {
        switch stage {
        case .entry:
            return .none
        case .run(var run):
            let outcome = run.outerBack()
            stage = .run(run)
            return outcome
        }
    }
}
