import SwiftUI
import ProximeetDomain

/// One complete woven loop on B1. The whole object and its external subtitle form the
/// button; selection changes the object itself (a small lift, the clasp latching and a
/// local light spill) plus a thin intent-colour rim and check, never the whole screen.
struct BandOption: View {
    let intent: BandIntent
    let isSelected: Bool
    let action: () -> Void
    @Adaptive private var adaptive

    var body: some View {
        Button(action: action) {
            BandOptionFace(intent: intent, isSelected: isSelected)
        }
        .buttonStyle(ObjectPressStyle())
        .accessibilityLabel(Text("\(intent.title) band"))
        .accessibilityValue(Text("\(intent.tagline). \(intent.summary)"))
        .accessibilityHint(Text("Selects this band for your draft."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(adaptive.selectionAnimation, value: isSelected)
    }
}

private struct BandOptionFace: View {
    let intent: BandIntent
    let isSelected: Bool
    @Adaptive private var adaptive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var lifts: Bool { isSelected && !adaptive.reduceMotion }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(spacing: 2) {
            BandAssembly(
                intent: intent,
                mount: .bare,
                claspClosed: isSelected,
                glows: isSelected,
                verticalProjection: 0.52,
                claspAnimation: adaptive.selectionAnimation
            )
            .frame(maxWidth: 310)
            .scaleEffect(lifts ? 1.03 : 1)
            .offset(y: lifts ? -3 : 0)

            if dynamicTypeSize.isAccessibilitySize {
                Text(intent.title)
                    .textRole(.section)
                    .foregroundStyle(Palette.porcelain)
            }
            HStack(alignment: .center, spacing: 6) {
                if isSelected {
                    SelectionCheck(accent: intent.tint)
                        .transition(.opacity)
                }
                Text(intent.tagline)
                    .textRole(.supporting)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        isSelected ? Palette.porcelain : Palette.quiet(increasedContrast: adaptive.increaseContrast)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .top)
        .background {
            if isSelected {
                shape.fill(intent.tint.opacity(0.08))
            }
        }
        .overlay {
            if isSelected {
                shape.strokeBorder(intent.tint, lineWidth: adaptive.increaseContrast ? 2.5 : 1.5)
            }
        }
        .contentShape(shape)
    }
}
