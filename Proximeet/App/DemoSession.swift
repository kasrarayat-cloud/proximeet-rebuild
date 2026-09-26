import Foundation
import Observation
import ProximeetDomain

/// Observable wrapper around the in-memory `DemoFlow`.
///
/// Every method forwards to a synchronous domain transition, so the UI never waits for
/// animation or time to change state. Nothing here persists, networks or verifies.
@Observable
final class DemoSession {
    private(set) var flow: DemoFlow

    /// Incremented on every reset. The navigation stack is keyed on it, so all view-local
    /// drafts (picker selections, form text) are discarded together with the model data.
    private(set) var resetGeneration = 0

    init(flow: DemoFlow = DemoFlow()) {
        self.flow = flow
    }

    // MARK: - Read-only state

    /// The domain's path. The domain only accepts pops, so forward navigation always goes through
    /// a validated action.
    var path: [DemoScene] {
        get { flow.path }
        set { flow.adoptNavigationPath(newValue) }
    }

    /// Places' inner stages: `PlacesView` shows them itself (dissolves and the ticket expansion),
    /// so the navigation stack never pushes them.
    static let placesStages: Set<DemoScene> = [.placeDetail, .placeExplanation]

    /// Bound to `NavigationStack`: the domain path without Places' inner stages. A pop proposed
    /// by the stack (a system back gesture from Places) is a pop of the domain path, which drops
    /// the inner stages with it; nothing longer or different is ever adopted.
    var navigationPath: [DemoScene] {
        get { flow.path.filter { !Self.placesStages.contains($0) } }
        set {
            guard newValue != navigationPath else { return }
            flow.adoptNavigationPath(newValue)
        }
    }

    var draft: DemoDraft { flow.draft }
    var readiness: ReadyForCheckIn? { flow.readiness }

    // MARK: - Transitions

    func begin() {
        flow.begin()
    }

    /// Uses the same Gregorian calendar and time zone as the birthday picker.
    func submitBirthday(_ dateOfBirth: Date, calendar: Calendar, now: Date = Date()) -> BirthdayCheck? {
        flow.submitBirthday(dateOfBirth, using: BirthdayEligibility(referenceDate: now, calendar: calendar))
    }

    /// Back or Leave demo on the approved Pass: returns to Birthday with its draft kept.
    func leavePass() {
        flow.leavePass()
    }

    /// Continue preview on the approved Pass's complete stage: opens the approved Guest List.
    func continueFromCompletedPass(_ demo: PassDemo) {
        flow.continueFromCompletedPass(demo)
    }

    // MARK: - Approved Guest List

    /// The introduction draft, exactly as entered. Memory only.
    var introduction: GuestIntroduction { flow.draft.introduction }

    func editIntroduction(_ change: (inout GuestIntroduction) -> Void) {
        flow.editIntroduction(change)
    }

    /// Bound to the Guest List's name field. Every keystroke, paste or composition is stored as
    /// the field reports it: never trimmed, truncated or rewritten.
    var introductionName: String {
        get { flow.draft.introduction.name }
        set { flow.editIntroduction { $0.name = newValue } }
    }

    /// Bound to the Guest List's opener field; over the limit the text stays as entered.
    var introductionOpener: String {
        get { flow.draft.introduction.opener }
        set { flow.editIntroduction { $0.opener = newValue } }
    }

    /// Back on the Guest List editor: returns to the Pass, still complete, with the draft kept.
    func leaveGuestList() {
        flow.leaveGuestList()
    }

    /// Continue preview on the approved Guest List card: opens the approved Wristband.
    func continueFromGuestListCard(_ demo: GuestListDemo) {
        flow.continueFromGuestListCard(demo)
    }

    // MARK: - Approved Wristband

    /// The single current intent, or none. Memory only.
    var intent: BandIntent? { flow.draft.band }

    /// Chooses the intent; choosing the current one again does nothing.
    func chooseIntent(_ intent: BandIntent) {
        flow.chooseIntent(intent)
    }

    /// Whether Continue preview is available: only with an intent chosen.
    var canContinueWristband: Bool { flow.canContinueFromWristband }

    /// Continue preview on the Wristband: opens the approved Signal carrying the chosen intent.
    func continueFromWristband() {
        flow.continueFromWristband()
    }

    /// Back on the Wristband: returns to the Guest List card, with the draft and intent kept.
    func leaveWristband() {
        flow.leaveWristband()
    }

    // MARK: - Approved Signal

    /// The single current approach, or none. Memory only; separate from the intent.
    var approach: ApproachSignal? { flow.draft.signal }

    /// Chooses the approach; choosing the current one again does nothing. Returns whether it
    /// changed, so the screen animates only a real change.
    @discardableResult
    func chooseApproach(_ approach: ApproachSignal) -> Bool {
        flow.chooseApproach(approach)
    }

