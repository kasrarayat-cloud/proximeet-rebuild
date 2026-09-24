import SwiftUI
import ProximeetDomain

struct RootView: View {
    @Environment(DemoSession.self) private var session

    var body: some View {
        @Bindable var session = session
        NavigationStack(path: $session.path) {
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
            DemoPassView()
        case .guestList:
            GuestListView()
        case .band:
            BandSelectionView()
        case .signal:
            SignalSelectionView()
        case .readyForCheckIn:
            ReadyForCheckInView()
        }
    }
}
