import SwiftUI

/// Chapter 01 — the approved Welcome, "A Place Opens" (handoff `LAYOUT_SPEC.json`, Figma
/// frame 1:35, a 440 × 956 canvas: the iPhone 17 Pro Max screen).
///
/// Native text and controls over the three original hero poses. This prototype has no
/// account system: "Continue with Apple" answers with an honest notice, and "More options"
/// offers "Continue the demo (no account)", the route into the approved Birthday.
struct WelcomeView: View {
    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ScrollView(.vertical) {
                WelcomeStack(
                    viewportHeight: proxy.size.height + insets.top + insets.bottom,
                    // Brand row at y 64: just below the status area on Dynamic Island phones,
                    // and never tighter than 2 pt under it elsewhere.
                    topMargin: max(insets.top + 2, 64),
                    // "18+ only" ends 27 pt above the screen edge (929 of 956).
                    bottomMargin: 27
                ) {
                    BrandRow()
                    WelcomeHero()
                    WelcomeCopy()
                    WelcomeActions()
                    EligibilityNote()
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(.container, edges: .vertical)
        }
        .background(WelcomeStyle.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Exact values from `LAYOUT_SPEC.json`. They belong to the approved Welcome composition
/// and are deliberately not merged into `Palette`, whose Social Objects tokens are close but
/// different (Carbon #080A0B, Porcelain #F5F6F2, quiet text #AAB0B5).
private enum WelcomeStyle {
    static let ground = Color(hex: 0x050606)
    static let buttonFill = Color(hex: 0xF6F7F2)
    static let secondaryText = Color(hex: 0xA8B0AD)
    /// The brand row's "cyan presence" dot.
    static let presence = Color(hex: 0x38DBE5)
}

// MARK: - Layout

/// Stacks the five Welcome rows on the approved gaps and gives the hero the height that is
/// left, up to a full-width square. On the 440 × 956 reference that is exactly the 440 × 440
/// hero at y 128. Shorter screens get a smaller hero, centred. Only when the hero reaches its
/// minimum (large text on a small phone) does the page grow and scroll, so nothing overlaps.
private struct WelcomeStack: Layout {
    let viewportHeight: CGFloat
    let topMargin: CGFloat
    let bottomMargin: CGFloat

    /// After the brand, hero, copy and actions: Figma 96→128, 568→570, 729→772, 888→913.
    private static let gaps: [CGFloat] = [32, 2, 43, 25]
    private static let heroIndex = 1
    private static let minimumHero: CGFloat = 140

    private struct Plan {
        /// Vertical slot per row; the hero's slot can exceed its square on tall screens.
        var slots: [CGFloat]
        var heroSide: CGFloat
        var height: CGFloat
    }

    private func plan(width: CGFloat, subviews: Subviews) -> Plan {
        var slots = subviews.indices.map { index in
            index == Self.heroIndex
                ? 0
                : subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        let gaps = Self.gaps.prefix(max(subviews.count - 1, 0)).reduce(0, +)
        let fixed = topMargin + bottomMargin + gaps + slots.reduce(0, +)
        let available = viewportHeight - fixed
        let side = min(width, max(available, Self.minimumHero))
        if slots.indices.contains(Self.heroIndex) {
            slots[Self.heroIndex] = max(available, side)
        }
        // When the hero fits, the page is exactly the viewport (no floating-point overshoot
        // that could make the scroll view think it has something to scroll).
        let height = available >= side ? viewportHeight : fixed + side
        return Plan(slots: slots, heroSide: side, height: height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let plan = plan(width: width, subviews: subviews)
        return CGSize(width: width, height: max(plan.height, viewportHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(width: bounds.width, subviews: subviews)
        var y = bounds.minY + topMargin
        for index in subviews.indices {
            let slot = plan.slots[index]
            if index == Self.heroIndex {
                subviews[index].place(
                    at: CGPoint(x: bounds.midX, y: y + slot / 2),
                    anchor: .center,
                    proposal: ProposedViewSize(width: plan.heroSide, height: plan.heroSide)
                )
            } else {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width, height: slot)
                )
            }
            y += slot + (index < Self.gaps.count ? Self.gaps[index] : 0)
        }
    }
}

// MARK: - Rows

/// Cyan presence dot (8 × 8 at x 32) and the "Proximeet" wordmark (Bold 24/32, −0.8).
private struct BrandRow: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 24

    var body: some View {
        let scale = size / 24
        HStack(spacing: 8 * scale) {
            Circle()
                .fill(WelcomeStyle.presence)
                .frame(width: 8 * scale, height: 8 * scale)
                .accessibilityHidden(true)
            Text("Proximeet")
                .font(Manrope.bold.font(size: size))
                .tracking(-0.8 * scale)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(height: 32 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
    }
}

/// Headline (ExtraBold 56/59, −2.2) with its approved line break, and the supporting line
/// (Regular 17/25, #A8B0AD) 16 pt below it.
private struct WelcomeCopy: View {
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var supportingSize: CGFloat = 17

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Make room")
                    .manrope(.extraBold, size: headlineSize, designSize: 56, lineHeight: 59, tracking: -2.2)
                Text("for a hello.")
                    .manrope(.extraBold, size: headlineSize, designSize: 56, lineHeight: 59, tracking: -2.2)
            }
            .foregroundStyle(.white)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Make room for a hello."))
            .accessibilityAddTraits(.isHeader)

            Text("Real places. New people. Your way.")
                .manrope(.regular, size: supportingSize, designSize: 17, lineHeight: 25)
                .foregroundStyle(WelcomeStyle.secondaryText)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
    }
}

/// "18+ only" (Medium 12/16, +0.2, #A8B0AD). Informational, not a control.
private struct EligibilityNote: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 12

    var body: some View {
        Text("18+ only")
            .manrope(.medium, size: size, designSize: 12, lineHeight: 16, tracking: 0.2)
            .foregroundStyle(WelcomeStyle.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
    }
}

// MARK: - Actions

/// Neither control signs anybody in: there is no authentication integration in this app.
/// "Continue with Apple" answers with a native notice and changes no state. "More options"
/// offers the demo (no account), which opens Birthday, or Cancel.
private struct WelcomeActions: View {
    @Environment(DemoSession.self) private var session
    @State private var isShowingAppleNotice = false
    @State private var isShowingMoreOptions = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                isShowingAppleNotice = true
            } label: {
                Text("Continue with Apple")
            }
            .buttonStyle(ContinueWithAppleStyle())
            .accessibilityIdentifier("welcome.continueWithApple")
            .alert("Apple sign-in isn’t connected", isPresented: $isShowingAppleNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This prototype doesn’t connect to Apple yet. Nothing was sent or saved.")
            }

            // The demo route into the approved Birthday: an explicit, labelled choice that
            // creates no account and no signed-in or verified state. An alert, not a
            // confirmation dialog: on iOS 26 a dialog anchored to its button opens as a popover
            // and drops its Cancel action, and this choice must always offer Cancel.
            Button("More options") {
                isShowingMoreOptions = true
            }
            .buttonStyle(MoreOptionsStyle())
            .accessibilityIdentifier("welcome.moreOptions")
            .alert("More options", isPresented: $isShowingMoreOptions) {
                Button("Continue the demo (no account)") {
                    session.begin()
                }
                .accessibilityIdentifier("welcome.continueDemo")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This prototype doesn’t include other sign-in methods yet.")
            }
        }
        .padding(.horizontal, 32)
    }
}

/// The approved light "Continue with Apple" control: 60 pt, #F6F7F2, radius 18, a dark Apple
/// mark in a 22 × 26 box and the label (SemiBold 18/24) 8 pt after it.
///
/// Deliberately not `SignInWithAppleButton`: tapping the system control starts a real
/// authorization request, which this prototype must not make.
private struct ContinueWithAppleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ContinueWithAppleBody(configuration: configuration)
    }
}

