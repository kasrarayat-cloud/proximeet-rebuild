import SwiftUI
import ProximeetDomain

/// B1 — choose a band. Four complete woven loops in wide, shallow rows.
/// Rows expand naturally at accessibility text sizes. Selection is immediate and replaces any earlier choice; the
/// primary action confirms and moves straight to the signal scene, where the same
/// assembled band appears secured. Nothing waits for the arrival or selection animations.
struct BandSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var hasArrived = false

    var body: some View {
        let selected = session.draft.band
        ScreenScaffold(title: "Band", step: 5) {
            SceneHeader(title: "Which band\ntonight?", subtitle: "One intent. Your kind of connection.")

            bandChoices(selected: selected)
                .padding(.top, 4)

            Footnote(text: DraftVisibility.notVisibleToAnyone.notice)
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

    /// Four wide, shallow objects like the showcase. Larger text expands each row
    /// naturally and scrolls; no fixed height can hide a caption or action.
    private func bandChoices(selected: BandIntent?) -> some View {
        VStack(spacing: 6) {
            ForEach(BandIntent.allCases) { intent in
                option(intent, selected: selected)
            }
        }
    }

    private func option(_ intent: BandIntent, selected: BandIntent?) -> some View {
        BandOption(intent: intent, isSelected: intent == selected) {
            session.selectBand(intent)
        }
        .frame(maxWidth: .infinity)
        // Measured arrival: offset and partial opacity only, so every band is visible
        // and tappable from the first frame.
        .offset(y: hasArrived || !adaptive.playsEntrances ? 0 : 18)
        .opacity(hasArrived || !adaptive.playsEntrances ? 1 : 0.35)
        .animation(adaptive.arrivalAnimation(index: intent.order), value: hasArrived)
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
