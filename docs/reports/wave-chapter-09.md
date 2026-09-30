# Wave chapter 09: implementation and native-verification preparation

Date: 2026-09-30. Not production-ready.

**Status:** implemented in source on an isolated local branch and checked on Linux. **Native compilation,
simulator runs, VoiceOver, system Reduce Motion, motion quality and device behaviour have not been run.**
No push, CI, Codemagic, Apple configuration, upload or signing change was made. The Xcode Cloud run scope
for Wave is a proposal awaiting the founder's authorization (§5). Nothing here is founder visual approval
of the native Wave, and nothing here says the Wave's automated checks passed: they have never run.

## 1. Baseline and provenance

| | |
| --- | --- |
| Base | Verified Room commit `1a5f97e0fe73168e5f63e392182507e457209964` on `origin/room-repair/xcode-checks-20260930` (= the Room repair candidate `062ea35` + three commits: distinct journey inputs in three UI tests, and the local-package reference that lets Xcode discover `ProximeetDomainTests`) |
| Wave branch | `wave/approved-20260930T173856Z`, worktree `/home/proximeet/proximeet-cloud-wave-20260930T173856Z`, created with `git worktree add` from `1a5f97e`; one local commit, not pushed |
| Not used as base | `testflight/internal-20260928` (still `67bf1a9`, per the current instructions); `redesign/social-objects`; `origin/verification/room-d2-1a5f97e-20260930` (a CI-only branch whose `.github/workflows` file would fail validator check 11) |
| Verified Room outcome (read from GitHub check runs on `1a5f97e`, not from the repository, whose Room report still shows the earlier pending status) | RoomVerificationMain success 14:51–15:42 UTC; RoomVerificationSmall success 14:51–15:17 UTC; Proximeet TestFlight Archive success 16:16–16:22 UTC (all 30 September). The "247 checks" and the delivered 0.1.0 (7) are the founder's figures |
| Handoff | The prompt's `Proximeet-Wave-Implementation-20260930.zip` is not on this machine. The complete approved handoff was taken from the master `PROXIMEET_ALL_TEN_APPROVED_HANDOFFS.zip` (SHA-256 `365df942…117f7`; its `SHA256SUMS.txt` 13 of 13 OK): `chapters/09-wave/PROXIMEET_WAVE_APPROVED_HANDOFF.zip`, SHA-256 `ecc5667d…6e106` (matches `HANDOFF_INDEX.json` order 9); inner `SHA256SUMS.txt` 23 of 23 OK, no unlisted files. A second extracted copy on the VPS is byte-identical |
| Handoff copy in the repository | `docs/design/wave-approved/`: README, DESIGN_NOTES, CLAUDE_PROMPT, `fixtures/WAVE_DEMO_CONTRACT.json`, the two reference boards and the handoff's own `SHA256SUMS.txt` (6 of the copied files match it; the art, fonts, specs and validation are not copied), exactly as the Room's `docs/design/room-approved/`. The source gate (`scripts/places_source_manifests.py`) now lists it with the approved files |
| Figma | page 74:567, review 76:387, approval annotation 84:498; founder "approve" 24 September 2026 22:31:36 PDT |

**Dependency evidence (read in source at `1a5f97e`).** Welcome ("More options" → "Continue the demo (no
account)" → `session.begin()`), Birthday (wheel and typed input; `continueFromBirthday(today:)` re-checks an
injected civil date), Pass (intro → progress → complete), Guest List (real text fields bound to the draft
introduction), Wristband (`chooseIntent`), Signal (`chooseApproach`; Places needs both), Places (fixed
snapshot "Fictional venues · demo Thursday, 8 pm"; eligibility = intent match and open), and Room (entry and
populated gates, one central blocked set, local unsent reports, terminal Leave, Return to Places at Now)
all exist and are wired as approved. There is no stable viewer ID in the code; the Wave uses the single
`WaveParticipant.viewer` identity and reads the actual Guest List name once when the Wave opens.

**Assets and fonts.** No new art or fonts. The handoff's `assets/common-ground.png` (1254 × 1254 RGBA) is
byte-identical to `Proximeet/Resources/Assets.xcassets/PlaceCommonGround.imageset/common-ground.png`, used
through `PlacesArt` with the approved crop [46, 83, 1211, 1218]; the five static Manrope faces and
`OFL.txt` are byte-identical to the bundled `Manrope-*.dataset` files (the handoff's variable face is not
needed). The rings are native ellipse strokes; no image, screenshot UI or effect was added. No envelope or
clasp concept, no ring-reflection experiment, no regenerated art, no font change.

