# Places — manual macOS verification run

The workflow `proximeet-places-review` in the root `codemagic.yaml` builds the approved Places
(chapter 07) as an unsigned Debug app for the iOS Simulator. It runs the Places XCTest review with
real taps and typing, records the real journey from Welcome into Places, and runs every earlier
chapter's checks on the same code. Then it packages the review.

It starts only by hand: there is no `triggering` section. It has no code signing, Apple
credentials, provisioning, archive/IPA, TestFlight, publishing, notifications or environment
groups. Its limit is 28 minutes. Results are recorded in each build's own artifacts and in the
delivery message.

## 0. Three scopes, one manifest

Not everything fits in one 28-minute build. The run input `PLACES_REVIEW_SCOPE` picks a scope, and
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

**Devices and time (after build `6ab84ede`).**
- Two measurements from that build set the device plan:
  - A simulator restarted after its first boot was not ready for 3.5 to 5.7 minutes.
  - A second first boot during the compilation slowed it by about 2 minutes.
- So the main simulator boots alone during the compilation and is never restarted. For regressions, device B is cloned from it before either boots. The other device boots when `ui-review` starts.
- The UI deadline is 1380 s after the gate. The run input `PLACES_UI_DEADLINE_SECONDS` (600 to 1380) lowers it.
- `proximeet-places-review-short` runs the same steps with a 24-minute limit. Its own `PLACES_UI_DEADLINE_SECONDS` is 1110 (at the worst 72 + 1110 + 75 + 100 + about 40 = 1397 s). It is for a final build that must fit what is left of the chapter's 90 free minutes.

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
7. `codemagic_verify.sh domain-tests`: `swift test` on the Mac. It covers the Places rules (the
   12-combination matrix, precedence, state preservation, clock independence) and every earlier
   chapter's rules.
8. `places_review.sh ui-review` runs the manifest's runs in four steps:
   - it boots the other device and compiles the test harness;
   - it copies the build products for the other device, so the two xcodebuild processes never
     share a DerivedData folder;
   - it runs main's runs and the other device's in parallel;
   - `bounded_test` bounds every xcodebuild. At its bound the run gets SIGINT, then SIGKILL 75 s
     later, so its result bundle survives.

   The UI deadline is 1380 s after the gate, or the run input.
9. `places_review.sh compact-video`: a half-size re-encode of the journey, trimmed to the app by
   the test's own start marker and duration. The original is kept.
10. `verdict`, `package-review` and `enforce`: the build fails unless the automated verdict is
    PASS.

## 3. Downloads (build page)

| File | Scope | What it holds |
| --- | --- | --- |
| `Places-Review.zip` | places | An offline `index.html`: the approved board beside the real journey's captures, the scene deliveries, the seven screens on both widths, the twelve eligibility captures, every route and interruption capture, the largest text on both widths, the recorded deviations, the scope's manifest rows, every test's outcome, the tests' notes (measured frames and pixels), the verdict, the source checkpoint, the logs and the unsigned app. It also holds both videos. Every link is checked. |
| `Places-Screens.zip` | places | Every screen. Each file name says `XCTest-journey` (the real route) or `XCTest-FIXTURE-direct-launch`. |
| `Places-walkthrough-compact.zip` / `.mp4` | places | The journey, re-encoded at half size and trimmed to the app. If the re-encode failed, the file is labelled a fallback copy. |
| `Places-walkthrough-original.zip` | places | The unedited simulator recording. |
| `Places-Signal-Review.zip`, `Places-Regressions-Review.zip` | signal, regressions | That scope's captures, results, logs and verdict. |
| `app/Proximeet-Debug-iphonesimulator-<sha>.zip` | every scope | The unsigned simulator app. It cannot be installed on an iPhone. |

Each archive has a `.sha256` beside it.

## 4. Not established by automation

- Visual approval against `docs/design/places-approved/reference` (the founder decides).
- VoiceOver.
- The system Reduce Motion setting (only the app's preview flag is tested).
- Composing keyboards.
- Landscape and iPad.
- Motion smoothness on a device.
