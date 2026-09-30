# Room chapter 08: implementation, repair and native verification

Dates: 2026-09-29 (implementation and Codemagic, Part I) and 2026-09-30 (repair and Xcode Cloud
preparation, Part II). Not production-ready.

**Status (2026-09-30): repaired in source, not yet verified natively.**
- **The repair candidate is the tip of branch `room-repair/verification-20260930T002530Z`.** It is the
  Room merged with the Goseng TestFlight signing setup, plus the repairs of Part II.
- **No native run has happened on it.** The required Xcode Cloud verification waits on one Apple-side
  step this machine cannot perform (§II.7).
- **The Room's automated checks have not all passed.** R7, R9 and R14 and the 11 smaller-iPhone Places
  rows have no passing execution on the final Codemagic app (`b5ee804`/`c7716a1`); R9 passed only on the
  older `51fe52a` and `82eef53`. No row has run on the candidate.
- **Founder visual review is pending.**

## Part II. Repair and native verification through Xcode Cloud (2026-09-30)

This part records the repair assignment of 2026-09-30. Part I below (sections 1–10) is the
historical record of the Codemagic phase and is kept as written, apart from correction notes marked
**Correction (2026-09-30)**. Nothing in Part II is founder visual approval.

### II.1 Honest status at the start of the repair

- **Room rows with any passing execution** in the four Codemagic builds: 12 of 14 (every row except R7
  and R14). **On the final Codemagic app** (builds 3 and 4 produced a byte-identical app, 11 of 11 files
  compared): 11 of 14. R9 passed only on `82eef53` and `51fe52a`; R7 failed in build 1 and was never
  rerun; R14 failed in all four builds.
- **Correction (2026-09-30):** the summary given at the end of the Codemagic phase said "13 of 14 rows
  have passing runs". That was wrong: its own list totals 12 of 14, and only 11 of 14 passed on the
  final app. It was never a final-candidate pass count.
- **Places regression:** the 12 main-phone rows passed once, on `c7716a1` (build 4). The 11
  smaller-iPhone rows have never run in a Room build.
- **Historical, unchanged:** the Places correction passed 15 of 15; B2's build-5 failure and the
  interruptions stay on record; the strict regression gate stays FAIL.
- **Codemagic ledger, retained:** four builds, 131 billed minutes, USD 12.45 (Part I §8). Those
  builds did not satisfy the Xcode Cloud-only instruction and are not retried.

### II.2 Source identity and how the branches were reconciled

| | |
| --- | --- |
| Room branch | `room/approved-20260929T170623Z` at `868587cc0526dccd334aa39f1a3e828af80643d2` (fetched from GitHub) |
| Delivery branch | `testflight/internal-20260928` at `67bf1a95ed9bd0824df64932147851e4f8fb1f04` = `d341782` + one commit, "Preserve Goseng internal TestFlight signing setup" |
| Common ancestor | `d341782d5fd3c0fb3029aaba4469725ed72dd633` (the only merge base) |
| Repair branch | `room-repair/verification-20260930T002530Z`, worktree `/home/proximeet/proximeet-cloud-room-repair-20260930T002530Z`, created with `git worktree add` from `868587c` |
| Reconciliation | merge commit `2f01b7c` (`git merge --no-ff`, parents `868587c` and `67bf1a9`). No textual conflicts. The project file, the generator and the validator carry exactly the signing side's changes; every other file is the Room's; the generated project equals a fresh render (`generate_project.py --check`: up to date); validator 13 of 13. The only stale file was the Places gate manifest, refreshed in the next commit. Nothing was reset, force-pushed or copied from another worktree |

The signing identity is preserved in both configurations of the app target: `PRODUCT_BUNDLE_IDENTIFIER
= com.goseng.proximeet`, `DEVELOPMENT_TEAM = 2G437MAN6W`, automatic signing, display name
"Proximeet Demo", `MARKETING_VERSION 0.1.0`, `CURRENT_PROJECT_VERSION 1`; UI tests
`com.goseng.proximeet.uitests`. There is no Debug-only identifier any more: the Codemagic builds'
simulator app (`com.proximeet.demo`) came from the Room branch before this merge. Launch fixtures
compile only under `DEBUG`; the normal demo entry (Welcome → More options → Continue the demo (no
account)) and the Room itself are not DEBUG-guarded, so they remain in Release.

**Build numbers.** The project's build number is 1, which is already used: version 0.1.0 (1) was
uploaded by hand on 28 September (`docs/reports/testflight-setup-20260928.md`). Xcode Cloud's own
numbering is the existing mechanism for later builds; the only Xcode Cloud run so far (below) archived
`67bf1a9` successfully. App Store Connect's current numbering cannot be read from this machine.

**Apple-side state observed read-only through GitHub.** Xcode Cloud is connected to the repository; its
GitHub app posts check runs on the commits it builds.
- `67bf1a9`: one run, "Proximeet | Proximeet TestFlight | Archive - iOS", success, 19:58–20:04 UTC on
  28 September (0 errors, 0 test failures, 0 warnings).
- Every Room commit pushed so far has only GitHub's automatic empty "queued" suite for Xcode Cloud (0
  check runs): no Room commit has been built by Xcode Cloud. **Apple runs used for this Room work: 0 of
  4; Apple compute used: 0 of 150 minutes.**
- The TestFlight workflow did not build any Room push, which is consistent with its start condition
  being restricted to `testflight/internal-20260928`. The workflow's configuration itself cannot be
  read from here.

### II.3 The review's rulings, and how each was applied

These are the rulings of the independent review of build 3's evidence. They are recorded as review
rulings, not as founder approval.

1. **One surviving fictional card after a block is correct.** The approved fixtures require Maya-only and
   Jules-only states; the sample count is not live attendance. Kept: all four block sets, both block
   orders, Jules's public note removed when he is blocked, host notes retained.
2. **The two deliberate demo gates stay** (Preview room demo → entry; Enter room demo → waiting; DEMO
   CONTROL / Show populated example → samples). Unchanged.
