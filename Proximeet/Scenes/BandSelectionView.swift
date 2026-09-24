import SwiftUI
import ProximeetDomain

/// B1 — choose a band. Selection is immediate and replaces any earlier choice; the primary
/// action confirms and moves straight to the signal scene, where the same band appears in
/// its secured pose. Nothing waits for the arrival or selection animations.
struct BandSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var hasArrived = false

    var body: some View {
        let selected = session.draft.band
        ScreenScaffold(title: "Band", step: 5) {
            SceneHeader(title: "Which band tonight?", subtitle: "One intent. Your kind of connection.")

            VStack(spacing: 10) {
                ForEach(BandIntent.allCases) { intent in
                    BandOption(intent: intent, isSelected: intent == selected) {
                        session.selectBand(intent)
                    }
                    // Measured arrival: offset and partial opacity only, so every band is
                    // visible and tappable from the first frame.
                    .offset(y: hasArrived ? 0 : 18)
                    .opacity(hasArrived ? 1 : 0.35)
                    .animation(adaptive.arrivalAnimation(index: intent.order), value: hasArrived)
                }
            }

            Footnote(text: "A draft choice you can change. \(DraftVisibility.notVisibleToAnyone.notice).")
        } actions: {
            Button {
                session.confirmBand()
            } label: {
                Text(selected.map { "Choose \($0.title)" } ?? "Select a band")
            }
            .buttonStyle(.proximeetPrimary)
            .disabled(selected == nil)
            .accessibilityHint(Text(selected == nil ? "Select a band first." : "Secures this band and moves to your signal."))
        }
        .sensoryFeedback(.selection, trigger: selected) { _, newValue in
            newValue != nil
        }
        .onAppear {
            hasArrived = true
        }
    }
}

#if DEBUG
#Preview("B1 · no selection") {
    NavigationStack { BandSelectionView() }
        .environment(PreviewFixtures.session(at: .band))
}

#Preview("B1 · Dating selected") {
    NavigationStack { BandSelectionView() }
        .environment(PreviewFixtures.session(at: .bandSelected, band: .dating))
}

#Preview("B1 · largest text") {
    NavigationStack { BandSelectionView() }
        .environment(PreviewFixtures.session(at: .bandSelected, band: .business))
        .dynamicTypeSize(.accessibility5)
}

#Preview("B1 · Reduce Motion presentation") {
    NavigationStack { BandSelectionView() }
        .environment(PreviewFixtures.session(at: .bandSelected, band: .activity))
        .environment(\.prefersReducedMotionPreview, true)
}
#endif
