# Wave verification in Xcode Cloud: the authorized run

**Status: AUTHORIZED, NOT RUN.** On 30 September 2026 the founder authorized pushing only this Wave
feature branch, creating a manual **Wave Verification** workflow, and starting **one** Xcode Cloud
verification build of at most **160 compute minutes across its actions**, with no automatic retry, no
Codemagic, no billing change, no archive and no TestFlight distribution. Nothing in this document has run
on an Apple system, and nothing here is a result. The Wave (chapter 09) is implemented in source and checked
on Linux only; a Linux type-check is not a native compile.

**What holds it.** The founder asked for the App Store Connect start conditions to be inspected before the
push. This machine has no App Store Connect access (no API key, no Apple sign-in, no connector), and the
standing rules forbid signing in or requesting Apple credentials, so neither that inspection nor creating the
workflow, starting or cancelling the build, nor downloading its artifacts can be done from here. The push is
held until the start conditions are confirmed (§5). Every Apple-side outcome stays **PENDING FOUNDER** until
the founder reports it or the lead reads it on GitHub.

- **Candidate:** branch `wave/approved-20260930T173856Z`, commit `<CANDIDATE_SHA>`: the branch tip whose
  full SHA the lead gives in the report of this chapter's second candidate. A document cannot contain its
  own commit's SHA. Until the push the branch exists only on the VPS.
- **Base:** the verified Room commit `1a5f97e0fe73168e5f63e392182507e457209964`
  (`room-repair/xcode-checks-20260930`). Its Room Verification run is the model for this one (§4).
- **Rows:** `docs/verification/wave-xcode-cloud-manifest.tsv`, one per required execution.
- **Plans:** `TestPlans/WaveVerificationMain.xctestplan` and `TestPlans/WaveVerificationSmall.xctestplan`,
  listed in the scheme after the two Room plans. `RoomVerificationMain` stays the scheme's default.

## 1. The bound

| | What | Apple compute | Authorized? |
| --- | --- | --- | --- |
| **The build** | One build of the manual-start **Wave Verification** workflow: its two Test actions, side by side, at `<CANDIDATE_SHA>` | estimated about 107–161 compute minutes (§4); the compute guard caps the UI tests at 104 + 36 min, and the rest is only estimated at 600 s an action, so 160 is a target the guard aims at, not a guarantee | **yes** (30 September 2026) |
| **A second build** | None. There is no automatic retry and no contingency build: any further build, for any reason, needs a new authorization (§6) | – | no |
| **Archive and delivery** | Not authorized (§9) | – | no |

No Codemagic, no TestFlight delivery, no change to the **Room Verification** or **Proximeet TestFlight**
workflows, and no paid compute.

## 2. The test inventory

| Plan | Destination | UI tests | Domain tests | Executed in total | Rows |
| --- | --- | --- | --- | --- | --- |
| `WaveVerificationMain` | iPhone 17 Pro Max (440 × 956) | **30**: 14 Wave, 13 Room, 3 Places | **250** | **280** | W1–W10, W11a, W11b, W12, W13, R1–R13, P1, P4, C1, D1 |
| `WaveVerificationSmall` | iPhone 17e (390 × 844) | **7**: 2 Wave, 1 Room, 4 Places | none | **7** | W14a, W14b, R14, C15, P9, C12, C11 |
| none (the VPS) | Linux, `swift test` | none | 8 | 8 | D2 |

**The count, reconciled.** The first candidate (`124c6a4`) expected **283** native executions: Main 30 UI + 246
domain = 276, and Small 7. The founder's decisions of 30 September 2026 added four domain tests
(`testAQueuedBlockAffectsOnlyItsActorInItsRun`, `testEveryInvitationControlRevalidatesTheRun`,
`testTheMenuBackReturnsToTheStillValidRoom`, `testTheFixedViewerIdentityIsDistinctAndNameIndependent`) and no UI
test method (their UI checks went into the existing 14 Wave methods). So this candidate expects **287** native
executions: Main 30 UI + 250 domain = **280**, Small **7**. The domain target has **258** tests: the 250 that
run on the simulator, and the **8** source-reading tests (D2) that both Main plans skip and that run once, on
the VPS (§8). The 8 are not among the 250, so nothing is counted twice.