## 2. What was implemented

- **Domain** (`ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift`, new; `RoomDemo.swift`, integration):
  - `WaveDemo` lives inside the Room run that opened it (`RoomRun.wave`), so the Wave shares the run's identity,
    populated phase and its one central blocked set, and one Leave ends both.
  - Invitations are typed values with an immutable ID (`WaveInvitationID(run, sequence)`, issued per explicit start,
    never reused), Room run ID, sender, recipient, venue, intent, direction and a single `status`; no `isSent` or
    `isAccepted` flags. Self-addressed or foreign-run invitations are rejected at construction.
  - Every action (`RoomRun.perform(WaveAction)`) re-reads central eligibility at action time: the run is active and
    populated, the counterpart is unblocked and shares the viewer's intent, and the venue is Common Ground. Stale
    and repeated handles (an old invitation ID, a screen, an overlay kind) change nothing.
  - Acceptance validates the contract's nine guards atomically (same Wave ID, same run, pending, viewer is the
    recipient, sender differs, run populated and active, same venue, same intent, no block or invalidation).
    There is no sender-facing Accept anywhere.
  - Withdraw, decline, sender-withdrawn, expired, block and Leave close the invitation; a closed invitation never
    changes again and is kept, append-only, for the life of the run (`RoomRun.closedInvitations`).
  - "Show no-allowance example" is an explicit demo condition with no Send action; there is no count, quota,
    refill, refund, cooldown or timer.
  - A Wave block writes the same central set: Maya loses her card and profile; Jules also loses his public
    note; the other sample's note is unchanged. A new example after a block shows "Connection blocked." and
    never unblocks, and no menu control can revive an ended run.
- **Session** (`DemoSession`): `openWaveDemo(_:)` (reads the actual Guest List name once, trimmed),
  `performWave(_:_:)` and `wave`, all through the existing run-ID-guarded `updateRoomRun`.
