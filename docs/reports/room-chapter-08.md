# Room chapter 08: implementation and Mac verification

Date: 2026-09-29. Not production-ready.

**Status: implementation committed; Mac verification in progress.** Nothing in this report has run on
a Mac yet unless a build is cited. Every Mac result below names its Codemagic build and commit.

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
  - **As now planned, after build 3 billed 30 minutes:** build 4 takes the 45-minute workflow (at most min(45, 49)).
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
  - **Cause:** under a panel, the dimmed page's full-screen scroll view and the panel's differ by a
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

## 8. Minutes and cost

The September free minutes were already used up, so every minute is billed at USD 0.095
(Mac mini M2), before tax.

| Build | Rounded minutes | Cost |
| --- | --- | --- |
| 1 (`6abc1b80`) | 34 | USD 3.23 |
| 2 (`6abc2ae1`) | 37 | USD 3.52 |
| 3 (`6abc3654`) | 30 | USD 2.85 |
| **Total so far** | **101 of 150** | **USD 9.60 of 15** |
