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

    /// B2 hero tag: 120.5°, #6E7B82 → #E4E9EC (38.4%) → #8B989F (80%).
    static var heroTag: [Gradient.Stop] {
        [
            .init(color: Color(hex: 0x6E7B82), location: 0),
            .init(color: Color(hex: 0xE4E9EC), location: 0.384),
            .init(color: Color(hex: 0x8B989F), location: 0.8),
        ]
    }
    static let heroTagAngle = 120.5

    /// B2 tag choice: 133°, #A4AEB4 → #F0F3F4 (38.4%) → #8C99A0 (80%).
    static var tagCard: [Gradient.Stop] {
        [
            .init(color: Color(hex: 0xA4AEB4), location: 0),
            .init(color: Color(hex: 0xF0F3F4), location: 0.384),
            .init(color: Color(hex: 0x8C99A0), location: 0.8),
        ]
    }
    static let tagCardAngle = 133.0
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
