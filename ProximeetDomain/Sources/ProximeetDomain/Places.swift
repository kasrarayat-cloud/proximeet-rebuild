/// Chapter 07, the approved Places: three fixed fictional venues in one fictional snapshot,
/// Thursday at 8 pm.
///
/// Nothing here reads a clock, a calendar, a time zone, a location or any live inventory: each
/// venue's availability is a fixed property of the snapshot, so no time of day ever opens a
/// session. Every venue name, host, description, rule and schedule is fictional. A venue is a
/// place a guest might choose to visit, never a booking, an admission or a reservation.
public enum PlacesSnapshot {
    /// Shown under the headline on every browse screen.
    public static let label = "Fictional venues · demo Thursday, 8 pm"
    /// The venue rules shown on every detail, in order.
    public static let rules = ["Respect a no.", "Stay within the venue."]
}

/// A browse category. Each filters the fixed catalog to exactly one venue.
public enum PlaceCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case now
    case later
    case upcoming

    public var id: String { rawValue }

    /// The tab's label.
    public var title: String {
        switch self {
        case .now: return "Now"
        case .later: return "Later"
        case .upcoming: return "Upcoming"
        }
    }

    /// The venue this category shows in the fixed catalog.
    public var venue: Venue {
        switch self {
        case .now: return .commonGround
        case .later: return .afterglow
        case .upcoming: return .fieldwork
        }
    }
}

/// Whether a venue's session is open in the fixed snapshot, or later (with the label its detail
/// shows while it is not).
public enum VenueAvailability: Equatable, Hashable, Sendable {
    case open
    case future(opens: String)
}

/// The three fictional venues of the fixed catalog.
public enum Venue: String, CaseIterable, Identifiable, Hashable, Sendable {
    case commonGround = "common-ground"
    case afterglow
    case fieldwork

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .commonGround: return "Common Ground"
        case .afterglow: return "Afterglow"
        case .fieldwork: return "Fieldwork"
        }
    }

    /// The venue's kind, as the ticket shows it.
    public var kind: String {
        switch self {
        case .commonGround: return "Fictional venue · Café"
        case .afterglow: return "Fictional venue · Listening lounge"
        case .fieldwork: return "Fictional venue · Creative workshop"
        }
    }

    /// The session's schedule within the snapshot ("Today" and "Tonight" are the snapshot's).
    public var schedule: String {
        switch self {
        case .commonGround: return "Today · 6–10 pm"
        case .afterglow: return "Tonight · 9–11 pm"
        case .fieldwork: return "Saturday · 10 am–1 pm"
        }
    }

    public var host: String {
        switch self {
        case .commonGround: return "Common Ground team"
        case .afterglow: return "Afterglow hosts"
        case .fieldwork: return "Fieldwork studio"
        }
    }

    /// "Host · [host]", as the detail shows it.
    public var hostLine: String { "Host · \(host)" }

    public var brief: String {
        switch self {
        case .commonGround: return "Coffee, small tables, and room for an unhurried conversation."
        case .afterglow: return "A warm listening room for records, conversation, and a little curiosity."
        case .fieldwork: return "A shared table for making, learning, and meeting through a small project."
        }
    }

    /// The intents this session welcomes, in the ticket's order.
    public var permittedIntents: [BandIntent] {
        switch self {
        case .commonGround: return [.social, .business]
        case .afterglow: return [.social, .dating]
        case .fieldwork: return [.activity, .business]
        }
    }

    /// Fixed by the snapshot: Common Ground is open; the others start later.
    public var availability: VenueAvailability {
        switch self {
        case .commonGround: return .open
        case .afterglow: return .future(opens: "Opens at 9 pm")
        case .fieldwork: return .future(opens: "Opens Saturday")
        }
    }

    /// The category whose tab shows this venue.
    public var category: PlaceCategory {
        switch self {
        case .commonGround: return .now
        case .afterglow: return .later
        case .fieldwork: return .upcoming
        }
    }
}

/// What the actual intent may do at a venue in the fixed snapshot, and the approved words for it.
///
/// Check-in preview needs both: the session is open in the snapshot AND the venue permits the
/// guest's actual intent. So only Social or Business at Common Ground may open the explanation;
/// every other combination keeps the detail's primary action disabled. A mismatch is explained
/// before any future-session label. Nothing here changes the intent, the approach or anyone's
/// visibility, and eligibility is never consent.
public struct PlaceEligibility: Equatable, Hashable, Sendable {
    public let venue: Venue
    public let intent: BandIntent

    public init(venue: Venue, intent: BandIntent) {
        self.venue = venue
        self.intent = intent
    }

    /// The venue permits the actual intent.
    public var intentMatches: Bool { venue.permittedIntents.contains(intent) }

    /// The session is open in the fixed snapshot.
    public var isOpen: Bool { venue.availability == .open }

    /// Only an open session that permits the actual intent can open the check-in explanation.
    public var canPreviewCheckIn: Bool { intentMatches && isOpen }

    private var mismatch: String { "Your \(intent.title) band doesn’t match this session." }

    /// The detail's primary action: "Preview check-in" when eligible; otherwise the reason it is
    /// disabled, the mismatch first.
    public var primaryLabel: String {
        guard intentMatches else { return "Not available for \(intent.title)" }
        switch venue.availability {
        case .open: return "Preview check-in"
        case .future(let opens): return opens
        }
    }

    /// The line under the browse ticket.
    public var browseBoundary: String {
        intentMatches ? "Your profile stays private until check-in." : mismatch
    }

    /// The last line on the detail ticket.
    public var detailBoundary: String {
        intentMatches ? "Sample session · not a reservation" : mismatch
    }

    /// Why the primary action is disabled, for its accessibility hint; `nil` when enabled.
    public var disabledReason: String? {
        guard !canPreviewCheckIn else { return nil }
        guard intentMatches else { return mismatch }
        switch venue.availability {
        case .open: return nil
        case .future(let opens): return "This fictional session is not open in the demo snapshot. \(opens)."
        }
    }
}

/// The check-in explanation (Common Ground only): what a later, real check-in would ask. Neither
/// check runs; nothing is requested, scanned, generated, timed, verified or entered.
public enum CheckInExplanation {
    public static let venue = Venue.commonGround
    public static let headline = ["Arrive.", "Then connect."]
    public static let support = "A place opens when you’re really there."
    public static let context = "Fictional venue · Today, 6–10 pm"
    public static let steps: [(title: String, explanation: String)] = [
        ("Confirm you’re here", "One location check while the app is open. No background tracking."),
        ("Scan the venue’s code", "Scan the rotating QR shown at the venue."),
    ]
    public static let presenceBoundary = "You stay private until both checks pass."
    public static let demoBoundary = "Demo · no location or camera used."
}
