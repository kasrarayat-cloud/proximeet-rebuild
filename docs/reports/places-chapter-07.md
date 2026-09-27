# Chapter 07 — approved Places, native implementation report

Date: 2026-09-26. Not production-ready.

**Status:** **the places scope passed on the Mac at `ea14c0011fa87b28c956640fa95d4eebc2674e7b`**
(Codemagic build `6ab8639c20c043a028c94e89`).
- All 13 required executions passed on their first and only attempt, with no retries: 11 methods,
  on the iPhone 17 Pro Max and the iPhone 17e.
- The signal and regressions scopes did not run within the chapter's budget (section 8).
- Two small visual findings on the narrower phone and at the largest text size are open for
  visual review (section 8).
- This report's final commit follows the verified revision and changes only documentation.

## 1. Workspace, dependency and provenance

| | |
| --- | --- |
| Base | `b06707ec88c8a6c2d15fdddff2869975c7339407` on `signal-correction/regressions-20260926T182011Z`: the approved Signal with the regression correction (the paste, Month-drag and regression-scheduling fixes are kept) |
| Provenance of the base | Signal's own scope passed at `1085af3d` (build `6ab7e942`). The 27 regressions passed at `b06707ec` (build `6ab81e22`). The 104 product files are identical between those two commits. Neither build ran both scopes on `b06707ec` |
| Branch and worktree | `places/approved-20260926T213808Z` at `/home/proximeet/proximeet-cloud-places-20260926T213808Z`, created with `git worktree add` from exactly `b06707ec`. Earlier branches, worktrees, backups and references are untouched |
| Design authority | `docs/design/places-approved/`, copied from `PROXIMEET_PLACES_APPROVED_HANDOFF.zip`. Its SHA-256 is `53761ca0581541e6323d5950576caa22c75c09dbc468b462e33a06c96cefd456`, as expected, and all 20 files match its `SHA256SUMS.txt`. The three scenes were added byte-identical (`common-ground.png` `71cac558…`, `afterglow.png` `a1b4ef8c…`, `fieldwork.png` `17167685…`, RGBA 1254 × 1254). The fonts and the licence are byte-identical to those already bundled |
| Workflow | `proximeet-places-review` (manual, unsigned simulator, 28 minutes, three scopes). See `docs/verification/places-mac-review.md` |

## 2. Route and behaviour

Welcome → … → Wristband (an intent) → Signal (an approach) → **Continue preview** → Places.

- **The entry.** Signal's Continue preview opens Places, replacing its "End of this preview."
  message. The first entry opens Now. `DemoFlow.openPlaces` needs Signal's own Continue condition
  (an intent and an approach) and the Places requirements, which include the Birthday gate. A
  repeated tap finds Places already open and pushes nothing.
- **The fixed snapshot.** `Places.swift` holds the fictional catalog and the eligibility words; it
  reads no clock:

  | Category | Venue | Schedule | Permitted | Availability |
  | --- | --- | --- | --- | --- |
  | Now | Common Ground | Today · 6–10 pm | Social, Business | open |
  | Later | Afterglow | Tonight · 9–11 pm | Social, Dating | future ("Opens at 9 pm") |
  | Upcoming | Fieldwork | Saturday · 10 am–1 pm | Activity, Business | future ("Opens Saturday") |

  DEMO and "Fictional venues · demo Thursday, 8 pm" are on every browse screen. There are no
  addresses, maps, people, counts or reservations.
- **Eligibility** (`PlaceEligibility`) means the session is open in the snapshot AND the venue
  permits the actual intent. So only Social or Business at Common Ground can preview check-in.

  | Case | Browse line | Detail's last line | Primary action |
  | --- | --- | --- | --- |
  | Mismatch (checked first) | "Your [Intent] band doesn’t match this session." | the same | "Not available for [Intent]", disabled |
  | Match, future session | "Your profile stays private until check-in." | "Sample session · not a reservation" | "Opens at 9 pm" or "Opens Saturday", disabled |
  | Match, open session | "Your profile stays private until check-in." | "Sample session · not a reservation" | "Preview check-in", enabled |

  The schedule stays visible in every case. The disabled action's own label is the reason, visible
  without a tap. Its accessibility hint adds the full sentence.
