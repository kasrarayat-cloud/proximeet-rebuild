import SwiftUI
import UIKit
import ProximeetDomain

/// Chapter 08 — the approved Room (handoff `LAYOUT_SPEC.json`, Figma page 66:111: the fifteen screens
/// 66:112–66:126, the eight panels 66:127–66:134 and the report-reason set 67:856), on the 440 × 956
/// reference canvas.
///
/// Shown by `PlacesView` above Common Ground's check-in explanation while `session.room` exists: first
/// the entry, then (only after "Enter room demo") one local run in waiting, the fictional sample (only
/// after the labelled demo control), and the ended screen. Everything on screen is derived from the
/// session's `RoomPreview` and its `RoomRun`: the phase, the one blocked set, the tab and the caller
/// levels. This view keeps no copy of any of them, and every control captures the run it was drawn for,
/// so a late or repeated tap on an earlier run changes nothing. A blocked sample, the samples in waiting
/// and everything after Leave are absent from the view tree, not hidden, so they are absent from
/// accessibility too.
///
/// Motion follows the approved prototype: Enter moves the ivory ticket, its art, the venue name and the
/// guest's preference line into the compact header in one 500 ms ease-out two-dimensional move (the
/// ticket keeps its identity; only its layout changes), while the session line crossfades and the entry
/// copy gives way to the waiting copy. Every other change (tabs, cards, profiles, panels, a report
/// reason) is a 240 ms ease-out dissolve. Reduce Motion (the system setting or the app's preview flag)
/// turns the move into a plain crossfade; VoiceOver gets no animation. The model always changes first;
/// Block and Leave change it with animations disabled, so what they hide never lingers. Nothing here
/// reads a clock, runs a timer, stores, sends or logs anything; the one deferred step is moving VoiceOver
/// focus on the next main-actor turn (`focusSoon`).
struct RoomView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @AccessibilityFocusState private var focus: RoomFocus?
    /// The last Room shown. The entry's Back and Return to Places end the Room inside a 240-ms dissolve;
    /// the copy SwiftUI keeps for that removal still reads the session, which is already empty, so it
    /// draws this instead and fades the actual entry or ended screen rather than a bare ground. Neither
    /// screen shows a sample, and every action still goes through the session's guards.
    @State private var lastShown: RoomPreview?
    /// The bar's last measured height, so the spacer that stands in for it under a panel keeps the page
    /// exactly where it was.
    @State private var barHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = min(376, max(0, proxy.size.width - 64))
            if let room = session.room ?? lastShown {
                layers(room, width: width, proxy: proxy)
            }
        }
        .background(RoomStyle.ground.ignoresSafeArea())
        .background(RepeatTapGuard())
        .onAppear {
            lastShown = session.room
            focusSoon(Self.appearTarget(session.room))
        }
        .onChange(of: session.room) { previous, current in
            if let current { lastShown = current }
            focusSoon(Self.focusTarget(from: previous, to: current))
        }
        // One container above every element, so VoiceOver's escape has a single owner here, as on Places.
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            RoomView.outerBack(session, animation: dissolveAnimation)
        }
        .accessibilityIdentifier("room.screen")
    }

    /// The Room's outer Back: a completed swipe from the leading edge (`PlacesView`) or VoiceOver's
    /// escape. The session decides what it means (the entry back to the explanation, one caller level,
    /// the terminal Leave at an active run's root, Places once ended); this decides only how it moves.
    /// A Leave changes the model with animations disabled, like the Leave buttons; anything else uses
    /// `animation`.
    @MainActor
    static func outerBack(_ session: DemoSession, animation: Animation?) {
        let leaves = session.room?.run.map { $0.isActive && $0.route.isEmpty } ?? false
        if leaves {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                _ = session.roomOuterBack()
            }
        } else {
            withAnimation(animation) {
                _ = session.roomOuterBack()
            }
        }
    }

    // MARK: - Layers

    /// The screen, and above it the open panel (if any) over the dimmed screen. While a panel is open
    /// the screen below takes no touches and is hidden from accessibility, and its bar is not built
    /// at all (see `page`); the panel is modal.
    private func layers(_ room: RoomPreview, width: CGFloat, proxy: GeometryProxy) -> some View {
        let screen = RoomScreen(room)
        let panel = room.run?.panel
        return ZStack {
            page(room, screen: screen, width: width, bottomInset: proxy.safeAreaInsets.bottom, covered: panel != nil)
                .accessibilityHidden(panel != nil)
                .allowsHitTesting(panel == nil)
            if let run = room.run, let panel {
                panelLayer(run, panel: panel, width: width, height: proxy.size.height)
                    .transition(.opacity)
            }
        }
    }

    /// The chrome and the screen's content scroll; the screen's last actions stay in a bar above the
    /// home indicator (as on Places), so Leave, Enter and Return to Places are never covered or
    /// scrolled away at any text size.
    ///
    /// `covered`: a panel is open above the page. The page and its scrolling content are hidden from
    /// accessibility, and the bar below them is replaced by an empty spacer of its height (see there).
    private func page(_ room: RoomPreview, screen: RoomScreen, width: CGFloat, bottomInset: CGFloat,
                      covered: Bool) -> some View {
        ScrollViewReader { reader in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    chrome(screen, run: room.run)
                        .id(RoomScrollTarget.top)
                    column(room, screen: screen, width: width)
                        .frame(width: width, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 11)
                .accessibilityHidden(covered)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ground behind the status bar, so scrolled text never runs under the clock.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(RoomStyle.ground.ignoresSafeArea(edges: .top))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if covered {
                    // Under a panel the bar is not built at all: builds 6abc1b80 and 6abc2ae1 found its
                    // Leave still in the accessibility tree with `accessibilityHidden` on the page and on
                    // the bar itself. An empty spacer of the bar's height keeps the dimmed page still.
                    Color.clear
                        .frame(height: barHeight)
                } else {
                    actionBar(room, screen: screen, width: width, bottomInset: bottomInset)
                        .background {
                            GeometryReader { bar in
                                Color.clear
                                    .onAppear { barHeight = bar.size.height }
                                    .onChange(of: bar.size.height) { _, height in barHeight = height }
                            }
                        }
                }
            }
            .onChange(of: screen) { previous, current in
                reveal(from: previous, to: current, with: reader)
            }
            // People and Room notes are one screen with two tabs, so a tab change (or a Block from a
            // note, which lands on People) also starts at the beginning, never at the other tab's offset.
            .onChange(of: room.run?.tab) {
                reader.scrollTo(RoomScrollTarget.top, anchor: .top)
            }
        }
    }

    /// A new screen starts at its beginning, never at the offset the previous one was scrolled to: with
    /// the ticket's move after Enter, at once otherwise (a dissolve hides it).
    private func reveal(from previous: RoomScreen, to current: RoomScreen, with reader: ScrollViewProxy) {
        let entering = previous == .entry && current == .waiting
        let moving = entering && adaptive.playsEntrances
        withAnimation(moving ? .easeOut(duration: 0.5) : nil) {
            reader.scrollTo(RoomScrollTarget.top, anchor: .top)
        }
    }

    /// Everything below the chrome, 376 wide on the reference phone (x 32…408). The entry copy sits above
    /// the ticket; the ticket (every screen but ended) keeps its identity from the entry to the compact
    /// header; each screen's own content dissolves in below it.
    private func column(_ room: RoomPreview, screen: RoomScreen, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if screen == .entry {
                entryIntro
                    .transition(.opacity)
            }
            if screen != .ended {
                RoomVenueTicket(compact: screen != .entry, preference: room.preference, width: width)
                    .padding(.top, screen == .entry ? 24 : 20)
                    .id(ticketIdentity(screen))
                    .transition(.opacity)
            }
            ZStack(alignment: .top) {
                stage(room, screen: screen, width: width)
                    .id(screen)
                    .transition(.opacity)
            }
        }
    }

    /// The ticket's identity: one ticket that moves, or (Reduce Motion) a large and a compact ticket that
    /// crossfade in place.
    private func ticketIdentity(_ screen: RoomScreen) -> Int {
        guard adaptive.reduceMotion else { return 0 }
        return screen == .entry ? 1 : 2
    }

    @ViewBuilder
    private func stage(_ room: RoomPreview, screen: RoomScreen, width: CGFloat) -> some View {
        switch screen {
        case .entry:
            entryBoundary
        case .waiting:
            if let run = room.run {
                waitingContent(run, width: width)
            }
        case .tabs:
            if let run = room.run {
                tabsContent(run)
            }
        case .profile(let actor):
            if let run = room.run {
                profileContent(run, actor: actor)
            }
        case .ended:
            endedContent(width: width)
        }
    }

    // MARK: - Chrome

    /// The persistent demo chrome (392 × 44 at 24, 64): the brand at x 8 ("Room" after the Back chevron
    /// on a profile, 67:119), the DEMO badge at x 260 and, in an active run, the Safety shield at x 348.
    /// The entry and ended screens use the plain chrome (67:130): the badge keeps its place and the
    /// shield's slot stays empty, so Enter fades the shield in without moving anything.
    private func chrome(_ screen: RoomScreen, run: RoomRun?) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if screen.profileActor != nil, let run {
                    profileLeading(run.id)
                        .transition(.opacity)
                } else {
                    RoomChromeTitle(text: "Proximeet")
                        .accessibilityIdentifier("room.brand")
                        .padding(.leading, 8)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 8)
            RoomDemoBadge()
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            ZStack {
                safetyButton(screen, run: run)
            }
            .frame(width: 44, height: 44)
            .padding(.leading, 16)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }

    /// A profile's Back (44 × 44, the chevron of 67:122) and its "Room" title, 16 apart. Back closes the
    /// profile to the filtered People.
    private func profileLeading(_ id: RoomRunID) -> some View {
        HStack(spacing: 16) {
            RoomIconButton(pieces: RoomPaths.chevron) {
                change(id, animation: dissolveAnimation) { $0.closeLevel() }
            }
            .accessibilityLabel("Back")
            .accessibilityHint(Text(verbatim: "Returns to the sample introductions."))
            .accessibilityIdentifier("roomProfile.back")
            // The profile chrome's title is its header (spec order: Back → "Room" (header) → DEMO → Safety).
            RoomChromeTitle(text: RoomCopy.profileTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("roomProfile.title")
        }
    }

    /// The shield (67:115 / 67:126): generic safety on waiting, People and Room notes; the actor's own
    /// safety on a profile. None before Enter or after Leave.
    @ViewBuilder
    private func safetyButton(_ screen: RoomScreen, run: RoomRun?) -> some View {
        if let run, run.isActive {
            switch screen {
            case .waiting, .tabs:
                RoomIconButton(pieces: RoomPaths.shield) {
                    change(run.id, animation: dissolveAnimation) { $0.openGlobalSafety() }
                }
                .accessibilityLabel("Safety")
                .accessibilityHint(Text(verbatim: "Opens the safety options of this demo."))
                .accessibilityFocused($focus, equals: .chromeSafety)
                .accessibilityIdentifier("room.safety")
                .transition(.opacity)
            case .profile(let actor):
                RoomIconButton(pieces: RoomPaths.shield) {
                    change(run.id, animation: dissolveAnimation) { $0.openActorSafety(actor) }
                }
                .accessibilityLabel("Safety")
                .accessibilityHint(Text(verbatim: "Opens the safety options for \(actor.name)."))
                .accessibilityFocused($focus, equals: .profileSafety)
                .accessibilityIdentifier("roomProfile.safety")
                .transition(.opacity)
            case .entry, .ended:
                EmptyView()
            }
        }
    }

    // MARK: - Entry (66:112)

    /// "Come in. / Stay yourself." (ExtraBold 48/56, −4 %, at y 148) and the support line (Regular 17/26,
    /// #A8B0AD, at y 276).
    private var entryIntro: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomHeadline(lines: RoomCopy.entryHeadline, size: 48, lineHeight: 56, tracking: -1.92,
                         identifier: "roomEntry.headline")
                .accessibilityFocused($focus, equals: .entryHeadline)
            WristbandBodyText(text: RoomCopy.entrySupport, size: 17, lineHeight: 26,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .accessibilityIdentifier("roomEntry.support")
                .padding(.top, 16)
        }
        .padding(.top, 40)
    }

    /// The demo boundary under the ticket (Regular 14/22, centred, at y 687).
    private var entryBoundary: some View {
        WristbandBodyText(text: RoomCopy.entryBoundary, size: 14, lineHeight: 22,
                          color: RoomStyle.secondaryText, alignment: .center)
            .accessibilityIdentifier("roomEntry.boundary")
            .padding(.top, 31)
    }

    /// Enter room demo: the one gate that starts a run. The model changes first; the ticket then moves
    /// into the header (500 ms), or crossfades under Reduce Motion; nothing moves for VoiceOver.
    private func enter() {
        withAnimation(entranceAnimation) {
            _ = session.enterRoomDemo()
        }
    }

    // MARK: - Waiting (66:113)

    /// The sealed envelope (x 76, y 316), "A little privacy. / Before a hello." (ExtraBold 34/40 at
    /// y 500), the threshold explanation (Regular 16/24 in its 72-pt box at y 603), the cyan DEMO
    /// CONTROL label (y 686) and the labelled control that shows the fictional sample (376 × 60 at
    /// y 722). No name, initials, note or count of anyone.
    private func waitingContent(_ run: RoomRun, width: CGFloat) -> some View {
        let id = run.id
        return VStack(alignment: .leading, spacing: 0) {
            RoomEnvelope(identifier: "roomWaiting.envelope")
                .frame(width: min(288, width))
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
            RoomHeadline(lines: RoomCopy.waitingHeadline, size: 34, lineHeight: 40,
                         identifier: "roomWaiting.headline")
                .accessibilityFocused($focus, equals: .waitingHeadline)
                .padding(.top, 34)
            WristbandBodyText(text: RoomCopy.waitingExplanation, size: 16, lineHeight: 24,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .frame(minHeight: 72 * scale, alignment: .top)
                .accessibilityIdentifier("roomWaiting.explanation")
                .padding(.top, 23)
            RoomLabel(text: RoomCopy.demoControl, color: RoomStyle.cyan, alignment: .center)
                .accessibilityIdentifier("roomWaiting.demoControl")
                .padding(.top, 11)
            Button(RoomCopy.showPopulated) {
                change(id, animation: dissolveAnimation) { $0.showPopulatedExample() }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 60))
            .accessibilityHint(Text(verbatim: "Demo control. Shows fictional sample introductions."))
            .accessibilityIdentifier("roomWaiting.showPopulated")
            .padding(.top, 14)
        }
    }

    // MARK: - Ended (66:114)

    /// The closed envelope (y 242), "DEMO SESSION ENDED" (cyan, y 443), "You’ve left / the room."
    /// (ExtraBold 48/56 at y 501) and the explanation (Regular 16/26 at y 643). No Back into the run.
    private func endedContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomEnvelope(identifier: "roomEnded.envelope")
                .frame(width: min(288, width))
                .frame(maxWidth: .infinity)
                .padding(.top, 134)
            RoomLabel(text: RoomCopy.endedStatus, color: RoomStyle.cyan, alignment: .center)
                .accessibilityFocused($focus, equals: .endedStatus)
                .accessibilityIdentifier("roomEnded.status")
                .padding(.top, 51)
            RoomHeadline(lines: RoomCopy.endedHeadline, size: 48, lineHeight: 56, tracking: -1.92,
                         identifier: "roomEnded.headline")
                .padding(.top, 36)
            WristbandBodyText(text: RoomCopy.endedExplanation, size: 16, lineHeight: 26,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .accessibilityIdentifier("roomEnded.explanation")
                .padding(.top, 30)
        }
    }

    // MARK: - People and Room notes (66:115–66:126)

    /// The two tabs (y 292) and the selected tab's page, which dissolves on a change.
    private func tabsContent(_ run: RoomRun) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar(run)
                .padding(.top, 32)
            ZStack(alignment: .top) {
                tabPage(run)
                    .id(run.tab)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func tabPage(_ run: RoomRun) -> some View {
        switch run.tab {
        case .people:
            peoplePage(run)
        case .notes:
            notesPage(run)
        }
    }

    /// People / Room notes: 376 × 48 (#111415, radius 18; 2 pt above and below, 4 at the sides and
    /// between) holding two 182 × 44 tabs (radius 14). Selected: #F6F7F2 with #050606 SemiBold 15;
    /// otherwise #A8B0AD. At larger text the tabs stack rather than truncate.
    private func tabBar(_ run: RoomRun) -> some View {
        let id = run.id
        let selected = run.tab
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(RoomTab.allCases) { tab in
                    tabButton(tab, selected: selected, id: id)
                }
            }
            VStack(spacing: 4) {
                ForEach(RoomTab.allCases) { tab in
                    tabButton(tab, selected: selected, id: id)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 18, style: .circular))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Room sections")
        .accessibilityIdentifier("room.tabs")
    }

    private func tabButton(_ tab: RoomTab, selected: RoomTab, id: RoomRunID) -> some View {
        let isSelected = tab == selected
        return Button {
            change(id, animation: dissolveAnimation) { $0.selectTab(tab) }
        } label: {
            RoomTabLabel(title: tab.title, selected: isSelected)
        }
        .buttonStyle(RoomTabStyle(selected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("room.tab.\(tab.rawValue)")
    }

    /// "SAMPLE INTRODUCTIONS" (y 355) and the visible sample cards (376 × 170 from y 391, 16 apart), or,
    /// with both samples blocked, the filtered empty card (y 408). Never a claim about the venue.
    private func peoplePage(_ run: RoomRun) -> some View {
        let id = run.id
        return VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.peopleFraming, color: RoomStyle.secondaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focus, equals: .framing)
                .accessibilityIdentifier("room.peopleFraming")
                .padding(.top, 15)
            if run.showsNoSampleIntroductions {
                RoomEmptyCard()
                    .padding(.top, 31)
            } else {
                VStack(spacing: 16) {
                    ForEach(run.visiblePeople) { actor in
                        sampleCard(actor, id: id)
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    /// A whole card is one button that opens its sample's profile; it reads the name once.
    private func sampleCard(_ actor: RoomActor, id: RoomRunID) -> some View {
        Button {
            change(id, animation: dissolveAnimation) { $0.openProfile(actor) }
        } label: {
            RoomSampleCard(actor: actor)
        }
        .buttonStyle(RoomPressStyle())
        .accessibilityLabel(Text(verbatim: "\(actor.name). \(actor.line). \(actor.introduction) View card"))
        .accessibilityHint(Text(verbatim: "Opens this fictional profile."))
        .accessibilityFocused($focus, equals: .card(actor))
        .accessibilityIdentifier("room.card.\(actor.rawValue)")
    }

    /// "READ-ONLY DEMO NOTES" (y 355), the host announcement (y 391) and icebreaker (y 519), which stay
    /// whatever is blocked, each visible public sample note (y 657), and, once a note's author is
    /// blocked, the line that says blocked sample notes stay hidden (y 677). Nothing can be written.
    private func notesPage(_ run: RoomRun) -> some View {
        let id = run.id
        return VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.notesFraming, color: RoomStyle.secondaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focus, equals: .framing)
                .accessibilityIdentifier("room.notesFraming")
                .padding(.top, 15)
            if run.showsHostNotes {
                RoomHostNote()
                    .padding(.top, 14)
                RoomIcebreaker()
                    .padding(.top, 16)
            }
            ForEach(run.visibleNoteAuthors) { author in
                publicNote(author, id: id)
                    .padding(.top, 16)
            }
            if run.showsHiddenNotesBoundary {
                WristbandBodyText(text: RoomCopy.hiddenNotesBoundary, size: 16, lineHeight: 24,
                                  color: RoomStyle.secondaryText, alignment: .center)
                    .accessibilityIdentifier("room.notes.hiddenBoundary")
                    .padding(.top, 36)
            }
        }
    }

    /// A public sample note (376 × 116, #111415, radius 22) with its "…" safety control (44 × 44,
    /// radius 10, at 316, 5), which opens the author's safety over Room notes.
    private func publicNote(_ author: RoomActor, id: RoomRunID) -> some View {
        RoomPublicNote(author: author)
            .overlay(alignment: .topTrailing) {
                RoomIconButton(pieces: RoomPaths.more) {
                    change(id, animation: dissolveAnimation) { $0.openActorSafety(author) }
                }
                .accessibilityLabel(Text(verbatim: "Safety for \(author.name)'s note"))
                .accessibilityFocused($focus, equals: .noteMore(author))
                .accessibilityIdentifier("room.note.public.\(author.rawValue).more")
                .padding(.top, 5)
                .padding(.trailing, 16)
            }
            .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 22, style: .circular))
    }

    // MARK: - Profiles (66:117, 66:118, 66:121, 66:124)

    /// The fictional profile (376 × 422 at y 292) and its information action (376 × 56 at y 744):
    /// "How Waves work" for a sample of the guest's own intent, "Back to people" for another intent,
    /// with the matching last line on the card. Both come from the run for the actual intent.
    private func profileContent(_ run: RoomRun, actor: RoomActor) -> some View {
        let id = run.id
        let action = run.profileAction(for: actor)
        let hint = action == .howWavesWork
            ? "Information only. Nothing is sent."
            : "Returns to the sample introductions."
        return VStack(alignment: .leading, spacing: 0) {
            RoomProfileCard(actor: actor, boundary: run.profileBoundary(for: actor), focus: $focus)
                .padding(.top, 32)
            Button(action.title) {
                profileAction(action, id: id)
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 56))
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityFocused($focus, equals: .profileAction)
            .accessibilityIdentifier("roomProfile.action")
            .padding(.top, 30)
        }
    }

    private func profileAction(_ action: RoomProfileAction, id: RoomRunID) {
        switch action {
        case .howWavesWork:
            change(id, animation: dissolveAnimation) { $0.openWaveInfo() }
        case .backToPeople:
            change(id, animation: dissolveAnimation) { $0.backToPeople() }
        }
    }

    // MARK: - The bottom bar

    /// The screen's last actions, kept above the home indicator. Entry: Enter room demo (376 × 60 at
    /// y 812) and Back (376 × 44 at y 883). An active run: Leave and disappear (376 × 56 at y 824), with
    /// People's boundary line (y 783) above it. Ended: Return to Places (376 × 60 at y 812).
    private func actionBar(_ room: RoomPreview, screen: RoomScreen, width: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            barLead(room, screen: screen)
            if let run = room.run, run.isActive {
                leaveButton(run.id, height: 56, identifier: "room.leave")
            }
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
        .padding(.top, 13)
        .padding(.bottom, Self.barBottom(screen, inset: bottomInset))
        .background(RoomStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func barLead(_ room: RoomPreview, screen: RoomScreen) -> some View {
        switch screen {
        case .entry:
            VStack(spacing: 11) {
                Button(RoomCopy.enter) {
                    enter()
                }
                .buttonStyle(RoomButtonStyle(kind: .primary, height: 60))
                .accessibilityHint(Text(verbatim: "Starts a new local demo with fictional people. Nothing is shared."))
                .accessibilityIdentifier("roomEntry.enter")
                Button(RoomCopy.entryBack) {
                    withAnimation(dissolveAnimation) {
                        _ = session.leaveRoomEntry()
                    }
                }
                .buttonStyle(RoomButtonStyle(kind: .outline, height: 44))
                .accessibilityHint(Text(verbatim: "Returns to Common Ground's explanation."))
                .accessibilityIdentifier("roomEntry.back")
            }
            .transition(.opacity)
        case .ended:
            Button(RoomCopy.returnToPlaces) {
                withAnimation(dissolveAnimation) {
                    _ = session.returnToPlacesFromRoom()
                }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 60))
            .accessibilityHint(Text(verbatim: "Opens Places at Now. Your choices are kept."))
            .accessibilityIdentifier("roomEnded.returnToPlaces")
            .transition(.opacity)
        case .tabs:
            if let run = room.run, run.tab == .people {
                WristbandBodyText(text: run.peopleBoundary, size: 14, lineHeight: 22,
                                  color: RoomStyle.secondaryText, alignment: .center)
                    .accessibilityIdentifier("room.boundary")
                    .padding(.bottom, 19)
                    .transition(.opacity)
            }
        case .waiting, .profile:
            EmptyView()
        }
    }

    /// The approved gap from the screen's bottom edge to the bar's last control: 29 pt under the
    /// entry's Back (y 927, as on Places), 76 pt under every Leave (y 880) and 84 pt under Return to
    /// Places (y 872). With a home indicator the bar sits that far up; a phone without one keeps Places'
    /// 29 pt, and a very large inset (landscape keyboards and the like) Places' 8.
    private static func barBottom(_ screen: RoomScreen, inset: CGFloat) -> CGFloat {
        let gap: CGFloat
        switch screen {
        case .entry: gap = 29
        case .ended: gap = 84
        case .waiting, .tabs, .profile: gap = 76
        }
        if inset >= 60 { return 8 }
        if inset < 1 { return min(gap, 29) }
        return gap - inset
    }

    /// Leave and disappear: from any level of an active run it ends the run at once, without a question,
    /// with animations disabled, so no sample outlives it on screen or in accessibility.
    private func leaveButton(_ id: RoomRunID, height: CGFloat, identifier: String) -> some View {
        Button(RoomCopy.leave) {
            changeAtOnce(id) { $0.leave() }
        }
        .buttonStyle(RoomButtonStyle(kind: .outline, height: height))
        .accessibilityHint(Text(verbatim: "Ends this demo at once."))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Panels (66:127–66:134)

    /// The open panel, centred over the dimmed screen (the ground at 72 %; tapping the dim does
    /// nothing). It scrolls when taller than the space, so its Leave is always reachable. A different
    /// panel dissolves in; a report reason changes in place.
    private func panelLayer(_ run: RoomRun, panel: RoomRoute, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoomStyle.ground
                .opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
            ScrollView(.vertical) {
                panelCard(run, panel: panel, width: width)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: height)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ground behind the status bar, as on the page: a panel scrolled at large text never
            // runs under the clock (builds 6abc2ae1-6abc3ebe, the largest-text panels at 390 and 440 pt).
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(RoomStyle.ground.ignoresSafeArea(edges: .top))
            }
            .id(Self.panelIdentifier(panel))
            .transition(.opacity)
        }
    }

    /// 376 wide (the column), #111415, radius 28, inset 24; "DEMO PREVIEW" (Bold 14/22, cyan) at 24, 24
    /// and the panel's own content from y 66.
    private func panelCard(_ run: RoomRun, panel: RoomRoute, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.overlayLabel, color: RoomStyle.cyan)
                .accessibilityIdentifier("roomPanel.label")
            panelBody(run, panel: panel)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .frame(width: width, alignment: .leading)
        .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 28, style: .circular))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(Self.panelIdentifier(panel))
    }

    @ViewBuilder
    private func panelBody(_ run: RoomRun, panel: RoomRoute) -> some View {
        switch panel {
        case .globalSafety:
            globalSafety(run.id)
        case .actorSafety(let actor):
            if run.showsSample(actor) {
                actorSafety(actor, id: run.id)
            }
        case .report(let actor, let selected):
            if run.showsSample(actor) {
                report(actor, selected: selected, id: run.id)
            }
        case .waveInfo(let actor):
            if run.showsSample(actor) {
                waveInfo(run.id)
            }
        case .profile:
            EmptyView()
        }
    }

    /// 66:127, 376 × 480: "Your space. / Your choice." (ExtraBold 32/38), the explanation (Regular
    /// 16/26 in 112), Close (328 × 52 at y 321) and Leave (328 × 52 at y 390).
    private func globalSafety(_ id: RoomRunID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle(RoomCopy.safetyTitle, size: 32, lineHeight: 38, box: 82)
            panelText(RoomCopy.safetyExplanation, size: 16, lineHeight: 26, box: 112,
                      color: RoomStyle.secondaryText, identifier: "roomPanel.explanation")
                .padding(.top, 26)
            Button(RoomCopy.close) {
                change(id, animation: dissolveAnimation) { $0.closeLevel() }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityIdentifier("roomPanel.close")
            .padding(.top, 35)
            leaveButton(id, height: 52, identifier: "roomPanel.leave")
                .padding(.top, 17)
        }
        .padding(.top, 20)
        .padding(.bottom, 38)
    }

    /// 66:128–66:131, 376 × 480: "[Name] · safety" (ExtraBold 28/44), the explanation (Regular 16/24
    /// in 80), Block (328 × 52 at y 229), Preview report (48 at y 297), Back (44 at y 359) and Leave
    /// (44 at y 417). Block adds the sample to the run's blocked set at once and shows the filtered
    /// People; Back returns to whichever profile or note opened it.
    private func actorSafety(_ actor: RoomActor, id: RoomRunID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle([RoomCopy.actorSafetyTitle(actor)], size: 28, lineHeight: 44, box: 44)
            panelText(RoomCopy.actorSafetyExplanation, size: 16, lineHeight: 24, box: 80,
                      color: RoomStyle.secondaryText, identifier: "roomPanel.explanation")
                .padding(.top, 21)
            Button(RoomCopy.block(actor)) {
                changeAtOnce(id) { $0.block(actor) }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityHint(Text(verbatim: "Hides this fictional person's card and public notes in this demo."))
            .accessibilityIdentifier("roomPanel.block")
            .padding(.top, 18)
            Button(RoomCopy.previewReport) {
                change(id, animation: dissolveAnimation) { $0.previewReport() }
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 48))
            .accessibilityHint(Text(verbatim: "Opens an unsent example. Nothing is submitted."))
            .accessibilityFocused($focus, equals: .previewReport)
            .accessibilityIdentifier("roomPanel.previewReport")
            .padding(.top, 16)
            Button(RoomCopy.actorSafetyBack) {
                change(id, animation: dissolveAnimation) { $0.closeLevel() }
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 44))
            .accessibilityIdentifier("roomPanel.back")
            .padding(.top, 14)
            leaveButton(id, height: 44, identifier: "roomPanel.leave")
                .padding(.top, 14)
        }
        .padding(.top, 20)
        .padding(.bottom, 19)
    }

    /// 66:132 / 66:133, 376 × 568: "Report [Name]", the explanation (Regular 15/24 in 58), the three
    /// sample reasons (328 × 56 rows, 6 apart, from y 212; none selected at first), Close preview (52 at
    /// y 424) and Leave (48 at y 492). Nothing is submitted, stored or sent; closing discards it.
    private func report(_ actor: RoomActor, selected: RoomReportReason?, id: RoomRunID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle([RoomCopy.reportTitle(actor)], size: 28, lineHeight: 44, box: 44)
            panelText(RoomCopy.reportExplanation, size: 15, lineHeight: 24, box: 58,
                      color: RoomStyle.secondaryText, identifier: "roomPanel.explanation")
                .padding(.top, 18)
            VStack(spacing: 6) {
                ForEach(RoomReportReason.allCases) { reason in
                    reasonRow(reason, selected: selected, id: id)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sample reasons")
            .padding(.top, 26)
            Button(RoomCopy.closePreview) {
                change(id, animation: dissolveAnimation) { $0.closeLevel() }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityHint(Text(verbatim: "Discards this unsent example."))
            .accessibilityIdentifier("roomPanel.closePreview")
            .padding(.top, 32)
            leaveButton(id, height: 48, identifier: "roomPanel.leave")
                .padding(.top, 16)
        }
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    /// A radio-style choice: another reason replaces the selection; the selected one again does
    /// nothing (the run decides). The change dissolves (240 ms).
    private func reasonRow(_ reason: RoomReportReason, selected: RoomReportReason?, id: RoomRunID) -> some View {
        let isSelected = reason == selected
        return Button {
            change(id, animation: dissolveAnimation) { $0.selectReportReason(reason) }
        } label: {
            RoomReasonLabel(title: reason.title, selected: isSelected)
        }
        .buttonStyle(RoomReasonStyle(selected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(verbatim: "Sample reason. Nothing is submitted."))
        .accessibilityIdentifier("room.report.reason.\(reason.rawValue)")
    }

    /// 66:134, 376 × 480: "A Wave is / an invitation." (ExtraBold 32/38), the explanation (Regular
    /// 18/26, white, in 72), the scope line (Regular 14/22 in 52), Back to profile (52 at y 333) and
    /// Leave (52 at y 401). Information only: nothing is sent, created or accepted.
    private func waveInfo(_ id: RoomRunID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle(RoomCopy.waveTitle, size: 32, lineHeight: 38, box: 82)
            panelText(RoomCopy.waveExplanation, size: 18, lineHeight: 26, box: 72,
                      color: .white, identifier: "roomPanel.explanation")
                .padding(.top, 26)
            panelText(RoomCopy.waveScope, size: 14, lineHeight: 22, box: 52,
                      color: RoomStyle.secondaryText, identifier: "roomPanel.scope")
                .padding(.top, 17)
            Button(RoomCopy.backToProfile) {
                change(id, animation: dissolveAnimation) { $0.closeLevel() }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityIdentifier("roomPanel.backToProfile")
            .padding(.top, 18)
            leaveButton(id, height: 52, identifier: "roomPanel.leave")
                .padding(.top, 16)
        }
        .padding(.top, 20)
        .padding(.bottom, 27)
    }

    /// A panel title (from y 66) in its Figma box; VoiceOver lands here when the panel opens.
    private func panelTitle(_ lines: [String], size: CGFloat, lineHeight: CGFloat, box: CGFloat) -> some View {
        RoomHeadline(lines: lines, size: size, lineHeight: lineHeight, box: box, identifier: "roomPanel.title")
            .accessibilityFocused($focus, equals: .panelTitle)
    }

    /// Panel copy in its Figma box (which grows with the text).
    private func panelText(_ text: String, size: CGFloat, lineHeight: CGFloat, box: CGFloat, color: Color,
                           identifier: String) -> some View {
        WristbandBodyText(text: text, size: size, lineHeight: lineHeight, color: color, alignment: .leading)
            .frame(minHeight: box * scale, alignment: .top)
            .accessibilityIdentifier(identifier)
    }

    /// The panel container's identifier, also its identity: a different panel dissolves in, while a
    /// reason selected inside the same report does not replace it.
    private static func panelIdentifier(_ panel: RoomRoute) -> String {
        switch panel {
        case .globalSafety: return "roomPanel.globalSafety"
        case .actorSafety(let actor): return "roomPanel.actorSafety.\(actor.rawValue)"
        case .report(let actor, _): return "roomPanel.report.\(actor.rawValue)"
        case .waveInfo: return "roomPanel.waveInfo"
        case .profile(let actor): return "roomProfile.\(actor.rawValue)"
        }
    }

    // MARK: - Changing the run

    /// 240 ms ease-out; none for VoiceOver.
    private var dissolveAnimation: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: 0.24)
    }

    /// Enter: the 500 ms ease-out move; a 240 ms crossfade under Reduce Motion; none for VoiceOver.
    private var entranceAnimation: Animation? {
        if adaptive.voiceOverRunning { return nil }
        return adaptive.reduceMotion ? .easeOut(duration: 0.24) : .easeOut(duration: 0.5)
    }

    /// One transition, applied only to the run the control was drawn for (a stale control, or a state
    /// that no longer allows it, changes nothing), with what it replaces dissolving.
    private func change(_ id: RoomRunID, animation: Animation?, _ transition: (inout RoomRun) -> Bool) {
        withAnimation(animation) {
            _ = session.updateRoomRun(id, transition)
        }
    }

    /// Block and Leave: the model changes with every animation disabled, so a blocked sample or an ended
    /// run's content never lingers on screen or in accessibility, and wins over any dissolve in flight.
    private func changeAtOnce(_ id: RoomRunID, _ transition: (inout RoomRun) -> Bool) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            _ = session.updateRoomRun(id, transition)
        }
    }

    // MARK: - VoiceOver focus

    /// Moves VoiceOver to `target` once the change is on screen (the new element exists by then).
    private func focusSoon(_ target: RoomFocus?) {
        guard let target else { return }
        Task { @MainActor in
            focus = target
        }
    }

    /// Where VoiceOver starts when the Room appears: the current screen's first element.
    private static func appearTarget(_ room: RoomPreview?) -> RoomFocus? {
        guard let room else { return nil }
        if room.run?.panel != nil { return .panelTitle }
        switch RoomScreen(room) {
        case .entry: return .entryHeadline
        case .waiting: return .waitingHeadline
        case .tabs: return .framing
        case .profile: return .profileName
        case .ended: return .endedStatus
        }
    }

    /// Where VoiceOver goes after a change: into a panel as it opens, back to the control that opened
    /// it as it closes, to the filtered People after Block, to a profile's name, back to the card a
    /// profile was opened from, and to the first element of a new screen. A tab or a report reason keeps
    /// the focus where it is.
    private static func focusTarget(from previous: RoomPreview?, to current: RoomPreview?) -> RoomFocus? {
        guard let current else { return nil }
        guard let run = current.run else {
            return previous == nil ? .entryHeadline : nil
        }
        guard let old = previous?.run, old.id == run.id else { return .waitingHeadline }
        if run.phase != old.phase {
            switch run.phase {
            case .ended: return .endedStatus
            case .populated: return .framing
            case .waiting: return nil
            }
        }
        if let panel = run.panel {
            let before = old.panel.map { Self.panelIdentifier($0) }
            if before == Self.panelIdentifier(panel) { return nil }
            // Close preview returns to the actor's safety, on the control that opened the report.
            if case .report? = old.panel, case .actorSafety = panel { return .previewReport }
            return .panelTitle
        }
        if let closed = old.panel {
            if run.blocked != old.blocked { return .framing }
            switch closed {
            case .globalSafety: return .chromeSafety
            case .actorSafety(let actor): return run.profile == nil ? .noteMore(actor) : .profileSafety
            case .waveInfo: return .profileAction
            case .report, .profile: return .framing
            }
        }
        if run.profile != old.profile {
            if run.profile != nil { return .profileName }
            if let actor = old.profile, run.visiblePeople.contains(actor) { return .card(actor) }
            return .framing
        }
        return nil
    }
}