3. **The safety tap rule.** Traced to its source:
   - No tap-count requirement exists anywhere in the approved handoff master
     (`PROXIMEET_ALL_TEN_APPROVED_HANDOFFS.zip`, SHA-256 `365df942…117f7`, 13 of 13 entries verified; the
     Room zip `d462d7ec…dfe6f0`, 22 of 22). A search of every chapter's README, DESIGN_NOTES,
     CLAUDE_PROMPT, LAYOUT_SPEC, fixtures and validation files finds no "two taps", "one tap", "Safety
     Center" or tap budget. The approved Room requirements are reachability: Room CLAUDE_PROMPT.md:58
     ("Keep the global safety control available in waiting and the active room; profiles and Jules's
     public note have actor-context safety controls") and DESIGN_NOTES.md:42.
   - The "at most two taps" rule came from rule 9 of `docs/non-negotiables.md` in the **legacy**
     repository (`kasrarayat-cloud/proximeet`, branch `rebuild/phase-01`). That document names itself
     authoritative for that branch only and lists rule 9 among the rules with "no implementing surface
     right now". This rebuild repository never references it. Its CLAUDE.md says the old project's
     "prior page freezes and old visual doctrine do not govern this new implementation. Their safety
     lessons remain relevant."
   - The approved graph itself specifies the People route: card 67:387 → profile 66:117 → profile Safety
     `I67:652;67:126` → Maya's safety 66:128 → "Block Maya in demo" 67:878 → filtered People 66:119, and
     the global Safety panel's approved copy (67:868) says "Open a sample card to block or preview a
     report." Counted from People, blocking is three taps (card, Safety, Block); from a profile or from
     Jules's note row it is two.
   - **Disposition:** no applicable binding rule was found, so no route was added and the authored route
     and tap counts above are recorded as they are. Because the rebuild keeps the old project's safety
     lessons "relevant", whether blocking from People should take at most two taps is **open for the
     founder** (II.10). Part I §5 item 11
     overstated the conflict: it called the legacy rules "the product non-negotiables" and quoted rule
     9's "Enforced by" and "Verify" rows as if they were the rule. The authored routes and actual tap
     counts above are the record.
4. **Compatibility comes from the actual intent.** Social → Maya and Business → Jules show How Waves
   work; the other two combinations show Back to people and "Waves stay within your selected intent."
   The complete handoff has no approved compatible-state Room line for Jules (Maya's 67:169 and Jules's
   incompatible 67:193 are the only "Approach boundary" nodes). **Disposition:** the Business → Jules
   line keeps the approved Signal approach copy, "Open to a brief hello. No pressure to continue.",
   whose reuse is recorded; it implies no consent to chat or meet.
5. **The largest-text ticket stack is kept** (Part I §5 item 14): normal size keeps the reference
   composition; at the accessibility sizes the text runs below the art so "Common Ground" stays whole.
6. **Hiding the covered screen's bottom bar under a panel is acceptable**, provided the covered screen
   stops receiving touches and assistive focus and the panel's actions remain. Applied: under a panel
   the page now also has `allowsHitTesting(false)` (the dim already took every touch), and it stays
   `accessibilityHidden`; the tests now check the underlay's accessibility tree (II.6).
7. **Text under the status clock is a confirmed defect.** Repaired (II.5).

### II.4 Disposition of Part I's fifteen deviations

| # | Deviation | Disposition |
| --- | --- | --- |
| 1 | Business guests' profile lines (Signal copy reused for Jules; approved same-intent line for Maya) | Valid; kept per ruling 4, reuse recorded |
| 2 | Validator exception for the approved "…enough people checked in." | Valid approved copy; the exception stays exact-literal |
| 3 | Entry is a dissolve over the explanation, not a push | Kept; the Places navigation path stays untouched |
| 4 | Block and Leave are instant | Kept; the brief requires immediate, and Leave invalidates the run before any transition |
| 5 | Panels centred in the safe area over a dimmed screen; the dim does nothing on tap | Kept; the Figma export has no placement, scrim or outside-tap data (LAYOUT_SPEC overlays are free-standing frames) |
| 6 | Ended outer Back returns to Places | Kept; it never re-enters a run |
| 7 | Report reasons centred on their radio | Kept as a native rendering difference |
| 8 | Both-blocked title in three 36-pt lines | Kept; matches the approved frame as Figma renders it |
| 9 | One ticket whose layout changes in the 500-ms move | Kept |
| 10 | VoiceOver hints and group labels not in the approved copy | Open for the founder; unchanged |
| 11 | "Conflicts" with legacy rules 9 and 11 | Rule 9: not binding as written; the three-tap People route is open for the founder (ruling 3). Rule 11: the single surviving card is approved behaviour (ruling 1) |
| 12 | Brand in chrome; DEMO badge instead of a banner | Valid; unchanged |
| 13 | VoiceOver card label | Kept |
| 14 | Compact ticket stacks at accessibility sizes | Kept per ruling 5 |
| 15 | No bottom bar under an open panel | Kept per ruling 6; the underlay now also takes no touches |

### II.5 What R14 actually hit, and the repairs

**The phantom bar (from builds 1–4's own logs and captures, reconstructed; the helper never logged the
element's identifier).**
- Every look of R14's six failing panel reveals, on the iPhone 17e (390 × 844, largest text), used a
  usable range of 47.0–592.3 ("bar top 592.3"). The same 592.3 appears on Room pages with no panel, and
  on the 440-pt phone the equivalent value is 704.3 (both 251.67 pt above the screen's bottom).
- It is not the Room's bar: under a panel that bar is not built (builds 3–4), and on a page its top is
  604 on 844 (Leave 617–768).
- It matches Places' own bottom bar under the Room: "Back to place" (one line, 67.33) and "Preview room
  demo" (two lines, 144.33) above an 11-pt gap and a −5 bottom padding put the primary's top at
  815 − 67.33 − 11 − 144.33 = 592.33. A pixel column of build 4's largest-text explanation capture shows
  the primary at 704.33–848.67 on the 956-pt phone. That bar sits in Places' scroll view's bottom
  `.safeAreaInset`, has no scroll-view ancestor in the tree, and so counted as a fixed bar in front of
  every panel. Inset content does not inherit an ancestor's `accessibilityHidden`: builds 1 and 2 showed
  the same for the Room's own bar.
- **Correction (2026-09-30):** Part I's build 3 diagnosis (rounding between two 844-pt scroll views)
  and build 4's (the dimmed page's elements) were wrong; build 1's R7 failure (4 pt short of a "bar" at
  704.3) was the same Places element.

| Failed control (build 3/4) | Frame at scroll end | Range before (47–592.3) | Range after (the panel's viewport, 47–824) |
| --- | --- | --- | --- |
| Jules's safety, Back | 526.3–610.0 | short by 16.7 pt | inside |
| Jules's safety, Leave | 624–775 | short by 181.7 pt | inside |
| Maya's report, Close preview | 448–599 | short by 5.7 pt | inside |
| Maya's report, Leave | 615–766 | short by 172.7 pt | inside |
| Wave information, Back to profile | 449–600 | short by 6.7 pt | inside |
| Wave information, Leave | 616–767 | short by 173.7 pt | inside |

These frames and captures show the controls on screen; they do not show that the taps work. The
repaired R7/R14 must prove each tap and its resulting state (II.6).

**Repairs made (in source; not yet run natively):**
1. **Places' bar under the Room is no longer built** (`PlacesView.swift`): while the Room shows, an empty
   spacer of the bar's last measured height stands in for it, and the bar dissolves out and back in
   with the Room. This removes the phantom bar and a real accessibility leak: "Preview room demo" and
   "Back to place" were reachable in the tree under the Room.
2. **Panel text stays out of the clock** (`RoomView.swift`): the panel's scroll view has the same ground
   strip behind the status bar as the page. Scrolled content passes under it; readable Dynamic Type
   and every reason and action stay reachable by scrolling.
3. **The covered screen takes no touches** (`allowsHitTesting(false)` beside `accessibilityHidden`); its
   bar is not built (unchanged since `b5ee804`). Focus returns to the caller on dismissal
   (`RoomView.focusTarget`, unchanged). Leave changes the model with animations disabled before any
   transition (unchanged).
4. **Invalid geometry candidates corrected.** The runtime warning "Invalid frame dimension (negative or
   non-finite)" is attached once to every test that renders Places (every row of builds 1–4, and the
   Places builds before the Room); its earliest instance is in the Birthday chapter's build of
   25 September at the Welcome → Birthday push. It predates the Room, and no Room code was found that
   can produce it. Two classes of source can:
   - `TicketFooterLayout` (Places' ticket footer) returned its proposal's width as its size, which is
     infinite for an infinite proposal. It now measures its natural width instead.
   - Five scenes computed `min(376, width − 64)` (and similar) without a floor, negative for a
     momentary zero width: Birthday, Wristband, Signal, Guest List and Pass. Each is now floored at 0.
   These changes do not alter any real layout (widths are 390 or 440). Which one produced the warning
   is unproven until a native run shows whether it disappears.

### II.6 Test repairs (in source; not yet run natively)

- **The reveal helper measures the active viewport** (`RoomReviewTests.reveal` / `revealLook`):
  - a target inside a panel is judged against that panel's own scroll view, clipped to the status bar
    and the home-indicator margin; nothing outside the panel counts as an occluder;
  - a target on a Room page is judged against the Room's own bar (its identifiers, or anything outside
    every scroll view in the lower half that is not a Places element), at the bar's visual top: its first
    element minus the bar's 13-pt top padding, with no extra margin;
  - every look logs which element set the edge, so a failure can be read from the log alone.
