# Wave verification in Xcode Cloud: the proposal

**Status: PROPOSAL. No run is authorized.** Nothing in this document has been run on an Apple system, and
nothing here is a result. The Wave (chapter 09) is implemented in source and checked on Linux only; a Linux
type-check is not a native compile. Every Apple-side outcome stays **PENDING FOUNDER** until the founder
reports it or the lead reads it on GitHub.

- **Candidate:** branch `wave/approved-20260930T173856Z`, commit `<CANDIDATE_SHA>`: the branch tip whose
  full SHA the lead gives in the handoff. A document cannot contain its own commit's SHA. At the time of
  writing the branch exists only on the VPS; Xcode Cloud builds branches from GitHub, so it must be pushed
  first, and that push needs its own authorization (step 1 of §5).
- **Base:** the verified Room commit `1a5f97e0fe73168e5f63e392182507e457209964`
  (`room-repair/xcode-checks-20260930`). Its Room Verification run is the model for this one (§4).
- **Rows:** `docs/verification/wave-xcode-cloud-manifest.tsv`, one per required execution.
- **Plans:** `TestPlans/WaveVerificationMain.xctestplan` and `TestPlans/WaveVerificationSmall.xctestplan`,
  listed in the scheme after the two Room plans. `RoomVerificationMain` stays the scheme's default.

## 1. The bound proposed

| | What | Apple compute (estimate, §4) | Authorized? |
| --- | --- | --- | --- |
| **Run 1** | One build of a new manual-start **Wave Verification** workflow: its two Test actions, side by side, at `<CANDIDATE_SHA>` | **about 105–160 compute minutes** | no |
| **Contingency** | At most one more build, only under the rules of §6 | at most the same again | no |
| **Archive** | Not part of this proposal. After a sufficient pass it is asked for separately (§9) | about 6 min (the Room's archive took 5 min 37 s) | no |

Nothing else is proposed: no Codemagic, no TestFlight delivery, no change to the **Room Verification** or
**Proximeet TestFlight** workflows, no paid compute. Buying compute is a founder decision outside this
proposal.

## 2. The test inventory

| Plan | Destination | UI tests | Domain tests | Executed in total | Rows |
| --- | --- | --- | --- | --- | --- |
| `WaveVerificationMain` | iPhone 17 Pro Max (440 × 956) | **30**: 14 Wave, 13 Room, 3 Places | **246** | **276** | W1–W10, W11a, W11b, W12, W13, R1–R13, P1, P4, C1, D1 |
| `WaveVerificationSmall` | iPhone 17e (390 × 844) | **7**: 2 Wave, 1 Room, 4 Places | none | **7** | W14a, W14b, R14, C15, P9, C12, C11 |
| none (the VPS) | Linux, `swift test` | none | 8 | 8 | D2 |

**Why these rows, and no others.** Every row here runs code that the Wave changed, and the Wave changed
only these product files: `RoomDemo.swift` and the new `WaveDemo.swift` (domain), `RoomView.swift` (the
profile's action is now "Preview Wave demo", the Wave information panel 66:134 is gone, the components are
internal, and a run with a Wave draws the new `WaveView.swift`), `DemoSession.swift` (three additions) and
`DebugFixtures.swift` (the Wave fixtures, `-ProximeetFixtureName`, and the name threaded through the shared
fixture path).
- **Wave:** every `WaveReviewTests` method; all 14 run on the 440-pt phone (W1–W13, W11 being two rows,
  W11a and W11b). The largest-text checks are two methods, `testLargestTextKeepsWaveScreensReachable`
  (the 12 screens and the two real Leaves) and `testLargestTextKeepsWavePanelsReachable` (the 7
  overlays), split from the one `testLargestTextKeepsWaveReachable` with every check kept (§4). Both run
  on whichever phone runs them, so, like the Room's R7 and R14, they run on the 390-pt phone as well (W14a,
  W14b). `testCaptureApprovedScreensAndOverlays` and
  `testReduceMotionPreviewAcceptJoinsWithoutAMove` read 440-pt geometry and stay on the larger phone.
