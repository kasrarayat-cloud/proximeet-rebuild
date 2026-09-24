import SwiftUI
import ProximeetDomain

/// One machined tag choice on B2 (Figma 166 × 100, radius 17). Labels and descriptions
/// are native text on a static, contrast-checked metal region.
struct SignalOption: View {
    let signal: ApproachSignal
    let isSelected: Bool
    let action: () -> Void
    @Adaptive private var adaptive

    var body: some View {
        Button(action: action) {
            SignalOptionFace(signal: signal, isSelected: isSelected)
        }
        .buttonStyle(ObjectPressStyle())
        .accessibilityLabel(Text(signal.title))
        .accessibilityValue(Text(signal.summary))
        .accessibilityHint(Text("Attaches this tag to your band."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(adaptive.selectionAnimation, value: isSelected)
    }
}

private struct SignalOptionFace: View {
    let signal: ApproachSignal
    let isSelected: Bool
    @Adaptive private var adaptive

    var body: some View {
        let plate = NotchedPlate(cornerRadius: 17, notchWidth: 18, notchDepth: 4)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: signal.symbolName)
                    .font(.system(size: 26, weight: .regular))
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 6)
            Text(signal.title)
                .textRole(.tagWord)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
            Text(signal.summary)
                .textRole(.supporting)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.carbon)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minHeight: 100)
        .background {
            ZStack {
                MetalSurface(shape: plate, stops: MetalFinish.tagCard, angle: MetalFinish.tagCardAngle)
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Palette.porcelain.opacity(0.08))
                    .padding(5)
            }
        }
        .overlay {
            if isSelected {
                plate
                    .stroke(Palette.porcelain, lineWidth: adaptive.increaseContrast ? 3.5 : 2.5)
                    .padding(-5)
            }
        }
        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 5)
        .padding(5)
        .contentShape(Rectangle())
    }
}

/// The selected tag seated on the band's clasp (Figma hero tag 108 × 103, radius 17).
struct HeroTag: View {
    let signal: ApproachSignal

    var body: some View {
        let plate = NotchedPlate(cornerRadius: 17, notchWidth: 18, notchDepth: 4)
        ZStack {
            MetalSurface(shape: plate, stops: MetalFinish.heroTag, angle: MetalFinish.heroTagAngle)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.porcelain.opacity(0.08))
                .padding(5)
            Image(systemName: signal.symbolName)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(Palette.carbon)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 12)
        .accessibilityHidden(true)
    }
}
