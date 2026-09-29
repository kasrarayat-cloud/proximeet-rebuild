# Room — manual macOS verification run

The workflow `proximeet-room-review-45` in the root `codemagic.yaml` builds the Room (chapter 08) as
an unsigned Debug app for the iOS Simulator. Its twins `proximeet-room-review-35`, `-30` and `-25` are
identical but for their name, their limit and their UI deadline (§5). It runs the Room's XCTest review with real taps, records
the real journey through Common Ground's explanation into the Room and back, reruns the Places rows
that the Room's integration touches, and packages the review.

It is the Places harness (`scripts/places_review.sh`, `scripts/places_review_results.py`,
`scripts/places_review_package.py`) with five new scopes and an optional row filter. It is not a new harness: every rule of
`docs/verification/places-mac-review.md` still holds (the source gate, the pinned commit, bounded
runs, no retries, one infrastructure rerun for a run that started no test, and the verdict kept apart
from manual review).

It starts only by hand: there is no `triggering` section. It has no code signing, Apple credentials,
provisioning, archive/IPA, TestFlight, publishing, notifications or environment groups. Its limit is
45 minutes (35, 30 or 25 for the twins).

**Nothing in this document has run on a Mac yet.** The harness was rehearsed on the VPS with stubbed
`xcodebuild`, `xcrun` and `simctl` (§7). Every Mac outcome is PENDING until a build reports it.

## 0. Starting a build

Start `proximeet-room-review-45` (or a twin, §5) through the Codemagic API with these environment
variables:

- `PLACES_EXPECTED_COMMIT`: the full 40-hex SHA of the reviewed commit. It is required on Codemagic,
  and the source gate fails unless `HEAD` equals it.
- `PLACES_REVIEW_SCOPE`: `room`, `room_regression`, `room_regression_main`, `room_regression_small`
  or `room_all` (§1). Any scope in the manifest is accepted, so the scope must be named.
- `PLACES_ROW_FILTER` (optional): comma-separated row IDs of that scope, for example `R3,R9,R14`
  (§1.1). Unset, every row of the scope runs.

Each workflow sets its own `PLACES_UI_DEADLINE_SECONDS`: 2340 (45), 1740 (35), 1440 (30) or 1140 (25)
(§5). The source gate accepts 600 to 2340; before the Room it accepted 600 to 2040. The Places
workflows keep their own values.

Whatever starts the build must pass the variables and name one of these workflows; the Places
workflows' dispatch does not start them.

## 1. Scopes

`docs/verification/places-review-manifest.tsv` holds the rows. Its columns are scope, order, device,
run, bundle, bound in seconds, test and kind.

| Scope | iPhone 17 Pro Max (main) | Then the smaller iPhone | Rows |
| --- | --- | --- | --- |
| `room` | R1, the recorded Room journey (alone, full holds); R2, the captures of every approved state and overlay (alone); R3–R13, the other `RoomReviewTests` methods | R14, the largest text again | 14 (13 unique methods) |
| `room_regression` | C1, C2, C3, P2, P4, P1; then C4, C5, C9, C6, C7, C8 | C15, P9–P13; then C10, C12, C13, C14; then C11 alone | 23 |
| `room_regression_main` | `room_regression`'s main rows: C1, C2, C3, P2, P4, P1; then C4, C5, C9, C6, C7, C8 | none (not booted) | 12 |
| `room_regression_small` | none (not booted) | `room_regression`'s smaller-iPhone rows: C15, P9–P13; then C10, C12, C13, C14; then C11 alone | 11 |
| `room_all` | `room`'s main rows, then `room_regression`'s | `room`'s R14, then `room_regression`'s | 37 |

**The Room's rows** (`RoomReviewTests`; each method name is the manifest's):