- **Room:** all 13 `RoomReviewTests` methods on the 440-pt phone and the largest-text one on the 390-pt
  phone, as in the Room plans. The removal of the Wave information panel changed the tests' shared
  helpers (`assertShown`, `assertProfile`, `checkSameIntent`, `panelID`, `sampleLeaks` and others) and the
  `RoomText`, `Panel` and `Shown` enums, and every one of the 13 tests goes through them. The Room's
  overlays fall from 8 to 7 reachable.
- **Places:** every Places UI test that goes into the Room, on the phone its Room plan ran it on. They were
  found by reading the test sources: the callers of `returnToNowThroughRoom` (Preview room demo, Enter
  room demo, Leave and disappear, Return to Places), and `testBackRoutesKeepTheCategoryAndTheDraft`, which
  opens the Room entry and leaves it by its Back. That is P1, P4 and C1 on the larger phone and C15, P9,
  C12 and C11 on the smaller one. **P4 and P9 are added to the lead's list** (P1, C1; C15, C12, C11): they
  go through the Room the same way.
- **Left out, with the reason.** The other 16 regression rows of the Room plans (C2, C3, P2, C9, C4–C8 on
  the larger phone; P10–P13, C10, C13, C14 on the smaller one) never open the Room. They reach the changed
  fixture code only through its shared path, with no `-ProximeetFixtureName`, which every Room and Wave
  fixture launch above runs as well. Leaving them out is the one deliberate residual risk of this bound.
  To remove it, the founder can add both Room plans to the same build (about 77 more compute minutes, as
  measured on 1a5f97e).
- **Domain:** the whole `ProximeetDomainTests` target on the simulator, minus the eight tests that read the
  repository's files (D1): the Room Main plan's six, and the two that chapter 09 adds
  (`RoomDemoTests/testTheRetiredWaveInformationPanelIsGone`, `WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring`),
  which both Main plans now skip as well. Those eight run on the VPS (D2, §8). Each of the two also skips
  itself when it finds no source tree, which is a safety net rather than the plan: a skip on Xcode Cloud
  would break criterion 3 of §7.

## 3. Devices, Xcode and the workflow

- **Devices.** Main on **iPhone 17 Pro Max**. Small on **iPhone 17e**, or **iPhone 16e** if 17e is not
  offered: both are 390 × 844. Choose no other model, and record which one was used. Both actions use the
  same iOS: the one the Room Verification run on 1a5f97e used (read with its Xcode version, below),
  or, if that is no longer offered, the latest iOS 26.x offered with that Xcode; record it.
- **Xcode: the one the Room Verification workflow used for its successful run on 1a5f97e** (App Store
  Connect build `29af42f6-f5c7-49ad-bd33-9d69d4ead089`), so that the Room and the Wave results come from
  one toolchain. The Room runbook set that workflow to **Xcode 26.6**, and the Room's Codemagic builds
  compiled on Xcode 26.6 (17F113). The GitHub check runs of that build do not name the Xcode version (the
  lead read both summaries), so the version actually used is **PENDING FOUNDER**: read it on the Room
  Verification workflow's Environment, or in build 29af42f6's log, and use exactly that. Do not upgrade
  Xcode for this run.
- **The workflow.** A new manual-start workflow, **Wave Verification**, with the Room Verification
  workflow's Environment (§5). The Room Verification and Proximeet TestFlight workflows are only read.
- **Expected GitHub check runs.** On 1a5f97e the Room's appeared as
  `Proximeet | Room Verification | RoomVerificationMain - iOS (Proximeet)` and
  `Proximeet | Room Verification | RoomVerificationSmall - iOS (Proximeet)`. The Wave's are expected as
  `Proximeet | Wave Verification | WaveVerificationMain - iOS (Proximeet)` and
  `… | WaveVerificationSmall - iOS (Proximeet)`. That naming is an expectation, not a fact, until the run.

