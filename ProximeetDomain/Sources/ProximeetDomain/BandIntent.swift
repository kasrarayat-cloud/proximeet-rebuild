/// The intent a guest wears on their band. In this demo it is a draft choice only.
public enum BandIntent: String, CaseIterable, Identifiable, Hashable, Sendable {
    case social
    case dating
    case business
    case activity

    public var id: String { rawValue }

    /// The word woven into the band. Always shown alongside the intent's colour and icon.
    public var title: String {
        switch self {
        case .social: return "Social"
        case .dating: return "Dating"
        case .business: return "Business"
        case .activity: return "Activity"
        }
    }

    /// Brief neutral description of the draft choice. Describes intent, never a policy.
    public var summary: String {
        switch self {
        case .social: return "Meet new people and see where it goes."
        case .dating: return "Open to meeting someone romantically."
        case .business: return "Here to talk work, ideas and projects."
        case .activity: return "Looking for people to do something with."
        }
    }
}
