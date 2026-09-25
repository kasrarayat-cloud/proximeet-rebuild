# Welcome — manual macOS verification run

**Status: configured, not run.** The workflow `proximeet-welcome-review` is in the root
`codemagic.yaml`. Nothing has been pushed or started, and no macOS build of this Welcome exists
yet. The checks the run feeds are listed in `welcome-runtime-review.md`.

## 1. What is being verified, and how the run proves it

**The source** is the approved Welcome (chapter 01) on branch
`welcome/approved-20260925T081446Z`, plus this review harness. The run must build **exactly**
the reviewed revision, never the base `7af76fa`.

**The source gate** is `bash scripts/welcome_review.sh checkpoint`, the second step. It fails
the build unless the whole checkout is exactly that revision:

- **Frozen Welcome.** `welcome-approved-files.sha256` lists every file under `Proximeet/`,
  `Proximeet.xcodeproj/`, `ProximeetDomain/` and `docs/design/welcome-approved/`: the app, art,
  fonts, licence, generated project, package and approved references. These are unchanged since
  the Welcome commit, and every one must match.
- **Everything else.** `welcome-review-files.sha256` lists every other tracked file (harness,
  workflow, docs, root files) except itself. Every one must match.
- **Nothing extra, nothing restored.** No other file may exist outside git's ignore rules, and
  the files the Welcome change deleted must be absent.
- **Optional pin.** The run input `WELCOME_EXPECTED_COMMIT=<full 40-hex SHA>` must also equal
  HEAD when it is given.

A manifest cannot vouch for the tree it lives in, and no commit or tree hash is stored inside
the tree. The external identity is the full commit SHA reviewed by the lead. Pass it as
`WELCOME_EXPECTED_COMMIT` when starting through the Codemagic API, which accepts variables
[C3]. The web UI's Start new build popup has no documented variable field, so without the pin,
compare `git_head` in `welcome/source-checkpoint.txt` (and `metadata/source.txt`) with the
reviewed SHA after the run.

## 2. Running it

### A. Codemagic (the founder has no Mac)

Codemagic builds a branch that exists on GitHub [C1], so the lead pushes the branch first. Then
someone clicks **Start new build**, selects the branch and `proximeet-welcome-review` [C3],
downloads the artifacts, and runs this on the VPS:

    python3 scripts/analyze_welcome_review.py <artifacts>/welcome

That needs ffmpeg, which is on the VPS but not on the Codemagic image [C5].

### B. A Mac with Xcode 26.6, no push needed

Check out the commit, then run the same steps in order:

    bash scripts/codemagic_verify.sh metadata          # fails unless Xcode 26.6
    bash scripts/welcome_review.sh checkpoint          # exactly the reviewed revision, or stop
    bash scripts/codemagic_verify.sh validate
    bash scripts/codemagic_verify.sh select-simulator  # prefers iPhone 17 Pro Max; never downloads
    bash scripts/welcome_review.sh destinations || true
    bash scripts/codemagic_verify.sh build             # app compilation, unsigned
    bash scripts/codemagic_verify.sh package || true
    bash scripts/welcome_review.sh captures || true
    bash scripts/welcome_review.sh ui-review || true
    bash scripts/welcome_review.sh verdict

The status bar override and the simulator text size are restored at the end. The unsigned
simulator app is installed into the selected simulators.

## 3. The workflow

`proximeet-welcome-review` runs on `mac_mini_m2` with Xcode `"26.6"`, for at most **30
minutes**. It has no `triggering` section, so it starts manually only [C2]. It has no signing,
Apple credentials, provisioning, archive or IPA, TestFlight, publishing, notifications or
environment groups.

