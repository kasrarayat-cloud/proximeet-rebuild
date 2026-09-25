# Birthday — manual macOS verification run

The workflow `proximeet-birthday-review` in the root `codemagic.yaml` builds the approved
Birthday (chapter 02) as an unsigned Debug app for the iOS Simulator, runs its XCTest review
with real taps, records the walkthrough and packages `Birthday-Review.zip`. It starts only by
hand: there is no `triggering` section, so pushes, pull requests, tags and webhooks start
nothing. Results are recorded in `docs/reports/birthday-chapter-02.md`.

Excluded: code signing, Apple credentials, provisioning, archive/IPA, TestFlight, publishing,
notifications and environment groups.

## 1. The source gate

`bash scripts/birthday_review.sh checkpoint` is the second step. It fails the build unless the
checkout is exactly the reviewed revision:

- **Approved assets.** `birthday-approved-files.sha256` lists the Welcome poses, the five
  Manrope faces and their licence, the Birthday housing and everything under
  `docs/design/welcome-approved/` and `docs/design/birthday-approved/`. Every file must match.
  The housing, the faces and the licence must also match the handoff's own
  `docs/design/birthday-approved/SHA256SUMS.txt`, and the faces must agree with Welcome's
  `FONT_SOURCE.json`.
- **Everything else.** `birthday-review-files.sha256` lists every other file except itself.
  That covers the app code, the project, the domain package, the tests, the harness and the docs.
- **Nothing extra, nothing restored.** No unlisted file may exist outside git's ignore rules.
  The files Welcome deleted (`welcome-review-deletions.txt`) must still be absent.
- **Pin.** The run input `BIRTHDAY_EXPECTED_COMMIT=<full 40-hex SHA>` must equal HEAD. The
  manifests never contain the hash of the commit that holds them. The pin comes from outside,
  in the API request that starts the build.

The Welcome gate (`welcome_review.sh checkpoint` and its two manifests) is kept unchanged as
the record of the Welcome checkpoint. It describes Welcome's revision, not this one.

## 2. Steps

| Step | Command | On failure |
| --- | --- | --- |
| Tool versions (Xcode 26.6 required) | `codemagic_verify.sh metadata` | stops |
| Source gate | `birthday_review.sh checkpoint` | stops |
| Project validation (no regeneration) | `codemagic_verify.sh validate` | stops |
| Simulator selection (iPhone 17 Pro Max preferred, no downloads) | `codemagic_verify.sh select-simulator` | stops |
| Installed destinations | `birthday_review.sh destinations` | continues |
| App compilation, unsigned | `codemagic_verify.sh build` | stops |
| Unsigned simulator app zip | `codemagic_verify.sh package` | continues |
| Domain tests on the Mac (`swift test`) | `codemagic_verify.sh domain-tests` | continues |
| Supplementary fixture captures | `birthday_review.sh captures` | continues |
| XCTest review | `birthday_review.sh ui-review` | continues |
| Verdict | `birthday_review.sh verdict` | continues |
| `Birthday-Review.zip` | `birthday_review.sh package-review` | continues |
| Enforce | `birthday_review.sh enforce` | fails the build unless PASS |

The XCTest review runs in this order:

1. `build-for-testing` compiles the app and the UI-test harness.
2. The simulator recorder starts and must print "Recording started" before anything runs.
3. `BirthdayReviewTests/testWalkthroughEntryCorrectionContinueBack` runs alone. It enters an
   adult date on the wheels, checks Continue's notice, corrects to an under-18 date, goes Back
   to Welcome and returns to find the draft kept. It also checks the screen's pixels, so it
   fails unless the wheel values are actually drawn, not merely present in the accessibility
   tree. It checks that:
   - the empty state draws nothing but the placeholders;
   - choosing only the day leaves month and year unset;
   - the window's edges show no part-row;
   - a real finger drag turns the Day wheel without setting or drawing month or year;
   - a short drag on the unset Month wheel, released back onto it, leaves "MMM" alone again;
   - ten rendered anchors (the Back arrow, the wordmark, the headline, the eligibility line,
     the three day rows, "Enter date instead", the guidance and Continue) sit where the
     approved board measures them.

   These screen checks record failures without stopping the walkthrough, so every later state
   is still captured. Any failure still fails the test.
4. The recorder stops, and its movie is `birthday-interaction.mp4`.
5. `testTypedEntryPreservesComponentsAndKeyboard` runs, followed by all of
   `WelcomeReviewTests`: Welcome's geometry, the Apple notice, the new More options choice,
   reduce motion and largest text.

Both runs pass `TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1` and
`TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1`. The stage passes only if every run executes tests and
none fail. These tests must pass, never skip:

- the Birthday walkthrough;
- the Birthday typed entry;
- `testHonestNotices`;
- `testReduceMotionPreviewLaunch`;
- `testDefaultGeometry`.

A test that is skipped or never discovered counts as a failure.

The fixture captures are DEBUG launches into a prepared state:

- empty;
- 12 May 1997;
- 12 May 2012;
- the adult state at the largest accessibility text size (`simctl ui content_size`, an
  undocumented command);
- the adult state on a smaller installed iPhone.

They are labelled as fixtures everywhere and are not interactions.

## 3. Starting it

Push the branch, then start the build through the Codemagic REST API. Use the branch
name, the workflow ID `proximeet-birthday-review` and the variable `BIRTHDAY_EXPECTED_COMMIT`
set to the pushed commit's full SHA. Afterwards, confirm three things:

- `birthday/source-checkpoint.txt` says `result=MATCH` and shows the same `git_head`;
- the build record's commit hash is the pushed SHA;
- `git ls-remote` shows the branch at that SHA.

On a Mac with Xcode 26.6, check out the commit and run the table's commands in order, with
`|| true` after the "continues" steps.

## 4. Artifacts

- `Birthday-Screens.zip` (the empty, adult and under-18 XCTest screenshots, a few MB) and
  `Birthday-Walkthrough.zip` (the walkthrough recording, when one was produced) are separate
  downloads, much smaller than the full review archive.
  `Birthday-Review.zip.sha256` is the archive's checksum.
- `Birthday-Review.zip`: open `Birthday-Review/index.html` after unzipping. It works offline
  with relative paths only. It holds:
  - the interaction movie;
  - the XCTest state screenshots beside crops of the approved board;
  - the typed-entry states;
  - the Welcome regression screens;
  - the labelled fixture captures;
  - the verdict and the source SHA;
  - the test results (`.xcresult` zips and summaries);
  - the logs;
  - the unsigned simulator app.
- The same evidence, loose, under `build/artifacts/birthday/`, plus `summary.txt`, the logs,
  the metadata and `app/`.

The simulator app cannot be installed on an iPhone or submitted anywhere.

## 5. Not automated

- Visual approval against `docs/design/birthday-approved/reference/` (the founder's call).
- VoiceOver: wheel adjustment, what is announced, and reading order.
- The system Reduce Motion and larger-text settings on a device.
- The 29 February policy (1 March in non-leap years) is provisional and needs product
  confirmation.
