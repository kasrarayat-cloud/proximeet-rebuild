import SwiftUI

// MARK: - Primary action (56 pt, Porcelain pill with arrow)

struct PrimaryActionStyle: ButtonStyle {
    var showsArrow = true

    func makeBody(configuration: Configuration) -> some View {
        PrimaryActionBody(configuration: configuration, showsArrow: showsArrow)
    }
}

private struct PrimaryActionBody: View {
    let configuration: ButtonStyleConfiguration
    let showsArrow: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        HStack(spacing: 12) {
            configuration.label
                .textRole(.button)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(isEnabled ? Palette.carbon : Palette.quiet(increasedContrast: adaptive.increaseContrast))
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(isEnabled ? Palette.porcelain : Palette.alloyShadow, in: shape)
        .overlay {
            if adaptive.increaseContrast {
                shape.strokeBorder(Palette.porcelain, lineWidth: 2)
            }
        }
        .contentShape(shape)
        .scaleEffect(configuration.isPressed && !adaptive.reduceMotion ? 0.98 : 1)
        .opacity(configuration.isPressed ? 0.88 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Secondary action (outlined, 48 pt)

struct SecondaryActionStyle: ButtonStyle {
    var tint: Color = Palette.porcelain

    func makeBody(configuration: Configuration) -> some View {
        SecondaryActionBody(configuration: configuration, tint: tint)
    }
}

private struct SecondaryActionBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        configuration.label
            .textRole(.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay {
                shape.strokeBorder(tint, lineWidth: adaptive.increaseContrast ? 2.5 : 1.5)
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Quiet action (44 pt, no fill or outline)

/// Low-emphasis secondary action, e.g. starting the demo over. The confirmation dialog
/// that follows carries the destructive emphasis.
struct QuietActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietActionBody(configuration: configuration)
    }
}

private struct QuietActionBody: View {
    let configuration: ButtonStyleConfiguration
    @Adaptive private var adaptive

    var body: some View {
        configuration.label
            .textRole(.label)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Inline edit link (44 pt target)

struct EditLinkStyle: ButtonStyle {
    var tint: Color = Palette.porcelain

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil")
                .accessibilityHidden(true)
            configuration.label
                .textRole(.label)
                .underline()
        }
        .foregroundStyle(tint)
        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Object press (bands and tags)

struct ObjectPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ObjectPressBody(configuration: configuration)
    }
}

private struct ObjectPressBody: View {
    let configuration: ButtonStyleConfiguration
    @Adaptive private var adaptive

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !adaptive.reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryActionStyle {
    static var proximeetPrimary: PrimaryActionStyle { PrimaryActionStyle() }

    static func proximeetPrimary(showsArrow: Bool) -> PrimaryActionStyle {
        PrimaryActionStyle(showsArrow: showsArrow)
    }
}

extension ButtonStyle where Self == SecondaryActionStyle {
    static var proximeetSecondary: SecondaryActionStyle { SecondaryActionStyle() }
    static var proximeetDestructive: SecondaryActionStyle { SecondaryActionStyle(tint: Palette.danger) }
}

extension ButtonStyle where Self == QuietActionStyle {
    static var proximeetQuiet: QuietActionStyle { QuietActionStyle() }
}
