import SwiftUI
import UIKit
import ProximeetDomain

/// Chapter 06 — the approved Signal (handoff `LAYOUT_SPEC.json`, Figma 50:190; the twelve states
/// 50:191–50:202), on the 440 × 956 reference canvas.
///
/// The carried intent (`DemoDraft.band`, chosen on the Wristband; Signal never opens without one)
/// and one optional approach (`DemoDraft.signal`): none on a fresh run, then Chat first or Okay to
/// say hello. Every row, the tag's pose and icon, the summary and Continue preview are derived
/// from those two values, so they cannot disagree. A tap chooses at once; the other row replaces
/// the choice; the chosen row does nothing. Nothing advances on its own.
///
/// Back (header or bottom) returns to the actual Wristband below, with the intent and the
/// approach kept. Continue preview, once an approach is chosen, only shows "End of this preview."
/// and stays: Places is not implemented.
///
/// An approach is a preference, not continuing consent. Choosing one sends or accepts no Wave,
/// opens no chat, creates no match and grants no permission to approach or message. The band
/// (`WristbandArt`, the canonical intent art) and the blank tag (`SignalTagArt`, the original
/// 1254² artwork cropped to [41, 154, 1216, 1060]) are raster decoration; every word, icon, radio
/// and control is native.
struct SignalView: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Adaptive private var adaptive
    @State private var isShowingEndOfPreview = false
    /// Bumped, without animation, to end a decorative movement at once: when Reduce Motion
    /// changes or the app becomes active again. The tag is then redrawn at its model pose.
    @State private var motionEpoch = 0

    var body: some View {
        if let intent = session.intent {
            screen(intent)
        } else {
            // Unreachable through the domain (Signal needs an intent); never shows a default.
            WristbandStyle.ground
                .ignoresSafeArea()
                .onAppear { session.leaveSignal() }
        }
    }

    private func screen(_ intent: BandIntent) -> some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    SignalHeadline()
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                    WristbandBodyText(text: "Let people know how to begin.", size: 17, lineHeight: 26,
                                      color: WristbandStyle.secondaryText, alignment: .leading)
                        .padding(.top, 14)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("signal.support")
                    SignalHero(intent: intent, approach: session.approach, width: min(376, proxy.size.width - 64))
                        .id(motionEpoch)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 26)
                    summary(intent)
                        .padding(.top, 5)
                        .padding(.horizontal, 32)
                    choices
                        .padding(.top, 10)
                        .padding(.horizontal, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ground behind the status bar, so scrolled text never runs under the clock.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(WristbandStyle.ground.ignoresSafeArea(edges: .top))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions(bottomInset: proxy.safeAreaInsets.bottom)
            }
        }
        .background(WristbandStyle.ground.ignoresSafeArea())
        .background(RepeatTapGuard())
        .toolbar(.hidden, for: .navigationBar)
        .alert("End of this preview.", isPresented: $isShowingEndOfPreview) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: session.approach) { _, approach in
            // Concise: the new choice only, never the whole screen again.
            if let approach {
                AccessibilityNotification.Announcement("\(approach.title) selected").post()
            }
        }
        .onChange(of: adaptive.reduceMotion) { _, _ in
            endMovement()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                endMovement()
            }
        }
    }

    // MARK: - Header

    /// Back (44 × 44 at 24, 64, the Figma arrow), the wordmark and the DEMO label, as on the
    /// Wristband.
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                session.leaveSignal()
            } label: {
                WristbandBackArrow()
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("signal.back")
            WristbandWordmark()
            Spacer(minLength: 8)
            WristbandDemoBadge(identifier: "signal.demoBadge")
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(minHeight: 44)
        .padding(.leading, 24)
        .padding(.trailing, 27)
        .padding(.top, 2)
    }

    // MARK: - Summary and choices

    /// "[Intent] band · Choose your approach", or "[Intent] band · [Preference]" (SemiBold 15/24,
    /// centred, y 547), then "You stay private until venue check-in." (Regular 14/20, y 572).
    private func summary(_ intent: BandIntent) -> some View {
        VStack(spacing: 1) {
            WristbandText(text: SignalSummary(intent: intent, approach: session.approach).title,
                          face: .semiBold, size: 15, lineHeight: 24, color: .white, alignment: .center)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("signal.summary")
            WristbandBodyText(text: "You stay private until venue check-in.", size: 14, lineHeight: 20,
                              color: WristbandStyle.secondaryText, alignment: .center)
                .accessibilityIdentifier("signal.privacy")
        }
        .frame(maxWidth: .infinity)
    }

    /// Chat first (y 602) and Okay to say hello (y 698): 376 × 84, 12 apart, one column that grows
    /// with its text.
    private var choices: some View {
        VStack(spacing: 12) {
            ForEach(ApproachSignal.allCases) { approach in
                row(approach)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose one approach")
    }

    private func row(_ approach: ApproachSignal) -> some View {
        let selected = session.approach == approach
        return Button {
            choose(approach)
        } label: {
            SignalRowLabel(approach: approach, selected: selected)
        }
        .buttonStyle(SignalRowStyle(selected: selected))
        .accessibilityLabel("\(approach.title). \(approach.summary)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("signal.approach.\(approach.rawValue)")
    }

    // MARK: - Actions

    /// Continue preview (376 × 60 at y 812) and Back (376 × 44 at y 883), kept on screen, as on
    /// the Wristband.
    private func actions(bottomInset: CGFloat) -> some View {
        VStack(spacing: 11) {
            Button("Continue preview") {
                if session.canContinueSignal {
                    isShowingEndOfPreview = true
                }
            }
            .buttonStyle(WristbandPrimaryStyle())
            .disabled(session.approach == nil)
            .accessibilityHint(session.approach == nil ? "Choose an approach first." : "")
            .accessibilityIdentifier("signal.primary")
            Button("Back") {
                session.leaveSignal()
            }
            .buttonStyle(WristbandSecondaryStyle())
            .accessibilityIdentifier("signal.secondary")
        }
        .padding(.horizontal, 32)
        .padding(.top, 13)
        .padding(.bottom, bottomInset < 60 ? 29 - bottomInset : 8)
        .background(WristbandStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Choosing and motion

    /// The model changes at once; the motion only follows it. The first choice moves the tag
    /// from its resting pose to the band (500 ms ease-out); a change between choices keeps it
    /// attached and dissolves the icon and the row treatment (220 ms ease-out). Reduce Motion and
    /// VoiceOver: no animation, the final state at once. The active row changes nothing, so it
    /// animates nothing.
    private func choose(_ approach: ApproachSignal) {
        let first = session.approach == nil
        let animation: Animation? = adaptive.reduceMotion || adaptive.voiceOverRunning
            ? nil
            : .easeOut(duration: first ? 0.5 : 0.22)
        withAnimation(animation) {
            _ = session.chooseApproach(approach)
        }
    }

    /// Ends any decorative movement where the model already is, without animation.
    private func endMovement() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            motionEpoch += 1
        }
    }
}

// MARK: - The hero

/// 376 × 216 at (32, 326). The band, stationary, at (0, 10), 376 × 181. The 88 × 68 tag rests at
/// (279, 124), turned 9° about its top-left corner (the spec's relative matrix: x' = 0.988x −
/// 0.156y + 279, y' = 0.156x + 0.988y + 124, i.e. clockwise on screen), and attaches at
/// (144, 129), straight. The tag and its native icon move as one group.
private struct SignalHero: View {
    let intent: BandIntent
    let approach: ApproachSignal?
    let width: CGFloat

    private var k: CGFloat { width / 376 }
    private var attached: Bool { approach != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WristbandBand(intent: intent)
                .frame(width: 376 * k, height: 181 * k)
                .padding(.top, 10 * k)
            SignalHeroTag(approach: approach, scale: k)
                .frame(width: 88 * k, height: 68 * k)
                .rotationEffect(.degrees(attached ? 0 : 9), anchor: .topLeading)
                .offset(x: (attached ? 144 : 279) * k, y: (attached ? 129 : 124) * k)
        }
        .frame(width: width, height: 216 * k, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// The blank steel tag and, once an approach is chosen, its native icon (25 × 25 at tag-local
/// 31.5, 31; #202526, 1.77 pt). The icons dissolve into each other in place.
private struct SignalHeroTag: View {
    let approach: ApproachSignal?
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let art = SignalTagArt.shared {
                Image(uiImage: art)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88 * scale, height: 68 * scale)
            }
            if let approach {
                SignalGlyph(pieces: SignalPaths.tagGlyph(approach), stroke: 1.7708333730697632,
                            color: SignalStyle.tagGlyph, designSize: 25)
                    .frame(width: 25 * scale, height: 25 * scale)
                    .offset(x: 31.5 * scale, y: 31 * scale)
                    .id(approach)
                    .transition(.opacity)
            }
        }
        .frame(width: 88 * scale, height: 68 * scale, alignment: .topLeading)
    }
}

/// The original blank tag, unchanged in the bundle, cropped once to [41, 154, 1216, 1060] with its
/// alpha (and hollow loop) kept.
@MainActor
private enum SignalTagArt {
    nonisolated static let crop = CGRect(x: 41, y: 154, width: 1175, height: 906)

    static let shared: UIImage? = {
        guard let cropped = UIImage(named: "SignalTag")?.cgImage?.cropping(to: crop) else { return nil }
        return UIImage(cgImage: cropped)
    }()
}

// MARK: - Rows

/// A choice row: the symbol (28 pt at 16, 28; #F3F2EF, 1.98 pt), the name (SemiBold 17/24) and
/// the explanation (Regular 14/20) in a 262-pt column, and the radio (20 pt): an outline
/// (#A8B0AD, 1.2 pt), or filled #F6F7F2 with its #050606 tick when selected. The row's size never
/// depends on the selection; Figma's 1.5 pt inside-border shift of a selected row's content is an
/// offset, applied at once. At accessibility text sizes the symbol and the radio share a line
/// above the words, which then have the row's full width, so no word breaks inside itself.
private struct SignalRowLabel: View {
    let approach: ApproachSignal
    let selected: Bool
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @Environment(\.dynamicTypeSize) private var typeSize

    private var graphic: CGFloat { min(scale, 1.5) }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 14) {
                        symbol
                        Spacer(minLength: 14)
                        radio
                    }
                    words
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    symbol
                    words
                    radio
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 22)
        .padding(.vertical, 9)
        // Not animated: the content never slides; only the row treatment and radio dissolve.
        .animation(nil) { content in
            content.offset(x: selected ? 1.5 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
    }

    private var symbol: some View {
        SignalGlyph(pieces: SignalPaths.rowSymbol(approach), stroke: 1.9833333492279053,
                    color: SignalStyle.rowSymbol, designSize: 28)
            .frame(width: 28 * graphic, height: 28 * graphic)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            WristbandText(text: approach.title, face: .semiBold, size: 17, lineHeight: 24, color: .white)
            WristbandText(text: approach.summary, face: .regular, size: 14, lineHeight: 20,
                          color: WristbandStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var radio: some View {
        SignalRadio(selected: selected)
            .frame(width: 20 * graphic, height: 20 * graphic)
    }
}

/// #111415, radius 18; selected: #242A2B with a 1.5 pt inside border, #7A8585.
private struct SignalRowStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .background(selected ? WristbandStyle.selectedTile : WristbandStyle.tile, in: shape)
            .overlay {
                if selected {
                    shape.strokeBorder(SignalStyle.selectedStroke, lineWidth: 1.5)
                }
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The 20-pt radio. Selected: the filled disc with the tick where the approved frames draw it
/// (a 16-pt frame at 6.5, 2 inside the disc, the 8 × 5.33 tick at 4, 5.33 within it).
private struct SignalRadio: View {
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 20
            if selected {
                context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 20 * scale, height: 20 * scale)),
                             with: .color(SignalStyle.radioFill))
                let tick = FigmaPath.make(SignalPaths.tick).applying(
                    CGAffineTransform(translationX: 10.5, y: 7.3333330154418945)
                        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                )
                context.stroke(tick, with: .color(WristbandStyle.ground),
                               style: StrokeStyle(lineWidth: 1.133333444595337 * scale, lineCap: .round, lineJoin: .round))
            } else {
                let inset = 0.6 * scale
                let ring = Path(ellipseIn: CGRect(x: inset, y: inset, width: 20 * scale - 2 * inset,
                                                  height: 20 * scale - 2 * inset))
                context.stroke(ring, with: .color(WristbandStyle.secondaryText), lineWidth: 1.2 * scale)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Stroked vector pieces in a `designSize` square, scaled to the frame; round caps and joins.
private struct SignalGlyph: View {
    let pieces: [WristbandPaths.Piece]
    let stroke: CGFloat
    let color: Color
    let designSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let scale = size.width / designSize
            for piece in pieces {
                let path = FigmaPath.make(piece.data).applying(
                    CGAffineTransform(translationX: piece.x, y: piece.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
                )
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: stroke * scale, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Text

/// "A hello, / on your terms." ExtraBold 48/56, −4 % tracking, on the approved line breaks; at
/// larger text each line wraps between its words rather than shrinking.
private struct SignalHeadline: View {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(["A hello,", "on your terms."], id: \.self) { line in
                Text(line)
                    .manrope(.extraBold, size: size, designSize: 48, lineHeight: 56, tracking: -1.92)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("A hello, on your terms."))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("signal.headline")
    }
}

// MARK: - Style and vectors

enum SignalStyle {
    static let rowSymbol = Color(hex: 0xF3F2EF)
    static let tagGlyph = Color(hex: 0x202526)
    static let selectedStroke = Color(hex: 0x7A8585)
    static let radioFill = Color(hex: 0xF6F7F2)
}

/// The approved vector paths, verbatim from `LAYOUT_SPEC.json`, with each vector's offset in its
/// frame (28 pt for the row symbols, 25 pt for the tag icons).
enum SignalPaths {
    typealias Piece = WristbandPaths.Piece

    static func rowSymbol(_ approach: ApproachSignal) -> [Piece] {
        switch approach {
        case .chatFirst:
            return [
                Piece(x: 3.5, y: 3.499883, data: "M 20.999998410551733 9.916782741188792 C 21.007572331289502 11.457037336714771 20.647610323486184 12.976878972143819 19.949998935072127 14.350115961495925 C 19.126837286080157 15.99715203163636 17.86137388064559 17.38248431248226 16.295356152907942 18.350942653259324 C 14.729338425170292 19.31940099403639 12.924615318847556 19.832737284321823 11.083332494457858 19.833449769902618 C 9.543077898931879 19.841023690640387 8.023236263502831 19.481061682837066 6.649999274150725 18.78345029442301 L 0 21.0001163482666 L 2.216666610153567 14.350115961495925 C 1.519055221739511 12.976878972143819 1.1590926576262144 11.457037336714771 1.1666665783639851 9.916782741188792 C 1.1673790639447803 8.075499916799094 1.680713685300284 6.270775697856407 2.64917202607735 4.704757970118757 C 3.6176303668544163 3.1387402423811066 5.002963204010291 1.8732787840314589 6.649999274150725 1.0501171350394871 C 8.023236263502831 0.35250574662543144 9.543077898931879 -0.0074568296944959945 11.083332494457858 0.00011709104327477101 L 11.666665783639852 0.00011709104327477101 C 14.096668924862179 0.13930949777206197 16.390615474381168 1.167323997677884 18.11170377340745 2.888412296704164 C 19.83279207243373 4.609500595730444 20.860806003822944 6.903446310784471 20.999998410551733 9.333449452006798 L 20.999998410551733 9.916782741188792 Z"),
                Piece(x: 9.333334, y: 11.666667, data: "M 0 0 L 9.333333015441895 0 M 0 4.666666507720947 L 5.833333134651184 4.666666507720947"),
            ]
        case .okayToSayHello:
            return [
                Piece(x: 2.333334, y: 2.333334, data: "M 7 12.83333245913446 L 7 5.833332935970209 C 6.999999999999999 5.369204110728767 7.184374247988066 4.924084571351073 7.512562910715739 4.595895930979411 C 7.840751573443413 4.26770729060775 8.285871143142382 4.083333055179146 8.75 4.083333055179146 C 9.214128856857618 4.083333055179146 9.659248426556587 4.26770729060775 9.987437089284262 4.595895930979411 C 10.315625752011936 4.924084571351073 10.5 5.369204110728767 10.5 5.833332935970209 L 10.5 11.666665871940419 L 10.5 2.3333331743880836 C 10.500000013832118 1.8692043491466417 10.684374247988066 1.424085087923937 11.01256291071574 1.0958964475522757 C 11.340751573443415 0.7677078071806143 11.785871143142382 0.5833332935970215 12.25 0.5833332935970209 C 12.714128856857618 0.5833332935970215 13.159248426556587 0.7677078071806143 13.487437089284262 1.0958964475522757 C 13.815625752011936 1.424085087923937 13.999999986167882 1.8692043491466417 14 2.3333331743880836 L 14 11.666665871940419 L 14 4.666666348776167 C 14 4.202537523534725 14.184374247988066 3.7574179841570308 14.51256291071574 3.4292293437853694 C 14.840751573443415 3.101040703413708 15.285871143142383 2.9166664679851055 15.750000000000002 2.9166664679851046 C 16.21412885685762 2.9166664679851046 16.659247313936554 3.101040703413708 16.987435976664226 3.4292293437853694 C 17.3156246393919 3.7574179841570308 17.5 4.202537523534725 17.5 4.666666348776167 L 17.5 12.83333245913446 L 17.5 9.333332697552335 C 17.5 8.869203872310893 17.684375360608104 8.424084332933198 18.012564023335777 8.095895692561536 C 18.34075268606345 7.767707052189874 18.785871143142383 7.583332816761273 19.25 7.5833328167612715 C 19.714128856857617 7.583332816761273 20.159247313936554 7.767707052189874 20.487435976664226 8.095895692561536 C 20.8156246393919 8.424084332933198 21 8.869203872310893 21 9.333332697552335 L 21 16.333332220716585 C 20.999999999999996 18.189847521682353 20.26250300804774 19.97032567919313 18.949748357137047 21.283080240679777 C 17.636993706226352 22.595834802166422 15.856515427430471 23.333331743880837 14 23.333331743880837 L 12.833333333333334 23.333331743880837 C 11.716921488444012 23.33827388765622 10.615520348151525 23.076113619051867 9.621053536732992 22.568732631637882 C 8.626586725314459 22.061351644223897 7.767902811368307 21.323468345228367 7.116667111714682 20.41666527589573 L 2.3333333333333335 13.999999046328501 C 2.094735252360503 13.639638617349856 1.997924883539478 13.20373317063229 2.0615508556365967 12.776251717325744 C 2.1251768277337155 12.348770264019198 2.3447382797797522 11.959953362635057 2.6779406865437827 11.684699216252362 C 3.011143093307813 11.409445069869667 3.4344154993693037 11.267225655620267 3.8662222226460776 11.285436656220476 C 4.298028945922852 11.303647656820685 4.707823559641838 11.481001205974438 5.016666889190674 11.783332975707806 L 7 13.999999046328501 M 0 4.666666348776167 L 2.3333333333333335 5.833332935970209 M 2.3333333333333335 0 L 4.083333333333334 2.3333331743880836"),
            ]
        }
    }

    static func tagGlyph(_ approach: ApproachSignal) -> [Piece] {
        switch approach {
        case .chatFirst:
            return [
                Piece(x: 3.125, y: 3.124896, data: "M 18.749999602637935 8.854270787149614 C 18.756762032236608 10.22949817952705 18.435367364897694 11.58649971368186 17.812500019870328 12.812604235277547 C 17.07753422178955 14.28317223518494 15.947656119649848 15.520076124774311 14.549425929401302 16.384771119018566 C 13.151195739152756 17.24946611326282 11.539835734981514 17.707802111709146 9.895833123614466 17.708438259583808 C 8.52060573123703 17.71520068918248 7.163604197082221 17.39380602184357 5.937499675486534 16.770938676816204 L 0 18.750104904174805 L 1.9791667240639657 12.812604235277547 C 1.3562993790366007 11.58649971368186 1.0349042149923227 10.22949817952705 1.0416666445909963 8.854270787149614 C 1.0423027924656592 7.210268175782567 1.5006373007958962 5.598907178200598 2.3653322950401505 4.200676987952053 C 3.230027289284405 2.802446797703508 4.466931675579142 1.6725704340325764 5.937499675486534 0.9376046359517969 C 7.163604197082221 0.3147372909244319 8.52060573123703 -0.00665788401862385 9.895833123614466 0.00010454558004972422 L 10.416666445909964 0.00010454558004972422 C 12.586312225951264 0.12438348693195098 14.634478899637394 1.042253626153251 16.171164964653133 2.5789396911689915 C 17.707851029668873 4.115625756184732 18.625720661286035 6.163791684812818 18.749999602637935 8.333437464854118 L 18.749999602637935 8.854270787149614 Z"),
                Piece(x: 8.333334, y: 10.416667, data: "M 0 0 L 8.333333015441895 0 M 0 4.166666507720947 L 5.208333134651184 4.166666507720947"),
            ]
        case .okayToSayHello:
            return [
                Piece(x: 2.083334, y: 2.083334, data: "M 6.25 11.458333377043278 L 6.25 5.20833335320149 C 6.249999999999999 4.793932586569237 6.414619864275059 4.39650439782195 6.707645455996196 4.103478804983012 C 7.000671047717333 3.8104532121440737 7.398099234948557 3.6458333472410427 7.812500000000001 3.6458333472410427 C 8.226900765051445 3.6458333472410427 8.624328952282667 3.8104532121440737 8.917354544003805 4.103478804983012 C 9.210380135724943 4.39650439782195 9.375 4.793932586569237 9.375 5.20833335320149 L 9.375 10.41666670640298 L 9.375 2.083333341280596 C 9.375000012350105 1.6689325746483428 9.539619864275059 1.2715046342537437 9.832645455996197 0.9784790414148057 C 10.125671047717335 0.6854534485758677 10.523099234948555 0.5208333353201494 10.9375 0.520833335320149 C 11.351900765051445 0.5208333353201494 11.749328952282667 0.6854534485758677 12.042354544003805 0.9784790414148057 C 12.335380135724943 1.2715046342537437 12.499999987649895 1.6689325746483428 12.5 2.083333341280596 L 12.5 10.41666670640298 L 12.5 4.166666682561192 C 12.5 3.7522659159289384 12.664619864275059 3.354837727181652 12.957645455996197 3.061812134342714 C 13.250671047717335 2.768786541503776 13.648099234948557 2.604166676600746 14.062500000000002 2.604166676600745 C 14.476900765051447 2.604166676600745 14.874327958871921 2.768786541503776 15.16735355059306 3.061812134342714 C 15.460379142314197 3.354837727181652 15.625000000000002 3.7522659159289384 15.625000000000002 4.166666682561192 L 15.625000000000002 11.458333377043278 L 15.625000000000002 8.333333365122384 C 15.625000000000002 7.91893259849013 15.789620857685806 7.521504409742844 16.082646449406944 7.228478816903906 C 16.37567204112808 6.935453224064968 16.773099234948557 6.770833359161938 17.1875 6.770833359161936 C 17.601900765051443 6.770833359161938 17.999327958871923 6.935453224064968 18.29235355059306 7.228478816903906 C 18.585379142314196 7.521504409742844 18.75 7.91893259849013 18.75 8.333333365122384 L 18.75 14.58333338896417 C 18.749999999999996 16.240936455493184 18.09152054289977 17.83064921048233 16.91941817601522 19.002751581838083 C 15.74731580913067 20.174853953193836 14.157603060205778 20.83333341280596 12.5 20.83333341280596 L 11.458333333333334 20.83333341280596 C 10.461537043253582 20.837746041494256 9.478143167992434 20.60367435625978 8.590226372083029 20.150655584909806 C 7.702309576173624 19.697636813559832 6.935627510150274 19.038812392064756 6.354167064030966 18.229166736205215 L 2.0833333333333335 12.500000047683574 C 1.8702993324647348 12.17824964152211 1.7838615031602485 11.789048321813159 1.8406704068183901 11.407368425333665 C 1.8974793104765317 11.025688528854172 2.0935163212319217 10.678530556217268 2.3910184701283774 10.432767907839725 C 2.688520619024833 10.187005259462182 3.066442410151164 10.060023630462341 3.4519841273625693 10.076283453596448 C 3.8375258445739746 10.092543276730554 4.203413892537355 10.250894671294411 4.479166865348816 10.52083377083131 L 6.25 12.500000047683574 M 0 4.166666682561192 L 2.0833333333333335 5.20833335320149 M 2.0833333333333335 0 L 3.6458333333333335 2.083333341280596"),
            ]
        }
    }

    static let tick = "M 0 2.6666667461395264 L 2.6666666666666665 5.333333492279053 L 8 0"
}

#if DEBUG
#Preview("Signal · Social, no approach") {
    NavigationStack { SignalView() }
        .environment(PreviewFixtures.session(at: .signal, band: .social))
}

#Preview("Signal · Dating, Okay to say hello") {
    NavigationStack { SignalView() }
        .environment(PreviewFixtures.session(at: .signalSelected, band: .dating, signal: .okayToSayHello))
}
#endif
