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
- **Planned builds:** `room` on the 45-minute workflow. The fixes, if any, go into one frozen candidate
  commit. `room_regression_main` and `room_regression_small` then run on the 35-minute workflow. At
  most 45 + 35 + 35 + 35 = 150 minutes.
- **Why the regression is split:** the 23 rows measured 1,964 s of test time in earlier builds, which
  cannot fit one serial 45-minute build.

## 7. Results

Pending the first build.

## 8. Minutes and cost

Pending.
