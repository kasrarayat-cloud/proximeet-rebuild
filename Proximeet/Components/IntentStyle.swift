import SwiftUI
import ProximeetDomain

// Icons: the Figma study's custom SVG icons could not be retrieved (downloads returned
// HTML, not SVG). These SF Symbols are documented INTERIM semantic substitutes chosen to
// match the described glyphs; they are not the final icon artwork.

extension BandIntent {
    var tint: Color {
        switch self {
        case .social: return Palette.social
        case .dating: return Palette.dating
        case .business: return Palette.business
        case .activity: return Palette.activity
        }
    }

    /// Figma "Icon / people", "heart", "business", "activity" (mountain).
    var symbolName: String {
        switch self {
        case .social: return "person.2"
        case .dating: return "heart"
        case .business: return "briefcase"
        case .activity: return "mountain.2"
        }
    }

    /// Short subtitle shown outside each B1 loop (Figma B1 subtitles).
    var tagline: String {
        switch self {
        case .social: return "Friends & crews"
        case .dating: return "Open to a match"
        case .business: return "Ideas & networks"
        case .activity: return "Do something together"
        }
    }

    /// Position in the fixed band order, used for the staggered arrival.
    var order: Int {
        BandIntent.allCases.firstIndex(of: self) ?? 0
    }
}

extension ApproachSignal {
    /// Figma "Icon / wave", "chat", "people", "eye".
    var symbolName: String {
        switch self {
        case .comeSayHi: return "hand.raised"
        case .chatFirst: return "bubble.left"
        case .withMyCrew: return "person.2"
        case .justLooking: return "eye"
        }
    }
}
