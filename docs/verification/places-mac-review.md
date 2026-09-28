# Places — manual macOS verification run

The workflow `proximeet-places-review` in the root `codemagic.yaml` builds the approved Places
(chapter 07) as an unsigned Debug app for the iOS Simulator. It runs the Places XCTest review with
real taps and typing, records the real journey from Welcome into Places, and runs every earlier
chapter's checks on the same code. Then it packages the review.

It starts only by hand: there is no `triggering` section. It has no code signing, Apple
credentials, provisioning, archive/IPA, TestFlight, publishing, notifications or environment
groups. Its limit is 28 minutes. Two twins run the same steps: `proximeet-places-review-short`
(24 minutes) and `proximeet-places-review-35` (35 minutes, for the recovery in §0b).
Results are recorded in each build's own artifacts and in the delivery message.

## 0. Scopes, one manifest

Not everything fits in one build. The run input `PLACES_REVIEW_SCOPE` picks a scope, and
each scope is its own build. `docs/verification/places-review-manifest.tsv` lists, for every
scope:
- every execution;
- its device;
- its run and result bundle;
- its time bound;
- whether it is required.

`scripts/places_review.sh` builds its xcodebuild runs from that file.
`scripts/places_review_results.py` judges every row against the build's logs.

Each scope uses the selected iPhone 17 Pro Max ("main") and one other device, and the two run in
parallel. Every test with 440-point pixel anchors runs on main, or on device B, the same model.

| Scope | Main (iPhone 17 Pro Max) | The other device | Executions |
| --- | --- | --- | --- |
| `places` | The recorded journey (alone, full holds). Then the Birthday gate on the way back, the largest text, rapid taps and interruptions, the Reduce Motion preview, relaunch and the seven screens | The smaller iPhone: Back routes with the retained category and draft, the band change, all twelve intent-venue combinations, the largest text, missing choices and the guarded explanation, and the seven screens | 13 (11 unique) |
| `signal` | Signal's journey (unrecorded), twelve states, first choices, rapid changes and the endpoint. Then build 6ab7e942's device-B tests (the same model): the age-gate journey, relaunch, the Reduce Motion preview, largest text, missing intent, the two `BandSignalInteractionTests` and both Guest List keyboard tests | The smaller iPhone: the keyboard Done/Back check and Signal's largest text | 16 (14 unique) |
| `regressions` | The Wristband (7), Pass (4) and Birthday (2) tests, the two walkthroughs first | Device B (a clone of main): the Guest List's paste test, its on-screen-keyboard tests with the names test, Welcome (all 4), a time-gated repeat of the paste test, and last its hardware Tab test | 27 required (+1 optional repeat) |
| `correction` | See §0a | The smaller iPhone; see §0a | 15 required |
| `gate_finish` | Recovery build 3; see §0b. C3, then C1 and C2, then C4, C5, C9, C6, C7, C8 (required); then S3–S6 and S8 (extras) | The smaller iPhone: P9–P13, then S15 and S16 (extras) | 9 required, 12 extras |
| `sweep_finish` | Recovery build 4; see §0b. P1–P6 (P1 short holds, not recorded), S9, S10, S12, S13, then M1–M3 | Device B (a clone of main): M4–M13, B1, B10–B13, and last B15 (hardware keys) | 29 required |
| `regression_finish` | Recovery build 5; see §0c. One queue shared with device B; preferred here: P3, then P6 and P1, then M2, then S9, S10, S12, S13 | Device B (a clone of main), preferred: B2 and B3, then B4–B7, then B8 and B9 | 16 required |
| `sweep` | P1, the real journey (short holds, not recorded), then P2–P6: the Birthday gate on the way back, the largest text, rapid taps and interruptions, the Reduce Motion preview and relaunch; then S3–S6, S8–S10, S12 and S13: both Guest List keyboard tests, the age-gate journey, twelve states, first choices, largest text, missing intent, the Reduce Motion preview and relaunch | The smaller iPhone: P9–P13, the band change, all twelve intent-venue combinations, the largest text, missing choices and the guarded explanation, and the seven screens; then S15 and S16, the keyboard Done/Back check and Signal's largest text | 22 required |

**Devices and time (after build `6ab84ede`).**
- Measurements from builds `6ab84ede` and `6ab85be6` set the device plan:
  - A simulator restarted after its first boot was not ready for 3.5 to 5.7 minutes.
  - A device first booted while the other ran tests needed about 15 minutes to reach its first test.
  - A second first boot during the compilation slowed it by about 2 minutes.
