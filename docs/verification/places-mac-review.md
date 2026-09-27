# Places — manual macOS verification run

The workflow `proximeet-places-review` in the root `codemagic.yaml` builds the approved Places
(chapter 07) as an unsigned Debug app for the iOS Simulator. It runs the Places XCTest review with
real taps and typing, records the real journey from Welcome into Places, and runs every earlier
chapter's checks on the same code. Then it packages the review.

It starts only by hand: there is no `triggering` section. It has no code signing, Apple
credentials, provisioning, archive/IPA, TestFlight, publishing, notifications or environment
groups. Its limit is 28 minutes. Two twins run the same steps: `proximeet-places-review-short`
(24 minutes) and `proximeet-places-review-35` (35 minutes, for the four-build recovery in §0b).
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
| `correction` | See §0a | The smaller iPhone; see §0a | 15 required (+2 optional diagnostics) |
| `sweep_places` | The recorded journey (P1, alone, full holds), then P2–P6: the Birthday gate on the way back, the largest text, rapid taps and interruptions, the Reduce Motion preview and relaunch | The smaller iPhone: P9–P13, the band change, all twelve intent-venue combinations, the largest text, missing choices and the guarded explanation, and the seven screens | 11 |
| `sweep_signal` | S3–S6, S8–S10, S12 and S13 in one run: both Guest List keyboard tests, the age-gate journey, twelve states, first choices, largest text, missing intent, the Reduce Motion preview and relaunch | The smaller iPhone: S15 and S16, the keyboard Done/Back check and Signal's largest text | 11 |

**Devices and time (after build `6ab84ede`).**
- Measurements from builds `6ab84ede` and `6ab85be6` set the device plan:
  - A simulator restarted after its first boot was not ready for 3.5 to 5.7 minutes.
  - A device first booted while the other ran tests needed about 15 minutes to reach its first test.
  - A second first boot during the compilation slowed it by about 2 minutes.
- So both devices boot during the compilation and neither is ever restarted. For regressions, device B is cloned from main before either boots.
- The UI deadline is 1380 s after the gate. The run input `PLACES_UI_DEADLINE_SECONDS` (600 to 1680) changes it; the source gate rejects any other value. A value above 1380 belongs only to the 35-minute workflow.
- `proximeet-places-review-short` runs the same steps with a 24-minute limit. Its own `PLACES_UI_DEADLINE_SECONDS` is 1110 (at the worst 72 + 1110 + 75 + 100 + about 40 = 1397 s). It is for a final build that must fit what is left of the chapter's 90 free minutes.
- `proximeet-places-review-35` runs the same steps with a 35-minute limit and one more (the preview copy, §2). Its own `PLACES_UI_DEADLINE_SECONDS` is 1680 (at the worst 72 + 1680 + 75 + 100 + about 45 = 1972 s of its 2100).
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

**Provenance.** Each build's verdict names its build, its scope and the pinned commit it ran on.
The final report lists every build, scope, commit and duration.

## 0a. The targeted correction scope (after build `6ab8639c`, reworked after `6ab88011`)

`PLACES_REVIEW_SCOPE=correction` runs one build that checks the Places correction. It is build 1
of the recovery in §0b. The runs, in order on each device (the device's runs are serial; the two
devices run in parallel):

| Device | Run (bound) | Rows |
| --- | --- | --- |
| Main (iPhone 17 Pro Max) | `correction_first` (600 s) | C3, the footers at the default text, alone and first: build `6ab88011` left it interrupted, and the bound includes the main runner's measured first start (about 300 s) |
| | `correction_main` (700 s) | C1, where a detail and the explanation start; C2, the footers at the largest text |
| | `correction_signal` (600 s) | C4, C5 (`BandSignalInteractionTests`), C9 (`PlacesReviewTests.testSevenScreensOnThisPhone`, now required), C6, C7, C8 (`SignalReviewTests`), in XCTest's class order |
| | `probe_main` (300 s, diagnostic) | C16, `PlacesCorrectionTests.testScrollDiagnosticProbe`: the optional scroll probe |
| Smaller iPhone | `journey` (420 s) | C10, the recorded correction walkthrough (full holds) |
| | `correction_small` (780 s) | C12, C13, C14 (the same three correction tests as on main), C15 (`PlacesReviewTests.testBackRoutesKeepTheCategoryAndTheDraft`, now required) |
| | `correction_small_b` (240 s) | C11, back gestures and controls, alone |
| | `probe_small` (300 s, diagnostic) | C17, the same probe |

- **Earlier rows it executes.** C9 is P7 and C15 is P8; C4, C5, C6, C7 and C8 are S1, S2, S7, S11
  and S14. Each is the same test method on the same device class in the same kind of run (short
  holds), at the same commit as the other three builds.
- **The diagnostic.** C16 and C17 are kind `diagnostic`: each starts, last on its device, only while
  its bound plus 60 s is left before the deadline, and is listed as not run otherwise. Its outcome and
  its run's exit are reported and never count toward the verdict, so the diagnosis cannot fail the
  correction gate, and it cannot stand for any required row.
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
  - `Places-Correction-Review.zip`: before and after, the changed files, every execution by test
    and device (the diagnostic labelled "diagnostic (optional)"), the earlier coverage (the seven
    earlier executions run here, and for each of the other 49 the build and row where it is due),
    logs, the verdict and `SHA256SUMS.txt`;
  - `Places-Correction-Screens.zip`;
  - `Places-Correction-walkthrough.zip`.
- **Verdict.** A clean run says "PASS (scope correction, build 1 of 4; the four-build
  reconciliation is separate; manual review still outstanding)".

