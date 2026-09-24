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
    /// Signal selected → tag seated against the band (450–650 ms).
    static let tagSeat: Double = 0.55
    /// Reduce Motion crossfades (opacity only).
    static let reducedBandCrossfade: Double = 0.18
    static let reducedTagCrossfade: Double = 0.15
    /// Band screen arrival: 4 × stagger + item ≈ 0.66 s (600–850 ms).
    static let arrivalItem: Double = 0.42
    static let arrivalStagger: Double = 0.08
    static let selection: Double = 0.18
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

    /// Single arc into the clasp; opacity only under Reduce Motion.
    var tagSeatTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .modifier(active: ArcSeat(progress: 0), identity: ArcSeat(progress: 1)),
                removal: .opacity
            )
    }
}

/// Lifts the tag from below-left along one arc and settles it into the clasp.
struct ArcSeat: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let remaining = 1 - progress
        content
            .offset(x: -28 * remaining, y: 70 * remaining - 34 * sin(progress * .pi))
            .rotationEffect(.degrees(-14 * remaining))
            .scaleEffect(0.86 + 0.14 * progress)
            .opacity(min(1, progress * 3))
    }
}

/// Lift-and-curve pose of the band before it settles flat and secured.
struct LiftCurvePose: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let remaining = 1 - progress
        content
            .rotation3DEffect(.degrees(34 * remaining), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(x: 0.82 + 0.18 * progress, y: 1)
            .offset(y: -22 * remaining)
    }
}