- **Room integration** (`RoomView.swift`): the same-intent profile action is now "Preview Wave demo" (hint "Opens
  a fictional Wave demo. Nothing is sent.") and opens the Wave menu with that sample as the counterpart; the other
  intent keeps "Back to people" and the same-intent explanation. When the run carries a Wave, the Room page is
  replaced by `WaveView`. Room's former Wave-information panel (66:134) has no entry point any more and is
  removed with its fixture and tests (Room's reachable overlays go from 8 to 7).
- **View** (`Proximeet/Scenes/WaveView.swift`, new): all 12 screens, 7 overlays and 4 report-reason variants,
  built from the live Room system (buttons, headline, labels, chrome, ticket layout, reason rows, tokens) with
  Wave's measured sizes where they differ; native ellipse rings; accessibility identifiers `wave.*` and
  `wavePanel.*`. The join is the only 800-ms ease-out move and runs only after a valid recipient acceptance has
  been committed; every other change is a 240-ms ease-out dissolve; with Reduce Motion the rings take their
  joined pose without the move.
- **Fixtures** (DEBUG only): `-ProximeetFixture wave-*` for every screen, with `-ProximeetWavePanel`,
  `-ProximeetWaveReason`, `-ProximeetWaveFrom`, `-ProximeetWaveAfterBlock`, `-ProximeetRoomBlocked` and
  `-ProximeetFixtureName`; each state is reached only through the actions a guest would take.

**The 12 screens** (Figma key = `WaveScreen` raw value; the DEBUG fixture is `wave-<key>`, except the menu's,
`wave-menu`): `demo-menu`, `out-confirm`, `out-pending`, `out-withdrawn`, `in-review`, `in-declined`,
`in-accepted`, `in-withdrawn`, `unavailable`, `blocked`, `allowance-unavailable`, `session-ended`. **The 7 overlays:** global safety, counterpart safety,
the report preview (no reason, and the three reasons: 4 variants), private-chat information, demo conditions.

**Integration behaviour, by contract clause, with the evidence that exists today:**

| Clause | Where it holds | Linux evidence | Native row (not run) |
| --- | --- | --- | --- |
| Entry only from an eligible profile's "Preview Wave demo", carrying the actual name, intent and approach; Social → unblocked Maya, Business → unblocked Jules | `RoomRun.openWaveDemo`, `DemoSession.openWaveDemo`, `RoomView` profile action | domain tests | W1, W2, W3, W13 |
| Shares the Room run identity, populated state and the one blocked set | `RoomRun.wave` | domain tests | W8 |
| Two independent immutable invitations; outgoing never accepts itself; only the valid pending recipient accepts | `WaveInvitation`, `acceptanceRefusal` | domain tests, including a randomised sequence test | W6 |
| Duplicate or stale actions, withdraw, decline, block, expiry or Room end never create acceptance | `RoomRun.perform` | domain tests | W5, W7 |
| Commit state before decoration; Block and Leave interrupt the join | `WaveView` (state first, animation after; block and Leave replace the page) | app type-check only | W7, W9, W12 |
| Menu resets never clear blocks or revive an ended Room | `RoomRun.perform`, `isConsistent` | domain tests | W8, W9 |
| Leave ends Room and Wave at once; Return to Places opens the actual Now with choices and the draft kept | `RoomRun.leave`, existing Places return | domain tests | W1, W9 |
| Report is an unsent local preview | `WaveOverlay.report` | domain tests | W4, W11b |
| No send, chat, notification, backend, timer or numeric allowance | the sources | validator check 11 (with the new Wave-only scan) and `DomainSourceGuardTests` | D2 |

## 3. Design comparison with the current Room, and decisions

Wave extends the Room system rather than replacing it:
- **Reused unchanged:** header (Wave 75:111/119/130 = Room 67:111/119/130), DEMO badge, shield and chevron,
  compact venue ticket (its third line now also carries the viewer's name), report panel and its four reason
  variants (Wave 75:627–657 = Room 67:816–846), button family (filled 60/56/52, outlined 56/52/48/44, radius 18,
  SemiBold 16), the 72 % dim with modal panels, the status-bar ground strip and the rule that no bar is built under
  an overlay.
- **New to the system, from the approved measurements:** the brushed-metal rings; the invitation card; the demo
  menu; the closed invitation paper (back sheet 264 × 136 tilted 3°, front 288 × 135, seal 60 × 34, which differ
  from Room's envelope); the Bold 14/24 context row; the centred ExtraBold 28/40 invitation title in ink;
  Regular 16/25 closed explanations; 30/38 panel titles; the demo-conditions panels; the 800-ms join.
- **Colour:** every Wave colour except the ring metal is an existing Room token; no intent colour decorates the
  Wave (the design notes' "Social coral" appears on no Wave node).
- **To access Room's components,** file-scope `private` types in `RoomView.swift` were made internal (access level
  only). Three Room components that hard-code Room identifiers or copy got Wave variants instead (ticket, DEMO
  badge, envelope).

Decisions where the handoff is silent (each is a recorded deviation or choice, not a founder approval):
1. **Room's Wave-information panel removed.** The handoff turns the profile's information action into "Preview Wave
   demo"; the panel it opened (66:134, including the approved line "Sending Waves comes in the next preview.") has
   no entry point, so it is removed.
2. **Back from the menu.** The design has no route from the Wave menu back to the Room. A back swipe or
   VoiceOver escape on the menu returns to the Room profile (or to filtered People if the counterpart is blocked);
   no visible control is added. Out-confirm's designed Back returns to the menu; closed screens' outer Back returns
   to the menu; pending, review and accepted have no outer Back; the ended screen's outer Back goes to Places, as
   Room's does.
3. **Blocked counterpart and new examples.** All three menu starts show the approved "Connection blocked." (74:576).
4. **Leave inside the Wave** shows the Wave's ended screen (74:578); Leave from the plain Room still shows Room's.
5. **Closed invitations** are kept in memory for the run's life.
6. **Panel Close** uses Room's 240-ms dissolve (Figma CLOSE carries no transition).
7. **Invitation preference line** shows the counterpart's own intent and approach; the header ticket shows the
   viewer's name, intent and approach. Different approaches are allowed.
8. **Uppercase name lines** ("OUTGOING · YOU ARE {NAME}") read in sentence case to VoiceOver. A guest whose
   Guest List name equals the counterpart's (case-insensitively) is written "YOU" in the direction line
   ("MAYA → YOU · INCOMING") so the two people stay distinct; the context line still reads "YOU ARE MAYA".
9. **No initials avatars** are drawn: the approved spec has no avatar node although the asset map mentions them.
10. **The demo-conditions panels** keep their measured 5-pt bottom padding and scroll at larger text.
11. **Ring rendering:** Figma's shadow blur 7 is drawn as SwiftUI radius 3.5, and the joined rotation pivots on each
    ring's top-left corner as the matrices specify; both need a native capture to confirm.

**Open for the founder** (the build follows the choice named; each can be changed cheaply):
- decisions 1, 2, 3, 5 and 8 above;
- the VoiceOver hint on "Preview Wave demo" ("Opens a fictional Wave demo. Nothing is sent."), heard but not seen;
- a Block tapped late, while the report preview is open on top, still counts, as in the Room;
- the DEBUG-only launch option `-ProximeetFixtureName`, which exists to capture long names at the largest text;
- the approved Block explanation (74:581) says blocking hides the person's "card and invitation"; blocking Jules
  also removes his public note. The approved copy is kept unchanged;
- the contract asks for a stable existing demo viewer ID; the code has none, so the Wave uses the single
  `WaveParticipant.viewer` identity and reads the Guest List name once when it opens (a recorded deviation);
- "Show expired example" closes the current invitation (an accepted one included) but does not end the Room: the
  fixed Thursday snapshot keeps the Room eligible, and the contract ends the Room only when the Room itself is
  ineligible.

## 4. Checks executed, with their evidence

All on the Linux VPS (Ubuntu, Swift 6.3.3), on the working files of the candidate before the commit. None is a
native compile or a simulator run.

| Check | Command | Result |
| --- | --- | --- |
| Design graph audit (the reviewed design fixture only) | `python3 validation/audit_design_graph.py` in the handoff | exit 0, `"passed": true`, `"errors": []`; 12 states, 7 overlays, 74 routes, one accept edge (75:419, in-review, SMART_ANIMATE 800 ms), 4 report-reason variants, all other authored navigation 240-ms dissolve |
| Domain tests | `swift test --package-path ProximeetDomain` in a scratch copy holding `ProximeetDomain/` and `Proximeet/` | `Executed 254 tests, with 0 failures (0 unexpected)`: 210 at the base + 43 `WaveDemoTests` + 1 Room test for the retired panel, Room tests adjusted |
| D2, the source-reading domain tests | the same, `--filter` on the eight D2 tests | `Executed 8 tests, with 0 failures (0 unexpected)` |
| App type-check (not a native compile) | the Linux rig: the app's Swift files against SwiftUI / UIKit / CoreGraphics / Accessibility stub modules, strict concurrency | `Debug: 0 errors, 0 warnings; Release: 0 errors, 0 warnings` |
| UI-test type-check (not a native compile) | every `ProximeetUITests` file against an XCTest shim (extended with the real `XCUIScreen.main.screenshot()`, `navigationBars` and `XCTAttachment(data:uniformTypeIdentifier:)`) | exit 0, 0 errors; 6 warnings, all the pre-existing `reviewFlag` warnings in the Birthday, Pass and Welcome tests |
| Project generator | `python3 -B scripts/generate_project.py --check` | `generate_project --check: up to date` |
| Project validator | `python3 -B scripts/validate_project.py` | `13 checks, 0 failed`; check 7: 30 + 7 Wave-plan UI tests selected, all 14 Wave and all 13 Room methods selected by some plan; check 11: both scanner self-tests passed, including the new Wave-only scan |
| Source gate | `python3 -B scripts/places_source_manifests.py`, then `--check`, then `scripts/places_review.sh checkpoint` | `up to date: approved 119, review 217`; checkpoint `result=MATCH` (run last, after every edit) |
| Guardrail audit | the `guardrail-auditor` agent on the full diff against `1a5f97e` | first pass FAIL on this report's wording (hardening changes called "fixed" without a native run or capture) and two stale script comments; all ten product guardrails PASS in the source. Reworded; re-check PASS |

**What the Linux checks cannot see.** SwiftUI layout and rendering, the accessibility tree, the 800-ms join and
the 240-ms dissolves, VoiceOver speech, Dynamic Type metrics, safe areas, the real XCTest runtime and every
UI-test assertion. The type-checks use stub modules that model only the declarations the app uses.

**Found in an independent hardening review and changed in source before this report** (none is verified
natively; each is PENDING a native run and, for the view, a capture):
- HIGH: at the largest text, the incoming review's Decline could never be revealed by the tests, because the
  reveal helper used the 13-pt bar padding everywhere and that screen's bar pads 10. Changed in the helper; unverified until W11a and W14a run.
- MEDIUM: by code reading, the rings would sit up to 8.5 pt above the approved alignment below 440 pt. Changed:
  fixed height, top alignment, a width floor at zero, and no hit testing; unverified until a native capture at
  390 pt.
- LOW: a viewer named like the counterpart (now "YOU"); the preference line's spoken attribution (now "Maya's
  intent and approach: …"); a selected reason read "Selected" twice (the selected trait alone now; VoiceOver speech unverified); taps that
  trusted `isHittable` under the bar (every tap now measures and reveals first); the direction line's order
  (now asserted sender before recipient); the validator had no Wave-specific scan (added: no `Date(`,
  `Date.now`, `Clock`, `DispatchQueue`, `.delay(`, `NotificationCenter`, `print(`, `Logger`, `os_log`,
  `NSLog` in code, and no "delivered", "online now", "read receipt", "typing" or "notified" in copy, with a
  known-answer fixture); the runbook's timing wording (now "estimated, unverified").
- Also found while re-counting: two new domain tests read the repository's files. Both Main plans now skip them
  alongside the six the Room already skipped, and they run on the VPS as D2 (8 tests); each also skips itself
  when no source tree is present, as a safety net.

## 5. The native test manifest and the smallest bounded Xcode Cloud proposal

- **Manifest:** `docs/verification/wave-xcode-cloud-manifest.tsv`, 39 rows.
  - **WaveVerificationMain** (iPhone 17 Pro Max, 440 × 956): W1–W10, W11a, W11b, W12, W13 (all 14
    `WaveReviewTests`), R1–R13 (all 13 `RoomReviewTests`), P1, P4, C1 (the Places tests that go through the
    Room) and D1 (the domain target minus the 8 D2 tests): **30 UI + 246 domain = 276 tests**.
  - **WaveVerificationSmall** (iPhone 17e, else 16e, 390 × 844): W14a, W14b (both largest-text Wave tests),
    R14, C15, P9, C12, C11: **7 tests**.
  - **D2** on the VPS: 8 source-reading domain tests.
- **Coverage asked for, and the rows that carry it:** every screen and panel (W4 captures, W11a/W11b/W14a/W14b
  reachability); both intents and both approaches (W1, W2, W3); long names and largest text (W11, W14 with
  `-ProximeetFixtureName`); safe areas and modal isolation (W4, W11, W14: nothing of the page under a panel in
  the accessibility tree); Leave everywhere (W9); immutable roles (W6); stale and duplicate actions (W5);
  interrupted acceptance (W7); blocks in both orders and Jules's note removal (W8); Places return with the
  draft (W1, W9); ineligible and other-intent profiles never reach the Wave (W13); back swipes (W10); Reduce
  Motion preview (W12). Room and Places regressions: R1–R14, P1, P4, P9, C1, C11, C12, C15.
- **Left out, deliberately:** the 16 Room-plan regression rows that never open the Room (C2, C3, P2, C9, C4–C8;
  P10–P13, C10, C13, C14). Adding both Room plans to the same build removes that residual risk for about 77
  more compute minutes.
- **The proposal** (`docs/verification/wave-xcode-cloud-verification.md`): **one** build of a new manual-start
  **Wave Verification** workflow, its two Test actions side by side, at the candidate commit, estimated at
  **about 80–120 min wall time and about 105–160 compute minutes** (scaled from the Room run on 1a5f97e: Main
  50 min 55 s, Small 26 min 28 s, 1.04–1.18 times the Codemagic-measured test time); **at most one contingency
  build** under the runbook's §6 rules; **the archive and delivery asked for separately** after a sufficient
  pass. Room's allowance does not transfer, and no Wave CI budget is authorized.
- **Before any of it:** pushing the branch (a new branch; no force, no merge) and confirming that no Xcode Cloud
  workflow's start condition matches it both need authorization; creating the workflow is the founder's step in
  App Store Connect.
- **Xcode Cloud cannot run:** the 8 D2 source-reading tests (its test environment has no repository), and
  nothing in §7 below.

## 6. The preview path

There is no hosted preview. Codemagic is disabled and Appetize is not a delivery path; no Wave build exists.
- **In a native build that contains this commit** (a Debug run from Xcode, or a later internal build): Welcome →
  More options → Continue the demo (no account) → Birthday → Pass → Guest List (the name typed here is the one
  the Wave shows) → Wristband Social (or Business) → Signal → Places → Common Ground → Preview room demo →
  Enter room demo → Show populated example → View card on Maya's introduction (Jules's for Business) →
  **Preview Wave demo**.
- **DEBUG shortcuts** (Xcode scheme arguments): `-ProximeetFixture wave-menu` (or any of the 12 `wave-*` keys),
  with `-ProximeetWavePanel`, `-ProximeetWaveReason`, `-ProximeetWaveFrom`, `-ProximeetWaveAfterBlock`,
  `-ProximeetRoomBlocked` and `-ProximeetFixtureName` as documented at the top of `DebugFixtures.swift`.
- **After an authorized run:** the result bundle keeps every test's captures and screen recording
  (`keepAlways`), which is the first time anyone will see the native Wave.

## 7. The honest remaining manual checks

None of these is covered by any automated row, and each is **PENDING FOUNDER**:
- **Native compilation and every automated row**: nothing has run on an Apple system.
- **VoiceOver:** reading order, focus after a panel closes, the modal panels, the decorative rings staying silent,
  and the sentence-case labels. The tests check the accessibility tree, not speech.
- **The system Reduce Motion setting:** the tests use the app's preview flag, not the setting.
- **Motion quality:** the 800-ms ring join on Accept, the 240-ms dissolves, and the ring shadow and pivot
  (decision 11), judged on video.
- **The device:** install, performance and feel on the founder's iPhone, and the founder's visual approval of
  the native Wave against the approved board.

**Known baseline issues, carried and not caused by the Wave:** the Guest List negative-frame warning (it
predates the Room; whether it is gone is only known after a native run), and the largest-text wrapping of the
INTRODUCTIONS label.

## 8. Changed files (against `1a5f97e`)

| File | Change |
| --- | --- |
| `ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift` | new, +715 |
| `ProximeetDomain/Sources/ProximeetDomain/RoomDemo.swift` | +153 −30 |
| `ProximeetDomain/Tests/ProximeetDomainTests/WaveDemoTests.swift` | new, +2,099 |
| `ProximeetDomain/Tests/ProximeetDomainTests/RoomDemoTests.swift` | +48 −11 |
| `Proximeet/Scenes/WaveView.swift` | new, +1,240 |
| `Proximeet/Scenes/RoomView.swift` | +114 −88 |
| `Proximeet/App/DemoSession.swift` | +26 |
| `Proximeet/App/DebugFixtures.swift` | +261 −25 |
| `ProximeetUITests/WaveReviewTests.swift` | new, +3,171 |
| `ProximeetUITests/RoomReviewTests.swift` | +103 −100 |
| `TestPlans/WaveVerificationMain.xctestplan`, `TestPlans/WaveVerificationSmall.xctestplan` | new |
| `TestPlans/RoomVerificationMain.xctestplan` | skips the two new source-reading domain tests; at this commit its domain run also includes `WaveDemoTests` (246 domain tests, 204 at `1a5f97e`) |
| `Proximeet.xcodeproj/project.pbxproj`, `…/xcschemes/Proximeet.xcscheme` | regenerated: the new sources and the two plans |
| `scripts/generate_project.py`, `scripts/validate_project.py`, `scripts/places_source_manifests.py` | the plans; the plan and Wave checks; the handoff copy |
| `docs/design/wave-approved/` | new: the approved handoff copy (§1) |
| `docs/verification/wave-xcode-cloud-manifest.tsv`, `docs/verification/wave-xcode-cloud-verification.md` | new |
| `docs/verification/places-approved-files.sha256`, `docs/verification/places-review-files.sha256` | regenerated last; the review manifest also refreshes two base entries that were already out of date at `1a5f97e` (`ProximeetUITests/PlacesReviewTests.swift`, `ProximeetUITests/SignalReviewTests.swift`), which the Wave did not touch |
| `docs/reports/wave-chapter-09.md` | this report |

Bundle identifier `com.goseng.proximeet` and Goseng automatic signing are unchanged (validator check 6; package
link and build phases, checks 4–5). The Release demo entry (`WelcomeView.swift`) is not in the diff.

## 9. Not done, by instruction

No push, no Xcode Cloud run or workflow change, no Codemagic, no Apple configuration, upload, signing change,
merge, TestFlight or deployment. Chat and Keep are out of scope and not started.
