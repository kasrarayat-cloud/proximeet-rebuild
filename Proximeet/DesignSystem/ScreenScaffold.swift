import SwiftUI
import ProximeetDomain

/// Shared screen structure: native navigation bar with brand and step, a scrolling body,
/// and a bottom action dock. At accessibility text sizes the actions move to the end of
/// the scrolling content so they never cover it.
struct ScreenScaffold<Content: View, Actions: View>: View {
    private let title: String
    private let step: Int?
    private let content: Content
    private let actions: Actions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String,
        step: Int?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.step = step
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
                if dynamicTypeSize.isAccessibilitySize {
                    actionStack
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.carbon.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                actionStack
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Palette.carbon.ignoresSafeArea(edges: .bottom))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.carbon, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Proximeet")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Palette.porcelain)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityShowsLargeContentViewer()
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let step {
                    StepIndicator(step: step, total: 6)
                } else {
                    DemoBadge()
                }
            }
        }
    }

    private var actionStack: some View {
        VStack(spacing: 12) {
            actions
        }
    }
}

/// Centered screen headline and supporting line.
///
/// Headlines are mixed-case heavy system type. Callers write the preferred two-line break
/// as "\n", so the normal size wraps in controlled, balanced lines; larger text keeps
/// wrapping naturally within each line, and nothing is truncated.
struct SceneHeader: View {
    let title: String
    var subtitle: String?
    @Adaptive private var adaptive

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .textRole(.hero)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.porcelain)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(title.replacingOccurrences(of: "\n", with: " ")))
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .textRole(.supporting)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct StepIndicator: View {
    let step: Int
    let total: Int

    var body: some View {
        Text(String(format: "%02d / %02d", step, total))
            .font(.subheadline.weight(.medium).monospacedDigit())
            .foregroundStyle(Palette.quietText)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityLabel(Text("Step \(step) of \(total)"))
    }
}

/// The only mark this demo ever shows: DEMO.
struct DemoBadge: View {
    var body: some View {
        Text(PassMark.demo.label)
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(Palette.carbon)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Palette.porcelain, in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityLabel(Text("Demo"))
    }
}

/// Stable, opaque notice region; used for "Demo — not visible to anyone".
struct NoticeBanner: View {
    let text: String
    var systemImage = "eye.slash"
    @Adaptive private var adaptive

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Label {
            Text(text)
                .textRole(.label)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Palette.porcelain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.graphite, in: shape)
        .overlay {
            shape.strokeBorder(
                adaptive.increaseContrast ? Palette.porcelain : Palette.hairline,
                lineWidth: adaptive.increaseContrast ? 2 : 1
            )
        }
    }
}

/// Small supporting copy under a group, e.g. draft-only reminders.
struct Footnote: View {
    let text: String
    @Adaptive private var adaptive

    var body: some View {
        Text(text)
            .textRole(.supporting)
            .foregroundStyle(Palette.quiet(increasedContrast: adaptive.increaseContrast))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Inline validation or eligibility message; icon plus text, never colour alone.
struct IssueMessage: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .accessibilityHidden(true)
        }
        .textRole(.label)
        .foregroundStyle(Palette.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