| Row | Run (bound) | Method |
| --- | --- | --- |
| R1 | `journey` (900 s), recorded | `testRealJourneyFromTheExplanationThroughTheRoomAndBack` |
| R2 | `room_capture` (720 s) | `testCaptureApprovedStatesAndOverlays` |
| R3 | `room_main` (1200 s) | `testBackGesturesInTheRoom` |
| R4 | `room_main` | `testBusinessCompatibility` |
| R5 | `room_main` | `testEntryNeedsBothDeliberateGates` |
| R6 | `room_main` | `testIneligibleAndStaleEntryIsRefused` |
| R7 | `room_main` | `testLargestTextKeepsRoomReachable` (iPhone 17 Pro Max) |
| R8 | `room_main` | `testLeaveFromEveryContext` |
| R9 | `room_main` | `testNotesFilteringAndBothBlockOrders` |
| R10 | `room_main` | `testReduceMotionPreviewRoom` |
| R11 | `room_main` | `testReportPreviewIsLocalAndRestoresItsCaller` |
| R12 | `room_main` | `testSocialCompatibilityAndBothApproaches` |
| R13 | `room_main` | `testTerminalReentryResetsTheDemo` |
| R14 | `room_small` (600 s), smaller iPhone | `testLargestTextKeepsRoomReachable` |

Within a run, XCTest orders the tests by class, then by name; R3–R13 are listed in that order.

- **R1 is alone and first.** It is the one recorded run, so it keeps full holds and its own bound.
  Its bound includes the main runner's first start.
- **R2 is alone.** It makes about 27 direct launches (15 states, 8 overlays, 4 report selections),
  so the longest test gets its own bound. A slow R2 cannot take R3–R13's time.

**The Places rows (`room_regression`)** are the recommended minimal rerun set from the Room's
affected-Places review. They cover entry and return, the category, eligibility, the age gate, the
footers and the Signal boundary. Each row keeps its earlier ID, test method and device, with short
holds; nothing is recorded:

