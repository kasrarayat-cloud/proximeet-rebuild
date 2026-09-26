import SwiftUI
import ProximeetDomain

/// Chapter 03 — the approved Pass (handoff `LAYOUT_SPEC.json`, Figma 26:282; intro, progress
/// and complete 27:111–27:113), on the 440 × 956 reference canvas.
///
/// A user-controlled preview of an age-check experience. It performs no age or identity
/// verification, stores nothing and grants nothing. The stage (`PassDemo`) is view-local, so
/// every entry from Birthday starts at the intro, and it changes only when the guest presses
/// the matching control: Try the demo, Finish preview, Cancel. Continue preview on the
/// complete stage only shows "End of this preview." and stays. Back and Leave demo return to
/// the actual Birthday screen, whose draft is kept.
///
/// The ivory pass, clip and loop are the approved raster decoration (`PassArtwork`, the full
/// 1254² source fitted to the 400 × 400 artwork box); every word on it is native text, moved
/// with the art as one unit.
struct PassView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var demo = PassDemo()
    @State private var isShowingEndOfPreview = false
    /// Changed by Cancel only, so the pass dissolves (180 ms) into its settled place, as in
    /// Figma, instead of gliding there.
    @State private var cardEpoch = 0

    var body: some View {
        GeometryReader { proxy in
            let card = min(400, proxy.size.width - 40)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    headline
                        .padding(.top, 46)
                    PassBodyText(text: copy.support, face: .regular)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .accessibilityIdentifier("pass.support")
                    // Its own layer, so a Cancel dissolve overlaps the two passes instead of
                    // stacking them.
                    ZStack {
                        PassCard(width: card)
                            .offset(y: cardLift * card / 400)
                            .id(cardEpoch)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    PassBodyText(text: "No age or identity verification\nis performed.", face: .medium)
                        .accessibilityLabel(Text("No age or identity verification is performed."))
                        .padding(.horizontal, 32)
                        .padding(.top, 9)
                        .accessibilityIdentifier("pass.claim")
                    primaryButton
                        .padding(.top, 25)
                    exitButton
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(PassStyle.ground.ignoresSafeArea())
        .background(RepeatTapGuard())
        .toolbar(.hidden, for: .navigationBar)
        .alert("End of this preview.", isPresented: $isShowingEndOfPreview) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: demo.stage) { _, stage in
            AccessibilityNotification.Announcement(Self.announcement(for: stage)).post()
        }
    }

    // MARK: - Rows

    /// Back (44 × 44 at 24, 64), the wordmark (Bold 22/32 at x 84) and the DEMO label
    /// (80 × 32 at 320, 70), all centred on the 44-pt header row.
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                session.leavePass()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("pass.back")
            PassWordmark()
            Spacer(minLength: 8)
            PassDemoBadge()
        }
        .frame(minHeight: 44)
        .padding(.leading, 24)
        .padding(.trailing, 40)
        .padding(.top, 2)
    }

    /// ExtraBold 56/59, −2.2, on the approved line breaks.
    private var headline: some View {
        PassHeadline(lines: copy.headline)
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(copy.headline.joined(separator: " ")))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pass.headline")
    }

    /// 376 × 60 at y 812: Try the demo, Finish preview or Continue preview. Each names its own
    /// transition, which does nothing from any other stage.
    private var primaryButton: some View {
        Button(copy.primary) {
            switch demo.stage {
            case .intro:
                withAnimation(stageAnimation) { _ = demo.start() }
            case .progress:
                withAnimation(stageAnimation) { _ = demo.finish() }
            case .complete:
                if demo.continuePreview() {
                    isShowingEndOfPreview = true
                }
            }
        }
        .buttonStyle(PassPrimaryStyle())
        .padding(.horizontal, 32)
        .accessibilityIdentifier("pass.primary")
    }

    /// 376 × 44 at y 880: Leave demo (to Birthday) or, in progress, Cancel (to the intro).
    private var exitButton: some View {
        Button(copy.exit) {
            if demo.stage == .progress {
                withAnimation(dissolveAnimation) {
                    if demo.cancel() {
                        cardEpoch &+= 1
                    }
                }
            } else {
                session.leavePass()
            }
        }
        .buttonStyle(PassExitStyle())
        .padding(.horizontal, 32)
        .accessibilityIdentifier("pass.exit")
    }

    // MARK: - Motion

    /// Start and finish: 220 ms, ease-out (Figma smart animate). Reduce Motion: a brief dissolve.
    private var stageAnimation: Animation? {
        if adaptive.voiceOverRunning { return nil }
        return adaptive.reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.22)
    }

    /// Cancel: 180 ms dissolve, ease-out (the text and the pass cross-dissolve to the intro).
    private var dissolveAnimation: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: adaptive.reduceMotion ? 0.12 : 0.18)
    }

    /// The pass lifts 6 pt while the demo is in progress (Figma: 330 → 324) and settles back
    /// when it completes or is cancelled. Reduce Motion keeps it stationary.
    private var cardLift: CGFloat {
        demo.stage == .progress && !adaptive.reduceMotion ? -6 : 0
    }

    // MARK: - Copy

    private var copy: PassCopy { PassCopy(stage: demo.stage) }

    /// Spoken when the stage changes: the demo state, never a verification result.
    static func announcement(for stage: PassDemo.Stage) -> String {
        let copy = PassCopy(stage: stage)
        return copy.headline.joined(separator: " ") + " " + copy.support
    }
}

/// The approved words for each stage.
struct PassCopy {
    let headline: [String]
    let support: String
    let primary: String
    let exit: String

