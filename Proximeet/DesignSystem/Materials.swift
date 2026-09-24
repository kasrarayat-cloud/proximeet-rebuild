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

/// Sculpted graphite aperture around the native birthday picker: a machined bezel, a
/// recessed well with an inner shadow, and soft depth falloff above and below the
/// selected row. The picker inside stays fully native; every layer here is static and
/// ignores touches.
struct GraphiteAperture<Content: View>: View {
    @ViewBuilder var content: Content
    @Adaptive private var adaptive

    var body: some View {
        let bezel = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let well = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x0F1214), in: well)
            .overlay {
                if !adaptive.increaseContrast {
                    // Depth falloff: adjacent values recede, the selected row stays crisp.
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0x0F1214).opacity(0.7), location: 0),
                            .init(color: .clear, location: 0.3),
                            .init(color: .clear, location: 0.7),
                            .init(color: Color(hex: 0x0F1214).opacity(0.7), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(well)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .overlay {
                // Inner shadow: the well is cut into the bezel, lit from above.
                well
                    .stroke(Color.black.opacity(0.9), lineWidth: 6)
                    .blur(radius: 4)
                    .offset(y: 2)
                    .clipShape(well)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                well
                    .strokeBorder(
                        adaptive.increaseContrast ? Palette.porcelain : Palette.hairline,
                        lineWidth: adaptive.increaseContrast ? 2 : 1
                    )
                    .allowsHitTesting(false)
            }
            .padding(10)
            .background {
                bezel
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x2B3034), Palette.graphite, Color(hex: 0x0C0E10)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay {
                        BeadBlastGrain(seed: 0x6A2A_9E11)
                            .clipShape(bezel)
                            .opacity(0.6)
                    }
                    .overlay {
                        bezel.strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.03), Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                    }
                    .shadow(color: Color.black.opacity(0.6), radius: 16, y: 10)
                    .accessibilityHidden(true)
            }
    }
}

// MARK: - Paper stock

/// Thick bright paper stock (the pass, the roster and the ready summary): a notched sheet
/// with a lit top edge, fine fibre grain and a soft contact shadow, optionally held by a
/// bead-blasted aluminium clip. Text on it is Carbon ink on a static, opaque region.
struct PaperSheet<Content: View>: View {
    var clipped = true
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content
    @Adaptive private var adaptive

    var body: some View {
        let sheet = NotchedPlate(cornerRadius: cornerRadius, notchWidth: 30, notchDepth: 6, notchPosition: 0.72)
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .foregroundStyle(Palette.carbon)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, clipped ? 34 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            sheet
                .fill(LinearGradient(
                    colors: [Palette.paper, Palette.paper, Palette.paperShade],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay {
                    PaperFibre()
                        .clipShape(sheet)
                }
                .overlay {
                    sheet.stroke(
                        adaptive.increaseContrast ? Palette.carbon.opacity(0.5) : Color.white.opacity(0.9),
                        lineWidth: 1
                    )
                }
                .shadow(color: Color.black.opacity(0.55), radius: 18, y: 12)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            if clipped {
                PaperClip()
                    .frame(width: 104, height: 34)
                    .offset(y: -14)
            }
        }
        .padding(.top, clipped ? 14 : 0)
    }
}

/// Precision aluminium clip holding the paper stock.
struct PaperClip: View {
    var body: some View {
        ZStack {
            MetalSurface(
                shape: NotchedPlate(cornerRadius: 9, notchWidth: 16, notchDepth: 3, notchPosition: 0.5),
                stops: MetalFinish.clasp,
                angle: MetalFinish.claspAngle
            )
            Capsule()
                .fill(Palette.carbon.opacity(0.55))
                .frame(width: 46, height: 5)
                .offset(y: 5)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 3)
        .accessibilityHidden(true)
    }
}

/// Faint deterministic fibre texture for paper stock. Drawn once per size change.
struct PaperFibre: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            var generator = SeededGenerator(seed: 0xF1B2_E5ED)
            var fibres = Path()
            let count = min(900, Int(size.width * size.height / 70))
            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &generator)
                let y = CGFloat.random(in: 0..<size.height, using: &generator)
                let length = CGFloat.random(in: 1.5..<4, using: &generator)
                fibres.addRect(CGRect(x: x, y: y, width: length, height: 0.6))
            }
            context.fill(fibres, with: .color(Palette.carbon.opacity(0.035)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Printed perforation across paper stock.
struct Perforation: View {
    var body: some View {
        Line()
            .stroke(Palette.paperRule, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: 1.5)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