- **R7 and R14** (`testLargestTextKeepsRoomReachable`, the same method on each phone) keep every earlier
  check and add, each on a fresh launch at the largest text:
  - the global Safety panel (previously never tested at this size);
  - a way-back proof for each panel: reveal, `isHittable`, tap, and the caller's state (Jules's Back →
    his profile; Maya's report Close preview → her safety panel, reopened with no reason selected;
    Wave information → Maya's profile; global Safety Close → People);
  - a Leave proof for each of the four panels, each on a recreated scenario: reveal, `isHittable`,
    tap Leave, the ended screen with no actor, note, profile or panel in one snapshot, a stale tap where
    Back was and a cancelled edge swipe (still ended, or Places at Now, never a run), Return to Places at
    Now, then Back to Signal with the fixture's "Social band · Chat first" still selected;
  - an underlay check on every panel: one snapshot must hold no identifier of the Room page or Places.
  - The test asks for a 1,200-s allowance (estimated 420–600 s at Codemagic's pace).
- **`assertPanel`** (every test that opens a panel) also requires Places' `explanation.primary` and
  `explanation.secondary` to be absent under the Room; the capture test runs the underlay check on all
  eight overlays and the three reason variants.
- **R1**, the recorded journey, keeps full holds even though the plans set short holds for all tests.
- The Places test files needed no change: none expects Places' bar while the Room shows.
- Linux evidence only: the whole app type-checks in Debug and Release against the SwiftUI/UIKit
  stand-ins (0 errors, 0 warnings); the UI-test target type-checks against the XCTest stand-in except
  three known stand-in gaps in the unchanged Welcome tests; the domain suite passes 210 of 210. None of
  this is a native compile or a simulator run.

### II.7 The native verification plan and the Apple-side step

- **Test plans (committed):** `TestPlans/RoomVerificationMain.xctestplan` (the scheme's default; 25 UI
  tests, R1–R13 and the 12 main-phone Places rows, plus 204 domain tests) and
  `TestPlans/RoomVerificationSmall.xctestplan` (12 UI tests: R14 and the 11 smaller-iPhone Places rows).
  Every row maps to the test method the Codemagic manifest names; `scripts/validate_project.py` check 7
  now verifies both plans (selected methods exist in their classes, the review flags are set,
  `parallelizable` false, no repetition). Each test may run 900 s; R7/R14 asks for 1,200 s. Coverage is
  off. No automatic retries.
- **Six domain tests** read the repository's files while they run and cannot run where Xcode Cloud runs
  tests; the Main plan skips them and they run on the VPS at the candidate commit (row D2).
- **Device manifest:** `docs/verification/room-xcode-cloud-manifest.tsv`, one row per required execution
  (R1–R14, the 23 Places rows, D1, D2), with its plan, destination, method, what it proves and its prior
  status. Every row is required on this candidate, because product files changed.
- **Runbook:** `docs/verification/room-xcode-cloud-verification.md`.
- **The Apple-side step that cannot be done from here.** This machine has no App Store Connect access (no
  API key, no Apple sign-in), so it cannot create a workflow, start a run or download results. The one
  missing step is the founder's: create the manual-start **Room Verification** workflow (Xcode 26.6; Test
  action 1 = scheme Proximeet, plan RoomVerificationMain, iPhone 17 Pro Max; Test action 2 = plan
  RoomVerificationSmall, iPhone 17e or else iPhone 16e; no Archive, no post-actions), then Start Build on
  this branch and confirm the built commit is the candidate. The existing Proximeet TestFlight workflow is
  only read, never edited. Results then appear on GitHub as check runs on the candidate commit, which this
  machine reads; the result bundles are downloaded by the founder.
