import SwiftUI
import ProximeetDomain

/// The four private-invitation objects approved on 29 October 2026. Their meaning is repeated in the
/// adjacent intent badge and invitation copy; none of the artwork is an accessibility control.
///
/// All dimensions below belong to a 376 × 220 illustration canvas. The canvas scales as a unit, so
/// decorative edges and shadows never determine the size of the readable invitation card below it.
/// The parent owns motion and the accepted state. There are no timers, appear animations or delays.
struct PrivateInvitationArtwork: View {
    let intent: BandIntent
    let accepted: Bool
    let width: CGFloat

    var body: some View {
        let availableWidth = width.isFinite ? max(0, width) : 0
        let factor = min(1, availableWidth / 376)
        ZStack {
            InvitationGroundGlow(tint: intent.tint)
            objects
        }
        .frame(width: 376, height: 220)
        .scaleEffect(factor, anchor: .top)
        .frame(width: availableWidth, height: 220 * factor, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("wave.artwork.\(intent.rawValue)")
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var objects: some View {
        switch intent {
        case .business:
            InvitationBusinessObjects(accepted: accepted)
        case .social:
            InvitationSocialObjects(accepted: accepted)
        case .activity:
            InvitationActivityObjects(accepted: accepted)
        case .dating:
            InvitationDatingObjects(accepted: accepted)
        }
    }
}

private enum InvitationMetal {
    static let edge = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x444C50), location: 0),
            .init(color: Color(hex: 0xDCE2E3), location: 0.12),
            .init(color: .white, location: 0.22),
            .init(color: Color(hex: 0x879295), location: 0.38),
            .init(color: Color(hex: 0x323B3F), location: 0.55),
            .init(color: Color(hex: 0xA5B0B3), location: 0.78),
            .init(color: Color(hex: 0xEDF0EB), location: 0.9),
            .init(color: Color(hex: 0x596164), location: 1)
        ], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let paper = LinearGradient(
        colors: [Color(hex: 0xF7F5EF), Color(hex: 0xE2DFD5), Color(hex: 0xC9C7BF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let thinHighlight = LinearGradient(
        colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.45)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

private struct InvitationGroundGlow: View {
    let tint: Color

    var body: some View {
        Ellipse()
            .fill(tint.opacity(0.12))
            .frame(width: 260, height: 35)
            .blur(radius: 23)
            .offset(y: 76)
        Ellipse()
            .fill(Color.white.opacity(0.035))
            .frame(width: 300, height: 24)
            .blur(radius: 15)
            .offset(y: 79)
    }
}

// MARK: - Business: two pieces of personal stationery, not a romantic emblem

private struct InvitationBusinessObjects: View {
    let accepted: Bool

    var body: some View {
        ZStack {
            InvitationBusinessCard(mark: .corner)
                .rotation3DEffect(.degrees(-14), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .rotationEffect(.degrees(accepted ? -5 : -12))
                .position(x: accepted ? 133 : 116, y: 88)
            InvitationBusinessCard(mark: .rule)
                .rotation3DEffect(.degrees(-13), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .rotationEffect(.degrees(accepted ? -5 : -10))
                .position(x: accepted ? 242 : 259, y: 139)
        }
    }
}

private struct InvitationBusinessCard: View {
    enum Mark { case corner, rule }
    let mark: Mark

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(InvitationMetal.edge)
                .offset(x: -5, y: 3)
            RoundedRectangle(cornerRadius: 10)
                .fill(InvitationMetal.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(InvitationMetal.thinHighlight, lineWidth: 1.5)
                }
                .padding(3)
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: "briefcase")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(Color(hex: 0x353D40))
                    .accessibilityHidden(true)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: 0x50585A))
                    .frame(width: mark == .corner ? 49 : 63, height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: 0x8D9290))
                    .frame(width: 27, height: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 23)
            if mark == .corner {
                InvitationCardCorner()
                    .fill(Palette.business)
                    .frame(width: 30, height: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4)
            } else {
                Capsule()
                    .fill(Palette.business)
                    .frame(width: 25, height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(17)
            }
        }
        .frame(width: 158, height: 109)
        .shadow(color: .black.opacity(0.65), radius: 10, x: 3, y: 16)
    }
}

private struct InvitationCardCorner: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Social: two distinct voices with a shared cyan edge

private struct InvitationSocialObjects: View {
    let accepted: Bool

