# Places recovery 01: diagnosis, corrections and the verification plan

Date: 2026-09-27. Not production-ready.

**Status:**
- **Recovery build 1** (`6ab8adb429a3df446d9749a3`, on `907d7401`) passed 14 of its 15 required
  correction rows. C12 found a small product defect.
- **Recovery build 2** (`6ab8c585873de42fcd4f1a8a`, on `808950f8`, with the correction) passed C12
  and the other five smaller-iPhone rows. On the iPhone 17 Pro Max its test runner failed to
  initialize for UI testing, and no test ran there (§7).
- **Builds 3 and 4** are PENDING. Nothing after `808950f` has run on a Mac. The infrastructure rerun
  and the `gate_finish` and `sweep_finish` scopes are untested on a Mac; build 3 is their first run.
Build `6ab8801175ac3236c0f1514f`, on `358f59f1204c02fa167d21ebd9e6226d8799ff02`, failed the targeted
correction: 8 of 13 required executions passed (`places-correction-01.md` §6). This recovery:
- diagnoses that build's five failures and one interruption from its logs, keeping what is proven
  apart from what is a hypothesis (§2);
- makes two product changes: a shared one-stage Places Back that now also answers VoiceOver's
  escape, and (after build 1's C12) a Back to places that aligns browsing again once the detail has
  gone; it also replaces the UI tests' scroll helper with one that checks its own progress, and
  adds a debug-only diagnosis switch (§3);
- records the lead's ruling on the DEMO badge and the obsolete banner (§4), and why no browser
  preview was opened (§5);
- plans four sequential builds on one frozen commit (§6); after build 1 changed the product, three
  remain on a new frozen commit: the correction gate again, one merged sweep, the regressions.

Linux cannot compile the SwiftUI app, so no check on the VPS shows the app working. The Linux checks
of the frozen commit are recorded in §7 when it exists.

## 1. Baseline and provenance

| | |
| --- | --- |
| Recovery branch | `places-recovery/verification-20260927T035353Z`, created from `ae908de411859dad61db27aa34a647ff6604a3a4` with `git worktree add` at `/home/proximeet/proximeet-cloud-places-recovery-20260927T035353Z`. Earlier branches and worktrees are untouched |
| Mac-tested source | `358f59f1204c02fa167d21ebd9e6226d8799ff02`: build `6ab8801175ac3236c0f1514f`, scope `correction`, AUTOMATED VERDICT: FAIL (8 of 13) |
| `ae908de` against it | One commit on top of `358f59f1` (`git merge-base --is-ancestor` confirms the ancestry). `git diff --name-status 358f59f1204c02fa167d21ebd9e6226d8799ff02 ae908de411859dad61db27aa34a647ff6604a3a4` lists four modified files and nothing else: `ProximeetUITests/PlacesCorrectionTests.swift`, `ProximeetUITests/PlacesReviewTests.swift`, `docs/reports/places-correction-01.md` and `docs/verification/places-review-files.sha256`. No product, project, workflow or script file differs |
| `ae908de`'s test repairs | Mid-page drags (`dx: 0.5`) in both scroll helpers (at `ae908de`: `PlacesCorrectionTests.swift:589`, `PlacesReviewTests.swift:1170`), a give-up note (`PlacesCorrectionTests.swift:608`), and `minimumTarget = 44 − 0.001` (`PlacesReviewTests.swift:78`) in the review tests only. None ran on a Mac. §3 replaces the helper and the tolerance |
| Preserved | the approved artwork, fonts, copy, layout, motion, catalog, fictional venue schedule and eligibility policy; DEMO and "Demo · no location or camera used."; no location or camera use; no permission strings |
| Evidence of build 6ab88011 | `/home/proximeet/proximeet-places-correction-review-6ab88011/Places-Correction-Review.zip`, SHA-256 `c6b68d1000340df24d9c1814560cf62d6fe7657c9d134a379e335c4dff80a9bc` (matches its `.sha256`), with `Places-Correction-Screens.zip` and `Places-Correction-walkthrough.zip`. Log line numbers below are in that package's `logs/` folder |

## 2. Why build 6ab88011 failed: evidence and hypotheses

Code references in this section are to `358f59f1`, as built (`git show 358f59f1:<path>`). The main
lane's log is `places-ui-review.log` (iPhone 17 Pro Max, 440 pt); the smaller lane's is
`places-ui-review-device-b.log` (iPhone 17e, 390 pt).

All four scrolling failures used the same helper, `scrollIntoView`
(`PlacesCorrectionTests.swift:582-604`, and its twin in `PlacesReviewTests.swift:1161`):
- up to 40 drags, each from y 217 to y 102, pressed at 96 % of the width (`:584`): x 422.4 on the
  440-pt phone, x 374.4 on the 390-pt phone;
- no frame, position or screenshot was logged inside the loop, so where each loop stopped is
  unknown.

| Row | Classification | Confidence |
| --- | --- | --- |
| C3 | Time budget | Proven |
| C15 | Floating-point representation in an exact comparison | Proven |
| C2 | Harness; the mechanism is unproven | High that it is not a product defect; medium on the mechanism |
| C12 | Harness; the mechanism is unproven | Medium |
| C13 | Harness; the mechanism is unproven | Medium |
| C1 | Open | — |

**C3 (main, the default-text footers): the run's time bound. Proven.**
- The run `correction_main` (C1, C2, C3) was bounded at 600 s (`places-ui-review.log:360`). Its
  test runner printed "Running tests..." at 02:42:33.8 (`:378`), about five minutes after the run
  began.
- C1 started at 02:43:10.08 (`:386`), C2 at 02:45:59.78 (`:1122`) and C3 at 02:47:16.06 (`:1673`).
  The bound stopped the run about 10–14 s after C3 started, before any assertion: the run's 600-s
  bound fell between 02:47:26 and 02:47:30 (its `bounded_test` started after the 02:37:26
  places-parallel line in summary.txt and no later than the result bundle's 02:37:30.1 start). C3's
  launch was still waiting for the app to idle (that step began at t = 6.46 s, `:1682`); the stop is
  `:1683`, and the run exited 142 (`:2222`). This agrees with `places-correction-01.md`'s "11 s after
  it started".
- C1 and C2 together took 246 s. The analysis of their step timestamps puts about 150 s of that in
  the two loops that stalled.
- The same test on the smaller phone (C14) passed in 27.2 s.
- Not ruled out: nothing about the product. The approved 440-pt footer at the default text is
  simply unverified. Why the main runner needed about five minutes to start is unknown.

**C15 (smaller, Back routes): floating-point representation. Proven.**
- The failing assertion is `XCTAssertGreaterThanOrEqual(tab.frame.height, 44)`
  (`PlacesReviewTests.swift:897`), logged at `places-ui-review-device-b.log:2476`:
  "43.99999999999997 is less than 44.0".
- 43.99999999999997 is 44 − 2.84 × 10⁻¹⁴, four units in the last place below 44. The tab's layout
  minimum is 44 (`PlacesView.swift:502`, `.frame(maxWidth: .infinity, minHeight: 44)`).
- A frame at a fractional position gives exactly that value: `(y + 44) − y` is 43.99999999999997 for
  y = k + 2/3 with k from 212 to 255, and 44.0 for k from 128 to 211 (checked in Python on the VPS).
- It came right after `places.back.doubleTap()` from Afterglow's detail
  (`PlacesReviewTests.swift:383`). At `358f59f1`, going back from a detail scrolls browsing to the
  originating ticket's end (`PlacesView.swift:284`), which can leave the tabs at a fractional y.
  `ea14c001` had no such scroll, and build 6ab8639c passed this test (P8, 64.0 s).
- Classification: the test's exact comparison, not a product defect. A product change (the scroll on
  Back) exposed it.
- The same hazard was left at `ae908de` in `PlacesCorrectionTests.swift:490`
  (`XCTAssertGreaterThanOrEqual(button.height, 44, …)`); `ae908de` applied its 44 − 0.001 tolerance
  only in `PlacesReviewTests.swift`.

**C2 (main, largest text): the harness. The mechanism is unproven.**
- Decisive: C2 scrolled the same page (Now, 440 pt, largest text), on the same device, with the same
  helper and x, as C1's first loop, which reached View place in 14 drags (`places-ui-review.log`
  lines 401–570). C2 made 40 drags (lines 1151–1658) and failed at `PlacesCorrectionTests.swift:176`
  (`:1669`): "Common Ground: View place reachable."
