# Places correction 01: the ticket footer, back navigation, where a stage starts

Date: 2026-09-27. Not production-ready.

**Status:** correction implemented; Linux checks passed; the Mac build and its captures are
PENDING. Nothing here is shown fixed yet. The Linux checks:
- the domain suite (174 tests, including the intent-venue matrix and the route guards) passed;
- the UI tests were type-checked against an XCUITest shim;
- the project validator passed;
- the source gate matched;
- a stubbed run of the harness under macOS's bash 3.2 completed.

Linux cannot compile the SwiftUI app, so none of these checks shows the app working. The Mac
verification is one targeted build. Its results are reported in the delivery message and in its own
`verdict.txt`, since a commit cannot contain its own build's result.

## 1. Baseline and provenance

| | |
| --- | --- |
| Mac-tested product | `ea14c0011fa87b28c956640fa95d4eebc2674e7b`: places scope PASS, 13 of 13 (build `6ab8639c`) |
| Places tip | `0fb4e467d70ca00a5cf5b1e8e48a671ec3c87517`. It descends from `ea14c001` and changes only the chapter report and the source-gate checksum list. Product and test files are identical, checked with `git diff --name-only` and `git merge-base --is-ancestor` |
| Correction branch | `places-correction/footer-navigation-20260927T012306Z`, created from that tip with `git worktree add` at `/home/proximeet/proximeet-cloud-places-correction-20260927T012306Z`. Earlier branches and worktrees are untouched |
| Preserved | the approved artwork, fonts, copy, catalog, eligibility policy, layout references and onboarding draft; the recovered paste and Month-drag test fixes; "A place opens when you’re really there.", DEMO and "Demo · no location or camera used." |

## 2. What was wrong, and the corrections

Each correction below is the intended behaviour. The manifest rows named under it check it on the
Mac, and until that build reports, each is PENDING.

1. **The browse footer at the largest text (confirmed defect).**
   - What was wrong. View place was drawn over the second line of Fieldwork's schedule:
     - at 440 pt only "Saturday · 10 am–" showed, with the button 8.3 pt below that line;
     - at 390 pt only "Saturday · 10" showed.
   - The cause. The footer chose between side by side and stacked with `ViewThatFits`. The
     schedule used the Manrope line-box modifier, itself a `ViewThatFits` (one line, else
     wrapping). Nested, the schedule was sized as one line and drawn wrapped.
   - The correction. A `Layout` (`TicketFooterLayout`) measures the actual content at the current
     text size:
     - The schedule and View place sit side by side when both fit at their natural widths.
     - Otherwise the complete schedule wraps to the column above the button, 12 pt apart, and the
       ticket and its paper grow; the page scrolls.
     - The schedule is plain wrapping text with the same first-line box (`PlacesWrappingText`).
     - At the largest sizes View place's words wrap inside it.
     - Nothing is shortened, capped or hidden.
   - What does not change. The approved 440-pt footer: View place 140 × 44 at (248, 754), the
     schedule's line at (52, 754).
   - Expected modes, from the bundled Manrope SemiBold advance widths:

     | Width | Column | Now (needs 253.1) | Later (261.2) | Upcoming (293.4) |
     | --- | --- | --- | --- | --- |
     | 440 pt | 336 pt | side by side | side by side | side by side |
     | 390 pt | 286 pt | side by side | side by side | stacked |

     At the largest text, every footer stacks.
   - Checked by C2, C3, C13 and C14 (both widths, all three venues, default and largest text, a
     real View place tap). PENDING.
2. **View place is a real button.** The ticket's name, kind, intents and schedule read on their
   own. View place is a labelled button ("View place") that tests tap directly. The card still
   opens the detail when tapped. Before, the whole ticket was one accessibility element. Its hint
   keeps the approved wording, "Opens this fictional venue's details." Checked by C2, C3, C13 and
   C14. PENDING.
3. **Back navigation.**
   - What was wrong. Places shows browsing, a detail and the explanation inside one navigation
     destination, so the expansion can play. That left the navigation stack's back gestures free
     to take any stage straight to Signal.
   - The correction (`PlacesEdgeBack`). While Places is on screen, a swipe in from the leading edge
     is Places' own:
     - It goes back exactly one stage, as the Back controls do: a detail to its category, the
       explanation to Common Ground's detail, browsing to the actual Signal (the stack's native
       pop, keeping the intent, approach, introduction and category).
     - The screen follows the finger. A swipe that is not completed returns and changes nothing.
     - The stack's pans and scroll views wait for this edge pan to fail. It fails at once for a
       touch that does not start at the edge.
     - On a detail or the explanation, iOS 26's swipe-from-anywhere pop
       (`interactiveContentPopGestureRecognizer`, looked up by name) is held off.
     - Outside Places nothing changes.
   - Explore other places still returns to Now explicitly.
   - The edge pan is not disabled globally, and no screen-wide gesture replaces it.
   - All of this is intended behaviour. It is checked by C10 and C11 (the recorded walkthrough and
     the gesture test, on the smaller iPhone). PENDING.