// MARK: - Screens, scroll targets and focus

/// Which screen the Room shows, derived from the preview each time.
private enum RoomScreen: Hashable {
    case entry
    case waiting
    case tabs
    case profile(RoomActor)
    case ended

    init(_ room: RoomPreview) {
        guard let run = room.run else {
            self = .entry
            return
        }
        switch run.phase {
        case .waiting:
            self = .waiting
        case .ended:
            self = .ended
        case .populated:
            if let actor = run.profile, run.showsSample(actor) {
                self = .profile(actor)
            } else {
                self = .tabs
            }
        }
    }

    var profileActor: RoomActor? {
        if case .profile(let actor) = self { return actor }
        return nil
    }
}

private enum RoomScrollTarget: Hashable {
    case top
}

/// The elements VoiceOver is moved to (see `RoomView.focusTarget`).
private enum RoomFocus: Hashable {
    case entryHeadline
    case waitingHeadline
    case endedStatus
    case chromeSafety
    case profileSafety
    case framing
    case card(RoomActor)
    case profileName
    case profileAction
    case noteMore(RoomActor)
    case panelTitle
    case previewReport
}

// MARK: - The venue ticket

/// The Common Ground ticket: large on the entry (67:140, 376 × 330: the art 220 × 198 centred at the
/// top, the ivory ticket from y 84, radius 26, the name ExtraBold 30/40 at 24, 205) and compact
/// everywhere after it (67:134, 376 × 132, radius 22: the name ExtraBold 23/30 at 20, 19, the art
/// 108 × 110 at 258, 10). One view in both, so Enter moves the same art, name and preference line
/// (SMART_ANIMATE matches them by name) while the session line crossfades. The preference is the
/// guest's actual intent and approach; the art is decoration.
private struct RoomVenueTicket: View {
    let compact: Bool
    let preference: String
    let width: CGFloat
    @ScaledMetric(relativeTo: .title) private var nameScale: CGFloat = 1
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let name = CheckInExplanation.venue.name
        let session = compact ? RoomCopy.compactSession : RoomCopy.entrySession
        let design: CGFloat = compact ? 23 : 30
        let line: CGFloat = compact ? 30 : 40
        let radius: CGFloat = compact ? 22 : 26
        RoomTicketLayout(compact: compact, width: width, stacks: typeSize.isAccessibilitySize) {
            RoundedRectangle(cornerRadius: radius, style: .circular)
                .fill(RoomStyle.ivory)
                .accessibilityHidden(true)
            // Takes its whole slot, so the fitted scene is centred in it (Figma FIT).
            RoomVenueArt()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(name)
                .manrope(.extraBold, size: design * nameScale, designSize: design, lineHeight: line)
                .foregroundStyle(RoomStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.interpolate)
                .accessibilityAddTraits(.isHeader)
            WristbandText(text: session, face: .regular, size: 14, lineHeight: 22, color: RoomStyle.ink)
                .contentTransition(.opacity)
            WristbandText(text: preference, face: .semiBold, size: 14, lineHeight: 22, color: RoomStyle.ink)
                .accessibilityIdentifier(compact ? "room.venue.preference" : "roomEntry.preference")
        }
        .frame(width: width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(name). \(session). \(preference)"))
        .accessibilityIdentifier(compact ? "room.venue" : "roomEntry.venue")
    }
}

