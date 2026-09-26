# Signal — manual macOS verification run

The workflow `proximeet-signal-review` in the root `codemagic.yaml` builds the approved Signal
(chapter 06) as an unsigned Debug app for the iOS Simulator. It runs the Signal XCTest review
with real taps and typing, records the real journey, runs the assignment's integration checks and
the earlier chapters' regressions, and packages the review.

It starts only by hand: there is no `triggering` section. It has no code signing, Apple
credentials, provisioning, archive/IPA, TestFlight, publishing, notifications or environment
groups. Its limit is 28 minutes. Results are recorded in each build's own artifacts and in the
delivery message.

## 0. Two scopes, one commit

All of the tests do not fit in one 28-minute build: Wristband build 2 needed 16.8 minutes for
27 tests. So the run input `SIGNAL_REVIEW_SCOPE` picks one half, and both halves run as separate
builds on the same pinned commit:

| Scope | Selected iPhone 17 Pro Max | Device B (a clone of it) | Smaller iPhone |
| --- | --- | --- | --- |
| `signal` | the recorded journey, then the twelve states, first choices, rapid changes and interruptions, the endpoint | the age-gate journey, relaunch, Reduce Motion preview, largest text, missing intent, the two `BandSignalInteractionTests`, and both Guest List keyboard tests | the keyboard Done/Back check, Signal's largest-text test, and three direct-launch captures |
| `regressions` | the Wristband (7), Pass (4), Birthday (2) and Welcome (all 4) tests | the Guest List's on-screen-keyboard tests (7), then its hardware-key tests (3) | not used |

Between them the two builds cover all 41 UI test methods, in 43 executions: the keyboard check
and Signal's largest-text test run on two sizes. Each verdict names its build and scope. The final report lists which build
supplied each result, and counts both builds and their minutes.

## 1. The source gate

`SIGNAL_REVIEW_SCOPE=<scope> bash scripts/signal_review.sh checkpoint` fails the build unless the
checkout is exactly the reviewed revision:

- **Approved assets.** `signal-approved-files.sha256` lists:
  - the Welcome poses, the five Manrope faces and their licence, the Birthday housing, the Pass
    artwork and the Guest List card art;
  - the four band artworks;
  - the blank tag (`SignalTag.imageset/signal-tag.png`, the original 1254 × 1254 RGBA file,
    unchanged);
  - everything under `docs/design/{welcome,birthday,pass,guest-list,wristband,signal}-approved/`.

  Every file must match. The tag, the four bands, the faces and the licence must also match the
  Signal handoff's own `SHA256SUMS.txt`. The bands must also match the Wristband handoff's records,
  and the faces and the licence must agree across all six handoffs.
- **Everything else.** `signal-review-files.sha256` lists every other file except itself.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules. The
  files in `signal-review-deletions.txt` must be absent. That list holds the earlier chapters'
  deletions and the legacy `SignalSelectionView.swift`.
- **The Signal guard.** `SignalView.swift`, `ApproachSignal.swift`, `DemoSession.swift`, and the
  Wristband, Guest List and Pass sources guarded before them must contain none of these:
  - verification, visibility, discoverability, membership, entitlement, presence or check-in
    flags;
  - camera, biometric, photo, document-capture, location, Bluetooth, NFC, Watch or notification
    APIs;
  - network, persistence or logging APIs;
  - timers or repeating animation.
- **One intent colour mapping.** `SignalView.swift` and `WristbandView.swift` must not use the
  legacy `.tint` or the `Palette` intent colours (whose Social is cyan).
- **Pin and scope.** The run inputs are `SIGNAL_EXPECTED_COMMIT=<full 40-hex SHA>`, which must equal
  HEAD, and `SIGNAL_REVIEW_SCOPE=signal|regressions`. Both are given in the API request that starts
  the build, never stored in the tree. On Codemagic, either one missing fails the gate. The stage
  also records the start of the time budget.

## 2. Steps

- `codemagic_verify.sh metadata`, then `signal_review.sh checkpoint`, then `codemagic_verify.sh
  validate` and `select-simulator`. A failure in any of these stops the build.
