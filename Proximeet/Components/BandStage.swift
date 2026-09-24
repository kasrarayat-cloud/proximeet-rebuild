import SwiftUI
import ProximeetDomain

/// Whether an assembled band carries the signal plate mount.
enum PlateMount: Equatable {
    /// B1: loop, word and clasp only.
    case bare
    /// B2 and Ready: the link ring hangs from the clasp; a chosen signal's plate is
    /// clipped to it. `nil` shows the empty ring.
    case mounted(ApproachSignal?)
}

/// One assembled band object: the tinted woven loop, the white intent word on its front
/// strap, the dark side clasp and, when mounted, the small signal plate. B1, B2 and Ready
/// all draw this view, so the object keeps identical geometry (`BandGeometry`) at every
/// size. It sizes itself to the width it is offered and keeps its aspect ratio.
///
/// Decorative for accessibility: the owning control or stage supplies the label.
struct BandAssembly: View {
    let intent: BandIntent
    var mount: PlateMount = .bare
    var claspClosed = true
    /// Local intent-colour light spill beneath the loop (off under Reduce Transparency).
    var glows = false
    /// A lower viewing angle for the shallow B1 rows. Labels retain their native height.
    var verticalProjection: CGFloat = 1
    var claspAnimation: Animation?
    @Adaptive private var adaptive

    private var widthFactor: CGFloat {
        mount == .bare ? BandGeometry.loopAspect : BandGeometry.mountedWidth
    }

    private var heightFactor: CGFloat {
        mount == .bare ? 1 : BandGeometry.mountedHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let loopHeight = min(proxy.size.width / widthFactor, proxy.size.height / (heightFactor * verticalProjection))
            assembly(loopHeight: loopHeight)
                .scaleEffect(x: 1, y: verticalProjection, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(widthFactor / (heightFactor * verticalProjection), contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func assembly(loopHeight h: CGFloat) -> some View {
        let loopWidth = BandGeometry.loopAspect * h
        let claspCenterX = BandGeometry.claspCenterX * h
        return ZStack(alignment: .topLeading) {
            // Contact shadow: one consistent light from above for every loop.
            Ellipse()
                .fill(Color.black.opacity(0.6))
                .frame(width: loopWidth * 0.84, height: h * 0.16)
                .blur(radius: h * 0.06)
                .offset(x: loopWidth * 0.08, y: h * 0.86)

            if glows && !adaptive.reduceTransparency {
                Ellipse()
                    .fill(intent.tint.opacity(0.38))
                    .frame(width: loopWidth * 0.78, height: h * 0.34)
                    .blur(radius: h * 0.16)
                    .offset(x: loopWidth * 0.11, y: h * 0.7)
            }

            WovenLoop(tint: intent.tint)
                .frame(width: loopWidth, height: h)

            StrapWord(text: intent.title, loopHeight: h)
                .scaleEffect(x: 1, y: 1 / verticalProjection)
                .frame(
                    width: h * BandGeometry.wordRegionWidth,
                    height: h * BandGeometry.wordRegionHeight
                )
                .offset(
                    x: h * (BandGeometry.wordCenterX - BandGeometry.wordRegionWidth / 2),
                    y: h * (BandGeometry.wordCenterY - BandGeometry.wordRegionHeight / 2)
                )

            if case .mounted(let signal) = mount {
                PlateLink()
                    .frame(width: h * BandGeometry.linkDiameter, height: h * BandGeometry.linkDiameter)
                    .offset(
                        x: claspCenterX - h * BandGeometry.linkDiameter / 2,
                        y: h * (BandGeometry.linkCenterY - BandGeometry.linkDiameter / 2)
                    )

                // A persistent slot sized to the plate, so the seating arc turns about the
                // plate's own centre whichever signal is inserted.
                ZStack {
                    if let signal {
                        AttachedPlate(signal: signal)
                            .id(signal)
                            .transition(adaptive.tagSeatTransition)
                    }
                }
                .frame(width: h * BandGeometry.plateWidth, height: h * BandGeometry.plateHeight)
                .offset(
                    x: claspCenterX - h * BandGeometry.plateWidth / 2,
                    y: h * BandGeometry.plateTop
                )
            }

            SideClasp(isClosed: claspClosed)
                .frame(width: h * BandGeometry.claspWidth, height: h * BandGeometry.claspHeight)
                .animation(claspAnimation, value: claspClosed)
                .offset(
                    x: claspCenterX - h * BandGeometry.claspWidth / 2,
                    y: h * (BandGeometry.claspCenterY - BandGeometry.claspHeight / 2)
                )
        }
        .animation(adaptive.tagSeatAnimation, value: mount)
    }
}

/// The persistent band on B2 and the ready summary: the confirmed band, secured, with the
/// chosen signal plate clipped to its clasp.
///
/// With `playsSecuringOnAppear`, the first appearance of this view instance runs the
/// band-confirm choreography (lift, curve, close clasp, settle ≈ 0.75 s). The model is
/// already secured before this view exists; the animation only decorates it and nothing
/// waits for it. Reduce Motion shows the static secured pose with a short crossfade, and
/// VoiceOver skips the entrance entirely.
struct BandStage: View {
    let intent: BandIntent
    let signal: ApproachSignal?
    /// Loop height at full size; the stage shrinks proportionally on narrow screens.
    var maxLoopHeight: CGFloat = 146
    var playsSecuringOnAppear = false
    @Adaptive private var adaptive
    @State private var hasAppeared = false

    private var isPosed: Bool {
        hasAppeared || !playsSecuringOnAppear || !adaptive.playsEntrances
    }

    private var fadesIn: Bool {
        playsSecuringOnAppear && adaptive.reduceMotion && !adaptive.voiceOverRunning
    }

    var body: some View {
        BandAssembly(
            intent: intent,
            mount: .mounted(signal),
            claspClosed: isPosed,
            glows: true,
            claspAnimation: adaptive.claspAnimation
        )
        .modifier(LiftCurvePose(progress: isPosed ? 1 : 0))
        .animation(adaptive.reduceMotion ? nil : adaptive.bandSecureAnimation, value: isPosed)
        .opacity(fadesIn && !hasAppeared ? 0 : 1)
        .animation(fadesIn ? .easeInOut(duration: Motion.reducedBandCrossfade) : nil, value: hasAppeared)
        .frame(maxWidth: maxLoopHeight * BandGeometry.mountedWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            hasAppeared = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityDescription))
    }

    private var accessibilityDescription: String {
        if let signal {
            return "\(intent.title) band, secured, with the \(signal.title) tag clipped on"
        }
        return "\(intent.title) band, secured. No tag clipped on yet."
    }
}
