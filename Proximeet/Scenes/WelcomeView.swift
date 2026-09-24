import SwiftUI
import ProximeetDomain

/// Scene 1 — the six social worlds, then the demo's promise. Starts the demo; there is no
/// account or sign-in.
struct WelcomeView: View {
    @Environment(DemoSession.self) private var session
    @State private var isConfirmingClear = false

    var body: some View {
        ScreenScaffold(title: "Welcome", step: nil) {
            WorldsTableau()
            SceneHeader(
                title: "Show how you\nwant to meet.",
                subtitle: "A short demo: choose a band and a signal for the places you go."
            )
            NoticeBanner(
                text: "Demo only. No account or sign-in; what you enter stays in memory on this phone.",
                systemImage: "lock"
            )
        } actions: {
            Button("Start the demo") {
                session.begin()
            }
            .buttonStyle(.proximeetPrimary)

            if session.hasEnteredData {
                Button("Clear entered details") {
                    isConfirmingClear = true
                }
                .buttonStyle(.proximeetSecondary)
            }
        }
        .confirmationDialog("Clear entered details?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear demo data", role: .destructive) {
                session.reset()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Your birthday, name, interests, band and signal will be removed.")
        }
    }
}

/// The lead-supplied `SocialWorldsWelcome` tableau (1024 × 1536: six miniature worlds in
/// two columns and three rows, no text). The whole composition is always shown, never
/// cropped: its height adapts to the visible screen and the width follows the aspect.
/// A 2% edge fade blends its near-black ground (#030607) into the Carbon stage.
private struct WorldsTableau: View {
    private static let aspect: CGFloat = 1024.0 / 1536.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Adaptive private var adaptive
    @State private var hasAppeared = false

    var body: some View {
        // Leave room for the copy and notice; less at accessibility text sizes.
        let share: CGFloat = dynamicTypeSize.isAccessibilitySize ? 0.34 : 0.48
        Image("SocialWorldsWelcome")
            .resizable()
            .interpolation(.high)
            .aspectRatio(Self.aspect, contentMode: .fit)
            .mask {
                EdgeFade(axis: .vertical)
                    .mask { EdgeFade(axis: .horizontal) }
            }
            .containerRelativeFrame(.vertical) { length, _ in
                length * share
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("Illustration of six miniature places to meet people"))
            .modifier(SettleEntrance(
                settled: hasAppeared,
                startScale: 0.96,
                animation: adaptive.welcomeAnimation
            ))
            .onAppear {
                hasAppeared = true
            }
    }
}

/// Opaque centre with a short fade to clear at both ends of one axis.
private struct EdgeFade: View {
    let axis: Axis

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.02),
                .init(color: .black, location: 0.98),
                .init(color: .clear, location: 1),
            ],
            startPoint: axis == .vertical ? .top : .leading,
            endPoint: axis == .vertical ? .bottom : .trailing
        )
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
#endif