- The only difference in app state is a tap on the Now tab, which was already selected. That tap
  changes nothing: `DemoFlow.choosePlaceCategory` returns false for the selected category
  (`DemoFlow.swift:280`).
- What differed was the pace. Of C2's drags that started within 0.2 s of the previous release, 16
  of 23 were followed by at least 0.2 s of app activity. In C1's loops that happened once, and in
  build 6ab8639c's passing largest-text loop on the 440-pt phone (left-margin drags, `dx` 0.04)
  never, in 9 such drags. These counts come from the XCTest step timestamps; they are a
  correlation, not a mechanism.
- Not ruled out: whether the page moved backwards or stood still (no frames), and which mechanism
  took the drags. The candidates:
  - **The scroll indicator.** Public user sources (not Apple documentation) describe pressing on
    the iOS scroll bar to grab it and scrub the page. The drags pressed about 11.6 pt left of the
    visible 3-pt bar on the 440-pt phone (9.6 pt on the 390-pt phone). The bar stays visible about
    1.1 s after the page stops, so a drag that follows quickly lands while it is shown. A grabbed
    bar dragged upward scrolls the page back, which fits 40 drags without progress. The bar's touch
    target and hold time are not documented, and a grab was never observed.
  - **The window-wide repeat-tap guard** (`RepeatTapGuard.swift:56`, `tapCount > 1`, which cancels
    the touch, `:49`). It existed unchanged in build 6ab8639c, whose left-margin drags with gaps of
    0.15–0.19 s were not swallowed, so it is unlikely. C2's shortest gaps were 0.09 s, so it is not
    excluded.
  - **Unlikely: the new edge pan** (`PlacesEdgeBack.swift:141-148`), which every scroll-view pan
    waits for. It fails at once for a touch that does not start at the leading edge, and the C10
    recording shows a right-edge drag moving the page 107 pt for a 115-pt finger movement from the
    first changed frame. A timing interaction with it at the largest text was not tested.

**C12 and C13 (smaller, largest text): the harness. The mechanism is unproven.**
- C12's first scroll, 40 drags from (374.4, 217) to (374.4, 102)
  (`places-ui-review-device-b.log` lines 926–1433), never brought View place into range; it failed
  at `PlacesCorrectionTests.swift:210` (`:1444`).
