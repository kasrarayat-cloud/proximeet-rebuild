import SwiftUI
import UIKit
import ProximeetDomain

/// Chapter 04 — the approved Guest List (handoff `LAYOUT_SPEC.json`, Figma 35:111; the empty
/// editor 36:134, the fictional example 36:169 and the personal card 36:204), on the 440 × 956
/// reference canvas.
///
/// The guest writes a short introduction and previews it as a small paper card. The draft
/// (`DemoDraft.introduction`) is kept in memory for this demo run only: it starts empty, keeps
/// exactly what was typed or pasted, survives Back to the Pass and re-entry, and is gone after
/// relaunch. Nothing is stored, sent or shown to anyone, and nothing is checked; the card is a
/// preview.
///
/// Two stages (`GuestListDemo`), each changed only by the guest: Preview my card (editor →
/// card) and Edit introduction or Back (card → editor), with a 220 ms ease-out dissolve. The
/// card settles into place in 450 ms, art and text together. Back on the editor returns to the
/// Pass, still complete below this screen. Continue preview on the card opens the approved
/// Wristband (chapter 05); its Back returns to this card, which stays below it.
///
/// The cotton paper, clip, woven tab and holder are the approved raster decoration
/// (`GuestListCardArt`, the original 1457 × 1079 artwork cropped to its silhouette); every word,
/// the initial and every control are native.
struct GuestListView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var demo = GuestListDemo()
    /// Gentle validation: the name's help appears only once the name has been edited or left.
    @State private var nameTouched = false
    @FocusState private var focus: GuestListField?
    @AccessibilityFocusState private var headlineFocused: Bool
    @ScaledMetric(relativeTo: .body) private var nameSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var openerSize: CGFloat = 17

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .id(GuestListScrollTarget.top)
                        // Its own layer, so the 220 ms dissolve overlaps the editor and the card
                        // instead of stacking them.
                        ZStack(alignment: .top) {
                            if demo.stage == .card, let card = session.introduction.card {
                                GuestListCardPage(
                                    card: card,
                                    width: min(392, max(0, proxy.size.width - 48)),
                                    headlineFocused: $headlineFocused
                                )
                                .transition(.opacity)
                            } else {
                                editor
                                    .transition(.opacity)
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                // The ground behind the status bar, so scrolled text never runs under the clock.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .background(GuestListStyle.ground.ignoresSafeArea(edges: .top))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    actions(bottomInset: proxy.safeAreaInsets.bottom)
                }
                .onChange(of: focus) { previous, field in
                    if previous == .name && field != .name {
                        nameTouched = true
                    }
                    reveal(field, with: reader)
                }
                .onChange(of: proxy.safeAreaInsets.bottom) { previous, inset in
                    // The keyboard arrived: keep the focused field above it. Not while it leaves,
                    // so an interactive dismissal is never fought.
                    if inset > previous {
                        reveal(focus, with: reader)
                    }
                }
                .onChange(of: demo.stage) { _, _ in
                    reader.scrollTo(GuestListScrollTarget.top, anchor: .top)
                    // Predictable focus after the switch: VoiceOver starts at the new headline.
                    Task { @MainActor in
                        headlineFocused = true
                    }
                }
            }
        }
        .background(GuestListStyle.ground.ignoresSafeArea())
        .background(RepeatTapGuard())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focus = nil
                }
                .accessibilityIdentifier("guestList.keyboardDone")
            }
        }
        .onChange(of: session.introduction.name) {
            nameTouched = true
        }
        .onChange(of: session.introduction.isOpenerWithinLimit) { _, within in
            // Once when the limit is crossed and once when it is restored, never per keystroke.
            AccessibilityNotification.Announcement(within ? GuestListCopy.openerRestored : GuestListCopy.openerOver).post()
        }
        .onAppear {
            openFixtureCard()
        }
    }

    // MARK: - Header

    /// Back (44 × 44 at 24, 64), the wordmark (Bold 22/32 at x 84) and the DEMO PROFILE label
    /// (128 × 32 at 285, 70), all centred on the 44-pt header row.
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                back()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("guestList.back")
            GuestListWordmark()
            Spacer(minLength: 8)
            // Never truncated: the wordmark gives way first. Its growth stops at the largest
            // non-accessibility size.
            DemoProfileBadge()
                .layoutPriority(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(minHeight: 44)
        .padding(.leading, 24)
        .padding(.trailing, 27)
        .padding(.top, 2)
    }

    // MARK: - Editor

    /// "A little about you." The name (required), the opener (optional, 120 characters) and
    /// the interests (optional), then the visibility boundary.
    private var editor: some View {
        let introduction = session.introduction
        return VStack(alignment: .leading, spacing: 0) {
            GuestListHeadline(lines: GuestListCopy.editorHeadline, focused: $headlineFocused)
                .padding(.top, 46)
            GuestListSupport(text: GuestListCopy.editorSupport)
                .padding(.top, 16.32)
            nameGroup(introduction)
                .padding(.top, 18)
            openerGroup(introduction)
                .padding(.top, 16)
            interestsGroup(introduction)
                .padding(.top, 16)
            GuestListBoundary()
                .padding(.top, 59)
        }
        .padding(.horizontal, 32)
    }

    /// "Name" (SemiBold 16/24) over a 376 × 56 field (Regular 18/24).
    private func nameGroup(_ introduction: GuestIntroduction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GuestListFieldLabel(text: "Name")
            GuestListInput(minHeight: 56, verticalPadding: 0) {
                TextField("", text: nameBinding, prompt: GuestListCopy.prompt("What should we call you?"))
                    .font(Manrope.regular.font(size: nameSize))
                    .foregroundStyle(.white)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focus = .opener
                    }
                    // Never autocorrected or auto-capitalised: the name is kept exactly as entered.
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onKeyPress(.tab, phases: .down) { press in
                        guard !press.modifiers.contains(.shift) else { return .ignored }
                        focus = .opener
                        return .handled
                    }
                    .accessibilityLabel("Name")
                    .accessibilityHint("Required to preview your card.")
                    .accessibilityIdentifier("guestList.name")
            }
            if nameTouched && introduction.isNameBlank {
                GuestListFieldHelp(text: GuestListCopy.nameHelp)
                    .accessibilityIdentifier("guestList.nameHelp")
            }
        }
        .id(GuestListScrollTarget.name)
    }

    /// "A little about you (optional)" over a 376 × 88 field (Regular 17/24) and the count
    /// (Medium 12/16, right-aligned). Over the limit the text stays; the help says why the
    /// preview waits.
    private func openerGroup(_ introduction: GuestIntroduction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GuestListFieldLabel(text: "A little about you (optional)")
            GuestListInput(minHeight: 88, verticalPadding: 13) {
                // Return adds a line; Done above the keyboard, Tab or scrolling leaves the field.
                TextField("", text: openerBinding, prompt: GuestListCopy.prompt("A good hello starts with…"), axis: .vertical)
                    .lineLimit(2...6)
                    .font(Manrope.regular.font(size: openerSize))
                    .foregroundStyle(.white)
                    .focused($focus, equals: .opener)
                    // Never autocorrected either: the guest's words stay exactly as entered.
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                    .onKeyPress(.tab, phases: .down) { press in
                        focus = press.modifiers.contains(.shift) ? .name : nil
                        return .handled
                    }
                    .accessibilityLabel("A little about you, optional")
                    .accessibilityHint("Up to \(GuestIntroduction.openerLimit) characters.")
                    .accessibilityIdentifier("guestList.opener")
            }
            GuestListCount(count: introduction.openerCount)
            if !introduction.isOpenerWithinLimit {
                GuestListFieldHelp(text: GuestListCopy.openerOver)
                    .accessibilityIdentifier("guestList.openerHelp")
            }
        }
        .id(GuestListScrollTarget.opener)
    }

    /// "Interests · optional · up to 3" (Medium 14/24) over three 116 × 44 chips, 8 apart.
    private func interestsGroup(_ introduction: GuestIntroduction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GuestListInterestsLabel()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    chips(introduction)
                }
                VStack(alignment: .leading, spacing: 8) {
                    chips(introduction)
                }
            }
        }
    }

    private func chips(_ introduction: GuestIntroduction) -> some View {
        ForEach(GuestIntroduction.Interest.allCases, id: \.self) { interest in
            let selected = introduction.isSelected(interest)
            Button(interest.label) {
                session.editIntroduction { $0.toggle(interest) }
            }
            .buttonStyle(InterestChipStyle(selected: selected))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("guestList.interest.\(interest.rawValue)")
        }
    }

    // MARK: - Actions

    /// iOS 26 floats the keyboard toolbar's Done above the keyboard's safe area: on build
    /// 6ab75905 (iPhone 17 Pro Max) Done lay at y 569–605 against a safe-area edge at 597, over
    /// the bottom-right corner of Back's 376 × 44 target. While a field is focused the actions
    /// keep this much more room, so Done never lies over Back or the primary action.
    private static let keyboardDoneClearance: CGFloat = 36

    /// 376 × 60 at y 812 and 376 × 44 at y 880, kept above the keyboard (safe-area inset). At
    /// rest the pair ends 32 pt above the screen's bottom edge, as in Figma.
    private func actions(bottomInset: CGFloat) -> some View {
        let editing = demo.stage == .editor
        return VStack(spacing: 8) {
            Button(editing ? "Preview my card" : "Continue preview") {
                primary()
            }
            .buttonStyle(GuestListPrimaryStyle())
            .disabled(editing && !session.introduction.canPreview)
            .accessibilityHint(primaryHint)
            .accessibilityIdentifier("guestList.primary")
            Button(editing ? "Back" : "Edit introduction") {
                secondary()
            }
            .buttonStyle(GuestListSecondaryStyle())
            .accessibilityIdentifier("guestList.secondary")
        }
        .padding(.horizontal, 32)
        .padding(.top, 25)
        // At rest (no field focused, no keyboard), 32 pt above the screen edge, which may reach
        // 2 pt into the home indicator area. While a field is focused, clear of the keyboard's
        // floating Done; while a keyboard is still leaving, 8 pt above it.
        .padding(.bottom, focus != nil ? 8 + Self.keyboardDoneClearance : (bottomInset < 60 ? 32 - bottomInset : 8))
        .background(GuestListStyle.ground.ignoresSafeArea(edges: .bottom))
    }

    private var primaryHint: String {
        let introduction = session.introduction
        guard demo.stage == .editor, !introduction.canPreview else { return "" }
        return introduction.isNameBlank ? GuestListCopy.nameHelp : GuestListCopy.openerOver
    }

    private func primary() {
        switch demo.stage {
        case .editor:
            focus = nil
            withAnimation(dissolve) {
                _ = demo.preview(session.introduction)
            }
        case .card:
            if demo.continuePreview() {
                session.continueFromGuestListCard(demo)
            }
        }
    }

    private func secondary() {
        switch demo.stage {
        case .editor:
            focus = nil
            session.leaveGuestList()
        case .card:
            withAnimation(dissolve) {
                _ = demo.edit()
            }
        }
    }

    /// Header Back: the editor returns to the Pass; the card returns to the editor (Figma 36:204).
    private func back() {
        secondary()
    }

    // MARK: - Draft

    private var nameBinding: Binding<String> {
        Bindable(session).introductionName
    }

    private var openerBinding: Binding<String> {
        Bindable(session).introductionOpener
    }

    /// Keeps the focused field, with its label, count and help, above the keyboard.
    private func reveal(_ field: GuestListField?, with reader: ScrollViewProxy) {
        guard let field else { return }
        reader.scrollTo(field == .name ? GuestListScrollTarget.name : GuestListScrollTarget.opener, anchor: .center)
    }

    // MARK: - Motion

    /// Editor ↔ card: 220 ms ease-out dissolve (Figma). Reduce Motion: a brief dissolve.
    private var dissolve: Animation? {
        adaptive.voiceOverRunning ? nil : .easeOut(duration: adaptive.reduceMotion ? 0.12 : 0.22)
    }

    private func openFixtureCard() {
        #if DEBUG
        if session.fixtureOpensGuestListCard {
            session.fixtureOpensGuestListCard = false
            demo.preview(session.introduction)
        }
        #endif
    }
}