## 4. Compute estimate

**Measured, Room Verification on 1a5f97e** (GitHub check runs, both `success`, 0 test failures):

| Action | Check run | Start–end (UTC, 30 Sep) | Wall time | Its UI tests' Codemagic-measured time |
| --- | --- | --- | --- | --- |
| RoomVerificationMain | 109967416420 | 14:51:12–15:42:07 | 50 min 55 s | 2,607–2,787 s (25 tests; R7 taken as 420–600 s) + 204 domain tests |
| RoomVerificationSmall | 109956469075 | 14:51:10–15:17:38 | 26 min 28 s | 1,350–1,530 s (12 tests; R14 taken as 420–600 s) |

Xcode Cloud therefore took **1.04–1.18 times** the Codemagic-measured test time per action, build, simulator
and runner start included. The earlier run on 062ea35 (Main 41 min 12 s with 3 failures, Small 26 min 52 s)
agrees. Per-test times on Xcode Cloud are not visible on GitHub.

**Scaled to the Wave inventory:** the Codemagic-measured times in the manifest, times the measured 1.04–1.18.
The Wave tests have never run, so their times are estimates. The two largest-text tests state their own:
`testLargestTextKeepsWaveScreensReachable` 520–740 s and `testLargestTextKeepsWavePanelsReachable`
240–380 s (together 760–1,120 s, the one test's 780–1,120 s before the split). The others are taken from
the Room test of the same shape, scaled by the number of launches and contexts.

| Action | Room and Places rows | Wave rows (estimate) | Test time | Wall-time estimate |
| --- | --- | --- | --- | --- |
| WaveVerificationMain | 2,072–2,232 s (R1–R13, P1, P4, C1) | 2,460–3,760 s (W1–W13, W11a and W11b) | 4,532–5,992 s | **about 80–120 min** |
| WaveVerificationSmall | 681–841 s (R14, C15, P9, C12, C11) | 760–1,120 s (W14a, W14b) | 1,441–1,961 s | **about 25–40 min** |

- The two actions run side by side, so run 1 takes about 80–120 minutes and uses **about 105–160 compute
  minutes** (Xcode Cloud counts each action's time; the Room run used about 77 compute minutes).
- C15 and P9 were measured only as a run of six (614 s) and C12 as a run of four (253 s); they are taken
  as equal shares. R7 and R14 never passed on Codemagic. Since chapter 09 the Room test's own comment
  estimates 350–510 s (six checks instead of seven).
- **The largest-text timing risk is estimated to be within limits after a split; this is unverified**
  until a native run times it. The one largest-text Wave test's upper
  estimate (1,120 s) times Xcode Cloud's measured 1.18 was about 1,320 s, beyond the 1,200-s maximum the
  plans take from the Room plans, so W11 or W14 could have been stopped by its allowance rather than by a
  defect. It is now two methods, sharing one check runner, each with its own list of checks, and no
  check dropped:

  | Rows | Method | Checks | Codemagic pace | × 1.04–1.18 | Allowance |
  | --- | --- | --- | --- | --- | --- |
  | W11a, W14a | `testLargestTextKeepsWaveScreensReachable` | 12 screens (92 texts and buttons), then the two real Leaves (the incoming review's bar, inside the report preview) | 520–740 s | about 540–875 s | asks for 1,200 s: its upper figure is within 25 s of the 900-s default |
  | W11b, W14b | `testLargestTextKeepsWavePanelsReachable` | 7 overlays (44 texts and buttons), the report with a reason selected | 240–380 s | about 250–450 s | the plans' 900-s default |

  The estimates come from the Room's six largest-text checks (229–322 s for six launches and 45 texts
  and buttons in builds 6abc1b80–6abc3ebe), fitted, not measured, as about 12–16 s a launch and 3.5–5 s a
  text or button; each range also covers 38–54 s a check, the Room's own spread. The split is not even: the screens carry 12 of
  the 19 launches, 92 of the 136 texts and buttons and both Leaves, and a screen at the largest text is
  the longer page to scroll, so the screens method stays the longest Wave test and the one to watch. Its
  upper figure at Xcode Cloud's pace leaves about 325 s under its 1,200-s allowance. The split needed no
  change to the plans' options (still the Room plans' 900 s and 1,200 s).
- Main's upper estimate is more than twice the Room's longest action (51 min). This VPS cannot know
  whether Xcode Cloud limits how long a single action may run.
- Each test may take 900 s, and 1,200 s if it asks for more, so no single test can hold an action open
  indefinitely.
- The remaining Xcode Cloud allowance is visible only in App Store Connect: **PENDING FOUNDER**.

## 5. Steps, and who can do each

| # | Step | Who | Reachable from the VPS? |
| --- | --- | --- | --- |
| 1 | Push `wave/approved-20260930T173856Z` at `<CANDIDATE_SHA>` to GitHub (a new branch; no force, no merge), then prove it with `git ls-remote` | lead | yes, **once authorized** |
| 2 | Before that push, confirm that no Xcode Cloud workflow has a Branch Changes, Pull Request or Tag start condition that the new branch would match (otherwise the push itself would start a build) | founder | no: App Store Connect only |
| 3 | Create **Wave Verification** (below) | founder | no |
| 4 | Start Build on the branch, and confirm the built commit is `<CANDIDATE_SHA>` | founder | no; the lead also checks the check runs' `head_sha` |
| 5 | Read the check runs: `gh api repos/kasrarayat-cloud/proximeet-rebuild/commits/<CANDIDATE_SHA>/check-runs` | lead | yes, read-only |
| 6 | Download each action's artifacts (§7) and hand them to the lead | founder | no |
| 7 | Run D2 at the candidate (§8) | lead | yes |
| 8 | The manual checks (§10) | founder, on a device | no |

**Creating Wave Verification (step 3), in App Store Connect → Apps → Proximeet Demo → Xcode Cloud →
Manage Workflows.** If the editor offers to duplicate **Room Verification**, duplicate it; otherwise
create a workflow with the same settings.
1. **General:** name `Wave Verification`; the existing product and repository.
2. **Environment:** the Room Verification workflow's Xcode and macOS, unchanged (§3). **Clean** on.
3. **Start Conditions:** only **Manual Start**, branch `wave/approved-20260930T173856Z`. No Branch
   Changes, Pull Request, Tag or Schedule condition.
4. **Actions:** exactly two **Test** actions, and no Build or Archive action:

   | | Test action 1 | Test action 2 |
   | --- | --- | --- |
   | Platform, scheme | iOS, Proximeet | iOS, Proximeet |
   | Test Plan | **WaveVerificationMain** | **WaveVerificationSmall** |
   | Destination | Simulator: **iPhone 17 Pro Max** | Simulator: **iPhone 17e** (else iPhone 16e) |
   | OS | the Room Verification run's iOS (§3), else the latest 26.x offered | the same as action 1 |
   | Required to pass (if shown) | on | on |

   If the Test Plan menu does not list both Wave plans, stop, save nothing and tell the lead; do not pick
   another plan, because no other plan sets `PROXIMEET_WAVE_REVIEW`.
5. **Post-Actions:** none.
6. Save. Change nothing in Room Verification or Proximeet TestFlight.

## 6. When to stop, and the contingency

**Stop before starting, and tell the lead, if:** the plans are not offered; a workflow would start by
itself on the push (step 2); the built commit is not `<CANDIDATE_SHA>` (that run does not count, and no
other is started).

**During the run.** An action still running at twice its estimate may be cancelled by the founder. A
cancelled action is not a result, and the build still counts as the run.

**After run 1.**
- Every criterion of §7 holds → verification is complete. **Stop.** No further Apple run.
- Anything else → no rerun until the lead has diagnosed it from the check run and the result bundle and
  reported it word for word. One run's failure stands; it is not rerun until it passes.

**The one contingency run,** only after that diagnosis and the founder's go:
- **The runner failed before a test ran** (runner not initialized, simulator not found, an infrastructure
  error with no test result): the same action again on the same commit. No test result exists, so this is
  not a retry.
- **A test or the product was wrong:** the fix makes a new candidate, and the contingency runs, at that
  commit, every action with a row the fix could touch. If any product file changed (`Proximeet/`,
  `ProximeetDomain/Sources/`, the project or the assets), that is **both actions, in full**: every row
  must pass on the commit that is delivered. If only test code changed, it is each action that runs the
  changed test code. Rerunning single rows would need a third plan in the scheme, which would itself
  change the candidate, so it is not proposed.
- **After the contingency, stop whatever the outcome** and report. Any further run needs a new
  authorization.

## 7. Evidence, and what counts as a pass

**Read by the lead, on GitHub (read-only):** the check suite on `<CANDIDATE_SHA>`, one check run per action:
conclusion, start and end, `head_sha`, and the summary's errors, test failures and warnings. The summary
does not give executed or skipped counts.

**Downloaded by the founder** (build page → each Test action → Artifacts), all handed to the lead:
- **the result bundle** (`.xcresult`): every test's outcome and count, the tests' own captures and notes,
  and the screen recording of each test, kept whatever the outcome (`keepAlways`). The recording was
  expected but unverified in the Room runbook, and it still is;
- **Test Products** and **the logs**. The Wave class prints `WAVE_REVIEW_FLAG_SEEN` when the plan's flag
  reaches its runner, so the logs prove the flag arrived.

The VPS has no Xcode, so if the lead cannot read the counts from the bundle, the founder reads them on the
build's Tests page and sends them. The captures show the simulator's real clock; no test reads it.

**A pass needs all of these:**
1. Both actions `success` on `<CANDIDATE_SHA>`, and the built commit is `<CANDIDATE_SHA>`.
2. Main executed exactly **276** tests (30 UI + 246 domain) and Small exactly **7**, every one passed.
   Those counts assume the tests at `<CANDIDATE_SHA>`; the lead re-counts them there before the run.
3. Nothing was skipped, expected to fail, repeated or retried. A Wave, Room or Places test skipped with
   "runs only with …PROXIMEET_…" means the plan's settings were not applied: that is a failed run.
4. `WAVE_REVIEW_FLAG_SEEN` is in both actions' logs.
5. D2 passed on the VPS at `<CANDIDATE_SHA>`.

## 8. D2: the eight source-reading domain tests

`DomainSourceGuardTests` (2), `PlacesBackWiringTests` (3),
`PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation`, and chapter 09's
`RoomDemoTests/testTheRetiredWaveInformationPanelIsGone` and `WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring`
read the repository's files while they run. Xcode Cloud's test environment has only `ci_scripts` (and this repository has none), so both Main plans
skip them. `DomainSourceGuardTests` also covers the new `WaveDemo.swift` (no persistence, networking,
`Codable`, clock or location).
- **On the VPS (proposed):** export the candidate with `git archive <CANDIDATE_SHA>` into a scratch folder,
  run `swift test --package-path ProximeetDomain --filter
  'DomainSourceGuardTests|PlacesBackWiringTests|PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation|RoomDemoTests/testTheRetiredWaveInformationPanelIsGone|WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring'`
  and require exactly 8 executed, 0 failures, then the whole target (254 tests). Nothing is built inside
  the worktree.
- **On GitHub Actions (optional, only if authorized):** as the Room did on
  `verification/room-d2-1a5f97e-20260930` (tip `169cb2d` = 1a5f97e + one workflow file; run 36742192843,
  `ubuntu-24.04`, "Executed 6 tests, with 0 failures"): a separate branch with one commit adding a
  workflow that checks out exactly `<CANDIDATE_SHA>`. That branch is never merged: validator check 11
  fails on any `.github/workflows` file.

## 9. Delivery: not proposed here

After a sufficient pass, and only with a separate authorization. For reference, the Room's archive
(`Proximeet | Proximeet TestFlight | Archive - iOS`, check run 109984548371, 16:16:45–16:22:22Z) ran on
1a5f97e itself, while `testflight/internal-20260928` stayed at `67bf1a9` (`git ls-remote`). The route is
decided when that authorization is given. Apple processing, availability to Founder Preview and the install
are each **PENDING FOUNDER**. A TestFlight build is a signed Release build for devices, not the simulator
build tested here.

## 10. Manual checks, kept apart from every automated row

No automated row covers any of these, and a green run says nothing about them:
- **VoiceOver:** the reading order, focus after a panel closes, the modal panels, and the decorative rings
  staying silent. The tests check the accessibility tree, not speech.
- **The system Reduce Motion setting:** the tests use the app's own preview flag
  (`-ProximeetReduceMotionPreview`), not the setting.
- **Motion quality:** the 800 ms ring join on Accept and the 240 ms dissolves, judged on video.
- **The device:** the install, performance and feel on the founder's iPhone, and the founder's visual
  approval of the native Wave.

Each is **PENDING FOUNDER**.

## 11. What the plans set

`scripts/validate_project.py` check 7 validates them.
- **The same options as the Room plans on 1a5f97e:** coverage off; 900 s per test by default and 1,200 s at
  most, with timeouts on; language `en`, region `US`; automatic captures kept for every test
  (`uiTestingScreenshotsLifetime` `keepAlways`); `parallelizable` false on every target; no repetition
  mode. Configuration `Wave Verification`, with an ID derived from the plan's name as the Room plans'
  were.
- **Environment:** the Room plans' nine variables (`PROXIMEET_ROOM_REVIEW`, `…_PLACES_…`, `…_SIGNAL_…`,
  `…_WRISTBAND_…`, `…_GUEST_LIST_…`, `…_PASS_…`, `…_BIRTHDAY_…`, `…_WELCOME_REVIEW` and
  `PROXIMEET_SHORT_HOLDS`), plus **`PROXIMEET_WAVE_REVIEW`**, all `"1"`. The two recorded journeys, R1
  and W1, keep full holds whatever `PROXIMEET_SHORT_HOLDS` says; every other test uses short holds.
- **Targets:** `ProximeetUITests` (object ID `A8309941D6B07785FF53BCEC`) with explicit `selectedTests`;
  Main only: `ProximeetDomainTests` in `container:ProximeetDomain`, skipping the eight D2 tests.
- **What check 7 now also enforces:** the Room plans stay first, with `RoomVerificationMain` the default;
  every plan has `RoomVerificationMain`'s options apart from its environment, and may only add
  variables; any plan selecting `WaveReviewTests` or `RoomReviewTests` sets its flag, and the class reads
  it; every `WaveReviewTests` and `RoomReviewTests` method is selected by some plan. Check 11 now also
  scans `WaveDemo.swift` for dishonest copy, and holds `WaveView.swift` and `WaveDemo.swift` to a Wave-only
  list (no clock, scheduling, notification or logging API; no delivery or presence copy), with a known-answer
  fixture. No approved Wave string needed an exception.
- **Command-line default:** `xcodebuild test -scheme Proximeet` without `-testPlan` still
  runs `RoomVerificationMain`, and the Room Verification workflow is unchanged (its App Store Connect
  settings; at this commit `RoomVerificationMain` skips two more tests and runs 246 domain tests, 204 at
  1a5f97e).