| # | Step | On failure | Proves | Does not prove |
| --- | --- | --- | --- | --- |
| 1 | `codemagic_verify.sh metadata` | stop | HEAD, Xcode 26.6 (build), SDK, host | — |
| 2 | `welcome_review.sh checkpoint` | stop | the checkout is exactly the reviewed revision | compilation |
| 3 | `codemagic_verify.sh validate` | stop | project file, resources, guardrails | compilation |
| 4 | `codemagic_verify.sh select-simulator` | stop | an installed iPhone was chosen (iPhone 17 Pro Max first), nothing downloaded | — |
| 5 | `welcome_review.sh destinations` | continue | installed destinations; whether **iPhone 17 Pro Max** was installed and selected. If it was not, the report says so plainly, and the verdict fails | — |
| 6 | `codemagic_verify.sh build` | stop | **app compilation**: the SwiftUI app compiles for the simulator, unsigned | device behaviour |
| 7 | `codemagic_verify.sh package` | continue | the zipped unsigned simulator `.app` | installability on a phone |
| 8 | `welcome_review.sh captures` | continue | the launch recording (the recorder is confirmed active before a cold launch); the settled screenshot; the Reduce Motion preview; largest text; a smaller iPhone | taste, VoiceOver, performance |
| 9 | `welcome_review.sh ui-review` | continue | **test-harness compilation** (`build-for-testing`), then **runtime assertions** from `-only-testing:ProximeetUITests/WelcomeReviewTests` with `TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1` [A1] | visual fidelity |
| 10 | `welcome_review.sh verdict` | fails the build | automated verdict, with manual items listed as outstanding | the founder's approval |

- **Step order.** The smaller-iPhone capture runs after compilation and never fails the
  compile.
- **Evidence steps continue on failure.** Codemagic's `ignore_failure: true` lets the workflow
  continue past a failed script [C8], so later evidence is still collected.
- **Artifacts from failed builds.** The docs do not say whether a failed build still publishes
  artifacts. In this account's failed build 3, it did: its full artifact archive was delivered
  (`docs/reports/native-3d-verification.md`).

**Only this step enables the Welcome tests.** `WelcomeReviewTests` skips itself unless
`PROXIMEET_WELCOME_REVIEW=1` reaches the test runner. The step selects only that class and sets
the flag for that one `xcodebuild`, so the existing workflow's interaction run is unchanged.

The step then counts xcodebuild's per-test lines and requires all of:
- a **non-zero executed count** (passed + failed), and **no failure**;
- `testHonestNotices` and `testReduceMotionPreviewLaunch` **passed**.

An executed test also proves the flag reached the runner, because the tests skip without it;
each one also logs a `WELCOME_REVIEW_FLAG_SEEN` marker. So a disabled, skipped or undiscovered
suite **fails**. Geometry skips on a window other than 440 × 956, and large text skips if its
launch argument has no effect. Each skip is shown in the counts and never counts as a pass.

**The verdict** (`welcome/verdict.txt`) keeps these apart:
- source;
- toolchain, simulator model and runtime;
- the primary target;
- image dimensions;
- app compilation;
- test-harness compilation;
- runtime assertions;
- the other captures;
- the off-machine analysis still pending;
- the **manual review still outstanding**: visual approval, VoiceOver, the system Reduce Motion
  setting, a tap during the motion and interruption, and Apple branding.

The verdict never presents a Linux check as an iOS compile.

## 4. Launches and captures

Every launch runs `xcrun simctl launch --terminate-running-process <udid> com.proximeet.demo <args>`.
Every capture checks that the app process is alive before and after.

| Capture | Launch arguments | How |
| --- | --- | --- |
| warmup (not captured) | `-ProximeetFixture welcome` | 15 s, so first-run prompts settle |
| `welcome-motion.mp4` | `-ProximeetFixture welcome` | Terminate the app and start recording. Wait until simctl prints "Recording started" [A2], then 1 s more, then cold-launch. If recording is not confirmed within 10 s, the app is not launched and the capture fails. Runs 6 s after launch |
| `01-welcome-settled.png` | (same process) | after the recording |
| `welcome-reduce-motion.mp4` | `… -ProximeetReduceMotionPreview YES` | same pattern, 4 s. This is the app-level preview, **not** the system setting |
| `02-welcome-preview-flag-settled-layout.png` | (same process) | a layout check only |
| `03-welcome-largest-text-top.png` | `-ProximeetFixture welcome`, with simulator text size `accessibility-extra-extra-extra-large` | `simctl ui content_size` is undocumented [A4], so this stays **unverified** until the screenshot shows larger text. Skipped if the size cannot be read; restored afterwards |
| `04-welcome-smaller-iphone.png` | `-ProximeetFixture welcome` | Optional. The first installed of iPhone SE (3rd generation), 17e, 16e, 17, 16, 17 Pro, 16 Pro. On Codemagic's image that is iPhone 17e [C5] |

