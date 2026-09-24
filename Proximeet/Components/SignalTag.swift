import SwiftUI
import ProximeetDomain

/// The lead-supplied blank machined plate, drawn so its machined face (not the transparent
/// margin) fills the frame. A frame at the face aspect shows it undistorted; taller frames
/// at larger text sizes stretch it vertically rather than crop it.
struct SignalPlateArt: View {
    var body: some View {
        GeometryReader { proxy in
            let face = SignalPlateGeometry.face
            let image = SignalPlateGeometry.imageSize
            let scaleX = proxy.size.width / face.width
            let scaleY = proxy.size.height / face.height
            Image(decorative: "SignalPlateBlank")
                .resizable()
                .interpolation(.high)
                .frame(width: image.width * scaleX, height: image.height * scaleY)
                .offset(x: -face.minX * scaleX, y: -face.minY * scaleY)
        }
        // The face fills the frame exactly; clipping drops only the transparent margin
        // and its faint flecks.
        .clipped()
        .allowsHitTesting(false)
    }
}

/// One compact landscape plate choice on B2 (about 171 × 90 pt on a 402 pt wide screen,
/// the artwork's 1.904:1 face aspect). The plate shows only its native icon and short
/// title, kept inside the face away from the rim; the full description is the
/// accessibility value, and the scene explains the selected plate below the grid.
struct SignalOption: View {
    let signal: ApproachSignal
    let isSelected: Bool
    /// The chosen band's intent colour, used only for the thin selection rim and check.
    let accent: Color
    let action: () -> Void
    @Adaptive private var adaptive

    var body: some View {
        Button(action: action) {
            SignalPlateFace(signal: signal, isSelected: isSelected, accent: accent)
        }
        .buttonStyle(ObjectPressStyle())
        .accessibilityLabel(Text(signal.title))
        .accessibilityValue(Text(signal.summary))
        .accessibilityHint(Text("Clips this tag to your band."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(adaptive.selectionAnimation, value: isSelected)
    }
}

private struct SignalPlateFace: View {
    let signal: ApproachSignal
    let isSelected: Bool
    let accent: Color
    @Adaptive private var adaptive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: signal.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .accessibilityHidden(true)
            Text(signal.title)
                .textRole(.plateTitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.carbon)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(
            maxWidth: .infinity,
            // Normal sizes keep the face aspect (171 × 90); the single accessibility column
            // starts near it too, and any plate grows rather than clipping its text.
            minHeight: dynamicTypeSize.isAccessibilitySize ? 180 : 90,
            maxHeight: .infinity
        )
        .background {
            SignalPlateArt()
                .shadow(color: Color.black.opacity(0.45), radius: 6, y: 4)
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                SelectionCheck(accent: accent)
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .overlay {
            if isSelected {
                // Thin intent-colour rim follows the visible plate; layout is unchanged.
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(accent, lineWidth: adaptive.increaseContrast ? 2.5 : 1.5)
                    .padding(1)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Selected-state check: Carbon mark on the intent colour, with a thin Carbon edge so it
/// reads on bright metal and on the dark stage alike. Never the only selection cue.
struct SelectionCheck: View {
    let accent: Color
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 18

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(Palette.carbon, accent)
            .font(.system(size: size, weight: .bold))
            .overlay {
                Circle().strokeBorder(Palette.carbon.opacity(0.4), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// The selected signal as a small plate hanging from the band's clasp: same plate
/// artwork, native icon only. Decorative; the band stage carries the accessible label.
struct AttachedPlate: View {
    let signal: ApproachSignal

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SignalPlateArt()
                Image(systemName: signal.symbolName)
                    .font(.system(size: proxy.size.height * 0.44, weight: .semibold))
                    .foregroundStyle(Palette.carbon)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 6, y: 5)
        .accessibilityHidden(true)
    }
}