/// Places the ticket's five pieces (the ivory, the art, the name, the session line, the preference) in
/// either arrangement, so a change of arrangement moves each piece rather than replacing it. Text is
/// measured at the current size, and the ticket grows with it; the art scales with the column
/// (`k = width / 376`), as on Places.
private struct RoomTicketLayout: Layout {
    let compact: Bool
    let width: CGFloat
    /// Only at the accessibility text sizes may the compact ticket stack its text below the art; at
    /// every other size it keeps the approved arrangement, on any phone width.
    let stacks: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // The ticket is always framed to the column; any other proposal (ideal or unbounded) gets that
        // width too, so no frame is ever infinite.
        let proposed = proposal.width ?? self.width
        let width = proposed.isFinite ? proposed : self.width
        return CGSize(width: width, height: frames(subviews, width: width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = frames(subviews, width: bounds.width)
        for index in placed.frames.indices where index < subviews.count {
            let frame = placed.frames[index]
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  anchor: .topLeading,
                                  proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func height(of subview: LayoutSubview, width: CGFloat) -> CGFloat {
        subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    }

    /// The five frames, in subview order, and the ticket's height.
    private func frames(_ subviews: Subviews, width: CGFloat) -> (frames: [CGRect], height: CGFloat) {
        guard subviews.count == 5 else { return ([], 0) }
        let k = width / 376
        if compact {
            // 67:134: art 108 × 110 at (258, 10); the text column 232 wide at x 20, 6 short of the art;
            // name y 19, session 8 below it, preference 16 below that, 15 above the ticket's end.
            let artWidth = 108 * k
            let artHeight = 110 * k
            let art = CGRect(x: width - 10 * k - artWidth, y: 10, width: artWidth, height: artHeight)
            let side = max(0, art.minX - 6 - 20)
            let full = max(0, width - 40)
            // At the accessibility sizes, when the name needs more lines beside the art than across the
            // ticket (a word as wide as "Common" broke mid-word there: build 6abc1b80, 390 pt, the
            // largest size), the text runs the ticket's full width below the art, which stays in place.
            let stacked = stacks && height(of: subviews[2], width: side) > height(of: subviews[2], width: full) + 1
            let column = stacked ? full : side
            let nameHeight = height(of: subviews[2], width: column)
            let sessionHeight = height(of: subviews[3], width: column)
            let preferenceHeight = height(of: subviews[4], width: column)
            let nameY: CGFloat = stacked ? art.maxY + 8 : 19
            let sessionY = nameY + nameHeight + 8
            let preferenceY = sessionY + sessionHeight + 16
            let total = max(preferenceY + preferenceHeight + 15, art.maxY + 12)
            return ([
                CGRect(x: 0, y: 0, width: width, height: total),
                art,
                CGRect(x: 20, y: nameY, width: column, height: nameHeight),
                CGRect(x: 20, y: sessionY, width: column, height: sessionHeight),
                CGRect(x: 20, y: preferenceY, width: column, height: preferenceHeight),
            ], total)
        }
        // 67:140: art 220 × 198 centred at the top; the ivory ticket from y 84; the text 328 wide at
        // x 24: name 7 below the art, session 11 below the name, preference 15 below that, 15 above
        // the end.
        let artWidth = 220 * k
        let artHeight = 198 * k
        let art = CGRect(x: (width - artWidth) / 2, y: 0, width: artWidth, height: artHeight)
        let column = max(0, width - 48)
        let nameHeight = height(of: subviews[2], width: column)
        let sessionHeight = height(of: subviews[3], width: column)
        let preferenceHeight = height(of: subviews[4], width: column)
        let nameY = art.maxY + 7
        let sessionY = nameY + nameHeight + 11
        let preferenceY = sessionY + sessionHeight + 15
        let total = preferenceY + preferenceHeight + 15
        let ivoryY = 84 * k
        return ([
            CGRect(x: 0, y: ivoryY, width: width, height: total - ivoryY),
            art,
            CGRect(x: 24, y: nameY, width: column, height: nameHeight),
            CGRect(x: 24, y: sessionY, width: column, height: sessionHeight),
            CGRect(x: 24, y: preferenceY, width: column, height: preferenceHeight),
        ], total)
    }
}

/// Common Ground's approved scene (Places' crop [46, 83, 1211, 1218], alpha kept), fitted, never
/// stretched. Decoration: hidden from VoiceOver, since the name says what the place is.
private struct RoomVenueArt: View {
    var body: some View {
        Group {
            if let image = PlacesArt.image(for: .commonGround) {
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

// MARK: - Envelope, notes, cards and profiles

/// The sealed privacy envelope (67:194, 288 × 150): a blank sheet (252 × 132, radius 18) at 16, 4,
/// turned 4° clockwise about its own corner, behind the sealed sheet (288 × 132, radius 20) at y 18
/// with its steel seal (60 × 36, radius 7, #7A8585) at the top edge, "INTRODUCTIONS" (Bold 14/24) and
/// "A little privacy comes first." (Regular 14/22), centred. No actor information of any kind; one
/// element for VoiceOver.
private struct RoomEnvelope: View {
    let identifier: String

    var body: some View {
        VStack(spacing: 0) {
            WristbandText(text: RoomCopy.envelopeLabel, face: .bold, size: 14, lineHeight: 24,
                          color: RoomStyle.ink, alignment: .center)
            WristbandText(text: RoomCopy.envelopePrivacy, face: .regular, size: 14, lineHeight: 22,
                          color: RoomStyle.ink, alignment: .center)
                .padding(.top, 9)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 61)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .circular)
                    .fill(RoomStyle.ivory)
                RoundedRectangle(cornerRadius: 7, style: .circular)
                    .fill(RoomStyle.stroke)
                    .frame(width: 60, height: 36)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .circular)
                .fill(RoomStyle.ivory)
                .rotationEffect(.degrees(4), anchor: .topLeading)
                .padding(.leading, 16)
                .padding(.trailing, 20)
                .offset(y: -14)
        }
        .padding(.top, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Introductions. \(RoomCopy.envelopePrivacy)"))
        .accessibilityIdentifier(identifier)
    }
}

/// The host announcement (67:431, 376 × 112, #111415, radius 22): the label (Bold 14/22, #A8B0AD) at
/// 20, 16 and the note (Medium 17/24, white) at y 51. One element.
private struct RoomHostNote: View {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.hostLabel, color: RoomStyle.secondaryText)
            WristbandText(text: RoomCopy.hostMessage, face: .medium, size: 17, lineHeight: 24, color: .white)
                .frame(maxWidth: .infinity, minHeight: 44 * scale, alignment: .topLeading)
                .padding(.top, 13)
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 22, style: .circular))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(RoomCopy.hostLabel). \(RoomCopy.hostMessage)"))
        .accessibilityIdentifier("room.note.host")
    }
}

/// The host icebreaker (67:434, 376 × 122, #F6F7F2, radius 22): the label (Bold 14/22) at 20, 17 and
/// the question (SemiBold 19/26) at y 53. One element.
private struct RoomIcebreaker: View {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.icebreakerLabel, color: RoomStyle.ink)
            WristbandText(text: RoomCopy.icebreaker, face: .semiBold, size: 19, lineHeight: 26, color: RoomStyle.ink)
                .frame(maxWidth: .infinity, minHeight: 54 * scale, alignment: .topLeading)
                .padding(.top, 14)
        }
        .padding(.top, 17)
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomStyle.ivory, in: RoundedRectangle(cornerRadius: 22, style: .circular))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(RoomCopy.icebreakerLabel). \(RoomCopy.icebreaker)"))
        .accessibilityIdentifier("room.note.icebreaker")
    }
}