**Status bar.** It is overridden to 9:41, a charged battery and four cellular bars, with
documented flags only [A3], and cleared at the end.

**Motion timing.** It is measured off-machine by `analyze_welcome_review.py`, relative to the
first frame in which the app's content is visible. The recording opens on the home screen. The
closed hold may be partly hidden by the iOS launch animation, so the verdict checks blend
durations, linearity, monotonic order and "no regression". The analyser's synthetic self-test
is not runtime evidence.

## 5. Artifacts (`build/artifacts/`)

- `summary.txt`: one line per step with its real status.
- `logs/*.log`: `build.log`, the compiler log for app compilation, plus a log for every other
  step.
- `metadata/`:
  - `source.txt`: HEAD and `CM_COMMIT`;
  - `tools.txt`: Xcode version and build, SDK;
  - `simulator.json`: model, runtime, UDID;
  - `welcome-devices-available.json` and `welcome-runtimes-available.json`.
- `app/Proximeet-Debug-iphonesimulator-<sha>.zip` (+ `.sha256`): the unsigned simulator app.
- `welcome/source-checkpoint.txt`: the gate result, HEAD, tree, pin and both manifest hashes.
- `welcome/destination.txt`: installed iPhones, the primary-target status, the selection.
- `welcome/captures.tsv`: every capture, with its simulator, time, **pixel dimensions** and
  SHA-256.
- `welcome/01…04-*.png`, `welcome-motion.mp4`, `welcome-reduce-motion.mp4` (+ `.sha256`,
  `.log`): the captures.
- `welcome/WelcomeReview.xcresult.zip`: the test result bundle.
- `welcome/attachments/`: XCTest screenshots, notes, geometry, and the accessibility tree
  `accessibility-tree-default`.
- `welcome/geometry-*.json`, `test-summary.json`, `ui-review-tests.txt`,
  `ui-review-counts.txt`: per-test outcomes, counts and flag evidence.
- `welcome/verdict.txt`: the separated verdict.
- `welcome/welcome-review-analysis.{json,txt}`: written later, on the VPS.

## 6. Prerequisites

- **Codemagic.** The personal account with the app `proximeet-rebuild`
  (github.com/kasrarayat-cloud/proximeet-rebuild) connected. During the lead's review it showed
  **40 / 500** free macOS minutes used, no subscription and no billing transactions. The
  pricing page states 500 free M2 minutes a month, then $0.095 a minute [C6]. Check usage again
  before starting.
- **Source upload.** The lead pushes the branch to `origin`. The local Mac path needs none.
- **Tools.** Nothing to install on Codemagic. A local Mac needs Xcode 26.6 with an iOS 26
  simulator runtime. The VPS needs python3 and ffmpeg for the analysis.
- **No Apple account, certificate, profile, App Store Connect or TestFlight access is needed.**

## 7. What else could start a build

The lead checked these dashboards during this review; nothing was changed.

| Route | Observed | Still open |
| --- | --- | --- |
| Codemagic push/PR/tag | Neither workflow declares `triggering`, so manual only [C2]. No webhook deliveries | — |
| Codemagic schedule | "No builds scheduled" | A schedule added later would start builds [C7] |
| Codemagic REST API | — | Anyone holding an API token can start a build [C3]; not inspectable here |
| GitHub | The Webhooks page lists no hooks. Installed apps: Claude, Codemagic CI/CD, Google Labs Jules. The repository has no Actions workflow directory | The installed apps' own automation is not inspected |
| Xcode Cloud | No Xcode Cloud app is listed on GitHub | Apple-side Xcode Cloud settings not inspected [A9] |

