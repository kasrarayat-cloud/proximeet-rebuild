/// Chapter 06, the approved Signal: how a guest would prefer a hello to begin. It is the draft's
/// one optional approach (`DemoDraft.signal`): none on a fresh run, then exactly one of these.
///
/// A preference, not continuing consent: either person can change their mind. Choosing it sends or
/// accepts no Wave, opens no chat, creates no match and grants no permission to approach or
/// message. Nobody else can see it in this demo.
public enum ApproachSignal: String, CaseIterable, Identifiable, Hashable, Sendable {
    case chatFirst
    case okayToSayHello

    public var id: String { rawValue }

    /// The choice's name, as the row and the summary show it.
    public var title: String {
        switch self {
        case .chatFirst: return "Chat first"
        case .okayToSayHello: return "Okay to say hello"
        }
    }

    /// The approved explanation under the name.
    public var summary: String {
        switch self {
        case .chatFirst: return "Start with a Wave. Chat after you both agree."
        case .okayToSayHello: return "Open to a brief hello. No pressure to continue."
        }
    }
}

/// The Signal summary line for the carried intent and the current approach, or for none.
public struct SignalSummary: Equatable, Sendable {
    public let title: String

    public init(intent: BandIntent, approach: ApproachSignal?) {
        title = "\(intent.title) band · \(approach?.title ?? "Choose your approach")"
    }
}