| Run (bound) | Device | Rows | Measured (latest passes) |
| --- | --- | --- | --- |
| `rr_places_main` (1080 s) | main | C1, C2, C3, P2, P4, P1 | 666 s |
| `rr_signal_main` (600 s) | main | C4, C5, C9, C6, C7, C8 (the correction's `correction_signal`) | 368 s |
| `rr_places_small` (900 s) | smaller | C15, P9, P10, P11, P12, P13 | 614 s |
| `rr_correction_small` (600 s) | smaller | C10, C12, C13, C14 | 253 s |
| `rr_correction_small_b` (240 s) | smaller | C11 alone, as in the correction scope | 63 s |

- C10 was the correction's recorded walkthrough. Here it runs unrecorded with short holds, like
  every row but R1.
- None of these results counts toward the Places recovery. That recovery is frozen at `808950f`,
  and the Room changes product files. The rows compare with the earlier builds' row by row, by ID.

**`room_regression_main` and `room_regression_small`** are `room_regression` split by lane, because
its 23 rows (1964 s of tests) do not fit one 45-minute build when the two iPhones run one after the
other (§5). Their rows are copies of `room_regression`'s: the same row IDs, test methods, devices,
runs, bundles, bounds and order. Everything `room_regression` gets, they get: they are room scopes
and sequential scopes, with the smaller iPhone's 420-s boot bound, the 600-s XCTest allowance (§4),
the generic review page and verdicts with their own counts (12 and 11).

### 1.1 The row filter (`PLACES_ROW_FILTER`)

An optional run input for any scope: comma-separated row IDs, for example `R3,R9,R14`.

- **The source gate validates it.** Every ID must match `^[A-Z][0-9]{1,2}$`, belong to the chosen
  scope and appear only once. Anything else fails the gate: an unknown ID, an ID from another scope, a
  duplicate, lower case, a space, an empty item (`R3,,R9`, `R3,`) or three digits.
- **The gate records it**, so the build proves what it ran: `row_filter=`, `rows_selected=` and
  `rows_not_selected=` in `places/source-checkpoint.txt`, `metadata/places-row-filter.txt` (which
  every later stage reads), and a `places-row-filter` line in `summary.txt`. Without a filter it
  records `row_filter=none` and the metadata file is empty.
- **Only the selected rows run.** Each keeps its run, its order in that run and its device. A run
  with no selected row is skipped whole, including the recorded journey unless its row (R1) is
  selected. A filter with no row on the iPhone 17 Pro Max never boots it (§2).
- **Only the selected rows are judged.** The results count them alone as required; an execution of
  any other test is unexpected, which fails the verdict. PASS means every selected row passed. The
  verdict names each selected row (test, device, run) and lists the others as NOT PART OF THIS BUILD
  (not run, not judged, not reported as passed); so do the `places-ui-run` summary line, the top of
  the review page, a `README.txt` inside the review zip, and the screens and walkthrough READMEs. The
  recording is required only when the journey's row is selected.
- **Without the variable, nothing changes.** The rehearsal (§7) compared the unfiltered room scopes'
  results, verdicts, pages and command sequences with the earlier rehearsal's: identical.

## 2. One simulator at a time

The five room scopes never run two simulators together. `sequential_scope` in
`scripts/places_review.sh` covers `room`, `room_regression`, `room_regression_main`,
`room_regression_small` and `room_all`.

1. `destinations` boots only the selected iPhone 17 Pro Max. It records the smaller iPhone in
   `metadata/places-smaller.env` (the first installed of iPhone 17e, iPhone 16e, …) but does not boot
   it. Summary line: `places-smaller-boot deferred`.
2. `ui-review` compiles the harness and runs every main row in manifest order. There is no parallel
   lane, and no second copy of the build products.
3. Then it shuts the iPhone 17 Pro Max down and boots the smaller iPhone. This is its first boot,
   and nothing else is running. It waits for the boot status for up to 420 s (the other scopes wait
   240 s), then runs the smaller iPhone's rows.

**With no selected row on the iPhone 17 Pro Max** (`room_regression_small`, or a filter such as `C11`),
`main_idle` holds and the iPhone 17 Pro Max never runs:
- `destinations` does not boot it (it runs `simctl shutdown` on it, in case it is booting) and boots
  the smaller iPhone at once, alone, behind the compilation. Summary lines: `places-main-boot not
  booted` and `places-smaller-boot started now, alone`.
- `ui-review` shuts it down again before the harness compiles (`places-main-lane none`), never waits
  for its boot status, sets no status bar on it and runs no lane on it; then the smaller iPhone's
  segment waits for its boot status (already booted) and runs its rows.

With no selected row on the smaller iPhone (`room_regression_main`, or a filter such as `R3,R9`) the
smaller iPhone is neither recorded nor booted, as for a scope without smaller-iPhone rows.
Why:
- In recovery builds 4 and 5, two simulators on the host's three CPUs ran the main device about
  2.7–7× slower per step.
- One lane also needs no DerivedData copy.
- The cost is time: the two devices' tests add up instead of overlapping (§5).

## 3. The recording

- **R1 is recorded from before the app launches.** The app is terminated first. `simctl io
  recordVideo` must confirm "Recording started" before the test starts, and the moment it does is
  written to `places/recording-started.txt`.
- **The original is delivered unedited**, as `places/room-walkthrough-original.mp4` with its
  `.sha256`, inside `Room-walkthrough-original.zip`. No compact video is made on the Mac:
  `compact-video` reports NOT APPLICABLE for `room` and `room_all`, and the workflow has no such step.
- **The trim point.** The test prints `ROOM_WALKTHROUGH_START <epoch>` when Common Ground's
  explanation shows, before Preview room demo is tapped. The harness writes that value to
  `places/room-walkthrough-started.txt` (the summary line is `places-room-marker`). The VPS trims
  from `room-walkthrough-started.txt − recording-started.txt` seconds into the movie. Both values
  are the host's clock.
- The verdict, the review page and the walkthrough zip's README all state that offset.
- A missing marker is reported and does not fail the verdict: the recording is then kept whole.
- A trimmed copy made on the VPS is an edit of the original, not new evidence.

## 4. Flags, holds and allowances

- **Flags.** Every `xctest` run sets `TEST_RUNNER_PROXIMEET_ROOM_REVIEW=1` beside the seven earlier
  chapter flags. `RoomReviewTests` skips without it, and a skip fails the verdict.
  `scripts/places_review_results.py` reports `ROOM_REVIEW_FLAG_SEEN` among the flags seen.
- **The journey's flags.** In the room scopes the recorded journey sets
  `TEST_RUNNER_PROXIMEET_ROOM_REVIEW=1` as well as the Places flag. The other scopes' journeys are
  unchanged.
- **Holds.** Every run except R1 sets `TEST_RUNNER_PROXIMEET_SHORT_HOLDS=1`.
- **XCTest's execution allowance** is 600 s (maximum 660 s) in every room scope.
  - `room` and `room_all`: R2 makes about 27 launches. At the seven screens' measured pace
    (73.7–107.2 s for 7 launches) that is about 280–410 s, too close to the default 300 s for a hang
    guard.
  - `room_regression`, `room_regression_main` and `room_regression_small`: their rows were measured
    under 200 s, but P1 now takes two Room detours (about 10–20 s more, near 200 s), and build 4 once
    ended a test of about 145 s at the 300-s allowance while the host was slow.
  - The allowance is a hang guard; each run's bound and the UI deadline still cap every run.

## 5. Time

**The workflows.** The deadline arithmetic follows the Places workflows. At the worst, a build's limit
must hold 72 s (the gate's start) + the UI deadline + 75 (an interrupted run's grace) + 100 (its
export) + 45 (publishing) + about 20 (the Room zips):

| Workflow | Limit | `PLACES_UI_DEADLINE_SECONDS` | Worst case | Margin |
| --- | --- | --- | --- | --- |
| `proximeet-room-review-45` | 2700 s | 2340 | 72 + 2340 + 75 + 100 + 45 + 20 = **2652 s** | 48 s |
| `proximeet-room-review-35` | 2100 s | 1740 | 72 + 1740 + 75 + 100 + 45 + 20 = **2052 s** | 48 s |
| `proximeet-room-review-30` | 1800 s | 1440 | 72 + 1440 + 75 + 100 + 45 + 20 = **1752 s** | 48 s |
| `proximeet-room-review-25` | 1500 s | 1140 | 72 + 1140 + 75 + 100 + 45 + 20 = **1452 s** | 48 s |

The twins are the 45 with its name, its limit and its deadline changed, nothing else (checked by
parsing `codemagic.yaml`). The UI deadline counts from the gate's start (T0).

The Room zips store images and the movie uncompressed. The recording goes only into the walkthrough
zip, not into `Room-Review.zip`.

**Fixed costs** (measured):
- On Codemagic's Mac mini M2 (build 6aba3533): from the gate's T0 to the start of the UI review step
  about 130 s (app compilation 82 s, domain tests 34 s); then build-for-testing about 60–90 s. So the
  first test starts about 220–304 s after T0 on a device that booted behind the compilation.
- From the gate to the first test on a single simulator: 196 s in recovery build 6.
- A runner's start: 30–50 s (84 s for Places build 2's first main run).
- A run's close: about 15–30 s, and up to 145 s while another simulator was booting.
- The smaller iPhone's first boot with nothing else running: not measured (bounded at 420 s).

