import SwiftUI
import ProximeetDomain

/// B2 — set a signal. The confirmed band arrives in its secured pose; choosing a tag seats
/// it on the clasp immediately. Confirming moves to "Ready for check-in". Nothing here is
/// visible to anyone.
struct SignalSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let band = session.draft.band
        let signal = session.draft.signal
        ScreenScaffold(title: "Signal", step: 6) {
            SceneHeader(title: "Make your hello clear.", subtitle: band?.title)

            if let band {
                BandStage(intent: band, signal: signal, playsSecuringOnAppear: true)
            }

            tagChoices(selected: signal)

            chosenSignal(band: band, signal: signal)
        } actions: {
            Button("Set my signal") {
                session.confirmSignal()
            }
            .buttonStyle(.proximeetPrimary)
            .disabled(signal == nil)
            .accessibilityHint(Text(signal == nil ? "Choose a tag first." : "Shows your demo summary."))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: signal) { _, newValue in
            newValue != nil
        }
    }

    /// 2 × 2 grid normally; a single column at accessibility text sizes.
    @ViewBuilder
    private func tagChoices(selected: ApproachSignal?) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(ApproachSignal.allCases) { option in
                    tagOption(option, selected: selected)
                }
            }
        } else {
            Grid(horizontalSpacing: 3, verticalSpacing: 2) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            tagOption(ApproachSignal.allCases[row * 2 + column], selected: selected)
                        }
                    }
                }
            }
        }
    }

    private func tagOption(_ option: ApproachSignal, selected: ApproachSignal?) -> some View {
        SignalOption(signal: option, isSelected: option == selected) {
            session.selectSignal(option)
        }
    }

    private func chosenSignal(band: BandIntent?, signal: ApproachSignal?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(signal.map { "Chosen signal: \($0.title)" } ?? "No signal chosen yet")
                .textRole(.label)
                .foregroundStyle(Palette.porcelain)
            if let signal, let band, let profile = session.draft.profile {
                Footnote(text: "Preview: \(profile.firstName) · \(band.title) band · \(signal.title)")
            }
            Footnote(text: DraftVisibility.notVisibleToAnyone.notice)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("B2 · no tag") {
    NavigationStack { SignalSelectionView() }
        .environment(PreviewFixtures.session(at: .signal))
}

#Preview("B2 · Chat first seated") {
    NavigationStack { SignalSelectionView() }
        .environment(PreviewFixtures.session(at: .signalSelected, band: .social, signal: .chatFirst))
}

#Preview("B2 · largest text") {
    NavigationStack { SignalSelectionView() }
        .environment(PreviewFixtures.session(at: .signalSelected, band: .dating, signal: .withMyCrew))
        .dynamicTypeSize(.accessibility5)
}

#Preview("B2 · Reduce Motion presentation") {
    NavigationStack { SignalSelectionView() }
        .environment(PreviewFixtures.session(at: .signalSelected, band: .activity, signal: .justLooking))
        .environment(\.prefersReducedMotionPreview, true)
}
#endif
