# Welcome — manual macOS verification run (proposed)

Status: **prepared, not run.** Nothing here has been dispatched, and no build of this Welcome
exists yet. This is the recipe for one manual, unsigned iOS Simulator build of the
checkpointed Welcome, plus its captures, a short motion recording and an XCTest review. The
checks it feeds are in `welcome-runtime-review.md`.

## 1. What is being verified

**Source.** The approved Welcome (chapter 01), implemented on branch
`welcome/approved-20260925T081446Z`, based on `7af76fafaaf51b729e008286570649ec3c79d209`. At
preparation time the implementation was **uncommitted**. Two private checkpoints on the VPS
hold it:

- **Checkpoint A**, `/home/proximeet/proximeet-welcome-checkpoint-A-20260925T143256Z`: the
  Welcome implementation alone, before this verification harness existed. It cannot run the
  review, because it has no harness.
- **Checkpoint B**, `/home/proximeet/proximeet-welcome-checkpoint-B-20260925T152758Z`: the same
  Welcome plus this harness and these documents. This is the source to review.

The lead's commit plan, kept with checkpoint B and outside the repository, turns B into a commit.

**The run must contain the checkpointed Welcome, never just the base commit.** The first
Welcome-specific stage enforces this:

- `bash scripts/welcome_review.sh checkpoint` checks that every file in
  `welcome-review-files.sha256` matches its SHA-256. That list covers every file under
  `Proximeet/`, `ProximeetUITests/`, `Proximeet.xcodeproj/`, `ProximeetDomain/` and `scripts/`,
  plus the changed documents.
- It also checks that **no other file** exists under those roots, and that the files in
  `welcome-review-deletions.txt` are absent.
- On any mismatch it fails, and the `captures` and `ui-review` stages then refuse to run.
- It writes `build/artifacts/welcome/source-checkpoint.txt` with the actual HEAD, tree, the
  manifest hash and the `codemagic.yaml` hash. `codemagic.yaml` is recorded rather than gated,
  because activating the proposed workflow changes it.
- The lead's plan also records the git tree the commit must have, so a reviewer can match
  `git_tree` too.
- The manifest cannot vouch for itself. If someone regenerates it after editing the app, the
  gate passes, but `manifest_sha256` and `git_tree` then differ from the plan. Compare both.

## 2. Two ways to run it

### A. Codemagic, the existing path (the founder has no Mac)

Codemagic builds a branch that exists in the connected GitHub repository, so the source must
be pushed first. That is the lead's decision and action, not this preparation's.

1. **Commit (lead).** Follow the lead commit plan: explicit paths only, no blanket staging.
2. **Activate the workflow (lead, optional commit).** Copy `proximeet-welcome-review` from
   `docs/verification/codemagic-welcome-review.yaml` into the root `codemagic.yaml` under
   `workflows:`, on the same branch. It has no `triggering` section, so it starts only by hand.
3. **Push the branch (lead).** Confirm it with `git ls-remote origin <branch>`; a local
   `origin/*` ref is only a cache.
4. **Start one build by hand (founder or lead, in the Codemagic web UI).** Click **Start new
   build**, then choose the pushed Welcome branch and the workflow `proximeet-welcome-review` in
   the **Specify build configuration** popup [C3]. Codemagic reads `codemagic.yaml` from the root
   of the branch being built [C1], so the workflow must be on that branch. Nothing in this
   repository starts it.
5. **Download the artifacts** (see §5) and put them on the VPS. Then run
   `python3 scripts/analyze_welcome_review.py <artifacts>/welcome`.

### B. Any Mac with Xcode 26.6, no push needed

