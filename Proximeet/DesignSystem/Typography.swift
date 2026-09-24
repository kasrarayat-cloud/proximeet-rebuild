import SwiftUI

/// Type roles. Figma uses Barlow Semi Condensed ExtraBold and Inter; this build substitutes
/// SF Pro Condensed Heavy and SF Pro as the Social Objects brief proposes, pending a
/// native render comparison. Every role scales with Dynamic Type from its base size.
enum TextRole {
    /// Screen headline. Figma 48 pt condensed; design baseline 38/40.
    case hero
    /// Large word on objects and cards, e.g. the guest name.
    case title
    /// Word woven into a band (Figma 31 pt).
    case bandWord
    /// Word machined into a tag (Figma 21 pt).
    case tagWord
    case section
    case body
    case supporting
    case label
    case button

    fileprivate var baseSize: CGFloat {
        switch self {
        case .hero: return 44
        case .title: return 32
        case .bandWord: return 30
        case .tagWord: return 21
        case .section: return 20
        case .body: return 17
        case .supporting: return 15
        case .label: return 15
        case .button: return 17
        }
    }

    fileprivate var textStyle: Font.TextStyle {
        switch self {
        case .hero: return .largeTitle
        case .title, .bandWord: return .title
        case .tagWord, .section: return .title3
        case .body: return .body
        case .supporting, .label: return .subheadline
        case .button: return .headline
        }
    }

    fileprivate var lineSpacing: CGFloat {
        switch self {
        case .hero, .title, .bandWord, .tagWord: return 0
        case .section: return 3
        case .body: return 5
        case .supporting, .label: return 4
        case .button: return 3
        }
    }

    fileprivate func font(size: CGFloat) -> Font {
        switch self {
        case .hero, .title, .bandWord, .tagWord:
            return .system(size: size, weight: .heavy).width(.condensed)
        case .section:
            return .system(size: size, weight: .bold)
        case .body, .supporting:
            return .system(size: size)
        case .label:
            return .system(size: size, weight: .semibold)
        case .button:
            return .system(size: size, weight: .semibold)
        }
    }
}

private struct TextRoleModifier: ViewModifier {
    private let role: TextRole
    @ScaledMetric private var size: CGFloat

    init(role: TextRole) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.baseSize, relativeTo: role.textStyle)
    }

    func body(content: Content) -> some View {
        content
            .font(role.font(size: size))
            .lineSpacing(role.lineSpacing)
    }
}

extension View {
    func textRole(_ role: TextRole) -> some View {
        modifier(TextRoleModifier(role: role))
    }
}
