# Signal — regression correction after build 6ab7ee20

One more manual, unsigned Codemagic build is meant to close Signal's open regression checks. It uses the
`regressions` scope of `proximeet-signal-review` (workflow limit 28 minutes). The branch starts from
`1085af3d7be62ef3fc463016446aa87c76b976f3` (`signal/approved-20260926T131402Z`).

The authorisation covers exactly one build, at most 30 free Mac mini M2 minutes. No signing,
Apple, TestFlight, publishing or Places.

Two revisions stay separate:

- **The `signal` scope** ran at `1085af3d`, in build `6ab7e9420cb984b7efbcbded` (PASS, 14 unique
  tests / 16 executions). It is **not** re-run. Its screens and videos keep that SHA.
- **The `regressions` scope** runs at the correction's own full SHA. The build pins it with
  `SIGNAL_EXPECTED_COMMIT`, and the source gate records it. For the product files that did not
  change, equivalence is by source (see
  `docs/verification/signal-regressions-recovery-source-comparison.txt`). That does not mean the
  signal scope's tests ran on this commit.

## 1. What build 6ab7ee20 showed

The host was an Apple M2 (Virtual), running Xcode 26.6 (17F113) with iOS 26.5 (23F77) simulators.
Two lanes ran in parallel: the selected iPhone 17 Pro Max, and device B, a clone of it.
Automatic retries were on (`-retry-tests-on-failure -test-iterations 2`).

| check | what the logs and attachments show |
| --- | --- |
| `GuestListReviewTests.testOpenerLimitBoundariesAndPreservedPaste` | failed 2 of 2 attempts at `GuestListReviewTests.swift:847` ("The paste arrived in guestList.opener") |
| `WristbandReviewTests.testWalkthroughRouteChoicesBackReentryEndpoint` | started at 16:28:40, 66 s before the main lane's 1000 s bound ended xcodebuild (SIGALRM, exit 142); never finished |
| `BirthdayReviewTests.testWalkthroughEntryCorrectionContinueBack` | attempt 1 failed at `:94`: the short Month drag left the wheel on "January"; attempt 2 (the automatic retry) passed |

