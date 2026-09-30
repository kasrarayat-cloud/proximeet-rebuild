import SwiftUI
import UIKit
import ProximeetDomain

/// Chapter 07 — the approved Places (handoff `LAYOUT_SPEC.json`, Figma 58:479; the seven frames
/// 58:480–58:486), on the 440 × 956 reference canvas.
///
/// One navigation destination with three stages, chosen by the domain's current scene: browsing
/// (Now, Later, Upcoming: each category filters the fixed fictional catalog to one venue), a
/// venue's detail, and Common Ground's check-in explanation. The stages are shown here rather than
/// pushed, so they can move as approved: 240 ms ease-out dissolves for a category change, Back and
/// the explanation, and a 500 ms ease-out two-dimensional expansion of the ticket from browsing
/// into its detail (the ticket keeps its identity, so the art and the native text move together).
/// Reduce Motion (the system setting or the app's preview flag) replaces the expansion with the
/// dissolve; VoiceOver gets no animation. The model always changes at once; the motion follows.
///
/// Back is one stage, whether it is the header's arrow, the bottom action, a swipe in from the
/// leading edge (`PlacesEdgeBack`) or VoiceOver's escape (the two-finger scrub): browsing to the
/// actual Signal, a detail to its category, the explanation to Common Ground's detail. Every one of
/// them goes through `back(from:)` and the domain's `placesBack(from:)`. Escape is handled on the
/// screen's container, above every element of every stage, so the stack's own pop (which would
/// leave the whole destination) is not what answers it. With VoiceOver itself this is unverified:
/// VoiceOver does not run in the Simulator. A detail and the explanation open at their beginning,
/// never at the offset browsing was scrolled to; going back to browsing shows the originating
/// ticket's end, where View place is.
///
/// Everything is derived from the actual draft: the carried intent decides every helper line and
/// whether Preview check-in is available (only Social or Business at Common Ground, the one open
/// session of the fixed Thursday 8 pm snapshot); the approach is kept untouched. Nothing here
/// reads a clock, requests a permission, uses location or the camera, checks anyone in, or makes
/// anyone visible. The venue scenes are raster decoration (the original 1254² artwork, cropped
/// and fitted); every word, chip, rule, tab, icon and control is native.
struct PlacesView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    /// Bumped inside the animation to dissolve the browse/detail content into its next stage
    /// instead of moving it: a detail's Back, and the expansion under Reduce Motion.
    @State private var dissolveToken = 0
    /// How far a back swipe from the leading edge has moved the screen (0 at rest).
    @State private var backDrag: CGFloat = 0
    /// A completed swipe is finishing its movement; further swipes are ignored until it has.
    @State private var backCompleting = false
    /// Bumped when Back to places from a detail completes its dissolve (or, after a swipe, right
    /// after its instant change), so browsing is aligned again against its own content and action
    /// bar. Build 6ab8adb4's frames, as reconstructed, put the scroll issued during the stage change
    /// within the outgoing detail's scroll range.
    @State private var revealTicketEnd = 0
    /// The action bar's last measured height, so the spacer that stands in for it under the Room keeps
    /// the stage where it was.
    @State private var actionBarHeight: CGFloat = 0

    var body: some View {
        if let intent = session.intent, session.approach != nil {
            screen(intent)
                .onAppear {
                    // Places always appears at rest, whatever a swipe that left it last time did.
                    backDrag = 0
                    backCompleting = false
                    session.reconcileRoute()
                }
                .onChange(of: session.flow.currentScene) { _, _ in
                    // The destination is guarded as well as its buttons: a stage whose
                    // requirements no longer hold is never shown.
                    session.reconcileRoute()
                }
        } else {
            // A missing intent or approach: back to its own choice screen, never a default.
            WristbandStyle.ground
                .ignoresSafeArea()
                .onAppear { session.reconcileRoute() }
        }
    }

    private var stage: PlacesStage {
        switch session.flow.currentScene {
        case .placeDetail: return .detail
        case .placeExplanation: return .explanation
        default: return .browse
        }
    }

    private func screen(_ intent: BandIntent) -> some View {
        let stage = self.stage
        let venue = session.placeVenue
        let eligibility = PlaceEligibility(venue: venue, intent: intent)
        return GeometryReader { proxy in
            let width = min(376, max(0, proxy.size.width - 64))
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(stage)
                            .id(PlacesScrollTarget.top)
                        ZStack(alignment: .top) {
                            if stage == .explanation {
                                PlacesExplanation(width: width)
                                    .transition(.opacity)
                            } else {
                                PlacesTicketStage(stage: stage, category: session.placesCategory, venue: venue,
                                                  eligibility: eligibility, width: width,
                                                  choose: chooseCategory, open: openDetail)
                                    .id(dissolveToken)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 11)
                }
                .scrollBounceBehavior(.basedOnSize)
                // The ground behind the status bar, so scrolled text never runs under the clock.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .background(WristbandStyle.ground.ignoresSafeArea(edges: .top))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if session.room == nil {
                        actions(stage, eligibility, width: width, bottomInset: proxy.safeAreaInsets.bottom)
                            .background {
                                GeometryReader { bar in
                                    Color.clear
                                        .onAppear { actionBarHeight = bar.size.height }
                                        .onChange(of: bar.size.height) { _, height in actionBarHeight = height }
                                }
                            }
                            .transition(.opacity)
                    } else {
                        // Under the Room the bar is not built: an inset's content kept its buttons in
                        // the accessibility tree under the Room although the stage above is hidden
                        // (builds 6abc1b80-6abc3ebe; the Room's own bar under a panel likewise). An
                        // empty spacer of its height keeps the explanation where it was, and the bar
                        // dissolves out and back in with the Room. The spacer keeps the bar's own ground, so
                        // nothing of the stage shows through while the buttons fade.
                        Color.clear
                            .frame(height: actionBarHeight)
                            .background(WristbandStyle.ground.ignoresSafeArea(edges: .bottom))
                    }
                }
                .onChange(of: session.flow.currentScene) { previous, scene in
                    revealStart(from: previous, to: scene, with: reader)
                }
                .onChange(of: revealTicketEnd) { _, _ in
                    revealTicketEndAgain(with: reader)
                }
            }
            // A back swipe in progress moves the whole screen with the finger; the ground stays.
            .offset(x: backDrag)
        }
        // While the Room shows above the explanation, the explanation is not an accessibility element.
        .accessibilityHidden(session.room != nil)
        .background(WristbandStyle.ground.ignoresSafeArea())
        .background(RepeatTapGuard())
        .background(PlacesEdgeBack(innerStage: stage != .browse, changed: swipeChanged, ended: swipeEnded,
                                   cancelled: swipeCancelled))
        // Chapter 08: the Room, above Common Ground's explanation (the flow stays on the explanation).
        .overlay {
            if session.room != nil {
                RoomView()
                    .transition(.opacity)
            }
        }
        .onChange(of: session.flow.currentScene) { _, scene in
            // Whatever changed the stage, no swipe offset outlives it. Leaving Places (a completed
            // swipe from browsing), the native pop carries the screen on from where the finger left it.
            if !backCompleting, scene == .places || DemoSession.placesStages.contains(scene) {
                backDrag = 0
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // One unlabelled container above every element of every stage, so VoiceOver's escape has a
        // single owner whatever is focused. The elements themselves (identifiers, labels, traits,
        // order) are unchanged; the identifier stays on the container, as places.tabs does.
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            escape(from: stage)
        }
        .accessibilityIdentifier("places.screen")
    }

    // MARK: - Header

    /// Back (44 × 44 at 24, 64), the wordmark and the DEMO label, as on the earlier chapters. Back
    /// returns one stage: browsing to the actual Signal, a detail to its category, the explanation
    /// to Common Ground's detail.
    private func header(_ stage: PlacesStage) -> some View {
        HStack(spacing: 16) {
            Button {
                back(from: stage)
            } label: {
                WristbandBackArrow()
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("places.back")
            ViewThatFits(in: .horizontal) {
                WristbandWordmark()
                WristbandWordmark().dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                WristbandWordmark().dynamicTypeSize(...DynamicTypeSize.large)
            }
            Spacer(minLength: 8)
            WristbandDemoBadge(identifier: "places.demoBadge")
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(minHeight: 44)
        .padding(.leading, 24)
        .padding(.trailing, 27)
        .padding(.top, 2)
    }

    // MARK: - Actions

    /// Browsing: Back (376 × 44 at y 883). A detail: its primary action (376 × 60 at y 812) and
    /// "Back to places". The explanation: "Preview room demo" and "Back to place". Kept on
    /// screen above the home indicator, as on the earlier chapters.
    private func actions(_ stage: PlacesStage, _ eligibility: PlaceEligibility, width: CGFloat,
                         bottomInset: CGFloat) -> some View {
        ZStack {
            Group {
                switch stage {
                case .browse:
                    Button("Back") {
                        back(from: .browse)
                    }
                    .buttonStyle(WristbandSecondaryStyle())
                    .accessibilityIdentifier("places.secondary")
                case .detail:
                    VStack(spacing: 11) {
                        Button(eligibility.primaryLabel) {
                            dissolve { session.previewCheckIn() }
                        }
                        .buttonStyle(WristbandPrimaryStyle())
                        .disabled(!eligibility.canPreviewCheckIn)
                        .accessibilityHint(eligibility.disabledReason
                                           ?? "Opens an explanation of how check-in would work. Nothing runs in this demo.")
                        .accessibilityIdentifier("place.primary")
                        Button("Back to places") {
                            back(from: .detail)
                        }
                        .buttonStyle(WristbandSecondaryStyle())
                        .accessibilityIdentifier("place.secondary")
                    }
                case .explanation:
                    VStack(spacing: 11) {
                        // Chapter 08: the explanation's primary opens the Room entry (the approved integration change:
                        // its label and destination only).
                        Button("Preview room demo") {
                            openRoom()
                        }
                        .buttonStyle(WristbandPrimaryStyle())
                        .accessibilityHint("Opens a fictional Room demo.")
                        .accessibilityIdentifier("explanation.primary")
                        Button("Back to place") {
                            back(from: .explanation)
                        }
                        .buttonStyle(WristbandSecondaryStyle())
                        .accessibilityIdentifier("explanation.secondary")
                    }
                }
            }
            .id(stage)
            .transition(.opacity)
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
        .padding(.top, 13)
        .padding(.bottom, bottomInset < 60 ? 29 - bottomInset : 8)
        .background(WristbandStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Moving between stages

    /// 240 ms ease-out; none for VoiceOver.
    private var dissolveAnimation: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: 0.24)
    }

    /// A category: the ticket and its line dissolve into the new venue's. The selected tab
    /// changes nothing and animates nothing.
    private func chooseCategory(_ category: PlaceCategory) {
        var changed = false
        withAnimation(dissolveAnimation) {
            changed = session.choosePlaceCategory(category)
        }
        if changed {
            AccessibilityNotification.Announcement("\(category.title): \(category.venue.name)").post()
        }
    }

    /// View place: the ticket expands into its detail (500 ms ease-out), or dissolves under Reduce
    /// Motion; nothing for VoiceOver.
    private func openDetail() {
        if adaptive.reduceMotion || adaptive.voiceOverRunning {
            dissolve { session.openPlaceDetail() }
        } else {
            withAnimation(.easeOut(duration: 0.5)) {
                _ = session.openPlaceDetail()
            }
        }
    }

    /// Preview room demo: the Room entry dissolves in above the explanation (240 ms; none for VoiceOver).
    private func openRoom() {
        withAnimation(dissolveAnimation) {
            _ = session.previewRoomDemo()
        }
    }

    /// Changes the model at once and dissolves whatever it replaced.
    private func dissolve(_ change: () -> Bool) {
        withAnimation(dissolveAnimation) {
            if change() {
                dissolveToken += 1
            }
        }
    }

    /// One stage back: the header's Back, the bottom Back actions, a completed swipe and VoiceOver's
    /// escape all come here. The domain decides where (`placesBack(from:)`: nothing if `stage` is no
    /// longer the one shown); this decides only how it moves. From browsing, the navigation stack's
    /// native pop carries the screen to Signal. An inner stage dissolves (240 ms, none for
    /// VoiceOver), or, after a swipe has already carried the screen away, changes at once. Returns
    /// whether it went back.
    @discardableResult
    private func back(from stage: PlacesStage, afterSwipe: Bool = false) -> Bool {
        if stage == .browse {
            return session.placesBack(from: stage.scene)
        }
        var moved = false
        if afterSwipe {
            // The screen has left; the previous stage takes its place at once, without replaying
            // a dissolve over a screen that is already gone.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                moved = session.placesBack(from: stage.scene)
                dissolveToken += 1
                backDrag = 0
            }
            if moved && stage == .detail {
                revealTicketEnd += 1
            }
        } else {
            // The dissolve (as `dissolve(_:)`), and once it has finished, Back to places from a
            // detail aligns browsing again (`revealTicketEndAgain`). A repeated request that no
            // longer moves anything re-aligns the same ticket, which is harmless.
            withAnimation(dissolveAnimation) {
                moved = session.placesBack(from: stage.scene)
                if moved {
                    dissolveToken += 1
                }
            } completion: {
                if stage == .detail {
                    revealTicketEnd += 1
                }
            }
        }
        return moved
    }

    /// VoiceOver's escape: exactly the one stage the Back controls go. Ignored while a completed
    /// swipe is still finishing, as a second swipe is; any swipe offset is dropped first.
    private func escape(from stage: PlacesStage) {
        if session.room != nil {
            RoomView.outerBack(session, animation: dissolveAnimation)
            return
        }
        guard !backCompleting else { return }
        backDrag = 0
        back(from: stage)
    }

    // MARK: - Where a stage starts

    /// Back to places, once browsing has replaced the detail: the ticket's end (the 25-pt gap below
    /// the ticket) is aligned with the bottom of the visible page again, now against browsing's own
    /// content and action bar. The scroll `revealStart` issues while the stage changes stopped, as
    /// reconstructed from build 6ab8adb4's frames, within the outgoing detail's scroll range (about
    /// 1293 on the 390-pt iPhone, where browsing's alignment was about 1311, leaving View place
    /// 3.7 pt under the bar). Nothing happens if another stage is showing by then.
    private func revealTicketEndAgain(with reader: ScrollViewProxy) {
        guard session.flow.currentScene == .places else { return }
        withAnimation(adaptive.reduceMotion || adaptive.voiceOverRunning ? nil : .easeOut(duration: 0.2)) {
            reader.scrollTo(PlacesScrollTarget.ticketEnd, anchor: .bottom)
        }
    }

    /// A new detail or explanation starts at its beginning (the header, then the venue or the
    /// headline), never at the offset browsing was scrolled to: moving with the expansion, at once
    /// for a dissolve. Back to browsing shows the originating ticket's end, where View place is;
    /// Explore other places starts browsing (at Now) from the top.
    private func revealStart(from previous: DemoScene, to scene: DemoScene, with reader: ScrollViewProxy) {
        let expanding = previous == .places && scene == .placeDetail
            && !adaptive.reduceMotion && !adaptive.voiceOverRunning
        withAnimation(expanding ? .easeOut(duration: 0.5) : nil) {
            switch scene {
            case .placeDetail, .placeExplanation:
                reader.scrollTo(PlacesScrollTarget.top, anchor: .top)
            case .places where previous == .placeDetail:
                reader.scrollTo(PlacesScrollTarget.ticketEnd, anchor: .bottom)
            case .places where previous == .placeExplanation:
                reader.scrollTo(PlacesScrollTarget.top, anchor: .top)
            default:
                break
            }
        }
    }

    // MARK: - The back swipe

    /// The screen follows the finger. Nothing changes in the model until the swipe is completed.
    private func swipeChanged(_ translation: CGFloat) {
        // Above the explanation the Room decides what a finished swipe does; the screen stays put.
        guard !backCompleting, session.room == nil else { return }
        backDrag = translation
    }

    /// Completed (past 40 % of the width, or a quick flick) the swipe goes back one stage, as the
    /// Back controls do; otherwise the screen returns and nothing changes. From browsing, the
    /// navigation stack pops to Signal, carrying the screen on from where the finger left it.
    private func swipeEnded(_ translation: CGFloat, _ velocity: CGFloat, _ width: CGFloat) {
        guard !backCompleting else { return }
        let completes = translation > width * 0.4 || (velocity > 700 && translation > 24)
        if session.room != nil {
            // The Room's outer Back: the entry to the explanation, one level of its callers, or, at an
            // active run's root, the terminal Leave. A swipe that is not completed changes nothing.
            if completes {
                RoomView.outerBack(session, animation: dissolveAnimation)
            }
            return
        }
        guard completes else {
            swipeCancelled()
            return
        }
        let stage = self.stage
        if stage == .browse {
            if !back(from: .browse) {
                swipeCancelled()
            }
            return
        }
        if adaptive.reduceMotion || adaptive.voiceOverRunning {
            backDrag = 0
            back(from: stage)
            return
        }
        backCompleting = true
        withAnimation(.easeOut(duration: 0.2)) {
            backDrag = width
        } completion: {
            // Nothing moves in the model if another Back already did while the screen slid away.
            back(from: stage, afterSwipe: true)
            backCompleting = false
        }
    }

    /// Not completed: the screen returns and nothing changes.
    private func swipeCancelled() {
        guard !backCompleting else { return }
        withAnimation(adaptive.reduceMotion || adaptive.voiceOverRunning ? nil : .easeOut(duration: 0.2)) {
            backDrag = 0
        }
    }
}

/// Scroll positions a stage can be shown from.
private enum PlacesScrollTarget: Hashable {
    /// The header: a stage's beginning.
    case top
    /// The end of the browse ticket, where View place is, and the 25-pt gap below it, so the ticket
    /// stops that far above the action bar once it is aligned (`revealTicketEndAgain`).
    case ticketEnd
}

private enum PlacesStage: Hashable {
    case browse
    case detail
    case explanation

    /// The domain scene this stage shows.
    var scene: DemoScene {
        switch self {
        case .browse: return .places
        case .detail: return .placeDetail
        case .explanation: return .placeExplanation
        }
    }
}

// MARK: - Browsing and detail

/// Browsing (the headline, the snapshot line, the tabs, the ticket and its line) or a detail (the
/// expanded ticket). The ticket keeps its identity across the two, so View place moves it.
private struct PlacesTicketStage: View {
    let stage: PlacesStage
    let category: PlaceCategory
    let venue: Venue
    let eligibility: PlaceEligibility
    let width: CGFloat
    let choose: (PlaceCategory) -> Void
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if stage == .browse {
                VStack(alignment: .leading, spacing: 0) {
                    PlacesHeadline(lines: ["Find your", "kind of place."], identifier: "places.headline")
                    WristbandBodyText(text: PlacesSnapshot.label, size: 14, lineHeight: 24,
                                      color: WristbandStyle.secondaryText, alignment: .leading)
                        .padding(.top, 14)
                        .accessibilityIdentifier("places.context")
                    PlacesTabs(selected: category, choose: choose)
                        .padding(.top, 18)
                }
                .padding(.top, 40)
                .transition(.opacity)
            }
            ZStack(alignment: .top) {
                VenueTicket(venue: venue, eligibility: eligibility, mode: stage == .browse ? .browse : .detail,
                            width: width, open: open)
                    .id(venue)
                    .transition(.opacity)
            }
            .padding(.top, stage == .browse ? 10 : 38)
            if stage == .browse {
                // The 25-pt gap between the ticket and its line: the target Back to places aligns
                // with the bottom of the visible page (`PlacesScrollTarget.ticketEnd`).
                Color.clear
                    .frame(height: 25)
                    .id(PlacesScrollTarget.ticketEnd)
                ZStack(alignment: .top) {
                    WristbandBodyText(text: eligibility.browseBoundary, size: 14, lineHeight: 22,
                                      color: WristbandStyle.secondaryText, alignment: .center)
                        .id(eligibility)
                        .transition(.opacity)
                        .accessibilityIdentifier("places.boundary")
                }
                .transition(.opacity)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// "Find your / kind of place." and "Arrive. / Then connect.": ExtraBold 48/56, −4 % tracking, on
/// the approved line breaks; at larger text each line wraps between its words rather than
/// shrinking.
private struct PlacesHeadline: View {
    let lines: [String]
    let identifier: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .manrope(.extraBold, size: size, designSize: 48, lineHeight: 56, tracking: -1.92)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(lines.joined(separator: " ")))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Tabs

/// Now / Later / Upcoming: 376 × 48 (#111415, radius 18; 2 pt above and below, 4 pt at the sides
/// and between) holding three 120 × 44 tabs (radius 14). Selected: #F6F7F2 with #050606
/// SemiBold 15; otherwise #A8B0AD. At larger text the tabs stack rather than truncate.
private struct PlacesTabs: View {
    let selected: PlaceCategory
    let choose: (PlaceCategory) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(PlaceCategory.allCases) { category in
                    tab(category)
                }
            }
            VStack(spacing: 4) {
                ForEach(PlaceCategory.allCases) { category in
                    tab(category)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(WristbandStyle.tile, in: RoundedRectangle(cornerRadius: 18, style: .circular))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessions")
        .accessibilityIdentifier("places.tabs")
    }

    private func tab(_ category: PlaceCategory) -> some View {
        let isSelected = category == selected
        return Button {
            choose(category)
        } label: {
            PlacesTabLabel(title: category.title, selected: isSelected)
        }
        .buttonStyle(PlacesTabStyle(selected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("places.tab.\(category.rawValue)")
    }
}

private struct PlacesTabLabel: View {
    let title: String
    let selected: Bool
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 15

    var body: some View {
        Text(title)
            .lineLimit(1)
            .manrope(.semiBold, size: size, designSize: 15, lineHeight: 44)
            .foregroundStyle(selected ? WristbandStyle.ground : WristbandStyle.secondaryText)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

private struct PlacesTabStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        configuration.label
            .background(selected ? WristbandStyle.primary : Color.clear, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed && !selected ? 0.7 : 1)
    }
}

// MARK: - The venue ticket

/// The native ticket under the venue's scene (`LAYOUT_SPEC.json`, component set 59:443). The scene
/// slot (344 × 248) sits at the ticket's top, centred; the ivory ticket (#F6F7F2, radius 26)
/// starts 92 pt below it. The name (ExtraBold 28/40, 32/40 on a detail) and the kind (Regular
/// 14/22) keep the same place in both layouts; below them browsing shows the permitted intents,
/// the perforation and the schedule beside "View place  →", and a detail the perforation, the
/// schedule (Bold 19/28), the intents, the host, the description, the rules and its last line.
private struct VenueTicket: View {
    enum Mode {
        case browse
        case detail
    }

    let venue: Venue
    let eligibility: PlaceEligibility
    let mode: Mode
    let width: CGFloat
    let open: () -> Void
    @ScaledMetric(relativeTo: .title) private var nameSize: CGFloat = 28

    private var k: CGFloat { width / 376 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VenueArt(venue: venue)
                .frame(width: 344 * k, height: 248 * k)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                name
                PlacesTicketText(text: venue.kind, face: .regular, size: 14, lineHeight: 22)
                    .padding(.top, 4)
                    .accessibilityIdentifier(mode == .browse ? "places.ticket.kind" : "place.kind")
                if mode == .browse {
                    browseLower
                        .transition(.opacity)
                } else {
                    detailLower
                        .transition(.opacity)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)
            .padding(.bottom, bottomPadding)
        }
        .frame(width: width, alignment: .leading)
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 26, style: .circular)
                .fill(WristbandStyle.primary)
                .padding(.top, 92 * k)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .browse {
                open()
            }
        }
        // Browsing: the name, kind, intents and schedule read in order, and View place is the one
        // action. The card itself also opens the detail when tapped.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(mode == .browse ? "places.ticket" : "place.ticket")
    }

    private var bottomPadding: CGFloat {
        switch mode {
        case .browse: return 14
        case .detail: return eligibility.intentMatches ? 12 : 4
        }
    }

    private var name: some View {
        let design: CGFloat = mode == .browse ? 28 : 32
        let size = nameSize * design / 28
        return Text(venue.name)
            .manrope(.extraBold, size: size, designSize: design, lineHeight: 40)
            .foregroundStyle(WristbandStyle.ground)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.interpolate)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(mode == .browse ? "places.ticket.name" : "place.name")
    }

    /// Browsing: the intents (y 328), the perforation (y 365) and the footer (y 380, 44 tall on
    /// the approved layout; taller when it has to stack, and the ticket grows with it).
    private var browseLower: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntentChips(intents: venue.permittedIntents, identifier: "places.ticket.intents")
                .padding(.top, 10)
            TicketPerforation(width: width)
                .padding(.top, 11)
            TicketFooterLayout {
                PlacesWrappingText(text: venue.schedule, face: .semiBold, size: 14, lineHeight: 22)
                    .accessibilityIdentifier("places.ticket.schedule")
                ViewPlaceButton(open: open)
            }
            .padding(.top, 14)
        }
    }

    /// A detail: the perforation (y 334), the schedule (y 352), the intents (y 390), the host
    /// (y 430), the description (y 467), the rules (y 536) and the last line: "Sample session · not
    /// a reservation" (y 596), or the mismatch in its two-line slot (y 582).
    private var detailLower: some View {
        VStack(alignment: .leading, spacing: 0) {
            TicketPerforation(width: width)
                .padding(.top, 16)
            PlacesTicketText(text: venue.schedule, face: .bold, size: 19, lineHeight: 28)
                .padding(.top, 17)
                .accessibilityIdentifier("place.schedule")
            IntentChips(intents: venue.permittedIntents, identifier: "place.intents")
                .padding(.top, 10)
            PlacesTicketText(text: venue.hostLine, face: .medium, size: 14, lineHeight: 22)
                .padding(.top, 14)
                .accessibilityIdentifier("place.host")
            PlacesTicketText(text: venue.brief, face: .regular, size: 16, lineHeight: 24)
                .padding(.top, 15)
                .accessibilityIdentifier("place.brief")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(PlacesSnapshot.rules, id: \.self) { rule in
                    PlacesTicketText(text: rule, face: .medium, size: 14, lineHeight: 22)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("place.rules")
            // After the element, so its frame is the rules' own lines, not the gap above them.
            .padding(.top, 21)
            PlacesTicketText(text: eligibility.detailBoundary, face: .regular, size: 14, lineHeight: 22)
                .frame(maxWidth: .infinity, minHeight: eligibility.intentMatches ? 22 : 44, alignment: .topLeading)
                .padding(.top, eligibility.intentMatches ? 16 : 2)
                .accessibilityIdentifier("place.boundary")
        }
    }
}