**Why these rows, and no others.** Every row here runs code that the Wave changed, and the Wave changed
only these product files: `RoomDemo.swift` and the new `WaveDemo.swift` (domain), `RoomView.swift` (the
profile's action is now "Preview Wave demo" with its spoken hint, the Wave information panel 66:134 is gone,
the components are internal, and a run with a Wave draws the new `WaveView.swift`), `DemoSession.swift`
(four additions) and `DebugFixtures.swift` (the Wave fixtures, `-ProximeetFixtureName`, and the name threaded
through the shared fixture path).
- **Wave:** every `WaveReviewTests` method; all 14 run on the 440-pt phone (W1–W13, W11 being two rows,
  W11a and W11b). The largest-text checks are two methods, `testLargestTextKeepsWaveScreensReachable`
  (the 12 screens, the blocked menu and the two real Leaves) and `testLargestTextKeepsWavePanelsReachable`
  (the 7 overlays). Both run on whichever phone runs them, so, like the Room's R7 and R14, they run on the
  390-pt phone as well (W14a, W14b). `testCaptureApprovedScreensAndOverlays` and
  `testReduceMotionPreviewAcceptJoinsWithoutAMove` read 440-pt geometry and stay on the larger phone.
- **Room:** all 13 `RoomReviewTests` methods on the 440-pt phone and the largest-text one on the 390-pt
  phone, as in the Room plans. The removal of the Wave information panel changed the tests' shared
  helpers and enums, and every one of the 13 tests goes through them. The Room's overlays fall from 8 to 7.
- **Places:** every Places UI test that goes into the Room, on the phone its Room plan ran it on: P1, P4
  and C1 on the larger phone and C15, P9, C12 and C11 on the smaller one.
- **Left out, with the justification the founder asked for.** The 16 older regression rows C2, C3, P2, C9,
  C4, C5, C6, C7, C8 (440-pt phone) and P10, P11, P12, P13, C10, C13, C14 (390-pt phone) stay out of both
  Wave plans because the Wave change set does not reach anything they run (an independent read of every
  row, 30 September 2026):
  - None of them opens the Room, so none can reach the Wave. The Room exists only after
    `DemoSession.previewRoomDemo()`, which the app calls only from Places' "Preview room demo"
    (`explanation.primary`); `RoomView` is built only while `session.room != nil`, and `WaveView` only
    inside `RoomView` while the run has a Wave. The only tests that press "Preview room demo" are P1, P4,
    P9, C15, C1, C12 and C11, and all of them are in the Wave plans. The excluded rows check that button's
    label, frame or hittability and never tap it.
  - They launch only the fixtures `welcome`, `wristband`, `signal`, `signal-selected`, `places`,
    `place-detail` and `place-explanation`, never `-ProximeetFixtureName`. With that argument absent,
    every changed shared fixture function returns exactly what it returned at 1a5f97e: the name is nil,
    `session(…)` and `flow(…)` receive their default `name: nil`, `exampleIntroduction(named: nil)`
    returns the unchanged "Alex" example, and the new Wave and Room branches match only `wave-*` and
    `room-*` stages.
  - `DemoSession.swift` only gained members; the `RoomDemo` and `WaveDemo` changes are read only while a
    Room exists; `RoomView`'s private components became internal but are used nowhere outside
    `RoomView.swift` and `WaveView.swift`. No Places, Signal, Wristband, component, design-system or
    app-entry file changed.
  - Their test bodies and helpers are unchanged. The only edit to their classes is
    `try RunBudget.begin(self)` as the first line of `setUpWithError` in `PlacesReviewTests` and
    `PlacesCorrectionTests`, which returns at once, with no effect, unless `PROXIMEET_RUN_BUDGET_SECONDS`
    is set, and only the two Wave plans set it (validator check 7).

  Their shared dependencies are therefore unaffected. Their last results stay those of the Room chapter
  and are not re-run here. To remove even this residual risk, both Room plans could be added to a later
  build (about 77 more compute minutes, as measured on 1a5f97e); that is not authorized.
