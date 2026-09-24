/// The only mark a demo pass can carry.
public enum PassMark: String, CaseIterable, Sendable {
    case demo = "DEMO"

    public var label: String { rawValue }
}

/// Who can see the draft. In this demo, nobody.
public enum DraftVisibility: CaseIterable, Sendable {
    case notVisibleToAnyone

    public var notice: String {
        switch self {
        case .notVisibleToAnyone: return "Demo — not visible to anyone"
        }
    }
}

/// Summary shown on the final demo screen. It describes draft choices only: reaching it
/// does not check anyone in, verify anything, or make the guest visible.
///
/// The date of birth is intentionally not part of the summary.
public struct ReadyForCheckIn: Equatable, Sendable {
    public let profile: GuestProfile
    public let band: BandIntent
    public let signal: ApproachSignal

    public var passMark: PassMark { .demo }
    public var visibility: DraftVisibility { .notVisibleToAnyone }

    init?(draft: DemoDraft) {
        guard draft.meetsRequirements(for: .readyForCheckIn),
              let profile = draft.profile,
              let band = draft.band,
              let signal = draft.signal
        else { return nil }
        self.profile = profile
        self.band = band
        self.signal = signal
    }
}