/// Ticket text: #050606 at its Figma size and line height, following Dynamic Type and wrapping.
private struct PlacesTicketText: View {
    let text: String
    let face: Manrope
    let size: CGFloat
    let lineHeight: CGFloat

    var body: some View {
        WristbandText(text: text, face: face, size: size, lineHeight: lineHeight, color: WristbandStyle.ground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The permitted intents: #050606 capsules, 26 tall (radius 13), with #F6F7F2 SemiBold 14/26
/// labels (the corrected ivory on dark), at their Figma widths (Social 72, Business 96, Activity
/// 84, Dating 72), 8 apart. Words, never colour alone. At larger text they stack.
private struct IntentChips: View {
    let intents: [BandIntent]
    let identifier: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(intents) { intent in
                    IntentChip(intent: intent)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(intents) { intent in
                    IntentChip(intent: intent)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("For \(intents.map(\.title).joined(separator: " and ")) bands")
        .accessibilityIdentifier(identifier)
    }
}

private struct IntentChip: View {
    let intent: BandIntent
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 14

    private var figmaWidth: CGFloat {
        switch intent {
        case .social, .dating: return 72
        case .business: return 96
        case .activity: return 84
        }
    }

    var body: some View {
        Text(intent.title)
            .lineLimit(1)
            .manrope(.semiBold, size: size, designSize: 14, lineHeight: 26)
            .foregroundStyle(WristbandStyle.primary)
            .padding(.horizontal, 12)
            .frame(minWidth: figmaWidth * size / 14, minHeight: 26)
            .background(WristbandStyle.ground, in: Capsule())
            .fixedSize()
    }
}

/// The browse ticket's footer: the schedule and View place side by side when both fit at their
/// natural sizes (the approved layout: the schedule top-aligned beside the 140 × 44 action, 8 apart,
/// in a 44-pt row), otherwise the complete schedule, wrapped to the column, above the action, 12
/// apart. Measured from the actual content at the current text size, so the action never covers
/// the schedule and nothing is cut; the ticket grows with the footer.
private struct TicketFooterLayout: Layout {
    private let spacing: CGFloat = 8
    private let stackedSpacing: CGFloat = 12
    private let rowHeight: CGFloat = 44

    /// Both at their natural (unwrapped) widths, with the spacing, fit the column.
    private func fitsSideBySide(_ subviews: Subviews, width: CGFloat) -> Bool {
        guard subviews.count == 2 else { return false }
        let schedule = subviews[0].sizeThatFits(.unspecified).width
        let action = subviews[1].sizeThatFits(.unspecified).width
        return schedule + spacing + action <= width
    }

    /// The action at its natural size, wrapped to the column only if it is wider than that.
    private func actionSize(_ subviews: Subviews, width: CGFloat) -> CGSize {
        let natural = subviews[1].sizeThatFits(.unspecified)
        return natural.width <= width ? natural : subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        // An unspecified or infinite proposal measures at the natural width: an infinite width returned
        // as this layout's size is an invalid (non-finite) frame.
        let natural = subviews[0].sizeThatFits(.unspecified).width + spacing + subviews[1].sizeThatFits(.unspecified).width
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? natural
        let action = actionSize(subviews, width: width)
        if fitsSideBySide(subviews, width: width) {
            let schedule = subviews[0].sizeThatFits(ProposedViewSize(width: width - spacing - action.width, height: nil))
            return CGSize(width: width, height: max(rowHeight, schedule.height, action.height))
        }
        let schedule = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: schedule.height + stackedSpacing + action.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let width = bounds.width
        let action = actionSize(subviews, width: width)
        if fitsSideBySide(subviews, width: width) {
            subviews[0].place(at: bounds.origin, anchor: .topLeading,
                              proposal: ProposedViewSize(width: width - spacing - action.width, height: nil))
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.minY), anchor: .topTrailing,
                              proposal: ProposedViewSize(action))
        } else {
            let schedule = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: width, height: nil))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + schedule.height + stackedSpacing),
                              anchor: .topLeading, proposal: ProposedViewSize(action))
        }
    }
}

