import SwiftUI
import ProximeetDomain

/// Scene 2 — honest functional scaffold. A self-entered eligibility check, never proof of
/// age. The picker and the evaluator share one Gregorian calendar and time zone.
struct BirthdayView: View {
    @Environment(DemoSession.self) private var session
    @State private var calendar = DemoSession.birthdayCalendar()
    @State private var selection = Date()
    @State private var hasChosenDate = false
    @State private var rejection: BirthdayCheck?
    @State private var hasLoadedDraft = false

    var body: some View {
        ScreenScaffold(title: "Birthday", step: 2) {
            SceneHeader(
                title: "When's your birthday?",
                subtitle: "This demo is for people 18 and over. It's a self-entered check, not proof of age, and nothing is verified."
            )
            GraphiteAperture {
                DatePicker("Date of birth", selection: $selection, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.calendar, calendar)
                    .environment(\.timeZone, calendar.timeZone)
            }
            .onChange(of: selection) {
                hasChosenDate = true
                rejection = nil
            }

            if let rejection {
                IssueMessage(text: rejection.message)
            } else if !hasChosenDate {
                Footnote(text: "Scroll to your date of birth to continue.")
            }

            Footnote(text: "Kept in memory for this demo run only. Starting over clears it.")
        } actions: {
            Button("Check eligibility") {
                submit()
            }
            .buttonStyle(.proximeetPrimary)
            .disabled(!hasChosenDate)
        }
        .onAppear(perform: loadDraftIfNeeded)
    }

    private func loadDraftIfNeeded() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true
        if let stored = session.draft.dateOfBirth {
            selection = stored
            hasChosenDate = true
        }
    }

    private func submit() {
        // The domain moves to the demo pass on success; only rejections need handling here.
        guard let result = session.submitBirthday(selection, calendar: calendar), result != .eligible else {
            return
        }
        rejection = result
        AccessibilityNotification.Announcement(result.message).post()
    }
}

#if DEBUG
#Preview("Birthday") {
    NavigationStack { BirthdayView() }
        .environment(DemoSession())
}
#endif
