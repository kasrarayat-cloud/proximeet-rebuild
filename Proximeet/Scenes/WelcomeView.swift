import SwiftUI
import ProximeetDomain

/// Scene 1 — honest functional scaffold. Starts the demo; there is no account or sign-in.
struct WelcomeView: View {
    @Environment(DemoSession.self) private var session
    @State private var isConfirmingClear = false

    var body: some View {
        ScreenScaffold(title: "Welcome", step: nil) {
            SceneHeader(
                title: "Show how you want to meet.",
                subtitle: "A short demo of choosing a band and a signal for the places you go."
            )
            WorldGrid()
            NoticeBanner(
                text: "No account and no sign-in. What you enter stays on this phone, in memory, for this demo run only.",
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

/// The six social worlds as a simple 2 × 3 scaffold. The bespoke miniature environments
/// in the Social Objects boards are future artwork.
private struct WorldGrid: View {
    private struct World: Identifiable {
        let title: String
        let symbol: String
        let tint: Color
        var id: String { title }
    }

    private let worlds = [
        World(title: "Cafés", symbol: "cup.and.saucer", tint: Palette.business),
        World(title: "Creative spaces", symbol: "paintpalette", tint: Palette.dating),
        World(title: "Events", symbol: "ticket", tint: Palette.social),
        World(title: "Games", symbol: "gamecontroller", tint: Palette.activity),
        World(title: "Activities", symbol: "figure.run", tint: Palette.activity),
        World(title: "Nights out", symbol: "music.note", tint: Palette.social),
    ]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(worlds) { world in
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: world.symbol)
                        .font(.title2)
                        .foregroundStyle(world.tint)
                    Text(world.title)
                        .textRole(.label)
                        .foregroundStyle(Palette.porcelain)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background(Palette.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Places this demo imagines: cafés, creative spaces, events, games, activities and nights out."))
    }
}

#if DEBUG
#Preview("Welcome") {
    NavigationStack { WelcomeView() }
        .environment(DemoSession())
}
#endif