/// Ticket text that wraps at any width: Manrope at its Figma size and line pitch (both following
/// Dynamic Type), #050606. Its first line box is the Figma line height, like `PlacesTicketText`'s,
/// but its size is always the wrapped text's, so a layout measuring it never sees one line where
/// two are drawn.
private struct PlacesWrappingText: View {
    let text: String
    let face: Manrope
    let size: CGFloat
    let lineHeight: CGFloat
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let scaled = size * scale
        let extra = max(0, lineHeight * scale - face.naturalLineHeight(size: scaled))
        Text(text)
            .font(face.font(size: scaled))
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .foregroundStyle(WristbandStyle.ground)
            .multilineTextAlignment(.leading)
    }
}

/// "View place  →": 140 × 44 at least, #050606 (radius 13), #F6F7F2 SemiBold 14, centred. A real
/// button (VoiceOver: "View place"); at the largest text sizes its words wrap inside it rather
/// than run past the ticket.
private struct ViewPlaceButton: View {
    let open: () -> Void
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 14

    var body: some View {
        Button(action: open) {
            Text("View place  →")
                .font(Manrope.semiBold.font(size: size))
                .multilineTextAlignment(.center)
                .foregroundStyle(WristbandStyle.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 140, minHeight: 44)
                .background(WristbandStyle.ground, in: RoundedRectangle(cornerRadius: 13, style: .circular))
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .circular))
        }
        .buttonStyle(ViewPlaceButtonStyle())
        .accessibilityLabel("View place")
        .accessibilityHint("Opens this fictional venue's details.")
        .accessibilityIdentifier("places.viewPlace")
    }
}

