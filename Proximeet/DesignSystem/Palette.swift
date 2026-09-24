import SwiftUI

/// Social Objects working tokens (docs/design/PROXIMEET_SOCIAL_OBJECTS_DESIGN.md).
/// Intent colours are semantic and always paired with a word and an icon.
enum Palette {
    static let carbon = Color(hex: 0x080A0B)
    static let graphite = Color(hex: 0x171A1D)
    static let alloyShadow = Color(hex: 0x25292D)
    static let porcelain = Color(hex: 0xF5F6F2)
    static let quietText = Color(hex: 0xAAB0B5)
    /// Supporting text when Increase Contrast is on.
    static let quietTextIncreased = Color(hex: 0xD6DADD)
    /// Frame border from the Figma study.
    static let hairline = Color(hex: 0x32383B)
    /// Secondary ink on Porcelain stock (roster and pass).
    static let stockInk = Color(hex: 0x3A3F43)
    static let stockChip = Color(hex: 0xE3E5E0)
    /// Thick bright pass and roster stock: lit top edge, faintly shaded foot.
    static let paper = Color(hex: 0xFCFCF9)
    static let paperShade = Color(hex: 0xECEDE8)
    /// Printed rules and perforations on paper stock.
    static let paperRule = Color(hex: 0xC9CCC6)

    static let social = Color(hex: 0x35D7FF)
    static let dating = Color(hex: 0xFF56B8)
    static let business = Color(hex: 0xFFD542)
    static let activity = Color(hex: 0x70F455)
    static let danger = Color(hex: 0xFF6B7B)

    static func quiet(increasedContrast: Bool) -> Color {
        increasedContrast ? quietTextIncreased : quietText
    }
}

/// Machined-metal gradients from the Figma B1/B2 study (CSS angles in degrees).
enum MetalFinish {
    /// B1 clasp: 115°, #4A5459 → #CCD2D5 (38.4%) → #68747A (80%).
    static var clasp: [Gradient.Stop] {
        [
            .init(color: Color(hex: 0x4A5459), location: 0),
            .init(color: Color(hex: 0xCCD2D5), location: 0.384),
            .init(color: Color(hex: 0x68747A), location: 0.8),
        ]
    }
    static let claspAngle = 115.0

    /// Subtle dark side clasp on the woven loop: smoked graphite alloy with one soft
    /// highlight, lit from the upper left like the loop artwork.
    static var darkClasp: [Gradient.Stop] {
        [
            .init(color: Color(hex: 0x16191C), location: 0),
            .init(color: Color(hex: 0x4A545A), location: 0.38),
            .init(color: Color(hex: 0x1D2124), location: 0.86),
        ]
    }
    static let darkClaspAngle = 112.0
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension UnitPoint {
    /// Start and end points matching the direction of CSS `linear-gradient(<deg>deg, …)`.
    static func cssGradientPoints(degrees: Double) -> (start: UnitPoint, end: UnitPoint) {
        let radians = degrees * .pi / 180
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}
