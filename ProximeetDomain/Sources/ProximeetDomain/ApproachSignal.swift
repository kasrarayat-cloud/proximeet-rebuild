/// How a guest would prefer to be approached. In this demo it is a draft choice only;
/// nothing is enforced and nobody else can see it.
public enum ApproachSignal: String, CaseIterable, Identifiable, Hashable, Sendable {
    case comeSayHi
    case chatFirst
    case withMyCrew
    case justLooking

    public var id: String { rawValue }

    /// The label machined into the tag.
    public var title: String {
        switch self {
        case .comeSayHi: return "Come say hi"
        case .chatFirst: return "Chat first"
        case .withMyCrew: return "With my crew"
        case .justLooking: return "Just looking"
        }
    }

    /// Brief neutral description of the preference.
    public var summary: String {
        switch self {
        case .comeSayHi: return "Happy for someone to walk over and say hello."
        case .chatFirst: return "Would rather exchange a few messages before meeting."
        case .withMyCrew: return "Out with friends right now. Keep it relaxed."
        case .justLooking: return "Getting a feel for the place for now."
        }
    }
}