private struct ViewPlaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// The perforation: 6 × 1 dashes (#050606) every 13 pt from 18 pt in, stopping 27 pt from the
/// far edge (26 dashes on the 376-pt ticket), and a 16-pt notch cut into each edge (the ground
/// colour), centred on the ticket's edges and on the line. Decoration. It takes 1 pt of the
/// column's height; the canvas reaches 8 pt past the ticket on each side for the notches' outer
/// halves (the column itself is inset 20 pt).
private struct TicketPerforation: View {
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            // The column's 1-pt row is the canvas's middle point row: the dash fills it and the
            // notches are centred on its top edge (Figma: dashes at y 739–740, notches 731–747).
            let y = size.height / 2 - 0.5
            let ticket = size.width - 16
            var x: CGFloat = 18
            while x + 6 <= ticket - 27 {
                context.fill(Path(CGRect(x: 8 + x, y: y, width: 6, height: 1)), with: .color(WristbandStyle.ground))
                x += 13
            }
            for centre in [CGFloat(8), 8 + ticket] {
                context.fill(Path(ellipseIn: CGRect(x: centre - 8, y: y - 8, width: 16, height: 16)),
                             with: .color(WristbandStyle.ground))
            }
        }
        .frame(width: width + 16, height: 16)
        .padding(.horizontal, -28)
        .padding(.vertical, -7.5)
        .accessibilityHidden(true)
    }
}