- **Expected Apple compute:** about 90–105 minutes for one full run (Main 55–65, Small 35–40, run side by
  side), estimated from Codemagic timings. That leaves room for the final signed archive but not for a
  second full run within the 150 minutes.
- **Delivery (not started):** only after every row has passed on the candidate, the delivery branch is
  fast-forwarded normally to it; that push is the TestFlight archive trigger, and no manual archive is
  added. The build number comes from Xcode Cloud. Archive success, Apple processing and availability to
  Founder Preview are confirmed separately.

### II.8 Row-by-row status

**On this candidate, no native row has run yet; every row below is required.** The historical column
lists every earlier execution (b1 = `51fe52a`, b2 = `82eef53`, b3 = `b5ee804`, b4 = `c7716a1`; b3 and b4
produced a byte-identical app). The candidate's product files differ from all of them (II.5), so no
earlier pass carries over.

| Row | Test | Earlier executions | This candidate |
| --- | --- | --- | --- |
| R1 | real journey from the explanation through the Room and back (recorded) | fail b1, fail b2, **pass b3** | not run |
| R2 | every state and overlay captured and checked | fail b1, fail b2, **pass b3** | not run |
| R3 | back gestures | fail b1, fail b2, **pass b3** | not run |
| R4 | Business compatibility | fail b1, fail b2, **pass b3** | not run |
| R5 | both deliberate entry gates | fail b1, fail b2, **pass b3** | not run |
| R6 | ineligible and stale entry refused | **pass b1, b2, b4** | not run |
| R7 | largest text, iPhone 17 Pro Max | fail b1 | not run |
| R8 | Leave from every context | fail b1, fail b2, **pass b3** | not run |
| R9 | notes filtering and both block orders | **pass b1, b2** | not run |
| R10 | the app's Reduce Motion preview flag (not the system setting) | fail b1, fail b2, **pass b3** | not run |
| R11 | report preview local, restores its caller | fail b1, fail b2, **pass b3** | not run |
| R12 | Social compatibility, both approaches | fail b1, fail b2, **pass b3** | not run |
| R13 | terminal re-entry resets the demo | **pass b1, b2, b4** | not run |
| R14 | largest text, smaller iPhone | fail b1, b2, b3, b4 | not run |
| C1, C2, C3, P2, P4, P1, C4, C5, C9, C6, C7, C8 | the 12 main-phone Places rows the Room touches | **pass b4** (once each) | not run |
| C15, P9, P10, P11, P12, P13, C10, C12, C13, C14, C11 | the 11 smaller-iPhone Places rows | never run | not run |
| D1 | domain tests on the simulator (204) | Mac host `swift test` passed in b1–b4 | not run |
| D2 | the six source-reading domain tests | — | VPS `swift test` at the candidate; its result is given with the candidate's SHA in the handoff and recorded after the native run |

### II.9 Budget and provider ledger

| Provider | Runs | Minutes | Cost | Status |
| --- | --- | --- | --- | --- |
| Codemagic (Part I) | 4 | 131 billed | USD 12.45 | kept in the record; not retried; no further Codemagic dispatch |
| Xcode Cloud, this Room work | 0 of 4 | 0 of 150 | within the included allowance | awaiting the founder's workflow (II.7) |
| Xcode Cloud, before the Room | 1 (TestFlight archive of `67bf1a9`, 28 Sep) | not visible from here | — | not part of this budget |

No Appetize, rented Mac, plan purchase or other paid service was used.

### II.10 Manual and unavailable checks, and what is still open

- **Not verifiable here, pending founder or device:**
  - VoiceOver (focus, modality of panels, the dimmed underlay), beyond the XCTest tree checks;
  - the system Reduce Motion setting: no supported way to switch it from these tests was found, and R10
    uses the app's own preview flag;
  - a physical device;
  - Apple processing and TestFlight availability;
  - motion quality. The 500-ms ticket move and the dissolves are judged on video.
- **Open until a native run:**
  - every row in II.8;
  - whether the "Invalid frame dimension" warning disappears;
  - whether Xcode Cloud offers the iPhone 17e simulator.
- **Founder decisions still open:**
  - blocking from People takes three taps (card, Safety, Block), against the legacy "at most two taps"
    safety lesson; from a profile or Jules's note it takes two (ruling 3);
  - the VoiceOver-only hints and group labels (Part I §5 item 10);
  - Room visual review.


## Part I. Implementation and the Codemagic phase (2026-09-29)

The historical record, kept as written apart from the correction notes marked (2026-09-30). Its original
status block, which the Part II status above replaces, is kept here:

> **Status: implemented and Mac-tested in four builds. The Room's automated checks did NOT all pass.**
> R14, the largest-text check on the smaller iPhone, failed in builds 1–4:
> - in builds 1 and 2, partly from product behaviour since changed;
> - in builds 3 and 4, at six panel reveals attributed to the test helper, which is unverified.
>
> R7 was not rerun. Founder visual review is pending. Every Mac result below names its Codemagic build and
> commit; §9 gives the outcome row by row.
>
> **Correction (2026-09-30):** builds 3 and 4's R14 failures were not the test helper alone; see §II.5.

## 1. Founder approval on record

The founder reviewed the current app and said, verbatim, *"it's cool, I like it"* on 28 September 2026.
This is recorded as **visual approval of the existing Welcome-through-Places preview for progression** to
the Room chapter. It is not a physical-device, accessibility or production sign-off, and it does not
cover the Room, which awaits its own founder visual review.

## 2. Prior evidence, unchanged

- **Places correction:** passed 15 of 15 (`places-recovery-01.md`).
- **Places regression:** all 56 regression rows have passing executions. B2's build-5 failure and the
  interrupted executions are retained in the record (`places-recovery-01.md` §9–§10).
- **Strict regression gate:** stays **FAIL** (55 of 56 under the rule that failures win). This chapter
  does not change that verdict.

## 3. Baseline and provenance