- So both devices boot during the compilation and neither is ever restarted. For regressions, device B is cloned from main before either boots.
- The UI deadline is 1380 s after the gate. The run input `PLACES_UI_DEADLINE_SECONDS` (600 to 2040) changes it; the source gate rejects any other value. A value above 1380 belongs only to the 30-, 35- and 40-minute workflows (1440, 1740 and 2040; see §0c for the 30- and 40-minute ones).
- `proximeet-places-review-short` runs the same steps with a 24-minute limit. Its own `PLACES_UI_DEADLINE_SECONDS` is 1110 (at the worst 72 + 1110 + 75 + 100 + about 40 = 1397 s). It is for a final build that must fit what is left of the chapter's 90 free minutes.
- `proximeet-places-review-35` runs the same steps with a 35-minute limit and one more (the preview copy, §2). Its own `PLACES_UI_DEADLINE_SECONDS` is 1740 (at the worst 72 + 1740 + 75 + 100 + about 45 = 2032 s of its 2100), raised from 1680 after build `6ab8adb4` measured the main device's first test 666 s after the gate.
- The regressions repeat (B14) starts only while 420 s are left before the deadline (300 s until the recovery). At 300 s it was a coin flip that left the required hardware-key run (B15) about 110–125 s for a run measured at 103 s.

`signal` and `regressions` preserve the earlier coverage: 41 unique test methods in 43 required
executions (builds `6ab7e942` and `6ab81e22`).

The one intentional change is Signal's endpoint. Continue preview now opens Places at Now instead
of "End of this preview.". Five tests changed their expectation from the message to Places:
- `SignalReviewTests`: `testWalkthroughRealJourney`, `testRapidChangesAndInterruptionsStayConsistent`
  and `testEndpointDuplicateTapsAndBack`;
- `BandSignalInteractionTests`: `testBandSignalInteraction` and
  `testReducedMotionStillUpdatesImmediately`.

In each, one Back returns to Signal, and nothing was dropped.

**Automatic retries are off in every scope.** Each of these fails the verdict:
- a test that fails, even once;
- a skipped test;
- an interrupted test (started, with no outcome recorded);
- a missing required execution;
- a run that does not exit 0.

A regressions repeat that is left unrun for time is recorded as such. If it runs, it must pass.
So must an extra (kind `extra`): it starts only while its bound plus 60 s is left before the
deadline, and is listed as "not run (time budget)" otherwise.

**Infrastructure reruns are not retries.** A run whose first attempt started no test is run once
more, never twice, and both attempts are listed (the first as `infra` in `runs.txt`, with its
reason); the second attempt's exit is the run's exit. There are two such cases:
- the simulator was not found (exit 70; build `6ab7dbf0`): it is booted again first;
- the test runner failed to initialize for UI testing and no `Test Case '…' started` line followed
  (build `6ab8c585`: "The test runner failed to initialize for UI testing. (Underlying Error:
  Failed call to AXDisableAccessibilityOnTermination: kAXErrorCannotComplete)", exit 65, on all three
  of the iPhone 17 Pro Max's runs, 39–106 s after its boot status reported Finished at 07:32:37; the
  smaller iPhone's first runner, at 07:35:27, worked). The cause is not established. The settle and
  rerun rest on one build and are untested on a Mac; build 3 exercises them first. The harness waits
  for `xcrun simctl bootstatus
  <udid> -b` (bounded), then 60 s more, then runs the same tests again. An optional run is started
  again only while its gate still holds; otherwise it is listed as not run for time.

