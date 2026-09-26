# Pass — manual macOS verification run

The workflow `proximeet-pass-review` in the root `codemagic.yaml` builds the approved Pass
(chapter 03) as an unsigned Debug app for the iOS Simulator, runs its XCTest review with real
taps, records the walkthrough and packages the review. It starts only by hand: there is no
`triggering` section. It has no code signing, Apple credentials, provisioning, archive/IPA,
TestFlight, publishing, notifications or environment groups. Results are recorded in
`docs/reports/pass-chapter-03.md`.

## 1. The source gate

`bash scripts/pass_review.sh checkpoint` fails the build unless the checkout is exactly the
reviewed revision:

- **Approved assets.** `pass-approved-files.sha256` lists:
  - the Welcome poses;
  - the five Manrope faces and their licence;
  - the Birthday housing;
  - the Pass artwork;
  - everything under `docs/design/{welcome,birthday,pass}-approved/`.

  Every file must match. The Pass artwork, faces and licence must also match the Pass
  handoff's own `SHA256SUMS.txt`, the housing must match Birthday's, and the faces must agree
  across all three handoffs.
- **Everything else.** `pass-review-files.sha256` lists every other file except itself.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules.
  The files in `pass-review-deletions.txt` (Welcome's deletions and the legacy
  `DemoPassView.swift`) must be absent.
- **The Pass guard.** The Pass sources must contain none of these:
  - verification-result wording or flags;
  - entitlement, camera, biometric, photo or document-capture APIs;
  - network or persistence APIs;
  - timers.
- **Pin.** The run input `PASS_EXPECTED_COMMIT=<full 40-hex SHA>` must equal HEAD. It is given
  in the API request that starts the build, never stored in the tree. On Codemagic a missing
  pin fails the gate. Elsewhere it is optional, and `git_head` in `pass/source-checkpoint.txt`
  is then compared by hand.

## 2. Steps

The steps are the Birthday review's steps, plus these:

- `pass_review.sh destinations`, `captures`, `ui-review`, `compact-video`, `verdict`,
  `package-review` and `enforce`;
- `codemagic_verify.sh metadata`, `validate`, `select-simulator`, `build`, `package` and
  `domain-tests`.

The metadata step, the gate, the validation, simulator selection and the build stop the build
on failure. The evidence steps continue. `enforce` fails the build unless the verdict is PASS.

The XCTest review runs in this order:

1. `build-for-testing`.
2. The recorder starts and must print "Recording started".
3. `PassReviewTests/testWalkthroughStartFinishEndpointLeaveReentryCancelBack` runs alone and
   is recorded. It covers the real route (Welcome, More options, the demo, Birthday wheels
   set to 12 May 1997, Continue), then:
   - Try the demo, and Finish preview at once;
   - Continue preview, "End of this preview." and OK, staying on Complete;
   - Leave demo, with Birthday keeping its date;
   - re-entry at the intro;
   - Cancel, back to the intro;
   - Back.

   It compares the rendered screen with the approved board, in points at 440 × 956:
   - Intro and Complete: the Back arrow, the wordmark, the DEMO label, the support line, the
     paper's top edge, the pass's "18+", "DEMO PASS" and "PROXIMEET", the claim, the primary
     action and the exit label.
   - Progress: the DEMO label, the paper and the card text lifted 6 pt, the claim and the
     primary action. The art and its text must move together.
   - The headline in every state, and Progress's support line and Cancel, are checked through
     accessibility labels only.
4. `testGateRapidTapsWaitingAndResumeNeverAdvanceOnTheirOwn` covers:
   - under-18 and partial dates not opening Pass;
   - a double tap on Continue, on Try the demo and on Back each acting once;
   - waiting and background/resume never advancing;
   - Finish preview working immediately;
   - no "verified" or "access granted" wording, and no permission prompt.
5. `testReduceMotionPreviewKeepsThePassStationary` launches with the app-level
   `-ProximeetReduceMotionPreview YES` flag, not the system setting, and checks the pass does
   not move.
6. `BirthdayReviewTests` and `WelcomeReviewTests` run as regressions.

All runs pass `TEST_RUNNER_PROXIMEET_PASS_REVIEW=1`, `…_BIRTHDAY_REVIEW=1` and
`…_WELCOME_REVIEW=1`. Every required test must be discovered, executed and passed; a skip
fails the stage.

`compact-video` re-encodes the recording at half size with AVFoundation
(`scripts/compact_video.swift`), starting from the walkthrough test's own start marker. If it
fails, the compact file is a labelled copy of the original.

## 3. Starting it

Push the branch, then start the build through the Codemagic REST API with the branch, the
workflow ID `proximeet-pass-review` and `PASS_EXPECTED_COMMIT`. Afterwards confirm three
things: `pass/source-checkpoint.txt` says `result=MATCH`, the build record's commit is the
pushed SHA, and `git ls-remote` agrees.

## 4. Artifacts

Codemagic lists `.zip` (and app/package) files as separate items; other files go into its
bundled `…_artifacts.zip`. The downloads are:

- `Pass-Screens.zip`: the Intro, Progress and Complete XCTest screenshots, plus the "End of
  this preview." message.
- `Pass-walkthrough-compact.zip`: the compact walkthrough MP4, labelled as re-encoded or as a
  fallback copy. The same MP4 is also a loose file, `Pass-walkthrough-compact.mp4`, inside
  the bundle.
- `Pass-walkthrough-original.zip`: the unedited simulator recording.
- `Pass-Review.zip`: an offline `Pass-Review/index.html` with real captures beside crops of the
  unchanged approved board. It also holds:
  - the recordings;
  - the Reduce Motion preview captures;
  - the labelled fixture captures (largest text, smaller iPhone);
  - the regressions;
  - the verdict and source SHA;
  - the test results;
  - the logs;
  - the unsigned simulator app.

  Its SHA-256 is in `Pass-Review.zip.sha256`.
- `Proximeet-Debug-iphonesimulator-<sha>.zip`: the unsigned simulator app. It cannot be
  installed on an iPhone.

## 5. Not automated

- Visual approval against `docs/design/pass-approved/reference/`, which is the founder's call.
- VoiceOver: the stage announcements, reading order, and the pass read once as a demo.
- The system Reduce Motion and larger-text settings on a device.
- Motion smoothness on a device. Simulator recordings drop frames.
