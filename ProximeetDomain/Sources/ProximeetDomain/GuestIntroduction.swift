/// Chapter 04, the approved Guest List: the guest's own introduction, held in memory for this
/// demo run only.
///
/// The draft keeps exactly what was typed or pasted. Nothing here trims, normalises, truncates
/// or rewrites it; edges are trimmed only when the card is presented (`card`).
///
/// - Name: required. Only a name made entirely of whitespace or newlines is blank. There is no
///   surname, length, script or character rule.
/// - Opener: optional, at most `openerLimit` user-perceived characters (`String.count`, extended
///   grapheme clusters). Longer text stays in the draft; it only holds back the preview.
/// - Interests: optional, any of the three catalog entries, each toggled on its own.
///
/// Nothing here identifies, verifies, lists or shows anyone: the card is a preview for the guest.
public struct GuestIntroduction: Equatable, Sendable {
    /// The whole illustrative catalog of this prototype, in its only order.
    public enum Interest: String, CaseIterable, Hashable, Sendable {
        case coffee
        case liveMusic
        case outdoors

        public var label: String {
            switch self {
            case .coffee: return "Coffee"
            case .liveMusic: return "Live music"
            case .outdoors: return "Outdoors"
            }
        }
    }

    public static let openerLimit = 120

    /// Exactly as entered.
    public var name: String
    /// Exactly as entered, including any length over the limit.
    public var opener: String
    /// The selected interests, in catalog order, each at most once.
    public private(set) var interests: [Interest]

    public init(name: String = "", opener: String = "", interests: [Interest] = []) {
        self.name = name
        self.opener = opener
        self.interests = Interest.allCases.filter(interests.contains)
    }

    public func isSelected(_ interest: Interest) -> Bool {
        interests.contains(interest)
    }

    /// Selects or deselects one interest; the others are untouched.
    public mutating func toggle(_ interest: Interest) {
        let selected = isSelected(interest)
        interests = Interest.allCases.filter { $0 == interest ? !selected : isSelected($0) }
    }

    /// User-perceived characters in the opener.
    public var openerCount: Int { opener.count }

    public var isNameBlank: Bool { Self.trimmed(name).isEmpty }

    public var isOpenerWithinLimit: Bool { openerCount <= Self.openerLimit }

    /// Preview my card: a nonblank name and an opener within the limit. The opener and the
    /// interests are optional.
    public var canPreview: Bool { !isNameBlank && isOpenerWithinLimit }

    /// What the card shows, or `nil` while the draft cannot be previewed.
    public var card: IntroductionCard? {
        guard canPreview else { return nil }
        let name = Self.trimmed(self.name)
        guard let initial = name.first else { return nil }
        let opener = Self.trimmed(self.opener)
        return IntroductionCard(
            name: String(name),
            initial: String(initial),
            opener: opener.isEmpty ? nil : String(opener),
            interests: interests
        )
    }

    /// `text` without leading and trailing whitespace or newlines, trimmed by whole characters
    /// so no grapheme is split.
    static func trimmed(_ text: String) -> Substring {
        var slice = Substring(text)
        while let first = slice.first, first.isWhitespace {
            slice.removeFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice.removeLast()
        }
        return slice
    }
}

/// The personal card: the draft presented, never stored or shared.
public struct IntroductionCard: Equatable, Sendable {
    /// The name with its edges trimmed; inside, exactly as entered.
    public let name: String
    /// The first user-perceived character of the first nonblank name token, unchanged. A visual
    /// placeholder, not an identity or age signal.
    public let initial: String
    /// The opener with its edges trimmed, or `nil` when there is none to show.
    public let opener: String?
    /// The selected interests, in catalog order.
    public let interests: [GuestIntroduction.Interest]
}
