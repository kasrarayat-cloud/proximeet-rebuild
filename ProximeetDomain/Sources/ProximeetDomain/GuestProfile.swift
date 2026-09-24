/// A validated guest-list entry: a first name and exactly three distinct interests.
///
/// Instances can only be created through `validated(firstName:interests:)`, so every
/// `GuestProfile` value already satisfies the rules below.
public struct GuestProfile: Equatable, Sendable {
    public static let interestCount = 3
    public static let firstNameCharacterLimit = 30
    public static let interestCharacterLimit = 30

    public let firstName: String
    public let interests: [String]

    private init(firstName: String, interests: [String]) {
        self.firstName = firstName
        self.interests = interests
    }

    /// Normalises each value (see `normalized(_:)`), then checks:
    /// a non-blank first name, exactly three non-blank interests, character limits, and
    /// interests that are distinct ignoring letter case.
    public static func validated(
        firstName: String,
        interests: [String]
    ) -> Result<GuestProfile, ProfileValidationError> {
        let name = normalized(firstName)
        let entries = interests.map(normalized)
        var issues: [ProfileIssue] = []

        if name.isEmpty {
            issues.append(.firstNameMissing)
        } else if name.count > firstNameCharacterLimit {
            issues.append(.firstNameTooLong(limit: firstNameCharacterLimit))
        }

        if entries.count != interestCount {
            issues.append(.wrongInterestCount(expected: interestCount, actual: entries.count))
        }

        var firstIndexByKey: [String: Int] = [:]
        for (index, entry) in entries.enumerated() {
            if entry.isEmpty {
                issues.append(.interestMissing(index: index))
                continue
            }
            if entry.count > interestCharacterLimit {
                issues.append(.interestTooLong(index: index, limit: interestCharacterLimit))
            }
            let key = entry.lowercased()
            if let earlier = firstIndexByKey[key] {
                issues.append(.duplicateInterest(index: index, duplicateOf: earlier))
            } else {
                firstIndexByKey[key] = index
            }
        }

        guard issues.isEmpty else {
            return .failure(ProfileValidationError(issues: issues))
        }
        return .success(GuestProfile(firstName: name, interests: entries))
    }

    /// Drops invisible control/format characters, trims, and collapses whitespace runs.
    static func normalized(_ text: String) -> String {
        text.filter { !isInvisible($0) }
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// A character made only of control or format scalars, such as a standalone zero-width
    /// space. Joiners inside emoji or words belong to a visible character and are kept.
    private static func isInvisible(_ character: Character) -> Bool {
        !character.isWhitespace && character.unicodeScalars.allSatisfy { scalar in
            let category = scalar.properties.generalCategory
            return category == .control || category == .format
        }
    }
}

/// Every problem found in a profile submission, in field order.
public struct ProfileValidationError: Error, Equatable, Sendable {
    public let issues: [ProfileIssue]
}

public enum ProfileIssue: Equatable, Hashable, Sendable {
    case firstNameMissing
    case firstNameTooLong(limit: Int)
    case wrongInterestCount(expected: Int, actual: Int)
    /// `index` is zero-based.
    case interestMissing(index: Int)
    case interestTooLong(index: Int, limit: Int)
    case duplicateInterest(index: Int, duplicateOf: Int)

    public var message: String {
        switch self {
        case .firstNameMissing:
            return "Enter your first name."
        case .firstNameTooLong(let limit):
            return "Use \(limit) characters or fewer for your first name."
        case .wrongInterestCount(let expected, _):
            return "Add exactly \(expected) interests."
        case .interestMissing(let index):
            return "Enter interest \(index + 1)."
        case .interestTooLong(let index, let limit):
            return "Use \(limit) characters or fewer for interest \(index + 1)."
        case .duplicateInterest(let index, let duplicateOf):
            return "Interest \(index + 1) repeats interest \(duplicateOf + 1). Choose something different."
        }
    }
}
