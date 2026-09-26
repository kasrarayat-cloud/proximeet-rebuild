# Guest List — manual macOS verification run

The workflow `proximeet-guest-list-review` in the root `codemagic.yaml` builds the approved Guest
List (chapter 04) as an unsigned Debug app for the iOS Simulator, runs its XCTest review with
real taps, typing and pastes, records the walkthrough and packages the review. It starts only by
hand: there is no `triggering` section. It has no code signing, Apple credentials, provisioning,
archive/IPA, TestFlight, publishing, notifications or environment groups. Results are recorded in
`docs/reports/guest-list-chapter-04.md` and in each build's own artifacts.

## 1. The source gate

`bash scripts/guest_list_review.sh checkpoint` fails the build unless the checkout is exactly the
reviewed revision:

- **Approved assets.** `guest-list-approved-files.sha256` lists:
  - the Welcome poses;
  - the five Manrope faces and their licence;
  - the Birthday housing;
  - the Pass artwork;
  - the Guest List card art (`GuestListCard.imageset/guest-list-card.png`, the original
    1457 × 1079 RGBA file, unchanged);
  - everything under `docs/design/{welcome,birthday,pass,guest-list}-approved/`.

  Every file must match. The card art, faces and licence must also match the Guest List
  handoff's own `SHA256SUMS.txt`, the Pass artwork must match the Pass handoff's, the housing
  must match Birthday's, and the faces must agree across all four handoffs.
- **Everything else.** `guest-list-review-files.sha256` lists every other file except itself.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules.
  The files in `guest-list-review-deletions.txt` (Welcome's deletions and the legacy
  `DemoPassView.swift`) must be absent. The legacy `GuestListView.swift` is replaced in place.
- **The Guest List guard.** The Guest List and Pass sources (`GuestListView.swift`,
  `PassView.swift`, `RepeatTapGuard.swift`, `DemoSession.swift`, `GuestIntroduction.swift`,
  `GuestListDemo.swift`, `PassDemo.swift`) must contain none of these:
  - verification, visibility, discoverability, membership, entitlement, presence or check-in
    flags or wording;
  - camera, biometric, photo, document-capture or location APIs;
  - network, persistence or logging APIs;
  - timers.
- **Pin.** The run input `GUEST_LIST_EXPECTED_COMMIT=<full 40-hex SHA>` must equal HEAD. It is
  given in the API request that starts the build, never stored in the tree. On Codemagic a
  missing pin fails the gate. Elsewhere it is optional, and `git_head` in
  `guest-list/source-checkpoint.txt` is then compared by hand.

## 2. Steps

The steps are the Pass review's steps, with `guest_list_review.sh` in place of `pass_review.sh`:

- `guest_list_review.sh destinations`, `captures`, `ui-review`, `compact-video`, `verdict`,
  `package-review` and `enforce`;
- `codemagic_verify.sh metadata`, `validate`, `select-simulator`, `build`, `package` and
  `domain-tests`.

`destinations` also starts booting a smaller iPhone in the background, so its first boot overlaps
the build and the main captures instead of being waited out. The metadata step, the gate, the
validation, simulator selection and the build stop the build on failure. The evidence steps continue. `enforce` fails the build unless the verdict is PASS.

The XCTest review runs in this order:

1. `build-for-testing`.
2. The recorder starts and must print "Recording started".
3. `GuestListReviewTests/testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint` runs
   alone and is recorded. The real route (Welcome, More options, the demo, Birthday wheels set to
   12 May 1997, Continue, Try the demo, Finish preview, Continue preview), then:
   - the empty editor;
   - typing "Alex", Return to the introduction, typing the fictional opener, Done;
   - the three interests;
   - Preview my card; Back on the card and Edit introduction, each back to the editor with the
     raw text and selections kept;
   - Back to the Pass, still complete, and re-entry with the draft kept;
   - Continue preview's "End of this preview." with OK, staying on the card.

   It compares the rendered screen with the approved board, in points at 440 × 956: the header,
   the support line, the labels, fields, placeholders or values, the count, the chips, the
   boundary sentence and both actions in the empty and example editors; and on the card the
   paper's top and bottom, the initial and its disc, the name, the opener's first line, the rule,
   the interests, the context line and both actions.
