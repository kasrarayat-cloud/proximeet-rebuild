# Room verification in Xcode Cloud: the founder's runbook

The Room repair candidate is verified by native Xcode tests in Xcode Cloud, through two committed test
plans. These steps are done in App Store Connect by the founder. The lead has no Apple access, so every
Apple-side result is **PENDING FOUNDER** until the founder reports it or the lead reads it on GitHub.

- **Candidate:** branch `room-repair/verification-20260930T002530Z`, commit `<CANDIDATE_SHA>`: the
  branch's tip, whose full SHA the lead gives in the handoff. A document cannot contain its own commit's
  SHA, so it is not written here, and no commit is added to the branch until the run is done.
- **Rows:** `docs/verification/room-xcode-cloud-manifest.tsv`, one per required execution. The row IDs
  and test methods are those of `docs/verification/places-review-manifest.tsv` (scopes `room`,
  `room_regression_main` and `room_regression_small`).

| Plan | Destination | Tests | Rows |
| --- | --- | --- | --- |
| `TestPlans/RoomVerificationMain.xctestplan` (the scheme's default) | iPhone 17 Pro Max (440 × 956) | 25 UI tests and 204 domain tests | R1–R13, C1–C9, P1, P2, P4, D1 |
| `TestPlans/RoomVerificationSmall.xctestplan` | iPhone 17e (390 × 844) | 12 UI tests | R14, C10–C15, P9–P13 |

**Six domain tests are not run in Xcode Cloud** (row D2): `DomainSourceGuardTests`,
`PlacesBackWiringTests` and `PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation`.
- They read the repository's source files while they run.
- Xcode Cloud clones the source only into the environment that builds the tests. The environments that
  run them get only `ci_scripts`, and this repository has none.
- The Main plan skips them. The lead runs them on the VPS at `<CANDIDATE_SHA>` with
  `swift test --package-path ProximeetDomain`.

## 1. Before starting

1. On GitHub, confirm that the branch tip of `room-repair/verification-20260930T002530Z` is
   `<CANDIDATE_SHA>`. Xcode Cloud builds a branch, not a commit.
2. In App Store Connect → Apps → Proximeet Demo → Xcode Cloud → Manage Workflows, open **Proximeet
   TestFlight** and only read it:
   - Its Start Condition is Branch Changes on `testflight/internal-20260928` and nothing else.
   - Its actions are Archive with the TestFlight post-action. If it also has a Test action, stop and tell
     the lead: that action would now run `RoomVerificationMain`.
   - Close it without saving. It is not edited.

## 2. Create the workflow (once)

In the same Manage Workflows screen, add a workflow (+):

1. **General:** name it `Room Verification`. Product: Proximeet (the existing one). Repository: the
   connected one.
2. **Environment:** Xcode **26.6**, with the macOS version that Xcode Cloud pairs with it (its
   recommended or default choice). Turn **Clean** on, so nothing cached from another build is reused.
3. **Start Conditions:**
   - Delete the default Branch Changes condition.
   - Add **Manual Start** for Branch `room-repair/verification-20260930T002530Z` only.
   - Add no Branch Changes, Pull Request, Tag or Schedule condition. The workflow must never start by
     itself.
4. **Actions:** remove any Build or Archive action that the editor added. Add two **Test** actions:

   | | Test action 1 | Test action 2 |
   | --- | --- | --- |
   | Platform | iOS | iOS |
   | Scheme | Proximeet | Proximeet |
   | Test Plan | **RoomVerificationMain** | **RoomVerificationSmall** |
   | Destination | Simulator: **iPhone 17 Pro Max** | Simulator: **iPhone 17e** |
   | OS | the latest iOS 26.x offered | the same iOS as action 1 |
   | Required to pass (if shown) | on | on |

   - If the Test Plan menu does not list both `RoomVerificationMain` and `RoomVerificationSmall`, stop,
     save nothing and tell the lead. Do not choose another plan: no other plan sets the review flags.
   - If iPhone 17e is not offered, choose **iPhone 16e**, which is also 390 × 844, and tell the lead which
     one you chose. Do not choose any other model: the small-phone tests check 390-pt layouts.
   - Choose exactly one destination per action.
   - If the editor lets you name the actions, call them `Test - iOS Main` and `Test - iOS Small`.
   - Write down the iOS version you chose. The Codemagic builds used iOS 26.5 (23F77).
5. **Post-Actions:** none. No TestFlight distribution and no notifications that publish anything.
6. Save.

## 3. Start the build

1. In Xcode Cloud, choose **Room Verification** → **Start Build** → Branch
   `room-repair/verification-20260930T002530Z` → Start.
2. On the build's page, read the commit that Xcode Cloud actually built. It must be `<CANDIDATE_SHA>`.
   If it is not, the run does not count. Say so and do not start another.
3. Send the lead the build number and the start time.

**Expected compute.** This is an estimate from the last measured Codemagic durations (Mac mini M2,
iOS 26.5) in the manifest. Xcode Cloud's pace is unmeasured.

| | Test time | With build-for-testing, simulator boot, test runner start and video | Estimate |
| --- | --- | --- | --- |
| Main | about 2,600–2,800 s (25 UI tests); the domain tests take seconds | about 10–15 min more | **55–65 min** |
| Small | about 1,350–1,550 s (12 UI tests) | about 10–15 min more | **35–40 min** |

- R7 and R14 have never passed, so their last times (about 250 s each) stopped at a failure. The
  rewritten test estimates itself at 420–600 s on each iPhone (`testLargestTextKeepsRoomReachable`'s
  comment), and that is what the table uses.
- The two actions run side by side, so the build takes about an hour and uses about **90–105 compute
  minutes**.
- The Codemagic hosts were at times 2.7–7 times slower per step. Each test may run 900 s; only a test that
  asks for more gets up to the 1,200-s maximum, and `testLargestTextKeepsRoomReachable` (R7, R14) asks for
  it. Coverage is off, as in the measured Codemagic runs.
- The chapter's recorded Xcode Cloud allowance is 150 minutes and 4 runs. One full run uses more than
  half of it, so a second full run does not fit.
- Buying extra compute is a founder decision and is not part of this runbook.

## 4. Results

- **On GitHub:** Xcode Cloud posts a check suite on the built commit, with one check run per action,
  named in the form `Proximeet | Room Verification | <action name>` (for example `Test - iOS Main` and
  `Test - iOS Small` if the actions were named as suggested). Each summary has a table of the tests.
  The lead reads these read-only.
- **To download** (build page → each Test action → Artifacts). Give all three to the lead:
  - **Test Products;**
  - **the result bundle** (`.xcresult`). It holds every test's outcome, the tests' own captures and
    notes and, expected but unverified until the first run, a screen recording of every test kept even
    when the test passes;
  - **the logs.**
- The captures show the simulator's real clock. The Codemagic harness set it to 9:41 and nothing does
  that here. No test reads the status bar's pixels.

**What counts as a pass. All of these must hold:**
1. Both actions are green on `<CANDIDATE_SHA>`.
2. Main executed exactly 229 tests: all 25 UI tests of its plan and 204 domain tests. Small executed
   exactly its 12. Every one passed.
3. No test was skipped, expected to fail, repeated or retried. A skipped Room, Places or Signal test with
   the message "runs only with TEST_RUNNER_PROXIMEET_…" means the plan's settings were not applied. That
   is a failed run, not a pass.
4. Row D2 passed on the VPS at `<CANDIDATE_SHA>`.

A test that did not run is not a pass. One run's failure stands: it is reported, not rerun until it
passes.

## 5. After a sufficient pass: delivery

Only after every row in the manifest has passed at `<CANDIDATE_SHA>`, and after the founder's go:

1. **The lead** fast-forwards the TestFlight branch to the verified commit:
   - check with `git merge-base --is-ancestor <tip of testflight/internal-20260928> <CANDIDATE_SHA>`;
   - push with `git push origin <CANDIDATE_SHA>:refs/heads/testflight/internal-20260928`, with no
     `--force`, so git refuses anything that is not a fast-forward;
   - confirm with `git ls-remote origin refs/heads/testflight/internal-20260928`.
2. **That push triggers the existing Proximeet TestFlight workflow** (Archive). Nothing is started by
   hand, and that workflow is not edited. Xcode Cloud assigns the next build number.
3. **The founder confirms each of these separately** in App Store Connect → TestFlight:
   - the build finished processing;
   - it is available to the **Founder Preview** group;
   - it installs on the iPhone.

   Until then, each of these is PENDING FOUNDER. The TestFlight build is a signed Release build for
   devices, so it is not the same binary as the simulator build tested here.

## 6. What the plans set

The plans are JSON version 1 files (Xcode 15 or later). `scripts/validate_project.py` check 7 validates
them.

- **Targets:**
  - `ProximeetUITests` by its project object ID `A8309941D6B07785FF53BCEC`, with explicit
    `selectedTests`;
  - Main only: `ProximeetDomainTests` in `container:ProximeetDomain`, minus the six D2 tests.
  - Every target sets `parallelizable` to false. There is no `testRepetitionMode`.
- **Environment variables, all set to "1":**
  - `PROXIMEET_ROOM_REVIEW`, `PROXIMEET_PLACES_REVIEW`, `PROXIMEET_SIGNAL_REVIEW`,
    `PROXIMEET_WRISTBAND_REVIEW`, `PROXIMEET_GUEST_LIST_REVIEW`, `PROXIMEET_PASS_REVIEW`,
    `PROXIMEET_BIRTHDAY_REVIEW`, `PROXIMEET_WELCOME_REVIEW` and `PROXIMEET_SHORT_HOLDS`.
  - These are the names the UI tests read. Codemagic passed the same names with xcodebuild's
    `TEST_RUNNER_` prefix.
  - Only the Room, Places and Signal flags gate selected classes. `BandSignalInteractionTests` has no
    flag.
- **Holds:** `PROXIMEET_SHORT_HOLDS=1` reaches every test, but R1 keeps full holds whatever it says
  (`RoomReviewTests.fullHolds`), so its recording can be read like build 3's walkthrough. P1, C8 and C10
  use short holds, as in the Codemagic `room_regression` runs. Assertions are the same either way.
- **Other options:**
  - execution time allowance 900 s by default and 1,200 s at most, with timeouts on;
  - language `en`, region `US`;
  - automatic screen capture kept for every test (`uiTestingScreenshotsLifetime` `keepAlways`), in Xcode's
    default capture format (screen recordings since Xcode 15). The plans set no capture-format key: the
    value `screenRecording` is confirmed only for `.xctestrun` files, and an unrecognised plan value could
    stop the plan from loading.
- **Left at Xcode's defaults:** code coverage, attachment lifetime and variable expansion. The tests mark
  their own captures and notes `keepAlways`.

**Side effect on command-line runs:** `xcodebuild test` or `test-without-building` with `-scheme
Proximeet` and no `-testPlan` now uses `RoomVerificationMain`, including its environment. The retired
Codemagic harness depended on the old autocreated plan. It is not maintained for this change; see the
repair report.