enum GuestListField: Hashable {
    case name
    case opener
}

private enum GuestListScrollTarget: Hashable {
    case top
    case name
    case opener
}

/// The approved words, and the field help this implementation adds.
enum GuestListCopy {
    static let editorHeadline = ["A little", "about you."]
    static let editorSupport = "Give your hello a starting point."
    static let cardHeadline = ["Your first", "hello."]
    static let cardSupport = "A small card. A real starting point."
    static let cardContext = "Your introduction, ready to edit."
    static let boundary = "This preview doesn’t make you\nvisible to anyone."
    static let nameHelp = "Add a name to preview your card."
    static let openerOver = "Keep it to \(GuestIntroduction.openerLimit) characters to preview your card."
    static let openerRestored = "Your introduction fits in \(GuestIntroduction.openerLimit) characters."

    @MainActor
    static func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(GuestListStyle.secondaryText)
    }
}

// MARK: - The card page

/// "Your first hello." The personal card settles into place (450 ms, art and text as one), then
/// "Your introduction, ready to edit." and the visibility boundary.
private struct GuestListCardPage: View {
    let card: IntroductionCard
    let width: CGFloat
    let headlineFocused: AccessibilityFocusState<Bool>.Binding
    @Adaptive private var adaptive
    @State private var settled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GuestListHeadline(lines: GuestListCopy.cardHeadline, focused: headlineFocused)
                .padding(.top, 46)
                .padding(.horizontal, 32)
            GuestListSupport(text: GuestListCopy.cardSupport)
                .padding(.top, 16.32)
                .padding(.horizontal, 32)
            PersonalCard(card: card, width: width)
                .modifier(SettleEntrance(settled: settled, offsetY: 24, animation: settleAnimation))
                .frame(maxWidth: .infinity)
                .padding(.top, 49)
            GuestListCentredText(text: GuestListCopy.cardContext)
                .padding(.top, 30.54)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("guestList.context")
            GuestListBoundary()
                .padding(.top, 33)
                .padding(.horizontal, 32)
        }
        .onAppear {
            settled = true
        }
    }

    /// 450 ms insert and settle; Reduce Motion keeps the card stationary with a brief dissolve.
    private var settleAnimation: Animation? {
        if adaptive.voiceOverRunning { return nil }
        return adaptive.reduceMotion ? .easeOut(duration: 0.15) : .timingCurve(0.25, 0.8, 0.25, 1, duration: 0.45)
    }
}

