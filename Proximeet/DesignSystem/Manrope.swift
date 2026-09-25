import CoreText
import SwiftUI
import UIKit

/// Manrope, the typeface of the approved Welcome composition (chapter 01 handoff,
/// `fonts/FONT_SOURCE.json`). The five static weights ship unmodified as data sets in the
/// asset catalog, with the original SIL Open Font License beside them in `Manrope-OFL`.
///
/// The generated Info.plist has no `UIAppFonts` entry, so the faces are registered for
/// this process at launch. A face that fails to register is reported, never silently
/// replaced: SwiftUI would otherwise fall back to the system font without a sound.
enum Manrope: String, CaseIterable {
    case regular = "Manrope-Regular"
    case medium = "Manrope-Medium"
    case semiBold = "Manrope-SemiBold"
    case bold = "Manrope-Bold"
    case extraBold = "Manrope-ExtraBold"

    // The raw value is both the PostScript name and the data set name.

    @MainActor private static var unavailable: [Manrope]?

    /// Registers every weight once and returns the ones that are not available.
    @MainActor
    @discardableResult
    static func register() -> [Manrope] {
        if let unavailable { return unavailable }
        let failures = allCases.filter { !$0.registerFromAssetCatalog() }
        unavailable = failures
        return failures
    }

    @MainActor
    private func registerFromAssetCatalog() -> Bool {
        guard let asset = NSDataAsset(name: rawValue),
              let provider = CGDataProvider(data: asset.data as CFData),
              let font = CGFont(provider) else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(font, &error) { return true }
        _ = error?.takeRetainedValue()
        // Already registered is not a failure; the face is what matters.
        return UIFont(name: rawValue, size: 12) != nil
    }

    /// The face at an exact size. Callers scale `size` with `@ScaledMetric`, so the approved
    /// sizes are exact at the default text size and follow Dynamic Type from there.
    @MainActor
    func font(size: CGFloat) -> Font {
        Self.register()
        return .custom(rawValue, fixedSize: size)
    }

    /// One line of this face as Core Text sets it: ascender + descender + line gap
    /// (2132 + 600 + 0 of 2000 units, 1.366 em, in every weight).
    func naturalLineHeight(size: CGFloat) -> CGFloat {
        UIFont(name: rawValue, size: size)?.lineHeight ?? size * 1.366
    }
}

/// Sets text on an approved Figma line height.
///
/// Figma centres the glyphs in every line box, splitting the leading evenly above and below.
/// For Manrope that leading is often negative (the Welcome headline is 59 pt against a
/// natural 76.5 pt line), which `lineSpacing` cannot express. A line that fits therefore
/// gets a frame of exactly the line height with its glyphs centred, which matches Figma's
/// baseline. Text that has to wrap (larger Dynamic Type, narrower phones) falls back to the
/// natural line plus any positive leading, so lines never overlap.
struct ManropeLineBox: ViewModifier {
    let face: Manrope
    let size: CGFloat
    let lineHeight: CGFloat

    func body(content: Content) -> some View {
        let extra = max(0, lineHeight - face.naturalLineHeight(size: size))
        ViewThatFits(in: .horizontal) {
            content
                .fixedSize()
                .frame(height: lineHeight)
            content
                .lineSpacing(extra)
                .padding(.vertical, extra / 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// Manrope at `size` (already scaled), tracked and set on its Figma line height. The
    /// Figma values are given at the default text size and scale with `size / designSize`.
    @MainActor
    func manrope(
        _ face: Manrope,
        size: CGFloat,
        designSize: CGFloat,
        lineHeight: CGFloat,
        tracking: CGFloat = 0
    ) -> some View {
        let scale = size / designSize
        return self
            .font(face.font(size: size))
            .tracking(tracking * scale)
            .modifier(ManropeLineBox(face: face, size: size, lineHeight: lineHeight * scale))
    }
}