/// A public sample note's words (67:437): "[Name] · public sample note" (SemiBold 14/24, white, 268
/// wide at 20, 15, clear of the "…" control) and the note (Regular 16/23, #A8B0AD) at y 52. One element;
/// the control beside it is its own button.
private struct RoomPublicNote: View {
    let author: RoomActor
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let message = author.publicNote ?? ""
        VStack(alignment: .leading, spacing: 0) {
            WristbandText(text: author.publicNoteLabel, face: .semiBold, size: 14, lineHeight: 24, color: .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 68)
            WristbandBodyText(text: message, size: 16, lineHeight: 23, color: RoomStyle.secondaryText,
                              alignment: .leading)
                .frame(minHeight: 48 * scale, alignment: .top)
                .padding(.top, 13)
        }
        .padding(.top, 15)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(author.publicNoteLabel). \(message)"))
        .accessibilityIdentifier("room.note.public.\(author.rawValue)")
    }
}

/// The filtered empty state (67:613, 376 × 236, #111415, radius 24): "No sample introductions / to
/// show." (ExtraBold 28/36 in 80, at 24, 38) and "Your demo blocks are still applied." (Regular 16/24,
/// #A8B0AD, in 52, at y 146). It says nothing about the venue or who is there.
private struct RoomEmptyCard: View {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    /// "No sample introductions" (339.6 pt at ExtraBold 28) is wider than the title's 328-pt box, so
    /// Figma draws the approved frame in three 36-pt lines ("No sample" / "introductions" / "to show."),
    /// 108 tall, running past its nominal 80 to the explanation at y 146 (card 236). The same lines here;
    /// VoiceOver reads the approved copy as one sentence.
    private static let titleLines: [String] = {
        guard let first = RoomCopy.emptyTitle.first, let split = first.range(of: " introductions") else {
            return RoomCopy.emptyTitle
        }
        return [String(first[..<split.lowerBound]), "introductions"] + RoomCopy.emptyTitle.dropFirst()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomHeadline(lines: Self.titleLines, size: 28, lineHeight: 36, box: 108, identifier: "room.empty.title")
            WristbandBodyText(text: RoomCopy.emptyExplanation, size: 16, lineHeight: 24,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .frame(minHeight: 52 * scale, alignment: .top)
                .accessibilityIdentifier("room.empty.explanation")
        }
        .padding(.top, 38)
        .padding(.horizontal, 24)
        .padding(.bottom, 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 24, style: .circular))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room.empty")
    }
}

