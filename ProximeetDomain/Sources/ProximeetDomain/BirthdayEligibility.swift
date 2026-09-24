import Foundation

/// Outcome of the self-entered birthday check. An eligible result only means the entered
/// date is 18 or more years ago; it is never proof of age or identity.
public enum BirthdayCheck: Equatable, Sendable {
    case eligible
    case underMinimumAge
    case futureDate

    public var message: String {
        switch self {
        case .eligible:
            return "Eligible for this demo. The date is self-entered and has not been checked."
        case .underMinimumAge:
            return "Proximeet is for people aged 18 and over, so this demo can't continue with that date."
        case .futureDate:
            return "That date is in the future. Choose your date of birth."
        }
    }
}

/// Evaluates a date of birth against a reference date using whole calendar days.
///
/// Both the reference date and the calendar are injected so results are deterministic.
/// The calendar's time zone decides which day an instant falls on; its identifier is
/// normalised to Gregorian so era-based calendars cannot distort the year arithmetic.
public struct BirthdayEligibility: Sendable {
    public static let minimumAge = 18

    public let referenceDate: Date
    public let calendar: Calendar

    public init(referenceDate: Date, calendar: Calendar = Calendar.current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        self.referenceDate = referenceDate
        self.calendar = gregorian
    }

    public func evaluate(dateOfBirth: Date) -> BirthdayCheck {
        let birthday = calendarDay(of: dateOfBirth)
        let today = calendarDay(of: referenceDate)
        if birthday > today {
            return .futureDate
        }
        let adulthood = birthday.anniversary(adding: Self.minimumAge)
        return today >= adulthood ? .eligible : .underMinimumAge
    }

    private func calendarDay(of date: Date) -> CalendarDay {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        let year = components.year ?? 0
        // Gregorian era 0 is BCE; map it onto a continuous astronomical year.
        let continuousYear = components.era == 0 ? 1 - year : year
        return CalendarDay(year: continuousYear, month: components.month ?? 1, day: components.day ?? 1)
    }
}

/// A Gregorian calendar day compared field by field, so time of day never matters.
struct CalendarDay: Comparable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The same month and day `years` later. A 29 February birthday is treated as
    /// 1 March in non-leap years, the later and therefore more conservative convention.
    func anniversary(adding years: Int) -> CalendarDay {
        let target = year + years
        if month == 2, day == 29, !CalendarDay.isLeapYear(target) {
            return CalendarDay(year: target, month: 3, day: 1)
        }
        return CalendarDay(year: target, month: month, day: day)
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