- **Domain:** the whole `ProximeetDomainTests` target on the simulator, minus the eight tests that read the
  repository's files (D1). Each of the two chapter-09 source readers also skips itself when it finds no
  source tree, a safety net rather than the plan: a skip on Xcode Cloud would break criterion 3 of §7.

## 3. Devices, Xcode and the workflow

- **Devices.** Main on **iPhone 17 Pro Max**. Small on **iPhone 17e**, or **iPhone 16e** if 17e is not
  offered: both are 390 × 844. Choose no other model, and record which one was used. Both actions use the
  same iOS: the one the Room Verification run on 1a5f97e used, or, if that is no longer offered, the latest
  iOS 26.x offered with that Xcode; record it.
- **Xcode: the one the Room Verification workflow used for its successful run on 1a5f97e** (App Store
  Connect build `29af42f6-f5c7-49ad-bd33-9d69d4ead089`), so that the Room and the Wave results come from
  one toolchain. The Room runbook set that workflow to **Xcode 26.6**; the check runs do not name the
  version actually used, so it is **PENDING FOUNDER**: read it on the Room Verification workflow's
  Environment and use exactly that. Do not upgrade Xcode for this run.
- **Expected GitHub check runs:** `Proximeet | Wave Verification | WaveVerificationMain - iOS (Proximeet)` and
  `… | WaveVerificationSmall - iOS (Proximeet)`, as the Room's appeared on 1a5f97e. An expectation, not a
  fact, until the run.

## 4. Compute, and the guard that aims to hold it at 160 minutes

**Measured, Room Verification on 1a5f97e** (GitHub check runs, both `success`, 0 test failures): Main
14:51:12–15:42:07 (50.92 min), Small 14:51:10–15:17:38 (26.47 min), **77.38 compute minutes** for the build.
A build-only action on 062ea35 took 2.28 min. Xcode Cloud took about **1.04–1.18 times** the
Codemagic-measured test time per action, build, simulator and runner start included.

**Estimated for the Wave**, from the manifest's per-row times (the Wave rows never ran, so theirs are
estimates, now including the checks added for the 30 September decisions):

| Action | Room and Places rows | Wave rows (estimate) | Test time, Codemagic pace | Action time at 1.04–1.18 |
| --- | --- | --- | --- | --- |
| WaveVerificationMain | 2,072–2,232 s | 2,597–3,943 s | 4,669–6,175 s | **about 81–121 min** |
| WaveVerificationSmall | 681–841 s | 815–1,190 s | 1,496–2,031 s | **about 26–40 min** |

So the build is estimated at **about 107–161 compute minutes**: the upper end slightly exceeds the authorized
160, which is why the guard below exists.

**The guard.** Nothing on this machine can cancel an Xcode Cloud build, so the tests stop themselves
(`ProximeetUITests/RunBudget.swift`). Each Wave plan gives its UI tests a budget in
`PROXIMEET_RUN_BUDGET_SECONDS`: **Main 6,240 s (104 min)** and **Small 2,160 s (36 min)**. Validator check 7
holds them to Main + Small + 2 × 600 s ≤ 9,600 s (160 min), the 600 s per action standing for the time
outside the UI tests (build for testing, simulator start, the domain tests, result upload), which the Room's
build suggests is about 4–6 min an action (the 2.28-min build action, and the Room actions' overhead over
their test time), so the allowance carries a few minutes of headroom each.
- The clock starts when the first UI test of the action begins. A test starting with less than 60 s left
  is designed to fail at once, before it launches anything, and print `RUN_BUDGET_SPENT`; every other test's
  allowance is lowered to the whole minutes left (never below one minute), so that a hanging test is
  stopped near the budget. The start is kept in the runner's temporary directory, so that a runner
  restarted after an overrun does not get the budget again. All of this is unverified until the run, and
  an overrun adds XCTest's own timeout handling (a process dump, then a runner restart) on top.