/// A sample introduction (67:146 / 67:170, 376 × 170, #F6F7F2, radius 22): the initials disc (60 at
/// 20, 20), the name (ExtraBold 25/30 at 100, 20), the sample's own intent and approach (Medium 14/20
/// in 42 at y 57), the introduction (Regular 16/22 at 20, 101) and "View card  →" (SemiBold 14/22,
/// right-aligned, ending 20 in, at y 142). The card grows with its text; the introduction's box ends
/// where "View card" starts, so a second line pushes it down instead of overlapping it.
private struct RoomSampleCard: View {
    let actor: RoomActor
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                RoomInitialsDisc(actor: actor, diameter: 60)
                VStack(alignment: .leading, spacing: 0) {
                    RoomTitleText(text: actor.name, size: 25, lineHeight: 30, color: RoomStyle.ink)
                    WristbandText(text: actor.line, face: .medium, size: 14, lineHeight: 20, color: RoomStyle.ink)
                        .frame(maxWidth: .infinity, minHeight: 42 * scale, alignment: .topLeading)
                        .padding(.top, 7)
                }
            }
            WristbandText(text: actor.introduction, face: .regular, size: 16, lineHeight: 22, color: RoomStyle.ink)
                .frame(maxWidth: .infinity, minHeight: 41 * scale, alignment: .topLeading)
                .padding(.top, 2)
            WristbandText(text: RoomCopy.viewCard, face: .semiBold, size: 14, lineHeight: 22,
                          color: RoomStyle.ink, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomStyle.ivory, in: RoundedRectangle(cornerRadius: 22, style: .circular))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .circular))
    }
}