/// The card (Figma 36:126, 392 × 256.46 at 24, 371): the initial in a 44-pt disc, the name
/// (ExtraBold 38/41.04), the opener (Medium 18/24), a rule and the interests (SemiBold 14/24),
/// on the paper art. Absent optional lines and the rule are left out, and whatever remains is
/// centred in the paper's writing area. The text follows Dynamic Type; when it needs more room
/// than the approved composition, the paper grows with it (`GuestListCardArt`).
///
/// One accessibility element: the name, the opener and the interests, read once. The initial
/// and the paper are decoration.
private struct PersonalCard: View {
    let card: IntroductionCard
    let width: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var nameSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var openerSize: CGFloat = 18
    @ScaledMetric(relativeTo: .subheadline) private var interestSize: CGFloat = 14
    @ScaledMetric(relativeTo: .title3) private var initialSize: CGFloat = 20

    private var k: CGFloat { width / 392 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nameRow
            if let opener = card.opener {
                // Medium 18 on Figma's 24-pt lines, tighter than the face's natural 24.59.
                TightLines(natural: Manrope.medium.naturalLineHeight(size: openerSize), pitch: 24 * openerSize / 18) {
                    Text(opener)
                        .font(Manrope.medium.font(size: openerSize))
                        .foregroundStyle(GuestListStyle.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14 * k)
            }
            if !card.interests.isEmpty {
                Rectangle()
                    .fill(GuestListStyle.ink.opacity(0.2))
                    .frame(width: 298 * k, height: 1)
                    .padding(.top, (card.opener == nil ? 14 : 13) * k)
                interestLine
                    .padding(.top, 9 * k)
            }
        }
        // The writing area, 69 to 224 on the approved card; shorter content is centred in it.
        .frame(maxWidth: .infinity, minHeight: 155 * k, alignment: .leading)
        .padding(.leading, 37 * k)
        .padding(.trailing, 52 * k)
        .padding(.top, 69 * k)
        .padding(.bottom, 32.46 * k)
        .frame(width: width)
        .frame(minHeight: 256.46 * k)
        .background {
            GuestListCardArt()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityIdentifier("guestList.card")
    }

    /// The initial's 44-pt disc (#050606, Bold 20/21.6 #F6F7F2) 13 pt before the name.
    private var nameRow: some View {
        let disc = max(44, 44 * initialSize / 20)
        return HStack(alignment: .top, spacing: 13 * k) {
            Circle()
                .fill(GuestListStyle.ink)
                .frame(width: disc, height: disc)
                .overlay(alignment: .top) {
                    Text(card.initial)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .manrope(.bold, size: initialSize, designSize: 20, lineHeight: 21.6)
                        .foregroundStyle(GuestListStyle.paperWhite)
                        .padding(.top, 9 * disc / 44)
                        .frame(width: disc * 0.8)
                }
                .padding(.top, 2)
            GuestListCardText(text: card.name, face: .extraBold, size: nameSize, designSize: 38, lineHeight: 41.04)
        }
    }

    /// "Coffee   /   Live music   /   Outdoors" on one line when it fits; otherwise one
    /// interest per line, with no separators to dangle.
    private var interestLine: some View {
        let labels = card.interests.map(\.label)
        return ViewThatFits(in: .horizontal) {
            Text(labels.joined(separator: "   /   "))
                .lineLimit(1)
                .manrope(.semiBold, size: interestSize, designSize: 14, lineHeight: 24)
                .fixedSize()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(labels, id: \.self) { label in
                    GuestListCardText(text: label, face: .semiBold, size: interestSize, designSize: 14, lineHeight: 24)
                }
            }
        }
        .foregroundStyle(GuestListStyle.ink)
    }