    var body: some View {
        ZStack {
            InvitationSpeechObject()
                .rotation3DEffect(.degrees(-13), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .rotationEffect(.degrees(accepted ? -3 : -9))
                .position(x: accepted ? 130 : 113, y: 95)
            InvitationSpeechObject()
                .scaleEffect(x: -1, y: 1)
                .rotation3DEffect(.degrees(13), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .rotationEffect(.degrees(accepted ? 3 : 9))
                .position(x: accepted ? 246 : 263, y: 127)
        }
    }
}

private struct InvitationSpeechObject: View {
    var body: some View {
        ZStack {
            InvitationSpeechShape()
                .fill(InvitationMetal.edge)
                .offset(x: -5, y: 3)
            InvitationSpeechShape()
                .fill(InvitationMetal.paper)
            InvitationSpeechShape()
                .stroke(Palette.social, lineWidth: 2.5)
            InvitationSpeechShape()
                .stroke(InvitationMetal.thinHighlight, lineWidth: 1)
                .offset(x: -1.5, y: -1.5)
        }
        .frame(width: 143, height: 135)
        .shadow(color: .black.opacity(0.7), radius: 11, x: 3, y: 16)
    }
}

private struct InvitationSpeechShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        return Path { path in
            path.move(to: point(0.23, 0.03))
            path.addLine(to: point(0.77, 0.03))
            path.addQuadCurve(to: point(0.97, 0.23), control: point(0.97, 0.03))
            path.addLine(to: point(0.97, 0.62))
            path.addQuadCurve(to: point(0.77, 0.82), control: point(0.97, 0.82))
            path.addLine(to: point(0.32, 0.82))
            path.addQuadCurve(to: point(0.13, 0.97), control: point(0.20, 0.93))
            path.addLine(to: point(0.16, 0.81))
            path.addQuadCurve(to: point(0.03, 0.63), control: point(0.03, 0.79))
            path.addLine(to: point(0.03, 0.23))
            path.addQuadCurve(to: point(0.23, 0.03), control: point(0.03, 0.03))
            path.closeSubpath()
        }
    }
}

// MARK: - Activity: a small terrain object, a route and two independent markers

private struct InvitationActivityObjects: View {
    let accepted: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            InvitationTerrain()
            InvitationTrail()
                .stroke(Palette.activity.opacity(0.15), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .blur(radius: 3)
            InvitationTrail()
                .stroke(Palette.activity, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 8]))
                .opacity(accepted ? 1 : 0.85)
            InvitationLocationPin()
                .scaleEffect(0.82, anchor: .bottom)
                .position(x: 277, y: 63)
            InvitationLocationPin()
                .position(x: 96, y: 140)
        }
        .frame(width: 376, height: 220)
    }
}

private struct InvitationTerrain: View {
    var body: some View {
        ZStack {
            terrainBase
                .fill(Color(hex: 0x070A0B))
                .offset(y: 9)
                .shadow(color: .black.opacity(0.75), radius: 9, x: 0, y: 12)
            terrainBase
                .fill(LinearGradient(colors: [Color(hex: 0x363E40), Color(hex: 0x141A1C)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            ridge(points: [(42, 159), (124, 91), (153, 131), (183, 51), (226, 116), (278, 98), (341, 151)])
                .fill(Color(hex: 0x262D30))
            ridge(points: [(42, 159), (124, 91), (102, 159), (183, 51), (166, 151), (226, 116), (278, 98), (246, 171), (341, 151)])
                .fill(LinearGradient(colors: [Color(hex: 0x4B5354), Color(hex: 0x171D1F)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            InvitationTerrainContours()
                .stroke(Color(hex: 0x7E8785).opacity(0.26), lineWidth: 0.8)
            Path { path in
                path.move(to: CGPoint(x: 35, y: 171))
                path.addLine(to: CGPoint(x: 166, y: 209))
                path.addLine(to: CGPoint(x: 346, y: 161))
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var terrainBase: Path {
        Path { path in
            path.move(to: CGPoint(x: 31, y: 164))
            path.addLine(to: CGPoint(x: 91, y: 122))
            path.addLine(to: CGPoint(x: 183, y: 96))
            path.addLine(to: CGPoint(x: 279, y: 87))
            path.addLine(to: CGPoint(x: 349, y: 151))
            path.addLine(to: CGPoint(x: 346, y: 170))
            path.addLine(to: CGPoint(x: 166, y: 216))
            path.addLine(to: CGPoint(x: 31, y: 180))
            path.closeSubpath()
        }
    }

    private func ridge(points: [(CGFloat, CGFloat)]) -> Path {
        Path { path in
            path.move(to: CGPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.0, y: point.1))
            }
            path.addLine(to: CGPoint(x: 166, y: 209))
            path.closeSubpath()
        }
    }
}

private struct InvitationTerrainContours: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<9 {
                let step = CGFloat(index) * 6
                path.move(to: CGPoint(x: 46 + step * 0.4, y: 167 + step * 0.55))
                path.addCurve(to: CGPoint(x: 328 - step * 0.4, y: 158 + step * 0.2),
                              control1: CGPoint(x: 118 + step, y: 118 + step * 1.2),
                              control2: CGPoint(x: 185 - step * 0.3, y: 121 + step))
            }
            for index in 0..<6 {
                let step = CGFloat(index) * 5
                path.move(to: CGPoint(x: 130 + step, y: 142 + step * 0.3))
                path.addLine(to: CGPoint(x: 183, y: 61 + step))
                path.addLine(to: CGPoint(x: 222 + step * 0.3, y: 132 + step))
            }
        }
    }
}

private struct InvitationTrail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 97, y: 179))
            path.addCurve(to: CGPoint(x: 210, y: 149),
                          control1: CGPoint(x: 146, y: 196), control2: CGPoint(x: 187, y: 183))
            path.addCurve(to: CGPoint(x: 278, y: 98),
                          control1: CGPoint(x: 225, y: 124), control2: CGPoint(x: 237, y: 94))
        }
    }
}

