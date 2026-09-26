import SwiftUI
import ProximeetDomain

/// End of the demo. The compact assembled band with its plate, then the real draft
/// profile, band and tag on bright paper, each with an edit affordance. It states plainly
/// that this is a local demo that nobody can see. There is no check-in, venue, presence
/// or verification.
struct ReadyForCheckInView: View {
    @Environment(DemoSession.self) private var session
    @State private var isEditingProfile = false
    @State private var isConfirmingReset = false

    var body: some View {
        ScreenScaffold(title: "Ready", step: nil) {
            if let ready = session.readiness {
                SceneHeader(
                    title: "Your demo\nis ready.",
                    subtitle: "Your band and signal, together."
                )
                SignatureBandHero(intent: ready.band, signal: ready.signal, height: 156, interactive: false)
                SummarySheet(
                    ready: ready,
                    onEditProfile: { isEditingProfile = true },
                    onChangeBand: { session.returnTo(.band) },
                    onChangeSignal: { session.returnTo(.signal) }
                )
                Footnote(text: "Private demo. Nothing is shared or verified.")
            } else {
                SceneHeader(title: "Draft\nincomplete.", subtitle: "Go back to finish your choices.")
            }
        } actions: {
            Button(role: .destructive) {
                isConfirmingReset = true
            } label: {
                Label("Clear demo and start over", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.proximeetQuiet)
        }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditorSheet(profile: session.draft.profile)
        }
        .confirmationDialog("Clear this demo?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Clear demo data", role: .destructive) {
                session.reset()
            }
            Button("Keep my draft", role: .cancel) {}
        } message: {
            Text("Your birthday, name, interests, band and signal will be removed.")
        }
    }
}

/// The draft summary printed on bright paper stock (unclipped), Carbon ink throughout.
private struct SummarySheet: View {
    let ready: ReadyForCheckIn
    let onEditProfile: () -> Void
    let onChangeBand: () -> Void
    let onChangeSignal: () -> Void

    var body: some View {
        PaperSheet(clipped: false) {
            SummaryRow(
                label: "Guest",
                value: ready.profile.firstName,
                detail: ready.profile.interests.joined(separator: " · "),
                actionTitle: "Edit profile",
                action: onEditProfile
            )
            rule
            SummaryRow(
                label: "Band",
                value: ready.band.title,
                detail: ready.band.tagline,
                swatch: ready.band.tint,
                actionTitle: "Change band",
                action: onChangeBand
            )
            rule
            SummaryRow(
                label: "Signal",
                value: ready.signal.title,
                detail: ready.signal.summary,
                actionTitle: "Change signal",
                action: onChangeSignal
            )
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Palette.paperRule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    let detail: String
    var swatch: Color?
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .textRole(.label)
                        .foregroundStyle(Palette.stockInk)
                    HStack(spacing: 10) {
                        if let swatch {
                            Capsule()
                                .fill(swatch)
                                .overlay { Capsule().strokeBorder(Palette.carbon.opacity(0.35), lineWidth: 1) }
                                .frame(width: 28, height: 12)
                                .accessibilityHidden(true)
                        }
                        Text(value)
                            .textRole(.section)
                            .foregroundStyle(Palette.carbon)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Button(actionTitle, action: action)
                    .buttonStyle(EditLinkStyle(tint: Palette.carbon))
                    .frame(minWidth: 44, minHeight: 44)
            }
            Text(detail)
                .textRole(.supporting)
                .foregroundStyle(Palette.stockInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

}

#if DEBUG
#Preview("Ready · fixture") {
    NavigationStack { ReadyForCheckInView() }
        .environment(PreviewFixtures.session(at: .ready, band: .business, signal: .okayToSayHello))
}

#Preview("Ready · largest text") {
    NavigationStack { ReadyForCheckInView() }
        .environment(PreviewFixtures.session(at: .ready, band: .social, signal: .chatFirst))
        .dynamicTypeSize(.accessibility5)
}
#endif
