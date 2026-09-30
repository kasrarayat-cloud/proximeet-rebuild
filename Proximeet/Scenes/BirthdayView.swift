import SwiftUI
import ProximeetDomain

/// Chapter 02 — the approved Birthday (handoff `LAYOUT_SPEC.json`, Figma 16:114; empty,
/// adult and under-18 states 19:111–19:113), on the 440 × 956 reference canvas.
///
/// A self-declared birthday, never proof of age or identity. The date starts unset
/// (DD / MMM / YYYY) and is entered on native wheels or, via "Enter date instead", in
/// labelled typed fields; both edit one in-memory draft. Any edit disables Continue at once;
/// a wheel that settles, or typed entry submitted with Done, checks the draft again. The
/// generated graphite housing is decoration behind native text and controls. An eligible
/// Continue opens the approved Pass (chapter 03); Back from Pass returns here, draft kept.
struct BirthdayView: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: EntryMode = .wheels
    @State private var dayText = ""
    @State private var monthText = ""
    @State private var yearText = ""
    @State private var initialFocus: Field = .day
    @FocusState private var focus: Field?
    @State private var lastAnnounced: BirthdayStatus?
    /// A wheel is being turned: its value is not settled, so Continue waits for it.
    @State private var isWheelMoving = false

    enum EntryMode { case wheels, typed }
    enum Field: Hashable { case day, month, year }

    var body: some View {
        GeometryReader { proxy in
            let console = min(376, max(0, proxy.size.width - 64))
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    headline
                        .padding(.top, 46)
                    BirthdayBodyText(text: "Proximeet is for adults 18 and over.", face: .regular, color: BirthdayStyle.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
                        .padding(.top, 16)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("birthday.eligibility")
                    DateConsole(
                        width: console,
                        mode: mode,
                        draft: session.birthday.draft,
                        years: Self.wheelYears,
                        dayText: $dayText,
                        monthText: $monthText,
                        yearText: $yearText,
                        focus: $focus,
                        initialFocus: initialFocus,
                        onWheelSettle: settle,
                        onWheelMotion: { isWheelMoving = $0 },
                        onSubmit: submitTyped
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 42)
                    modeSwitch
                        .padding(.top, 16)
                    guidance
                        .padding(.top, 13)
                    continueButton
                        .padding(.top, 25)
                        .padding(.bottom, 50)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(BirthdayStyle.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { submitTyped() }
                    .accessibilityIdentifier("birthday.keyboardDone")
            }
        }
        .onAppear { session.reevaluateBirthday() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.reevaluateBirthday() }
        }
    }

    // MARK: - Rows

    /// Back (44 × 44 at 24, 64) and the wordmark: Figma's text box at (84, 70), Bold 22 on a
    /// 24-pt line at the top of the box, so its capitals start at 74.6 (74.7 on the approved
    /// board). Centred in the 44-pt row instead, they started 4 pt lower, at 78.6.
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Button {
                focus = nil
                session.returnTo(.welcome)
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("birthday.back")
            BirthdayWordmark()
                .padding(.top, 6)
        }
        .frame(minHeight: 44, alignment: .topLeading)
        .padding(.leading, 24)
        .padding(.top, 2)
    }

    /// "First, your birthday." ExtraBold 56/59, −2.2, on its approved line break.
    private var headline: some View {
        BirthdayHeadline()
            .padding(.horizontal, 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("First, your birthday."))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("birthday.headline")
    }

    /// "Enter date instead" (Medium 16/24, underlined, 44-pt target), or the way back to the
    /// wheels from typed entry.
    private var modeSwitch: some View {
        Button {
            switchMode()
        } label: {
            BirthdayBodyText(
                text: mode == .wheels ? "Enter date instead" : "Use date wheels instead",
                face: .medium,
                color: .white,
                underline: true
            )
            .frame(minWidth: 240, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .accessibilityIdentifier(mode == .wheels ? "birthday.enterDate" : "birthday.useWheels")
    }

    private var guidance: some View {
        let copy = Self.guidance(for: session.birthday.status)
        return BirthdayBodyText(
            text: copy.text,
            face: .regular,
            color: copy.isError ? BirthdayStyle.errorText : BirthdayStyle.secondaryText
        )
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
        .padding(.horizontal, 32)
        .accessibilityIdentifier("birthday.guidance")
    }

    private var continueButton: some View {
        Button("Continue") { attemptContinue() }
            .buttonStyle(BirthdayContinueStyle())
            .disabled(!session.birthday.canContinue || isWheelMoving)
            .padding(.horizontal, 32)
            .accessibilityIdentifier("birthday.continue")
    }

    // MARK: - Behaviour

    /// A wheel settled on a row: that is both the edit and the moment to check the draft.
    private func settle(_ column: BirthdayWheels.Column, _ value: Int?) {
        isWheelMoving = false
        session.editBirthday { entry in
            switch column {
            case .day: entry.setDay(value)
            case .month: entry.setMonth(value)
            case .year: entry.setYear(value)
            }
        }
        session.commitBirthday()
        announceIfChanged()
    }

    /// Typed entry is checked when submitted: keyboard Done, return, or leaving typed entry.
    private func submitTyped() {
        focus = nil
        session.commitBirthday()
        announceIfChanged()
    }

    private func switchMode() {
        isWheelMoving = false
        switch mode {
        case .wheels:
            let draft = session.birthday.draft
            dayText = draft.day.map(String.init) ?? ""
            monthText = draft.month.map(String.init) ?? ""
            yearText = draft.year.map(String.init) ?? ""
            if draft.day == nil {
                initialFocus = .day
            } else if draft.month == nil {
                initialFocus = .month
            } else if draft.year == nil {
                initialFocus = .year
            } else {
                initialFocus = .day
            }
            mode = .typed
        case .typed:
            submitTyped()
            mode = .wheels
        }
    }

    /// Only an eligible committed date opens the approved Pass (chapter 03); anything else
    /// stays here and says why.
    private func attemptContinue() {
        focus = nil
        guard !isWheelMoving else { return }
        if session.continueFromBirthday() != .eligible {
            announceIfChanged()
        }
    }

    /// Speaks a result once when it changes, never on every wheel step or keystroke.
    private func announceIfChanged() {
        let status = session.birthday.status
        guard status != lastAnnounced else { return }
        lastAnnounced = status
        switch status {
        case .eligible, .underMinimumAge, .impossible, .yearOutOfRange, .future:
            AccessibilityNotification.Announcement(Self.guidance(for: status).text).post()
        case .empty, .editing, .incomplete:
            break
        }
    }

    // MARK: - Copy

    static func guidance(for status: BirthdayStatus) -> (text: String, isError: Bool) {
        switch status {
        case .empty, .editing, .incomplete:
            return ("Select your day, month and year.", false)
        case .eligible:
            return ("Check your date before continuing.", false)
        case .underMinimumAge:
            return ("You need to be 18 or older\nto join Proximeet.", true)
        case .impossible:
            return ("That date doesn’t exist.\nCheck the day and month.", true)
        case .yearOutOfRange:
            return ("Check the year.\nUse four digits, from 1900.", true)
        case .future:
            return ("That date is in the future.\nCheck the year.", true)
        }
    }

    /// Wheel years: the domain's earliest year to the current year. Typed entry is held to
    /// the same lower bound when it is checked, so a checked date always shows on the wheels.
    static var wheelYears: ClosedRange<Int> {
        BirthdayEntry.earliestYear...DemoSession.civilToday(now: Date()).year
    }
}

// MARK: - Text

/// Regular or Medium 16/24 body text that follows Dynamic Type. Every line, including the
/// two-line guidance, sits on the 24-pt Figma pitch (scaled): the gap between Manrope's
/// natural line and the pitch is added as line spacing and split above and below.
private struct BirthdayBodyText: View {
    let text: String
    let face: Manrope
    let color: Color
    var underline = false
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16

    var body: some View {
        let extra = max(0, 24 * size / 16 - face.naturalLineHeight(size: size))
        Text(text)
            .underline(underline)
            .font(face.font(size: size))
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Proximeet" Bold 22 on Figma's 24-pt line (the line box, not the glyphs, is 24 pt tall,
/// as in Figma, so the glyphs sit where Figma's half-leading puts them).
private struct BirthdayWordmark: View {
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 22

    var body: some View {
        Text("Proximeet")
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .manrope(.bold, size: size, designSize: 22, lineHeight: 24)
            .foregroundStyle(.white)
    }
}

private struct BirthdayHeadline: View {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("First, your")
                .manrope(.extraBold, size: size, designSize: 56, lineHeight: 59, tracking: -2.2)
            // One word: at the largest text sizes it shrinks to fit rather than breaking
            // mid-word and leaving the full stop on a line of its own.
            Text("birthday.")
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .manrope(.extraBold, size: size, designSize: 56, lineHeight: 59, tracking: -2.2)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Date console

/// The graphite housing (decoration) with the native Day / Month / Year labels, the wheels
/// or typed fields, the selected lane and the column separators. Everything is placed on
/// the Figma console coordinates (376 × 288 at the reference size) and scaled with `width`,
/// so the controls always sit inside the housing's window. The console is a fixed object:
/// its own text is capped at the largest non-accessibility size; typed entry and the rest
/// of the screen follow Dynamic Type.
private struct DateConsole: View {
    @Environment(DemoSession.self) private var session
    let width: CGFloat
    let mode: BirthdayView.EntryMode
    let draft: BirthdayComponents
    let years: ClosedRange<Int>
    @Binding var dayText: String
    @Binding var monthText: String
    @Binding var yearText: String
    var focus: FocusState<BirthdayView.Field?>.Binding
    let initialFocus: BirthdayView.Field
    let onWheelSettle: (BirthdayWheels.Column, Int?) -> Void
    let onWheelMotion: (Bool) -> Void
    let onSubmit: () -> Void

    private var s: CGFloat { width / 376 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            BirthdayHousing(width: width)
            ForEach(Self.columns, id: \.label) { column in
                Text(column.label)
                    .font(Manrope.medium.font(size: 16))
                    .foregroundStyle(BirthdayStyle.secondaryText)
                    .frame(width: column.x.width * s, height: 24 * s, alignment: .center)
                    .padding(.leading, column.x.origin * s)
                    .padding(.top, 32 * s)
                    .accessibilityHidden(true)
            }
            // The approved selected lane, in both modes: the wheels hide UIKit's own bar.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BirthdayStyle.lane.opacity(0.76))
                .frame(width: 308 * s, height: 58 * s)
                .padding(.leading, 42 * s)
                .padding(.top, 114 * s)
                .accessibilityHidden(true)
            ForEach([CGFloat(137), CGFloat(247)], id: \.self) { x in
                Rectangle()
                    .fill(BirthdayStyle.separator.opacity(0.28))
                    .frame(width: 1, height: 32 * s)
                    .padding(.leading, x * s)
                    .padding(.top, 126 * s)
                    .accessibilityHidden(true)
            }
            switch mode {
            case .wheels:
                // The picker keeps its own (taller) height, so its rows keep the approved
                // spacing; only the 150-pt window shows them: previous, selected and next.
                BirthdayWheels(draft: draft, years: years, scale: s, onSettle: onWheelSettle, onMotion: onWheelMotion)
                    .frame(width: 308 * s, height: 150 * s)
                    .clipped()
                    .padding(.leading, 42 * s)
                    .padding(.top, 68 * s)
            case .typed:
                typedFields
                    .padding(.leading, 42 * s)
                    .padding(.top, 114 * s)
            }
        }
        .frame(width: width, height: 288 * s, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var typedFields: some View {
        HStack(spacing: 8 * s) {
            field("DD", text: $dayText, field: .day, digits: 2, label: "Day", id: "day", width: 92)
            field("MM", text: $monthText, field: .month, digits: 2, label: "Month, 1 to 12", id: "month", width: 100)
            field("YYYY", text: $yearText, field: .year, digits: 4, label: "Year", id: "year", width: 92)
        }
        .padding(.leading, 4 * s)
        .frame(width: 308 * s, height: 58 * s, alignment: .leading)
        .onAppear { focus.wrappedValue = initialFocus }
    }

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        field: BirthdayView.Field,
        digits: Int,
        label: String,
        id: String,
        width: CGFloat
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder)
                .font(Manrope.semiBold.font(size: 24))
                .foregroundStyle(BirthdayStyle.secondaryText)
        )
        .font(Manrope.semiBold.font(size: 30))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .submitLabel(.done)
        .focused(focus, equals: field)
        .onSubmit(onSubmit)
        .frame(width: width * s, height: max(44, 58 * s))
        .accessibilityLabel(label)
        .accessibilityIdentifier("birthday.field.\(id)")
        .onChange(of: text.wrappedValue) { _, newValue in
            let cleaned = String(newValue.filter(\.isNumber).prefix(digits))
            if cleaned != newValue {
                text.wrappedValue = cleaned
                return
            }
            edit(field, value: Int(cleaned))
        }
    }

    /// Every keystroke is an edit: Continue is disabled until the entry is submitted.
    private func edit(_ field: BirthdayView.Field, value: Int?) {
        session.editBirthday { entry in
            switch field {
            case .day: entry.setDay(value)
            case .month: entry.setMonth(value)
            case .year: entry.setYear(value)
            }
        }
    }

    private struct ColumnSpec {
        let label: String
        let x: (origin: CGFloat, width: CGFloat)
    }

    /// Figma columns relative to the console: Day 46/92, Month 146/100, Year 254/92.
    private static let columns = [
        ColumnSpec(label: "Day", x: (46, 92)),
        ColumnSpec(label: "Month", x: (146, 100)),
        ColumnSpec(label: "Year", x: (254, 92)),
    ]
}

/// The original 1254 × 1254 RGBA housing, shown through the approved transparent-margin crop
/// (25, 204)–(1214, 1045) and fitted to 376 × 266 at the reference size, without distortion.
private struct BirthdayHousing: View {
    let width: CGFloat

    var body: some View {
        let k = width / 1189
        Image(decorative: "BirthdayHousing")
            .resizable()
            .interpolation(.high)
            .frame(width: 1254 * k, height: 1254 * k)
            .offset(x: -25 * k, y: -204 * k)
            .frame(width: width, height: 841 * k, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Style

enum BirthdayStyle {
    static let ground = Color(hex: 0x050606)
    static let secondaryText = Color(hex: 0xA8B0AD)
    static let errorText = Color(hex: 0xFFB087)
    static let lane = Color(hex: 0x242A2B)
    static let separator = Color(hex: 0x808F8F)
    static let continueEnabled = Color(hex: 0xF6F7F2)
    static let continueDisabled = Color(hex: 0x1F2424)
    static let continueDisabledLabel = Color(hex: 0x737D7A)
}

/// Continue: 60 pt, radius 18. Enabled #F6F7F2 with a #050606 label; disabled #1F2424 with
/// a #737D7A label (SemiBold 18/24).
private struct BirthdayContinueStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BirthdayContinueBody(configuration: configuration)
    }
}

private struct BirthdayContinueBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        configuration.label
            .manrope(.semiBold, size: size, designSize: 18, lineHeight: 24)
            .foregroundStyle(isEnabled ? BirthdayStyle.ground : BirthdayStyle.continueDisabledLabel)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? BirthdayStyle.continueEnabled : BirthdayStyle.continueDisabled, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

#if DEBUG
#Preview("Birthday · empty") {
    NavigationStack { BirthdayView() }
        .environment(PreviewFixtures.session(at: .birthday))
}

#Preview("Birthday · adult") {
    NavigationStack { BirthdayView() }
        .environment(PreviewFixtures.session(at: .birthdayAdult))
}

#Preview("Birthday · under 18") {
    NavigationStack { BirthdayView() }
        .environment(PreviewFixtures.session(at: .birthdayUnder18))
}
#endif