- **What it stops first.** XCTest runs classes and methods alphabetically by default (neither plan randomizes the order): Places, then Room, then Wave.
  At the upper estimates the guard would stop the last Wave tests of each action first: on Main
  `testRealJourneyFromTheRoomProfileThroughTheWaveAndBack` (W1, the recorded walkthrough),
  `testReduceMotionPreviewAcceptJoinsWithoutAMove` and `testRolesNeverChange`; on Small
  `testLargestTextKeepsWaveScreensReachable` (W14a). A stopped test is a failure of the run, not of the
  product, and makes the run insufficient (§7).
- **What it does not cover.** The time outside the UI tests is bounded only by the estimate above, and
  Apple's own usage meter may count differently (queueing, set-up, rounding). The lead reads each action's
  start and end on GitHub as it runs (§5, step 6); only the founder can see Apple's meter or cancel.

## 5. Steps, and who can do each

| # | Step | Who | Reachable from the VPS? |
| --- | --- | --- | --- |
| 1 | Confirm that no existing Xcode Cloud workflow (Room Verification, Proximeet TestFlight, any other) has a Branch Changes, Pull Request or Tag start condition that `wave/approved-20260930T173856Z` would match, for example "any branch", `*` or `wave/*` | founder | **no**: App Store Connect only. GitHub's record is indirect evidence (below) |
| 2 | Create **Wave Verification** (below) | founder | no |
| 3 | Push `wave/approved-20260930T173856Z` at `<CANDIDATE_SHA>` (a new branch; no force, no merge), prove it with `git ls-remote`, and watch GitHub for ten minutes to confirm that no Xcode Cloud run started by itself | lead, after step 1 | yes (authorized) |
| 4 | Start Build on the branch, at `<CANDIDATE_SHA>` | founder | no |
| 5 | Confirm the built commit: the check runs' `head_sha` is `<CANDIDATE_SHA>` | lead | yes, read-only |
| 6 | Watch both actions' check runs to completion (start, end, conclusion, the summary's failures), and add up the compute minutes | lead | yes, read-only |
| 7 | Download each action's artifacts (§7) and hand them to the lead | founder | no |
| 8 | The manual checks (§10) | founder, on a device | no |

**GitHub's record of the start conditions (read-only, 30 September 2026 22:13Z).** None of the 11 pushes
or branch creations since Xcode Cloud was connected (28 September, between 18:48 and 19:31Z) started a
build within five minutes. Nine never got an Xcode Cloud run at all, among them three new branches
(`room-repair/verification-…`, `room-repair/xcode-checks-…`, `verification/room-d2-…`); the two that did
started 18 minutes to nearly 2 hours after the push, which fits a manual Start Build. The repository has no
pull requests and no tags. This contradicts an any-branch Branch Changes condition on either existing
workflow, but it cannot rule out a condition scoped to a pattern never pushed since (such as `wave/*` or
`testflight/*`), or any change in App Store Connect after the last Xcode Cloud activity (16:22:28Z). It is
evidence, not the inspection the founder asked for, which is why step 1 comes first.

**Creating Wave Verification (step 2), in App Store Connect → Apps → Proximeet Demo → Xcode Cloud →
Manage Workflows.** If the editor offers to duplicate **Room Verification**, duplicate it; otherwise
create a workflow with the same settings.
1. **General:** name `Wave Verification`; the existing product and repository.
2. **Environment:** the Room Verification workflow's Xcode and macOS, unchanged (§3). **Clean** on.
3. **Start Conditions:** only **Manual Start**, for the branch `wave/approved-20260930T173856Z` (or, if the
   editor offers only existing branches before the push, for any branch: a manual start never starts by
   itself). No Branch Changes, Pull Request, Tag or Schedule condition.
4. **Actions:** exactly two **Test** actions, and no Build or Archive action:

   | | Test action 1 | Test action 2 |
   | --- | --- | --- |
   | Platform, scheme | iOS, Proximeet | iOS, Proximeet |
   | Test Plan | **WaveVerificationMain** | **WaveVerificationSmall** |
   | Destination | Simulator: **iPhone 17 Pro Max** | Simulator: **iPhone 17e** (else iPhone 16e) |
   | OS | the Room Verification run's iOS (§3), else the latest 26.x offered | the same as action 1 |
   | Required to pass (if shown) | on | on |

   One destination per action: the compute guard counts per action and assumes one device each. If the
   Test Plan menu does not list both Wave plans, stop, save nothing and tell the lead; no other plan sets
   `PROXIMEET_WAVE_REVIEW` or the budget.