/// A fictional profile (67:154 / 67:178, 376 × 422, #F6F7F2, radius 24): "FICTIONAL PROFILE" (Bold
/// 14/22 at 24, 22), the initials disc (82 at 24, 68), the name (ExtraBold 34/40 at 128, 80), the
/// sample's intent and approach (SemiBold 14/21 in 44 at y 126), About (Regular 18/24 in 96 at y 191),
/// the interests (y 296) and the last line (Medium 14/22 in 46 at y 351): the sample's approach for the
/// guest's own intent, otherwise that Waves stay within the selected intent. The card grows with its
/// text.
private struct RoomProfileCard: View {
    let actor: RoomActor
    let boundary: String
    let focus: AccessibilityFocusState<RoomFocus?>.Binding
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: RoomCopy.profileLabel, color: RoomStyle.ink)
                .accessibilityIdentifier("roomProfile.label")
            header
                .padding(.top, 24)
            RoomAbout(text: actor.about)
                .frame(minHeight: 96 * scale, alignment: .topLeading)
                .accessibilityIdentifier("roomProfile.about")
                .padding(.top, 21)
            RoomInterestChips(interests: actor.interests)
                .padding(.top, 9)
            WristbandText(text: boundary, face: .medium, size: 14, lineHeight: 22, color: RoomStyle.ink)
                .frame(maxWidth: .infinity, minHeight: 46 * scale, alignment: .topLeading)
                .accessibilityIdentifier("roomProfile.boundary")
                .padding(.top, 27)
        }
        .padding(.top, 22)
        .padding(.horizontal, 24)
        .padding(.bottom, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomStyle.ivory, in: RoundedRectangle(cornerRadius: 24, style: .circular))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roomProfile.card")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 22) {
            RoomInitialsDisc(actor: actor, diameter: 82)
            VStack(alignment: .leading, spacing: 0) {
                RoomTitleText(text: actor.name, size: 34, lineHeight: 40, color: RoomStyle.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(focus, equals: .profileName)
                    .accessibilityIdentifier("roomProfile.name")
                    .padding(.top, 12)
                WristbandText(text: actor.line, face: .semiBold, size: 14, lineHeight: 21, color: RoomStyle.ink)
                    .frame(maxWidth: .infinity, minHeight: 44 * scale, alignment: .topLeading)
                    .accessibilityIdentifier("roomProfile.line")
                    .padding(.top, 6)
            }
        }
    }
}

