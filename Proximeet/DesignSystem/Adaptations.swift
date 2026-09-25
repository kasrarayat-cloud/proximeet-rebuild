import SwiftUI

// MARK: - App-level Reduce Motion preview

private struct ReducedMotionPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Presents the Reduce Motion variant without touching the system setting. Set only by
    /// DEBUG launch arguments and previews; the system value is read, never written.
    var prefersReducedMotionPreview: Bool {
        get { self[ReducedMotionPreviewKey.self] }
        set { self[ReducedMotionPreviewKey.self] = newValue }
    }
}

// MARK: - Resolved accessibility context

struct AccessibilityContext {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool
    let voiceOverRunning: Bool

    /// Arrivals are decorative; skip them for Reduce Motion and VoiceOver so every element
    /// is present immediately.
    var playsEntrances: Bool { !reduceMotion && !voiceOverRunning }
}

/// Reads the system accessibility settings a view needs in one place.
@propertyWrapper
struct Adaptive: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.prefersReducedMotionPreview) private var reducedMotionPreview

    init() {}

    var wrappedValue: AccessibilityContext {
        AccessibilityContext(
            reduceMotion: systemReduceMotion || reducedMotionPreview,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            voiceOverRunning: voiceOverEnabled
        )
    }
}

// MARK: - Motion score

/// Proposed choreography targets from the Social Objects motion score. Animations are
/// decorative: every state change is applied immediately and never waits for them.
enum Motion {
    /// Band confirmed → secured pose: lift, curve, close clasp, settle (650–850 ms).
    static let bandSecure: Double = 0.75
    static let claspCloseDelay: Double = 0.42
    static let claspClose: Double = 0.30
    /// Signal selected → plate clipped onto the band (450–650 ms).
    static let tagSeat: Double = 0.55
    /// Reduce Motion crossfades (opacity only).
    static let reducedBandCrossfade: Double = 0.18
    static let reducedTagCrossfade: Double = 0.15
    /// Band screen arrival: 4 × stagger + item ≈ 0.66 s (600–850 ms).
    static let arrivalItem: Double = 0.42
    static let arrivalStagger: Double = 0.08
    static let selection: Double = 0.18
    /// Welcome pose study (chapter 01 handoff): closed hold, then linear blends to the opening
    /// and settled poses, ending at 1.4 s. Played once; Reduce Motion shows the settled pose.
    static let welcomeClosedHold: Double = 0.4
    static let welcomeToOpening: Double = 0.45
    static let welcomeToSettled: Double = 0.55
    /// Pass or roster stock settling into place (450–650 ms).
    static let paperSettle: Double = 0.5
}

extension AccessibilityContext {
    var bandSecureAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: Motion.reducedBandCrossfade)
            : .timingCurve(0.2, 0.85, 0.25, 1, duration: Motion.bandSecure)
    }

    /// `nil` under Reduce Motion: the clasp is simply shown closed.
    var claspAnimation: Animation? {
        reduceMotion
            ? nil
            : .timingCurve(0.55, 0, 0.2, 1, duration: Motion.claspClose).delay(Motion.claspCloseDelay)
    }

    var tagSeatAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: Motion.reducedTagCrossfade)
            : .timingCurve(0.3, 0.7, 0.2, 1, duration: Motion.tagSeat)
    }

    var selectionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.12) : .snappy(duration: Motion.selection)
    }

    func arrivalAnimation(index: Int) -> Animation? {
        playsEntrances
            ? .easeOut(duration: Motion.arrivalItem).delay(Double(index) * Motion.arrivalStagger)
            : nil
    }

    /// Single arc onto the clasp; opacity only under Reduce Motion.
    var tagSeatTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .modifier(active: ArcSeat(progress: 0), identity: ArcSeat(progress: 1)),
                removal: .opacity
            )
    }

    var paperSettleAnimation: Animation? {
        if voiceOverRunning { return nil }
        return reduceMotion
            ? .easeOut(duration: Motion.reducedTagCrossfade)
            : .timingCurve(0.25, 0.8, 0.25, 1, duration: Motion.paperSettle)
    }
}

/// Lifts the signal plate from below-left along one arc and settles it onto the clasp.
///
/// The arc (a sine lift) is not linear in `progress`, so this modifier interpolates its
/// own value. It is declared `nonisolated` so the `Animatable` witness is genuinely
/// nonisolated instead of inheriting main-actor isolation from `ViewModifier`; its
/// state is a single `Double`. Only `body`, which builds views, runs on the main actor.
nonisolated struct ArcSeat: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @MainActor
    func body(content: Content) -> some View {
        let remaining = 1 - progress
        content
            .offset(x: -24 * remaining, y: 56 * remaining - 26 * sin(progress * .pi))
            .rotationEffect(.degrees(-12 * remaining))
            .scaleEffect(0.86 + 0.14 * progress)
            .opacity(min(1, progress * 3))
    }
}

/// Lift-and-curve pose of the band before it settles flat and secured.
///
/// Every transform is linear in `progress`, so the standard modifiers interpolate it
/// exactly; no custom `Animatable` conformance (and no isolation crossing) is needed.
struct LiftCurvePose: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        let remaining = 1 - progress
        content
            .rotation3DEffect(.degrees(30 * remaining), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(x: 0.84 + 0.16 * progress, y: 1)
            .offset(y: -20 * remaining)
    }
}

// MARK: - Finite entrances

/// One-shot entrance keyed to a view instance: `settled` flips once in `onAppear` and the
/// view is always interactive. Offset/scale only with normal motion; opacity only under
/// Reduce Motion; no entrance for VoiceOver.
struct SettleEntrance: ViewModifier {
    let settled: Bool
    var offsetY: CGFloat = 0
    var startScale: CGFloat = 1
    let animation: Animation?
    @Adaptive private var adaptive

    func body(content: Content) -> some View {
        let plays = animation != nil && !settled
        let moves = plays && !adaptive.reduceMotion
        content
            .offset(y: moves ? offsetY : 0)
            .scaleEffect(moves ? startScale : 1)
            .opacity(plays ? (adaptive.reduceMotion ? 0 : 0.4) : 1)
            .animation(animation, value: settled)
    }
}
