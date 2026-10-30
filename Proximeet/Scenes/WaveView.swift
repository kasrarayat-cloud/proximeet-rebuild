import SwiftUI
import ProximeetDomain

/// Chapter 09 — the Wave state machine and safety flow originated in the handoff (`LAYOUT_SPEC.json`, Figma page 74:567, review board 76:387: the
/// twelve screens 74:568–74:579, the seven overlays 74:580–74:586 and the report-reason variants
/// 75:627–75:657). The approved 29 October private-invitation design replaces the common rings with
/// category-specific native artwork, a compact intent badge, invitation copy and coloured primary actions.
///
/// Shown by `RoomView`, in place of the Room's page and panels, while the shown run has a Wave: from
/// "Preview Wave demo" on an eligible same-intent profile until the menu closes back to the still-valid
/// Room (by the menu's visible Back, the existing 75:119 Back pattern, used to meet the founder's decision
/// of 30 September 2026, or the same outer Back: a swipe or VoiceOver's escape), and after a Leave made from
/// inside it
/// (so the Wave's own ended screen 74:578 shows, not the Room's 66:114). Closing keeps the run's
/// identity, phase, blocks and closed invitations.
///
/// Everything on screen is derived from the `RoomRun` and its `WaveDemo` it is given: the screen, the
/// overlay stack, the invitation's status, the counterpart and the viewer's actual Guest List name. This
/// view keeps no copy of any of them. Every control goes through the session to the run it was drawn for
/// (`performWave(run.id, …)`, and the menu's Back `closeWaveDemo(run.id)`) and carries what it was drawn
/// for — the invitation's identity, the screen, the overlay, or Block's actor — so a late, repeated or
/// stale tap changes nothing. A blocked counterpart and every closed or ended invitation are absent from
/// the view tree, not hidden; once blocked, the menu's three choices stay, disabled, beside one generic
/// line that names nobody.
///
/// Motion follows the prototype: every navigation, overlay and reason change is a 240 ms ease-out
/// dissolve (the Figma CLOSE actions carry no transition, so Close follows the Room's own 240 ms
/// precedent); Accept updates the artwork in one 800 ms ease-out transition: cards, bubbles and rings
/// move together, while the Activity route brightens. The invitation's changed words crossfade in place. Reduce Motion
/// turns the join into a 240 ms crossfade to the accepted artwork with the same text; VoiceOver gets no
/// animation. The model always changes first; Block and Leave change it with animations disabled, so
/// they win over a join in flight and nothing they close lingers. Nothing here reads a clock, runs a
/// timer, stores, sends or logs anything; the one deferred step is moving VoiceOver focus on the next
/// main-actor turn (`focusSoon`).
struct WaveView: View {
    let run: RoomRun
    let wave: WaveDemo
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @AccessibilityFocusState private var focus: WaveFocus?
    /// The bar's last measured height, so the spacer that stands in for it under an overlay keeps the
    /// page exactly where it was (the Room's lesson from builds 6abc1b80 and 6abc2ae1).
    @State private var barHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = min(376, max(0, proxy.size.width - 64))
            layers(width: width, proxy: proxy)
        }
        .onAppear {
            focusSoon(Self.appearTarget(wave))
        }
        .onChange(of: wave) { previous, current in
            focusSoon(Self.focusTarget(from: previous, to: current))
        }
        // The screen's container, present with or without an overlay above it. VoiceOver's escape keeps
        // its single owner, `RoomView`'s root, which routes it through the run's Wave-aware outer Back.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wave.screen.\(wave.screen.rawValue)")
    }

    // MARK: - Layers

    /// The screen, and above it the top overlay (if any) over the dimmed screen. While an overlay is
    /// open the screen takes no touches and is hidden from accessibility, and its bar is not built at all
    /// (see `page`); the overlay is modal.
    private func layers(width: CGFloat, proxy: GeometryProxy) -> some View {
        let overlay = wave.overlay
        return ZStack {
            page(width: width, bottomInset: proxy.safeAreaInsets.bottom, covered: overlay != nil)
                // Give modal hiding its own container; the page's children keep their individual
                // accessibility properties, including the decorative artwork's hidden state.
                .accessibilityElement(children: .contain)
                .accessibilityHidden(overlay != nil)
                .allowsHitTesting(overlay == nil)
            if let overlay {
                panelLayer(overlay, width: width, height: proxy.size.height)
                    .transition(.opacity)
            }
        }
    }

    /// The chrome and the screen's content scroll; Leave (or, once ended, Return to Places) stays in a bar
    /// above the home indicator, as on the Room, so it is never covered or scrolled away at any text size.
    private func page(width: CGFloat, bottomInset: CGFloat, covered: Bool) -> some View {
        let screen = wave.screen
        return ScrollViewReader { reader in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    chrome(screen)
                        .id(WaveScrollTarget.top)
                    column(screen, width: width)
                        .frame(width: width, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, Self.contentBottom(screen))
                .accessibilityElement(children: .contain)
                .accessibilityHidden(covered)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ground behind the status bar, so scrolled text never runs under the clock.
            .safeAreaInset(edge: .top, spacing: 0) {
                groundStrip
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if covered {
                    // Under an overlay the bar is not built at all: Room builds 6abc1b80 and 6abc2ae1 found
                    // its Leave still in the accessibility tree with `accessibilityHidden` on the page and
                    // on the bar. An empty spacer of the bar's height keeps the dimmed page still.
                    Color.clear
                        .frame(height: barHeight)
                } else {
                    actionBar(screen, width: width, bottomInset: bottomInset)
                        .background {
                            GeometryReader { bar in
                                Color.clear
                                    .onAppear { barHeight = bar.size.height }
                                    .onChange(of: bar.size.height) { _, height in barHeight = height }
                            }
                        }
                }
            }
            // A new screen starts at its beginning (Accept's reaction sets `resetScrollPosition`), at once:
            // the dissolve, or the ring join, is the motion. Explicitly unanimated, as the Room's `reveal`
            // does: work done in `onChange` inherits the transaction of the change that triggered it, so a
            // bare `scrollTo` would glide for 800 ms under Accept, or 240 ms under Reduce Motion's crossfade.
            .onChange(of: screen) {
                withAnimation(nil) {
                    reader.scrollTo(WaveScrollTarget.top, anchor: .top)
                }
            }
        }
    }

    /// Everything below the chrome, 376 wide on the reference phone (x 32…408). The four active
    /// invitation screens share one subtree, so Send, Accept and the rest change only what differs (and
    /// the rings keep their identities for the join); every other change of screen dissolves the whole
    /// column.
    private func column(_ screen: WaveScreen, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            stage(screen, width: width)
                .id(Self.stageKey(screen))
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func stage(_ screen: WaveScreen, width: CGFloat) -> some View {
        if screen == .menu {
            menuContent(width: width)
        } else if screen.showsCounterpart, let invitation = wave.invitation {
            invitationContent(screen, invitation: invitation, width: width)
        } else {
            closedContent(screen, width: width)
        }
    }

    private static func stageKey(_ screen: WaveScreen) -> String {
        screen.showsCounterpart ? "invitation" : screen.rawValue
    }

    // MARK: - Chrome (75:111, 75:119, 75:130)

    /// The persistent demo chrome (392 × 44 at 24, 64), the Room's own: the brand at x 8, the DEMO badge
    /// at x 260 and the Safety shield at x 348. The unsent confirmation and, by the founder's integration
    /// decision of 30 September 2026, the menu use 75:119 instead: the Back chevron and the title "Wave"
    /// at x 60 (on the menu Back returns to the Room; on the confirmation it discards the unsent example).
    /// The ended screen (75:130) keeps the badge in place and leaves the shield's slot empty.
    private func chrome(_ screen: WaveScreen) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // One branch for both Backs, so going from the menu to the confirmation keeps the chevron
                // and "Wave" in place (only what Back does changes) rather than crossfading two copies.
                if let back = backControl(screen) {
                    backLeading(back)
                        .transition(.opacity)
                } else {
                    WaveChromeTitle(text: screen.showsCounterpart ? WaveCopy.composeBrand : WaveCopy.brand)
                        .accessibilityIdentifier("wave.brand")
                        .padding(.leading, 8)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 8)
            WaveDemoBadge()
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            ZStack {
                safetyButton(screen)
            }
            .frame(width: 44, height: 44)
            .padding(.leading, 8)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }

    /// What the 75:119 Back does on `screen`, or nil where the chrome has no Back. The menu's Back returns
    /// to the still-valid Room that opened the Wave, with its state and blocks kept (the run refuses it
    /// from a stale run or with anything open); the confirmation's discards the unsent invitation (its
    /// identity is never reused) and shows the menu. Nothing is sent either way.
    private func backControl(_ screen: WaveScreen) -> WaveBackControl? {
        guard screen.chrome == .back else { return nil }
        let id = run.id
        if screen == .menu {
            return WaveBackControl(hint: WaveCopy.menuBackHint) {
                withAnimation(dissolveAnimation) {
                    _ = session.closeWaveDemo(id)
                }
            }
        }
        guard let invitation = wave.invitation else { return nil }
        let invitationID = invitation.id
        return WaveBackControl(hint: "Returns to the demo menu. This unsent example is discarded.") {
            perform(.discardCompose(invitationID), animation: dissolveAnimation)
        }
    }

    /// The 75:119 leading pair: Back (44 × 44, the chevron of 75:122) and "Wave", 16 apart, shared by the
    /// menu and the unsent confirmation.
    private func backLeading(_ back: WaveBackControl) -> some View {
        HStack(spacing: 10) {
            RoomIconButton(pieces: RoomPaths.chevron, action: back.action)
                .accessibilityLabel("Back")
                .accessibilityHint(Text(verbatim: back.hint))
                .accessibilityIdentifier("wave.back")
            // Spec order: Back → "Wave" (header) → DEMO → Safety, as the Room profile's chrome.
            WaveChromeTitle(text: WaveCopy.composeBrand)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("wave.brand")
        }
    }

    /// The shield (…;75:115 / 75:126): the counterpart's safety (74:581) over an active invitation, the
    /// general safety (74:580) over the menu and the closed screens, none once ended. The run decides
    /// which from the screen the shield was drawn on.
    @ViewBuilder
    private func safetyButton(_ screen: WaveScreen) -> some View {
        if let kind = screen.safety {
            RoomIconButton(pieces: RoomPaths.shield) {
                perform(.openSafety(from: screen), animation: dissolveAnimation)
            }
            .accessibilityLabel("Safety")
            .accessibilityHint(Text(verbatim: safetyHint(kind)))
            .accessibilityFocused($focus, equals: .chromeSafety)
            .accessibilityIdentifier("wave.safety")
            .transition(.opacity)
        }
    }

    private func safetyHint(_ kind: WaveOverlay) -> String {
        if kind == .counterpartSafety, let counterpart = wave.visibleCounterpart {
            return "Opens the safety options for \(counterpart.name)."
        }
        return "Opens the safety options of this demo."
    }

    // MARK: - Menu (74:568)

    /// "Every hello / needs a choice." (ExtraBold 48/56, −4 %, at y 148), the role line (Regular 17/26 at
    /// y 279) with the actual Guest List name, the bare separate rings (75:287, y 345), the boundary
    /// (Regular 16/24, centred, in 52 at y 496) and the three explicit choices: Start outgoing (60 at
    /// y 580), Start incoming (60 at y 654) and Show no-allowance (outline 52 at y 730). The menu alone
    /// starts nothing; each start is re-checked by the run when it arrives.
    ///
    /// Once the counterpart is blocked (founder decision, 30 September 2026), the three choices keep their
    /// own labels and are disabled, and the boundary's slot holds one generic explanation instead
    /// (`WaveCopy.menuBlocked`, same type and box). Nothing on the menu names the counterpart, blocked or not.
    private func menuContent(width: CGFloat) -> some View {
        let blocked = run.waveCounterpartBlocked
        return VStack(alignment: .leading, spacing: 0) {
            RoomHeadline(lines: WaveCopy.menuHeadline, size: 48, lineHeight: 56, tracking: -1.92, box: 112,
                         identifier: "wave.menu.headline")
                .accessibilityFocused($focus, equals: .menuHeadline)
                .padding(.top, 40)
            WristbandBodyText(text: WaveCopy.roleExplanation(viewer: wave.viewerName), size: 17, lineHeight: 26,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .accessibilityIdentifier("wave.menu.role")
                .padding(.top, 19)
            PrivateInvitationIntentBadge(intent: wave.intent)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            PrivateInvitationArtwork(intent: wave.intent, accepted: false, width: width)
                .padding(.top, 12)
            // #A8B0AD on the ground either way (the boundary's own colour, well above AA).
            WristbandBodyText(text: blocked ? WaveCopy.menuBlocked : WaveCopy.menuBoundary, size: 16,
                              lineHeight: 24, color: RoomStyle.secondaryText, alignment: .center)
                .frame(minHeight: 52 * scale, alignment: .top)
                .accessibilityIdentifier(blocked ? "wave.menu.blocked" : "wave.menu.boundary")
                .padding(.top, 23)
            menuChoices(blocked: blocked)
                .padding(.top, 32)
        }
    }

    /// The three explicit choices. Blocked, each is disabled (drawn in the other screens' approved disabled
    /// fill and label colours; the disabled outline has no approved reference, `WaveChoiceStyle`) and
    /// VoiceOver hears "Unavailable. Connection blocked." after its own label; the
    /// run refuses a start that arrives anyway.
    private func menuChoices(blocked: Bool) -> some View {
        VStack(spacing: 0) {
            Button(WaveCopy.startOutgoing) {
                perform(.startOutgoing, animation: dissolveAnimation)
            }
            .buttonStyle(WaveChoiceStyle(kind: .primary, height: 60))
            .disabled(blocked)
            .accessibilityHint(Text(verbatim: blocked ? WaveCopy.startBlockedHint
                                    : "Starts a new fictional outgoing example. Nothing is sent to anyone."))
            .accessibilityIdentifier("wave.menu.startOutgoing")
            Button(WaveCopy.startIncoming) {
                perform(.startIncoming, animation: dissolveAnimation)
            }
            .buttonStyle(WaveChoiceStyle(kind: .primary, height: 60))
            .disabled(blocked)
            .accessibilityHint(Text(verbatim: blocked ? WaveCopy.startBlockedHint
                                    : "Starts a new fictional incoming example. Nothing is sent to anyone."))
            .accessibilityIdentifier("wave.menu.startIncoming")
            .padding(.top, 14)
            Button(WaveCopy.showNoAllowance) {
                perform(.showNoAllowance, animation: dissolveAnimation)
            }
            .buttonStyle(WaveChoiceStyle(kind: .outline, height: 52))
            .disabled(blocked)
            .accessibilityHint(Text(verbatim: blocked ? WaveCopy.startBlockedHint
                                    : "Demo condition. Shows an example without a Wave allowance."))
            .accessibilityIdentifier("wave.menu.noAllowance")
            .padding(.top, 16)
        }
    }

    // MARK: - Active invitations (74:569, 74:570, 74:572, 74:574)

    /// Category, fictional venue context, decorative objects and the readable invitation form one
    /// scrolling column. Consent and demo disclosure precede the state's own action; Leave stays fixed.
    private func invitationContent(_ screen: WaveScreen, invitation: WaveInvitation, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WaveVenueTicket(venue: wave.venue.name, preference: viewerPreference, intent: wave.intent, width: width)
                .padding(.top, 12)
            stateRow(screen, invitation: invitation)
                .padding(.top, 8)
            invitationCard(screen, invitation: invitation, width: width)
                .padding(.top, 2)
            if screen == .outgoingConfirm {
                WristbandBodyText(text: WaveCopy.recipientChoice(counterpart: wave.counterpart), size: 14,
                                  lineHeight: 22, color: RoomStyle.secondaryText, alignment: .center)
                    .accessibilityIdentifier("wave.invitation.consent")
                    .padding(.top, 10)
            }
            WristbandBodyText(text: WaveCopy.boundary(screen) ?? "", size: 14, lineHeight: 22,
                              color: RoomStyle.secondaryText, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("wave.boundary")
                .padding(.top, screen == .outgoingConfirm ? 4 : 10)
            // Each screen's actions replace the last ones in place: Accept and Decline fade out where they
            // were while About private chat fades in at y 744, as the prototype's Smart Animate does
            // (those layers are unmatched), rather than sliding.
            ZStack(alignment: .top) {
                invitationActions(screen, invitation: invitation)
                    .id(screen)
                    .transition(.opacity)
            }
            .padding(.top, 4)
        }
    }

    /// The ticket's third line: the viewer's actual name, intent and approach ("Alex · Social · Chat first"
    /// in the reference), never the counterpart's.
    private var viewerPreference: String {
        WaveCopy.viewerPreference(viewer: wave.viewerName, intent: wave.intent, approach: wave.approach)
    }

    /// "OUTGOING · YOU ARE [NAME]" (Bold 14/24, #A8B0AD, 272 wide at y 280) and, on pending, review and
    /// accepted, the cyan "Demo cases" control (104 × 44 at 304, 270). When a long name or larger text
    /// cannot keep both on one line, the control moves below the words instead of squeezing them.
    @ViewBuilder
    private func stateRow(_ screen: WaveScreen, invitation: WaveInvitation) -> some View {
        if screen.conditions.isEmpty {
            stateContext(invitation.direction)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 0) {
                    stateContext(invitation.direction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ZStack {
                        demoCasesSlot(screen, invitation: invitation)
                    }
                    .frame(minWidth: 104, minHeight: 44)
                }
                VStack(alignment: .leading, spacing: 0) {
                    stateContext(invitation.direction)
                        .padding(.vertical, 10)
                    demoCasesSlot(screen, invitation: invitation)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    /// Upper case on screen, as approved; VoiceOver reads it in sentence case, with the actual name.
    private func stateContext(_ direction: WaveDirection) -> some View {
        WristbandText(text: WaveCopy.stateContext(direction, viewer: wave.viewerName), face: .bold, size: 14,
                      lineHeight: 24, color: RoomStyle.secondaryText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: Self.contextLabel(direction, viewer: wave.viewerName)))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("wave.invitation.context")
    }

    @ViewBuilder
    private func demoCasesSlot(_ screen: WaveScreen, invitation: WaveInvitation) -> some View {
        if !screen.conditions.isEmpty {
            Button {
                perform(.openConditions(invitation.id), animation: dissolveAnimation)
            } label: {
                WristbandText(text: WaveCopy.demoCases, face: .medium, size: 14, lineHeight: 24,
                              color: wave.intent.tint, alignment: .center)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 104, minHeight: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .circular))
            }
            .buttonStyle(WaveLinkStyle())
            .accessibilityHint(Text(verbatim: "Demo controls. Shows closed examples; nothing runs by itself."))
            .accessibilityFocused($focus, equals: .demoCases)
            .accessibilityIdentifier("wave.demoCases")
            .transition(.opacity)
        }
    }

    /// The approved private invitation: category artwork on a 376 × 220 canvas above a scalable ivory
    /// slip. The decorative objects are never the source of truth for invitation state or consent.
    private func invitationCard(_ screen: WaveScreen, invitation: WaveInvitation, width: CGFloat) -> some View {
        let joined = screen.rings == .joined
        return VStack(spacing: 0) {
            ZStack {
                PrivateInvitationArtwork(intent: wave.intent, accepted: joined, width: width)
                    .id(ringIdentity(joined: joined))
                    .transition(.opacity)
            }
            invitationSlip(screen, invitation: invitation)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wave.invitation")
    }

    /// The rings' identity: one pair whose pose changes (so Accept's 800 ms move interpolates position and
    /// rotation, "Halo ring 1" and "Halo ring 2" matched by name), or, under Reduce Motion, a separate and a
    /// joined pair that crossfade in place: the approved "restrained crossfade" with the same state text.
    private func ringIdentity(joined: Bool) -> Int {
        guard adaptive.reduceMotion else { return 0 }
        return joined ? 2 : 1
    }

    /// The ivory slip's words, all #050606 and centred: the direction and actors (Bold 14/22 at 20, 21),
    /// the title (ExtraBold 28/40 at 20, 53), the purpose (Regular 16/23 in 48 at 24, 102) and the
    /// counterpart's own intent and approach (SemiBold 14/22 at 24, 156), 10 above the slip's end. Words
    /// that change with the state crossfade in place.
    private func invitationSlip(_ screen: WaveScreen, invitation: WaveInvitation) -> some View {
        let counterpart = wave.counterpart
        return VStack(spacing: 0) {
            directionLine(screen, invitation: invitation)
            WaveCardTitle(text: WaveCopy.invitationTitle(screen, counterpart: counterpart) ?? "")
                .contentTransition(.opacity)
                .accessibilityFocused($focus, equals: .invitationTitle)
                .accessibilityIdentifier("wave.invitation.title")
                .padding(.top, 10)
            WristbandBodyText(text: WaveCopy.invitationPurpose(screen, counterpart: counterpart) ?? "", size: 16,
                              lineHeight: 23, color: RoomStyle.ink, alignment: .center)
                .frame(minHeight: 46 * scale, alignment: .top)
                // Preserve the approved two-line minimum, but reserve all wrapped lines before
                // placing the preference below. The inner text alone having ideal height is not enough.
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("wave.invitation.purpose")
                .padding(.horizontal, 4)
                .padding(.top, 9)
            // The layer is named "Shared preference", but it carries the counterpart's own values: the two
            // approaches need not match, and nothing here claims they do.
            WristbandText(text: counterpart.line, face: .semiBold, size: 14, lineHeight: 22, color: RoomStyle.ink,
                          alignment: .center)
                .frame(maxWidth: .infinity)
                // Whose values these are is part of the label, not a hint VoiceOver users may have turned off.
                .accessibilityLabel(Text(verbatim: "\(counterpart.name)’s intent and approach: \(counterpart.line)"))
                .accessibilityIdentifier("wave.invitation.preference")
                .padding(.horizontal, 4)
                .padding(.top, 6)
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(RoomStyle.ivory, in: RoundedRectangle(cornerRadius: 24, style: .circular))
    }

    /// "ALEX → MAYA · OUTGOING" and its siblings: who sent it, to whom, and which way, in upper case on the
    /// slip, from the invitation's own sender and recipient. The viewer is `.viewer` by identity and is
    /// written with the actual Guest List name, even when it is the counterpart's own (founder decision,
    /// 30 September 2026); VoiceOver hears the same in sentence case with "you" for that identity ("From
    /// you (Alex) to Maya. Outgoing."), never inferred from a name.
    private func directionLine(_ screen: WaveScreen, invitation: WaveInvitation) -> some View {
        let text = WaveCopy.directionLine(invitation, on: screen, viewer: wave.viewerName) ?? ""
        let spoken = WaveCopy.directionSpoken(invitation, on: screen, viewer: wave.viewerName) ?? ""
        return RoomLabel(text: text, color: RoomStyle.ink, alignment: .center)
            .contentTransition(.opacity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("wave.invitation.direction")
    }

    /// The screen's own actions. Every one carries the invitation's identity, so a tap that arrives after
    /// the invitation changed (or on a stale copy) is refused by the run.
    @ViewBuilder
    private func invitationActions(_ screen: WaveScreen, invitation: WaveInvitation) -> some View {
        let id = invitation.id
        switch screen {
        case .outgoingConfirm:
            Button(WaveCopy.send) {
                perform(.send(id), animation: dissolveAnimation)
            }
            .buttonStyle(PrivateInvitationButtonStyle(intent: wave.intent, height: 56))
            .accessibilityHint(Text(verbatim: "A local demo step. Nothing is sent to anyone."))
            .accessibilityIdentifier("wave.send")
        case .outgoingPending:
            Button(WaveCopy.withdraw) {
                perform(.withdraw(id), animation: dissolveAnimation)
            }
            .buttonStyle(PrivateInvitationButtonStyle(intent: wave.intent, height: 56))
            .accessibilityHint(Text(verbatim: "Closes this outgoing example."))
            .accessibilityIdentifier("wave.withdraw")
            .padding(.top, 14)
        case .incomingReview:
            reviewActions(id)
        case .incomingAccepted:
            Button(WaveCopy.aboutPrivateChat) {
                perform(.openChatInformation(id), animation: dissolveAnimation)
            }
            .buttonStyle(PrivateInvitationButtonStyle(intent: wave.intent, height: 56))
            .accessibilityHint(Text(verbatim: "Information only. No chat opens."))
            .accessibilityFocused($focus, equals: .aboutChat)
            .accessibilityIdentifier("wave.aboutChat")
            .padding(.top, 14)
        default:
            EmptyView()
        }
    }

    /// Accept (52, the only way into 74:574) and Decline (outline 44), 12 apart. Only the recipient's
    /// review shows them, and the run re-checks every acceptance guard when Accept arrives.
    private func reviewActions(_ id: WaveInvitationID) -> some View {
        VStack(spacing: 0) {
            Button(WaveCopy.accept) {
                perform(.accept(id), animation: acceptAnimation)
            }
            .buttonStyle(PrivateInvitationButtonStyle(intent: wave.intent, height: 52))
            .accessibilityHint(Text(verbatim: "Accepts this fictional invitation. Nothing is sent."))
            .accessibilityIdentifier("wave.accept")
            Button(WaveCopy.decline) {
                perform(.decline(id), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 44))
            .accessibilityHint(Text(verbatim: "Closes this incoming example. No explanation needed."))
            .accessibilityIdentifier("wave.decline")
            .padding(.top, 12)
        }
    }

    // MARK: - Closed and ended screens (74:571, 74:573, 74:575–74:579)

    /// The closed invitation (75:206, 288 × 150 at 76, 165), the headline (ExtraBold 48/56, −4 %, at y 376),
    /// the explanation (Regular 16/25 in 76 at y 530), the cyan closure line (Medium 14/24 at y 654) and
    /// "Back to demo menu" (56 at y 744). None of them names the other person or says why. The ended screen
    /// has the same paper and lines and no Back: its only way on is Return to Places, in the bar.
    private func closedContent(_ screen: WaveScreen, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WaveClosedInvitation()
                .frame(width: min(288, width))
                .frame(maxWidth: .infinity)
                .padding(.top, 57)
            RoomHeadline(lines: WaveCopy.closedHeadline(screen) ?? [], size: 48, lineHeight: 56, tracking: -1.92,
                         box: 112, identifier: "wave.closed.headline")
                .accessibilityFocused($focus, equals: .closedHeadline)
                .padding(.top, 61)
            WristbandBodyText(text: WaveCopy.closedExplanation(screen) ?? "", size: 16, lineHeight: 25,
                              color: RoomStyle.secondaryText, alignment: .leading)
                .frame(minHeight: 76 * scale, alignment: .top)
                .accessibilityIdentifier("wave.closed.explanation")
                .padding(.top, 42)
            WristbandText(text: WaveCopy.closedBoundary, face: .medium, size: 14, lineHeight: 24,
                          color: RoomStyle.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("wave.closed.boundary")
                .padding(.top, 48)
            if screen.isClosed {
                Button(WaveCopy.backToMenu) {
                    perform(.backToMenu(from: screen), animation: dissolveAnimation)
                }
                .buttonStyle(RoomButtonStyle(kind: .primary, height: 56))
                .accessibilityHint(Text(verbatim: "Opens the demo menu. A new example starts only when you choose one."))
                .accessibilityIdentifier("wave.backToMenu")
                .padding(.top, 66)
            }
        }
    }

    // MARK: - The bottom bar

    /// Leave and disappear (376 × 56 at y 824) on every screen but the ended one, which has Return to
    /// Places (376 × 60 at y 812) and nothing else: no Leave, no Back.
    private func actionBar(_ screen: WaveScreen, width: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if screen == .sessionEnded {
                Button(WaveCopy.returnToPlaces) {
                    withAnimation(dissolveAnimation) {
                        _ = session.returnToPlacesFromRoom()
                    }
                }
                .buttonStyle(RoomButtonStyle(kind: .primary, height: 60))
                .accessibilityHint(Text(verbatim: "Opens Places at Now. Your choices are kept."))
                .accessibilityIdentifier("wave.returnToPlaces")
                .transition(.opacity)
            } else {
                leaveButton(height: 56, identifier: "wave.leave")
            }
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
        .padding(.top, Self.barTop(screen))
        .padding(.bottom, Self.barBottom(screen, inset: bottomInset))
        .background(RoomStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    /// The gap above Leave: the Room's 11 + 13 below a screen's last control (y 800 → 824), except under
    /// the recipient's review, whose Decline ends at y 814, 10 above Leave (74:572), so nothing there
    /// needs a scroll at the reference size.
    private static func barTop(_ screen: WaveScreen) -> CGFloat {
        screen == .incomingReview ? 10 : 13
    }

    private static func contentBottom(_ screen: WaveScreen) -> CGFloat {
        screen == .incomingReview ? 0 : 11
    }

    /// The approved gap from the screen's bottom edge to the bar's last control, as on the Room: 76 pt
    /// under Leave (y 880) and 84 under Return to Places (y 872). With a home indicator the bar sits that
    /// far up; a phone without one keeps Places' 29 pt, and a very large inset Places' 8.
    private static func barBottom(_ screen: WaveScreen, inset: CGFloat) -> CGFloat {
        let gap: CGFloat = screen == .sessionEnded ? 84 : 76
        if inset >= 60 { return 8 }
        if inset < 1 { return min(gap, 29) }
        return gap - inset
    }

    /// Leave and disappear, from every screen and overlay: it ends the Room run and its Wave at once,
    /// without a question, with animations disabled (so it wins over a ring join in flight and nothing it
    /// closes lingers), and shows the Wave's own ended screen.
    private func leaveButton(height: CGFloat, identifier: String) -> some View {
        Button(WaveCopy.leave) {
            leave()
        }
        .buttonStyle(RoomButtonStyle(kind: .outline, height: height))
        .accessibilityHint(Text(verbatim: "Ends this demo at once."))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Overlays (74:580–74:586)

    /// The top overlay, centred over the dimmed screen (the ground at 72 %; tapping the dim does nothing).
    /// It scrolls when taller than the space, so its Leave is always reachable. A different overlay
    /// dissolves in; a report reason changes in place.
    ///
    /// Only the top overlay is drawn (`wave.overlay`, the stack's last): under the report preview the
    /// counterpart's safety, and its Block, are not in the view tree at all. The dim takes every tap aimed
    /// outside the card, the card takes every tap on itself (`panelCard`), and the page below takes none
    /// (`layers`), so no touch on an overlay reaches a control underneath (founder decision, 30 September
    /// 2026).
    private func panelLayer(_ overlay: WaveOverlay, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoomStyle.ground
                .opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
            ScrollView(.vertical) {
                panelCard(overlay, width: width)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: height)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The ground behind the status bar, as on the page: an overlay scrolled at large text never runs
            // under the clock (Room builds 6abc2ae1–6abc3ebe, the largest-text panels at 390 and 440 pt).
            .safeAreaInset(edge: .top, spacing: 0) {
                groundStrip
            }
            .id(panelIdentifier(overlay))
            .transition(.opacity)
        }
    }

    /// 376 wide (the column), #111415, radius 28, inset 24; the cyan label (Bold 14/22) at 24, 24 and the
    /// overlay's own content from y 66.
    private func panelCard(_ overlay: WaveOverlay, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomLabel(text: overlay == .conditions ? WaveCopy.controlsLabel : WaveCopy.previewLabel,
                      color: RoomStyle.cyan)
                .accessibilityIdentifier("wavePanel.label")
            panelBody(overlay)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .frame(width: width, alignment: .leading)
        .background(RoomStyle.panel, in: RoundedRectangle(cornerRadius: 28, style: .circular))
        // The founder's rule for the report panel (30 September 2026), on every overlay: the card's whole
        // rectangle, gaps between its controls included, takes the touch, so none passes through it to
        // the dim or to anything beneath. Hit testing only; nothing drawn changes.
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(panelIdentifier(overlay))
    }

    @ViewBuilder
    private func panelBody(_ overlay: WaveOverlay) -> some View {
        switch overlay {
        case .globalSafety:
            globalSafety
        case .counterpartSafety:
            if let counterpart = wave.visibleCounterpart {
                counterpartSafety(counterpart)
            }
        case .report(let selected):
            if let counterpart = wave.visibleCounterpart {
                report(counterpart, selected: selected)
            }
        case .chatInformation:
            chatInformation
        case .conditions:
            conditions
        }
    }

    /// 74:580, 376 × 480: "Your choice / comes first." (ExtraBold 32/38 in 82), the explanation (Regular
    /// 16/26 in 106 at y 176), Close (328 × 52 at y 320) and Leave (52 at y 392).
    private var globalSafety: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle(WaveCopy.safetyTitle, size: 32, lineHeight: 38, box: 82)
            panelText(WaveCopy.safetyExplanation, size: 16, lineHeight: 26, box: 106)
                .padding(.top, 28)
            Button(WaveCopy.close) {
                perform(.closeOverlay(.globalSafety), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityIdentifier("wavePanel.close")
            .padding(.top, 38)
            leaveButton(height: 52, identifier: "wavePanel.leave")
                .padding(.top, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 36)
    }

    /// 74:581, 376 × 480: "[Name] · safety" (ExtraBold 28/44), the explanation (Regular 16/24 in 80 at
    /// y 132), Block (52 at y 230), Preview report (outline 48 at y 296), Back (outline 44 at y 358) and
    /// Leave (outline 44 at y 416). Block adds the counterpart to the Room's one blocked set at once and
    /// closes the invitation as blocked (74:576).
    private func counterpartSafety(_ counterpart: RoomActor) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle([WaveCopy.counterpartSafetyTitle(counterpart)], size: 28, lineHeight: 44, box: 44)
            panelText(WaveCopy.counterpartSafetyExplanation, size: 16, lineHeight: 24, box: 80)
                .padding(.top, 22)
            Button(WaveCopy.block(counterpart)) {
                // The actor and the run this Block was drawn for: a queued tap blocks nobody else, and
                // nothing in another run (founder decision, 30 September 2026).
                performAtOnce(.blockCounterpart(counterpart, run: run.id))
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityHint(Text(verbatim: "Hides this fictional person’s card and invitation in this demo."))
            .accessibilityIdentifier("wavePanel.block")
            .padding(.top, 18)
            Button(WaveCopy.previewReport) {
                perform(.previewReport, animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 48))
            .accessibilityHint(Text(verbatim: "Opens an unsent example. Nothing is submitted."))
            .accessibilityFocused($focus, equals: .previewReport)
            .accessibilityIdentifier("wavePanel.previewReport")
            .padding(.top, 14)
            Button(WaveCopy.back) {
                perform(.closeOverlay(.counterpartSafety), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 44))
            .accessibilityIdentifier("wavePanel.back")
            .padding(.top, 14)
            leaveButton(height: 44, identifier: "wavePanel.leave")
                .padding(.top, 14)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
    }

    /// 74:582, 376 × 568 (node for node the Room's 66:132): "Report [Name]", the explanation (Regular 15/24
    /// in 58 at y 128), the three sample reasons (328 × 56 rows, 6 apart, from y 212; none selected at
    /// first: 75:627), Close preview (52 at y 424) and Leave (outline 48 at y 492). Nothing is submitted,
    /// stored or sent; closing discards the choice and returns to the counterpart's safety.
    private func report(_ counterpart: RoomActor, selected: RoomReportReason?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle([WaveCopy.reportTitle(counterpart)], size: 28, lineHeight: 44, box: 44)
            panelText(WaveCopy.reportExplanation, size: 15, lineHeight: 24, box: 58)
                .padding(.top, 18)
            VStack(spacing: 6) {
                ForEach(RoomReportReason.allCases) { reason in
                    reasonRow(reason, selected: selected)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sample reasons")
            .padding(.top, 26)
            Button(WaveCopy.closePreview) {
                perform(.closeOverlay(.report(selected)), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityHint(Text(verbatim: "Discards this unsent example."))
            .accessibilityIdentifier("wavePanel.closePreview")
            .padding(.top, 32)
            leaveButton(height: 48, identifier: "wavePanel.leave")
                .padding(.top, 16)
        }
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    /// A radio-style choice (75:637 / 75:647 / 75:657): another reason replaces the selection with a
    /// 240 ms dissolve; the selected one again does nothing (it has no reaction in its variant, and the
    /// run refuses it). The selection is announced by the selected trait, as on Room's reasons.
    private func reasonRow(_ reason: RoomReportReason, selected: RoomReportReason?) -> some View {
        let isSelected = reason == selected
        return Button {
            perform(.selectReportReason(reason), animation: dissolveAnimation)
        } label: {
            RoomReasonLabel(title: reason.title, selected: isSelected)
        }
        .buttonStyle(RoomReasonStyle(selected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(verbatim: "Sample reason. Nothing is submitted."))
        .accessibilityIdentifier("wave.report.reason.\(reason.rawValue)")
    }

    /// 74:583, 376 × 480: "A private chat. / By mutual choice." (ExtraBold 30/38 in 82), the explanation
    /// (Regular 17/26 in 112 at y 176), Back (52 at y 320) and Leave (52 at y 392). Information only: no
    /// composer, conversation or Keep.
    private var chatInformation: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle(WaveCopy.chatTitle, size: 30, lineHeight: 38, box: 82)
            panelText(WaveCopy.chatExplanation, size: 17, lineHeight: 26, box: 112)
                .padding(.top, 28)
            Button(WaveCopy.back) {
                perform(.closeOverlay(.chatInformation), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityIdentifier("wavePanel.back")
            .padding(.top, 32)
            leaveButton(height: 52, identifier: "wavePanel.leave")
                .padding(.top, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 36)
    }

    /// 74:584 / 74:586 (and 74:585 on the recipient's review), 376 × 480: "DEMO REVIEW CONTROLS", "Try a
    /// closed / example." (ExtraBold 30/38 in 82), the explanation (Regular 15/24 in 74 at y 165), Show
    /// expired example (52 at y 254), on 74:585 Show sender withdrawn (outline 48 at y 318), Back (outline
    /// 44 at y 326, or 379) and Leave (outline 44 at y 431 in all three, 5 above the panel's end).
    private var conditions: some View {
        let offersWithdrawn = wave.screen.conditions.contains(.senderWithdrawn)
        let id = wave.invitation?.id
        return VStack(alignment: .leading, spacing: 0) {
            panelTitle(WaveCopy.conditionsTitle, size: 30, lineHeight: 38, box: 82)
            panelText(WaveCopy.conditionsExplanation, size: 15, lineHeight: 24, box: 74)
                .padding(.top, 17)
            Button(WaveCopy.showExpired) {
                if let id { perform(.showExpired(id), animation: dissolveAnimation) }
            }
            .buttonStyle(RoomButtonStyle(kind: .primary, height: 52))
            .accessibilityHint(Text(verbatim: "Demo condition. Closes this example as expired."))
            .accessibilityIdentifier("wavePanel.showExpired")
            .padding(.top, 15)
            if offersWithdrawn {
                Button(WaveCopy.showSenderWithdrawn) {
                    if let id { perform(.showSenderWithdrawn(id), animation: dissolveAnimation) }
                }
                .buttonStyle(RoomButtonStyle(kind: .outline, height: 48))
                .accessibilityHint(Text(verbatim: "Demo condition. Closes this example as withdrawn by the sender."))
                .accessibilityIdentifier("wavePanel.showSenderWithdrawn")
                .padding(.top, 12)
            }
            Button(WaveCopy.back) {
                perform(.closeOverlay(.conditions), animation: dissolveAnimation)
            }
            .buttonStyle(RoomButtonStyle(kind: .outline, height: 44))
            .accessibilityIdentifier("wavePanel.back")
            .padding(.top, offersWithdrawn ? 13 : 20)
            leaveButton(height: 44, identifier: "wavePanel.leave")
                .padding(.top, offersWithdrawn ? 8 : 61)
        }
        .padding(.top, 20)
        .padding(.bottom, 5)
    }

    /// An overlay title (from y 66) in its Figma box; VoiceOver lands here when the overlay opens.
    private func panelTitle(_ lines: [String], size: CGFloat, lineHeight: CGFloat, box: CGFloat) -> some View {
        RoomHeadline(lines: lines, size: size, lineHeight: lineHeight, box: box, identifier: "wavePanel.title")
            .accessibilityFocused($focus, equals: .panelTitle)
    }

    /// Overlay copy (#A8B0AD) in its Figma box, which grows with the text.
    private func panelText(_ text: String, size: CGFloat, lineHeight: CGFloat, box: CGFloat) -> some View {
        WristbandBodyText(text: text, size: size, lineHeight: lineHeight, color: RoomStyle.secondaryText,
                          alignment: .leading)
            .frame(minHeight: box * scale, alignment: .top)
            .accessibilityIdentifier("wavePanel.explanation")
    }

    /// The overlay container's identifier, also its identity: a different overlay dissolves in, while a
    /// reason selected inside the same report does not replace it.
    private func panelIdentifier(_ overlay: WaveOverlay) -> String {
        switch overlay {
        case .globalSafety: return "wavePanel.globalSafety"
        case .counterpartSafety: return "wavePanel.counterpartSafety.\(wave.counterpart.rawValue)"
        case .report: return "wavePanel.report.\(wave.counterpart.rawValue)"
        case .chatInformation: return "wavePanel.chatInfo"
        case .conditions: return "wavePanel.conditions"
        }
    }

    private var groundStrip: some View {
        Color.clear
            .frame(height: 0)
            .background(RoomStyle.ground.ignoresSafeArea(edges: .top))
    }

    // MARK: - Changing the run

    /// 240 ms ease-out; none for VoiceOver.
    private var dissolveAnimation: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: 0.24)
    }

    /// Accept (75:419): the one 800 ms ease-out move; a 240 ms crossfade under Reduce Motion (the rings
    /// change identity, see `ringIdentity`); none for VoiceOver.
    private var acceptAnimation: Animation? {
        if adaptive.voiceOverRunning { return nil }
        return adaptive.reduceMotion ? .easeOut(duration: 0.24) : .easeOut(duration: 0.8)
    }

    /// One Wave control, applied only to the run it was drawn for; the run re-checks the Room's central
    /// state and the control's own handle when it arrives, and a refused one changes nothing.
    private func perform(_ action: WaveAction, animation: Animation?) {
        withAnimation(animation) {
            _ = session.performWave(run.id, action)
        }
    }

    /// Block: the model changes with every animation disabled, so the counterpart's invitation never
    /// lingers on screen or in accessibility, and a ring join in flight loses.
    private func performAtOnce(_ action: WaveAction) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            _ = session.performWave(run.id, action)
        }
    }

    /// Leave, through the Room's own transition: the run and its Wave end together, at once.
    private func leave() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            _ = session.updateRoomRun(run.id) { $0.leave() }
        }
    }

    // MARK: - VoiceOver focus

    /// Moves VoiceOver to `target` once the change is on screen (the new element exists by then).
    private func focusSoon(_ target: WaveFocus?) {
        guard let target else { return }
        Task { @MainActor in
            focus = target
        }
    }

    /// Where VoiceOver starts when the Wave appears: the overlay's title, or the screen's first element.
    private static func appearTarget(_ wave: WaveDemo) -> WaveFocus {
        wave.overlay == nil ? screenTarget(wave.screen) : .panelTitle
    }

    /// A screen's first element: the menu's headline, an invitation's title (its state), or a closed
    /// screen's headline.
    private static func screenTarget(_ screen: WaveScreen) -> WaveFocus {
        if screen == .menu { return .menuHeadline }
        return screen.showsCounterpart ? .invitationTitle : .closedHeadline
    }

    /// Where VoiceOver goes after a change: into an overlay as it opens, back to Preview report when the
    /// report closes, back to the control that opened an overlay as it closes (the shield, Demo cases or
    /// About private chat), and to the first element of a new screen. A report reason keeps the focus
    /// where it is.
    private static func focusTarget(from previous: WaveDemo, to current: WaveDemo) -> WaveFocus? {
        if let overlay = current.overlay {
            if let before = previous.overlay, sameLevel(before, overlay) { return nil }
            if case .report? = previous.overlay, overlay == .counterpartSafety { return .previewReport }
            return .panelTitle
        }
        if current.screen != previous.screen { return screenTarget(current.screen) }
        guard let closed = previous.overlay else { return nil }
        switch closed {
        case .globalSafety, .counterpartSafety, .report: return .chromeSafety
        case .conditions: return .demoCases
        case .chatInformation: return .aboutChat
        }
    }

    private static func sameLevel(_ first: WaveOverlay, _ second: WaveOverlay) -> Bool {
        switch (first, second) {
        case (.report, .report): return true
        default: return first == second
        }
    }

    // MARK: - VoiceOver copy

    /// "OUTGOING · YOU ARE ALEX" read in sentence case, with the name as the guest typed it.
    private static func contextLabel(_ direction: WaveDirection, viewer: String) -> String {
        "\(direction == .outgoing ? "Outgoing" : "Incoming"). You are \(viewer)."
    }
}

// MARK: - Scroll targets and focus

private enum WaveScrollTarget: Hashable {
    case top
}

/// The 75:119 Back's hint and action on the screen it was drawn for (see `WaveView.backControl`).
private struct WaveBackControl {
    let hint: String
    let action: @MainActor () -> Void
}

/// The elements VoiceOver is moved to (see `WaveView.focusTarget`).
private enum WaveFocus: Hashable {
    case menuHeadline
    case invitationTitle
    case closedHeadline
    case chromeSafety
    case demoCases
    case aboutChat
    case panelTitle
    case previewReport
}

// MARK: - The venue ticket

/// Compact context for the private invitation. The selected intent leads, while the fictional venue,
/// session and viewer preference remain visible and available to assistive technology.
struct WaveVenueTicket: View {
    let venue: String
    let preference: String
    let intent: BandIntent
    let width: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            PrivateInvitationIntentBadge(intent: intent)
            WristbandText(text: "\(venue) · \(WaveCopy.session)", face: .regular, size: 12,
                          lineHeight: 18, color: RoomStyle.secondaryText, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            WristbandText(text: preference, face: .semiBold, size: 14, lineHeight: 22,
                          color: RoomStyle.secondaryText, alignment: .center)
                .accessibilityIdentifier("wave.venue.preference")
        }
        .frame(width: width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(venue). \(WaveCopy.session). \(preference)"))
        .accessibilityIdentifier("wave.venue")
    }
}

/// The intent is communicated by its word and symbol as well as its semantic colour.
struct PrivateInvitationIntentBadge: View {
    let intent: BandIntent
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: intent.symbolName)
                .font(.system(size: size, weight: .semibold))
                .accessibilityHidden(true)
            Text(intent.title)
                .manrope(.bold, size: size, designSize: 16, lineHeight: 24)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(intent.tint)
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .overlay(Capsule().strokeBorder(intent.tint, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(intent.title))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("wave.intent.\(intent.rawValue)")
    }
}

/// Primary invitation actions use the selected intent, with a dark, high-contrast label.
struct PrivateInvitationButtonStyle: ButtonStyle {
    let intent: BandIntent
    let height: CGFloat
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .manrope(.bold, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(RoomStyle.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(intent.tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - The invitation's title and the closed invitation

/// The invitation's title (ExtraBold 28/40, #050606, centred, 336 wide): the state, in words. It wraps
/// between words at larger text rather than shrinking. A header.
struct WaveCardTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .manrope(.extraBold, size: 28 * scale, designSize: 28, lineHeight: 40)
            .foregroundStyle(RoomStyle.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The closed invitation (75:206, 288 × 150): a blank sheet (264 × 136, radius 20) at 12, 4, turned 3°
/// clockwise about its own corner (Figma −3°, matrix [[0.9986, −0.0523, 12], [0.0523, 0.9986, 4]]), behind
/// the closed sheet (288 × 135, radius 20) at y 15 with its steel seal (60 × 34, radius 7, #7A8585) at the
/// top edge, "AN INVITATION" (Bold 14/24 at y 59) and "There is always room to choose." (Regular 14/22 at
/// y 95), centred, 18 above the sheet's end. It is the Room's envelope metaphor on the Wave's own
/// measurements, and it names nobody: every closed and ended screen shows the same paper.
struct WaveClosedInvitation: View {
    var body: some View {
        VStack(spacing: 0) {
            WristbandText(text: WaveCopy.closedLabel, face: .bold, size: 14, lineHeight: 24,
                          color: RoomStyle.ink, alignment: .center)
                .accessibilityIdentifier("wave.closed.label")
            WristbandText(text: WaveCopy.closedChoice, face: .regular, size: 14, lineHeight: 22,
                          color: RoomStyle.ink, alignment: .center)
                .accessibilityIdentifier("wave.closed.choice")
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 59)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .circular)
                    .fill(RoomStyle.ivory)
                RoundedRectangle(cornerRadius: 7, style: .circular)
                    .fill(RoomStyle.stroke)
                    .frame(width: 60, height: 34)
            }
        }
        .background {
            // One point taller than the front sheet (136 against 135) and 11 above it (y 4 against 15).
            RoundedRectangle(cornerRadius: 20, style: .circular)
                .fill(RoomStyle.ivory)
                .rotationEffect(.degrees(3), anchor: .topLeading)
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .padding(.bottom, -1)
                .offset(y: -11)
        }
        .padding(.top, 15)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Chrome and controls

/// The Room's DEMO label (75:113 = 67:113): 72 × 28, radius 9, a 0.6-pt cyan outline inside, "DEMO" Bold
/// 11/28 in cyan, centred, with the Wave's identifier. One element: "Demo".
struct WaveDemoBadge: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 11

    var body: some View {
        Text("DEMO")
            .lineLimit(1)
            .manrope(.bold, size: size, designSize: 11, lineHeight: 28)
            .fixedSize()
            .foregroundStyle(RoomStyle.cyan)
            .padding(.horizontal, 8)
            .frame(minWidth: 48, minHeight: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .circular)
                    .strokeBorder(RoomStyle.cyan, lineWidth: 0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Demo"))
            .accessibilityIdentifier("wave.demoBadge")
    }
}

/// A longer invitation title keeps its readable size and may wrap instead of shrinking to fit.
private struct WaveChromeTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 16

    var body: some View {
        Text(text)
            .manrope(.bold, size: size, designSize: 16, lineHeight: 22)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The menu's three choices: exactly `RoomButtonStyle` while enabled (it is `RoomButtonBody` itself), and,
/// once disabled by a blocked counterpart, the app's approved disabled treatment (Birthday, Guest List,
/// Wristband, Signal and Places: a #1F2424 fill with a #737D7A label, `WristbandStyle.disabledFill` and
/// `.disabledText`). No approved screen has a disabled outline, so the outline keeps its shape, its 1-pt
/// border in the disabled fill and its label in the disabled text colour (#737D7A on the #050606 ground
/// is 4.8:1; on the #1F2424 fill 3.7:1, as on those five screens). Same metrics, radius and height; no
/// press dimming, as a disabled button takes no press. `RoomButtonStyle`, shared with the Room, does not
/// read `isEnabled`, so the treatment lives here rather than changing the Room's buttons.
struct WaveChoiceStyle: ButtonStyle {
    let kind: RoomButtonStyle.Kind
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        WaveChoiceBody(configuration: configuration, primary: kind == .primary, height: height)
    }
}

private struct WaveChoiceBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    let height: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        if isEnabled {
            RoomButtonBody(configuration: configuration, primary: primary, height: height)
        } else {
            let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
            configuration.label
                .manrope(.semiBold, size: size, designSize: 16, lineHeight: 24)
                .foregroundStyle(WristbandStyle.disabledText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(primary ? WristbandStyle.disabledFill : Color.clear, in: shape)
                .overlay {
                    shape.strokeBorder(primary ? Color.clear : WristbandStyle.disabledFill, lineWidth: 1)
                }
                .contentShape(shape)
        }
    }
}

/// "Demo cases" (75:363): a text control with no fill (its 104 × 44 frame has radius 12), dimmed while
/// pressed like the Room's outline buttons.
struct WaveLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#if DEBUG
#Preview("Wave · menu, Social") {
    NavigationStack { PlacesView() }
        .environment(DebugLaunch.session(arguments: ["-ProximeetFixture", "wave-menu", "-ProximeetFixtureBand",
                                                     "social", "-ProximeetFixtureSignal", "chatFirst"])
                     ?? DemoSession())
}

#Preview("Wave · in-review, Business") {
    NavigationStack { PlacesView() }
        .environment(DebugLaunch.session(arguments: ["-ProximeetFixture", "wave-in-review", "-ProximeetFixtureBand",
                                                     "business", "-ProximeetFixtureSignal", "okayToSayHello"])
                     ?? DemoSession())
}

#Preview("Wave · in-accepted, Social") {
    NavigationStack { PlacesView() }
        .environment(DebugLaunch.session(arguments: ["-ProximeetFixture", "wave-in-accepted", "-ProximeetFixtureBand",
                                                     "social", "-ProximeetFixtureSignal", "chatFirst"])
                     ?? DemoSession())
}
#endif