4. The other `GuestListReviewTests` that use only the on-screen keyboard:
   - `testInterestsToggleIndependentlyAndOptionalContentIsOmitted`: zero to three interests, the
     card's list and separators, the check mark, and a name-only card with no rule;
   - `testKeyboardFocusOrderReachabilityAndDismissal`: the focused field and both actions above
     the keyboard, Return from Name to Introduction, Return adding a line, and Done keeping the
     labels and the draft;
   - `testRepeatedTapsNeverDuplicateOrSkipARoute`: double taps on Continue preview, Preview my
     card, Edit introduction and both Backs;
   - `testRelaunchResetsTheDraftAndNothingIsConferred`: the endpoint, no verified, visible,
     present or member wording, no prompt, and an empty editor after relaunch through the real
     route;
   - `testReduceMotionPreviewKeepsTheCardStationary` (the app-level
     `-ProximeetReduceMotionPreview YES` flag, not the system setting);
   - `testLargestTextReflowsAndKeepsEverythingReachable` (the largest accessibility text size).

   `PassReviewTests`, `BirthdayReviewTests` and `WelcomeReviewTests` run as regressions in the
   same pass.
5. Last, in their own pass, the tests that send hardware key events (a hardware Tab, or ⌘V if
   the edit menu's Paste does not appear), since such events can leave the simulator without its
   on-screen keyboard:
   - `testBlankInternationalAndLongNames`: blank names, pasted international, punctuated and long
     names kept exactly, trimmed only on the card, and a long name growing the card;
   - `testOpenerLimitBoundariesAndPreservedPaste`: a 121-character paste (emoji, a family
     sequence, a composed accent, a flag) kept whole, 121 / 120 with help and no preview, one
     deletion back to 120 / 120, and 120 family emoji within the limit;
   - `testHardwareTabAndShiftTabMoveBetweenFields`: Tab from Name to Introduction, Shift-Tab back,
     Tab leaving Introduction, and no tab character typed.

The first two passes set `TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1`, `…_PASS_REVIEW=1`,
`…_BIRTHDAY_REVIEW=1` and `…_WELCOME_REVIEW=1`; the last sets the Guest List flag. Every required
test must be discovered, executed and passed; a skip fails the stage.

Tests that start from a DEBUG fixture say so. The `guest-list…` fixtures reach the Guest List
through Birthday's gate and a completed Pass demo; the fictional Alex example exists only in them
and in the tests.

`compact-video` re-encodes the recording at half size with AVFoundation
(`scripts/compact_video.swift`), trimmed to the app by frame brightness. If the re-encode fails,
the compact file is a labelled copy of the original.

## 3. Starting it

Push the branch, then start the build through the Codemagic REST API with the branch, the
workflow ID `proximeet-guest-list-review` and `GUEST_LIST_EXPECTED_COMMIT`. Afterwards confirm
three things: `guest-list/source-checkpoint.txt` says `result=MATCH`, the build record's commit is
the pushed SHA, and `git ls-remote` agrees.

## 4. Artifacts

Codemagic lists `.zip` (and app/package) files as separate items; other files go into its bundled
`…_artifacts.zip`. The downloads are:

- `Guest-List-Screens.zip`: the XCTest screenshots of the empty editor, the filled editor, the
  personal card, the name-only card, the validation feedback, the end-of-preview message, the
  largest text size (editor and card) and the keyboard open.
- `Guest-List-walkthrough-compact.zip`: the compact walkthrough MP4, labelled as re-encoded and
  trimmed, or as a fallback copy. The same MP4 is also a loose file inside the bundle.
- `Guest-List-walkthrough-original.zip`: the unedited simulator recording.
- `Guest-List-Review.zip`: an offline `Guest-List-Review/index.html` with real captures beside
  crops of the unchanged approved board, plus the recordings, the Reduce Motion preview, largest
  text and smaller-iPhone evidence, the regressions, the verdict and source SHA, the test
  results, the logs and the unsigned simulator app. Its SHA-256 is in
  `Guest-List-Review.zip.sha256`.
- `Proximeet-Debug-iphonesimulator-<sha>.zip`: the unsigned simulator app. It cannot be installed
  on an iPhone.

## 5. Not automated

- Visual approval against `docs/design/guest-list-approved/reference/`, which is the founder's
  call.
- VoiceOver: reading order, the card read once, focus after preview and edit, and the limit
  announcements.
- Composing input with a real input method (for example Japanese, Chinese or Korean).
- The system Reduce Motion and larger-text settings, and the keyboards, on a device.
- Motion smoothness on a device. Simulator recordings drop frames.
