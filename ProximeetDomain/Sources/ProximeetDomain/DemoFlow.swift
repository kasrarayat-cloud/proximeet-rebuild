import Foundation

public enum ProfileSaveOutcome: Equatable, Sendable {
    case saved(GuestProfile)
    /// The submission was rejected and the previously saved profile, if any, is unchanged.
    case invalid(ProfileValidationError)
    /// Profiles can only be saved on the guest list or the ready summary.
    case unavailable
}

/// The in-memory demo journey:
/// Welcome → Birthday → Demo Pass → Guest List → Band → Signal → Ready for check-in.
///
/// Every transition is a synchronous value mutation. Nothing here reads the clock, waits
/// for animation, stores data, or talks to any service. The only time input is the
/// reference date injected through `BirthdayEligibility`.
///
/// Invariants:
/// - `path` is always a prefix of the journey after Welcome, which is the root.
/// - Every scene in `path` has its requirements met by `draft`.
/// - `readiness` is non-nil only on the ready scene.
public struct DemoFlow: Equatable, Sendable {
    /// Scenes pushed above Welcome, in order. Suitable for driving a navigation stack.
    public private(set) var path: [DemoScene] = []
    public private(set) var draft = DemoDraft()

    public init() {}

    public var currentScene: DemoScene { path.last ?? .welcome }

    /// The summary for the ready screen, derived from the current draft each time it is read.
    public var readiness: ReadyForCheckIn? {
        guard currentScene == .readyForCheckIn else { return nil }
        return ReadyForCheckIn(draft: draft)
    }

    // MARK: - Welcome

    @discardableResult
    public mutating func begin() -> Bool {
        advance(from: .welcome)
    }

    // MARK: - Birthday

    /// Checks the entered date and, if eligible, stores it and moves to the demo pass.
    ///
    /// A rejected date never advances and clears any previously stored date of birth.
    /// An under-18 result also clears the rest of the draft. Returns `nil` without
    /// evaluating when the birthday scene is not current.
    @discardableResult
    public mutating func submitBirthday(
        _ dateOfBirth: Date,
        using eligibility: BirthdayEligibility
    ) -> BirthdayCheck? {
        guard currentScene == .birthday else { return nil }
        let check = eligibility.evaluate(dateOfBirth: dateOfBirth)
        switch check {
        case .eligible:
            draft.dateOfBirth = dateOfBirth
            advance(from: .birthday)
        case .underMinimumAge:
            draft = DemoDraft()
        case .futureDate:
            draft.dateOfBirth = nil
        }
        return check
    }

    /// Applies one edit or check to the approved Birthday screen's entry. Only available on
    /// the birthday scene; nothing here navigates.
    @discardableResult
    public mutating func updateBirthday(_ change: (inout BirthdayEntry) -> Void) -> Bool {
        guard currentScene == .birthday else { return false }
        change(&draft.birthdayEntry)
        return true
    }

    /// Continue on the approved Birthday screen. The committed date is re-checked against
    /// `today` first. The next chapter (Pass) is not built, so an eligible result is returned
    /// for the screen to say so and the flow does not advance. Returns `nil` off the
    /// birthday scene.
    public mutating func continueFromBirthday(today: CivilDate) -> BirthdayStatus? {
        guard currentScene == .birthday else { return nil }
        draft.birthdayEntry.reevaluate(today: today)
        return draft.birthdayEntry.status
    }

    // MARK: - Demo pass

    @discardableResult
    public mutating func continueFromPass() -> Bool {
        advance(from: .demoPass)
    }

    // MARK: - Guest list

    /// Validates and stores the profile. Invalid input leaves the saved profile untouched.
    @discardableResult
    public mutating func saveProfile(firstName: String, interests: [String]) -> ProfileSaveOutcome {
        guard currentScene == .guestList || currentScene == .readyForCheckIn else {
            return .unavailable
        }
        switch GuestProfile.validated(firstName: firstName, interests: interests) {
        case .success(let profile):
            draft.profile = profile
            return .saved(profile)
        case .failure(let error):
            return .invalid(error)
        }
    }

    @discardableResult
    public mutating func continueFromGuestList() -> Bool {
        advance(from: .guestList)
    }

    // MARK: - Band

    /// Replaces any previous band choice. Only available on the band scene.
    @discardableResult
    public mutating func selectBand(_ intent: BandIntent) -> Bool {
        guard currentScene == .band else { return false }
        draft.band = intent
        return true
    }

    /// Confirms the selected band and moves to the signal scene.
    @discardableResult
    public mutating func confirmBand() -> Bool {
        advance(from: .band)
    }

    // MARK: - Signal

    /// Replaces any previous signal choice. Only available on the signal scene.
    @discardableResult
    public mutating func selectSignal(_ signal: ApproachSignal) -> Bool {
        guard currentScene == .signal else { return false }
        draft.signal = signal
        return true
    }

    /// Confirms the selected signal and moves to the ready summary.
    @discardableResult
    public mutating func confirmSignal() -> Bool {
        advance(from: .signal)
    }

    // MARK: - Navigation

    /// Pops one scene. The draft is kept.
    @discardableResult
    public mutating func goBack() -> Bool {
        guard !path.isEmpty else { return false }
        return adoptNavigationPath(Array(path.dropLast()))
    }

    /// Pops back to `scene` if it is on the path, e.g. to edit an earlier choice.
    /// The draft is kept, so the scene shows the existing values.
    @discardableResult
    public mutating func returnTo(_ scene: DemoScene) -> Bool {
        if scene == .welcome {
            return adoptNavigationPath([])
        }
        guard let index = path.firstIndex(of: scene) else { return false }
        return adoptNavigationPath(Array(path[...index]))
    }

    /// Accepts a path proposed by a navigation container only when it pops scenes.
    /// Longer or different paths are rejected, so navigation can never skip validation.
    @discardableResult
    public mutating func adoptNavigationPath(_ proposed: [DemoScene]) -> Bool {
        guard proposed.count <= path.count,
              proposed.elementsEqual(path.prefix(proposed.count))
        else { return false }
        path = proposed
        return true
    }

    // MARK: - Reset

    /// Clears every entered value and choice and returns to Welcome.
    public mutating func reset() {
        self = DemoFlow()
    }

    // MARK: - Private

    @discardableResult
    private mutating func advance(from scene: DemoScene) -> Bool {
        guard currentScene == scene,
              let next = scene.next,
              draft.meetsRequirements(for: next)
        else { return false }
        path.append(next)
        return true
    }
}