Check out the lead's commit. Or restore **checkpoint B** with the git route in its
`RESTORE.md`: clone `base.bundle`, check out the base commit, then apply the patches. A bare tar
extraction is not enough, because the `metadata` and `package` stages need a git checkout.
Checkpoint A has no harness. Then run the same stages, stopping at the first failure:

    set -e
    bash scripts/codemagic_verify.sh metadata          # fails unless Xcode 26.6
    bash scripts/welcome_review.sh checkpoint          # exactly the checkpointed Welcome, or stop
    bash scripts/codemagic_verify.sh validate
    bash scripts/codemagic_verify.sh select-simulator  # prefers iPhone 17 Pro Max; never downloads
    bash scripts/codemagic_verify.sh build             # Debug, iphonesimulator, signing disabled
    bash scripts/codemagic_verify.sh package
    bash scripts/welcome_review.sh captures            # refuses to run unless checkpoint said MATCH
    bash scripts/welcome_review.sh ui-review           # likewise; fails if the review tests did not run
    python3 scripts/analyze_welcome_review.py build/artifacts/welcome   # needs ffmpeg; or run it on the VPS

A local Mac run changes the simulator's status bar override (restored at the end) and its text
size (read, then restored). It installs the unsigned simulator app into the selected simulators.

## 3. The stages and what each proves

| Stage | Command | Proves | Does not prove |
| --- | --- | --- | --- |
| metadata | `codemagic_verify.sh metadata` | HEAD, branch, Xcode 26.6, SDK, host | — |
| checkpoint | `welcome_review.sh checkpoint` | the Welcome files are the checkpointed ones | that they compile |
| validate | `codemagic_verify.sh validate` | the project file, resources and guardrails | compilation |
| select-simulator | `codemagic_verify.sh select-simulator` | an installed iPhone (iPhone 17 Pro Max preferred) is used; nothing is downloaded | — |
| build | `codemagic_verify.sh build` | **the SwiftUI app compiles** for the simulator, unsigned | device behaviour |
| package | `codemagic_verify.sh package` | a zipped simulator `.app` with its checksum | installability on a phone |
| captures | `welcome_review.sh captures` | what the screen showed: settled screen, pose-study recording, Reduce Motion preview, largest text, a smaller iPhone | taste, VoiceOver, performance |
| ui-review | `welcome_review.sh ui-review` | measured geometry, both notices, no navigation, large-text reachability (`WelcomeReviewTests`). It fails unless the notices and Reduce Motion preview tests actually **passed**. Geometry skips on a screen other than 440 × 956, and large text skips if its launch argument has no effect. Each skip appears in the summary line and never counts as a pass | visual fidelity (see captures) |
| analysis (off-machine) | `analyze_welcome_review.py` | motion timing and linearity, Reduce Motion settled from the first frame, pixel and ink closeness to the reference | the founder's approval |

The Welcome review deliberately leaves out the domain tests. They do not test Welcome, and
the existing workflow already runs them. It also leaves out the Band/Signal interaction stage,
and every fixture after Welcome: the **legacy Birthday is not captured or exposed**.

**The UI test is gated.** `WelcomeReviewTests` skips itself unless the runner has
`PROXIMEET_WELCOME_REVIEW=1`. The `ui-review` stage sets `TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1`
in xcodebuild's environment, which passes it to the test runner without the prefix. So the
existing `interaction` stage, which runs the whole UI test target while recording the
Band/Signal reel, is unchanged: the Welcome tests skip there.

## 4. Launch steps used

All launches go through `xcrun simctl launch --terminate-running-process <udid> com.proximeet.demo <args>`:

| Capture | Launch arguments | Timing |
| --- | --- | --- |
| warmup (not captured) | `-ProximeetFixture welcome` | 15 s, so first-run system prompts settle |
| `welcome-motion.mp4` | `-ProximeetFixture welcome` | the previous instance is terminated first. Recording starts on the home screen, and the app launches 1 s after simctl reports "Recording started". The recording runs 6 s after launch, and the app must still be running at the end |
| `01-welcome-settled.png` | (same process) | taken after that recording, well past 1.4 s |
| `welcome-reduce-motion.mp4` | `-ProximeetFixture welcome -ProximeetReduceMotionPreview YES` | same pattern, 4 s. **This recording is the Reduce Motion evidence** |
| `02-welcome-preview-flag-settled-layout.png` | (same process) | taken 4 s after launch, when even normal motion has settled. It is a **layout check only, not Reduce Motion evidence** |
| `03-welcome-largest-text-top.png` | `-ProximeetFixture welcome`, with simulator text size `accessibility-extra-extra-extra-large` | 5 s; the size is restored afterwards |
| `04-welcome-smaller-iphone.png` | `-ProximeetFixture welcome` on the first installed of: iPhone SE (3rd generation), iPhone 17e, iPhone 16e, iPhone 17, iPhone 16, iPhone 17 Pro, iPhone 16 Pro. On Codemagic's Xcode 26.6 image that is **iPhone 17e**, since the image lists iPhone 17, 17 Pro, 17 Pro Max, 17e and Air [C5]. Its screen size is recorded from the capture, not assumed | 15 s warmup, relaunch, 5 s; skipped if none is installed |