These observations reduce the unknowns; they do not prove that no external trigger can exist.

## 8. Tracked, not changed in this run

- **Apple branding.** The approved prototype button stays as designed for this first simulator
  review. Before any sign-in or distribution work it needs correcting to Apple's HIG for custom
  Sign in with Apple buttons [A7]:
  - use Apple's supplied logo artwork, not the SF Symbol `apple.logo`;
  - make the logo and title black or white;
  - match the system's title-to-height proportions (the HIG quotes 43% of the button height as
    the system-font example, not as a universal number for every typeface).

  A pixel comparison of the button is not compliance approval, and no authentication is
  connected.
- **Birthday** is not implemented. It branches from the final Welcome commit, never from
  `7af76fa`, with the agreed route: More options → "Continue the demo (no account)" → the
  approved Birthday, Back to a settled Welcome, the draft kept in memory, and no authentication
  or verification state.

## 9. Sources (official documentation, 2026-09-25)

| Ref | Fact | Source |
| --- | --- | --- |
| C1 | `codemagic.yaml` must be at the repository root and is read per branch | https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/ |
| C2 | No `triggering` events means manual starts only; `codemagic.yaml` webhooks are set up by hand | https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/ |
| C3 | Manual start via Start new build → Specify build configuration; REST `POST /builds` can pass environment variables | yaml-getting-started; https://docs.codemagic.io/rest-api/builds/ |
| C4 | `mac_mini_m2` is valid; `max_build_duration` is 1–120 min; `xcode` accepts "26.6" | yaml-getting-started |
| C5 | The Xcode 26.6 image: Xcode 26.6 (17F113), macOS 26.5.1, iOS 26.5 runtime; iPhone 17, 17 Pro, 17 Pro Max, 17e, Air; python3 3.12.7; **no ffmpeg** | https://docs.codemagic.io/specs-macos/xcode-26-6/ |
| C6 | 500 free macOS M2 minutes a month (individual), then $0.095/min; 30-day artifact retention | https://codemagic.io/pricing/ |
| C7 | The Scheduled builds tab starts builds on a schedule | https://docs.codemagic.io/yaml-running-builds/scheduling/ |
| C8 | "When you set `ignore_failure` to `true`, the workflow will continue to run even if the script fails." Whether a failed build publishes artifacts is not stated (observed in build 3) | yaml-getting-started |
| A1 | `TEST_RUNNER_`-prefixed variables reach the test runner without the prefix | Xcode 13 release notes |
| A2 | `simctl io recordVideo --codec h264 --force`; stopped by SIGINT; prints "Recording started" | WWDC20 session 10647; Xcode 12.3 release notes |
| A3 | `simctl status_bar override --time --batteryState --batteryLevel --cellularBars`; `clear` | Xcode 11 release notes; WWDC20 10647 |
| A4 | No documented simctl switch for Reduce Motion; `simctl ui content_size` undocumented | unconfirmed (only `simctl ui appearance` is documented) |
| A5 | `xcresulttool export attachments` exists since Xcode 16; its manifest format is not documented on the web | Xcode 16.3 release notes |
| A6 | `-UIPreferredContentSizeCategoryName` launch argument | unconfirmed: community sources only |
| A7 | Custom Sign in with Apple buttons: Apple logo artwork, black or white, system proportions, allowed titles | https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple |
| A8 | SF Symbols depicting Apple products: display only, not customizable | https://developer.apple.com/design/human-interface-guidelines/sf-symbols |
| A9 | Xcode Cloud start conditions include Branch Changes | https://developer.apple.com/documentation/xcode/configuring-start-conditions |
| A10 | iPhone 17 Pro Max: 2868 × 1320 px; no official page gives 440 × 956 pt or the insets, so both are measured at runtime | https://support.apple.com/en-us/125091 |