    private var accessibilitySummary: String {
        var parts = [card.name]
        if let opener = card.opener {
            parts.append(opener)
        }
        if !card.interests.isEmpty {
            parts.append("Interests: " + card.interests.map(\.label).joined(separator: ", "))
        }
        return parts.reduce("") { text, part in
            guard !text.isEmpty else { return part }
            let ends = text.last.map { ".!?…".contains($0) } ?? false
            return text + (ends ? " " : ". ") + part
        }
    }
}

/// Card text on its Figma line height, wrapping when it has to (never clipped or shrunk).
private struct GuestListCardText: View {
    let text: String
    let face: Manrope
    let size: CGFloat
    let designSize: CGFloat
    let lineHeight: CGFloat

    var body: some View {
        Text(text)
            .manrope(face, size: size, designSize: designSize, lineHeight: lineHeight)
            .foregroundStyle(GuestListStyle.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wrapped text whose Figma line height is tighter than the face's natural line: the block takes
/// Figma's height (lines × `pitch`) and the text is centred on it. Each baseline then sits within
/// (natural − pitch) × (lines − 1) / 2 of Figma's, 0.3 pt for two lines of Medium 18/24, and what
/// follows sits exactly where Figma puts it. `ManropeLineBox` cannot do this: `lineSpacing` has
/// no negative values.
private struct TightLines: Layout {
    let natural: CGFloat
    let pitch: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let size = text.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        let lines = max(1, (size.height / natural).rounded())
        // The whole offered width, so the text is placed at the width it was measured at and
        // wraps the same way.
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? size.width
        return CGSize(width: width, height: size.height - lines * max(0, natural - pitch))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        let size = text.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        text.place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: bounds.width, height: size.height)
        )
    }
}