`-ProximeetFixture welcome` is the existing DEBUG launch argument. It starts a fresh demo
session on Welcome, which is also the app's normal entry screen. `-ProximeetReduceMotionPreview
YES` is the app-level Reduce Motion override, not the system setting; the system setting is a
manual check, and no documented simctl switch exists for it [A4].

**Status bar and recording.** The status bar is overridden to 9:41, with a charged battery and
four cellular bars, using only documented flags [A3], and cleared at the end. If the override
fails, the captures show the live status bar. Recordings are H.264 and are stopped with SIGINT
[A2]. The script waits for simctl's "Recording started" line before launching the app.

**Undocumented but used.** `simctl ui … content_size` has no official Apple documentation. It
worked in Codemagic build 2 (`docs/reports/visual-mac-verification.md`), and the stage skips
large text if it cannot read the current size. `-UIPreferredContentSizeCategoryName`, used by
the XCTest large-text case, is also undocumented [A6]. That test **skips**, and never passes, if
the text did not actually grow.

## 5. Artifact paths

Everything lands under `build/artifacts/` (DerivedData stays in `build/DerivedData`, never an artifact):

| Path | Content |
| --- | --- |
| `summary.txt` | one PASS/FAIL line per stage, with real exit status |
| `logs/*.log` | full log per stage (`welcome-checkpoint.log`, `welcome-captures.log`, `welcome-ui-review.log`, …) |
| `metadata/source.txt`, `tools.txt`, `simulator.json`, `app.txt` | source, tools, chosen simulator, built app |
| `app/Proximeet-Debug-iphonesimulator-<sha>.zip` (+ `.sha256`) | the unsigned simulator app |
| `welcome/source-checkpoint.txt` | checkpoint gate result, HEAD, tree, manifest hash |
| `welcome/captures.tsv` | every screenshot and recording, with its simulator, time, size and SHA-256 |
| `welcome/01-welcome-settled.png` | settled Welcome |
| `welcome/02-welcome-preview-flag-settled-layout.png` | settled layout under the Reduce Motion preview flag (layout only) |
| `welcome/03-welcome-largest-text-top.png` | largest text size, top of page |
| `welcome/04-welcome-smaller-iphone.png` | smaller iPhone, if installed |
| `welcome/welcome-motion.mp4` (+ `.sha256`, `.log`) | launch and pose study, 6 s |
| `welcome/welcome-reduce-motion.mp4` (+ `.sha256`, `.log`) | Reduce Motion launch, 4 s |
| `welcome/WelcomeReview.xcresult.zip` | the XCTest result bundle |
| `welcome/attachments/` | exported XCTest screenshots, notes and geometry JSON |
| `welcome/geometry-*.json` | geometry per scenario (from attachments, or from the test log) |
| `welcome/test-summary.json`, `ui-review-result.txt`, `ui-review-tests.txt` | xcresult summary, exit status, and each test's outcome (passed/failed/skipped) from xcodebuild's log |
| `welcome/welcome-review-analysis.{json,txt}` | written later by `analyze_welcome_review.py` |

## 6. Prerequisites

**Tools.**
- *Codemagic path:* nothing to install; the machine image provides Xcode, simulators and Python.
- *Mac path:* Xcode 26.6 with an iOS 26.x simulator runtime already installed, and python3.
- *Analysis:* python3 and ffmpeg/ffprobe (present on the VPS).

**Account.**
- The existing Codemagic account, with the `kasrarayat-cloud/proximeet-rebuild` repository connected (see `docs/reports/codemagic-setup.md`), for the founder or lead.
- No Apple account, certificates, profiles, App Store Connect or TestFlight access is needed.

**Source upload.** For Codemagic, the lead commits the plan's files and pushes the Welcome
branch to `origin`. The local Mac path needs no upload.

**Budget.** The workflow allows up to 45 minutes (the platform maximum is 120) [C4]. The
previous full workflow, which included the heavier interaction stage, took 16 m 27 s (build 4).

Codemagic's pricing page today (2026-09-25) states:
- 500 free macOS M2 minutes a month for the individual plan, one parallel build [C6];
- after that, $0.095 a minute on Mac mini M2;
- artifacts kept 30 days on the free plan.

The account's actual remaining minutes and billing state are **unknown from here**. The only
recorded figure is 10 of 500 used after build 2 (`docs/reports/visual-mac-verification.md`).
Builds 3 (13 m 31 s) and 4 (16 m 27 s) ran afterwards, with no recorded figure. Whether a run past
the free minutes would be billed or refused depends on the account's billing setting, which is
also unknown. Check the Codemagic billing page before starting.

## 7. Potential external build triggers

| System | What could start a build | Known state |
| --- | --- | --- |
| Codemagic, push/PR/tag | Only events declared under `triggering` in the branch's `codemagic.yaml`: "If no events are defined, you can start builds only manually" [C2]. For `codemagic.yaml` apps, webhooks are set up by hand [C2]. Neither the existing workflow nor this proposal declares events | Verified in the repo |
| Codemagic, scheduled builds | A schedule added in the app's **Scheduled builds** tab (branch, workflow, days, time) starts builds with no `triggering` section [C7] | **Unknown**: check that tab before pushing |
| Codemagic, REST API | Any `POST /builds` call with the account's API token starts a build [C3] | **Unknown** who holds a token; nothing here uses one |
| GitHub Actions | Nothing: the repository has no workflow directory, and the validator fails if one appears | Verified in the repo |
| Xcode Cloud | A push matching a workflow's **Branch Changes** start condition starts a build, if an Xcode Cloud workflow is connected to this repository [A9] | **Unknown**: not checkable from here. The repo's own report says Xcode Cloud "is not used" for this project; the legacy app's Xcode Cloud history belongs to a different repository |
| Other webhooks | Whatever is configured in GitHub › Settings › Webhooks for the repository | **Unknown**: check before pushing |

## 8. Notes that the run will not settle

- **The Apple logo and the custom button do not follow Apple's custom-button rules.** This is
  a design and compliance decision, not a runtime defect. The run confirms that the build
  matches the approved design, not that the design meets Apple's guidelines.

  For custom Sign in with Apple buttons, Apple's Human Interface Guidelines say [A7]:
  - "Use only the logo artwork downloaded from Apple Design Resources; never create a custom
    Apple logo." The approved build uses the SF Symbol `apple.logo` instead. SF Symbols that
    depict Apple products may be displayed but not customized; their per-symbol restrictions
    are shown only in the SF Symbols app [A8].
  - The logo and title must both be **black or white** on a black or white button. The approved
    button uses #050606 on #F6F7F2.
  - The title size must keep the system proportion: 43% of button height with the system font.
    The approved button has an 18 pt label in a 60 pt button.
  - "Continue with Apple" is an allowed title, and other fonts are allowed.

  Apple's guidelines also say App Review evaluates custom buttons, and TestFlight beta builds
  should comply with the App Review Guidelines [A7, A10]. The founder should decide, before real
  sign-in or any external TestFlight build, whether to swap in Apple's artwork and colours.
  Nothing in this preparation changes the approved button.
- **Birthday.** The later route is More options → "Continue the demo (no account)" → the
  approved Birthday, with Back returning to a settled Welcome and the Birthday draft kept in
  memory, creating no authentication or verification state. It is **not** part of this
  preparation or run. Its branch must be created from the lead's Welcome commit, **never from
  `7af76fa`**, which does not contain Welcome.

## 9. Remaining blockers before a verdict exists

1. **Nothing is committed or pushed.** The lead must commit checkpoint B's change set with the
   plan's explicit paths, then push the branch, for Codemagic to see it.
2. **The workflow is not active.** It exists only as a proposal under `docs/verification/`.
   The lead must add it to the root `codemagic.yaml`, manual and without triggers, or use a Mac.
3. **External state is unknown.** Codemagic minutes and billing, scheduled builds, API
   tokens, Xcode Cloud workflows and repository webhooks all need checking before a push (§7).
4. **The first native compile of Welcome has not happened.** Every result so far is Linux
   source checks, a syntax parse, and review; none of them is an iOS compile.
5. **The Apple button needs a design decision** (§8) before real sign-in or an external
   TestFlight build.
6. **Manual checks remain** (VoiceOver, system Reduce Motion, visual approval). They need a
   person with the running app or its artifacts; the founder's eyes decide what it looks like.

## 10. Sources checked (official documentation, 2026-09-25)

Each item was looked up on the official page and then independently re-checked.
"Unconfirmed" means no official page answered it.

| Ref | Fact | Source |
| --- | --- | --- |
| C1 | `codemagic.yaml` must be in the repository root and is read per branch (a file under `docs/` is inert) | https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/ |
| C2 | No `triggering` events → manual starts only; `codemagic.yaml` webhooks are set up manually | https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/ |
| C3 | Manual start: Start new build → Specify build configuration; REST `POST /builds` can also start builds with variables | yaml-getting-started (above); https://docs.codemagic.io/rest-api/builds/ |
| C4 | `mac_mini_m2` is valid; `max_build_duration` 1–120 min; `xcode` accepts a version such as "26.6" | yaml-getting-started (above) |
| C5 | Xcode 26.6 image: Xcode 26.6 (17F113), macOS 26.5.1, iOS 26.5 runtime; iPhone 17, 17 Pro, 17 Pro Max, 17e, Air; python3 3.12.7; **no ffmpeg** | https://docs.codemagic.io/specs-macos/xcode-26-6/ |
| C6 | 500 free macOS M2 minutes a month (individual); then $0.095/min; 30-day artifact retention | https://codemagic.io/pricing/ |
| C7 | Scheduled builds tab starts builds on a schedule | https://docs.codemagic.io/yaml-running-builds/scheduling/ |
| A1 | `TEST_RUNNER_`-prefixed variables reach the test runner without the prefix (not the launched app) | Xcode 13 release notes, developer.apple.com |
| A2 | `simctl io recordVideo --codec h264 --force`; recording ends on SIGINT; "Recording started" is printed | WWDC20 session 10647; Xcode 12.3 release notes |
| A3 | `simctl status_bar override --time --batteryState --batteryLevel --cellularBars`; `clear` | Xcode 11 release notes; WWDC20 10647 (`--wifiBars` unconfirmed, so not used) |
| A4 | No documented simctl switch for Reduce Motion or Increase Contrast; `simctl ui content_size` undocumented | Unconfirmed (only `simctl ui appearance` is documented, Xcode 11.4) |
| A5 | `xcresulttool export attachments` exists since Xcode 16 | Xcode 16.3 release notes; the manifest format is unconfirmed (`xcresulttool help` on the Mac) |
| A6 | `-UIPreferredContentSizeCategoryName` launch argument | Unconfirmed: community sources only |
| A7 | Sign in with Apple custom-button rules (logo artwork, black/white, proportions, titles, App Review evaluates) | https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple |
| A8 | SF Symbols depicting Apple products: display only, no customization; restrictions in the SF Symbols app | https://developer.apple.com/design/human-interface-guidelines/sf-symbols |
| A9 | Xcode Cloud start conditions include Branch Changes | https://developer.apple.com/documentation/xcode/configuring-start-conditions |
| A10 | TestFlight builds should comply with the App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| A11 | iPhone 17 Pro Max: 2868 × 1320 px, 460 ppi, Dynamic Island. No current official page gives 440 × 956 pt or the safe-area insets, so both are measured at runtime | https://support.apple.com/en-us/125091 |
