import SwiftUI

/// Shared proportions of the assembled band object, as fractions of the loop's height
/// (the loop image is 2 loop-heights wide).
///
/// B1, B2 and Ready all draw one assembly (loop, word, side clasp and, when mounted, the
/// signal plate) from these values, so the object keeps the same geometry at every size.
/// Positions follow the delivered `WovenBandNeutral` artwork and the lead's asset notes
/// (docs/visual-assets/asset-manifest.json): opaque loop bounds x 86–1694 and y 47–841 of
/// 1774 × 887 px, front-strap label at about x 0.48, y 0.76 of the image, clasp at the
/// right-hand turn. They still need confirmation on a native render.
enum BandGeometry {
    /// `WovenBandNeutral` is 1774 × 887 px: one oval loop, elevated three-quarter view.
    static let loopAspect: CGFloat = 1774.0 / 887.0

    /// The intent word sits on the front strap.
    static let wordCenterX: CGFloat = 0.48 * loopAspect
    static let wordCenterY: CGFloat = 0.76
    static let wordSize: CGFloat = 0.17
    static let wordRegionWidth: CGFloat = 1.24
    static let wordRegionHeight: CGFloat = 0.24

    /// The dark clasp wraps the loop's right-hand turn (about x 0.93 of the image).
    static let claspCenterX: CGFloat = 0.93 * loopAspect
    static let claspCenterY: CGFloat = 0.57
    static let claspWidth: CGFloat = 0.12
    static let claspHeight: CGFloat = 0.44

    /// Link ring between the clasp foot and a mounted plate.
    static let linkDiameter: CGFloat = 0.09
    static let linkCenterY: CGFloat = 0.82

    /// Mounted signal plate: a small landscape plate hanging from the ring, with the
    /// same face aspect as the plate choices (`SignalPlateGeometry.faceAspect`).
    static let plateHeight: CGFloat = 0.34
    static let plateTop: CGFloat = 0.855

    static var plateWidth: CGFloat { SignalPlateGeometry.faceAspect * plateHeight }
    /// How far a mounted plate extends past the loop image's trailing edge.
    static var plateOverhang: CGFloat { max(0, claspCenterX + plateWidth / 2 - loopAspect) }
    /// Assembly size, in loop heights, with a mounted plate.
    static var mountedWidth: CGFloat { loopAspect + plateOverhang }
    static var mountedHeight: CGFloat { plateTop + plateHeight }
}

/// Where the machined face sits inside the delivered `SignalPlateBlank` artwork (opaque
/// bounds x 47–1561 and y 89–884 of 1609 × 978 px). Plates map this face, not the
/// transparent margin, onto their frames, so a 1.904:1 frame shows it undistorted.
enum SignalPlateGeometry {
    static let imageSize = CGSize(width: 1609, height: 978)
    static let face = CGRect(x: 47, y: 89, width: 1561 - 47, height: 884 - 89)
    static var faceAspect: CGFloat { face.width / face.height }
}

/// One oval woven loop: the lead-supplied neutral raster, tinted by multiplying with the
/// intent colour. The transparent inner hole shows whatever is behind the loop.
struct WovenLoop: View {
    /// Opaque loop bounds (x 86–1694, y 47–841 of 1774 × 887 px) plus an 8 px soft-edge
    /// allowance; clipping here drops faint flecks in the transparent margin only.
    private static let visibleBounds = CGRect(
        x: 78.0 / 1774, y: 39.0 / 887,
        width: (1702.0 - 78) / 1774, height: (849.0 - 39) / 887
    )
    let tint: Color

    var body: some View {
        Image(decorative: "WovenBandNeutral")
            .resizable()
            .interpolation(.high)
            .aspectRatio(BandGeometry.loopAspect, contentMode: .fit)
            .colorMultiply(tint)
            .clipShape(UnitRect(bounds: Self.visibleBounds))
    }
}

/// A rectangle given in unit coordinates of the frame it is drawn in.
struct UnitRect: Shape {
    let bounds: CGRect

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX + rect.width * bounds.minX,
            y: rect.minY + rect.height * bounds.minY,
            width: rect.width * bounds.width,
            height: rect.height * bounds.height
        ))
    }
}

/// The intent word printed in white on the loop's front strap. It is part of the object,
/// so it scales with the loop rather than with Dynamic Type; the band's accessible name
/// and external subtitle carry the same meaning in scalable text.
struct StrapWord: View {
    let text: String
    let loopHeight: CGFloat
    @Adaptive private var adaptive

    var body: some View {
        Text(text)
            .font(.system(size: max(11, loopHeight * BandGeometry.wordSize), weight: .heavy))
            .tracking(0.3)
            .foregroundStyle(Color.white)
            .fixedSize()
            .shadow(color: Palette.carbon.opacity(0.8), radius: 1.2, y: 1)
            .shadow(color: Palette.carbon.opacity(0.45), radius: 4)
            .padding(.horizontal, adaptive.increaseContrast ? loopHeight * 0.05 : 0)
            .padding(.vertical, adaptive.increaseContrast ? loopHeight * 0.012 : 0)
            .background {
                if adaptive.increaseContrast {
                    Capsule().fill(Palette.carbon.opacity(0.78))
                }
            }
    }
}