When the bound ended the main lane, `RegressionsMain.xcresult` was lost ("Info.plist … does not
exist"). None of that lane's screenshots survived.

### The paste

The failing attempts are compared with the passing ones: every other paste on this host and in
build 6ab78983 (M2 Pro host), taken from the logs:

- **In both failing attempts, the first delete pass left text.** The helper tapped the field's end
  at (0.95, 0.85) and typed 332 deletes for 120 characters. A second pass, starting with a tap at
  the left edge (0.05, 0.85), then emptied the field; the "is empty" assertion passed. The same
  thing happened on this host to the Latin name "  Zoë Ødegård-Nakamura ". It never happened to a
  left-to-right text in build 6ab78983.
- **After such a left-edge pass, the tap meant to open the edit menu opened none within 3 s** in 3
  of 4 cases (both opener attempts, name 2). The menu did appear after the Arabic name's left-edge
  pass. It appeared after every paste that needed only one pass.
- **The ⌘V fallback landed once (name 2) and failed twice (the opener).** In the opener attempts,
  the element tree at the failure shows the field keyboard-focused, empty ("0 of 120 characters"),
  and no alert. The keyboard area grew by 34 pt after ⌘V.
- **What is not established:** why the deletes left text (dropped keystrokes or caret placement),
  and why the menu did not open. That the host's speed is the cause remains a hypothesis. No app
  defect is established either. The field kept focus and took the delete key. The opener is a
  plain `TextField(axis: .vertical)` with `.lineLimit(2...6)` bound to the session, with nothing
  that intercepts a paste. So no product file changes.

**The fix is in the harness only** (`GuestListReviewTests.paste`). It keeps a real edit-menu
paste and every content, length and Unicode assertion. The steps:

1. The fictional payload is set, then read back from the pasteboard by the test runner that wrote
   it (change count, `hasStrings`, exact string; at most 5 s).
2. The helper waits for focus, the keyboard, and a still field. The field's frame must read the
   same three times, 0.25 s apart.
3. The field is emptied from the end of its text: the right edge, or the left only for
   right-to-left text. It is read back after every pass, at most four passes. A left-to-right text
   never gets the left-edge tap that preceded every missing menu.
4. The edit menu is opened by one tap on the still, empty field. If no menu appears within 5 s,
   the screen and the element tree are attached and one press-and-hold follows, which opens the
   menu on release. A second tap is never used, because it would close a menu that arrived late.
   A menu that is already open is used as it is.
5. The menu's Paste is tapped exactly once. There is no ⌘V fallback any more, so a late first paste
   and a fallback can never insert the payload twice. The paste tests also no longer send hardware
   key events.
6. The field must then hold exactly the payload within 10 s. An "Allow Paste" prompt that actually
   appears, in the app or on SpringBoard, is answered by its button (noted and captured), never by
   coordinates. The field must still hold the payload a moment later.

Every step is noted with its time. Any failure attaches the screen and the element tree.

The paste now fails if no menu opens, rather than trying ⌘V. That is deliberate: a longer timeout
alone is not a fix, and the edit menu is the real paste. Only the Mac run can show whether the
change works.

### The Wristband walkthrough

xcodebuild runs a run's tests class by class and name by name. The walkthrough was the last of 17
tests in one bounded run. That run started cold: 207 s passed before its first test. It also
included a 101 s failed Birthday attempt and its retry.

### The Month drag

The drag moves the unset Month wheel 20 pt, less than half a row: the rows are 47–53 pt apart on
screen. It then holds 0.3 s and lifts. The downloaded logs hold 10 recorded attempts in 9 builds,
and 2 failed:

- Guest List build 6ab74794 left the wheel on March.
- Build 6ab7ee20 left it on January.

Both are plain M2 hosts; 6 other attempts on plain M2 hosts passed. A wheel three rows along the
drag, or even one, after a 20-pt placement means it was flung: it still carried speed when the
finger lifted. The logs show no timing difference between passing and failing attempts, so the
host remains a hypothesis here too.

**The fix is in the harness only** (`BirthdayReviewTests`). The distance (20 pt), the speed
(`.slow`) and the expected result (Not set, no neighbours drawn, clean edges) are unchanged, and
nothing is retried:

- **Starting state.** Before the drag, every wheel must be seen at rest: two screenshots in a row
  light the same pixels in each wheel's column, at two thresholds, within 6 s. The Month wheel must
  read "Not set" and draw its placeholder alone. The screen is captured
  (`birthday-before-month-drag`).
- **Positioning.** The drag starts on the Month lane: the middle wheel's centre, on the date
  window's centre line. Both frames are noted.
- **Release.** The finger rests 0.8 s instead of 0.3 s before it lifts, so the release carries no
  speed.
- **Result.** The result is read only after the wheels are seen at rest again. The time the gesture
  took is noted, as evidence of any stall in event delivery.

### The lane deadline

The 1000 s bound on the main lane was the immediate cause. A single longer bound would not have
been enough, and it would have eaten the time needed for the result bundle and the package.

## 2. The correction

| file | change |
| --- | --- |
| `ProximeetUITests/GuestListReviewTests.swift` | the paste helper above; `waitForFocus` takes an optional timeout; the hardware-key test's comment |
| `ProximeetUITests/BirthdayReviewTests.swift` | the Month drag above (`waitForWheelsAtRest`, `monthLane`) |
| `scripts/signal_review.sh` | regressions scope only; details below |
| `scripts/signal_regressions_results.py` | new: judges every execution against the manifest |
| `scripts/signal_regression_recovery.py` | new: `Signal-Regression-Recovery.zip` |
| `docs/verification/signal-regressions-recovery-manifest.tsv` | new: the correction's test manifest |
| `docs/verification/signal-regressions-original-manifest.txt` | new: build 6ab7ee20's manifest, verbatim |
| `docs/verification/signal-regressions-recovery-source-comparison.txt` | new: every difference from `1085af3d` |
| `codemagic.yaml` | two step names; the recovery zip and its checksum as artifacts |
| `docs/verification/signal-mac-review.md`, this report, the source-gate manifest | documentation and the regenerated gate |

The `signal_review.sh` changes, regressions scope only:

- No automatic retries.
- Runs, order, devices and bundles come from the manifest.
- A time-gated repeat of the paste test.
- A graceful bound that interrupts rather than kills.
- An earlier deadline, and the new parser and package.

Nothing changes in the app, its assets, fonts or project, or in the domain package. The signal
scope's lanes, retries, deadline, parse and package are unchanged.

**Nothing is compiled twice.** The `build` step compiles the app. `build-for-testing` compiles
only the 10 UI-test sources: its log in build 6ab7ee20 lists `SwiftCompile` only for target
`ProximeetUITests`. Device B runs from an APFS clone of those products. Every test run is
`test-without-building`. The regressions scope records no video, so nothing is encoded.

## 3. The manifest

`docs/verification/signal-regressions-recovery-manifest.tsv` is the single source. The script
builds each run's `-only-testing` list from it, and the parser judges each row against the logs.

| device | runs, in order |
| --- | --- |
| selected iPhone 17 Pro Max | `main_early`: Birthday walkthrough, Wristband walkthrough · `main_rest`: Birthday typed entry, Pass (4), Wristband (6) |
| device B (its clone) | `paste_b`: the opener paste test · `regressions_b`: the Guest List on-screen-keyboard tests (7), the names test, Welcome (4) · `paste_repeat_b`: the paste test again (planned repeat, time-gated) · `hardware_keys_b`: the hardware Tab test |

- **Coverage.** The same 27 required tests as build 6ab7ee20: 17 on the selected simulator, 10 on
  device B. Of these, 23 run on the same device as before. The four Welcome tests moved to device B
  (the same model and runtime) to balance the lanes. Nothing is omitted, renamed or substituted.
- **Order.** The checks that failed or never ran come first on their devices.
- **The repeat.** It is disclosed as a repeat, not a unique test and not a retry. It runs only while
  at least 300 s are left, which covers it and the required hardware-key run after it at their
  worst measured overheads. If it runs, it must pass. By the estimates below it will usually not
  fit, and it is then recorded as not run for time.
- **The hardware-key test** is last on device B because hardware key events can leave the simulator
  without its on-screen keyboard.

## 4. Time, planned from the plain M2 host of build 6ab7ee20

Two figures from that build:

- The source gate starts 47–58 s into a build.
- The lanes start about 178 s after the gate (compile, domain tests, UI-test compile, boots,
  clone).

Three more figures, measured on this host type:

- **Cold start.** The selected simulator's first xcodebuild reaches its first test about 207 s after
  it starts (6ab7ee20; build 6ab7e942's lane start shows the same stall of about 3 minutes). Device
  B's first xcodebuild takes about 97 s.
- **Warm start.** A warm xcodebuild takes about 20–25 s, including the previous run's export.
- **Close.** After its last test, xcodebuild needs 13–57 s to close its result bundle: 33.5 s twice
  in 6ab7ee20, up to 56.7 s in 6ab7e2b4.

Each extra run therefore costs about a minute. Two runs are extra: the separate run that puts the
walkthroughs first, and the paste test's own run.

| lane | work | estimate |
| --- | --- | --- |
| selected iPhone | cold ≈ 207 s, the two walkthroughs ≈ 300 s, close ≈ 34–57 s, warm ≈ 22 s, the rest ≈ 485 s, close | ≈ 1090–1140 s |
| device B | cold ≈ 97 s, paste ≈ 80 s, close, warm, on-screen tests with the names test and Welcome ≈ 695 s, close, warm, hardware-key run ≈ 23 s, close | ≈ 1050–1130 s without the repeat |

So the lanes end about 1230–1320 s after the gate. The UI deadline is 1410 s, so the margin is
90–180 s. These are estimates; the Mac run is the measurement.

At the deadline, a running xcodebuild gets SIGINT, which is how it closes its result bundle. After
75 s it gets SIGKILL. Then come:

- the export (at most 60 s);
- the verdict and the recovery package, which run whether the review passed or not;
- publishing.

In build 6ab7ee20 everything after the UI review took 8 s. So even at the worst,
58 + 1410 + 75 + 60 + about 30 s is about 1633 s, or 27:15.

## 5. The verdict and the download

A **required execution** passes only if its run executed it exactly once and it passed. A failure,
a skip, an interruption, a missing execution, a second execution in one run, or a run exit other
than 0 is a FAIL. So is a repeat that runs and does not pass.

- **Infrastructure reruns** (exit 70, no test ran) are listed separately.
- **Retries** are off, so none are reported.
- **Unique cases and executions** are counted apart, as are first attempts and retries.

`Signal-Regression-Recovery.zip` is published as a build artifact, with its SHA-256 beside it. It
holds an offline `index.html` whose links are all checked against the archive, and:

- the source gate's record, the source comparison, and git's own diff on the build machine;
- both manifests and their comparison;
- every execution;
- the raw `.xcresult` bundles and xcresulttool JSON;
- the failure evidence, every screenshot and note, and the logs;
- `SHA256SUMS.txt`.

It also points to the signal scope's downloads on build 6ab7e942, each named with its SHA-256.

## 6. Local checks before the dispatch (Linux)

- **Syntax.** `bash -n` passes with bash 5 and with a bash 3.2.57 build, and the Python scripts
  compile.
- **The graceful bound**, tested with real processes:
  - normal exits;
  - a command that honours SIGINT;
  - one that ignores it (killed after the grace);
  - the device-B background-lane shape;
  - signals forwarded to the wrapper.
- **The parser against the real logs of build 6ab7ee20.** It reports exactly that build's
  failures: the walkthrough interrupted, the Birthday test failed and then passed (two executions,
  not a pass), the paste failed twice, exits 65 and 142.
- **Dry runs of parse, verdict and package** on synthetic lane logs: all pass; one failure; the
  repeat left unrun for time. Links were checked, with 0 broken.
- **Swift.** The two changed UI-test files type-check against the Linux XCUITest shim with the same
  compiler (Swift 6.3.3, Swift 5 mode, strict concurrency complete), with no diagnostic beyond the
  baseline's. This is an approximation of Apple's SDK, not a compilation.
- **Domain tests.** `swift test --package-path ProximeetDomain`: 154 tests, 0 failures.
- **The source gate** (`checkpoint`) runs locally on the committed tree.

## 7. Still open

These stay open whatever this build shows:

- visual approval of Signal (its captures have not yet been inspected by the lead);
- VoiceOver;
- the system Reduce Motion setting;
- composing keyboards;
- real-device checks, including motion smoothness.
