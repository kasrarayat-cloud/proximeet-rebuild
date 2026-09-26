import SwiftUI
import ProximeetDomain

struct RootView: View {
    @Environment(DemoSession.self) private var session

    var body: some View {
        @Bindable var session = session
        NavigationStack(path: $session.navigationPath) {
            WelcomeView()
                .navigationDestination(for: DemoScene.self) { scene in
                    SceneDestination(scene: scene)
                }
        }
        .id(session.resetGeneration)
        .tint(Palette.porcelain)
        .preferredColorScheme(.dark)
    }
}

private struct SceneDestination: View {
    let scene: DemoScene

    var body: some View {
        switch scene {
        case .welcome:
            WelcomeView()
        case .birthday:
            BirthdayView()
        case .demoPass:
            PassView()
        case .guestList:
            GuestListView()
        case .band:
            WristbandView()
        case .signal:
            SignalView()
        case .readyForCheckIn:
            ReadyForCheckInView()
        case .places, .placeDetail, .placeExplanation:
            // One destination: Places shows its detail and explanation stages itself.
            PlacesView()
        }
    }
}
