import SwiftUI
import ProximeetDomain

/// Scene 4 — bright roster stock held by an aluminium clip. Only the guest's own entry
/// appears; there are no fixture attendees. Editing happens in a native sheet that closes
/// only after a successful save.
struct GuestListView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var isEditing = false
    @State private var hasAppeared = false

    var body: some View {
        let profile = session.draft.profile
        ScreenScaffold(title: "Guest list", step: 4) {
            SceneHeader(
                title: "Add yourself\nto the list.",
                subtitle: "Your first name and three interests. Only you appear on this demo list."
            )
            RosterSheet {
                if let profile {
                    GuestEntry(profile: profile) {
                        isEditing = true
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No entry yet")
                            .textRole(.section)
                        Text("Add your first name and three interests.")
                            .textRole(.body)
                            .foregroundStyle(Palette.stockInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .modifier(SettleEntrance(
                settled: hasAppeared,
                offsetY: 14,
                startScale: 0.98,
                animation: adaptive.paperSettleAnimation
            ))
            .onAppear {
                hasAppeared = true
            }
        } actions: {
            if profile == nil {
                Button("Add yourself") {
                    isEditing = true
                }
                .buttonStyle(.proximeetPrimary(showsArrow: false))
            } else {
                Button("Continue to band") {
                    session.continueFromGuestList()
                }
                .buttonStyle(.proximeetPrimary)
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditorSheet(profile: profile)
        }
    }
}

/// Clipped roster stock with a printed heading and one ruled entry.
struct RosterSheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        PaperSheet {
            HStack(alignment: .firstTextBaseline) {
                Text("Guest list")
                    .textRole(.section)
                Spacer(minLength: 12)
                Text("Demo")
                    .textRole(.label)
                    .foregroundStyle(Palette.stockInk)
            }
            .accessibilityElement(children: .combine)
            Rectangle()
                .fill(Palette.paperRule)
                .frame(height: 1.5)
                .accessibilityHidden(true)
            content
        }
    }
}

/// The guest's own row, using exactly the saved profile values.
struct GuestEntry: View {
    let profile: GuestProfile
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("You")
                    .textRole(.label)
                    .foregroundStyle(Palette.stockInk)
                Text(profile.firstName)
                    .textRole(.title)
                    .fixedSize(horizontal: false, vertical: true)
                InterestChips(interests: profile.interests)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(profile.firstName). Interests: \(profile.interests.joined(separator: ", "))"))

            Button("Edit", action: onEdit)
                .buttonStyle(EditLinkStyle(tint: Palette.carbon))
                .accessibilityLabel(Text("Edit profile"))
        }
    }
}

struct InterestChips: View {
    let interests: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
    }

    private var chips: some View {
        ForEach(interests, id: \.self) { interest in
            Text(interest)
                .textRole(.label)
                .foregroundStyle(Palette.carbon)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.stockChip, in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("Guest list · empty") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .guestList))
}

#Preview("Guest list · fixture") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .band))
}
#endif