| | |
| --- | --- |
| Room branch | `room/approved-20260929T170623Z`, worktree `/home/proximeet/proximeet-cloud-room-20260929T170623Z`, created with `git worktree add` from `87de90638ac110f68fe991dd4427234817748698` (the local docs commit above pushed `d341782`; product baseline `808950f8102d1c0e0f6c3422fc0aed3a0df555fe`). Other branches and worktrees are untouched |
| Handoff | `/home/proximeet/proximeet-handoff-sj4ivb_k/PROXIMEET_ALL_TEN_APPROVED_HANDOFFS.zip` (SHA-256 `365df942…117f7`). Its `SHA256SUMS.txt` verifies all 13 entries. `chapters/08-room/PROXIMEET_ROOM_APPROVED_HANDOFF.zip` is `d462d7ec…dfe6f0`, as listed, and its own `SHA256SUMS.txt` verifies all 22 files |
| Figma | page 66:111, board 68:465, approval 74:566. States 66:112–66:126, overlays 66:127–66:134, report variants 67:816/826/836/846 |
| Copied into the repository | `docs/design/room-approved/` (board, Common Ground delivery reference, README, design notes, prompt, fixture contract, checksums); the source gate checks it against its `SHA256SUMS.txt` |
| Art and type | the existing Common Ground art (crop [46, 83, 1211, 1218]) and Manrope (OFL). No new art, portraits, motion library or screen-shaped images |

## 4. What was built

- **Domain** (`ProximeetDomain/Sources/ProximeetDomain/RoomDemo.swift`): `RoomPreview` (entry, or a run)
  and `RoomRun`, a typed run model: phase (waiting, populated, ended), blocked set, tab and a
  presentation route. It is separate from the production flow (`DemoFlow` is not changed). A `RoomRunID`
  rejects stale callbacks. Memory only: nothing is persisted, and a relaunch restores no Room.
  - **Eligibility:** only from Common Ground's check-in explanation, with an eligible Social or Business
    band and a chosen approach. Nothing is defaulted, and the Room is dropped as soon as that state no
    longer holds.
  - **Gates:** only "Enter room demo" creates a run, and it starts in waiting with no sample
    information. Only "DEMO CONTROL / Show populated example" populates it. No timer, navigation or
    relaunch substitutes for either.
  - **Blocks:** immediate, additive and never undone; they survive tabs, Back and redraws.
  - **Reports:** unsent and local; one reason at a time; choosing the same reason again changes
    nothing; Close discards.
  - **Leave:** reachable from every context, immediate and terminal; the ended state cannot go back
    into a run.
  - **Tests:** 24 new domain tests, 210 in the full suite on Linux, 0 failures.
- **Session** (`DemoSession`): `previewRoomDemo`, `leaveRoomEntry`, `enterRoomDemo`, `updateRoomRun`
  (id-guarded), `returnToPlacesFromRoom` (browsing at Now with the draft intact) and `roomOuterBack`.
- **View** (`Proximeet/Scenes/RoomView.swift`): all 15 full-screen states, the 8 overlays and the 4
  report-selection variants, in native SwiftUI.
  - It is shown above the explanation by `PlacesView`, which hides its own content from accessibility
    meanwhile.
  - Motion: the 500-ms ease-out ticket-to-header move after Enter and 240-ms dissolves elsewhere. Under
    Reduce Motion both are a crossfade or instant.
  - Targets are at least 44 pt, and Leave stays in a fixed bottom bar at every text size.
- **Places integration:** only the eligible Common Ground explanation's primary changes, to "Preview room
  demo". The Room's outer Back is a completed leading-edge swipe or VoiceOver's escape; a cancelled
  swipe changes nothing.
- **Tests and harness:** `ProximeetUITests/RoomReviewTests.swift` (13 methods, manifest rows R1–R14).
  The six Places tests that tapped the old primary now take the approved route back to Now: Preview
  room demo → Enter room demo → Leave and disappear → Return to Places. The manifest has Room scopes
  and the workflow is `proximeet-room-review-45` (with 35-, 30- and 25-minute variants).

## 5. Decisions, assumptions and deviations

1. **Business guests' profile lines.** The approved frames show a Social guest only.
   - For a Business guest, Jules (compatible) ends with Signal's approved summary for Okay to say
     hello, "Open to a brief hello. No pressure to continue.". That sentence is not Room copy.
   - Maya (incompatible) ends with the approved "Waves stay within your selected intent."
2. **Validator exception.** The approved waiting copy says "…enough people checked in." The guardrail
   scanner bans "checked in". It now allows exactly that literal, and it scans the domain copy file as
   well, so the exception cannot hide other copy.
3. **Room entry is a dissolve over the explanation, not a system push**, and so is entry Back. This keeps
   the Places navigation path untouched.
4. **Block and Leave are instant**; the prototype's dissolve on Leave is replaced by an immediate change,
   as the brief's "immediate" requires.
5. **Overlay placement.** Panels are centred in the safe area over a dimmed screen. A tap on the dim does
   nothing. Figma exports no position or outside-tap behaviour.
6. **Ended outer Back** (swipe or escape) returns to Places, the same as "Return to Places". It never
   re-enters a run.
7. **Report reasons** are centred on their radio; Figma top-aligns one-line labels about 11 pt above it.
8. **The both-blocked title** is drawn as Figma renders it in its 328-pt box: three 36-pt lines, running
   past its nominal 80-pt box to the explanation at y 146 (card 236 tall).
9. **The ticket move** is one ticket whose layout changes inside the 500-ms animation, not two matched
   tickets.
10. **VoiceOver hints and group labels** such as "Opens a fictional Room demo." and "Sample reasons" are
    not approved copy. They are read only by VoiceOver, and the founder should approve or remove them.
11. **Design-level conflicts recorded for the founder, not changed in code.** The approved Room design
    is implemented as drawn. Measured against the product non-negotiables, it departs from two rules in
    the ways below; the founder should rule on each. The rules live in the original checkout, not in this
    repository: `/home/proximeet/proximeet/docs/non-negotiables.md` (`kasrarayat-cloud/proximeet`),
    rules 9 and 11, quoted here.
    - **Rule 9** says: *"Safety Center is one tap (the SafetyShieldButton) from any room or chat
      surface; block and report complete in at most two taps."* It also says *"Report and block appear
      on every message row and every profile"*, and that Safety Center carries *"the plain statement
      that the service does not monitor every interaction and is not an emergency service."*
      - **Shield:** the shield is on waiting, both tabs and each profile. On a profile it opens that
        sample's safety, not the general one.
      - **Block:** from People it takes three taps (card → profile Safety → "Block … in demo"). From
        Room notes it takes two (Jules's "…" → Block).
      - **Report:** the preview never completes, by design, because nothing is sent. Reaching a chosen
        reason takes four taps from People (card → Safety → Preview report → reason) and three from
        Room notes ("…" → Preview report → reason).
      - **Rows without controls:** the host note and the icebreaker have no block or report control.
      - **Missing line:** the Room's global safety panel does not carry the monitoring and emergency
        statement.
    - **Rule 11** says: *"Below the minimum crowd size, the product never shows a participant list,
      never shows an exact count, and never reveals that a single person is present. It shows 'A few
      people are checking in.' instead."*
      - **Waiting:** no list, count or sample is shown, but the approved waiting copy replaces the
        rule's fixed line with "Introductions appear only when a venue session has enough people
        checked in." (see item 2).
      - **One card:** when one sample is blocked, People shows the other sample's card alone. Both
        cards are labelled fictional sample introductions.
12. **Brand and banner.** "Proximeet" appears in the Room's chrome (as in every approved chapter's
    header) and in the workflow names. No `BrandConfig.swift` or prototype banner exists in this rebuild:
    each screen and panel carries the approved DEMO badge instead, as every earlier chapter does.
