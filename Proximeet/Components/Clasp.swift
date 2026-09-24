import SwiftUI
import ProximeetDomain

/// Metal clasp at the end of a B1 band (Figma 58 × 69, radius 9). Engaged when selected:
/// the latch sits flush against the strap.
struct BandClasp: View {
    let intent: BandIntent
    var isEngaged: Bool
    @Adaptive private var adaptive

    var body: some View {
        ZStack {
            MetalSurface(
                shape: NotchedPlate(cornerRadius: 9, notchWidth: 14, notchDepth: 3),
                stops: MetalFinish.clasp,
                angle: MetalFinish.claspAngle
            )
            Image(systemName: intent.symbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.carbon)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Palette.carbon.opacity(isEngaged ? 0.85 : 0.35))
                .frame(width: 4)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5)
                .offset(x: adaptive.reduceMotion || isEngaged ? 0 : -3)
        }
        .shadow(color: Color.black.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

/// Clasp at the centre of the secured band (B2 stage and summary). Closing is decorative;
/// the secured state already exists in the model before this view appears.
struct StageClasp: View {
    let intent: BandIntent
    var isClosed: Bool

    var body: some View {
        ZStack {
            MetalSurface(
                shape: NotchedPlate(cornerRadius: 14, notchWidth: 16, notchDepth: 4),
                stops: MetalFinish.heroTag,
                angle: MetalFinish.heroTagAngle
            )
            Image(systemName: intent.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.carbon)
                .offset(y: -7)
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: 0x3B4347), Color(hex: 0x8C98A0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 44, height: 8)
                .rotationEffect(.degrees(isClosed ? 0 : -24), anchor: .leading)
                .offset(y: isClosed ? 17 : 6)
        }
        .shadow(color: Color.black.opacity(0.45), radius: 8, y: 6)
        .accessibilityHidden(true)
    }
}
