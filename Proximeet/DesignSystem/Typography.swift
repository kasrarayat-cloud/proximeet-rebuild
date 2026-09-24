import SwiftUI

/// Type roles. Figma uses Barlow Semi Condensed ExtraBold and Inter; this build uses the
/// native system face: heavy, normal-width, mixed-case display type for headlines and
/// SF Pro for interface text, pending a native render comparison. Every role scales with
/// Dynamic Type from its base size.
///
/// The intent word woven into a band is deliberately not a role here: it is part of the
/// band object and scales with the object's geometry (see `BandGeometry`), while the
/// band's accessible name and external subtitle use these scalable roles.
enum TextRole {
    /// Centered screen headline, normally two controlled lines (design baseline 34–38 pt).
    case hero
    /// Large word on paper and cards, e.g. the guest name or "Demo pass".
    case title
    /// Short title printed on a signal plate.
    case plateTitle
    case section
    case body
    case supporting
    case label
    case button

    fileprivate var baseSize: CGFloat {
        switch self {
        case .hero: return 36
        case .title: return 30
        case .plateTitle: return 18
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
        case .title: return .title
        case .plateTitle: return .headline
        case .section: return .title3
        case .body: return .body
        case .supporting, .label: return .subheadline
        case .button: return .headline
        }
    }

    fileprivate var lineSpacing: CGFloat {
        switch self {
        case .hero, .title, .plateTitle: return 0
        case .section: return 3
        case .body: return 5
        case .supporting, .label: return 4
        case .button: return 3
        }
    }

    /// Slightly tighter tracking for heavy display sizes; none for interface text.
    fileprivate var tracking: CGFloat {
        switch self {
        case .hero: return -0.5
        case .title: return -0.3
        default: return 0
        }
    }

    fileprivate func font(size: CGFloat) -> Font {
        switch self {
        case .hero, .title, .plateTitle:
            return .system(size: size, weight: .heavy)
        case .section:
            return .system(size: size, weight: .bold)
        case .body, .supporting:
            return .system(size: size)
        case .label, .button:
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
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }
}

extension View {
    func textRole(_ role: TextRole) -> some View {
        modifier(TextRoleModifier(role: role))
    }
}