13. **VoiceOver card label.** Each sample card reads as one button, for example "Maya. Social · Chat
    first. Coffee, bookshops, and a good detour. View card".
14. **The compact ticket at accessibility text sizes** (a deviation from 67:134, which shows only
    the default size). When the text size is one of the accessibility sizes and the name would need more
    lines beside the art than across the ticket, the name, session line and preference run the ticket's
    full width below the art. The art keeps its approved place. At every other size, on any phone
    width, including 375-pt phones that no build here tests, the approved arrangement is kept.
15. **Under an open panel, the dimmed screen shows no bottom bar** (its Leave, or People's boundary
    line). An empty spacer of the bar's height takes its place. Figma exports the panels alone and does
    not show what lies under them; each panel carries its own Leave.
    - **Captures launched straight into a panel:** the bar was never measured there, so the spacer is
      empty and the dimmed page underneath sits slightly differently from the real journey. This is
      cosmetic only.

## 6. Mac verification plan

Budget: up to four new manual unsigned Codemagic builds, 150 aggregate rounded runner minutes,
USD 15 incremental before tax, each build at most min(45, remaining) minutes. The rate was re-checked on
2026-09-29: Mac mini M2 at USD 0.095 per minute. The account's September free minutes are exhausted
(596 rounded minutes used), so every minute is billed: 150 minutes is at most USD 14.25.

The manifest (`docs/verification/places-review-manifest.tsv`) is committed before any build:
- **`room`:** R1–R14. The recorded real journey, the capture of every state and overlay, and eleven
  behaviour tests run on the iPhone 17 Pro Max. The largest-text test also runs on the smaller iPhone.
- **`room_regression_main`** / **`room_regression_small`:** the 23 affected Places rows under their
  earlier IDs: entry and return, category, eligibility, age gate, footer and the Signal boundary.
- **Constraints:** one simulator at a time, no retries, and every build pinned to its exact commit by
  the source gate. A gate-validated row filter (`PLACES_ROW_FILTER`) can rerun only named rows; the
  verdict then names the rows it judged and never reports an unselected row as passed.
- **Planned builds (as first committed):** `room` on the 45-minute workflow; the fixes, if any, into one
  frozen candidate commit; then `room_regression_main` and `room_regression_small` on the 35-minute
  workflow. The 23 regression rows measured 1,964 s of test time in earlier builds, which cannot fit one
  serial 45-minute build.
- **Revised after build 1 (deviation, reported at once):** with every Room test running to its end, the
  Room rows alone are estimated at about 2,400 s of tests, more than one 45-minute build's UI deadline.
  With 116 minutes and three builds left, the remaining builds run one candidate commit, each selecting
  its rows with the gate-checked filter:
  - **build 2 (45 min):** R1–R6 and R8–R13 on the iPhone 17 Pro Max, then R14 on the smaller iPhone
    once that simulator is shut down;
  - **build 3 (35 min):** the 12 main-phone regression rows (`room_regression_main`);
  - **build 4 (35 min):** the 11 smaller-iPhone regression rows (`room_regression_small`).

  Before build 2, the unexecuted steps of the nine stopped tests were traced against the code and
  build 1's log. No further failure was found, and the full durations were estimated at about 1,300 s
  of tests for build 2.
- **Revised again after build 2 (deviation, reported at once):** 71 of 150 minutes are used, and 79
  minutes and two builds are left. That cannot hold every Room row plus both regression halves.
  - **Build 3 (45 min):** the ten rows build 2 failed (R1–R5, R8, R10–R12 on the iPhone 17 Pro Max,
    then R14 on the smaller iPhone).
  - **Build 4:** R6 and R13 again on the final commit, plus the 12 main-phone regression rows. It
    takes the 35-minute workflow only if build 3 bills 44 rounded minutes or fewer; otherwise the
    30-minute one, dropping rows if they cannot fit.
  - **As run (build 4, §7), after build 3 billed 30 minutes:** build 4 takes the 45-minute workflow (at most min(45, 49)).
    It uses scope `room_all` with rows R6, R13, the 12 main-phone regression rows, and R14 last on the
    smaller iPhone, on the final commit. Product files are identical to `b5ee804`; only the test helper
    differs.
  - **R9** (notes filtering and both block orders) passed on `82eef53` in build 2. On the final commit it
    stays unverified: every block goes through an actor-safety panel, and after each panel closes it
    waits on People's boundary line, which is in the bar that the final commit replaces under a panel.
    No remaining build has room for its 365 s beside the regression rows.
  - **Not run in this chapter:**
    - **The 11 smaller-iPhone regression rows** (`room_regression_small`). The Places regression on the
      smaller iPhone stays unverified after the Room's Places changes, so `room_regression` cannot be
      reported as PASS.
    - **R7**, as above.

  **R7** (the largest-text test on the iPhone 17 Pro Max) failed in build 1 and is not rerun: the budget
  does not fit it. The largest-text check on the iPhone 17 Pro Max therefore stays unverified. R7 is
  still a required row of the manifest, so the `room` scope as a whole cannot be reported as PASS; only
  the rows a build selected can be.

## 7. Results

### Build 1: `6abc1b808e9286d412451950`, scope `room`, commit `51fe52a7`

- **Timing:** the build ran from 20:11:54Z to 20:45:23Z, 33.5 minutes (34 rounded).
- **Verdict: AUTOMATED VERDICT FAIL.** 3 of the 14 required executions passed: R6, R9 and R13.
- **Build steps that passed:** app compilation on Xcode 26.6 (61 s), the Mac domain tests, and the
  test-harness compilation. The recording was confirmed.
