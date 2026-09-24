import SwiftUI

/// Rounded plate with the Social Objects offset notch cut into its top edge: the shared
/// signature of clasps, tags, the pass and the roster. The notch is deliberately off-centre.
struct NotchedPlate: Shape {
    var cornerRadius: CGFloat
    var notchWidth: CGFloat = 14
    var notchDepth: CGFloat = 4
    var notchPosition: CGFloat = 0.7

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        let depth = min(notchDepth, rect.height / 4)
        let centerX = rect.minX + rect.width * notchPosition
        let left = max(rect.minX + radius, centerX - notchWidth / 2)
        let right = min(rect.maxX - radius, centerX + notchWidth / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        if right - left > depth * 2 {
            path.addLine(to: CGPoint(x: left, y: rect.minY))
            path.addLine(to: CGPoint(x: left + depth, y: rect.minY + depth))
            path.addLine(to: CGPoint(x: right - depth, y: rect.minY + depth))
            path.addLine(to: CGPoint(x: right, y: rect.minY))
        }
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: radius
        )
        path.closeSubpath()
        return path
    }
}

/// Interim procedural bead-blasted aluminium: a static directional gradient, fine grain
/// and an edge highlight. Not the photoreal production material.
struct MetalSurface<S: Shape>: View {
    let shape: S
    let stops: [Gradient.Stop]
    let angle: Double

    var body: some View {
        let points = UnitPoint.cssGradientPoints(degrees: angle)
        shape
            .fill(LinearGradient(stops: stops, startPoint: points.start, endPoint: points.end))
            .overlay {
                BeadBlastGrain()
                    .clipShape(shape)
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.08), Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .accessibilityHidden(true)
    }
}

/// Deterministic stipple drawn once per size change. No animation, no timeline.
struct BeadBlastGrain: View {
    var seed: UInt64 = 0x5EED_B1A5

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            var generator = SeededGenerator(seed: seed)
            var dark = Path()
            var light = Path()
            let count = min(1_400, Int(size.width * size.height / 22))
            for index in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &generator)
                let y = CGFloat.random(in: 0..<size.height, using: &generator)
                let dot = CGRect(x: x, y: y, width: 0.9, height: 0.9)
                if index.isMultiple(of: 2) {
                    dark.addEllipse(in: dot)
                } else {
                    light.addEllipse(in: dot)
                }
            }
            context.fill(dark, with: .color(Color.black.opacity(0.1)))
            context.fill(light, with: .color(Color.white.opacity(0.14)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// SplitMix64, so procedural textures render identically every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Recessed graphite surround used for the birthday picker.
struct GraphiteAperture<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        content
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Palette.graphite, in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color.white.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
            }
    }
}
