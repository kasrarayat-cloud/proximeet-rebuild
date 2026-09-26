# Wristband — manual macOS verification run

The workflow `proximeet-wristband-review` in the root `codemagic.yaml` builds the approved
Wristband (chapter 05) as an unsigned Debug app for the iOS Simulator, runs its XCTest review
with real taps and typing, records the walkthrough, repeats the Guest List keyboard check on two
phone sizes, runs the earlier chapters' regressions and packages the review. It starts only by
hand: there is no `triggering` section. It has no code signing, Apple credentials, provisioning,
archive/IPA, TestFlight, publishing, notifications or environment groups. Its limit is 28 minutes.
Results are recorded in each build's own artifacts and in the delivery message.

## 1. The source gate

`bash scripts/wristband_review.sh checkpoint` fails the build unless the checkout is exactly the
reviewed revision:

- **Approved assets.** `wristband-approved-files.sha256` lists:
  - the Welcome poses, the five Manrope faces and their licence, the Birthday housing, the Pass
    artwork and the Guest List card art;
  - the four Wristband artworks (`Wristband{Social,Dating,Business,Activity}.imageset/`
    `wristband-<intent>.png`, the original 1254 × 1254 RGBA files, unchanged);
  - everything under `docs/design/{welcome,birthday,pass,guest-list,wristband}-approved/`.

  Every file must match. The four artworks, the faces and the licence must also match the
  Wristband handoff's own `SHA256SUMS.txt`; the card art, the Pass artwork and the housing must
  match their handoffs'; the faces and the licence must agree across all five handoffs.
- **Everything else.** `wristband-review-files.sha256` lists every other file except itself.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules. The
  files in `wristband-review-deletions.txt` (the earlier chapters' deletions and the legacy
  `BandSelectionView.swift`) must be absent.
- **The Wristband guard.** `WristbandView.swift`, `WristbandChoice.swift` and the Guest List and
  Pass sources guarded before them must contain none of these:
  - verification, visibility, discoverability, membership, entitlement, presence or check-in
    flags or wording;
  - camera, biometric, photo, document-capture, location, Bluetooth, NFC, Watch or notification
    APIs;
  - network, persistence or logging APIs;
  - timers or repeating animation.
- **Pin.** The run input `WRISTBAND_EXPECTED_COMMIT=<full 40-hex SHA>` must equal HEAD. It is
  given in the API request that starts the build, never stored in the tree. On Codemagic a
  missing pin fails the gate. The stage also records the start of the time budget.

## 2. Steps

- `codemagic_verify.sh metadata`, then `wristband_review.sh checkpoint`, then `codemagic_verify.sh
  validate` and `select-simulator`. These stop the build on failure.
- `wristband_review.sh destinations` reports the iPhone 17 Pro Max target and creates a second
  iPhone 17 Pro Max on the same runtime ("device B", deleted when the review ends). Both start
  booting here, behind the compilation.
- `codemagic_verify.sh build`, `package` and `domain-tests`.
- `wristband_review.sh ui-review`, `compact-video`, `verdict`, `package-review` and `enforce`.
  `enforce` fails the build unless the verdict is PASS.

`ui-review` keeps its own deadline, 22.5 minutes after the gate began, and bounds every
`xcodebuild` and every wait by it, so the video, the verdict and the downloads are always made
inside the 28 minutes. XCTest's own per-test time allowance is on (300 s, at most 360 s).

It runs in this order:

1. `build-for-testing`, then an APFS clone of the build products for device B.
2. In parallel:
   - **The selected iPhone 17 Pro Max.** The recorder starts and must print "Recording started".
     `WristbandReviewTests/testWalkthroughRouteChoicesBackReentryEndpoint` runs alone, recorded,
     with its full pauses. Then the other `WristbandReviewTests` and the `BirthdayReviewTests`
     and `WelcomeReviewTests` regressions.
   - **Device B.** The on-screen-keyboard `GuestListReviewTests` (the new
     `testKeyboardDoneAndBackStayIndependent` included) and `PassReviewTests`; then, last and in
     their own pass, the Guest List tests that send hardware key events. The Guest List tests are
     not recorded here, so they run with `PROXIMEET_SHORT_HOLDS=1`: each of their pauses is at
     most 0.6 s, still longer than any 220 ms change. The Pass, Birthday and Welcome tests are
     unchanged and keep their own pauses.
3. The selected simulator shuts down, and a smaller iPhone (the first installed of iPhone 17e,
   16e, SE, 17, 16, 17 Pro, 16 Pro) runs `testKeyboardDoneAndBackStayIndependent` again, then
   three supplementary fixture captures (empty, Social, Activity).

Without device B the same tests run in sequence on the selected simulator, if the time allows.

### The Wristband tests

- `testWalkthroughRouteChoicesBackReentryEndpoint` (recorded). The real route (Welcome, More
  options, the demo, Birthday 12 May 1997, Continue, the Pass demo, Continue preview), typing a
  fictional introduction, Preview my card, Continue preview. Then:
  - the empty Wristband: no tile selected, the empty summary, Continue preview disabled;
  - Social, Dating, Business and Activity, each by a real tap, each checked on the rendered screen;
  - the chosen tile again: nothing changes;
  - header Back to the actual Guest List card, with the typed introduction;
  - Edit introduction, adding to the opener, Preview my card (the edit shows), Continue preview:
    Activity is kept;
  - the bottom Back, re-entry, Activity kept;
  - Continue preview: "End of this preview." with OK, staying on Activity.