    init(stage: PassDemo.Stage) {
        switch stage {
        case .intro:
            headline = ["Your next", "chapter."]
            support = "Preview the age-check experience."
            primary = "Try the demo"
            exit = "Leave demo"
        case .progress:
            headline = ["Demo in", "progress."]
            support = "You control this preview."
            primary = "Finish preview"
            exit = "Cancel"
        case .complete:
            headline = ["Demo", "complete."]
            support = "You have finished the demo."
            primary = "Continue preview"
            exit = "Leave demo"
        }
    }
}

// MARK: - Text

/// Regular or Medium 16/24 body text that follows Dynamic Type, every line on the 24-pt pitch.
private struct PassBodyText: View {
    let text: String
    let face: Manrope
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        let extra = max(0, 24 * size / 16 - face.naturalLineHeight(size: size))
        Text(text)
            .font(face.font(size: size))
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .foregroundStyle(PassStyle.secondaryText)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
    }
}

/// "Proximeet" Bold 22 on Figma's 32-pt line, centred on the header row.
private struct PassWordmark: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22

    var body: some View {
        Text("Proximeet")
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manrope(.bold, size: size, designSize: 22, lineHeight: 32)
            .foregroundStyle(.white)
    }
}

/// The persistent DEMO label: Bold 16/24 cyan in an 80 × 32 outline (radius 8, cyan at 45 %).
/// Hidden from VoiceOver: the pass itself and the headline already say this is a demo.
private struct PassDemoBadge: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        Text("DEMO")
            .lineLimit(1)
            .manrope(.bold, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(PassStyle.cyan)
            .frame(minWidth: 80, minHeight: 32)
            .padding(.horizontal, size > 16 ? 6 : 0)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(PassStyle.cyan.opacity(0.45), lineWidth: 1)
            }
            .accessibilityHidden(true)
            .accessibilityIdentifier("pass.demoBadge")
    }
}

private struct PassHeadline: View {
    let lines: [String]
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .manrope(.extraBold, size: size, designSize: 56, lineHeight: 59, tracking: -2.2)
                    .contentTransition(.opacity)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - The pass

/// The approved pass: the original artwork fitted to its 400 × 400 box, with the native card
/// text placed on it at the Figma card coordinates (28:118), all scaled together with `width`.
/// One accessibility element; the artwork is decoration.
private struct PassCard: View {
    let width: CGFloat

    private var s: CGFloat { width / 400 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(decorative: "PassArtwork")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: width, height: width)
            cardText("18+", face: .extraBold, size: 88, lineHeight: 100, color: PassStyle.cardInk,
                     box: CGRect(x: 92, y: 115, width: 216, height: 100))
            cardText("DEMO PASS", face: .extraBold, size: 24, lineHeight: 32, color: PassStyle.cardTeal,
                     box: CGRect(x: 92, y: 225, width: 216, height: 36))
            Rectangle()
                .fill(PassStyle.cardRule.opacity(0.30))
                .frame(width: 156 * s, height: max(1, s))
                .padding(.leading, 122 * s)
                .padding(.top, 278 * s)
            cardText("PROXIMEET", face: .medium, size: 16, lineHeight: 24, color: PassStyle.cardInk,
                     box: CGRect(x: 92, y: 302, width: 216, height: 24), tracking: 2)
        }
        .frame(width: width, height: width, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        // The printed PROXIMEET is not read again: the header wordmark already names the brand.
        .accessibilityLabel(Text("Demo pass, 18 plus"))
        .accessibilityIdentifier("pass.card")
    }

    /// Card type is part of the printed pass: it scales with the pass, not with Dynamic Type.
    /// Each line sits where Figma sets it: its line box (`lineHeight`) at the top of the text
    /// box, the glyphs centred on that line (so "DEMO PASS", 32 on a 36 box, is not centred
    /// in the box).
    private func cardText(
        _ text: String, face: Manrope, size: CGFloat, lineHeight: CGFloat, color: Color, box: CGRect,
        tracking: CGFloat = 0
    ) -> some View {
        Text(text)
            .font(face.font(size: size * s))
            .tracking(tracking * s)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .frame(width: box.width * s, height: lineHeight * s)
            .padding(.leading, box.minX * s)
            .padding(.top, box.minY * s)
    }
}

// MARK: - Style

enum PassStyle {
    static let ground = Color(hex: 0x050606)
    static let secondaryText = Color(hex: 0xA8B0AD)
    static let cyan = Color(hex: 0x38DBE5)
    static let cardInk = Color(hex: 0x050606)
    static let cardTeal = Color(hex: 0x06575E)
    static let cardRule = Color(hex: 0x14383B)
    static let primary = Color(hex: 0xF6F7F2)
}

/// 376 × 60, radius 18, #F6F7F2 with a #050606 label (SemiBold 18/24).
private struct PassPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PassPrimaryBody(configuration: configuration)
    }
}

private struct PassPrimaryBody: View {
    let configuration: ButtonStyleConfiguration
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .manrope(.semiBold, size: size, designSize: 18, lineHeight: 24)
            .foregroundStyle(PassStyle.ground)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(PassStyle.primary, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// 376 × 44 text action: Medium 16/24, white, centred.
private struct PassExitStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PassExitBody(configuration: configuration)
    }
}

private struct PassExitBody: View {
    let configuration: ButtonStyleConfiguration
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        configuration.label
            .manrope(.medium, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#if DEBUG
#Preview("Pass · intro") {
    NavigationStack { PassView() }
        .environment(PreviewFixtures.session(at: .pass))
}
#endif