/// About: two sentences on their approved line break, each on the 24-pt line (tighter than the face's
/// natural 24.6, so each sentence gets its own line box rather than one `lineSpacing`). One element.
private struct RoomAbout: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let lines = text.split(separator: "\n").map(String.init)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .manrope(.regular, size: 18 * scale, designSize: 18, lineHeight: 24)
                    .foregroundStyle(RoomStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: lines.joined(separator: " ")))
    }
}

/// The interests: #050606 chips, 28 tall (radius 14), with #F6F7F2 Medium 14/28 labels at their Figma
/// widths, 8 apart. At larger text they stack. One element: "Interests: A, B, C".
private struct RoomInterestChips: View {
    let interests: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    RoomInterestChip(title: interest)
                }
            }
            // Stacked (larger text): each chip hugs its label and never asks for more than the card's
            // width, so a long interest wraps inside its chip instead of pushing past the card.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    RoomInterestChip(title: interest, usesFigmaWidth: false)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Interests: \(interests.joined(separator: ", "))"))
        .accessibilityIdentifier("roomProfile.interests")
    }
}

private struct RoomInterestChip: View {
    let title: String
    var usesFigmaWidth = true
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 14

    /// The approved chip widths (67:163–67:167, 67:187–67:191).
    private var figmaWidth: CGFloat {
        switch title {
        case "Coffee", "Design": return 68
        case "Bookshops": return 100
        case "Detours": return 76
        case "Ideas": return 60
        case "Small business": return 118
        default: return 0
        }
    }

    var body: some View {
        Text(title)
            .manrope(.medium, size: size, designSize: 14, lineHeight: 28)
            .foregroundStyle(RoomStyle.ivory)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .frame(minWidth: usesFigmaWidth ? figmaWidth * size / 14 : nil, minHeight: 28)
            .background(RoomStyle.ink, in: Capsule())
    }
}

/// Fictional initials on a #E0E0D9 disc inside a 2-pt ring of the sample's own intent colour (the
/// word beside it says the same thing). Decoration: the name is read instead.
private struct RoomInitialsDisc: View {
    let actor: RoomActor
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RoomStyle.initialsDisc)
            Circle()
                .strokeBorder(WristbandStyle.color(for: actor.intent), lineWidth: 2)
            // ExtraBold 18.6 on the 60-pt disc, 25.42 on the 82-pt one: 0.31 of the diameter.
            Text(actor.initials)
                .font(Manrope.extraBold.font(size: diameter * 0.31))
                .foregroundStyle(RoomStyle.ink)
                .lineLimit(1)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - Text

/// A headline or title on its approved line breaks (ExtraBold; 48/56 at −4 %, 34/40, 32/38, 28/44,
/// 28/36), each line on its own line box because every one of these is tighter than the face's natural
/// line; at larger text a line wraps between its words rather than shrinking. `box` is the Figma text
/// box, kept as a minimum height. One header element.
private struct RoomHeadline: View {
    let lines: [String]
    let size: CGFloat
    let lineHeight: CGFloat
    var tracking: CGFloat = 0
    var box: CGFloat = 0
    let identifier: String
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .manrope(.extraBold, size: size * scale, designSize: size, lineHeight: lineHeight,
                             tracking: tracking)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: lines.joined(separator: " ")))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(identifier)
        .frame(minHeight: box * scale, alignment: .topLeading)
    }
}