// MARK: - The venue scenes

/// A venue's original 1254 × 1254 RGBA scene, cropped once to its approved rectangle with its
/// alpha kept, and fitted (never stretched) into the 344 × 248 slot. Decoration: hidden from
/// VoiceOver, since the name and the description already say what the place is.
private struct VenueArt: View {
    let venue: Venue

    var body: some View {
        Group {
            if let image = PlacesArt.image(for: venue) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
    }
}

@MainActor
enum PlacesArt {
    /// `ART_PROMPTS.json` / `LAYOUT_SPEC.json` crops, XYXY: [46, 83, 1211, 1218], [5, 105, 1249,
    /// 1186] and [8, 39, 1247, 1163].
    nonisolated static func crop(for venue: Venue) -> CGRect {
        switch venue {
        case .commonGround: return CGRect(x: 46, y: 83, width: 1211 - 46, height: 1218 - 83)
        case .afterglow: return CGRect(x: 5, y: 105, width: 1249 - 5, height: 1186 - 105)
        case .fieldwork: return CGRect(x: 8, y: 39, width: 1247 - 8, height: 1163 - 39)
        }
    }

    nonisolated static func assetName(for venue: Venue) -> String {
        switch venue {
        case .commonGround: return "PlaceCommonGround"
        case .afterglow: return "PlaceAfterglow"
        case .fieldwork: return "PlaceFieldwork"
        }
    }