private struct ContinueWithAppleBody: View {
    let configuration: ButtonStyleConfiguration
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18
    @Adaptive private var adaptive

    var body: some View {
        let scale = size / 18
        // Figma's radius 18 with its default (zero) corner smoothing is a circular arc.
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        HStack(spacing: 8 * scale) {
            // The mark's ink is 14 × 16 in the reference, centred in its 22 × 26 box.
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
                .frame(width: 14 * scale, height: 16 * scale)
                .frame(width: 22 * scale, height: 26 * scale)
                .accessibilityHidden(true)
            configuration.label
                .manrope(.semiBold, size: size, designSize: 18, lineHeight: 24)
                .multilineTextAlignment(.leading)
                // Figma's label box is 187 pt wide around 174 pt of glyphs. Keeping the box
                // keeps the approved optical position of the mark and label in the button;
                // when space is shorter (large text), the label wraps inside the button.
                .frame(maxWidth: 187 * scale, alignment: .leading)
        }
        .foregroundStyle(WelcomeStyle.ground)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(WelcomeStyle.buttonFill, in: shape)
        .contentShape(shape)
        .scaleEffect(configuration.isPressed && !adaptive.reduceMotion ? 0.98 : 1)
        .opacity(configuration.isPressed ? 0.88 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// "More options": Regular 17/25, white, centred in a full-width 44 pt target.
private struct MoreOptionsStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MoreOptionsBody(configuration: configuration)
    }
}

private struct MoreOptionsBody: View {
    let configuration: ButtonStyleConfiguration
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 17

