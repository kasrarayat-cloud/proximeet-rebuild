# Chapter 07 — approved Places, native implementation report

Date: 2026-09-26. Not production-ready.

**Status:** implemented and statically checked on Linux (domain tests, the UI tests type-checked
against an XCUITest shim, the project validator, the source gate). The macOS results are reported
with each build's own artifacts and in the delivery message, since a commit cannot contain its own
build's result.

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

Later builds are reported in the delivery message and in each build's own `verdict.txt`.

## 9. Not verified by automation

- VoiceOver.
- The system Reduce Motion setting.
- Composing keyboards.
- Landscape and iPad.
- Physical-device smoothness.
- Visual approval, which is the founder's.
