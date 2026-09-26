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
    /// The approved Guest List's introduction: raw name, raw opener and interests. Kept when
    /// going Back to Pass, so returning within the same demo run shows it again.
    public internal(set) var introduction = GuestIntroduction()
    public internal(set) var profile: GuestProfile?
    /// The approved Wristband's single current intent: none until the guest chooses one, then
    /// exactly one. Kept when going Back to the Guest List card, so returning shows it again.
    public internal(set) var band: BandIntent?
    /// The approved Signal's single current approach: none until the guest chooses one, then
    /// exactly one. Separate from the intent and kept when the intent changes, when going Back to
    /// the Wristband and when earlier chapters are edited.
    public internal(set) var signal: ApproachSignal?

    public init() {}

    /// Whether the draft holds everything needed to enter `scene`.
    public func meetsRequirements(for scene: DemoScene) -> Bool {
        switch scene {
        case .welcome, .birthday:
            return true
        case .demoPass:
            // The approved Birthday gate: an eligible committed date. The legacy stored date
            // counts only while the approved entry is untouched (the DEBUG fixtures of later,
            // legacy scenes), so an old adult date can never stand in for an entry the guest has
            // since changed to an under-18, incomplete or impossible one.
            return birthdayEntry.canContinue || (birthdayEntry.status == .empty && dateOfBirth != nil)
        case .guestList:
            // Through the Pass, so through the same Birthday gate. Completing the Pass demo is
            // checked by `DemoFlow.continueFromCompletedPass`.
            return meetsRequirements(for: .demoPass)
        case .band:
            // The approved route: from a previewable Guest List introduction, through the same
            // Birthday gate. The legacy profile remains for the DEBUG fixtures of later scenes.
            return meetsRequirements(for: .guestList) && (introduction.canPreview || profile != nil)
        case .signal:
            return meetsRequirements(for: .band) && band != nil
        case .readyForCheckIn:
            return meetsRequirements(for: .signal) && signal != nil
        case .places, .placeDetail:
            // The approved Signal's Continue preview: the Birthday gate, the introduction, the
            // actual intent and the actual approach, all still valid. Browsing and details stay
            // open to every intent.
            return meetsRequirements(for: .signal) && signal != nil
        case .placeExplanation:
            // Only an eligible actual intent at the only open session (Common Ground) may read
            // its explanation.
            guard meetsRequirements(for: .placeDetail), let band else { return false }
            return PlaceEligibility(venue: CheckInExplanation.venue, intent: band).canPreviewCheckIn
        }
    }
}
