import SwiftUI
import ProximeetDomain

/// One woven band on B1. The whole object is the button; selection changes the object
/// itself (lift, engaged latch, Porcelain ring, check mark) rather than the screen.
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
        .accessibilityValue(Text(intent.tagline))
        .accessibilityHint(Text("Selects this band for your draft."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(adaptive.selectionAnimation, value: isSelected)
    }
}

private struct BandOptionFace: View {
    let intent: BandIntent
    let isSelected: Bool
    @Adaptive private var adaptive

    /// Clasp width (Figma 58 pt) plus its inset from the strap end.
    private let claspWidth: CGFloat = 58
    private let claspInset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(intent.title)
                    .textRole(.bandWord)
                    .textCase(.uppercase)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .transition(.opacity)
                }
            }
            Text(intent.tagline)
                .textRole(.label)
        }
        .foregroundStyle(Palette.carbon)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 18)
        .padding(.trailing, claspWidth + claspInset + 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 65, alignment: .leading)
        .background {
            WovenStrip(tint: intent.tint)
        }
        .overlay(alignment: .trailing) {
            // The overlay is proposed the strap's size, so the clasp always matches the
            // strap height and overhangs it by 2 pt top and bottom as in the Figma study.
            BandClasp(intent: intent, isEngaged: isSelected)
                .frame(width: claspWidth)
                .padding(.vertical, -2)
                .padding(.trailing, claspInset)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.porcelain, lineWidth: adaptive.increaseContrast ? 3 : 2)
                    .padding(-5)
            }
        }
        .scaleEffect(isSelected && !adaptive.reduceMotion ? 1.02 : 1)
        .shadow(
            color: intent.tint.opacity(isSelected && !adaptive.reduceTransparency ? 0.45 : 0),
            radius: 16,
            y: 6
        )
        .shadow(color: Color.black.opacity(0.55), radius: 4, y: 3)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