The verdict names each rerun by its reason ("simulator not found, no test ran" or "test runner
failed to initialize, no test ran"). The recorded journey gets the same one rerun, recorder
restarted.

**Provenance.** Each build's verdict names its build, its scope and the pinned commit it ran on.
The final report lists every build, scope, commit and duration.

## 0a. The targeted correction scope (after build `6ab8639c`, reworked after `6ab88011`)

`PLACES_REVIEW_SCOPE=correction` runs one build that checks the Places correction. It ran as
recovery build 2 (§0b).

The first correction build (Codemagic `6ab8adb4`, on `907d7401`) passed 14 of its 15 required
rows. C12 failed on a product issue, corrected in `Proximeet/Scenes/PlacesView.swift`. So the
correction ran again on `808950f`, with the same required rows, runs, bounds and order, as recovery
build 2 (Codemagic `6ab8c585873de42fcd4f1a8a`): C10–C15 passed on the smaller iPhone (C12 among
them); on the iPhone 17 Pro Max every run exited 65 before any test started (the test runner
failed to initialize for UI testing), so C1–C9 run again in `gate_finish` (§0b). Build `6ab8adb4`
counts toward nothing in the recovery.

The runs, in order on each device (the device's runs are serial; the two devices run in parallel):

| Device | Run (bound) | Rows |
| --- | --- | --- |
| Main (iPhone 17 Pro Max) | `correction_first` (600 s) | C3, the footers at the default text, alone and first: build `6ab88011` left it interrupted, and the bound includes the main runner's measured first start (about 300 s) |
| | `correction_main` (700 s) | C1, where a detail and the explanation start; C2, the footers at the largest text |
| | `correction_signal` (600 s) | C4, C5 (`BandSignalInteractionTests`), C9 (`PlacesReviewTests.testSevenScreensOnThisPhone`, now required), C6, C7, C8 (`SignalReviewTests`), in XCTest's class order |
| Smaller iPhone | `journey` (420 s) | C10, the recorded correction walkthrough (full holds) |
| | `correction_small` (780 s) | C12, C13, C14 (the same three correction tests as on main), C15 (`PlacesReviewTests.testBackRoutesKeepTheCategoryAndTheDraft`, now required) |
| | `correction_small_b` (240 s) | C11, back gestures and controls, alone |

- **Earlier rows it executes.** C9 is P7 and C15 is P8; C4, C5, C6, C7 and C8 are S1, S2, S7, S11
  and S14. Each is the same test method on the same device class in the same kind of run (short
  holds), at the same commit as the other two builds.
- **The diagnostic is removed.** Of C16 and C17 (`probe_main` and `probe_small`, both running
  `PlacesCorrectionTests.testScrollDiagnosticProbe`, kind `diagnostic`), build `6ab8adb4` ran C17
  (smaller iPhone); C16 was left unrun for time. They are no longer manifest rows, so no scope runs the probe. The
  test method stays in the test file, and the harness still handles kind `diagnostic` (reported,
  never part of a verdict) should one return.
- **Footer checks.** They use frames and pixels:
  - the schedule and View place never meet and stay in the column;
  - a stacked gap is clear of ink;
  - the button's face and the paper below it are drawn;
  - on 440 pt, the approved footer is checked to the point.
- **Gestures.** They are real swipes from the leading edge:
  - completed and not completed;
  - a mid-screen swipe that must change nothing;
  - each tested separately from the header Back and the bottom Back.
- **Stage start.** A stage that has just opened must show its header where it rests.
- **Recording.** The correction's recording is delivered unedited; no re-encode is made on the Mac.
- **Downloads.**
  - `Places-Correction-Review.zip`: before and after, the changed files (and the product files
    changed since `907d7401`, build `6ab8adb4`'s commit), every execution by test and device, the
    earlier coverage (the seven earlier executions run here, and for each of the other 49 the
    recovery build and row where it is due), logs, the verdict and `SHA256SUMS.txt`;
  - `Places-Correction-Screens.zip`;
  - `Places-Correction-walkthrough.zip`.
- **Verdict.** Build 2's verdict (from the harness at `808950f`) named the role only: "FAIL (scope
  correction, recovery build (correction gate))". With this harness a clean run is designed to say
(not yet produced on a Mac) "PASS (scope
  correction, recovery build (correction gate, build 2); the row-level reconciliation is separate;
  manual review still outstanding)", and `gate_finish` and `sweep_finish` say "gate finish, build 3"
  and "sweep finish, build 4".

## 0b. The recovery: build 2, then gate_finish and sweep_finish, reconciled row by row

After the Places correction, every earlier required execution runs again at `808950f`'s product.
Before build 2 the plan was three builds on one commit: `correction`, `sweep`, `regressions`. Build
2 (`correction`, Codemagic `6ab8c585873de42fcd4f1a8a`, on `808950f`) passed C10–C15 on the smaller
iPhone, but on the iPhone 17 Pro Max every run exited 65 before any test started. Only two builds
were left, so the recovery ends with two new scopes, run on one commit that changes only harness and
documentation files from `808950f`:

| Build | Scope | Required | Extras | What it runs |
| --- | --- | --- | --- | --- |
| 2 (done) | `correction` | 15 (6 passed) | – | C10–C15 passed on the smaller iPhone; C1–C9 never started |
| 3 | `gate_finish` | 9 | 12 | C1–C9 on main; extras S3–S6, S8 on main, P9–P13, S15, S16 on the smaller iPhone |
| 4 | `sweep_finish` | 29 | – | P1–P6, S9, S10, S12, S13, M1–M3 on main; M4–M13, B1, B10–B13, B15 on device B |
| pending | – | – | – | B2–B9 and the optional repeat B14: no recovery build runs them |

- **`gate_finish`'s runs.** In order on each device; the two devices run in parallel:

  | Device | Run (bundle, bound) | Rows |
  | --- | --- | --- |
  | Main (iPhone 17 Pro Max) | `correction_first` (`GateFirst`, 600 s) | C3, alone and first |
  | | `correction_main` (`GateMain`, 700 s) | C1, C2 |
  | | `correction_signal` (`GateSignal`, 600 s) | C4, C5, C9, C6, C7, C8 |
  | | `signal_main_a` (`GateSignalExtra`, 420 s) | S3, S4, S5, S6, S8 (extras) |
  | Smaller iPhone | `places_small` (`GatePlacesSmall`, 900 s) | P9–P13 (extras) |
  | | `signal_small` (`GateSignalSmall`, 420 s) | S15, S16 (extras) |

  C1–C9 keep the correction scope's row IDs, tests, runs, bounds and order. The extras keep the
  places and signal scopes' row IDs and tests; each extra run starts only while its bound plus 60 s
  is left, must pass if it runs, and is listed as not run (time budget) otherwise. C10–C15 are
  build 2's and are not rerun.
- **`sweep_finish`'s runs.**

  | Device | Run (bundle, bound) | Rows |
  | --- | --- | --- |
  | Main (iPhone 17 Pro Max) | `places_signal_main` (`FinishPlacesSignalMain`, 1020 s: its tests, about 620 s, plus a first xcodebuild start measured up to about 337 s (build 6ab88011, the main device's first run, from its xcodebuild start to its first test) and a close of about 65 s; the UI deadline still caps it) | P1 (`PlacesReviewTests.testWalkthroughRealJourney`, short holds, not recorded), P2–P6, S9, S10, S12, S13 |
  | | `birthday_wristband_main` (`FinishBirthdayWristbandMain`, 600 s) | M1, M2, M3 |
  | Device B (clone of main) | `pass_wristband_b` (`FinishPassWristbandB`, 700 s) | M4–M13 |
  | | `paste_b` (`FinishPasteB`, 480 s) | B1 |
  | | `welcome_b` (`FinishWelcomeB`, 240 s) | B10–B13 |
  | | `hardware_keys_b` (`FinishHardwareKeysB`, 240 s) | B15, last on its device (it sends hardware key events) |

  Every row keeps its earlier row ID and test method. Nothing is recorded; the recovery's
  walkthrough video is build 2's C10.
- **Why B2–B9 are pending.** Only two builds were left after build 2's runner failure, and the plan
  for them leaves out the Guest List's `regressions_b` run (B2–B9; its bound in the regressions scope
  is 1000 s). The 27 regressions last passed at `b06707ec` (build `6ab81e22`,
  `docs/reports/places-chapter-07.md`). The Guest List sits upstream of the Places changes on the
  route (Welcome → Birthday → Pass → Guest List → Wristband → Signal → Places), and its view is
  unchanged since `b06707ec`:
  `git diff --stat b06707ec 808950f -- Proximeet/Scenes/GuestListView.swift` prints nothing, and
  neither do `ProximeetUITests/GuestListReviewTests.swift`,
  `ProximeetDomain/Sources/ProximeetDomain/GuestIntroduction.swift` and `GuestListDemo.swift`. The
  shared route files did change for Places (`DemoSession.swift`, `DemoFlow.swift`, `DemoDraft.swift`,
  `DemoScene.swift`, `RootView.swift`, `DebugFixtures.swift`), so B2–B9 are not claimed at `808950f`:
  they stay pending, and the full regression reads INCOMPLETE until a build runs them. B14, the
  optional repeat of B1, is pending too and counts toward no verdict. (Welcome, Birthday and the
  Pass are further upstream than the Guest List and are run: B10–B13, M1, M3, M4–M7.)
- **Workflow.** `proximeet-places-review-35`, each build with `PLACES_EXPECTED_COMMIT` set to the new
  commit and its own `PLACES_REVIEW_SCOPE`. Retries stay off; the infrastructure rerun (§0) applies.
  Both scopes are untested on a Mac; build 3 is the first run of `gate_finish`.
- **Downloads.** `Places-Gate-Review.zip` shows this build's correction captures (C1, C2, C3 at
  440 pt, C9's seven screens, the Signal captures of C4–C8) beside the BEFORE images, names every
  capture of C10–C15 (the 390-pt screens, the gestures, the walkthrough, C15's Back routes) as build
  2's, shows the extras' captures, and lists C1–C15 and every earlier row with where each ran or is
  due. `Places-Finish-Review.zip` is laid out like the sweep's page, with its P, S, M and B rows'
  captures, and names each capture another recovery build makes. Both show the product and test files
  changed since `808950f` (none expected).
- **The coverage file.** `docs/verification/places-recovery-coverage.tsv` lists every target, 72 in
  all: the correction's C1–C15, the 56 earlier required executions (13 places, 16 signal, 27
  regressions) and the optional B14, each with its test, device class, and the build, scope, run and
  row expected to execute it (C10–C15 build 2; C1–C9, S3–S6, S8, P9–P13, S15, S16 build 3; P1–P6,
  S9, S10, S12, S13, M1–M13, B1, B10–B13, B15 build 4; B2–B9 and B14 pending). P7, P8, S1, S2, S7,
  S11 and S14 are executed by C9, C15, C4, C5, C6, C7 and C8 (the same test on the same device class,
  in the same kind of run).
- **Row-level reconciliation.** After build 4:

  ```
  python3 scripts/places_recovery_reconcile.py \
      <build 2 results> Places-Gate-Review.zip Places-Finish-Review.zip
  ```

  It takes any number of builds, each a review zip, its unpacked folder, or a build's
  `build/artifacts`; the same build given twice counts once. It first checks the coverage file
  against the manifest. Then, for every target, it looks for a PASSED execution (kind required or
  extra; for B14, kind repeat) of the same test on the same device class in the same run type, in a
  build whose `git_head` is product-equivalent to `808950f8102d1c0e0f6c3422fc0aed3a0df555fe`:
  `git diff --name-only <git_head> 808950f -- Proximeet ProximeetDomain ProximeetUITests
  Proximeet.xcodeproj assets` must print nothing. It prints every head and that command's result.
  Build 1 (`907d7401`) never counts.
  - Device classes: main and device B are one class (the iPhone 17 Pro Max model and runtime; B is
    its clone); small is the iPhone 17e. A build whose recorded devices are other models counts for
    no row of that class, a build whose runtime is not recorded counts for no row of either class,
    and the counted builds must share one runtime.
  - Identity exceptions, stated and printed where they apply: P1 runs with short holds, unrecorded
    (the places scope's P1 was the recorded journey, full holds; its assertions are the same); the M
    rows run on device B instead of main (the same model and runtime).
  - A non-passing execution (failed, skipped, interrupted, executed twice) of a target's test on its
    class in a product-equivalent build is a failure, whatever its kind: retries are off, and an extra
    that runs must pass.
  - Two verdicts, printed separately: **TARGETED CORRECTION** is PASS when C1–C15 all passed and none
    failed, otherwise FAIL with the failed and missing rows. **FULL REGRESSION** is PASS when all 56
    earlier required executions are covered, FAIL when any failed, and otherwise INCOMPLETE with
    every uncovered row and why (B2–B9: pending, not scheduled). Build-level verdicts are
    informational: build 2 failed on infrastructure, but its passed rows count.
  - Exit 0 when both verdicts pass; 3 when the targeted correction passes and the full regression is
    INCOMPLETE; 1 on any FAIL (or a coverage file that disagrees with the manifest); 2 on a usage
    error. `--tsv <file>` writes the joined table.
  - `--assume-product-equivalent <sha>` is a test mode for stubbed results whose `git_head` is not a
    real commit (such as `0000…`): that head is treated as product-equivalent without git, and both
    verdicts say "TEST MODE … not a real result". It is never for real builds.
- **The earlier plan.** The `sweep` and `regressions` scopes stay in the manifest unchanged and can
  still run as scopes of their own, but they are no longer recovery builds; their measured
  durations (builds `6ab85be6`, `6ab8639c` and `6ab7e942`) were 188–213 s for a passing P1, 233–240 s
  for P2–P6 together and about 375 s for nine S rows on main, and about 511 s for P9–P13 and 82 s for
  S15 and S16 on the smaller iPhone.

## 0c. Recovery build 5: `regression_finish`, the rows build 4 left unverified

Build 4 (`sweep_finish`, Codemagic `6ab8f638`) ran out of time: 21 passed and none failed, but P3,
P6 and M2 were interrupted and P1, S9, S10, S12 and S13 never started. B2–B9 were never scheduled. A
further authorisation allows two more builds, 70 rounded minutes and USD 7. `regression_finish` runs
exactly those 16 rows: the same row IDs, test methods and device class. P1 keeps its short holds,
unrecorded.

**Why build 4 was slow.** These points are measured from its logs, not guessed:
- The slowdown was inside build 4's main simulator. Its XCTest queries and synthesised events ran
  about 2.7–7× slower per paired step from its first test to the deadline, including 7 minutes
  after device B had finished.
- Device B, its clone on the same host, ran at normal per-step pace. Its first runner start took
  105 s, against 40 s in build 6ab81e22.
- Its drags moved the page normally, but each took 2–5× longer: 4.2–11.2 s, against 1.8–2.2 s on
  build 3's main lane.
- Result-bundle closes and export were normal.
- Its compile was 52 s slower (200.6 s against 148.8 s), which took 53 s off the UI budget. Compile
  time does not predict test pace: build 1 compiled in 223 s and tested at normal pace.

The mechanism is unknown. In all 7 builds examined (recovery builds 1–4, 6ab88011, 6ab8639c and 6ab81e22; a pattern fitted to those same builds), the main device's first test runner
started late (199–301 s) or failed to initialize whenever a device's first boot was still in
progress or had just finished. It started in 32–46 s when both devices were already booted. That
start-up delay did not predict the lasting slowdown (1 of 3 builds).

**What changed, and only in this scope:**
- **Readiness barrier.** No lane starts until both devices report their boot finished. The times
  are recorded in `metadata/places-boot-ready.txt`.
- **One shared queue.** The runs are shared by the two iPhone 17 Pro Max simulators, the selected
  one and device B, its clone, which are one device class. The manifest's device column is a
  preference. Each lane takes its own next run. When a lane has none left, it takes the other
  lane's last unstarted run, so a slow simulator cannot strand the rest.
  - `runs.txt` names the lane each run ran on (`lane=main` or `lane=b`), and the results judge each
    execution against that lane's device.
  - Claims and their times are in `metadata/places-queue-claims.txt`.
  - A run nobody started before the deadline is listed as never started. It counts as unverified,
    never as passed.
- **XCTest's execution time allowance** is 600 s (maximum 660 s). It was 300/360 s. In build 4, P3
  was still making progress when the 300-s allowance ended it, and B2's healthy time of 190 s has
  only 1.6× headroom under 300 s. The allowance is a hang guard, not a check. The run bounds and
  the deadline still apply.
- **Host telemetry.** Every 30 s, `logs/places-host-load.log` records `top`, `vm_stat`, memory
  pressure, swap, and each simulator's processes (count, CPU, memory, the busiest).
- **Result bundles.** Every run's result bundle is kept in `Places-Remaining-Results.zip`,
  including any that a time bound stopped (SIGINT lets xcodebuild close it). The exception is a
  first attempt that started no test: its bundle is replaced by its infrastructure rerun's.

| Preferred lane | Run (bundle, bound) | Rows |
| --- | --- | --- |
| Main | `rf_p3` (`RemainingP3`, 960 s) | P3 |
| | `rf_places` (`RemainingPlaces`, 1080 s) | P6, P1 |
| | `rf_wristband` (`RemainingWristband`, 960 s) | M2 |
| | `rf_signal` (`RemainingSignal`, 960 s) | S9, S10, S12, S13 |
| Device B | `rf_guest_a` (`RemainingGuestA`, 1080 s) | B2, B3 |
| | `rf_guest_b` (`RemainingGuestB`, 960 s) | B4, B5, B6, B7 |
| | `rf_guest_c` (`RemainingGuestC`, 960 s) | B8, B9 |

- **Time.** The workflow is `proximeet-places-review-40`: 40 minutes, with a UI deadline 2040 s
  after the source gate. At the worst that is 72 + 2040 + 75 (grace) + 100 (export) + 45
  (publishing) + 60 (the bundles' zip) = 2392 s. The zip's bound is whatever is left of that plan,
  between 15 and 240 s.
- **Bounds and cut-offs.** Every run's bound is at least 960 s. That is room for a slow runner
  start (build 4: 302 s), one test's full 600-s allowance and a start on its close; the close itself
  gets the separate 75-s grace. A run whose tests together take longer at a slow pace is stopped by
  its bound and recorded as interrupted, never passed. The UI deadline caps every bound. A lane claims no new run with less than 180 s left. A lane whose
  run started no test at all, even after its infrastructure rerun, stops and leaves the rest to the
  other lane. A broken device therefore cannot take and fail the healthy lane's runs.
- **Boot barrier record.** Each device's line says `boot_finished` only when `simctl bootstatus`
  exited 0. Otherwise it says `boot_NOT_CONFIRMED`, with its exit code.
- **The shorter workflow.** `proximeet-places-review-30` (30 minutes, deadline 1440 s) is for a
  later build when less of the allowance is left. As committed, the regression_finish scope queues
  all 16 rows and names itself build 5. So a second build needs its own scope, with only the
  unverified rows and its own build label, before it is started.
- **Omitted.** Neither workflow makes a runnable preview copy or a compact video: the app build 3
  published is the preview, and this scope records nothing.
- **Reconciliation.** `scripts/places_recovery_reconcile.py` now treats an interrupted execution
  (started, stopped before an outcome) as unverified, not as a failure.
  - A later pass in a product-equivalent build covers the row, and the interrupted attempt is listed
    under "Repeated executions (disclosed)".
  - A failed, skipped or twice-executed execution still fails its row.
  - `sweep_finish`'s rows for the eight moved targets stay as build 4's record.

## 1. The source gate

`PLACES_REVIEW_SCOPE=<scope> bash scripts/places_review.sh checkpoint` fails the build unless the
checkout is exactly the reviewed revision:

- **Approved assets.** `places-approved-files.sha256` lists:
  - the Welcome poses, the five Manrope faces and their licence, the Birthday housing, the Pass
    artwork, the Guest List card art, the four band artworks and the blank Signal tag;
  - the three Places scenes (`PlaceCommonGround`, `PlaceAfterglow` and `PlaceFieldwork`). Each is
    the original 1254 × 1254 RGBA file, unchanged. The app crops them at run time to
    [46, 83, 1211, 1218], [5, 105, 1249, 1186] and [8, 39, 1247, 1163], and fits them without
    stretching;
  - everything under `docs/design/{welcome,birthday,pass,guest-list,wristband,signal,places}-approved/`.

  Every file must match. The three scenes, the faces and the licence must also match the Places
  handoff's own `SHA256SUMS.txt`, which covers the approved package whose ZIP had SHA-256
  `53761ca0581541e6323d5950576caa22c75c09dbc468b462e33a06c96cefd456`. Every handoff document
  copied into `docs/design/places-approved/` must match that record too. The faces and the licence
  must agree across all seven handoffs.
- **Everything else.** `places-review-files.sha256` lists every other file except itself.
  `scripts/places_source_manifests.py` writes both manifests.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules. The
  files in `places-review-deletions.txt` (the earlier chapters' deletions) must be absent.
- **The Signal guard, unchanged.** The approved route's sources (Signal, Wristband, Guest List,
  Pass, the repeat-tap guard, `DemoSession.swift`) must contain none of these:
  - verification, visibility, membership, presence or check-in flags;
  - capture, location, Bluetooth, NFC or notification APIs;
  - network, persistence, logging or timer APIs.
- **The Places guard.** `PlacesView.swift` and `Places.swift` must contain none of these:
  - clock, calendar, time zone, locale, formatter or timer APIs;
  - location, map, camera, AVFoundation, VisionKit, scanner, image-detection, Bluetooth, NFC or
    biometric APIs;
  - permission requests;
  - notification, network, persistence or logging APIs;
  - checked-in, present, visible, verified, member, reservation or booking identifiers.

  Since the correction, the guard also covers `Proximeet/Components/PlacesEdgeBack.swift`.

  The visible sentences say what a later, real check-in would ask and what is not done here.
- **One intent mapping.** Signal, the Wristband and Places never use the legacy intent tint.
- **Pinned.** `PLACES_EXPECTED_COMMIT` (full SHA) must equal HEAD. `PLACES_REVIEW_SCOPE` must name a
  manifest scope. Both are required on Codemagic.

## 2. Steps

1. `codemagic_verify.sh metadata`: records the source, host and tools; fails unless Xcode 26.6.
2. `places_review.sh checkpoint`: the source gate. It also starts the time budget.
3. `codemagic_verify.sh validate`: validates the checked-in project; nothing is regenerated.
4. `codemagic_verify.sh select-simulator`: selects the iPhone 17 Pro Max (no downloads).
5. `places_review.sh destinations`: starts the first boots behind the compilation.
6. `codemagic_verify.sh build` and `package`: the unsigned Debug app and its zip.
   In `proximeet-places-review-35` only, `places_review.sh preview-app` then copies the app, before
   the UI review rebuilds the build products, to `build/preview/Proximeet.app` (with `ditto`) and
   writes `build/preview/PREVIEW.txt`: the source commit (`git rev-parse HEAD`), the app zip's name
   and SHA-256, and the line "Prototype — Places verification pending: a runnable app is not
   evidence that its checks passed." It never fails the build; a problem is a note in its log, the
   summary and `PREVIEW.txt`.
7. `codemagic_verify.sh domain-tests`: `swift test` on the Mac. It covers the Places rules (the
   12-combination matrix, precedence, state preservation, clock independence) and every earlier
   chapter's rules.
8. `places_review.sh ui-review` runs the manifest's runs in four steps:
   - it compiles the test harness (both devices have been booting since destinations);
   - it copies the build products for the other device, so the two xcodebuild processes never
     share a DerivedData folder;
   - it runs main's runs and the other device's in parallel;
   - `bounded_test` bounds every xcodebuild. At its bound the run gets SIGINT, then SIGKILL 75 s
     later, so its result bundle survives;
   - a run whose first attempt started no test (simulator not found, or the test runner failed to
     initialize for UI testing) is run once more after the device is ready (§0).

   The UI deadline is 1380 s after the gate, or the run input.
9. `places_review.sh compact-video`: a half-size re-encode of the journey, trimmed to the app by
   the test's own start marker and duration (places only). The original is kept. The correction's
   recording is delivered unedited; the sweep, `gate_finish`, `sweep_finish` and the other scopes
   record nothing (NOT APPLICABLE).
10. `verdict`, `package-review` and `enforce`: the build fails unless the automated verdict is
    PASS.

## 3. Downloads (build page)

| File | Scope | What it holds |
| --- | --- | --- |
| `Places-Review.zip` | places | An offline `index.html`: the approved board beside the real journey's captures, the scene deliveries, the seven screens on both widths, the twelve eligibility captures, every route and interruption capture, the largest text on both widths, the recorded deviations, the scope's manifest rows, every test's outcome, the tests' notes (measured frames and pixels), the verdict, the source checkpoint, the logs and the unsigned app. It also holds both videos. Every link is checked. |
| `Places-Screens.zip` | places | Every screen. Each file name says `XCTest-journey` (the real route) or `XCTest-FIXTURE-direct-launch`. |
| `Places-walkthrough-compact.zip` / `.mp4` | places | The journey, re-encoded at half size and trimmed to the app. If the re-encode failed, the file is labelled a fallback copy. |
| `Places-walkthrough-original.zip` | places | The unedited simulator recording. |
| `Places-Sweep-Review.zip`, `Places-Sweep-Screens.zip` | sweep | As for places, with the S rows' captures (chosen by the test that attached them) beside the Places ones (`Signal-rows-*` in the Screens zip) and every P and S execution listed by row, device, outcome and the earlier row it counts as. It records nothing. P7's 440-pt screens and P8's Back-route captures are made by the correction build (C9, C15) and are named as such, not as missing. |
| `Places-Signal-Review.zip`, `Places-Regressions-Review.zip` | signal, regressions | That scope's captures, results, logs and verdict. |
| `Places-Correction-Review.zip`, `Places-Correction-Screens.zip`, `Places-Correction-walkthrough.zip` | correction | See §0a. |
| `Places-Gate-Review.zip`, `Places-Gate-Screens.zip` | gate_finish | Like the correction's page, with this build's correction captures (C1–C3 at 440 pt, C9, C4–C8) beside the BEFORE images; every capture of C10–C15 named as recovery build 2's; the extras' captures; C1–C15 and every earlier row with where it ran or is due; the product files changed since `808950f`. See §0b. |
| `Places-Finish-Review.zip`, `Places-Finish-Screens.zip` | sweep_finish | Like the sweep's, with its P, S, M and B rows' captures (the M and B rows' by test class) and every execution by row and the earlier row it counts as; each capture another recovery build makes is named as such (`*.IN-GATE-BUILD.txt`, `*.IN-CORRECTION-BUILD.txt` in the Screens zip). See §0b. |
| `Places-Remaining-Review.zip` | regression_finish | Its 16 rows' captures, results (each on the lane it ran on), the queue's claims, the boot barrier's times, the host-load log, logs and verdict. See §0c. |
| `Places-Remaining-Results.zip` | regression_finish | Every run's `.xcresult`, including any that a time bound stopped. |
| `app/Proximeet-Debug-iphonesimulator-<sha>.zip` | every scope | The unsigned simulator app. It cannot be installed on an iPhone. |
| `build/preview/Proximeet.app`, `build/preview/PREVIEW.txt` | every scope, `proximeet-places-review-35` only | The same app, runnable. Codemagic shows Quick Launch beside a `.app` artifact only for teams with App Preview; on a personal account it is a plain download. A runnable app is not evidence that its checks passed. |

Each archive has a `.sha256` beside it. An unknown scope (the retired `sweep_places` and
`sweep_signal` included) makes no archive, so no archive can carry another scope's name.

## 4. Not established by automation

- Visual approval against `docs/design/places-approved/reference` (the founder decides).
- VoiceOver, including the escape gesture: each Places stage is one container (`places.screen`)
  whose escape action goes back one stage. VoiceOver does not run in the Simulator.
- The system Reduce Motion setting (only the app's preview flag is tested).
- Composing keyboards.
- Landscape and iPad.
- Motion smoothness on a device.
