import SwiftUI
import ProximeetDomain

/// Scene 4 — honest functional scaffold. Only the guest's own entry appears; no fixture
/// attendees. Editing happens in a native sheet that closes only after a successful save.
struct GuestListView: View {
    @Environment(DemoSession.self) private var session
    @State private var isEditing = false

    var body: some View {
        let profile = session.draft.profile
        ScreenScaffold(title: "Guest list", step: 4) {
            SceneHeader(
                title: "Add yourself to the list.",
                subtitle: "Your first name and three interests. Only you appear on this demo list."
            )
            RosterBoard {
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

/// Bright roster stock held by an aluminium clip.
struct RosterBoard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .foregroundStyle(Palette.carbon)
        .padding(20)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.porcelain, in: NotchedPlate(cornerRadius: 22, notchWidth: 28, notchDepth: 6))
        .overlay(alignment: .top) {
            MetalSurface(
                shape: RoundedRectangle(cornerRadius: 8, style: .continuous),
                stops: MetalFinish.clasp,
                angle: MetalFinish.claspAngle
            )
            .frame(width: 96, height: 26)
            .offset(y: -12)
        }
        .padding(.top, 12)
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
        .environment(DemoSession())
}

#Preview("Guest list · fixture") {
    NavigationStack { GuestListView() }
        .environment(PreviewFixtures.session(at: .band))
}
#endif