4. **Where a stage starts.**
   - What was wrong. Build 6ab8639c's largest-text "detail-top" captures showed Fieldwork's detail
     at its host and description. The test had scrolled browsing to the ticket before tapping, and
     the detail kept browsing's scroll offset. Those captures showed that retained offset, not
     the detail's beginning.
   - The correction:
     - A new detail and a new explanation start at their beginning, following the Guest List's
       proven `ScrollViewReader` pattern. For the expansion, the scroll moves with it.
     - Back to places shows the originating ticket's end, where View place is.
     - Explore other places starts browsing at the top.
   - Checked by C1 and C12 (both widths, largest text), and in the footer tests. PENDING.

## 3. Decisions and deviations

- Accepted by the lead for the prototype, recorded as deviations from Figma and not as matches:
  - native push and pop at the Signal–Places boundary;
  - the lower-card cross-fade within the 2D expansion.
- A completed swipe on an inner stage slides the screen away (200 ms) and then shows the previous
  stage at once. Under Reduce Motion the screen returns at once and the stage dissolves (240 ms), as
  the Back controls do. Under VoiceOver it is the stage change alone. No animation was redesigned.
- A completed swipe from browsing hands the screen to the stack's native pop from where the finger
  left it; it does not snap back first. If the model refuses that pop, the screen returns. Places
  always appears at rest.
- VoiceOver's escape gesture is not handled by Places. The stack's own pop leaves the whole
  destination, so from a detail or the explanation it most likely goes straight to Signal, the
  skip this correction removes for touch. An escape action on the whole screen could have changed
  the accessibility tree that every test depends on, and there is only one build, so it was left
  out. Open and unverified.
- The guardrail audit again flagged the earlier doctrine's brand-string, "PROTOTYPE" banner and
  `app.projecthalo.lab` rules. They do not match this rebuild, and this correction does not change
  them. TASK_01 sets the provisional `com.proximeet.demo` and says not to inherit
  `app.projecthalo.lab`; every approved chapter shows the DEMO badge (see the Places chapter
  report, §7). The report page's title no longer carries the product name.
- No permission, scanner, verification, presence, visibility or Room was added. The snapshot,
  eligibility (only Social or Business at Common Ground), missing-choice and age-gate protections
  are unchanged.

## 4. The previous compact video

Build 6ab8639c's `Places-walkthrough-compact` was labelled "trimmed to the app", but its first 11.0 s
show the home screen. The trim started 0.5 s before the test's start marker, which was printed before
the app launched. A separately labelled local viewing trim from 11.5 s is kept beside the preserved
originals:
- `/home/proximeet/proximeet-places-review-6ab8639c/Places-walkthrough-LOCAL-VIEWING-TRIM-from-11.5s.mp4`;
- SHA-256 `7e867bb19e5dab73f943badb7e2597bc09331b7d192e47feb4041291491df829`;
- with its README.

It was re-encoded on the VPS, is not a Mac artifact, and is not evidence of smoothness. The recorded
tests now print `PLACES_WALKTHROUGH_APP_READY` at the app's first screen, and the harness trims from
there.

## 5. The targeted verification plan

Workflow `proximeet-places-review`, scope `correction` (manifest rows C1–C15, retries off). Critical
checks come first on each device; the two extras run only if they fit.
- **Main (iPhone 17 Pro Max):**
  - where a stage starts;
  - the footers at the largest and the default text;
  - the five Signal and interaction tests whose endpoint expectation changed (C4–C8).

  Those five tests are `BandSignalInteractionTests.testBandSignalInteraction`,
  `BandSignalInteractionTests.testReducedMotionStillUpdatesImmediately`,
  `SignalReviewTests.testEndpointDuplicateTapsAndBack`,
  `SignalReviewTests.testRapidChangesAndInterruptionsStayConsistent` and
  `SignalReviewTests.testWalkthroughRealJourney`, the real onboarding → Signal → Places route. They
  keep their earlier device, the iPhone 17 Pro Max. Extra: the seven screens.
- **Smaller iPhone:**
  - the recorded correction walkthrough;
  - back gestures and controls, including cancelled and mid-screen swipes, a double tap on the
    header Back, the band change, one stage per swipe, and a completed and a cancelled swipe under
    the app's Reduce Motion preview flag;
  - where a stage starts;
  - the footers.

  Extra: Back routes.

The earlier 13 Places executions and the 43 earlier-chapter executions are not re-run, except rows
the review package lists by test and device. The full regression sweep is pending.

## 6. Verification build

**PENDING.** Reported in the delivery message and in the build's own `verdict.txt`.

## 7. Not verified by automation

- VoiceOver, including the escape gesture (most likely one stage too far from a detail or the
  explanation).
- The system Reduce Motion setting.
- Composing keyboards.
- Physical-device smoothness and gestures.
- The full regression sweep.
- Visual approval, which is the founder's.
