import SwiftUI

/// Interim procedural woven strap: intent colour, vertical ribs (Figma: 1 pt at 12% Carbon
/// every 15 pt), a fine weft, tubular shading, a top highlight and edge stitching.
/// Static drawing only; not the photoreal production textile.
struct WovenStrip: View {
    let tint: Color
    var ribSpacing: CGFloat = 15
    var cornerRadius: CGFloat = 12
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(tint)
            .overlay {
                WeaveTexture(ribSpacing: ribSpacing, strength: adaptive.increaseContrast ? 0.5 : 1)
                    .clipShape(shape)
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.14), location: 0),
                        .init(color: Color.clear, location: 0.35),
                        .init(color: Color.black.opacity(0.16), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Palette.porcelain.opacity(0.4))
                    .frame(height: 2)
                    .padding(.horizontal, 10)
                    .padding(.top, 3)
            }
            .overlay {
                shape
                    .inset(by: 5)
                    .stroke(Palette.carbon.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .accessibilityHidden(true)
    }
}

/// Ribs plus a staggered weft, filled as two paths so a strap is only two draw calls.
struct WeaveTexture: View {
    var ribSpacing: CGFloat
    var strength: Double = 1

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }

            var ribs = Path()
            var x = ribSpacing * 0.66
            while x < size.width {
                ribs.addRect(CGRect(x: x, y: 1, width: 1, height: size.height - 2))
                x += ribSpacing
            }

            var weft = Path()
            let cell = CGSize(width: 5, height: 3)
            let columns = Int(size.width / cell.width) + 1
            let rows = Int(size.height / cell.height) + 1
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    weft.addRect(CGRect(
                        x: CGFloat(column) * cell.width,
                        y: CGFloat(row) * cell.height + 0.8,
                        width: 3.2,
                        height: 1.1
                    ))
                }
            }

            context.fill(weft, with: .color(Palette.carbon.opacity(0.07 * strength)))
            context.fill(ribs, with: .color(Palette.carbon.opacity(0.12 * strength)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