**The scopes** (UI time from T0; "tests" is the sum of the rows' measured test durations, from the
recovery's two-simulator builds):

| Scope | Estimate | 45 (2340) | 35 (1740) | 30 (1440) | 25 (1140) |
| --- | --- | --- | --- | --- | --- |
| `room` | Not measured (no Room test has run on a Mac). From the nearest measured tests: R1 250–400 s, R2 280–410 s, R3–R13 500–1000 s together, R14 100–160 s; about **1600–2400 s** | Likely; at the slow end R14, the last run, is left for time | No | No | No |
| `room_regression_main` | 220–304 (to the first test) + 1034 (tests: 666 + 368) + 45–80 (the second run's close and start) + 15–30 (the last close) = **1314–1448 s**, plus 10–20 s for P1's two Room detours: **about 1330–1470 s** | Yes, 870–1010 s spare | **Yes, 270–410 s spare (recommended)** | At the edge: −30 to +110 s | No |
| `room_regression_small` | 220–304 + 930 (tests: 614 + 253 + 63) + 90–160 (two more runs' close and start) + 15–30 = **1255–1424 s**; plus up to about 245 s if the smaller iPhone's first boot (started in destinations, alone, about 175–205 s before its boot status is read) runs to its 420-s bound: **about 1255–1670 s** | Yes, 670–1085 s spare | **Yes, 70–485 s spare (recommended)** | Only at the fast end | No |
| `room_regression` | 220–304 + 1964 (tests) + four runs' close and start (180–320) + the smaller iPhone's first boot after the main phone's runs (unmeasured, up to 420) + 15–30: **about 2400–3040 s** | No: split it into `room_regression_main` and `room_regression_small` | No | No | No |
| `room_all` | both: **about 3800–4900 s** | No | No | No | No |
| a filtered build | 220–304 s to the first test + the selected rows' tests + 45–80 s per further run + 15–30 s, plus up to 420 s for the smaller iPhone's first boot when it follows the main phone's runs (a smaller-iPhone-only filter boots it in destinations instead) | Choose the shortest twin whose deadline covers the worst case | | | |

Two worked filters:
- `room_regression` with `C11` (63 s measured): 220–304 + 63 + 15–30, plus up to 245 s of boot wait =
  about 300–640 s. The 25-minute twin (1140) fits.
- `room` with `R3,R14` (neither measured; R14 100–160 s, R3 guessed at 50–100 s): 220–304 + 50–100 +
  15–30 + the smaller iPhone's first boot after the main phone (up to 420) + 30–84 + 100–160 + 15–30 =
  up to about 1130 s. That is too close to the 25-minute twin's 1140; use the 30-minute twin.

**The budget** (4 builds, 150 billed minutes, every build at most 45 minutes, one simulator at a time).
Billed at each workflow's limit, the worst case of `room` on the 45, then `room_regression_main` and
`room_regression_small` on the 35, is 115 minutes for 3 builds, which leaves one build of at most 35
minutes (for example a filtered rerun on the 35, 30 or 25): 45 + 35 + 35 + 35 = 150.

- **A run that is still going at the deadline** is interrupted (SIGINT, so it can close its result
  bundle).
- **What that costs.** Its unfinished rows and every run not yet started fail the verdict, as "not
  run (time)". If fewer than 180 s are left after the main rows, the smaller iPhone's rows are
  listed as not run.

## 6. The source gate, the verdict and the downloads

**The source gate** (`checkpoint`) keeps every earlier check. It adds four:

- **The Room guard.**
  - Files: `Proximeet/Scenes/RoomView.swift` and
    `ProximeetDomain/Sources/ProximeetDomain/RoomDemo.swift` must exist. Every other `Room*.swift`
    under `Proximeet/` or `ProximeetDomain/Sources/` (`RoomComponents.swift`, or any later split) is
    guarded too.
  - Tokens: none of these files may contain any of the Places guard's tokens. `URLSession`, `print(`
    and `Timer` are among them; the Room's list names them again. It adds the Signal guard's
    `verified`, `Verified`, `presence`, `Presence` and `checkIn`, which the Room's view was written
    against (the Places list has only `isVerified` and `checkedIn`).
  - This covers clocks, calendars, locales, location, the camera, scanners, the network,
    persistence, logging, timers, and the visible, present, checked-in, member and verified tokens.
  - `isPresent` matches `.sheet(isPresented:)`, so the Room has no `isPresented` sheet.
- **The Room handoff copy.**
  - `docs/design/room-approved/` holds `reference/room-review.png`,
    `reference/common-ground-delivery.png`, `README.md`, `DESIGN_NOTES.md`, `CLAUDE_PROMPT.md` and
    `fixtures/ROOM_DEMO_CONTRACT.json`.
  - Each must equal the handoff's own `SHA256SUMS.txt`, which is copied beside them.
  - Nothing else may be in the folder.
  - That record's `assets/common-ground.png`, `fonts/OFL.txt` and Manrope faces must equal the
    Places record: the Room reuses the Places scene and the bundled fonts, so no new asset is added.
  - `scripts/places_source_manifests.py` lists the folder with the approved handoff copies.
- **The deadline range**, 600 to 2340.
- **The row filter** (§1.1): `PLACES_ROW_FILTER`, when set, must name rows of the scope, each once,
  each matching `^[A-Z][0-9]{1,2}$`. The gate records `row_filter=` (`none` without one) and, with
  one, `rows_selected=` and `rows_not_selected=`.

As before, the manifests are written last, after every edit (`python3
scripts/places_source_manifests.py`).

**The verdict** requires everything the Places verdict does:
- the gate;
- the scope;
- the iPhone 17 Pro Max selected;
- the app build;
- the domain tests;
- the harness build;
- every required row: executed once, on its device, passed, and its run exited 0.

`room` and `room_all` also require a confirmed, non-empty recording, unless a row filter leaves out
the journey's row (R1).

With a row filter it requires only the selected rows, and also that the gate's recorded filter, the
filter the stages read and the filter the results judged are the same. Its first line, its row-filter
block and its last line name the selected rows and say the others were not part of the build.

Reported, not required:
- the marker and its offset;
- the app zip;
- that no compact video and no preview copy are made.

The manual review it lists as outstanding:
- visual approval against the board, which does not show the report, Wave and profile-safety
  overlays;
- VoiceOver (escape, modal panels, focus);
- the system Reduce Motion setting and larger text on a device;
- on-device motion;
- other orientations.

**The downloads** (each archive with a `.sha256` beside it):

| File | Scope | What it holds |
| --- | --- | --- |
| `Room-Review.zip` | room | An offline `index.html` (details below) |
| `Room-Screens.zip` | room | Every capture, as `Room-journey-NN-<step>-XCTest-REAL-JOURNEY.png` (in the order taken) or `Room-NN-<state>-…-XCTest-FIXTURE-direct-launch.png` (by state in the approved flow's order), with a README and the tests' notes |
| `Room-walkthrough-original.zip` | room | `Room-walkthrough-original.mp4`, unedited, and a README with the recording's facts and the trim offset |
| `Proximeet-Debug-iphonesimulator-<sha12>.zip` | every scope | The unsigned simulator app from `codemagic_verify.sh package`, under its own name in `build/artifacts/app/` and inside the review zip |
| `Room-Regression-Review.zip` | room_regression | The generic Places page: every capture, every execution by row with the row it reruns, the manifest rows, the verdict and the logs |
| `Room-Regression-Main-Review.zip` | room_regression_main | The same page for its 12 iPhone 17 Pro Max rows |
| `Room-Regression-Small-Review.zip` | room_regression_small | The same page for its 11 smaller-iPhone rows |
| `Room-All-Review.zip`, `Room-All-Screens.zip`, `Room-All-walkthrough-original.zip` | room_all | As `room`'s, with the Places rows' captures (`Places-rows-*`) and executions after the Room's |

`Room-Review.zip`'s `index.html` shows, in order:
- the approved board;
- the Common Ground delivery;
- the recorded journey's facts;
- every Room capture, grouped by the state it shows (entry, waiting, People, Room notes, profiles,
  safety panels, the report preview, Wave information, ended, back in Places). Each state sets the
  board's frame for it beside the captures, and each caption says REAL JOURNEY or FIXTURE;
- the manifest rows;
- every execution with its outcome;
- every test;
- the tests' notes;
- the verdict;
- the logs and results;
- the approved handoff documents;
- a `SHA256SUMS.txt` of every file inside.

A relative link that names no packed file fails the stage.

A filtered build's archives say so: the review page opens with the filter (the selected rows and the
rows that were not part of the build), the review zip holds a `README.txt` with the same statement
and the verdict's last line (and, on the Room pages, is listed in `SHA256SUMS.txt`), and every screens
or walkthrough README starts with it. A `room` or `room_all` build whose filter leaves out R1 makes no
walkthrough zip; the page says the journey was not part of the build. An unfiltered build's archives
are exactly as before.

The workflow also publishes:
- `summary.txt`;
- `logs/*.log`;
- `metadata/*`;
- `app/*`;
- `places/*.{sha256,log,txt,tsv,json}`, which includes `room-walkthrough-started.txt` and
  `recording-started.txt`.

## 7. Rehearsal on the VPS (stubs, not evidence)

The rig is `scratchpad/room/hdry-room`, adapted from the Places rig. `run.sh` runs every stage
after the checkpoint with bash 3.2.57 on a copy of a repository snapshot, never on the worktree.
The stubs name the Room's captures as the contract does, skip `RoomReviewTests` unless its flag is
set, and print `ROOM_WALKTHROUGH_START`. The checkpoint was rehearsed separately on a snapshot
turned into a fresh git repository, with its manifests written there.

**Rehearsal results:**
- `room`, `room_regression` and `room_all` each passed every stage (14, 23 and 37 executions).
- Each device ran only after the other: boot main, main's runs, shut main down, boot the smaller
  iPhone, its runs.
- Every link resolved (141, 137 and 250 links). The stubs used the capture names in
  `RoomReviewTests.swift` as drafted, and every one was filed under the state it shows.
- A failed Room test, a missing marker, the deadline cutting a run, and the smaller iPhone's runner
  failing to initialize (one infrastructure rerun) each behaved as described.
- The gate caught a forbidden token in `RoomView.swift` and in a `RoomComponents.swift`, a missing
  `RoomView.swift`, an edited or extra handoff file, a deadline of 2341 and an unknown scope. It
  also caught `verified` in `RoomView.swift`, `presence` in `RoomDemo.swift` and `print(` in a split
  `Proximeet/Scenes/RoomPanels.swift`.
- The `places`, `correction` and `regression_finish` scopes still behaved as before.

**The split scopes and the row filter** were rehearsed with a second rig, `scratchpad/room/hdry-room2`.
Its `run2.sh` runs the real source gate on a hard-linked copy of a snapshot turned into a fresh git
repository (manifests written there; `make-snapshot.sh` rebuilds it), then every later stage of the
Room workflow with the same stubs and bash 3.2.57. Its `run-old.sh` is the first rig's `run.sh` pointed
at the same snapshot.

- **The gate** (20 cases): it accepted no filter and `R3,R14` (room), `C11` (room_regression),
  `C1,C8` (room_regression_main), `C15,C11` (room_regression_small) and `R1,C11` (room_all), recording
  each. It rejected 14: unknown IDs (`R99`, `R15`); IDs from another scope (`C11` for room, `C1` for
  room_regression_small, `C11` for room_regression_main, `R1` for room_regression); duplicates
  (`R3,R9,R3`, `C11,C11`); and `r3`, `R3, R9`, `R3,,R9`, `R3,`, `R100` and `RR3`. A rejected filter
  leaves no metadata record, and the later stages refuse to test.
- **`room_regression_main`**: every stage passed; 12 of 12 executions, all on the iPhone 17 Pro Max;
  the smaller iPhone was never booted; 78 links resolved in `Room-Regression-Main-Review.zip`.
- **`room_regression_small`**: every stage passed; 11 of 11 executions on the smaller iPhone. The iPhone
  17 Pro Max was never booted or awaited (shut down in destinations and again in ui-review; no boot
  status read); the smaller iPhone booted in destinations. 84 links resolved in
  `Room-Regression-Small-Review.zip`.
- **`room` with `R3,R14`**: every stage passed; 2 executions (R3 in `room_main` on the iPhone 17 Pro
  Max, then R14 in `room_small` on the smaller iPhone); no journey, no recorder, no `room_capture`
  run; no walkthrough zip. The verdict, the summary, the page and the READMEs name R3 and R14 and list
  the other 12 as not part of the build. 58 links resolved.
- **`room_regression` with `C11`**: every stage passed; 1 execution, in `rr_correction_small_b` on the
  smaller iPhone; the iPhone 17 Pro Max was never booted. The other 22 rows are listed as not part of
  the build. 31 links resolved.
- **Failure and edge cases**: with R3 failing under `R3,R14`, the verdict was FAIL, R14 was reported
  as passed and no unselected row appeared anywhere as passed. `R1` alone recorded the journey and
  required the recording (PASS); with the marker suppressed it still passed, reporting the marker as
  NOT FOUND. A filter record changed after the gate (`R3` to `R3,R4`) failed the verdict on the new
  gate-consistency requirement. `room_all` with `R1,C11` recorded R1 on the iPhone 17 Pro Max, then
  ran C11 on the smaller iPhone, and passed.
- **Unchanged without a filter**: `room`, `room_regression` and `room_all` passed every stage again
  (14, 23 and 37 executions; 141, 137 and 250 links), through the real gate and through `run-old.sh`.
  Against the first rig's final runs their results, verdicts, summaries, runs, manifest rows, zip
  listings, pages and simctl/xcodebuild command sequences are identical, apart from timestamps and
  the XCTest allowance of `room_regression` (now 600 s, §4). `places`, `correction`,
  `regression_finish` and `sweep_finish` differ only in timing noise and in what `git diff` reports
  (the first rig's snapshot had no `.git`).

None of this shows that the Room compiles, that its tests pass, or how long they take on a Mac. Those
are PENDING the first build.
