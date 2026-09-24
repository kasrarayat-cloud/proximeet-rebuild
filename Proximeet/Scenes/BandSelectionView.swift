import SwiftUI
import UIKit
import ProximeetDomain

/// B1 — one physical object, four clear intents. The preview starts cyan without
/// silently choosing Social: confirmation remains disabled until a real selection.
struct BandSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Adaptive private var adaptive

    var body: some View {
        let selected = session.draft.band
        ScreenScaffold(title: "Band", step: 5) {
            SceneHeader(title: "Your night.\nYour intention.", subtitle: "Choose what you're open to.")

            SignatureBandHero(intent: selected ?? .social, height: 212)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BandIntent.allCases) { intent in
                    intentButton(intent, selected: selected == intent)
                }
            }

            Text(selected?.summary ?? "Select a band to make it yours.")
                .font(.subheadline)
                .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("band.description")
        } actions: {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                session.confirmBand()
            } label: {
                Text(selected.map { "Wear \($0.title)" } ?? "Choose your band")
            }
            .buttonStyle(.proximeetPrimary)
            .disabled(selected == nil)
            .accessibilityIdentifier("band.confirm")
            .accessibilityHint("Confirms your band and opens signal selection.")

            Text("Private demo · Nothing is shared")
                .font(.caption2)
                .foregroundStyle(Palette.quietText)
        }
        .sensoryFeedback(.selection, trigger: selected) { _, newValue in newValue != nil }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private func intentButton(_ intent: BandIntent, selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button {
            session.selectBand(intent)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: intent.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(intent.tint)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(intent.title)
                        .font(.headline)
                        .foregroundStyle(Palette.porcelain)
                    Text(intent.tagline)
                        .font(.caption)
                        .foregroundStyle(Palette.quietText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(intent.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(selected ? intent.tint.opacity(0.09) : Palette.graphite, in: shape)
            .overlay {
                shape.strokeBorder(selected ? intent.tint : Palette.hairline.opacity(0.7), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(ObjectPressStyle())
        .accessibilityLabel("\(intent.title) band")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(intent.summary)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("intent.\(intent.rawValue)")
        .animation(adaptive.selectionAnimation, value: selected)
    }
}

#if DEBUG
#Preview("B1 · native 3D") {
    NavigationStack { BandSelectionView() }
        .environment(PreviewFixtures.session(at: .band))
}
#endif
