# Task 01A — finish the domain and tests only

Continue the source you have already begun. This pass is strictly limited to ProximeetDomain and its tests. Defer SwiftUI, Xcode generation, assets and visual work to the next pass. Do not re-plan the full app. Your existing plan and the four source files are retained.

Implement a small, explicit in-memory onboarding draft:
Welcome → Birthday → Demo Pass → Guest List → Band → Signal → Ready for check-in.
Read the existing four Swift files. Complete profile/draft/scene state and transitions using their types.

Required invariants:
- Direct forward actions reject invalid or absent data; do not rely on disabled buttons.
- Eligibility uses an injected current date and Gregorian calendar, rejects future or under-18 dates, accepts the exact 18th birthday, and documents/tests leap-day behavior. No claim of verified age.
- Profile first name plus three nonblank distinct interests; trim whitespace. Invalid profile edits cannot leave a later ready state claiming readiness.
- Exactly one of four intents and one of four signals. Missing choices cannot confirm. Repeated selections replace previous choices. Back navigation retains drafts. Edits appear in summary.
- Reset removes personal draft data and all selections. No persistence, presence, authentication, network or verification side effects.
- State transitions are independent of any animation or elapsed time.

Write meaningful tests for the above and run:
swift test --package-path ProximeetDomain --jobs 2
Keep the model straightforward; no future backend abstractions or unrelated product policy decisions. Do not change project permission settings or anything outside this worktree. Do not commit, push, call Apple or run CI.
Save actual test results and any remaining gap to docs/reports/task01-domain.md and return a concise report. Then STOP so the lead can review before the separate SwiftUI pass.