    var body: some View {
        configuration.label
            .manrope(.regular, size: size, designSize: 17, lineHeight: 25)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Hero

/// The approved 2D pose study: three static illustrations, crossfaded. It is not a 3D model
/// and not a continuous fold.
///
/// Closed holds for 0.4 s, blends linearly to the opening pose by 0.85 s and to the settled
/// pose by 1.4 s, then holds. It runs once per appearance of this Welcome and never repeats.
/// Reduce Motion shows the settled pose from the first frame. Leaving the screen completes the
/// sequence at once, so nothing is still animating when the user returns. The hero is
/// decorative, hidden from VoiceOver, and does not take touches.
private struct WelcomeHero: View {
    @Adaptive private var adaptive
    @State private var isOpening = false
    @State private var isFinished = false

    var body: some View {
        ZStack {
            if isFinished || adaptive.reduceMotion {
                pose(.settled)
            } else {
                pose(.closed)
                // Scoped animations: only the opacity blends, never a size or position change
                // that happens to land in the same update.
                pose(.opening)
                    .animation(.linear(duration: Motion.welcomeToOpening).delay(Motion.welcomeClosedHold)) {
                        $0.opacity(isOpening ? 1 : 0)
                    }
                pose(.settled)
                    .animation(
                        .linear(duration: Motion.welcomeToSettled)
                            .delay(Motion.welcomeClosedHold + Motion.welcomeToOpening)
                    ) {
                        $0.opacity(isOpening ? 1 : 0)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isOpening = true
        }
        .onDisappear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isFinished = true
            }
        }
    }

    /// Each pose sits on the page colour, so fading one in over another blends the two
    /// composed frames, as the motion study does. Without it, the transparent margins of the
    /// upper pose would leave the lower one showing at full strength.
    private func pose(_ which: HeroPose) -> some View {
        which.image
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fit)
            .background(WelcomeStyle.ground)
    }
}

/// The three original 1254 × 1254 RGBA poses from the handoff's `assets/`, unmodified.
private enum HeroPose {
    case closed
    case opening
    case settled

    var image: Image {
        switch self {
        case .closed: Image(decorative: "WelcomeClosed")
        case .opening: Image(decorative: "WelcomeOpening")
        case .settled: Image(decorative: "WelcomeSettled")
        }
    }
}

#if DEBUG
#Preview("Welcome") {
    NavigationStack { WelcomeView() }
        .environment(DemoSession())
}

#Preview("Welcome · largest text") {
    NavigationStack { WelcomeView() }
        .environment(DemoSession())
        .dynamicTypeSize(.accessibility5)
}

#Preview("Welcome · Reduce Motion") {
    NavigationStack { WelcomeView() }
        .environment(DemoSession())
        .environment(\.prefersReducedMotionPreview, true)
}
#endif
