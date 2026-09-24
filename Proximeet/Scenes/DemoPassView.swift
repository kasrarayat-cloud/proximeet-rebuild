import SwiftUI
import ProximeetDomain

/// Scene 3 — a clipped sheet of bright pass stock marked DEMO. The birthday line says
/// exactly what happened: a self-entered date passed this demo's 18+ check. No stamp
/// timer and no suggestion that any external check happened.
struct DemoPassView: View {
    @Environment(DemoSession.self) private var session
    @Adaptive private var adaptive
    @State private var hasAppeared = false

    var body: some View {
        ScreenScaffold(title: "Demo pass", step: 3) {
            SceneHeader(
                title: "Your demo\npass.",
                subtitle: "A prop for this demo only. It isn't a ticket and doesn't prove age or identity."
            )
            PassSheet()
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
            Button("Continue to guest list") {
                session.continueFromPass()
            }
            .buttonStyle(.proximeetPrimary)
        }
    }
}

private struct PassSheet: View {
    var body: some View {
        PaperSheet {
            HStack(alignment: .firstTextBaseline) {
                Text("Proximeet")
                    .textRole(.section)
                Spacer(minLength: 12)
                Text("Local demo")
                    .textRole(.label)
                    .foregroundStyle(Palette.stockInk)
                    .multilineTextAlignment(.trailing)
            }
            Text("Demo pass")
                .textRole(.title)
                .fixedSize(horizontal: false, vertical: true)
            Perforation()
            PassField(
                label: "Birthday",
                value: "Self-entered and 18+ for this demo. Not checked by anyone."
            )
            PassField(label: "Valid for", value: "This demo on this phone. Not a ticket.")
            HStack {
                Spacer()
                DemoStamp()
            }
        }
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

/// The only mark the pass can carry: DEMO, inked at a slight angle.
private struct DemoStamp: View {
    var body: some View {
        Text(PassMark.demo.label)
            .font(.system(.title, design: .monospaced).weight(.black))
            .foregroundStyle(Palette.carbon)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.carbon, lineWidth: 3)
            }
            .rotationEffect(.degrees(-7))
            .padding(.vertical, 6)
            .accessibilityLabel(Text("Marked demo"))
    }
}

#if DEBUG
#Preview("Demo pass") {
    NavigationStack { DemoPassView() }
        .environment(PreviewFixtures.session(at: .pass))
}
#endif