- **Artifacts:** all four downloads match their `.sha256` files.
- **Failure 1, eight rows (R1–R5, R8, R10–R12).** Each failed at its first panel, on
  `XCTAssertFalse(room.leave.exists)`: the screen's own Leave, in its scroll view's bottom
  `.safeAreaInset`, was still in the accessibility tree under the panel, although the page carried
  `.accessibilityHidden`. The Places explanation's headline, inside Places' scroll content, was hidden
  under the Room, as the journey confirmed.
  - **Change in source for build 2:** the page's scrolling content and its bar each carried the hidden
    flag themselves, and Places' own bar did the same under the Room. Build 2 showed that this did not
    work (see there); it was replaced after build 2.
- **Failure 2, R7 and R14 (largest text).** The test's scroll helper failed on both phones.
  - **Four causes:**
    - it measured each panel against the hidden screen's bar (the cause above);
    - it used a fixed 62-pt top, while the 390-pt phone's chrome rests at y 50;
    - it gave up after 15 looks of at most 150 pt, when a target is about 2,000 pt away;
    - it asked 4 pt of clearance above the bar. At the page's end, "How Waves work" sits fully visible
      about 25 pt above Leave; the capture shows it.
  - **Change in source for build 2:** the helper's top is 62 or 47 pt by phone, it takes up to 40 looks
    and drags of up to 360 pt, and it keeps no margin above the bar. Build 2 showed these fixes were only
    partial (see there).
- **Captures showed a product defect.** At the largest size on the 390-pt phone, the compact ticket
  broke "Common" mid-word beside the art.
  - **Change in source for build 2:** only at the accessibility text sizes, and only when the name would
    need more lines beside the art than across the ticket, the ticket puts its text below the art at full
    width (§5 item 14). Build 2's captures confirm it (see there).

### Build 2: `6abc2ae1e51bc7fc79c09cd4`, scope `room` with rows R1–R6 and R8–R14, commit `82eef53`

- **Timing:** the build ran from 21:17:29Z to 21:53:46Z, 36.3 minutes (37 rounded).
- **Verdict: AUTOMATED VERDICT FAIL.** R6, R9 and R13 passed; the other 10 selected rows failed. The
  app compiled and the Mac domain tests passed.
- **The first change did not work.** Hiding the bar directly did not remove it: the screen's Leave was
  still in the accessibility tree under every panel. The same eight rows failed at the same line.
- **The change also moved a frame.** The flag on the bar made its single control report the whole
  440-pt bar as its frame:
  - `room.leave` on waiting, notes and profiles, and "Return to Places" on the ended screen;
  - this broke R2's frame checks and R14's bar check;
  - the same modifier had also been added to Places' bar, and it is reverted.
- **R14's other failure was the helper.** At the largest text the stacked People and Room notes tabs
  filled the helper's drag band on the smaller iPhone, and it would not touch down on a button.
- **The captures confirm the stacked ticket.** At the largest text on the smaller iPhone the ticket
  reads "Common / Ground" with no mid-word break: `room-notes-0-largest-390pt-fixture.png`, build
  `6abc2ae1`.
- **Changes in source after build 2 (not yet run on a Mac):**
  - **Room view:** under a panel, the page's bar is not built at all. An empty spacer of its last
    measured height stands in for it, so the dimmed page does not move. Nothing under the dim can be
    tapped: the dim takes every touch.
  - **Places view:** identical to `51fe52a` again.
  - **Scroll helper:** it shortens the drag when no touch-down point is free.

### Build 3: `6abc3654613b43be72355452`, scope `room` with rows R1–R5, R8, R10–R12 and R14, commit `b5ee804`

- **Timing:** the build ran from 22:06:21Z to 22:36:05Z, 29.7 minutes (30 rounded).
- **Verdict:** 9 of its 10 selected rows passed on the iPhone 17 Pro Max, first attempt, no retries:
  - R1, the recorded real journey from Common Ground's explanation through the Room and back to Places;
  - R2, the capture of every state and overlay;
  - R3 back gestures, R4 Business compatibility, R5 both entry gates, R8 Leave from every context;
  - R10 the Reduce Motion preview, R11 report isolation, R12 Social compatibility with both approaches.
- **R14 failed,** on the smaller iPhone at the largest text, only in the scroll helper.
  - **Correction (2026-09-30): this cause was wrong; see §II.5.** The element at 592.3 was Places' own bar
    under the Room.
  - **Cause, as first stated:** under a panel, the dimmed page's full-screen scroll view and the panel's differ by a
    rounding fraction (844 against 843.99999). The helper compared them exactly, so it treated a page
    element at y 592.3 as a fixed bar and refused panel buttons below it.
  - **The captures show those three panels hold:** Jules's safety, Maya's report and the Wave
    information. Each panel's actions, including its Leave, are on screen after scrolling:
    `room-jules-safety-0-largest-end-390pt-fixture.png`,
    `room-report-maya-harassment-largest-end-390pt-fixture.png` and
    `room-wave-info-largest-end-390pt-fixture.png`, build `6abc3654`. The global Safety panel's Leave at
    the largest text is not tested by any build.
  - **Change in source (not yet run on a Mac):** the helper compares scroll-view frames to within a
    point. This is a test-only change; the product files are identical to `b5ee804`.
- **The screen's bar is gone from the tree under a panel**, since the Leave checks passed. But the tests
  still see the dimmed page's other elements there: `accessibilityHidden` did not remove them from
  XCUITest's tree. Whether VoiceOver ignores them (the panel carries `isModal`, the page
  `accessibilityHidden`) is unverified.
- **Known defect, left unfixed** to keep the product frozen at `b5ee804`: at the largest text a scrolled
  panel's text passes under the status bar, which has no ground strip behind it. In
  `room-jules-safety-0-largest-end-390pt-fixture.png` (build `6abc3654`), "notes from" runs under the
  09:41 clock.
- **A stale code comment, also left for the next product change:** the comment above `layers` in
  `RoomView.swift` says the screen below a panel "is not an accessibility element"; build 3 found the
  dimmed page's elements still in XCUITest's tree.
- **Evidence:** `/home/proximeet/proximeet-room-review-6abc3654` holds Room-Review.zip, Room-Screens.zip,
  the unedited walkthrough, the unsigned simulator app and the small artifacts bundle. All four
  published `.sha256` files match.

### Build 4: `6abc3ebee1c7948817c7bb8b`, scope `room_all`, commit `c7716a1`

Rows: R6, R13, the 12 main-phone Places regression rows, then R14 on the smaller iPhone.