5. **Post-Actions:** none.
6. Save. Change nothing in Room Verification or Proximeet TestFlight.

## 6. When to stop

**Before starting, stop and tell the lead if:** the plans are not offered; any workflow would start by itself
on the push (step 1); the built commit is not `<CANDIDATE_SHA>`.

**During the run.** The guard is designed to hold the UI tests to their budgets (unverified until the run); the time outside them is only estimated. If Apple's usage meter shows the build
nearing 160 compute minutes for any other reason, the founder may cancel it; a cancelled action is not a
result, and the build still counts as the one authorized build.

**After the build.** Every criterion of §7 holds → verification is complete; stop. Anything else → the lead
diagnoses it from the check runs and the artifacts and reports it word for word. **No retry, no second build
and no contingency without a new authorization**, whatever the cause (a runner failure, a product defect, a
test defect, or a test the guard stopped).

## 7. Evidence, and what counts as a pass

**Read by the lead, on GitHub (read-only):** the check suite on `<CANDIDATE_SHA>`, one check run per action:
conclusion, start and end, `head_sha`, and the summary's errors, test failures and warnings. The summary
does not give executed or skipped counts, per-test times, screenshots or recordings.

**Downloaded by the founder** (build page → each Test action → Artifacts), all handed to the lead:
- **the result bundle** (`.xcresult`): every test's outcome and count, the tests' own captures and notes,
  and the screen recording of each test, kept whatever the outcome (`keepAlways`). The recordings are
  expected but unverified. The motion walkthrough is W1's recording (the whole real route, full holds) with,
  for the menu's Back and the blocked menu, the recordings and captures of W2, W8 and W10;
- **Test Products** and **the logs**. The Wave class prints `WAVE_REVIEW_FLAG_SEEN` when the plan's flag
  reaches its runner; the guard prints `RUN_BUDGET` lines, and `RUN_BUDGET_SPENT` for any test it stopped.

**A pass needs all of these:**
1. Both actions `success` on `<CANDIDATE_SHA>`, and the built commit is `<CANDIDATE_SHA>`.
2. Main executed exactly **280** tests (30 UI + 250 domain) and Small exactly **7**, every one passed:
   **287** native executions. The lead re-counts them at `<CANDIDATE_SHA>` before the run.
3. Nothing was skipped, expected to fail, repeated or retried, and no `RUN_BUDGET_SPENT` appears. A Wave,
   Room or Places test skipped with "runs only with …PROXIMEET_…" means the plan's settings were not
   applied: that is a failed run.
4. `WAVE_REVIEW_FLAG_SEEN` is in both actions' logs.
5. D2 passed on the VPS at `<CANDIDATE_SHA>`: exactly 8 executed, 0 failures.

**One expected note.** In W5 a real tap lands where Block was while the report is open. By the panels'
layout it should land on the report's second reason row and select "Harassment or harmful content"; the test
allows that, records it in a note, and fails only if the report closes, the screen changes or anyone is
blocked.

## 8. D2: the eight source-reading domain tests

`DomainSourceGuardTests` (2), `PlacesBackWiringTests` (3),
`PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation`, and chapter 09's
`RoomDemoTests/testTheRetiredWaveInformationPanelIsGone` and `WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring`
read the repository's files while they run. Xcode Cloud's test environment has only `ci_scripts` (and this
repository has none), so both Main plans skip them. `DomainSourceGuardTests` also covers `WaveDemo.swift`
(no persistence, networking, `Codable`, clock or location); the session mirror also pins the new
`DemoSession.closeWaveDemo(_:)`.
- **On the VPS:** export the candidate with `git archive <CANDIDATE_SHA>` into a scratch folder, run
  `swift test --package-path ProximeetDomain --filter
  'DomainSourceGuardTests|PlacesBackWiringTests|PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation|RoomDemoTests/testTheRetiredWaveInformationPanelIsGone|WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring'`
  and require exactly 8 executed, 0 failures, then the whole target (258 tests). Nothing is built inside
  the worktree.