// MARK: - The paper art

/// The approved decoration: `guest-list-card.png` unchanged in the bundle, cropped here to its
/// visible silhouette [66, 93, 1436, 988] and fitted to the card's width (392 × 256.09 in the
/// 392 × 256.46 card, centred). When the card's text needs more height, only a plain band of
/// paper (rows 419–699 of the crop, below the woven tab and above the holder) is stretched, so
/// the clip, the tab and the holder keep their shape.
private struct GuestListCardArt: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            if let slices = CardArtSlices.shared {
                let size = proxy.size
                let natural = size.width * CardArtSlices.crop.height / CardArtSlices.crop.width
                if size.height <= natural + 1 {
                    Image(uiImage: slices.whole)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: natural)
                        .frame(width: size.width, height: size.height)
                } else {
                    let scale = size.width / CardArtSlices.crop.width
                    let top = pixelRounded(CardArtSlices.topRows * scale)
                    let bottom = pixelRounded(CardArtSlices.bottomRows * scale)
                    VStack(spacing: 0) {
                        slice(slices.top, height: top)
                        slice(slices.middle, height: size.height - top - bottom)
                        slice(slices.bottom, height: bottom)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func slice(_ image: UIImage, height: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .frame(height: height)
    }

    /// Slice boundaries on whole device pixels, so the three pieces meet without a seam.
    private func pixelRounded(_ value: CGFloat) -> CGFloat {
        (value * displayScale).rounded() / displayScale
    }
}

/// The crop of the original artwork, and its three horizontal slices, made once.
@MainActor
private struct CardArtSlices {
    nonisolated static let crop = CGRect(x: 66, y: 93, width: 1370, height: 895)
    nonisolated static let topRows: CGFloat = 419
    nonisolated static let bottomRows: CGFloat = 196

    let whole: UIImage
    let top: UIImage
    let middle: UIImage
    let bottom: UIImage

    static let shared: CardArtSlices? = {
        guard let source = UIImage(named: "GuestListCard")?.cgImage else { return nil }
        func piece(_ y: CGFloat, _ height: CGFloat) -> UIImage? {
            source.cropping(to: CGRect(x: crop.minX, y: crop.minY + y, width: crop.width, height: height))
                .map { UIImage(cgImage: $0) }
        }
        let middleRows = crop.height - topRows - bottomRows
        guard let whole = piece(0, crop.height),
              let top = piece(0, topRows),
              let middle = piece(topRows, middleRows),
              let bottom = piece(topRows + middleRows, bottomRows)
        else { return nil }
        return CardArtSlices(whole: whole, top: top, middle: middle, bottom: bottom)
    }()
}

// MARK: - Text

/// ExtraBold 48/51.84 on the approved line breaks.
private struct GuestListHeadline: View {
    let lines: [String]
    let focused: AccessibilityFocusState<Bool>.Binding
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .manrope(.extraBold, size: size, designSize: 48, lineHeight: 51.84)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(lines.joined(separator: " ")))
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused(focused)
        .accessibilityIdentifier("guestList.headline")
    }
}