- **Timing:** the build ran from 22:42:13Z to 23:11:53Z, 29.7 minutes (30 rounded).
- **Verdict: 14 of 15 passed**, first attempt, no retries. The app compiled and the Mac domain tests
  passed. Every Places regression row passed on the iPhone 17 Pro Max:
  - C1, C2, C3 and P2 (the age gate on the way back);
  - P4, P1 (the real Places journey, now returning through the Room);
  - C4, C5, C9, C6, C7 and C8 (the Signal boundary).

  R6 (ineligible and stale entry refused) and R13 (terminal re-entry resets the demo) passed on the final
  commit.
- **R14 failed again**, at the same six panel reveals, with the same bar top of 592.3.
  - **The rounding explanation was wrong:** a within-a-point comparison of scroll-view frames did not
    change it.
  - **Correction (2026-09-30): this diagnosis was also wrong; see §II.5.** The element was Places' bar,
    not the dimmed Room page.
  - **Diagnosis, from builds 3 and 4, not verified on a Mac (superseded):** under a panel the dimmed page's elements
    stay in XCUITest's tree, as build 3 showed, but without a scroll-view ancestor there. The helper
    counts anything outside a scroll view in the lower half of the screen as a fixed bar in front of
    the panel.
  - **Next step, not done because no build is left:** in `RoomReviewTests.reveal`, ignore fixed bars
    when the target is inside a panel (identifier `roomPanel.*`), since nothing can be drawn over a
    panel. Then rerun R14 alone.
  - **The product side is shown by the captures, as in build 3:** the three largest-text panels show
    every action, Leave included, on screen after scrolling.
- **Evidence:** `/home/proximeet/proximeet-room-review-6abc3ebe` holds Room-All-Review.zip (its hash
  matches) with every capture, the verdict and the logs. Build 4's app zip was removed locally after a
  file-by-file comparison with build 3's Proximeet.app (identical; see the folder's README). Both
  remain on Codemagic.

## 8. Minutes and cost

The September free minutes were already used up, so every minute is billed at USD 0.095
(Mac mini M2), before tax.

| Build | Rounded minutes | Cost |
| --- | --- | --- |
| 1 (`6abc1b80`) | 34 | USD 3.23 |
| 2 (`6abc2ae1`) | 37 | USD 3.52 |
| 3 (`6abc3654`) | 30 | USD 2.85 |
| 4 (`6abc3ebe`) | 30 | USD 2.85 |
| **Total** | **131 of 150** | **USD 12.45 of 15** |

All four authorised builds are used. The Codemagic build list shows exactly these four builds on
2026-09-29, all on the Room branch; no other build, workflow or paid action was started.

## 9. Outcome

**Room automated checks: not all passed.** Row by row:

| Row | Check | Last result | Build | Commit |
| --- | --- | --- | --- | --- |
| R1 | real journey from Common Ground's explanation through the Room and back (recorded) | PASS | 3 | `b5ee804` |
| R2 | every state and overlay captured and checked at 440 pt | PASS | 3 | `b5ee804` |
| R3 | back gestures (completed, cancelled, nested, from ended) | PASS | 3 | `b5ee804` |
| R4 | Business compatibility | PASS | 3 | `b5ee804` |
| R5 | both deliberate entry gates | PASS | 3 | `b5ee804` |
| R6 | ineligible and stale entry refused | PASS | 4 | `c7716a1` |
| R7 | largest text on the iPhone 17 Pro Max | FAIL (not rerun) | 1 | `51fe52a` |
| R8 | Leave from every context | PASS | 3 | `b5ee804` |
| R9 | notes filtering and both block orders | PASS, not on the final product (§6) | 2 | `82eef53` |
| R10 | the app's Reduce Motion preview flag | PASS | 3 | `b5ee804` |
| R11 | report preview local, restores its caller | PASS | 3 | `b5ee804` |
| R12 | Social compatibility with both approaches | PASS | 3 | `b5ee804` |
| R13 | terminal re-entry resets the demo | PASS | 4 | `c7716a1` |
| R14 | largest text on the smaller iPhone | FAIL (builds 3–4 attributed to the test helper, unverified; correction (2026-09-30): see §II.5) | 1, 2, 3, 4 | `c7716a1` |

- **Product files:** `b5ee804` and `c7716a1` have identical product files. `c7716a1` changes only the
  test helper and docs.
- **Places regression, affected rows:**
  - **Main phone:** 12 of 12 passed on `c7716a1` (build 4).
  - **Smaller iPhone:** 11 rows not run (C15, P9, P10, P11, P12, P13, C10, C12, C13, C14, C11), so
    `room_regression` is not PASS.
- **Historical status, unchanged:**
  - the Places correction passed 15 of 15;
  - all 56 regression rows have passing executions;
  - B2's build-5 failure and the interruptions are retained;
  - the strict regression gate stays **FAIL** (§2).
- **Not claimed:** VoiceOver, the system Reduce Motion setting (R10 uses the app's own preview flag),
  device, TestFlight or App Store behaviour. The global Safety panel at the largest text is untested.

## 10. Deliverables

The deliverables are in `/home/proximeet/proximeet-room-review-6abc3654`, from build 3; its README
describes each file:
- `Room-Review.zip`, the offline viewer;
- `Room-Screens.zip`: all 15 states, 8 overlays and 4 report variants at 440 pt, the 14 real-journey
  frames and the smaller-iPhone largest-text screens;
- the unedited `Room-walkthrough-original.zip`;
- `Room-walkthrough.mp4`, trimmed on the VPS: 75.5 s, from the explanation to Back to Signal;
- the unsigned simulator app `Proximeet-Debug-iphonesimulator-b5ee804eb160.zip`, with `Proximeet.app`
  at its root.

**Codemagic:**
- **Build page, authenticated:**
  https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6abc3654613b43be72355452
- **Artifact name:** `Proximeet-Debug-iphonesimulator-b5ee804eb160.zip`

**Appetize:** no existing authorised Appetize access was available, and none was searched for. The one
upload action is the founder's:
1. At appetize.io, upload that zip as a new iOS app.
2. In its App Permissions, set run = authenticated.
3. Open its link in a signed-out private window and confirm it will not run.

These are the same private-preview safeguards as `places-recovery-01.md` §10 and
`/home/proximeet/proximeet-preview/README-PREVIEW.md`. To reach the Room, walk Welcome → More options → Continue the demo (no account) → Birthday → Pass →
Guest List → Wristband (Social or Business) → Signal → Places → View place (Common Ground, Now) →
Preview check-in → Preview room demo.
