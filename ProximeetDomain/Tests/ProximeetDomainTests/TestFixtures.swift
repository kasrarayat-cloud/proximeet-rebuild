import Foundation
import XCTest
import ProximeetDomain

/// Deterministic, explicitly fictional test data. Nothing here reads the clock.
enum Fixture {
    static let utc: Calendar = calendar(secondsFromGMT: 0)

    static func calendar(
        _ identifier: Calendar.Identifier = .gregorian,
        secondsFromGMT: Int
    ) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)!
        return calendar
    }

    /// A UTC instant built from Gregorian fields.
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static let today = date(2026, 9, 24)
    static let eligibility = BirthdayEligibility(referenceDate: today, calendar: utc)

    static let adultBirthday = date(1995, 5, 17)
    static let underageBirthday = date(2010, 1, 2)
    static let futureBirthday = date(2026, 9, 25)

    static let firstName = "Fixture"
    static let interests = ["Bouldering", "Film photography", "Board games"]

    /// Drives a fresh flow through the public API until `target` is the current scene: the legacy
    /// route up to Signal and its ready summary; Places through the approved Signal's Continue
    /// preview, View place and Preview check-in (so `.placeExplanation` needs an eligible `band`).
    static func flow(
        at target: DemoScene,
        band: BandIntent = .social,
        signal: ApproachSignal = .chatFirst,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> DemoFlow {
        var flow = DemoFlow()
        while flow.currentScene != target {
            let moved: Bool
            switch flow.currentScene {
            case .welcome:
                moved = flow.begin()
            case .birthday:
                moved = flow.submitBirthday(adultBirthday, using: eligibility) == .eligible
            case .demoPass:
                moved = flow.continueFromPass()
            case .guestList:
                moved = flow.saveProfile(firstName: firstName, interests: interests) != .unavailable
                    && flow.continueFromGuestList()
            case .band:
                moved = flow.selectBand(band) && flow.confirmBand()
            case .signal:
                if [.places, .placeDetail, .placeExplanation].contains(target) {
                    moved = flow.selectSignal(signal) && flow.openPlaces()
                } else {
                    moved = flow.selectSignal(signal) && flow.confirmSignal()
                }
            case .places:
                moved = flow.openPlaceDetail()
            case .placeDetail:
                moved = flow.previewCheckIn()
            case .readyForCheckIn, .placeExplanation:
                moved = false
            }
            guard moved else {
                XCTFail("Fixture could not advance past \(flow.currentScene)", file: file, line: line)
                return flow
            }
        }
        return flow
    }
}