- C13's first two drags (lines 1465 and 1478, 1.11 s apart) reached its tab. After the tap on Now
  (line 1491), 40 more (lines 1503–2010) did not reach View place; it failed at
  `PlacesCorrectionTests.swift:176` (`:2021`).
- Both show C2's signature: of the drags that started within 0.2 s of a release, 17 of 18 (C12) and
  15 of 19 (C13) were followed by at least 0.2 s of app activity, and the press-to-press intervals
  alternate (about 1.12 / 1.57 s in C12, 1.18 / 1.7 s in C13).
- Not ruled out: reaching View place at the largest text on the 390-pt phone was never observed in
  this build. Forty drags against the roughly 15 the page needs suggest movement backwards, not just
  lost drags.

**C1 (main, largest text, where a stage starts): open.**
- The first loop, on browsing, reached View place in 14 drags (lines 401–570), and the detail it
  opened started at its beginning (capture). The second loop, 40 drags on Common Ground's detail
  (lines 600–1107), never reached the detail's last line; the test failed at
  `PlacesCorrectionTests.swift:219` (`:1118`).
- C2's timing signature is absent: of the 53 drags in C1 that followed another drag, only 3 started
  within 0.2 s of its release. The main simulator was slower instead (each drag took 1.2–3.2 s),
  most likely from the other lane's load on the shared Mac.
- **No drag in this build ever scrolled a detail, at any text size.** Two product changes on the
  detail are therefore unobserved rather than cleared:
  - scrolling after `revealStart`'s animated `scrollTo(.top)` (`PlacesView.swift:276-291`);
  - scrolling while iOS 26's swipe-from-anywhere pop is held off on inner stages
    (`PlacesEdgeBack.swift:83-93`, `contentPop.isEnabled = !innerStage` at `:92`). A disabled
    recognizer should not block others; that is expected, not shown.
- Build 6ab8639c (left-margin drags, before `PlacesEdgeBack` and `revealStart` existed) passed the
  largest-text reachability tests on both phones (P3, P11). Between its commit and `358f59f1` the
  product changed only in `PlacesView.swift` and the new `PlacesEdgeBack.swift`, including the
  ticket that the detail shares with browsing.
- Neither a harness cause nor a product cause is established. There is no give-up screenshot and no
  frame.

**What the next build decides.**
- **The new scroll helper (§3)** prints one `PLACES_SCROLL` line per drag (the touch-down, the
  travel, the target's top before and after, how far the header moved, any sideways movement, the
  stage's last line and the bar). A failure is tagged:
  - `Scroll PRODUCT:` when the page has reached its end (the stage's last line is above the bar) or
    its start with the element still out of range: a product finding;
  - `Scroll HARNESS:` when a drag moved the page the wrong way, sideways, further than the finger
    twice, or not at all twice, or the screen changed: the per-drag trace then shows which drag.

  It attaches a note and a screenshot either way. Its drags touch down inside the content column,
  away from both screen edges and every control, at least 0.7 s after the previous lift, so both
  suspected mechanisms are avoided. If C1, C2, C12 and C13 pass with it, that shows the Places
  pages reach their targets; it does not say which mechanism stopped the old drags.
- **The optional probe**, `PlacesCorrectionTests/testScrollDiagnosticProbe` (C16 on main, C17 on
  the smaller phone; kind "diagnostic": it runs last on each device only when it fits, and its
  outcome is reported but never counts toward a verdict), exists to answer that. At the largest text, on
  browsing (Now) and on Common Ground's detail, each launched fresh at its top, it makes five drags
  from y 217 to y 102 in each pattern and prints a `PLACES_PROBE` line per drag (the gap since the
  previous release, and how far the header moved):
  - A, `edge-fast`: the old helper's, at 0.96 of the width, the next drag at once;
  - B, `edge-spaced`: the same, with 1.5 s between one release and the next drag;
  - C, `column-spaced`: in the page's column, on no control, 0.7 s apart;
  - on the detail, C again with the debug-only `-ProximeetPlacesKeepContentPop YES` (§3), which
    leaves iOS 26's swipe-from-anywhere pop enabled.

  It records and does not judge. How to read it:
  - A stalling where B moves points to the pace at the edge.
  - A and B stalling where C moves points to the edge position.
  - C stalling on the detail only without the switch points to the held-off pop.
  - C stalling on the detail with and without it points to the app.

  It cannot by itself tell the scroll indicator from the repeat-tap guard, since both need a quick
  second touch. PENDING. If its run does not fit before the deadline it is listed as not run, and
  nothing required depends on it.

## 3. The corrections in this recovery

Each item is the intended behaviour and the rows that check it. Builds 1 and 2's results are in §7:
build 1 ran 907d7401, before item 5, and build 2 ran 808950f. Nothing after `808950f` has run on a
Mac. Files in this section are cited by
symbol: several changed while this report was written.

1. **One shared, one-stage Places Back (product).**
   - `DemoFlow.placesBack(from:)` (domain, `@discardableResult`, mutating) goes back one stage from
     the stage the request was made on: browsing to the actual Signal (`leavePlaces()`), a detail to
     its originating category (`leavePlaceDetail()`), the explanation to Common Ground's detail
     (`backToPlace()`). A request from a stage that is no longer showing, or from off Places, does
     nothing, so one request never goes back two stages. The intent, approach, introduction and
     category are kept. `DemoSession.placesBack(from:)` forwards to it.
   - Every Back on Places goes through `PlacesView.back(from:)` and that function: the header's
     Back, the bottom Back on browsing (before, it called `leavePlaces()` directly), "Back to
     places", "Back to place", a completed swipe from the leading edge, and VoiceOver's escape.
   - **VoiceOver's escape is new.** Each Places stage is one unlabelled accessibility container,
     `places.screen` (`.accessibilityElement(children: .contain)`), which owns the escape action
     and sits above every element, so the stack's own pop (which would leave the whole destination
     for Signal) is not what answers it. Escape is ignored while a completed swipe is finishing, as
     a second swipe is. The elements keep their identifiers, labels, traits and order.
   - Motion is unchanged: browsing leaves by the stack's native pop; an inner stage dissolves
     (240 ms, none under VoiceOver) or, after a completed swipe, changes at once.
   - This supersedes `places-correction-01.md` §3's "VoiceOver's escape gesture is not handled by
     Places", which describes `358f59f1`.
   - Checked by:
     - on Linux (§7): `PlacesBackTests` (the route from every stage, requests from a stage no longer
       shown, nothing off Places), `PlacesBackWiringTests` (reads `PlacesView.swift` as text: one
       `places.screen` container owning the escape action, and every Back control through the
       shared route), and the random-action `DemoFlowInvariantTests`;
     - on the Mac: C11, which also asserts exactly one `places.screen` on browsing, a detail and the
       explanation, with the stage's headline or name, header Back and bottom actions found by
       queries scoped to it; C10 and C15 (swipes, the Back controls, a double tap on the header
       Back); and every Places UI test, which would fail to find its elements if the container hid
       them.

     That is the structure escape relies on, not escape itself. XCUITest cannot perform VoiceOver's
     escape and VoiceOver does not run in the Simulator: **PENDING FOUNDER**, on a device (§8).
2. **A scroll helper that checks its own progress (tests).** It replaces `scrollIntoView` in
   `PlacesCorrectionTests` and `PlacesReviewTests` with one identical block.
   - Where it touches: a half, a quarter or three quarters across the page's column (81 pt or more
     from either screen edge on the 390-pt phone), clear of every control by 12 pt, and off
     browsing's ticket unless no other point exists. It waits at least 0.7 s after each lift and
     prefers a point 60 pt from the last drag.
   - What it checks: after each drag, the target's settled frame. The page must move the right way
     by a quarter of the drag and at least 2 pt; no drag may carry the element past the far side of
     the accepted range. The acceptance rule itself is unchanged.
   - What it reports: the `PLACES_SCROLL` trace and the PRODUCT or HARNESS verdict (§2). It still
     returns `Bool`, so no call site changed.
   - Checked by: C1, C2, C12 and C13 (build 1), and every Places review row that scrolls, among them
     P3 and P11 (the sweep). On Linux it can only be type-checked against a shim of the XCUITest types
     (§7), so the real `XCUIElement.snapshot()` and `XCUIElementSnapshot` signatures are unconfirmed
     until the Mac compiles them.
