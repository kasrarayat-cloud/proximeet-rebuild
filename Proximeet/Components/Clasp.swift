import SwiftUI

/// Subtle dark clasp wrapped around the loop's right-hand turn, drawn natively in smoked
/// graphite alloy. Its latch closes when the band is chosen (B1) or secured (B2). The
/// motion is decorative: the model state already exists before the latch moves, and under
/// Reduce Motion the latch keeps a static pose and only its opacity changes.
struct SideClasp: View {
    var isClosed: Bool
    @Adaptive private var adaptive

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let closedPose = isClosed || adaptive.reduceMotion
            ZStack {
                MetalSurface(
                    shape: NotchedPlate(
                        cornerRadius: width * 0.34,
                        notchWidth: width * 0.4,
                        notchDepth: max(1, width * 0.08),
                        notchPosition: 0.5
                    ),
                    stops: MetalFinish.darkClasp,
                    angle: MetalFinish.darkClaspAngle
                )
                // Groove where the strap passes through.
                RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                    .fill(Color.black.opacity(0.5))
                    .frame(width: max(1.5, width * 0.16), height: height * 0.56)
                    .offset(y: -height * 0.06)
                // Latch lever, hinged at its leading end.
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x6B777E), Color(hex: 0x2A3034)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: width * 0.86, height: max(2, height * 0.09))
                    .rotationEffect(.degrees(closedPose ? 0 : -32), anchor: .leading)
                    .offset(y: height * 0.32)
                    .opacity(isClosed ? 1 : 0.6)
            }
            .frame(width: width, height: height)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 2, x: -1, y: 2)
        .accessibilityHidden(true)
    }
}

/// Small ring linking the clasp to a mounted signal plate.
struct PlateLink: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: 0x7C888F), Color(hex: 0x23282C)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.5, proxy.size.width * 0.22)
                )
        }
        .shadow(color: Color.black.opacity(0.4), radius: 1.5, y: 1)
        .accessibilityHidden(true)
    }
}