- `testEveryChangeBetweenIntentsKeepsEverythingInAgreement` (fixture `wristband`): none to Social,
  then all twelve ordered changes between intents in one circuit. After each, exactly one tile is
  selected, the summary, explanation and Continue preview match it, the hero shows its band (by
  colour) and only its tile draws the check.
- `testRapidChangesLeaveTheLastChoice` (fixture `wristband`): taps in quick succession leave the
  last choice, shown consistently. Turning the device leaves the portrait-only screen as it was.
- `testEndpointDuplicateTapsAndBack` (fixture `wristband-business`): a double tap on Continue
  preview shows one message; a double tap on either Back stops at the card; re-entry keeps
  Business; no verified, visible, member or consent wording and no prompt.
- `testRelaunchStartsUnselected` (fixture `wristband-dating`, then a relaunch and the real route):
  the new run's introduction is empty and its Wristband unselected.
- `testReduceMotionPreviewChangesWithoutMovement` (the app-level `-ProximeetReduceMotionPreview
  YES` flag, not the system setting): the new band is in place 0.2 s after the tap, and nothing
  moves. The standard path is also an in-place dissolve (220 ms rather than 120 ms), so this test
  shows the Reduce Motion outcome; it does not prove that the flag shortened the dissolve.
- `testLargestTextKeepsEveryChoiceReachable` (fixture `wristband-social`, the largest
  accessibility text size): DEMO is drawn whole, the headline wraps rather than shrinks, the
  choices become one column of 44-pt-or-taller targets, and every choice, the summary, the
  privacy sentence and both actions are reachable.

The rendered-screen checks compare the screenshot, in points at 440 × 956, with the approved
board (empty, Social, Dating) and `LAYOUT_SPEC.json` (Business, Activity): the back arrow, the
wordmark, DEMO, the headline, the support line, the bands' rows (four quadrants when empty), the
summary in the intent's colour, the explanation, each tile's fill, name and icon, the selected
tile's border and check, the privacy sentence and both actions. Band colours come from the
original artworks with the approved crop.

### The Guest List keyboard follow-up

On build `6ab75905` (iPhone 17 Pro Max) the keyboard's floating Done lay at y 569–605 over the
bottom-right corner of Back's 376 × 44 target (545–589). While a field is focused, the editor's
actions now keep 36 pt more room above the keyboard (a public-API padding; the targets keep their
size and the keyboard-closed layout is unchanged). `testKeyboardDoneAndBackStayIndependent` runs
on both sizes. For each field it records the frames of Done, both actions, the keyboard and the
field, and checks that Done meets neither action, that both actions keep their size above the
keyboard, and that Done closes the keyboard and stays on the editor with the draft. Then, with the
keyboard open, a tap 3 pt inside the bottom-right corner of Back's target must go back to the Pass.

### Regressions

The Guest List tests keep their checks. Only the endpoint changed, intentionally: Continue
preview on the card opens the Wristband, whose Back returns to the card. `PassReviewTests`,
`BirthdayReviewTests` and `WelcomeReviewTests` are unchanged.

Every required test must be discovered, executed and passed on its device (the Wristband,
Birthday and Welcome tests on the selected simulator, the Guest List and Pass tests on device B,
the keyboard check also on the smaller iPhone); a skip fails the stage. The review flags are
`TEST_RUNNER_PROXIMEET_{WRISTBAND,GUEST_LIST,PASS,BIRTHDAY,WELCOME}_REVIEW=1`.

## 3. Starting it

Push the branch, then start the build through the Codemagic REST API with the branch, the
workflow ID `proximeet-wristband-review` and `WRISTBAND_EXPECTED_COMMIT`. Afterwards confirm
three things: `wristband/source-checkpoint.txt` says `result=MATCH`, the build record's commit is
the pushed SHA, and `git ls-remote` agrees.

## 4. Artifacts

- `Wristband-Screens.zip`: the XCTest screenshots of the empty state, Social, Dating, Business,
  Activity and the end-of-preview message; the largest text size; the smaller-iPhone fixture
  captures; and the Guest List keyboard evidence from both sizes, with the measured frames.
- `Wristband-walkthrough-compact.zip` (and the same MP4 loose): the compact walkthrough, labelled
  as re-encoded and trimmed, or as a fallback copy.
- `Wristband-walkthrough-original.zip`: the unedited simulator recording.
- `Wristband-Review.zip`: an offline `Wristband-Review/index.html` with the captures beside crops
  of the unchanged approved board and the four delivery references, the recordings, the route,
  Reduce Motion preview, largest-text, smaller-iPhone and keyboard evidence, the regressions, the
  verdict and source SHA, the test results and the logs, and the unsigned simulator app. Its
  SHA-256 is in `Wristband-Review.zip.sha256`.
- `Proximeet-Debug-iphonesimulator-<sha>.zip`: the unsigned simulator app. It cannot be installed
  on an iPhone.

## 5. Not automated

- Visual approval against `docs/design/wristband-approved/reference/`, which is the founder's call.
- VoiceOver: the single-choice reading, the selection announcement and focus after each choice
  and after Back.
- The system Reduce Motion and larger-text settings, and the keyboards, on a device.
- Motion smoothness on a device. Simulator recordings drop frames.
