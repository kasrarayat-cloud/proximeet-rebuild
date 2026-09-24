import SwiftUI
import UIKit
import ProximeetDomain

/// B2 — the same band, with a front-mounted physical plate. All four choices and the
/// confirmation are native controls; no product action waits for the seating motion.
struct SignalSelectionView: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Adaptive private var adaptive

    var body: some View {
        let band = session.draft.band
        let signal = session.draft.signal
        ScreenScaffold(title: "Signal", step: 6) {
            SceneHeader(title: "A little signal.\nAn easier hello.", subtitle: band.map { "Your \($0.title.lowercased()) band. Your way to connect." })

            if let band {
                SignatureBandHero(intent: band, signal: signal, height: 198)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ApproachSignal.allCases) { option in
                    SignatureSignalOption(signal: option, isSelected: signal == option, accent: band?.tint ?? Palette.porcelain) {
                        session.selectSignal(option)
                    }
                }
            }

            Text(signal?.summary ?? "Choose how you'd like to be approached.")
                .font(.subheadline)
                .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("signal.description")
        } actions: {
            Button("Set my signal") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                session.confirmSignal()
            }
            .buttonStyle(.proximeetPrimary)
            .disabled(signal == nil)
            .accessibilityIdentifier("signal.confirm")
            .accessibilityHint("Confirms your signal and shows your private demo summary.")

            Text("Private demo · Nothing is shared")
                .font(.caption2)
                .foregroundStyle(Palette.quietText)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: signal) { _, newValue in newValue != nil }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }
}

/// A small native metal control, with the exact semantic glyph used on the 3D plate.
private struct SignatureSignalOption: View {
    let signal: ApproachSignal
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: signal.symbolName)
                    .font(.system(size: 23, weight: .medium))
                    .shadow(color: .white.opacity(0.65), radius: 0, y: 1)
                    .accessibilityHidden(true)
                Text(signal.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Palette.carbon)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .background {
                shape.fill(LinearGradient(stops: [
                    .init(color: Color(hex: 0xF2F3F3), location: 0),
                    .init(color: Color(hex: 0xACB4BC), location: 0.32),
                    .init(color: Color(hex: 0xE3E8EB), location: 0.53),
                    .init(color: Color(hex: 0x8D979F), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.strokeBorder(.white.opacity(0.6), lineWidth: 0.8)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Palette.carbon, accent)
                        .font(.system(size: 18, weight: .bold))
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if isSelected { shape.strokeBorder(accent, lineWidth: adaptive.increaseContrast ? 3 : 2) }
            }
            .contentShape(shape)
        }
        .buttonStyle(ObjectPressStyle())
        .accessibilityLabel(signal.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(signal.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("signal.\(signal.rawValue)")
        .animation(adaptive.selectionAnimation, value: isSelected)
    }
}

#if DEBUG
#Preview("B2 · native 3D") {
    NavigationStack { SignalSelectionView() }
        .environment(PreviewFixtures.session(at: .signalSelected, band: .social, signal: .chatFirst))
}
#endif
