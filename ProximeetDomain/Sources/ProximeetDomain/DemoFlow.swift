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
    /// `today` first; only an eligible committed date (the Birthday gate, unchanged) opens the
    /// approved Pass. Anything else stays on Birthday. Returns the checked status, or `nil`
    /// off the birthday scene, so a repeated Continue cannot push Pass twice.
    public mutating func continueFromBirthday(today: CivilDate) -> BirthdayStatus? {
        guard currentScene == .birthday else { return nil }
        draft.birthdayEntry.reevaluate(today: today)
        if draft.birthdayEntry.canContinue {
            advance(from: .birthday)
        }
        return draft.birthdayEntry.status
    }

    // MARK: - Demo pass

    /// Back or Leave demo on the approved Pass: returns to Birthday, whose draft is kept.
    /// Only available on the pass scene, so a repeated Back cannot also leave Birthday.
    @discardableResult
    public mutating func leavePass() -> Bool {
        guard currentScene == .demoPass else { return false }
        return returnTo(.birthday)
    }

    /// Continue preview on the approved Pass's complete stage: opens the approved Guest List
    /// editor. Only a completed demo on the pass scene moves on, so an unfinished demo or a
    /// repeated tap (the scene is then Guest List) does nothing.
    @discardableResult
    public mutating func continueFromCompletedPass(_ demo: PassDemo) -> Bool {
        guard demo.continuePreview() else { return false }
        return advance(from: .demoPass)
    }

    /// The legacy onward route. The approved Pass never calls it; it remains for the DEBUG
    /// fixtures of later, not yet approved scenes.

    @discardableResult
    public mutating func continueFromPass() -> Bool {
        advance(from: .demoPass)
    }

    // MARK: - Guest list (approved, chapter 04)

    /// Applies one edit to the introduction. Only available on the guest list scene; nothing
    /// here validates, trims or navigates. The draft stays in memory for this demo run.
    @discardableResult
    public mutating func editIntroduction(_ change: (inout GuestIntroduction) -> Void) -> Bool {
        guard currentScene == .guestList else { return false }
        change(&draft.introduction)
        return true
    }

    /// Back on the approved Guest List editor: returns to the Pass, whose screen is still below
    /// it. The introduction is kept. Only available on the guest list scene, so a repeated Back
    /// cannot also leave the Pass.
    @discardableResult
    public mutating func leaveGuestList() -> Bool {
        guard currentScene == .guestList else { return false }
        return returnTo(.demoPass)
    }

    // MARK: - Guest list (legacy profile, DEBUG fixtures of later scenes)

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

    /// The legacy onward route from a saved profile. The approved Guest List never calls it; it
    /// remains for the DEBUG fixtures of later, not yet approved scenes.
    @discardableResult
    public mutating func continueFromGuestList() -> Bool {
        guard draft.profile != nil else { return false }
        return advance(from: .guestList)
    }

    // MARK: - Wristband (approved, chapter 05)

    /// Continue preview on the approved Guest List card: opens the approved Wristband. Only the
    /// card stage of a previewable introduction on the guest list scene moves on, so a repeated
    /// tap (the scene is then the band) or the editor does nothing. The introduction and any
    /// earlier intent are kept.
    @discardableResult
    public mutating func continueFromGuestListCard(_ demo: GuestListDemo) -> Bool {
        guard demo.continuePreview(), draft.introduction.canPreview else { return false }
        return advance(from: .guestList)
    }

    /// Chooses the single current intent on the approved Wristband. Returns whether it changed:
    /// the chosen intent replaces any other, and choosing the current one again does nothing (it
    /// never clears the choice). Only available on the band scene.
    @discardableResult
    public mutating func chooseIntent(_ intent: BandIntent) -> Bool {
        guard currentScene == .band, draft.band != intent else { return false }
        draft.band = intent
        return true
    }

    /// Whether Continue preview on the approved Wristband is available: only once an intent is
    /// chosen, so Signal can never open without one.
    public var canContinueFromWristband: Bool {
        currentScene == .band && draft.band != nil
    }

    /// Continue preview on the approved Wristband: opens the approved Signal carrying the chosen
    /// intent. Without an intent, or off the band scene (a repeated tap), it does nothing. The
    /// introduction, the intent and any earlier approach are kept.
    @discardableResult
    public mutating func continueFromWristband() -> Bool {
        guard canContinueFromWristband else { return false }
        return advance(from: .band)
    }

    /// Back on the approved Wristband: returns to the Guest List, whose card is still below it.
    /// The introduction and the intent are kept. Only available on the band scene, so a repeated
    /// Back cannot also leave the Guest List.
    @discardableResult
    public mutating func leaveWristband() -> Bool {
        guard currentScene == .band else { return false }
        return returnTo(.guestList)
    }

    // MARK: - Band (legacy, DEBUG fixtures of later scenes)

    /// Replaces any previous band choice. Only available on the band scene.
    @discardableResult
    public mutating func selectBand(_ intent: BandIntent) -> Bool {
        guard currentScene == .band else { return false }
        draft.band = intent
        return true
    }

    /// Confirms the selected band and moves to the signal scene. Legacy route only: it needs the
    /// legacy profile; the approved Wristband uses `continueFromWristband()`.
    @discardableResult
    public mutating func confirmBand() -> Bool {
        guard draft.profile != nil else { return false }
        return advance(from: .band)
    }

    // MARK: - Signal (approved, chapter 06)

    /// Chooses the single current approach on the approved Signal. Returns whether it changed:
    /// the chosen approach replaces the other, and choosing the current one again does nothing (it
    /// never clears the choice). Only available on the signal scene, which always carries an
    /// intent. Nothing is sent, accepted, opened or granted.
    @discardableResult
    public mutating func chooseApproach(_ approach: ApproachSignal) -> Bool {
        guard currentScene == .signal, draft.band != nil, draft.signal != approach else { return false }
        draft.signal = approach
        return true
    }

    /// Continue preview on the approved Signal: available once an approach is chosen. Returns
    /// whether the end-of-preview message should be shown; nothing navigates, and Places does not
    /// exist.
    public func continueSignalPreview() -> Bool {
        currentScene == .signal && draft.band != nil && draft.signal != nil
    }

    /// Back on the approved Signal: returns to the Wristband, still below it, with the intent and
    /// the approach kept. Only available on the signal scene, so a repeated Back cannot also leave
    /// the Wristband.
    @discardableResult
    public mutating func leaveSignal() -> Bool {
        guard currentScene == .signal else { return false }
        return returnTo(.band)
    }

    // MARK: - Signal (legacy, DEBUG fixtures of later scenes)

    /// Replaces any previous signal choice. Only available on the signal scene.
    @discardableResult
    public mutating func selectSignal(_ signal: ApproachSignal) -> Bool {
        guard currentScene == .signal else { return false }
        draft.signal = signal
        return true
    }

    /// Confirms the selected signal and moves to the (unapproved) ready summary. Legacy route
    /// only: it needs the legacy profile, so the approved Signal can never reach it.
    @discardableResult
    public mutating func confirmSignal() -> Bool {
        guard draft.profile != nil else { return false }
        return advance(from: .signal)
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