## 9. Delivery: not authorized

No archive and no TestFlight distribution were authorized. After a sufficient pass, delivery is proposed
separately, with its own route. Apple processing, availability to Founder Preview and the install would each
be **PENDING FOUNDER**. A TestFlight build is a signed Release build for devices, not the simulator build
tested here.

## 10. Manual checks, kept apart from every automated row

No automated row covers any of these, and a green run says nothing about them; each is **PENDING FOUNDER**:
- **VoiceOver:** the reading order, focus after a panel closes and after the menu's Back, the modal panels,
  the decorative rings staying silent, "you (name)" in the direction line, and the hints (on "Preview Wave
  demo", on the menu's Back and on the disabled choices). The tests check the accessibility tree, not speech,
  and XCUITest cannot read hints.
- **The system Reduce Motion setting:** the tests use the app's own preview flag
  (`-ProximeetReduceMotionPreview`), not the setting.
- **Motion quality:** the 800 ms ring join on Accept and the 240 ms dissolves (the menu's Back included),
  judged on video.
- **The device:** the install, performance and feel on the founder's iPhone, and the founder's visual
  approval of the native Wave, including the two visible changes the decisions brought: the menu's header
  (Back and "Wave" instead of the "Proximeet" wordmark) and the blocked menu (its disabled choices, the
  disabled outline having no approved reference, and its generic line, which may wrap to three lines on the
  390-pt phone).

## 11. What the plans set

`scripts/validate_project.py` check 7 validates them.
- **The same options as the Room plans on 1a5f97e:** coverage off; 900 s per test by default and 1,200 s at
  most, with timeouts on; language `en`, region `US`; automatic captures kept for every test
  (`uiTestingScreenshotsLifetime` `keepAlways`); `parallelizable` false on every target; no repetition
  mode. Configuration `Wave Verification`, with an ID derived from the plan's name as the Room plans' were.
- **Environment:** the Room plans' nine variables (`PROXIMEET_ROOM_REVIEW`, `…_PLACES_…`, `…_SIGNAL_…`,
  `…_WRISTBAND_…`, `…_GUEST_LIST_…`, `…_PASS_…`, `…_BIRTHDAY_…`, `…_WELCOME_REVIEW` and
  `PROXIMEET_SHORT_HOLDS`), plus **`PROXIMEET_WAVE_REVIEW`**, all `"1"`, and
  **`PROXIMEET_RUN_BUDGET_SECONDS`**: `"6240"` in Main, `"2160"` in Small. The two recorded journeys, R1
  and W1, keep full holds whatever `PROXIMEET_SHORT_HOLDS` says; every other test uses short holds.
- **Targets:** `ProximeetUITests` (object ID `A8309941D6B07785FF53BCEC`) with explicit `selectedTests`;
  Main only: `ProximeetDomainTests` in `container:ProximeetDomain`, skipping the eight D2 tests.
- **What check 7 enforces:** the Room plans stay first, with `RoomVerificationMain` the default; every plan
  has `RoomVerificationMain`'s options apart from its environment, and may only add variables; any plan
  selecting `WaveReviewTests` or `RoomReviewTests` sets its flag, and the class reads it; every
  `WaveReviewTests` and `RoomReviewTests` method is selected by some plan; each Wave plan sets the budget,
  no Room plan does, the budgets fit 160 minutes as above, `RunBudget.swift` exists, and every UI test class a
  Wave plan selects calls `RunBudget.begin` first in `setUpWithError` and sets no allowance directly. Check
  11 scans `WaveDemo.swift` for dishonest copy, and holds `WaveView.swift` and `WaveDemo.swift` to a
  Wave-only list (no clock, scheduling, notification or logging API; no delivery or presence copy), with a
  known-answer fixture.
- **Command-line default:** `xcodebuild test -scheme Proximeet` without `-testPlan` still runs
  `RoomVerificationMain`. At this commit it skips the same eight source readers and runs 250 domain tests
  (204 at 1a5f97e); the Room Verification workflow's App Store Connect settings are unchanged.
