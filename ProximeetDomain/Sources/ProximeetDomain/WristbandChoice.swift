/// Chapter 05, the approved Wristband: the words each intent carries on that screen. The intent
/// itself is `DemoDraft.band`, the single optional source of truth; everything shown for a
/// choice is derived from it here, so the tile, the summary and the action cannot disagree.
///
/// An intent is a present choice for this demo run. It verifies nothing, shows the guest to no
/// one and grants no permission to approach or message.
public extension BandIntent {
    /// The short hint under the intent's name on its tile.
    var wristbandHint: String {
        switch self {
        case .social: return "People & moments"
        case .dating: return "Romantic connection"
        case .business: return "Ideas & work"
        case .activity: return "Do something"
        }
    }

    /// The explanation shown under "[Intent] · Selected".
    var wristbandExplanation: String {
        switch self {
        case .social: return "Meet people. Share a moment."
        case .dating: return "Explore a romantic connection."
        case .business: return "Exchange ideas and opportunities."
        case .activity: return "Find someone to do things with."
        }
    }
}

/// The Wristband summary for the current choice, or for none.
public struct WristbandSummary: Equatable, Sendable {
    public let title: String
    public let explanation: String

    public init(choice: BandIntent?) {
        if let choice {
            title = "\(choice.title) · Selected"
            explanation = choice.wristbandExplanation
        } else {
            title = "Your moment. Your choice."
            explanation = "Pick the band that fits right now."
        }
    }
}
