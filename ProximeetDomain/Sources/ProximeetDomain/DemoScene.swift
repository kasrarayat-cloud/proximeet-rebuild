/// The screens of the demo, in their only permitted order.
public enum DemoScene: String, CaseIterable, Hashable, Sendable {
    case welcome
    case birthday
    case demoPass
    case guestList
    case band
    case signal
    case readyForCheckIn

    /// The scene a forward action leads to, or `nil` at the end of the demo.
    public var next: DemoScene? {
        switch self {
        case .welcome: return .birthday
        case .birthday: return .demoPass
        case .demoPass: return .guestList
        case .guestList: return .band
        case .band: return .signal
        case .signal: return .readyForCheckIn
        case .readyForCheckIn: return nil
        }
    }
}
