/// The screens of the demo. After Signal the journey has two branches: the approved Places
/// (browse, a venue's detail, Common Ground's check-in explanation), reached through Signal's
/// Continue preview, and the legacy, DEBUG-only ready summary, reached only through the legacy
/// route that the approved screens never call.
public enum DemoScene: String, CaseIterable, Hashable, Sendable {
    case welcome
    case birthday
    case demoPass
    case guestList
    case band
    case signal
    case readyForCheckIn
    /// Places browsing: the retained category's venue ticket (Now the first time).
    case places
    /// The detail of the retained category's venue.
    case placeDetail
    /// Common Ground's check-in explanation. Explanation only: nothing is checked.
    case placeExplanation

    /// The scene a forward action leads to, or `nil` at the end of a branch. Signal's legacy
    /// successor is the ready summary; the approved Signal opens Places with
    /// `DemoFlow.openPlaces()` instead.
    public var next: DemoScene? {
        switch self {
        case .welcome: return .birthday
        case .birthday: return .demoPass
        case .demoPass: return .guestList
        case .guestList: return .band
        case .band: return .signal
        case .signal: return .readyForCheckIn
        case .readyForCheckIn: return nil
        case .places: return .placeDetail
        case .placeDetail: return .placeExplanation
        case .placeExplanation: return nil
        }
    }

    /// The approved journey after Welcome, through Signal into Places.
    public static let approvedJourney: [DemoScene] = [
        .birthday, .demoPass, .guestList, .band, .signal, .places, .placeDetail, .placeExplanation,
    ]

    /// The legacy journey after Welcome, ending at the DEBUG-only ready summary.
    public static let legacyJourney: [DemoScene] = [.birthday, .demoPass, .guestList, .band, .signal, .readyForCheckIn]
}