- `signal_review.sh destinations` reports the iPhone 17 Pro Max target and starts the first boots
  behind the compilation: the selected simulator, and in the signal scope a smaller iPhone (the
  first installed of iPhone 17e, 16e, SE, 17, 16, 17 Pro, 16 Pro).
- `codemagic_verify.sh build`, `package` and `domain-tests`. The domain tests include
  `SignalRouteTests` and `AgeGateReturnTests`.
- `signal_review.sh ui-review`, `compact-video`, `verdict`, `package-review` and `enforce`.
  `enforce` fails the build unless the verdict is PASS.

`ui-review` keeps its own deadline, 24 minutes after the gate began. Every `xcodebuild` and every
long wait is bounded by that deadline, leaving about four minutes for the exports, the verdict,
the downloads and publishing.

Retries work like this:
- XCTest's per-test time allowance is on: 300 s, at most 360 s.
- A failed test other than the recorded journey runs once more
  (`-retry-tests-on-failure -test-iterations 2`).
- Every attempt is parsed, attributed to its own result bundle, and listed as "retried". Only a
  test's final outcome counts.
- xcodebuild's exit 65 is accepted only for a run whose bundle shows a test that failed and then
  passed. The recorded journey must exit 0.
- A skip, or a test that did not run, fails the stage.

Device B is the selected simulator cloned after its first boot, so it starts warm. It gets an
APFS clone of the build products and is deleted when the review ends. Without device B, its lane
runs after the selected simulator's.

### The Signal tests (`SignalReviewTests`)

These run only with `PROXIMEET_SIGNAL_REVIEW=1`.

- `testWalkthroughRealJourney` (recorded, full journey). The fresh app from Welcome: Birthday, the
  Pass demo, a typed fictional introduction, the card, then the Wristband with Social. Then:
  - Signal empty;
  - Chat first (the first choice: the tag moves onto the band);
  - Okay to say hello (the icon dissolves);
  - the active row again (nothing changes);
  - Back to the actual Wristband, then Dating and Continue preview: Okay to say hello is kept and
    the tag is attached at once;
  - Back to the card, an edit of the opener, then forward: the edit shows and both values are kept;
  - "End of this preview." with OK, staying on the choice.
- `testAllTwelveStates` (direct launches, fixture `signal`, once per intent). The unselected
  state, Chat first and Okay to say hello. Each is checked on the rendered screen: the carried
  band (by colour), the tag's pose, the icon on the tag, the rows, the summary and Continue.
- `testFirstChoicesChangesNoOpsAndReentry`. Both first choices, each on a fresh screen; both
  directions of change; the active row as a no-op (the tag does not move); and re-entry, which is
  attached at once rather than replaying the movement.
- `testRapidChangesAndInterruptionsStayConsistent`. Rapid taps leave the last choice, with the
  icon to match. Continue preview during a change shows one message. Back during the first
  movement, then forward, shows the attached tag and Chat first. The app sent to the background
  during the first movement and resumed shows the attached tag, the chosen icon, the summary and
  Continue. (A change to the system Reduce Motion setting during the movement is not run:
  XCUITest cannot change it inside a running app.)
- `testEndpointDuplicateTapsAndBack`. A double tap on Continue preview shows one message and
  stays. A double tap on either Back stops at the Wristband. Re-entry keeps both values, and no
  wording claims a Wave, chat, match, verification or visibility.
- `testMissingIntentKeepsSignalClosed`. Without an intent, Continue preview is disabled and
  Signal never opens.
- `testRelaunchStartsWithoutAnApproach`. After a relaunch and the real route, Signal has no
  approach.
- `testReduceMotionPreviewAttachesAtOnce`. With the app's `-ProximeetReduceMotionPreview YES`
  flag (not the system setting), the tag is attached immediately after the tap.
- `testLargestTextKeepsEveryChoiceReachable`, on device B and on the smaller iPhone. At the
  largest accessibility size:
  - DEMO is drawn whole;
  - the headline wraps;
  - the rows grow taller than 84 pt with their words, with the symbol and radio on a line above
    them;
  - both choices, the summary, the privacy line and both actions are reachable.

  Its captures name the width.
