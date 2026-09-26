import Foundation

/// Everything the guest has entered or chosen during this demo run.
///
/// Held in memory only: the type is deliberately not `Codable`, and `DemoFlow.reset()`
/// replaces it with an empty draft.
public struct DemoDraft: Equatable, Sendable {
    /// Stored only after an eligible birthday check; cleared by any later rejected check.
    public internal(set) var dateOfBirth: Date?
    /// The approved Birthday screen's entry: the day/month/year draft and its last check.
    /// Kept when going Back to Welcome, so returning within the same demo run shows it again.
    public internal(set) var birthdayEntry = BirthdayEntry()
    public internal(set) var profile: GuestProfile?
    public internal(set) var band: BandIntent?
    public internal(set) var signal: ApproachSignal?

    public init() {}

    /// Whether the draft holds everything needed to enter `scene`.
    public func meetsRequirements(for scene: DemoScene) -> Bool {
        switch scene {
        case .welcome, .birthday:
            return true
        case .demoPass:
            // The approved Birthday gate: an eligible committed date. The legacy stored date
            // remains for the DEBUG fixtures of later scenes.
            return birthdayEntry.canContinue || dateOfBirth != nil
        case .guestList:
            return dateOfBirth != nil
        case .band:
            return dateOfBirth != nil && profile != nil
        case .signal:
            return meetsRequirements(for: .band) && band != nil
        case .readyForCheckIn:
            return meetsRequirements(for: .signal) && signal != nil
        }
    }
}
