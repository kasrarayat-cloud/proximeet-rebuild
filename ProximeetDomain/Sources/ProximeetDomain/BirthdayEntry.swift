import Foundation

/// A Gregorian calendar date with no time of day and no time zone. A birthday is a civil
/// date, never an instant, so it is stored and compared field by field.
public struct CivilDate: Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// A real Gregorian date, or `nil`. Nothing is normalised: 31 April or 29 February in a
    /// non-leap year is rejected, never rolled over into the next month.
    public init?(year: Int, month: Int, day: Int) {
        guard year >= 1, (1...12).contains(month),
              day >= 1, day <= CivilDate.numberOfDays(inMonth: month, year: year)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// Days in `month` of `year` (Gregorian), or 0 for a month outside 1…12.
    public static func numberOfDays(inMonth month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// The Gregorian civil day on which `instant` falls in `timeZone`: the device's local
    /// "today" when given the current instant and time zone. The caller supplies the
    /// instant; the domain never reads the clock.
    public static func day(of instant: Date, in timeZone: TimeZone) -> CivilDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        return CivilDate(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
            ?? CivilDate.epoch
    }

    /// The same month and day `years` later. A 29 February birthday falls on 1 March in a
    /// non-leap year. This is a provisional product policy and needs confirmation before
    /// production; it is the later, more conservative of the two common conventions.
    public func anniversary(adding years: Int) -> CivilDate {
        let target = year + years
        if month == 2, day == 29, !CivilDate.isLeapYear(target) {
            return CivilDate(year: target, month: 3, day: 1) ?? self
        }
        return CivilDate(year: target, month: month, day: day) ?? self
    }

    private static let epoch = CivilDate(unchecked: 1970, 1, 1)

    private init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

/// The day, month and year as entered so far. Any of them may be unset, and a complete set
/// may still name an impossible date; nothing here validates.
public struct BirthdayComponents: Equatable, Sendable {
    public var day: Int?
    public var month: Int?
    public var year: Int?

    public init(day: Int? = nil, month: Int? = nil, year: Int? = nil) {
        self.day = day
        self.month = month
        self.year = year
    }

    public var isEmpty: Bool { day == nil && month == nil && year == nil }
    public var isComplete: Bool { day != nil && month != nil && year != nil }
}

/// Where the birthday entry stands. Only `.eligible` allows Continue.
public enum BirthdayStatus: Equatable, Sendable {
    /// Nothing entered yet.
    case empty
    /// Changed since the last check; the previous result no longer applies.
    case editing
    /// Checked while a day, month or year was still missing.
    case incomplete
    /// Checked, but the day, month and year do not form a real date (e.g. 31 April).
    case impossible
    /// Checked, but the year is before `BirthdayEntry.earliestYear` (e.g. a two-digit year).
    case yearOutOfRange
    /// A real date after today.
    case future
    /// A real date less than 18 years ago.
    case underMinimumAge
    /// A real date at least 18 years ago. Self-declared: never proof of age or identity.
    case eligible
}

/// The birthday draft and its last check.
///
/// Draft components are kept apart from the committed date. Any edit immediately
/// invalidates the previous result (so Continue becomes unavailable), and only an explicit
/// `commit`, when a wheel settles or typed entry is submitted, checks the draft again.
/// Eligibility compares civil dates with the exact eighteenth birthday; it never subtracts
/// years alone or measures elapsed seconds. Held in memory only.
public struct BirthdayEntry: Equatable, Sendable {
    public static let minimumAge = 18
    /// The earliest birth year either input accepts, and the year wheel's first row, so a
    /// checked date can always be shown on the wheels. A two-digit year is refused rather
    /// than read as a century guess.
    public static let earliestYear = 1900

    public private(set) var draft = BirthdayComponents()
    /// The complete, real date that was last checked, or `nil`.
    public private(set) var committed: CivilDate?
    public private(set) var status: BirthdayStatus = .empty

    public init() {}

    public var canContinue: Bool { status == .eligible }

    public mutating func setDay(_ day: Int?) { edit { $0.day = day } }
    public mutating func setMonth(_ month: Int?) { edit { $0.month = month } }
    public mutating func setYear(_ year: Int?) { edit { $0.year = year } }

    /// Checks the draft as it stands against the device's civil `today`.
    public mutating func commit(today: CivilDate) {
        guard let day = draft.day, let month = draft.month, let year = draft.year else {
            committed = nil
            status = draft.isEmpty ? .empty : .incomplete
            return
        }
        guard year >= Self.earliestYear else {
            committed = nil
            status = .yearOutOfRange
            return
        }
        guard let date = CivilDate(year: year, month: month, day: day) else {
            committed = nil
            status = .impossible
            return
        }
        committed = date
        status = Self.evaluate(date, today: today)
    }

    /// Re-checks the committed date against a new `today`, e.g. when the app resumes or
    /// just before Continue. A draft being edited is left alone.
    public mutating func reevaluate(today: CivilDate) {
        guard let committed, status != .editing else { return }
        status = Self.evaluate(committed, today: today)
    }

    public static func evaluate(_ birthday: CivilDate, today: CivilDate) -> BirthdayStatus {
        if birthday > today {
            return .future
        }
        return today >= birthday.anniversary(adding: minimumAge) ? .eligible : .underMinimumAge
    }

    private mutating func edit(_ change: (inout BirthdayComponents) -> Void) {
        var next = draft
        change(&next)
        guard next != draft else { return }
        draft = next
        committed = nil
        status = next.isEmpty ? .empty : .editing
    }
}