    /// Whether Continue preview is available: an intent and an approach, on Signal.
    var canContinueSignal: Bool { flow.continueSignalPreview() }

    /// Continue preview on Signal: opens Places at the retained category (Now the first time).
    @discardableResult
    func openPlaces() -> Bool {
        flow.openPlaces()
    }

    /// Back on Signal: returns to the Wristband, with the intent and the approach kept.
    func leaveSignal() {
        flow.leaveSignal()
    }

    // MARK: - Approved Places

    /// The retained category: Now until the guest chooses another. Memory only.
    var placesCategory: PlaceCategory { flow.placesCategory }

    /// The retained category's venue: the one browsing and the detail show.
    var placeVenue: Venue { flow.placeVenue }

    /// What the actual intent may do at that venue, derived each time it is read.
    var placeEligibility: PlaceEligibility? { flow.placeEligibility }

    /// A category tab; the selected tab does nothing. Returns whether it changed.
    @discardableResult
    func choosePlaceCategory(_ category: PlaceCategory) -> Bool {
        flow.choosePlaceCategory(category)
    }

    /// View place: the retained category's venue detail, whatever the intent.
    @discardableResult
    func openPlaceDetail() -> Bool {
        flow.openPlaceDetail()
    }

    /// Preview check-in: only an eligible actual intent at Common Ground opens the explanation.
    @discardableResult
    func previewCheckIn() -> Bool {
        flow.previewCheckIn()
    }

    /// Back on browsing: the actual Signal, everything kept.
    @discardableResult
    func leavePlaces() -> Bool {
        flow.leavePlaces()
    }

    /// Back on a detail: browsing at the originating category.
    @discardableResult
    func leavePlaceDetail() -> Bool {
        flow.leavePlaceDetail()
    }

    /// Back on the explanation: Common Ground's detail.
    @discardableResult
    func backToPlace() -> Bool {
        flow.backToPlace()
    }

    /// Explore other places on the explanation: browsing at Now.
    @discardableResult
    func exploreOtherPlaces() -> Bool {
        flow.exploreOtherPlaces()
    }

    /// Pops a stale route back to the last scene still allowed (a missing intent to the
    /// Wristband, a missing approach to Signal). A valid route is left alone.
    func reconcileRoute() {
        flow.reconcileRoute()
    }

    #if DEBUG
    /// DEBUG fixtures only: open the next Guest List on its card, as if Preview my card had been
    /// pressed. Read once.
    var fixtureOpensGuestListCard = false
    #endif

    /// Transactional: `.invalid` leaves any previously saved profile untouched.
    func saveProfile(firstName: String, interests: [String]) -> ProfileSaveOutcome {
        flow.saveProfile(firstName: firstName, interests: interests)
    }

    func continueFromGuestList() {
        flow.continueFromGuestList()
    }

    func selectBand(_ intent: BandIntent) {
        flow.selectBand(intent)
    }

    func confirmBand() {
        flow.confirmBand()
    }

    func returnTo(_ scene: DemoScene) {
        flow.returnTo(scene)
    }

    func reset() {
        flow.reset()
        resetGeneration += 1
    }

    // MARK: - Approved Birthday

    var birthday: BirthdayEntry { flow.draft.birthdayEntry }

    /// Edits the birthday draft. Any change invalidates the previous check at once.
    func editBirthday(_ change: (inout BirthdayEntry) -> Void) {
        flow.updateBirthday(change)
    }

    /// Checks the draft: called when a wheel settles or typed entry is submitted.
    func commitBirthday(now: Date = Date()) {
        let today = Self.civilToday(now: now)
        flow.updateBirthday { $0.commit(today: today) }
    }

    /// Re-checks the committed date, e.g. when the app becomes active again.
    func reevaluateBirthday(now: Date = Date()) {
        let today = Self.civilToday(now: now)
        flow.updateBirthday { $0.reevaluate(today: today) }
    }

    /// Continue on Birthday: re-checks against today; only an eligible committed date opens
    /// the approved Pass. Returns the checked status.
    func continueFromBirthday(now: Date = Date()) -> BirthdayStatus? {
        flow.continueFromBirthday(today: Self.civilToday(now: now))
    }

    /// The device's local calendar day, read as a Gregorian civil date.
    static func civilToday(now: Date, timeZone: TimeZone = .current) -> CivilDate {
        CivilDate.day(of: now, in: timeZone)
    }

    // MARK: - Calendar

    /// Gregorian calendar in the device's current time zone, shared by the birthday picker
    /// and the eligibility check so both agree on which day a date falls on.
    static func birthdayCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
