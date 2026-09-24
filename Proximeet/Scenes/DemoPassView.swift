import SwiftUI
import ProximeetDomain

/// Scene 3 — honest functional scaffold. The pass is a static demo prop marked DEMO. No
/// stamp timer and no suggestion that any external check happened.
struct DemoPassView: View {
    @Environment(DemoSession.self) private var session

    var body: some View {
        ScreenScaffold(title: "Demo pass", step: 3) {
            SceneHeader(
                title: "Your demo pass.",
                subtitle: "A prop for this demo only. It isn't a ticket and doesn't prove age or identity."
            )
            PassCard()
        } actions: {
            Button("Continue to guest list") {
                session.continueFromPass()
            }
            .buttonStyle(.proximeetPrimary)
        }
    }
}

private struct PassCard: View {
    var body: some View {
        let plate = NotchedPlate(cornerRadius: 24, notchWidth: 30, notchDepth: 7)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Proximeet")
                    .textRole(.section)
                Spacer()
                Circle()
                    .strokeBorder(Palette.stockInk.opacity(0.5), lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            Text("Demo pass")
                .textRole(.title)
                .textCase(.uppercase)
            Rectangle()
                .fill(Palette.stockInk.opacity(0.25))
                .frame(height: 1)
                .accessibilityHidden(true)
            PassField(label: "Birthday", value: "Self-entered. Not checked by anyone.")
            PassField(label: "Use", value: "This demo only. Not a ticket.")
            HStack {
                Spacer()
                Text(PassMark.demo.label)
                    .font(.system(.title, design: .monospaced).weight(.black))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Palette.carbon, lineWidth: 3)
                    }
                    .rotationEffect(.degrees(-8))
                    .accessibilityLabel(Text("Marked demo"))
            }
        }
        .foregroundStyle(Palette.carbon)
        .padding(24)
        .background(Palette.porcelain, in: plate)
        .shadow(color: Color.black.opacity(0.5), radius: 18, y: 12)
        .accessibilityElement(children: .combine)
    }
}

private struct PassField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .textRole(.label)
                .foregroundStyle(Palette.stockInk)
            Text(value)
                .textRole(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("Demo pass") {
    NavigationStack { DemoPassView() }
        .environment(DemoSession())
}
#endif