    private static var cache: [Venue: UIImage] = [:]

    static func image(for venue: Venue) -> UIImage? {
        if let cached = cache[venue] {
            return cached
        }
        guard let cropped = UIImage(named: assetName(for: venue))?.cgImage?.cropping(to: crop(for: venue)) else {
            return nil
        }
        let image = UIImage(cgImage: cropped)
        cache[venue] = image
        return image
    }
}

// MARK: - The check-in explanation

/// Common Ground's check-in explanation (58:486): "Arrive. / Then connect.", the support line,
/// the venue card, the two steps a later, real check-in would ask for, and the two boundaries.
/// Explanation only: no permission, location, camera, scanner, credential, timer, result,
/// presence or Room. The icons are the supplied explanatory vectors.
private struct PlacesExplanation: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlacesHeadline(lines: CheckInExplanation.headline, identifier: "explanation.headline")
                .padding(.top, 40)
            WristbandBodyText(text: CheckInExplanation.support, size: 16, lineHeight: 26,
                              color: WristbandStyle.secondaryText, alignment: .leading)
                .padding(.top, 14)
                .accessibilityIdentifier("explanation.support")
            card
                .padding(.top, 30)
            ForEach(Array(CheckInExplanation.steps.enumerated()), id: \.offset) { index, step in
                CheckInStep(number: index + 1, title: step.title, explanation: step.explanation)
                    .padding(.top, index == 0 ? 27 : 16)
            }
            WristbandText(text: CheckInExplanation.presenceBoundary, face: .medium, size: 14, lineHeight: 24,
                          color: .white, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
                .accessibilityIdentifier("explanation.presence")
            WristbandText(text: CheckInExplanation.demoBoundary, face: .medium, size: 14, lineHeight: 24,
                          color: WristbandStyle.cyan, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .accessibilityIdentifier("explanation.demo")
        }
        .frame(width: width, alignment: .leading)
    }