private struct InvitationLocationPin: View {
    var body: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .stroke(Palette.activity.opacity(0.8), lineWidth: 2)
                .frame(width: 43, height: 12)
                .offset(y: 79)
            InvitationPinShape()
                .fill(InvitationMetal.edge)
                .frame(width: 51, height: 84)
                .offset(x: -3, y: 1)
            InvitationPinShape()
                .fill(InvitationMetal.edge)
                .overlay {
                    InvitationPinShape().stroke(InvitationMetal.thinHighlight, lineWidth: 1)
                }
                .frame(width: 46, height: 84)
            Ellipse()
                .fill(Color(hex: 0x172A13))
                .frame(width: 28, height: 31)
                .offset(y: 12)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x3F8F21), Palette.activity],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 23, height: 27)
                .overlay { Ellipse().stroke(Color.white.opacity(0.25), lineWidth: 1) }
                .offset(x: 1, y: 15)
        }
        .frame(width: 54, height: 92)
        .shadow(color: .black.opacity(0.55), radius: 4, x: 3, y: 5)
    }
}

private struct InvitationPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.3),
                          control1: CGPoint(x: rect.width * 0.3, y: rect.height * 0.83),
                          control2: CGPoint(x: rect.minX, y: rect.height * 0.5))
            path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control1: CGPoint(x: rect.minX, y: rect.height * 0.1),
                          control2: CGPoint(x: rect.width * 0.2, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.3),
                          control1: CGPoint(x: rect.width * 0.8, y: rect.minY),
                          control2: CGPoint(x: rect.maxX, y: rect.height * 0.1))
            path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control1: CGPoint(x: rect.maxX, y: rect.height * 0.5),
                          control2: CGPoint(x: rect.width * 0.7, y: rect.height * 0.83))
            path.closeSubpath()
        }
    }
}

// MARK: - Dating: the paired rings belong only to this intent

private struct InvitationDatingObjects: View {
    let accepted: Bool

    var body: some View {
        ZStack {
            InvitationDatingRing()
                .rotationEffect(.degrees(accepted ? -13 : 10))
                .position(x: accepted ? 164 : 111, y: 112)
            InvitationDatingRing()
                .scaleEffect(0.88)
                .rotationEffect(.degrees(accepted ? 13 : -9))
                .position(x: accepted ? 222 : 271, y: 130)
        }
    }
}

private struct InvitationDatingRing: View {
    var body: some View {
        ZStack {
            Ellipse()
                .strokeBorder(InvitationMetal.edge, lineWidth: 14)
                .offset(x: -7, y: 2)
            Ellipse()
                .strokeBorder(LinearGradient(
                    colors: [Color(hex: 0x4A283D), Palette.dating, Color(hex: 0xFFE1F0), Color(hex: 0x982865)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 9)
                .padding(8)
                .offset(x: 3)
            Ellipse()
                .strokeBorder(InvitationMetal.edge, lineWidth: 10)
            Ellipse()
                .strokeBorder(InvitationMetal.thinHighlight, lineWidth: 1)
                .padding(1)
            Ellipse()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8)
                .padding(10)
        }
        .frame(width: 108, height: 161)
        .shadow(color: .black.opacity(0.65), radius: 6, x: 3, y: 10)
    }
}