/// Regular 16/24 #A8B0AD, on a 48-pt box as in Figma, so the page below starts where it does
/// there whether the line wraps or not.
private struct GuestListSupport: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        GuestListBodyText(text: text, face: .regular, size: size, alignment: .leading)
            .frame(minHeight: 48 * size / 16, alignment: .top)
            .accessibilityIdentifier("guestList.support")
    }
}

/// "This preview doesn’t make you / visible to anyone." Regular 16/24, centred, on every stage.
private struct GuestListBoundary: View {
    var body: some View {
        GuestListCentredText(text: GuestListCopy.boundary)
            .accessibilityLabel(Text("This preview doesn’t make you visible to anyone."))
            .accessibilityIdentifier("guestList.boundary")
    }
}

private struct GuestListCentredText: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        GuestListBodyText(text: text, face: .regular, size: size, alignment: .center)
            .frame(minHeight: 48 * size / 16, alignment: .top)
    }
}

/// Body text that follows Dynamic Type, every line on the 24-pt pitch (scaled).
private struct GuestListBodyText: View {
    let text: String
    let face: Manrope
    let size: CGFloat
    let alignment: TextAlignment

    var body: some View {
        let extra = max(0, 24 * size / 16 - face.naturalLineHeight(size: size))
        Text(text)
            .font(face.font(size: size))
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .foregroundStyle(GuestListStyle.secondaryText)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

/// A persistent field label, SemiBold 16/24 white. The field itself carries the label for
/// VoiceOver, so this is not read twice.
private struct GuestListFieldLabel: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        Text(text)
            .manrope(.semiBold, size: size, designSize: 16, lineHeight: 24)
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }
}

/// "Interests · optional · up to 3", Medium 14/24 #A8B0AD.
private struct GuestListInterestsLabel: View {
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

    var body: some View {
        Text("Interests · optional · up to 3")
            .manrope(.medium, size: size, designSize: 14, lineHeight: 24)
            .foregroundStyle(GuestListStyle.secondaryText)
            .accessibilityLabel(Text("Interests, optional, up to 3"))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("guestList.interestsLabel")
    }
}

/// "38 / 120", Medium 12/16 #A8B0AD, right-aligned. Updated silently.
private struct GuestListCount: View {
    let count: Int
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 12

    var body: some View {
        Text("\(count) / \(GuestIntroduction.openerLimit)")
            .manrope(.medium, size: size, designSize: 12, lineHeight: 16)
            .foregroundStyle(GuestListStyle.secondaryText)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(Text("\(count) of \(GuestIntroduction.openerLimit) characters"))
            .accessibilityIdentifier("guestList.count")
    }
}

/// Inline help under a field: a symbol and a sentence, so the reason is not carried by colour.
private struct GuestListFieldHelp: View {
    let text: String
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: size, weight: .semibold))
                .accessibilityHidden(true)
            Text(text)
                .font(Manrope.medium.font(size: size))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(GuestListStyle.paperWhite)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "Proximeet" Bold 22 on Figma's 32-pt line, centred on the header row.
