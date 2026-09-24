import SwiftUI
import ProximeetDomain

/// Native form for the guest's first name and three interests.
///
/// Save contract: the sheet dismisses only when the domain returns `.saved`. A rejected
/// save keeps the visible edits and shows each issue next to its field; the previously
/// saved profile stays untouched. Cancel discards the edits.
struct ProfileEditorSheet: View {
    @Environment(DemoSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var interests: [String]
    @State private var issues: [ProfileIssue] = []
    @State private var hasAttemptedSave = false
    @State private var isUnavailable = false
    @FocusState private var focusedField: Field?
    private let isNewEntry: Bool

    enum Field: Hashable {
        case firstName
        case interest(Int)
    }

    init(profile: GuestProfile?) {
        _firstName = State(initialValue: profile?.firstName ?? "")
        _interests = State(initialValue: profile?.interests
            ?? Array(repeating: "", count: GuestProfile.interestCount))
        isNewEntry = profile == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .firstName)
                        .onSubmit { focusedField = .interest(0) }
                    ForEach(fieldIssues(.firstName), id: \.self) { issue in
                        IssueMessage(text: issue.message)
                    }
                } header: {
                    Text("First name")
                } footer: {
                    Text("Shown only in this demo's summary.")
                }

                Section {
                    ForEach(0..<GuestProfile.interestCount, id: \.self) { index in
                        TextField("Interest \(index + 1)", text: $interests[index])
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(index == GuestProfile.interestCount - 1 ? .done : .next)
                            .focused($focusedField, equals: .interest(index))
                            .onSubmit { advanceFocus(after: index) }
                        ForEach(fieldIssues(.interest(index)), id: \.self) { issue in
                            IssueMessage(text: issue.message)
                        }
                    }
                    ForEach(listIssues, id: \.self) { issue in
                        IssueMessage(text: issue.message)
                    }
                } header: {
                    Text("Three interests")
                } footer: {
                    Text("Three different things you enjoy.")
                }

                if isUnavailable {
                    Section {
                        IssueMessage(text: "Your profile can't be changed from this screen.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.graphite)
            .navigationTitle(isNewEntry ? "Add yourself" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: firstName) { revalidateAfterFirstAttempt() }
            .onChange(of: interests) { revalidateAfterFirstAttempt() }
        }
    }

    // MARK: - Save

    private func save() {
        hasAttemptedSave = true
        switch session.saveProfile(firstName: firstName, interests: interests) {
        case .saved:
            issues = []
            dismiss()
        case .invalid(let error):
            issues = error.issues
            focusedField = error.issues.first.flatMap { field(for: $0) }
            let summary = error.issues.first?.message ?? "Check the highlighted fields."
            AccessibilityNotification.Announcement(summary).post()
        case .unavailable:
            isUnavailable = true
        }
    }

    /// After the first attempt, issues follow the typing so fixed fields clear at once.
    /// This only re-checks; it never saves.
    private func revalidateAfterFirstAttempt() {
        guard hasAttemptedSave else { return }
        switch GuestProfile.validated(firstName: firstName, interests: interests) {
        case .success:
            issues = []
        case .failure(let error):
            issues = error.issues
        }
    }

    // MARK: - Issue placement

    private func fieldIssues(_ target: Field) -> [ProfileIssue] {
        issues.filter { field(for: $0) == target }
    }

    private var listIssues: [ProfileIssue] {
        issues.filter { field(for: $0) == nil }
    }

    private func field(for issue: ProfileIssue) -> Field? {
        switch issue {
        case .firstNameMissing, .firstNameTooLong:
            return .firstName
        case .interestMissing(let index), .interestTooLong(let index, _), .duplicateInterest(let index, _):
            return .interest(index)
        case .wrongInterestCount:
            return nil
        }
    }

    private func advanceFocus(after index: Int) {
        let next = index + 1
        focusedField = next < GuestProfile.interestCount ? .interest(next) : nil
    }
}

#if DEBUG
#Preview("Editor · new") {
    ProfileEditorSheet(profile: nil)
        .environment(PreviewFixtures.session(at: .guestList))
}
#endif
