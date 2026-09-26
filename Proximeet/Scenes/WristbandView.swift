import SwiftUI
import UIKit
import ProximeetDomain

/// Chapter 05 — the approved Wristband (handoff `LAYOUT_SPEC.json`, Figma 42:111; unselected
/// 42:112, Social 42:113, Dating 42:114, Business 42:115, Activity 42:116), on the 440 × 956
/// reference canvas.
///
/// One current intent for this moment. The single source of truth is `DemoDraft.band`: no intent
/// on a fresh run, then exactly one. Every tile, the hero, the summary and Continue preview are
/// derived from it, so they cannot disagree. A tap chooses at once; another tile replaces the
/// choice; the chosen tile does nothing. Nothing advances on its own.
///
/// Back (header or bottom) returns to the actual Guest List card, still below this screen, with
/// the introduction and the intent kept in memory for this run. Continue preview, once an intent
/// is chosen, only shows "End of this preview." and stays: Signal is not implemented.
///
/// An intent verifies nothing, shows the guest to no one and grants no permission to approach or
/// message. The four bands are the approved raster decoration (`WristbandArt`, the original
/// 1254² artworks cropped to [22, 335, 1235, 920]); every word, icon, check and control is native.
struct WristbandView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var isShowingEndOfPreview = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    WristbandHeadline()
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                    WristbandBodyText(text: "One intent for this moment.", size: 17, lineHeight: 26,
                                      color: WristbandStyle.secondaryText, alignment: .leading)
                        .padding(.top, 14)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("wristband.support")
                    WristbandHero(choice: session.intent, width: min(376, proxy.size.width - 64))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                    summary
                        .padding(.top, 8)
                        .padding(.horizontal, 32)
                    choices
                        .padding(.top, 16)
                        .padding(.horizontal, 32)
                    WristbandBodyText(text: "Choosing a band doesn’t make you visible.", size: 14, lineHeight: 20,
                                      color: WristbandStyle.secondaryText, alignment: .center)
                        .padding(.top, 9)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("wristband.privacy")
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
        .onChange(of: session.intent) { _, intent in
            // Concise: the new choice only, never the whole screen again.
            if let intent {
                AccessibilityNotification.Announcement("\(intent.title) selected").post()
            }
        }
    }

    // MARK: - Header

    /// Back (44 × 44 at 24, 64, the Figma arrow), the wordmark (Bold 22/32 at x 84) and the DEMO
    /// label (128 × 32 at 285, 70), all centred on the 44-pt header row.
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                session.leaveWristband()
            } label: {
                WristbandBackArrow()
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("wristband.back")
            WristbandWordmark()
            Spacer(minLength: 8)
            // Never truncated: the wordmark gives way first. Its growth stops at the largest
            // non-accessibility size.
            WristbandDemoBadge()
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(minHeight: 44)
        .padding(.leading, 24)
        .padding(.trailing, 27)
        .padding(.top, 2)
    }

    // MARK: - Summary and choices

    /// "Your moment. Your choice." / "Pick the band that fits right now." with no intent;
    /// "[Intent] · Selected" in the intent's colour and its explanation with one.
    private var summary: some View {
        let intent = session.intent
        let summary = WristbandSummary(choice: intent)
        return VStack(alignment: .leading, spacing: 2) {
            WristbandText(text: summary.title, face: .semiBold, size: 18, lineHeight: 26,
                          color: intent.map(WristbandStyle.color(for:)) ?? .white)
                .contentTransition(.opacity)
                .accessibilityIdentifier("wristband.summary")
            WristbandText(text: summary.explanation, face: .regular, size: 14, lineHeight: 22,
                          color: WristbandStyle.secondaryText)
                .contentTransition(.opacity)
                .accessibilityIdentifier("wristband.explanation")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Social / Dating, then Business / Activity: 182 × 78 tiles, 12 apart. One column when a
    /// row of two no longer fits at equal widths (larger text, from xxxLarge on this phone). The
    /// choice never depends on the selection: a tile's size does not change when it is chosen.
    private var choices: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: 12) {
                ForEach([[BandIntent.social, .dating], [.business, .activity]], id: \.self) { row in
                    WristbandTileRow(spacing: 12) {
                        ForEach(row) { intent in
                            tile(intent)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(BandIntent.allCases) { intent in
                    tile(intent)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose one intent")
    }

    private func tile(_ intent: BandIntent) -> some View {
        let selected = session.intent == intent
        return Button {
            withAnimation(dissolve) {
                session.chooseIntent(intent)
            }
        } label: {
            WristbandTileLabel(intent: intent, selected: selected)
        }
        .buttonStyle(WristbandTileStyle(intent: intent, selected: selected))
        .accessibilityLabel(intent.title)
        .accessibilityHint(intent.wristbandHint)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("wristband.intent.\(intent.rawValue)")
    }

    // MARK: - Actions

    /// Continue preview (376 × 60 at y 812) and Back (376 × 44 at y 883), kept on screen. At
    /// rest the pair ends 29 pt above the screen's bottom edge, as in Figma.
    private func actions(bottomInset: CGFloat) -> some View {
        VStack(spacing: 11) {
            Button("Continue preview") {
                if session.canContinueWristband {
                    isShowingEndOfPreview = true
                }
            }
            .buttonStyle(WristbandPrimaryStyle())
            .disabled(session.intent == nil)
            .accessibilityHint(session.intent == nil ? "Choose a band first." : "")
            .accessibilityIdentifier("wristband.primary")
            Button("Back") {
                session.leaveWristband()
            }
            .buttonStyle(WristbandSecondaryStyle())
            .accessibilityIdentifier("wristband.secondary")
        }
        .padding(.horizontal, 32)
        .padding(.top, 13)
        .padding(.bottom, bottomInset < 60 ? 29 - bottomInset : 8)
        .background(WristbandStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Motion

    /// Choice changes: 220 ms ease-out dissolve (Figma). Reduce Motion: a brief dissolve with no
    /// movement. VoiceOver: none. Selection never waits for it.
    private var dissolve: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: adaptive.reduceMotion ? 0.12 : 0.22)
    }
}

// MARK: - The hero

/// 376 × 200 at (32, 328). No intent: the four bands at an equal 182 × 88, two by two, 12 and 12
/// apart. An intent: only its band, 376 × 181, centred in the hero. The bands dissolve into each
/// other in place; nothing moves.
private struct WristbandHero: View {
    let choice: BandIntent?
    let width: CGFloat

    private var k: CGFloat { width / 376 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let choice {
                WristbandBand(intent: choice)
                    .frame(width: 376 * k, height: 181 * k)
                    .padding(.top, 10 * k)
                    .id(choice)
                    .transition(.opacity)
            } else {
                ForEach(Array(BandIntent.allCases.enumerated()), id: \.element) { index, intent in
                    WristbandBand(intent: intent)
                        .frame(width: 182 * k, height: 88 * k)
                        .padding(.leading, CGFloat(index % 2) * 194 * k)
                        .padding(.top, CGFloat(index / 2) * 100 * k)
                }
                .transition(.opacity)
            }
        }
        .frame(width: width, height: 200 * k, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// One band, fitted without stretching.
private struct WristbandBand: View {
    let intent: BandIntent

    var body: some View {
        if let art = WristbandArt.shared[intent] {
            Image(uiImage: art)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        }
    }
}

/// The four original artworks, unchanged in the bundle, cropped once to the approved common
/// silhouette box [22, 335, 1235, 920] with their alpha kept.
@MainActor
private enum WristbandArt {
    nonisolated static let crop = CGRect(x: 22, y: 335, width: 1213, height: 585)

    static let shared: [BandIntent: UIImage] = {
        var art: [BandIntent: UIImage] = [:]
        let names: [BandIntent: String] = [.social: "WristbandSocial", .dating: "WristbandDating",
                                          .business: "WristbandBusiness", .activity: "WristbandActivity"]
        for (intent, name) in names {
            if let cropped = UIImage(named: name)?.cgImage?.cropping(to: crop) {
                art[intent] = UIImage(cgImage: cropped)
            }
        }
        return art
    }()
}

// MARK: - Tiles

/// Two tiles side by side at equal widths, 12 apart. Its ideal width is twice the wider tile's
/// plus the gap, so `ViewThatFits` keeps two columns only when both tiles fit the width they will
/// actually get; the taller tile sets the row's height, and both take it.
private struct WristbandTileRow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let count = CGFloat(subviews.count)
        let gaps = spacing * (count - 1)
        if let width = proposal.width, width.isFinite {
            let column = max(0, (width - gaps) / count)
            let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(width: (ideals.map(\.width).max() ?? 0) * count + gaps, height: ideals.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = CGFloat(subviews.count)
        let column = max(0, (bounds.width - spacing * (count - 1)) / count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * (column + spacing), y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: column, height: bounds.height)
            )
        }
    }
}

/// The tile's content: the intent's icon (24 pt, stroked in its colour), its name (SemiBold
/// 16/24), the check (16 pt, shown only when selected), and the short hint (Regular 12/20).
///
/// Its size never depends on the selection, so choosing cannot rearrange the grid: the check is
/// always laid out and only fades in, and Figma's 1.5 pt inside-border shift of a selected tile's
/// content is drawn as an offset. The name's column is up to 89 pt (Figma), which puts the check at
/// x 145 (146.5 selected) in a 182-pt tile, but never forces a width. The icon and check grow at
/// most 1.5× with Dynamic Type; at accessibility sizes they share a line above the name, so the
/// name has the tile's whole width and never breaks inside the word.
private struct WristbandTileLabel: View {
    let intent: BandIntent
    let selected: Bool
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scale) {
            if typeSize.isAccessibilitySize {
                HStack(spacing: 9) {
                    icon
                    Spacer(minLength: 9)
                    check
                }
                name
            } else {
                HStack(spacing: 9) {
                    icon
                    name
                        .frame(maxWidth: 89 * scale, alignment: .leading)
                    check
                }
            }
            WristbandText(text: intent.wristbandHint, face: .regular, size: 12, lineHeight: 20,
                          color: WristbandStyle.secondaryText)
        }
        .padding(14)
        .offset(x: selected ? 1.5 : 0, y: selected ? 1.5 : 0)
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: .infinity, alignment: .topLeading)
    }

    private var graphic: CGFloat { min(scale, 1.5) }

    private var icon: some View {
        WristbandIcon(intent: intent)
            .frame(width: 24 * graphic, height: 24 * graphic)
    }

    private var name: some View {
        WristbandText(text: intent.title, face: .semiBold, size: 16, lineHeight: 24, color: .white)
    }

    private var check: some View {
        WristbandCheck(color: WristbandStyle.color(for: intent))
            .frame(width: 16 * graphic, height: 16 * graphic)
            .opacity(selected ? 1 : 0)
    }
}

/// #111415, radius 16; selected: #242A2B with a 1.5 pt inside border in the intent's colour.
private struct WristbandTileStyle: ButtonStyle {
    let intent: BandIntent
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        configuration.label
            .background(selected ? WristbandStyle.selectedTile : WristbandStyle.tile, in: shape)
            .overlay {
                if selected {
                    shape.strokeBorder(WristbandStyle.color(for: intent), lineWidth: 1.5)
                }
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Vector icons (the supplied Figma paths)

/// The intent's 24 × 24 icon, from the approved vector paths: people, heart, briefcase, bolt.
/// Stroked 1.8 pt with round caps and joins in the intent's colour. Decorative: the tile's name
/// says the intent.
private struct WristbandIcon: View {
    let intent: BandIntent

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            for piece in WristbandPaths.icon(intent) {
                let path = FigmaPath.make(piece.data).applying(
                    CGAffineTransform(translationX: piece.x, y: piece.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
                )
                context.stroke(path, with: .color(WristbandStyle.color(for: intent)),
                               style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The selected check (16 × 16): a 14 pt disc in the intent's colour with a #050606 tick.
private struct WristbandCheck: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 16
            let transform = { (x: CGFloat, y: CGFloat) in
                CGAffineTransform(translationX: x, y: y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
            }
            context.fill(FigmaPath.make(WristbandPaths.checkDisc).applying(transform(1, 1)), with: .color(color))
            context.stroke(FigmaPath.make(WristbandPaths.checkTick).applying(transform(4.5, 5.4)),
                           with: .color(WristbandStyle.ground),
                           style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The header's back arrow (Figma 14 × 12 at 39, 80), stroked 1.8 pt, white.
private struct WristbandBackArrow: View {
    var body: some View {
        Canvas { context, _ in
            let path = FigmaPath.make(WristbandPaths.backArrow)
                .applying(CGAffineTransform(translationX: 15, y: 16))
            context.stroke(path, with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The approved vector paths, verbatim from `LAYOUT_SPEC.json`, with each vector's offset in its
/// 24 pt (or 16 pt) frame.
enum WristbandPaths {
    struct Piece {
        let x: CGFloat
        let y: CGFloat
        let data: String
    }

    static let backArrow = "M 14 6 L 0 6 M 0 6 L 6 0 M 0 6 L 6 12"

    static func icon(_ intent: BandIntent) -> [Piece] {
        switch intent {
        case .social:
            return [
                Piece(x: 2, y: 15, data: "M 14 6 L 14 4 C 13.999999999999998 2.9391340017318726 13.578572809696198 1.9217191338539124 12.8284273147583 1.1715736389160156 C 12.078281819820404 0.4214281439781189 11.060865998268127 3.552713678800501e-15 10 0 L 4 0 C 2.9391340017318726 1.7763568394002505e-15 1.921718418598175 0.4214281439781189 1.1715729236602783 1.1715736389160156 C 0.4214274287223816 1.9217191338539124 1.3322676295501878e-15 2.9391340017318726 0 4 L 0 6 M 20 6 L 20 4 C 19.999338921974413 3.113727867603302 19.704355657100677 2.252772092819214 19.161365509033203 1.5523147583007812 C 18.61837536096573 0.8518574237823486 17.858129620552063 0.35156796872615814 17 0.13000011444091797"),
                Piece(x: 5, y: 3, data: "M 8 4 C 8 6.209139108657837 6.209139108657837 8 4 8 C 1.790860891342163 8 0 6.209139108657837 0 4 C 0 1.790860891342163 1.790860891342163 0 4 0 C 6.209139108657837 0 8 1.790860891342163 8 4 Z"),
                Piece(x: 16, y: 3.13, data: "M 0 0 C 0.860414981842041 0.2203010469675064 1.6230372190475464 0.7207009792327881 2.1676387786865234 1.4223103523254395 C 2.7122403383255005 2.123919725418091 3.0078430175781214 2.986829698085785 3.007843017578125 3.875 C 3.0078430175781214 4.763170301914215 2.7122403383255005 5.626079797744751 2.1676387786865234 6.327689170837402 C 1.6230372190475464 7.029298543930054 0.860414981842041 7.529698953032494 0 7.75"),
            ]
        case .dating:
            return [
                Piece(x: 1.54871, y: 2.99817, data: "M 19.291290283203125 1.611825704574585 C 18.780534386634827 1.1008299589157104 18.1741042137146 0.6954718828201294 17.50664520263672 0.41890954971313477 C 16.839186191558838 0.14234721660614014 16.123779356479645 -1.3322676295501878e-15 15.401291847229004 0 C 14.678804337978363 -4.440892098500626e-16 13.96339464187622 0.14234721660614014 13.29593563079834 0.41890954971313477 C 12.628476619720459 0.6954718828201294 12.022047400474548 1.1008299589157104 11.51129150390625 1.611825704574585 L 10.45129108428955 2.671825647354126 L 9.391290664672852 1.611825704574585 C 8.359598517417908 0.5801335573196411 6.960323810577393 0.0005347620022817523 5.501290798187256 0.0005347728729248047 C 4.042257785797119 0.0005347837435678571 2.6429829597473145 0.5801335573196411 1.6112908124923706 1.611825704574585 C 0.5795986652374268 2.643517851829529 1.0870643052385276e-8 4.042792320251465 0 5.501825332641602 C -1.0870643052385276e-8 6.960858345031738 0.5795986652374268 8.360133528709412 1.6112908124923706 9.391825675964355 L 10.45129108428955 18.23182487487793 L 19.291290283203125 9.391825675964355 C 19.802286028862 8.881069779396057 20.207642912864685 8.27463960647583 20.48420524597168 7.607180595397949 C 20.760767579078674 6.939721584320068 20.90311622619629 6.224312841892242 20.90311622619629 5.501825332641602 C 20.90311622619629 4.779337823390961 20.760767579078674 4.063929319381714 20.48420524597168 3.396470308303833 C 20.207642912864685 2.729011297225952 19.802286028862 2.1225816011428833 19.291290283203125 1.611825704574585 Z"),
            ]
        case .business:
            return [
                Piece(x: 3, y: 7, data: "M 2 0 L 16 0 C 17.10456955432892 0 18 0.8954304456710815 18 2 L 18 12 C 18 13.104569554328918 17.10456955432892 14 16 14 L 2 14 C 0.8954304456710815 14 0 13.104569554328918 0 12 L 0 2 C 0 0.8954304456710815 0.8954304456710815 0 2 0 Z"),
                Piece(x: 3, y: 3, data: "M 13 4 L 13 2 C 13 1.4695670008659363 12.78928592801094 0.960859090089798 12.414213180541992 0.5857863426208496 C 12.039140433073044 0.21071359515190125 11.530432999134064 4.440892098500626e-16 11 0 L 7 0 C 6.469567000865936 4.440892098500626e-16 5.960859566926956 0.21071359515190125 5.585786819458008 0.5857863426208496 C 5.2107140719890594 0.960859090089798 5.000000000000001 1.4695670008659363 5 2 L 5 4 M 0 9 C 2.8127200603485107 10.334190249443054 5.886889457702637 11.026333808898924 9 11.026333808898926 C 12.113110542297363 11.02633380889892 15.18727993965149 10.334190249443054 18 9 M 7 9 L 7 12 L 11 12 L 11 9"),
            ]
        case .activity:
            return [
                Piece(x: 3, y: 2, data: "M 10 0 L 0 12 L 8 12 L 7 20 L 18 8 L 10 8 L 11 0 L 10 0 Z"),
            ]
        }
    }

    static let checkDisc = "M 14 7 C 14 10.86599326133728 10.86599326133728 14 7 14 C 3.1340067386627197 14 0 10.86599326133728 0 7 C 0 3.1340067386627197 3.1340067386627197 0 7 0 C 10.86599326133728 0 14 3.1340067386627197 14 7 Z"
    static let checkTick = "M 0 2.5999999046325684 L 2.1999998092651367 4.799999713897705 L 7 0"
}

/// Builds a `Path` from Figma's absolute SVG path data: M, L, C and Z, as `LAYOUT_SPEC.json`
/// records them.
enum FigmaPath {
    static func make(_ data: String) -> Path {
        var path = Path()
        let tokens = data.split(separator: " ").map(String.init)
        var index = 0
        func number() -> CGFloat {
            defer { index += 1 }
            return index < tokens.count ? CGFloat(Double(tokens[index]) ?? 0) : 0
        }
        func point() -> CGPoint {
            let x = number()
            return CGPoint(x: x, y: number())
        }
        while index < tokens.count {
            let command = tokens[index]
            index += 1
            switch command {
            case "M":
                path.move(to: point())
            case "L":
                path.addLine(to: point())
            case "C":
                let control1 = point(), control2 = point()
                path.addCurve(to: point(), control1: control1, control2: control2)
            case "Z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }
}

// MARK: - Text

/// "Choose your / kind of hello." ExtraBold 48/56, −4 % tracking, on the approved line breaks.
/// Each line is about 278 pt wide at the default size; at larger text a line wraps between its
/// words rather than shrinking.
private struct WristbandHeadline: View {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(["Choose your", "kind of hello."], id: \.self) { line in
                Text(line)
                    .manrope(.extraBold, size: size, designSize: 48, lineHeight: 56, tracking: -1.92)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Choose your kind of hello."))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("wristband.headline")
    }
}

/// Text at its Figma size and line height (`size`, `lineHeight`), following Dynamic Type from
/// there and wrapping rather than shrinking.
private struct WristbandText: View {
    let text: String
    let face: Manrope
    let size: CGFloat
    let lineHeight: CGFloat
    let color: Color
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .manrope(face, size: size * scale, designSize: size, lineHeight: lineHeight)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Body copy that follows Dynamic Type from its Figma size, on its line pitch (scaled).
private struct WristbandBodyText: View {
    let text: String
    let size: CGFloat
    let lineHeight: CGFloat
    let color: Color
    let alignment: TextAlignment
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let scaled = size * scale
        let extra = max(0, lineHeight * scale - Manrope.regular.naturalLineHeight(size: scaled))
        Text(text)
            .font(Manrope.regular.font(size: scaled))
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: lineHeight * scale, alignment: alignment == .center ? .top : .topLeading)
    }
}

/// "Proximeet" Bold 22 on Figma's 32-pt line, centred on the header row.
private struct WristbandWordmark: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22

    var body: some View {
        Text("Proximeet")
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manrope(.bold, size: size, designSize: 22, lineHeight: 32)
            .foregroundStyle(.white)
    }
}

/// The persistent DEMO label: Bold 11/24, 0.9 tracking, cyan, in a 128 × 32 outline (radius 8,
/// cyan at 45 %).
private struct WristbandDemoBadge: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 11

    var body: some View {
        Text("DEMO")
            .lineLimit(1)
            .manrope(.bold, size: size, designSize: 11, lineHeight: 24, tracking: 0.9)
            .fixedSize()
            .foregroundStyle(WristbandStyle.cyan)
            .padding(.horizontal, 8)
            .frame(minWidth: 128, minHeight: 32)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(WristbandStyle.cyan.opacity(0.45), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Demo"))
            .accessibilityIdentifier("wristband.demoBadge")
    }
}

// MARK: - Actions

/// 376 × 60, radius 18. Enabled: #F6F7F2 with #050606 SemiBold 18/24. Disabled: #1F2424 with
/// #737D7A. The label's 24-pt line sits at y 17 of the button, as in Figma.
private struct WristbandPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WristbandPrimaryBody(configuration: configuration)
    }
}

private struct WristbandPrimaryBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .manrope(.semiBold, size: size, designSize: 18, lineHeight: 24)
            .padding(.bottom, 2 * size / 18)
            .foregroundStyle(isEnabled ? WristbandStyle.ground : WristbandStyle.disabledText)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? WristbandStyle.primary : WristbandStyle.disabledFill, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// 376 × 44 text action: Medium 16/24, white, centred.
private struct WristbandSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WristbandSecondaryBody(configuration: configuration)
    }
}

private struct WristbandSecondaryBody: View {
    let configuration: ButtonStyleConfiguration
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        configuration.label
            .manrope(.medium, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Style

enum WristbandStyle {
    static let ground = Color(hex: 0x050606)
    static let secondaryText = Color(hex: 0xA8B0AD)
    static let cyan = Color(hex: 0x38DBE5)
    static let tile = Color(hex: 0x111415)
    static let selectedTile = Color(hex: 0x242A2B)
    static let primary = Color(hex: 0xF6F7F2)
    static let disabledFill = Color(hex: 0x1F2424)
    static let disabledText = Color(hex: 0x737D7A)

    /// The intent colours of the approved screens: coral, orchid, blue, amber. Always beside the
    /// intent's name and icon, never alone.
    static func color(for intent: BandIntent) -> Color {
        switch intent {
        case .social: return Color(hex: 0xF2877F)
        case .dating: return Color(hex: 0xC689ED)
        case .business: return Color(hex: 0x5CA7FF)
        case .activity: return Color(hex: 0xEFC16B)
        }
    }
}

#if DEBUG
#Preview("Wristband · unselected") {
    NavigationStack { WristbandView() }
        .environment(PreviewFixtures.session(at: .wristband))
}

#Preview("Wristband · Dating") {
    NavigationStack { WristbandView() }
        .environment(PreviewFixtures.session(at: .wristbandDating))
}
#endif