private struct GuestListWordmark: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22

    var body: some View {
        Text("Proximeet")
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manrope(.bold, size: size, designSize: 22, lineHeight: 32)
            .foregroundStyle(.white)
    }
}

/// The persistent DEMO PROFILE label: Bold 11/24, 0.9 tracking, cyan, in a 128 × 32 outline
/// (radius 8, cyan at 45 %).
private struct DemoProfileBadge: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 11

    var body: some View {
        Text("DEMO PROFILE")
            .lineLimit(1)
            .manrope(.bold, size: size, designSize: 11, lineHeight: 24, tracking: 0.9)
            .fixedSize()
            .foregroundStyle(GuestListStyle.cyan)
            .padding(.horizontal, 8)
            .frame(minWidth: 128, minHeight: 32)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(GuestListStyle.cyan.opacity(0.45), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Demo profile"))
            .accessibilityIdentifier("guestList.demoBadge")
    }
}

// MARK: - Fields and chips

/// #111415, radius 18, a 1 pt #7A8585 stroke; the text 17 pt from the leading edge, 15 from the
/// trailing edge.
private struct GuestListInput<Field: View>: View {
    let minHeight: CGFloat
    let verticalPadding: CGFloat
    @ViewBuilder let field: Field

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        field
            .padding(.leading, 17)
            .padding(.trailing, 15)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: verticalPadding > 0 ? .topLeading : .leading)
            .background(GuestListStyle.field, in: shape)
            .overlay {
                shape.strokeBorder(GuestListStyle.stroke, lineWidth: 1)
            }
    }
}

/// 116 × 44, radius 18. Unselected: #111415 with a #7A8585 stroke, white SemiBold 14/24.
/// Selected: cyan #38DBE5 with #050606 text and a check mark, so selection is not colour alone.
private struct InterestChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        InterestChipBody(configuration: configuration, selected: selected)
    }
}

private struct InterestChipBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

    var body: some View {
        let scale = size / 14
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .manrope(.semiBold, size: size, designSize: 14, lineHeight: 24)
            .foregroundStyle(selected ? GuestListStyle.ground : Color.white)
            .padding(.horizontal, 22 * scale)
            .frame(minWidth: 116, minHeight: 44)
            .background(selected ? GuestListStyle.cyan : GuestListStyle.field, in: shape)
            .overlay {
                if !selected {
                    shape.strokeBorder(GuestListStyle.stroke, lineWidth: 1)
                }
            }
            .overlay(alignment: .leading) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11 * scale, weight: .bold))
                        .foregroundStyle(GuestListStyle.ground)
                        .padding(.leading, 9 * scale)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 376 × 60, radius 18. Enabled: #F6F7F2 with #050606 SemiBold 18/24. Disabled: #1F2424 with
/// #737D7A (Figma 36:134).
private struct GuestListPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GuestListPrimaryBody(configuration: configuration)
    }
}

private struct GuestListPrimaryBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .manrope(.semiBold, size: size, designSize: 18, lineHeight: 24)
            // Figma's label box is 26 pt at y 17 with the 24-pt line at its top, so the line sits
            // 1 pt above the button's centre.
            .padding(.bottom, 2 * size / 18)
            .foregroundStyle(isEnabled ? GuestListStyle.ground : GuestListStyle.disabledText)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? GuestListStyle.primary : GuestListStyle.disabledFill, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// 376 × 44 text action: Medium 16/24, white, centred.
private struct GuestListSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GuestListSecondaryBody(configuration: configuration)
    }
}

private struct GuestListSecondaryBody: View {
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

// MARK: - Style

enum GuestListStyle {
    static let ground = Color(hex: 0x050606)
    static let secondaryText = Color(hex: 0xA8B0AD)
    static let cyan = Color(hex: 0x38DBE5)
    static let field = Color(hex: 0x111415)
    static let stroke = Color(hex: 0x7A8585)
    static let ink = Color(hex: 0x050606)
    static let paperWhite = Color(hex: 0xF6F7F2)
    static let primary = Color(hex: 0xF6F7F2)
    static let disabledFill = Color(hex: 0x1F2424)
    static let disabledText = Color(hex: 0x737D7A)
}

#if DEBUG
#Preview("Guest List · empty") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .guestList))
}

#Preview("Guest List · fictional example") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .guestListFilled))
}

#Preview("Guest List · card") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .guestListCard))
}
#endif