3. **A documented 1e-6 epsilon for the 44-pt target checks (tests).** A 44-pt control may measure
   44 − 1e-6 or more; a real shortfall is far larger than any floating-point error. It replaces
   `ae908de`'s `44 − 0.001` and the exact comparison it left in `PlacesCorrectionTests`. Checked by
   C15 (= P8) and every row that asserts a 44-pt target.
4. **A debug-only diagnosis switch (app, DEBUG builds only).** With `-ProximeetPlacesKeepContentPop
   YES` in a DEBUG build's launch arguments, `PlacesEdgeBack` leaves iOS 26's
   `interactiveContentPopGestureRecognizer` enabled on a detail and the explanation instead of
   holding it off. Without the switch nothing changes, and a Release build never reads it (`#if
   DEBUG`). Only the probe's last detail pattern used it (build 6ab8adb4's C17; C16 was left unrun
   and no scope runs the probe any more), and the probe records rather than judges, so nothing
   asserts the switch's effect. The default behaviour, without it, is what C10 and C11 check.
5. **Back to places aligns browsing again once the detail has gone (app, after build 1).** Added
   after build 1's C12 (§7). It was observed on the 390-pt iPhone 17e in build 2: C12 passed and was
   photographed. It is not yet observed on the 440-pt iPhone 17 Pro Max (C1, build 3).
   - The scroll that `revealStart` issues when the stage changes still runs, so the dissolve shows
     roughly the right place.
   - When the dissolve completes (or at once after a swipe's instant change), a `@State` token asks
     the `ScrollViewReader` to align the ticket's end with the bottom of the visible page again,
     now against browsing's own content and action bar. It is animated over 0.2 s, and instant
     under Reduce Motion or VoiceOver. It does nothing if another stage is showing by then.
   - `PlacesScrollTarget.ticketEnd` is now the 25-pt gap between the ticket and its line: a
     `Color.clear` of that height replaces the line's `.padding(.top, 25)`. The layout is intended
     to be identical, so an aligned ticket stops 25 pt above the bar.
   - No timer is used; the Places source guard forbids them. The completion of the existing
     animation drives it.

Nothing else in the product changed: no copy, layout, motion, artwork, catalog, eligibility,
permission, location or camera behaviour.

## 4. The DEMO disclosure and the banner

**The lead's ruling.** The earlier Project Halo doctrine required a literal "PROTOTYPE — mock data
only." banner, gated on a `PROTOTYPE` build condition, with brand strings in `BrandConfig.swift` and
its own bundle identifier. For these rebuilt screens that literal requirement is obsolete. No banner
is added, because no approved design has one: Welcome's approved handoff says "do not add an
unapproved banner that changes the settled Welcome composition"
(`docs/design/welcome-approved/CLAUDE_PROMPT.md:115`), and Welcome's runtime check 2.5 is "no
banner, badge, navigation bar or demo label on Welcome"
(`docs/verification/welcome-runtime-review.md:36`).
The disclosure the banner served is not weakened: the app must make clear it is a demo with
fictional data that uses no location or camera. The fictional venue schedule, the eligibility rules
and the no-location, no-camera behaviour are kept. The ruling is now in `CLAUDE.md:7` and in
`places-correction-01.md` §3.

**Where the app discloses it.**

| Screen | What it shows | Where |
| --- | --- | --- |
| Welcome | No badge, as approved. The only way on, into Birthday, is "Continue the demo (no account)" | `Proximeet/Scenes/WelcomeView.swift:223` |
| Pass | DEMO badge; "No age or identity verification is performed." | `Proximeet/Scenes/PassView.swift:92`, `:48-49` |
| Guest List | DEMO PROFILE badge | `Proximeet/Scenes/GuestListView.swift:137` |
| Wristband | DEMO badge | `Proximeet/Scenes/WristbandView.swift:99` |
| Signal | DEMO badge | `Proximeet/Scenes/SignalView.swift:121` |
| Places, every stage | DEMO badge in the shared header (`places.demoBadge`) | `Proximeet/Scenes/PlacesView.swift`, `header(_:)` |
| Places browsing | "Fictional venues · demo Thursday, 8 pm" | `ProximeetDomain/Sources/ProximeetDomain/Places.swift:10` |
| Places tickets | "Fictional venue · Café", "… · Listening lounge", "… · Creative workshop" | `Places.swift:68-70` |
| Places explanation | "Fictional venue · Today, 6–10 pm" and "Demo · no location or camera used." | `Places.swift:194`, `:200` |

Birthday shows no badge, as approved; it is reached only through Welcome's demo route.
- The bundle identifier is the provisional `com.proximeet.demo`
  (`Proximeet.xcodeproj/project.pbxproj:498`, `:525`), as `docs/tasks/TASK_01.md:6` requires. There
  is no `BrandConfig.swift` and no `PROTOTYPE` condition.
- The project sets no permission usage strings (`scripts/validate_project.py:640-642`). The
  validator forbids location APIs (`:954-960`) and the legacy bundle identifier in every non-`docs/`
  text file (`:973-978`).

## 5. A browser preview: not opened

**Codemagic App Preview.**
- The docs say: "This feature is available for teams only."
  (docs.codemagic.io/yaml-distributing/app-preview/, read 2026-09-27).
- This account appears to be personal: it builds on the 500 free monthly M2 minutes, which Codemagic
  reserves for personal accounts. The API calls available did not confirm it; they return only an
  owner id.
- Enabling it would need a paid team ("Teams is a paid feature on Codemagic") and a transfer of the
  app into it, which is permanent ("Once an application has been transferred to a team, it cannot
  be transferred back to the personal account or to other teams"). The assignment forbids both.
- Also, Quick Launch is offered next to a `.app` artifact of a successful build. Before this
  recovery no build published one; recovery build 1 (6ab8adb4) published `Proximeet.app` (§7), but
  it failed its verdict, and the account has no App Preview anyway.

**Appetize.**
- It needs the founder's own sign-in or an Appetize API token. There is no token on the VPS. The
  only one known is a GitHub Actions secret on the legacy repository, which is write-only and usable
  only by that repository's own workflow runs.
- The agent could not operate a browser session and did not test one.

**The upload-ready artifact.**

| | |
| --- | --- |
| File | `Proximeet-Debug-iphonesimulator-358f59f1204c.zip`, inside `Places-Correction-Review.zip` at `Places-Correction-Review/app/` |
| Size and SHA-256 | 24,732,698 bytes; `48e1d333b758277a3f07ea4cddc1ebf47e576be36ce2b6724911746a623260f8` (matches its `.sha256`) |
| Source | `358f59f1`, built by build 6ab88011: unsigned Debug, iOS Simulator, arm64 only, bundle `com.proximeet.demo`, minimum iOS 17.0, iPhone Simulator SDK 26.5 |
| Label | "Prototype — Places verification pending" |
| Caution | It predates this recovery's product change (§3): it has the one-stage Back controls and swipe, not the escape action |

**The founder's steps, if he chooses to preview it.** A plain launch on the real route, with no
test fixtures.
1. Sign in at appetize.io in your own browser, on the account that already holds the earlier
   preview.
2. Before uploading, go to Organization → Session Defaults → Permissions (Legacy). Set **run** to
   authenticated, and the same for debugLog, networkProxy and networkIntercept, so the new build is
   never runnable by anyone who has its link.
3. Upload the inner file, `Proximeet-Debug-iphonesimulator-358f59f1204c.zip`, not the review zip,
   with the note "Prototype — Places verification pending". It creates a new app,
   `com.proximeet.demo`. Do not update the earlier preview's entry. If the plan refuses a second
   app, stop and decide.
4. Open the build → Settings → App Permissions and confirm **run = authenticated**.
5. Open the app's link while signed in. Choose the iPhone 17 Pro Max and iOS 26.0, and launch it
   with no launch arguments. It opens at Welcome: More options → "Continue the demo (no account)" →
   Birthday → the Pass → the Guest List → the Wristband → Signal → Continue preview → Places.
6. Optional, your decision: to let the agent drive sessions without a browser, generate an API token
   (Organization → API Tokens, Developer role) and put it in a file on the VPS readable only by the
   agent's account, never in git or chat. Whether a token-started session may run a build set to
   authenticated is inferred, not documented, and sessions use your metered minutes.

**Parity gaps.**
- Build 6ab88011's tests ran on iOS 26.5 simulators. Appetize's device list (fetched 2026-09-27)
  offers the iPhone 17 Pro Max on iOS 26.0 only, its highest version, so a preview is not the tested
  runtime. That the app installs there is inferred from its iOS 17.0 minimum.
- Appetize has no iPhone 17e.
- A plain launch shows the default text size, so the largest-text rows are not reproduced by it.

## 6. The build plan

**As planned before build 1:** four builds on one frozen commit (`907d7401`): the correction gate,
then `sweep_places`, `sweep_signal` and `regressions`. Build 1 ran the correction gate and found a
product defect (§7), and the fix changes product code. Nothing measured at `907d7401` can count
toward the final verdict, so the plan was revised.

**Now: three builds, one at a time, on one new frozen commit.** That commit holds the product fix,
this recovery's tests, manifest, harness and workflow. Each build is pinned by
`PLACES_EXPECTED_COMMIT`, and the source gate rejects anything else.

| | |
| --- | --- |
| Frozen commit | PENDING (the commit that adds this section) |
| Workflow | `proximeet-places-review-35`: 35 minutes, `PLACES_UI_DEADLINE_SECONDS=1740` (the harness accepts 600–1740). It was 1680 for build 1. It was raised because build 1 measured the main device's first test 666 s after the harness's gate. The worst-case end is 2032 s of the 2100 |
| Machine | Mac mini M2 (`mac_mini_m2`), Xcode 26.6, unsigned simulator; retries off |
| Order | A build starts only after the previous one's verdict and evidence have been read |

| Build | Scope | iPhone 17 Pro Max ("main") | Other device |
| --- | --- | --- | --- |
| 2 | `correction` (C16/C17 probes removed) | `correction_first` [C3] 600 → `correction_main` [C1, C2] 700 → `correction_signal` [C4, C5, C9, C6, C7, C8] 600 | iPhone 17e: `journey` [C10, recorded] 420 → `correction_small` [C12, C13, C14, C15] 780 → `correction_small_b` [C11] 240 |
| 3 | `sweep` | `places_main` [P1 (short holds, not recorded), P2–P6] 900 → `signal_main` [S3, S4, S5, S6, S8, S9, S10, S12, S13] 900 | iPhone 17e: `places_small` [P9–P13] 900 → `signal_small` [S15, S16] 420 |
| 4 | `regressions`, rows unchanged | `main_early` [M1, M2] 780 → `main_rest` [M3–M13] 1000 | device B (a Pro Max clone): `paste_b` [B1] 480 → `regressions_b` [B2–B13] 1000 → `paste_repeat_b` [B14, repeat, time-gated] 300 → `hardware_keys_b` [B15] 240 |

- **Coverage.** 64 required executions across the three builds (15 + 22 + 27), plus the optional B14.
  - Seven correction rows are the same check as an earlier row: same method, device, commit and kind
    of run (P7 = C9, P8 = C15, S1 = C4, S2 = C5, S7 = C6, S11 = C7, S14 = C8).
  - The other 49 earlier executions run in `sweep` and `regressions`.
  - `docs/verification/places-recovery-coverage.tsv` lists every execution. The command
    `scripts/places_recovery_reconcile.py <three build folders>` passes only when every required row
    passed on its device, on one commit.
- **Predicted, from measured timings.**
  - **Build 2:** like build 1, about 25 minutes. Build 1's main lane's last test ended 341 s before
    its 1680-s deadline.
  - **Build 3, the thin one.** A review of the measured timelines put the main lane, with P1 as a
    recorded journey, at only 65–140 s before the deadline, and gave it a 5–15% chance of
    overrunning.
    - Its inputs: first tests at 590–666 s after the gate; P2–P6 at about 265 s with the new helper;
      the journey's own close and gap of about 81 s; result-bundle closes of about 25 s.
    - So P1 runs in `places_main` with short holds and is not recorded. Its assertions and device
      are the same.
    - That saves the journey run's own start and close. The expected margin is then about 150–195 s.
    - This is the one run-type difference the reconciliation accepts, and it is stated there.
    - The recovery's walkthrough video is the correction's C10. The full real route is still
      executed, unrecorded, by P1 and by C8.
  - **Build 4:** at about gate + 1500–1550 s on each lane, a margin of about 190–240 s.
    B14 will probably be left unrun for time, which is allowed.
  - **Minutes:** about 25 + 30 + 28 on top of build 1's 25, so about 108 of the 120.

**After build 2: the last two builds.** Build 2's iPhone 17 Pro Max ran nothing, so 79 of the
120 minutes and two of the four builds remain. The correction gate's nine 17 Pro Max rows and the
49 earlier rows cannot all fit in two builds. Both builds run on one commit (the one that adds this
section, or a later harness- and document-only one), whose product and test files are identical to
`808950f`; only the harness and documents differ. So
build 2's passed rows count toward the same verdicts.

| Build | Scope | iPhone 17 Pro Max ("main") | Other device |
| --- | --- | --- | --- |
| 3 | `gate_finish` | C3 → C1, C2 → C4, C5, C9, C6, C7, C8 (the gate's nine rows, required) → extra: S3, S4, S5, S6, S8 | iPhone 17e, extra: P9–P13 → S15, S16 |
| 4 | `sweep_finish` | P1 (short holds, not recorded), P2–P6, S9, S10, S12, S13 → M1, M2, M3 (required) | device B (a Pro Max clone): M4–M13 → B1 → B10–B13 → B15 (required) |

- **Order of priority.** The gate first. Then the Places and Signal rows, which sit nearest the
  change. Then the Wristband, the Pass, Birthday and Welcome.
- **Left pending, not scheduled:** the Guest List rows B2–B9 and the optional repeat B14. The Guest
  List view and its tests are unchanged since `b06707ec`, where they last passed. The shared route
  files (`DemoFlow`, `DemoSession`, `DemoScene`, `RootView`) have changed since then, so they are
  not claimed at `808950f`.
- **Extras.** Rows marked extra start only when their bound plus 60 s is left. If they run they must
  pass; otherwise they are listed as not run.
- **Reconciliation.** `scripts/places_recovery_reconcile.py` joins the builds row by row, at commits
  whose product and test files are identical, and prints two verdicts:
  - the targeted correction, C1–C15;
  - the full regression, the 56 earlier executions. It reads INCOMPLETE while any row is
    uncovered.
- **Device classes.** The Pass and Wristband rows M4–M13 run on device B, the same model and runtime
  as main, and that is stated as an identity exception. So is P1's short-hold run.

**Budget.**

| | |
| --- | --- |
| Rate | Mac mini M2, pay as you go: $0.095 a minute, published at codemagic.io/pricing, read 2026-09-27 |
| Caps | 120 build minutes and USD 15 for this assignment |
| Free minutes | 15 rounded (28.1 exact) were left before build 1. Used after build 1: 510 rounded / 496.3 exact of 500 (−10 rounded / 3.7 exact left), summed from the account's build list, not a figure the account displays. Codemagic resets a personal account's 500 free minutes on the 1st of each month (docs.codemagic.io/billing/pricing, read 2026-09-27), so none come back before 2026-10-01 |
| Cost estimate | Further builds are fully billable if Codemagic rounds each build up to the whole minute. If it bills exact minutes, the first 3.7 minutes of build 2 are free (about $0.35 less). Either way about $2.40–3.30 per build, and at most $11.40 if all 120 minutes were billed |
| Guard | A build starts only while its 35-minute limit fits under what is left of the 120 |

Codemagic's pages do not say how minutes are rounded; the rounded figures here round each build up
to the whole minute, as this project's usage counter does. The account's actual invoice is not
readable through the API.

## 7. Results

| Build | Scope | Codemagic build | Commit | Minutes (exact / rounded) | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | `correction` | `6ab8adb429a3df446d9749a3` | `907d7401ec8b97a10138c2764094a9c564d0e4ce` | 24.45 / 25 | **FAIL**: 14 of 15 required passed; C12 failed (below) |
| 2 | `correction` | `6ab8c585873de42fcd4f1a8a` | `808950f8102d1c0e0f6c3422fc0aed3a0df555fe` | 15.54 / 16 | **FAIL, infrastructure**: on the iPhone 17 Pro Max the test runner failed to initialize for all three runs (no test ran there); on the iPhone 17e all six rows passed (C10–C15, including C12) |
| 3 | `gate_finish` | PENDING | PENDING | PENDING | PENDING |
| 4 | `sweep_finish` | PENDING | PENDING | PENDING | PENDING |

**Build 2** (07:28:13–07:43:45 UTC). The app, now with the re-alignment, compiled; the domain tests
passed on the Mac.
- **iPhone 17 Pro Max: no test ran.** Its three runners started at 07:33:01, 07:33:50 and 07:34:19.
  Each failed to initialize within 4–15 s (07:33:16, 07:33:54, 07:34:23), 1.3–2.5 minutes after the
  UI step began and 39–106 s after the device's boot status reported Finished (07:32:37). Each
  exited 65 with "The test runner failed to
  initialize for UI testing. (Underlying Error: Failed call to AXDisableAccessibilityOnTermination:
  kAXErrorCannotComplete)". No test started, so none of C1–C9 has a result from this build.
- **iPhone 17e: all six rows passed.** C10 (65.5 s, recorded), C11 (63.0 s), C12 (102.8 s), C13
  (67.2 s), C14 (17.7 s) and C15 (39.7 s), all at `808950f`. Its first runner started at 07:35:27,
  and C10 began at 07:35:34.
- **C12 photographed passing.** After Back to Now and Back to Upcoming at the largest text, the
  ticket's end now lands just above the Back area, with View place fully visible. The captures are
  `correction-entry-back-to-now-390pt-largest-fixture` and
  `correction-footer-back-to-upcoming-largest-390pt-fixture`. The re-alignment worked on this phone.
- **Response.** The harness now treats "the test runner failed to initialize, no test ran" as an
  infrastructure fault: it waits for the simulator (`bootstatus`, then 60 s) and runs the same
  tests once more. This extends the existing rerun for "simulator not found". It is not a test
  retry, because no test ran.
- **Durations** (from `executions.tsv`): as above.

**Build 1** (05:46:37–06:11:04 UTC, Mac mini M2, Xcode 26.6, iOS 26.5). The app and the new escape
routing compiled; the domain tests passed on the Mac; the preview copy of the app was published as
`Proximeet.app` (with `Proximeet-Debug-iphonesimulator-907d7401ec8b.zip`).
- Passed on their first and only attempt: C1, C2, C3 (main: the stage starts and endings at the
  largest text, the largest-text footers, the default-text footers with the approved 440-pt
  geometry), C4–C8 (the five Signal tests, including the real onboarding route), C9 (the seven
  screens, now required); C10, C11, C13, C14, C15 (smaller iPhone: the recorded walkthrough, the back
  gestures and controls with the `places.screen` containment check, the largest-text and
  default-text footers, the Back routes).
- **C12 failed** (smaller iPhone, largest text): after Back to places from Common Ground's detail,
  View place's bottom was at 738.3 pt and the action bar's top at 734.7 pt: 3.7 pt of the button
  sat under the bar. It is a product defect in this correction's "Back to places shows the ticket's
  end".
  - **The mechanism, reconstructed from this build's frames (not logged directly).** The scroll
    issued while the stage changes (during the 240-ms dissolve) stopped at the outgoing detail's
    largest scroll offset. Its own target, the ticket's end aligned against the detail's taller
    action bar, lay beyond that. Browsing's alignment point, the ticket's end at browsing's own bar,
    is a different offset:
    - On the 390-pt iPhone it stopped at about 1293, short of browsing's alignment (about 1311), so
      View place sat under the bar.
    - On the 440-pt iPhone it stopped at about 1106, about 52 pt beyond browsing's alignment, so the
      ticket ended well above the bar and C1 passed.

    The landing depends on the detail's scroll range, not on a fixed shortfall.
  - **Correction, after build 1** (§3, item 5): browsing is aligned again once the dissolve has
    finished. It was observed passing on the 390-pt iPhone 17e in build 2. It is not yet observed on
    the 440-pt iPhone 17 Pro Max (C1, build 3).
  - **Rerun.** It changes product code, so the whole correction gate reruns on the new commit.
- **The scroll diagnosis is settled by evidence.** The new helper made 138 traced drags (59 on the
  iPhone 17 Pro Max, 79 on the iPhone 17e) and none stalled: each moved the page its finger travel
  less 9.6–10.4 pt. That includes the largest-text pages where build 6ab88011's scrolls failed:
  browsing on the 390-pt iPhone 17e, where C12 stopped at `PlacesCorrectionTests.swift:210`, and
  Common Ground's detail on the 440-pt phone, where C1 stopped at `:219`. It also includes the
  explanation page, which neither test reached in that build. 54 of them started on the browse ticket's paper (the helper's fallback
  when no other clear point exists) and none opened anything. The optional probe (C17, smaller iPhone, largest text) measured, five drags each:

  | Pattern | Browsing (Now) | Common Ground's detail |
  | --- | --- | --- |
  | A: 0.96 of the width, next drag at once (the old helper) | +105, −105, +105, −105, +105 | +105, −105, +105, −105, +105 |
  | B: 0.96 of the width, 1.5 s between drags | +105 × 5 | +105 × 5 |
  | C: the column, away from controls, 0.7 s between drags | +105 × 5 | +105 × 5 |
  | C with iOS 26's content pop kept enabled (debug switch) | not run | +105 × 5 |

  So the old helper's stalls came from its own drags: back-to-back drags at the trailing edge moved
  the page back as often as forwards. The app scrolls normally, and holding off the content pop on a
  detail does not affect scrolling. Why a quick second drag at the edge reverses (the scroll
  indicator is the likeliest) is not established. The main-device probe (C16) was left unrun for
  time, as a diagnostic may be.
- Durations: C1 97.3 s, C2 64.1 s, C3 33.7 s, C12 112.9 s (to its failure), C13 75.7 s. The UI step
  took 18.0 minutes. The main device's first test began 666 s after the harness's gate: about
  6 minutes (361 s) after the UI step began, against 373 s in build 6ab88011.
- Downloads: all six artifacts matched their published sizes. The four with a published `.sha256`
  also matched it: the review, screens and walkthrough packages and the Debug simulator zip.
  `Proximeet.app.zip` and the `proximeet-rebuild_1_artifacts.zip` bundle have no published hash.
  The review page's 155 links, to 148 distinct files, all resolve.

Linux checks of the frozen commit, each PENDING: the domain suite (`swift test`), the project
validator, the source-gate manifests (`scripts/places_source_manifests.py --check`), and the UI
tests type-checked against an XCUITest shim. None of them shows the app working.

## 8. Not verified by automation

- VoiceOver, hands-on, including the new escape action from each stage: browsing → Signal; a detail
  → its category; the explanation → Common Ground's detail → browsing → Signal; the same with Reduce
  Motion on. XCUITest cannot perform the escape and VoiceOver does not run in the Simulator.
- The system Reduce Motion setting (only the app's preview flag is tested).
- Composing keyboards.
- A physical device: smoothness and gestures.
- The browser preview (§5).
- Visual approval, which is the founder's.