/// A name (ExtraBold 25/30 or 34/40), following Dynamic Type like a title and wrapping.
private struct RoomTitleText: View {
    let text: String
    let size: CGFloat
    let lineHeight: CGFloat
    let color: Color
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .manrope(.extraBold, size: size * scale, designSize: size, lineHeight: lineHeight)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An upper-case label: Bold 14/22 (framing lines, DEMO CONTROL, DEMO PREVIEW, DEMO SESSION ENDED,
/// FICTIONAL PROFILE, the note labels).
private struct RoomLabel: View {
    let text: String
    let color: Color
    var alignment: TextAlignment = .leading

    var body: some View {
        WristbandText(text: text, face: .bold, size: 14, lineHeight: 22, color: color, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

/// The chrome's "Proximeet" or "Room": Bold 22 on the 38-pt line, centred on the 44-pt row; at the
/// largest sizes it steps down rather than crowd the badge.
private struct RoomChromeTitle: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            RoomChromeTitleText(text: text)
            RoomChromeTitleText(text: text).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            RoomChromeTitleText(text: text).dynamicTypeSize(...DynamicTypeSize.large)
        }
    }
}

private struct RoomChromeTitleText: View {
    let text: String
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manrope(.bold, size: size, designSize: 22, lineHeight: 38)
            .foregroundStyle(.white)
    }
}

/// The Room's DEMO label (67:113): 72 × 28, radius 9, a 0.6-pt cyan outline inside, "DEMO" Bold 11/28
/// in cyan, centred. One element: "Demo".
private struct RoomDemoBadge: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 11

    var body: some View {
        Text("DEMO")
            .lineLimit(1)
            .manrope(.bold, size: size, designSize: 11, lineHeight: 28)
            .fixedSize()
            .foregroundStyle(RoomStyle.cyan)
            .padding(.horizontal, 8)
            .frame(minWidth: 72, minHeight: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .circular)
                    .strokeBorder(RoomStyle.cyan, lineWidth: 0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Demo"))
            .accessibilityIdentifier("room.demoBadge")
    }
}

// MARK: - Controls

/// The Room's buttons, radius 18, SemiBold 16 centred. Primary (Enter room demo, Show populated example,
/// the profile action, Return to Places, Close, Block, Close preview, Back to profile): #F6F7F2 with
/// #050606. Outline (Leave, the entry's Back, Preview report, the actor's Back): no fill, a 1-pt
/// #7A8585 border inside, white. `height` is the approved height (60, 56, 52, 48 or 44); a label that
/// needs more at larger text grows the button.
private struct RoomButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case outline
    }

    let kind: Kind
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        RoomButtonBody(configuration: configuration, primary: kind == .primary, height: height)
    }
}

private struct RoomButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    let height: CGFloat
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        let fill: Color = primary ? RoomStyle.ivory : Color.clear
        let border: Color = primary ? Color.clear : RoomStyle.stroke
        let text: Color = primary ? RoomStyle.ink : Color.white
        let pressed: Double = primary ? 0.88 : 0.6
        configuration.label
            .manrope(.semiBold, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: 1)
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? pressed : 1)
    }
}

/// A card or an icon: its own look, dimmed while pressed.
private struct RoomPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A 44 × 44 icon button (radius 12 or 10, no fill) with its 24-pt glyph centred; the glyph grows with
/// the text up to 1.5×, the target never below 44.
private struct RoomIconButton: View {
    let pieces: [WristbandPaths.Piece]
    let action: @MainActor () -> Void
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let glyph = 24 * min(scale, 1.5)
        Button(action: action) {
            RoomGlyph(pieces: pieces)
                .frame(width: glyph, height: glyph)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(RoomPressStyle())
    }
}

/// People / Room notes tab label: SemiBold 15/44.
private struct RoomTabLabel: View {
    let title: String
    let selected: Bool
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 15

    var body: some View {
        Text(title)
            .lineLimit(1)
            .manrope(.semiBold, size: size, designSize: 15, lineHeight: 44)
            .foregroundStyle(selected ? RoomStyle.ink : RoomStyle.secondaryText)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

private struct RoomTabStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        return configuration.label
            .background(selected ? RoomStyle.ivory : Color.clear, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed && !selected ? 0.7 : 1)
    }
}

/// A sample reason row's content (328 × 56): the reason (Medium 14/20, white, 272 wide at x 16) and the
/// 16-pt radio at x 296. The label is centred on the radio's line rather than top-aligned in its
/// two-line Figma box, so a one-line reason sits level with its radio.
private struct RoomReasonLabel: View {
    let title: String
    let selected: Bool
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let radio = 16 * min(scale, 1.5)
        HStack(alignment: .center, spacing: 8) {
            WristbandText(text: title, face: .medium, size: 14, lineHeight: 20, color: .white)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoomRadio(selected: selected)
                .frame(width: radio, height: radio)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }
}

/// Unselected: #111415 (the panel's own colour, as approved). Selected: #242A2B with a 1-pt #7A8585
/// border inside. Radius 14.
private struct RoomReasonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        return configuration.label
            .background(selected ? RoomStyle.selectedPanel : RoomStyle.panel, in: shape)
            .overlay {
                shape.strokeBorder(selected ? RoomStyle.stroke : Color.clear, lineWidth: 1)
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The 16-pt report radio (67:819 / 67:829): a 1-pt #A8B0AD ring inside, filled #F6F7F2 when selected.
private struct RoomRadio: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? RoomStyle.ivory : Color.clear)
            Circle()
                .strokeBorder(RoomStyle.secondaryText, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Stroked vector pieces in a 24-pt frame, scaled to the frame: #F3F2EF, 1.7 pt, round caps and joins.
private struct RoomGlyph: View {
    let pieces: [WristbandPaths.Piece]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            for piece in pieces {
                let path = FigmaPath.make(piece.data).applying(
                    CGAffineTransform(translationX: piece.x, y: piece.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
                )
                context.stroke(path, with: .color(RoomStyle.glyph),
                               style: StrokeStyle(lineWidth: 1.7 * scale, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Style and vectors

/// The Room's colours: the live tokens of the approved chapters, plus the initials disc.
enum RoomStyle {
    static let ground = WristbandStyle.ground
    /// Ink on ivory paper (the same #050606 as the ground).
    static let ink = WristbandStyle.ground
    static let ivory = WristbandStyle.primary
    static let secondaryText = WristbandStyle.secondaryText
    static let cyan = WristbandStyle.cyan
    /// #111415: the tab track, the dark notes, the empty card, the panels and unselected reasons.
    static let panel = WristbandStyle.tile
    /// #242A2B: a selected reason.
    static let selectedPanel = WristbandStyle.selectedTile
    /// #7A8585: outline borders, the selected reason's border and the envelope's steel seal.
    static let stroke = SignalStyle.selectedStroke
    /// #F3F2EF: the shield, chevron and "…" glyphs.
    static let glyph = SignalStyle.rowSymbol
    /// #E0E0D9: the fictional initials' disc.
    static let initialsDisc = Color(hex: 0xE0E0D9)
}

/// The approved glyphs, verbatim from `LAYOUT_SPEC.json`, with each vector's offset in its 24-pt frame.
private enum RoomPaths {
    typealias Piece = WristbandPaths.Piece

    /// The Safety shield and its tick (67:117, 67:118).
    static let shield: [Piece] = [
        Piece(x: 4, y: 3, data: "M 8 0 L 16 3 L 16 8 C 16 13 8 18 8 18 C 8 18 0 13 0 8 L 0 3 L 8 0 Z"),
        Piece(x: 9, y: 10, data: "M 0 2 L 2 4 L 6 0"),
    ]

    /// The profile's Back chevron (67:122).
    static let chevron: [Piece] = [
        Piece(x: 8, y: 6, data: "M 6 0 L 0 6 L 6 12"),
    ]

    /// The note's "…" (67:441–67:443): three 2-pt circles, stroked.
    static let more: [Piece] = [
        Piece(x: 4, y: 11, data: dot),
        Piece(x: 11, y: 11, data: dot),
        Piece(x: 18, y: 11, data: dot),
    ]

    private static let dot = "M 2 1 C 2 1.5522847771644592 1.5522847771644592 2 1 2 C 0.44771522283554077 2 0 1.5522847771644592 0 1 C 0 0.44771522283554077 0.44771522283554077 0 1 0 C 1.5522847771644592 0 2 0.44771522283554077 2 1 Z"
}

#if DEBUG
#Preview("Room · entry, Business") {
    NavigationStack { PlacesView() }
        .environment(DebugLaunch.session(arguments: ["-ProximeetFixture", "room-entry", "-ProximeetFixtureBand",
                                                     "business", "-ProximeetFixtureSignal", "okayToSayHello"])
                     ?? DemoSession())
}

#Preview("Room · People, Social") {
    NavigationStack { PlacesView() }
        .environment(DebugLaunch.session(arguments: ["-ProximeetFixture", "room-populated", "-ProximeetFixtureBand",
                                                     "social", "-ProximeetFixtureSignal", "chatFirst"])
                     ?? DemoSession())
}
#endif