    /// The venue card: 376 × 88, #F6F7F2, radius 20; "Common Ground" ExtraBold 23/30 and
    /// "Fictional venue · Today, 6–10 pm" Medium 14/22, 4 apart, inset 14 / 20.
    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            PlacesTicketText(text: CheckInExplanation.venue.name, face: .extraBold, size: 23, lineHeight: 30)
            PlacesTicketText(text: CheckInExplanation.context, face: .medium, size: 14, lineHeight: 22)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(WristbandStyle.primary, in: RoundedRectangle(cornerRadius: 20, style: .circular))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("explanation.venue")
    }
}

/// A step: 376 × 112, #111415, radius 18, inset 16; the 28-pt symbol (#F3F2EF, 1.98 pt) and, 14
/// apart, the title (SemiBold 17/24) over the explanation (Regular 14/20, #A8B0AD), 6 apart.
private struct CheckInStep: View {
    let number: Int
    let title: String
    let explanation: String
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PlacesGlyph(pieces: number == 1 ? PlacesPaths.location : PlacesPaths.scan,
                        stroke: 1.9833333492279053, color: SignalStyle.rowSymbol, designSize: 28)
                .frame(width: 28 * min(scale, 1.5), height: 28 * min(scale, 1.5))
            VStack(alignment: .leading, spacing: 6) {
                WristbandText(text: title, face: .semiBold, size: 17, lineHeight: 24, color: .white)
                WristbandText(text: explanation, face: .regular, size: 14, lineHeight: 20,
                              color: WristbandStyle.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(WristbandStyle.tile, in: RoundedRectangle(cornerRadius: 18, style: .circular))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("explanation.step.\(number)")
    }
}

/// Stroked vector pieces in a `designSize` square, scaled to the frame; round caps and joins.
private struct PlacesGlyph: View {
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

/// The explanation's step symbols, verbatim from `LAYOUT_SPEC.json` (nodes 59:824, 59:825 and
/// 59:831), with each vector's offset in its 28-pt frame.
enum PlacesPaths {
    typealias Piece = WristbandPaths.Piece

