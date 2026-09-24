import SwiftUI
import ProximeetDomain

/// End of the demo. Shows the real draft profile, band and tag, and states plainly that
/// nothing is visible to anyone. There is no check-in, venue, presence or verification.
struct ReadyForCheckInView: View {
    @Environment(DemoSession.self) private var session
    @State private var isEditingProfile = false
    @State private var isConfirmingReset = false

    var body: some View {
        ScreenScaffold(title: "Ready", step: nil) {
            if let ready = session.readiness {
                SceneHeader(title: "Ready for check-in.", subtitle: "Your demo draft, exactly as you set it.")
                NoticeBanner(text: ready.visibility.notice)
                BandStage(intent: ready.band, signal: ready.signal)
                SummaryCard(
                    ready: ready,
                    onEditProfile: { isEditingProfile = true },
                    onChangeBand: { session.returnTo(.band) },
                    onChangeSignal: { session.returnTo(.signal) }
                )
                Footnote(text: "Check-in isn't part of this demo. Nothing you entered is saved, shared or verified.")
            } else {
                SceneHeader(title: "Draft incomplete.", subtitle: "Go back to finish your choices.")
            }
        } actions: {
            Button("Clear demo and start over", role: .destructive) {
                isConfirmingReset = true
            }
            .buttonStyle(.proximeetDestructive)
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

private struct SummaryCard: View {
    let ready: ReadyForCheckIn
    let onEditProfile: () -> Void
    let onChangeBand: () -> Void
    let onChangeSignal: () -> Void
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 18) {
            SummaryRow(
                label: "Guest",
                value: ready.profile.firstName,
                detail: ready.profile.interests.joined(separator: " · "),
                actionTitle: "Edit profile",
                action: onEditProfile
            )
            divider
            SummaryRow(
                label: "Band",
                value: ready.band.title,
                detail: ready.band.tagline,
                swatch: ready.band.tint,
                actionTitle: "Change band",
                action: onChangeBand
            )
            divider
            SummaryRow(
                label: "Signal",
                value: ready.signal.title,
                detail: ready.signal.summary,
                actionTitle: "Change signal",
                action: onChangeSignal
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.graphite, in: shape)
        .overlay {
            shape.strokeBorder(
                adaptive.increaseContrast ? Palette.porcelain : Palette.hairline,
                lineWidth: adaptive.increaseContrast ? 2 : 1
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.hairline)
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
    @Adaptive private var adaptive

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .textRole(.label)
                    .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
                HStack(spacing: 10) {
                    if let swatch {
                        Capsule()
                            .fill(swatch)
                            .frame(width: 28, height: 12)
                            .accessibilityHidden(true)
                    }
                    Text(value)
                        .textRole(.section)
                        .foregroundStyle(Palette.porcelain)
                }
                Text(detail)
                    .textRole(.supporting)
                    .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Button(actionTitle, action: action)
                .buttonStyle(EditLinkStyle())
        }
    }
}

#if DEBUG
#Preview("Ready · fixture") {
    NavigationStack { ReadyForCheckInView() }
        .environment(PreviewFixtures.session(at: .ready, band: .business, signal: .comeSayHi))
}

#Preview("Ready · largest text") {
    NavigationStack { ReadyForCheckInView() }
        .environment(PreviewFixtures.session(at: .ready, band: .social, signal: .justLooking))
        .dynamicTypeSize(.accessibility5)
}
#endif