- **The destination is guarded as well as the button.** `DemoFlow.previewCheckIn` and
  `DemoDraft.meetsRequirements(.placeExplanation)` refuse any ineligible intent. `allows(_:)` and
  `reconcileRoute()` trim a stale route to the last scene whose requirements still hold, so a
  missing intent returns to the Wristband and a missing approach to Signal. The view calls
  `reconcileRoute()` on appearing and on every scene change. The DEBUG fixture
  `place-explanation` with Dating or Activity therefore stops on Common Ground's detail.
- **Routes.**
  - Browsing: both Backs return to the actual Signal.
  - A detail: both Backs return to the originating category.
  - The explanation: the header Back and "Back to place" return to Common Ground's detail;
    "Explore other places" returns to Now.
- **The category is retained** across Back to Signal and re-entry, and further back. It is kept
  in memory with the draft. Only Explore other places sets it, to Now.
- **Band changes recompute everything.** Eligibility is derived from the actual intent each time it
  is read; the approach and the introduction are kept.
- **The Birthday gate on the way back** now covers Places: an under-18 or uncommitted date blocks
  every Places route (domain `AgeGateReturnTests`; UI `testAgeGateOnTheWayBackBlocksPlaces`).
- **Nothing is conferred.** The explanation is explanation only. There is no permission prompt,
  location, camera, scanner, QR, timer, success or presence state, and no Room. Nobody is
  checked in, reserved or made visible, and there are no people, maps, Waves, chat, Keep or
  bottom navigation. Nothing is networked, persisted, logged or analysed; a relaunch resets
  everything. `Venue`, `PlaceCategory` and `PlaceEligibility` are not `Codable`.
- **Fixtures are fixtures.** Social with Chat first appears only in DEBUG fixtures. The Places
  fixtures refuse to launch without an explicit band and approach, and the app has no default for
  either.

## 3. Screens (440 × 956, `LAYOUT_SPEC.json` 58:480–58:486)