    static let location: [Piece] = [
        Piece(x: 4.6666669845581055, y: 2.333333730697632, data: "M 18.66666603088379 9.333332824707032 C 18.66666603088379 16.333332443237307 9.333333015441895 23.333332061767578 9.333333015441895 23.333332061767578 C 9.333333015441895 23.333332061767578 0 16.333332443237307 0 9.333332824707032 C 0 6.857978963644156 0.9833306335268475 4.484009399036609 2.7336700620990655 2.7336700062341155 C 4.4840094906712835 0.983330613431622 6.857979103792985 2.590520249619874e-15 9.333333015441895 0 C 11.808686927090804 1.5543121497719245e-15 14.182657096522505 0.983330613431622 15.932996525094723 2.7336700062341155 C 17.68333595366694 4.484009399036609 18.666666030883786 6.857978963644156 18.66666603088379 9.333332824707032 Z"),
        Piece(x: 11.083333015441895, y: 8.75, data: "M 5.8333330154418945 2.9166665077209473 C 5.8333330154418945 4.527496985231278 4.527496985231278 5.8333330154418945 2.9166665077209473 5.8333330154418945 C 1.3058360302106164 5.8333330154418945 0 4.527496985231278 0 2.9166665077209473 C 0 1.3058360302106164 1.3058360302106164 0 2.9166665077209473 0 C 4.527496985231278 0 5.8333330154418945 1.3058360302106164 5.8333330154418945 2.9166665077209473 Z"),
    ]

    static let scan: [Piece] = [
        Piece(x: 3.500000476837158, y: 3.500000476837158, data: "M 5.833333333333334 0 L 2.3333333333333335 0 C 1.7144948343435924 5.181040781584064e-16 1.121002271771431 0.24583252767721814 0.6834173997243246 0.6834173997243246 C 0.24583252767721814 1.121002271771431 5.181040781584064e-16 1.7144948343435924 0 2.3333333333333335 L 0 5.833333333333334 M 15.166666666666668 0 L 18.666666666666668 0 C 19.28550516565641 5.181040781584064e-16 19.878997171918552 0.24583252767721814 20.31658204396566 0.6834173997243246 C 20.754166916012768 1.121002271771431 21 1.7144948343435924 21 2.3333333333333335 L 21 5.833333333333334 M 21 15.166666666666668 L 21 18.666666666666668 C 21 19.28550516565641 20.754166916012768 19.878997171918552 20.31658204396566 20.31658204396566 C 19.878997171918552 20.754166916012768 19.28550516565641 21 18.666666666666668 21 L 15.166666666666668 21 M 5.833333333333334 21 L 2.3333333333333335 21 C 1.7144948343435924 21 1.121002271771431 20.754166916012768 0.6834173997243246 20.31658204396566 C 0.24583252767721814 19.878997171918552 5.181040781584064e-16 19.28550516565641 0 18.666666666666668 L 0 15.166666666666668 M 1.1666666666666667 10.5 L 19.833333333333336 10.5"),
    ]
}

#if DEBUG
#Preview("Places · Now, Social") {
    NavigationStack { PlacesView() }
        .environment(PreviewFixtures.session(at: .places, band: .social, signal: .chatFirst))
}

#Preview("Places · Fieldwork detail, Social") {
    NavigationStack { PlacesView() }
        .environment(PreviewFixtures.session(at: .placeDetail, band: .social, signal: .chatFirst, category: .upcoming))
}

#Preview("Places · check-in explanation, Business") {
    NavigationStack { PlacesView() }
        .environment(PreviewFixtures.session(at: .placeExplanation, band: .business, signal: .okayToSayHello))
}
#endif
