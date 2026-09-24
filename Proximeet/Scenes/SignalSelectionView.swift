import SwiftUI
import ProximeetDomain

/// B2 — set a signal. The confirmed band arrives secured as a larger assembled object;
/// choosing a compact plate clips a smaller copy of it to the band's clasp immediately.
/// Only the selected plate's full explanation appears below the grid. Confirming moves to
/// "Ready for check-in". Nothing here is visible to anyone.
struct SignalSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Adaptive private var adaptive

    var body: some View {
        let band = session.draft.band
        let signal = session.draft.signal
        ScreenScaffold(title: "Signal", step: 6) {
            SceneHeader(
                title: "Make your\nhello clear.",
                subtitle: band.map { "Clip one tag to your \($0.title) band." }
            )

            if let band {
                // 146 pt loop → about 319 × 175 pt with the plate mounted.
                BandStage(intent: band, signal: signal, maxLoopHeight: 146, playsSecuringOnAppear: true)
            }

            plateChoices(selected: signal, accent: band?.tint ?? Palette.porcelain)

            selectedExplanation(signal)
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

    /// 2 × 2 compact landscape plates with equal row heights; one column at
    /// accessibility text sizes.
    @ViewBuilder
    private func plateChoices(selected: ApproachSignal?, accent: Color) -> some View {
        let signals = ApproachSignal.allCases
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                ForEach(signals) { option in
                    plate(option, selected: selected, accent: accent)
                }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(0..<(signals.count + 1) / 2, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(signals[(row * 2)..<min(row * 2 + 2, signals.count)]) { option in
                            plate(option, selected: selected, accent: accent)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func plate(_ option: ApproachSignal, selected: ApproachSignal?, accent: Color) -> some View {
        SignalOption(signal: option, isSelected: option == selected, accent: accent) {
            session.selectSignal(option)
        }
        .frame(maxWidth: .infinity)
    }

    /// The selected plate's full explanation, then the demo visibility notice.
    private func selectedExplanation(_ signal: ApproachSignal?) -> some View {
        let quiet = Palette.quiet(increasedContrast: adaptive.increaseContrast)
        return VStack(alignment: .leading, spacing: 8) {
            if let signal {
                Label {
                    Text("\(Text(signal.title).fontWeight(.semibold)): \(signal.summary)")
                        .foregroundStyle(Palette.porcelain)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: signal.symbolName)
                        .foregroundStyle(Palette.porcelain)
                        .accessibilityHidden(true)
                }
            } else {
                Text("Choose the tag that matches how you'd like to be approached.")
                    .foregroundStyle(quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label {
                Text(DraftVisibility.notVisibleToAnyone.notice)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "eye.slash")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(quiet)
        }
        .textRole(.supporting)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
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