- `testAgeGateReturnJourneyBlocksForwardRoutesAndKeepsTheDrafts` (full journey). From Signal
  (Activity, Chat first), Back through every chapter to Birthday. An under-18 date disables
  Continue and opens nothing. The corrected date moves nothing until Continue, which opens the
  Pass at its intro. After the Pass is completed again, the introduction, the intent and the
  approach are all still there.

The pixel checks work at 3× on the 440 × 956 screen. They were calibrated against the approved
board:
- **The tag's pose.** Steel to the right of the band means resting. Steel under the clasp,
  reaching y 522, means attached.
- **The icon.** A 5 × 5 ink signature in the tag's 25 × 25 icon box.
- **The band.** Its mean colour.

### The integration checks

- **The Birthday gate on the way back.** The UI journey above, and the domain's
  `AgeGateReturnTests`, which cover:
  - under 18;
  - incomplete, impossible, future and uncommitted entries;
  - an old adult date from the legacy input, which cannot authorize a changed entry;
  - the correction, which needs Continue and goes through the Pass intro;
  - relaunch.
- **The Guest List keyboard Back.** `testKeyboardBackOnTheRealRouteReturnsToTheCompletePass`
  runs the full journey. With the keyboard open in the editor, a tap 3 pt inside Back's
  bottom-right corner returns to the actual, complete Pass, and the draft is kept.
  `testKeyboardDoneAndBackStayIndependent` is a direct launch (fixture `guest-list-filled`). Its
  captures are named `-direct-launch`, because the Pass below that fixture is a new screen at its
  intro.
- **`BandSignalInteractionTests`.** Rewritten for the approved Wristband → Signal flow. It is
  ungated, so the original verification workflow's interaction reel records the approved screens.

## 3. Starting it

1. Push the branch and confirm it with `git ls-remote`.
2. Check the free minutes, and check that no build is running.
3. Start one build through the Codemagic REST API with the branch, the workflow ID
   `proximeet-signal-review`, `SIGNAL_EXPECTED_COMMIT` and `SIGNAL_REVIEW_SCOPE`.
4. When it finishes, start the other scope on the same SHA. The two never overlap.

Afterwards confirm that `signal/source-checkpoint.txt` says `result=MATCH` with the expected
`scope=`, that the build record's commit is the pushed SHA, and that `git ls-remote` agrees.

## 4. Artifacts

Signal scope:

- `Signal-Screens.zip`:
  - the twelve states (direct launches);
  - the real journey's three Social states and end-of-preview message;
  - the largest text size on both widths;
  - the smaller iPhone (direct launches);
  - the integration evidence (age-gate journey, keyboard Back journey, keyboard direct launches
    on two sizes), with the notes the tests attached.

  Every file name says whether it is `XCTest-journey`, `XCTest-FIXTURE-direct-launch` or
  `simctl-FIXTURE-direct-launch`.
- `Signal-walkthrough-compact.zip` (and, only when it was re-encoded, the same MP4 loose). The compact journey, a labelled
  half-size re-encode trimmed to the app, or a labelled fallback copy.
- `Signal-walkthrough-original.zip`: the unedited simulator recording.
- `Signal-Review.zip`: an offline `Signal-Review/index.html`. It has:
  - the captures beside crops of the unchanged approved board, its row of band materials, and the
    band and tag delivery references;
  - the recordings;
  - the integration findings table, with each finding's tests and their outcomes;
  - every test with its device, outcome and duration;
  - the notes, the verdict, the source SHA, the logs and the unsigned simulator app.

  Its relative links are checked when it is made. Its SHA-256 is in `Signal-Review.zip.sha256`.

Regressions scope: `Signal-Regressions-Review.zip`, the same page for the earlier chapters' tests.

Both scopes: `Proximeet-Debug-iphonesimulator-<sha>.zip`, the unsigned simulator app. It cannot be
installed on an iPhone.

## 5. Not automated

- Visual approval against `docs/design/signal-approved/reference/`, which is the founder's call.
- VoiceOver: the single-choice reading, the "selected" announcement, and focus staying on the row.
- The system Reduce Motion and larger-text settings on a device.
- Composing keyboards, and the software keyboard on a device.
- Landscape and iPad. The app is portrait-only on iPhone, and other orientations are untested.
- Motion smoothness on a device. Simulator recordings drop frames.