| Element | Where |
| --- | --- |
| Header | As on the earlier chapters: Back 44 × 44 at (24, 64), the wordmark, DEMO |
| Browse headline | "Find your / kind of place." ExtraBold 48/56, −1.92, at (32, 148) |
| Snapshot line | Regular 14/24, #A8B0AD, y 274 |
| Tabs | 376 × 48 at (32, 316), #111415, radius 18. Three 120 × 44 tabs (radius 14); the selected one is #F6F7F2 with #050606 SemiBold 15 |
| Browse ticket | 376 × 438 at (32, 374). Scene slot 344 × 248, centred; ivory #F6F7F2 (radius 26) from y 466 to 812. Name ExtraBold 28/40 at y 626; kind Regular 14/22 at 670; chips at 702; perforation at 739; schedule and "View place  →" (140 × 44, #050606) at 754 |
| Browse line | Regular 14/22, centred, y 837; Back 376 × 44 at y 883 |
| Detail ticket | 376 × 630 at (32, 146); ivory from 238 to 776. Name ExtraBold 32/40 at 398; kind 442; perforation 480; schedule Bold 19/28 at 498; chips 536; host 576; description Regular 16/24 at 613; rules 682; last line 742 (a mismatch: two lines at 728) |
| Detail actions | Primary 376 × 60 at y 812 (#F6F7F2 on #050606, or #1F2424 with #737D7A); "Back to places" at 883 |
| Explanation | "Arrive. / Then connect." at 148; support Regular 16/26 at 274; the venue card 376 × 88 at 330 (ivory, radius 20); steps 376 × 112 at 445 and 573 (#111415, radius 18, the supplied 28-pt symbols); "You stay private until both checks pass." at 711; "Demo · no location or camera used." (cyan) at 751; "Explore other places" at 812; "Back to place" at 883 |
| Chips | #050606 capsules 26 tall, ivory SemiBold 14 words, Figma widths (Social 72, Business 96, Activity 84, Dating 72), 8 apart |
| Perforation | 26 dashes 6 × 1 every 13 pt from x 50, and a 16-pt ground-coloured notch on each edge |
| Scenes | The original RGBA files, cropped once at [46, 83, 1211, 1218], [5, 105, 1249, 1186] and [8, 39, 1247, 1163], fitted, never stretched. They are hidden from VoiceOver |

On narrower phones the column is the width minus 64 pt, and the scene slot scales with it. At
larger text sizes, the tabs, chips and browse footer stack, and every part scrolls.

## 4. Motion and accessibility

- **A category change:** 240 ms ease-out. The ticket and its line dissolve; the selected tab
  does nothing.
- **View place:** a 500 ms ease-out two-dimensional expansion. The ticket keeps its identity, so
  the scene, the name and the kind move to their detail places. The lower parts cross-fade.
- **Back from a detail, Preview check-in, Back to place and Explore other places:** 240 ms
  dissolves.
- **Reduce Motion** (the system setting or the app's preview flag) replaces the expansion with
  the dissolve. **VoiceOver** gets no animation.
- **The model changes first**, and the motion follows. Rapid taps, Back and the app going to the
  background act on the model, so the screen is consistent by construction; the UI tests check it.
- **Accessibility.**
  - The browse ticket is one button whose label is the venue, the kind, the permitted intents and
    the schedule, with the hint "View place".
  - The tabs carry the selected trait, and a change is announced.
  - The detail's lines are separate elements; the disabled action gives its reason in its label
    and its hint.
  - Targets are at least 44 pt; the primary is 60 pt.

## 5. Deviations from the approved design

1. **Signal ↔ Places uses push and pop, not Figma's dissolve.** This is how every earlier chapter
   moves between chapters; inside Places the approved dissolves and expansion are kept.
2. **Browsing, a detail and the explanation are one navigation destination.** This is what lets
   them dissolve and expand as approved. A system edge swipe, where available, therefore leaves
   Places for Signal from any stage; the on-screen Backs go one stage up.
3. **The expansion is SwiftUI's layout animation of the same ticket.** Figma's smart animate
   interpolates matching layers. Here the chips and the footer cross-fade rather than fly.
4. **Larger text.** The tabs, chips and footer stack instead of truncating (Figma has one size).

## 6. Tests

- **Domain** (`swift test`, 174 tests, 0 failures on Linux).
  - `PlacesRouteTests` (20):
    - the catalog and the explanation's words;
    - the 12-combination matrix; only Social and Business at Common Ground are eligible;
    - mismatch precedence; the same availability whatever the day, with no clock or location API
      in the sources;
    - entry at Now and retention; the tabs as filters (the selected tab is a no-op); rapid
      changes; categories only while browsing;
    - every detail for every intent, with its Back; only an eligible preview;
    - the explanation's exits; band-change recomputation; missing choices; navigation accepts
      only pops;
    - nothing conferred; relaunch resets; nothing persistable.
  - The age-gate, invariant (a guided fuzz of 1 in 4 forward steps now reaches the deepest
    scenes), Signal-route and flow tests were updated for Places.
- **UI** (`PlacesReviewTests`, gated by `PROXIMEET_PLACES_REVIEW`, 11 methods):
  - the recorded full journey;
  - the seven screens on the iPhone 17 Pro Max and the smaller iPhone;
  - all twelve intent-venue combinations;
  - Back routes with the retained category and draft;
  - the band change; missing choices and the guarded explanation;
  - the Birthday gate on the way back; relaunch;
  - rapid taps and interruptions; the Reduce Motion preview flag;
  - the largest text on two widths.

  On the 440-pt phone the tests check the approved frames (boxes to 1 pt, text lines to 3 pt)
  and the drawing (the ivory ticket's edges, 26 dashes, the notches, the chips, the tab fills,
  the scene, the primary's fill).
- **The Signal endpoint expectation changed in five UI tests**, and nothing was dropped (see
  `docs/verification/places-mac-review.md`). The 41 unique methods and 43 executions of earlier
  coverage run in the `signal` and `regressions` scopes.

## 7. Review before the first build

A four-lens review (compile risk, UI tests against the app, the harness, spec fidelity) ran with
adversarial verification of every finding, and a guardrail audit ran on the diff. Confirmed and
fixed before any build:

- **The app would not have compiled.** `PreviewFixtures.Stage` had both `case places` and a
  `static let places` set: an invalid redeclaration. The Linux gates cannot see it, since the app
  target compiles only on the Mac. The set is now `placesStages`.
- **A false failure.** The rules element's frame included its 21-pt top padding, so the y 682
  check would have failed on a correct app. The padding now follows the element; the layout is
  unchanged.
- **Evidence worded honestly.** After a double tap on Continue preview, one Back leaving Places
  cannot by itself prove a single push, because Back pops to Signal whatever the path holds. The
  single push is proved in the domain (`SignalRouteTests`), and the UI messages now say so.
- **VoiceOver:** the browse ticket's hint no longer repeats its label.
- **Timing:** the per-run result exports are bounded to 20 + 20 + 60 s, and the UI deadline is
  1380 s. The worst case now fits the 28-minute build.
- **A false edge:** the Reduce Motion frame check skips the tabs' rows, where the selected tab
  is ivory.

Questions from the guardrail audit, recorded for the lead or founder. None of them changes this
chapter's code.

- The approved explanation line "A place opens when you’re really there." is the founder's copy,
  word for word. With the rotating-QR step it may read as a promise about a later, real check-in.
  The handoff's `DESIGN_NOTES.md` puts anti-spoofing in that later flow.
- The earlier doctrine's brand-string and "PROTOTYPE" banner rules do not match this rebuild.
  Everything here is named Proximeet, there is no `BrandConfig.swift`, and every approved chapter
  shows the DEMO badge instead of a banner. This predates Places.

## 8. Verification builds

| # | Build | Scope | Commit | Minutes | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | `6ab84ede6ba94782f897685a` | places | `71487baf` | 25.75 (26 rounded) | **FAIL**, see below |
| 2 | `6ab85be69602ff96bb8f8aaf` | places | `44af4491` | 25.75 (26 rounded) | **FAIL**: 9 passed, the smaller iPhone's run cut off by the deadline |
| 3 | `6ab8639c20c043a028c94e89` | places | `ea14c001` | 21.67 (22 rounded) | **PASS**: 13 of 13 on the first attempt |

**Build 1 compiled the app, the domain tests passed on the Mac, and 9 of the 11 Places methods
executed and passed.** They are:
- all twelve intent-venue combinations;
- Back routes with the retained category and draft;
- the band change and missing choices;
- the Birthday gate on the way back and relaunch;
- rapid taps and interruptions;
- the Reduce Motion preview flag;
- the largest text on the 440-pt phone.

It failed for two reasons, both the harness's and neither the app's.

1. **The headline check measured the wrong thing.** In the walkthrough, the headline's
   accessibility frame (an `.ignore` container) came back as its words' union: 285 × 121.67 at
   y 143.17, not the 376 × 112 layout box. Every other frame and pixel check on Now, Common
   Ground's detail and the explanation passed, including:
   - the ivory ticket's edges at 466/812 and 238/776;
   - the 26 perforation dashes from x 50 to 381 and both notches;
   - the tab fills, the chips, the scene and the primary action's fill.

   The captures, compared with the approved board at 1×, match it element for element: a mean
   difference of 2.6 to 3.3 levels, and only anti-aliasing outlines. The drawn headline glyphs
   are at 159.33–262.0 (Now) and 159.33–251.33 (explanation), against the board's 159–261 and
   159–250. The check is now those glyph rows, taken from the board, to 1.5 pt, with the
   frame's x.
2. **Time.** Both simulators were restarted after their first boot, and neither was ready for
   3.5 and 5.7 minutes. Device B's run reached its bound during the seven screens, and the smaller
   iPhone was left unrun for the deadline. The places scope was not verified on either the seven
   screens or the smaller iPhone.

**Deviation alert: the harness changed shape between builds.** It still runs the same tests and
judges them the same way, with no retries.
- Main boots alone and is never restarted; each scope pairs it with one parallel device (see
  `docs/verification/places-mac-review.md`).
- Signal's former device-B tests run on main, the same model.
- The Places tests' wait helpers return at once when the state already holds. An
  XCTNSPredicateExpectation makes its first check about a second after it starts, and those
  seconds cost minutes.
- The reason is the budget: three scopes at build 1's pace would not fit the 64 minutes left.

**Build 2: every execution on the iPhone 17 Pro Max passed.** That is the recorded journey
(including the headline now checked by its pixels), the Birthday gate, the largest text, rapid taps
and interruptions, the Reduce Motion preview, relaunch and the seven screens. On the smaller iPhone,
Back routes and the band change passed. The run was cut off by the UI deadline during the twelve
combinations, so four executions there did not complete.

The smaller iPhone was first booted only when the UI review began, at about 00:00:56, while main
was about to run its tests.
- Its boot finished at 00:07:55.
- Its xcodebuild then printed nothing for 9.5 minutes before "Testing started" (00:17:28). The
  first test began at 00:17:52.
- During that boot, the journey's xcodebuild took about 2.4 minutes to close (00:07:27 to
  00:09:48). Main's next xcodebuild, with no boot in progress, closed in 28 s.

**Deviation alert: what the rest of the budget can verify.**
- After two builds, 38 of the chapter's 90 free minutes remain (26 + 26 rounded).
- That is one more build at the 28-minute limit and none after it, so the signal and regressions
  scopes cannot run in this chapter.
- The last build runs the places scope: the chapter's own evidence, which has not yet passed
  whole.
- For the last build both devices boot during the compilation and are never restarted. In build 2
  the main simulator, booted that way, reached its first test 84 s after its xcodebuild started.
  Whether early boots also remove the smaller iPhone's 9.5-minute wait is unverified until that
  build runs.
- The earlier chapters' 43 executions last passed at `1085af3d` (signal) and `b06707ec`
  (regressions), not on the Places revision.

**Build 3: PASS.**
- **Source.** The source gate matched `ea14c0011fa87b28c956640fa95d4eebc2674e7b`, pinned by
  `PLACES_EXPECTED_COMMIT`. It is the tip of `places/approved-20260926T213808Z`, confirmed with
  `git ls-remote`.
- **Toolchain.** Xcode 26.6 (17F113), iOS 26.5 simulators. The host reported 10 GB of memory and
  3 CPUs.
- **Build and gates.** The app compiled unsigned. The domain tests passed on the Mac. The test
  harness compiled.
- **Main (iPhone 17 Pro Max), 7 executions:**

  | Test | Seconds |
  | --- | --- |
  | The recorded journey | 187.9 |
  | The Birthday gate on the way back | 35.5 |
  | The largest text | 91.6 |
  | Rapid taps and interruptions | 34.7 |
  | The Reduce Motion preview | 11.7 |
  | Relaunch | 59.1 |
  | The seven screens | 73.7 |

- **The iPhone 17e (390 pt), 6 executions:**

  | Test | Seconds |
  | --- | --- |
  | Back routes | 64.0 |
  | The band change | 48.7 |
  | All twelve combinations | 171.0 |
  | The largest text | 151.8 |
  | Missing choices and the guarded explanation | 57.5 |
  | The seven screens | 82.1 |

- **Totals.** 11 unique methods and 13 executions. None failed, was skipped, was interrupted or
  was retried, and every run exited 0.
- **Downloads.** They are on the build page,
  `https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6ab8639c20c043a028c94e89`. Each was
  downloaded, its size checked against the API and its SHA-256 checked. Every relative link in
  the offline index resolves: 163 links, 0 broken.

  | File | SHA-256 |
  | --- | --- |
  | `Places-Review.zip` (289.0 MB) | `fce064228606cabc835c639b2a5e57feba82d835234033ba354d739a5cd88936` |
  | `Places-Screens.zip` (51.3 MB, 71 screens, none missing) | `0912248ac04c09457f3902a6481fef2c68630903ec4504642849dbf639b6e38a` |
  | `Places-walkthrough-compact.zip` (59.3 MB) | `6ff39faa5c39cc7f191e444ed4abdd62e87c3a4514a5059842aabacbd1009031` |
  | `Places-walkthrough-compact.mp4` | `117f88c971e18e9b1065f57bfe4181a429f6cc8c5e7363dd4e65eb4f1cea3e44` |
  | `Places-walkthrough-original.zip` (155.7 MB) | `9c21c664fd9712963514db0d567502dd4356739a7763e0b062992dec3449015c` |
  | `Proximeet-Debug-iphonesimulator-ea14c0011fa8.zip` (unsigned simulator app) | `0a3c7750d2b241d131486824abc11126626b1c2231c668acfdf4eeeecd6b89b8` |

- **The compact walkthrough.** It is re-encoded at half size (660 × 1434) and trimmed to the
  test's own start and end: 94.21 s to 284.06 s of a 340.93 s recording, 189.6 s long. The
  original is kept unedited.
- **Visual comparison with the approved board at 1×.** The journey's Now, Common Ground detail
  and explanation match element for element. The mean difference is 2.6 to 3.3 levels, and the
  only difference is anti-aliasing. The status bar is present in the captures and absent on the
  board. The twelve eligibility captures show exactly the approved words.

**Findings for visual review. Not fixed: no build remains to verify a fix.**
1. **On a 390-pt phone, Upcoming's "View place  →" sits below the fold.**
   - At default text, Fieldwork's schedule ("Saturday · 10 am–1 pm") and the 140-pt label do not
     fit side by side in the 286-pt column.
   - The footer's `ViewThatFits` therefore stacks them. The label then lies under the action bar
     until the page is scrolled.
   - The ticket stays one tappable action and scrolls into view (both were checked).
   - The 440-pt phone is unaffected.
   - Proposed fix: keep the side-by-side footer and let the schedule wrap to two lines within its
     44 pt. Stack only at accessibility text sizes.
2. **At the largest accessibility size, the stacked browse footer draws "View place  →" over the
   schedule's second line.**
   - The schedule is set by the Manrope line-box modifier, itself a `ViewThatFits` (one line, else
     wrapping). Inside the footer's own `ViewThatFits` it appears to be sized as one line and then
     drawn wrapped.
   - VoiceOver still reads the whole schedule.
   - Proposed fix: set the footer schedule as plain wrapping text (no nested `ViewThatFits`).
3. **On the 390-pt phone, the detail's last line and the explanation's two boundary lines lie
   below the fold** until scrolled. That is expected for a shorter screen: they were checked
   reachable, and the 440-pt frames show everything at once.

**Budget.** Three builds used 73.2 exact / 74 rounded free Mac mini M2 minutes of the 90
authorized (25.75 + 25.75 + 21.67), and no build overlapped another. The account shows 450.2 exact
/ 463 rounded of 500 minutes used, with 49.8 / 37 left. The 16 minutes left of the chapter's
allowance cannot hold a fourth build, since every workflow's limit is 24 or 28 minutes.

**Not run in this chapter: the signal and regressions scopes (43 executions, 41 unique
methods).**
- They are in the manifest and the harness, ready to run.
- They last passed at `1085af3d` (signal, build `6ab7e942`) and `b06707ec` (regressions, build
  `6ab81e22`), before Places.
- On this revision, the places tests themselves cross into those chapters and passed there:
  - Signal's Continue preview, and Back with the intent and the approach kept;
  - the Wristband band change and the Guest List card;
  - the Pass and the Birthday gate on the way back;
  - relaunch through Welcome.
- The five Signal and interaction tests whose endpoint expectation changed have not run on the
  Mac.

## 9. Not verified by automation

- The signal and regressions scopes on this revision (section 8).
- VoiceOver.
- The system Reduce Motion setting.
- Composing keyboards.
- Landscape and iPad.
- Physical-device smoothness.
- Visual approval, which is the founder's.