## 0b. The recovery: four builds on one commit

After the Places correction, every earlier required execution runs again at one frozen commit, in
four builds started by hand, one after another, each only if the one before passed:

| Build | Scope | Required | What it covers |
| --- | --- | --- | --- |
| 1 | `correction` | 15 | the correction's own checks, and P7, P8, S1, S2, S7, S11, S14 (as C9, C15, C4–C8) |
| 2 | `sweep_places` | 11 | P1–P6 and P9–P13, under the places scope's IDs |
| 3 | `sweep_signal` | 11 | S3–S6, S8–S10, S12, S13, S15 and S16, under the signal scope's IDs |
| 4 | `regressions` | 27 | M1–M13, B1–B13 and B15 (+ the optional repeat B14), its rows unchanged |

- **Workflow.** `proximeet-places-review-35`, each build with the same `PLACES_EXPECTED_COMMIT` and
  its own `PLACES_REVIEW_SCOPE`. Retries stay off.
- **The identity rule.** An execution counts as an earlier one only when it is the same test
  method, on the same device class, in the same run type (a recorded `journey` run keeps full
  holds; every other run uses short holds), at the same commit as the other three builds. The
  places and signal rows of the manifest stay as the record; the sweeps keep their row IDs, so the
  builds reconcile by row ID and device.
- **The coverage file.** `docs/verification/places-recovery-coverage.tsv` lists all 67 executions
  of the four builds (64 required, B14, C16 and C17 optional) and the earlier row each one counts
  as. Together they cover the 56 earlier required executions: 13 places, 16 signal, 27 regressions.
- **Reconciliation.** Each build's verdict covers that build only. After build 4:

  ```
  python3 scripts/places_recovery_reconcile.py --expect-sha <frozen SHA> \
      Places-Correction-Review.zip Places-Sweep-Places-Review.zip \
      Places-Sweep-Signal-Review.zip Places-Regressions-Review.zip
  ```

  It takes the four downloaded review zips, their unpacked folders, or folders holding a build's
  results. It checks the coverage file against the manifest, prints one line per execution, and
  exits 0 only when one build of each scope was given, all four ran the same `git_head` (and the
  manifest given), every required row executed once on its device and passed, no optional row that
  ran failed, nothing ran outside the rows, every supplied verdict is PASS, and all 56 earlier
  required executions are covered. Otherwise it lists exactly which rows are missing, failed,
  interrupted or not run, and which SHAs differ. `--tsv <file>` also writes the joined table.

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
     later, so its result bundle survives.

   The UI deadline is 1380 s after the gate, or the run input.
9. `places_review.sh compact-video`: a half-size re-encode of the journey, trimmed to the app by
   the test's own start marker and duration (places and sweep_places). The original is kept. The
   correction's recording is delivered unedited; the other scopes record nothing.
10. `verdict`, `package-review` and `enforce`: the build fails unless the automated verdict is
    PASS.

## 3. Downloads (build page)

| File | Scope | What it holds |
| --- | --- | --- |
| `Places-Review.zip` | places | An offline `index.html`: the approved board beside the real journey's captures, the scene deliveries, the seven screens on both widths, the twelve eligibility captures, every route and interruption capture, the largest text on both widths, the recorded deviations, the scope's manifest rows, every test's outcome, the tests' notes (measured frames and pixels), the verdict, the source checkpoint, the logs and the unsigned app. It also holds both videos. Every link is checked. |
| `Places-Screens.zip` | places | Every screen. Each file name says `XCTest-journey` (the real route) or `XCTest-FIXTURE-direct-launch`. |
| `Places-walkthrough-compact.zip` / `.mp4` | places | The journey, re-encoded at half size and trimmed to the app. If the re-encode failed, the file is labelled a fallback copy. |
| `Places-walkthrough-original.zip` | places | The unedited simulator recording. |
| `Places-Sweep-Places-Review.zip`, `Places-Sweep-Places-Screens.zip`, `Places-Sweep-Places-walkthrough-original.zip` | sweep_places | As for places, but the recording is delivered unedited: no compact re-encode is made on the Mac. P7's 440-pt screens and P8's Back-route captures are made by the correction build (C9, C15) and are named as such, not as missing. |
| `Places-Signal-Review.zip`, `Places-Sweep-Signal-Review.zip`, `Places-Regressions-Review.zip` | signal, sweep_signal, regressions | That scope's captures, results, logs and verdict. |
| `Places-Correction-Review.zip`, `Places-Correction-Screens.zip`, `Places-Correction-walkthrough.zip` | correction | See §0a. |
| `app/Proximeet-Debug-iphonesimulator-<sha>.zip` | every scope | The unsigned simulator app. It cannot be installed on an iPhone. |
| `build/preview/Proximeet.app`, `build/preview/PREVIEW.txt` | every scope, `proximeet-places-review-35` only | The same app, runnable. Codemagic shows Quick Launch beside a `.app` artifact only for teams with App Preview; on a personal account it is a plain download. A runnable app is not evidence that its checks passed. |

Each archive has a `.sha256` beside it. An unknown scope makes no archive, so no archive can carry
another scope's name.

## 4. Not established by automation

- Visual approval against `docs/design/places-approved/reference` (the founder decides).
- VoiceOver, including the escape gesture: each Places stage is one container (`places.screen`)
  whose escape action goes back one stage. VoiceOver does not run in the Simulator.
- The system Reduce Motion setting (only the app's preview flag is tested).
- Composing keyboards.
- Landscape and iPad.
- Motion smoothness on a device.
