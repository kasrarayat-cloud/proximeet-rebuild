import SwiftUI
import ProximeetDomain

/// The persistent band: the confirmed band in its secured pose with the clasp closed and,
/// once chosen, the signal tag seated on the clasp. Shared by B2 and the ready summary so
/// the same object carries through.
///
/// With `playsSecuringOnAppear`, the first appearance runs the band-confirm choreography
/// (lift, curve, close clasp, settle ≈ 0.75 s). The model is already secured before this
/// view exists; the animation only decorates it and nothing waits for it.
struct BandStage: View {
    let intent: BandIntent
    let signal: ApproachSignal?
    var playsSecuringOnAppear = false
    @Adaptive private var adaptive
    @State private var hasAppeared = false

    private var isPosed: Bool {
        hasAppeared || !playsSecuringOnAppear || !adaptive.playsEntrances
    }

    var body: some View {
        ZStack {
            if !adaptive.reduceTransparency {
                Ellipse()
                    .fill(intent.tint.opacity(0.28))
                    .frame(height: 56)
                    .blur(radius: 26)
                    .offset(y: 26)
                    .accessibilityHidden(true)
            }

            WovenStrip(tint: intent.tint, ribSpacing: 13, cornerRadius: 14)
                .frame(height: 50)
                .padding(.horizontal, 14)
                .modifier(LiftCurvePose(progress: isPosed ? 1 : 0))
                .animation(adaptive.reduceMotion ? nil : adaptive.bandSecureAnimation, value: isPosed)

            StageClasp(intent: intent, isClosed: isPosed)
                .frame(width: 72, height: 64)
                .animation(adaptive.claspAnimation, value: isPosed)

            if let signal {
                HeroTag(signal: signal)
                    .frame(width: 108, height: 103)
                    .id(signal)
                    .transition(adaptive.tagSeatTransition)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .opacity(playsSecuringOnAppear && adaptive.reduceMotion && !hasAppeared ? 0 : 1)
        .animation(
            adaptive.reduceMotion ? .easeInOut(duration: Motion.reducedBandCrossfade) : nil,
            value: hasAppeared
        )
        .animation(adaptive.tagSeatAnimation, value: signal)
        .onAppear {
            hasAppeared = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityDescription))
    }

    private var accessibilityDescription: String {
        if let signal {
            return "\(intent.title) band, secured, with the \(signal.title) tag attached"
        }
        return "\(intent.title) band, secured. No tag attached yet."
    }
}
