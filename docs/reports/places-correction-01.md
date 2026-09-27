# Places correction 01: the ticket footer, back navigation, where a stage starts

Date: 2026-09-27. Not production-ready.

**Status: targeted correction FAIL; full regression sweep pending.** The one Mac build
(`6ab8801175ac3236c0f1514f`, on `358f59f1204c02fa167d21ebd9e6226d8799ff02`) passed 8 of its 13
required executions (§6). What passed, with captures, is the default-text footer on the 390-pt
phone, the back gestures and controls, the recorded walkthrough, and the five Signal tests. The
largest-text checks failed; they most likely failed because of where the test drags, but that is not
verified. The Linux checks before the build:
- the domain suite (174 tests, including the intent-venue matrix and the route guards) passed;
- the UI tests were type-checked against an XCUITest shim;
- the project validator passed;
- the source gate matched;
- a stubbed run of the harness under macOS's bash 3.2 completed.

Linux cannot compile the SwiftUI app, so none of these checks shows the app working.

## 1. Baseline and provenance

| | |
| --- | --- |
| Mac-tested product | `ea14c0011fa87b28c956640fa95d4eebc2674e7b`: places scope PASS, 13 of 13 (build `6ab8639c`) |
| Places tip | `0fb4e467d70ca00a5cf5b1e8e48a671ec3c87517`. It descends from `ea14c001` and changes only the chapter report and the source-gate checksum list. Product and test files are identical, checked with `git diff --name-only` and `git merge-base --is-ancestor` |
| Correction branch | `places-correction/footer-navigation-20260927T012306Z`, created from that tip with `git worktree add` at `/home/proximeet/proximeet-cloud-places-correction-20260927T012306Z`. Earlier branches and worktrees are untouched |
| Preserved | the approved artwork, fonts, copy, catalog, eligibility policy, layout references and onboarding draft; the recovered paste and Month-drag test fixes; "A place opens when you’re really there.", DEMO and "Demo · no location or camera used." |

## 2. What was wrong, and the corrections

Each correction below is the intended behaviour. The manifest rows named under it check it on the
Mac. Their results from build `6ab88011` are in §6.

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
     real View place tap). Only C14 (390 pt, default text) passed. C2 and C13 (largest text)
     failed, and C3 (440 pt, default text) was cut off.
2. **View place is a real button.** The ticket's name, kind, intents and schedule read on their
   own. View place is a labelled button ("View place") that tests tap directly. The card still
   opens the detail when tapped. Before, the whole ticket was one accessibility element. The label
   passed in C10 and C14, and the tap in C10, C11 and C14. Its hint keeps the approved wording,
   "Opens this fictional venue's details." The hint is not machine-checked, since XCUITest cannot
   read it; it is left to the VoiceOver review (§7).
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
   - Checked by C10 and C11 (the recorded walkthrough and the gesture test, on the smaller
     iPhone). Both passed.
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
   - Checked by C1 and C12 (both widths, largest text), and in the footer tests. The 440-pt
     detail opened at its beginning (C1's capture). C1 then failed reaching the detail's last line,
     and C12 failed before it opened anything. At the default text on 390 pt, Fieldwork's detail
     opened at its beginning (C10, C14), and Back to places showed View place (C10).

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
  `app.projecthalo.lab`. Every approved chapter from the Pass on shows a DEMO badge. Welcome and
  Birthday show none; Welcome's route reads "Continue the demo (no account)". The Places chapter
  report's §7 says every chapter shows the badge, which is wrong in the same way. That report is
  left unchanged here, and this line corrects it. The report page's title no longer carries the
  product name.
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

| | |
| --- | --- |
| Build | Codemagic `6ab8801175ac3236c0f1514f`, workflow `proximeet-places-review`, scope `correction`, Mac mini M2, unsigned simulator |
| Source | `358f59f1204c02fa167d21ebd9e6226d8799ff02` on `places-correction/footer-navigation-20260927T012306Z` (pinned; the source gate matched) |
| Time | 02:31:54 to 02:53:38 UTC: 21.74 minutes exact, 22 rounded, of the 30 authorised |
| Account after it | 27 builds, 471.9 exact / 485 rounded of 500 free minutes; 28.1 exact / 15 rounded left (read from the account's build list after the build) |
| Toolchain | Xcode 26.6 (17F113), iOS 26.5 simulators: iPhone 17 Pro Max ("main") and iPhone 17e ("smaller") |
| Result | **AUTOMATED VERDICT: FAIL.** The app compiled, the domain tests passed on the Mac, and 8 of 13 required executions passed on their first and only attempt (retries off) |

| Row | Device | Test | Result |
| --- | --- | --- | --- |
| C1 | main | `PlacesCorrectionTests.testDetailAndExplanationStartAtTheirBeginning` | failed, 169.7 s: "The detail's last line is reachable." It first passed: browsing scrolled to View place, and the detail at its beginning |
| C2 | main | `PlacesCorrectionTests.testFootersAtLargestTextStackAndStayReadable` | failed, 76.3 s: "Common Ground: View place reachable." |
| C3 | main | `PlacesCorrectionTests.testFootersAtNormalTextFitOrStack` | interrupted: its run's 600-s bound, 11 s after it started |
| C4 | main | `BandSignalInteractionTests.testBandSignalInteraction` | passed, 35.8 s |
| C5 | main | `BandSignalInteractionTests.testReducedMotionStillUpdatesImmediately` | passed, 20.5 s |
| C6 | main | `SignalReviewTests.testEndpointDuplicateTapsAndBack` | passed, 28.7 s |
| C7 | main | `SignalReviewTests.testRapidChangesAndInterruptionsStayConsistent` | passed, 53.6 s |
| C8 | main | `SignalReviewTests.testWalkthroughRealJourney` (onboarding → Signal → Places) | passed, 111.5 s |
| C9 | main | `PlacesReviewTests.testSevenScreensOnThisPhone` (extra) | not run: time |
| C10 | smaller | `PlacesCorrectionTests.testCorrectionWalkthroughScrollingAndBackGestures` (recorded) | passed, 57.5 s |
| C11 | smaller | `PlacesCorrectionTests.testBackGesturesMatchTheBackControls` | passed, 66.2 s |
| C12 | smaller | `PlacesCorrectionTests.testDetailAndExplanationStartAtTheirBeginning` | failed, 64.2 s: its first scroll to View place gave up |
| C13 | smaller | `PlacesCorrectionTests.testFootersAtLargestTextStackAndStayReadable` | failed, 84.2 s: "Common Ground: View place reachable." |
| C14 | smaller | `PlacesCorrectionTests.testFootersAtNormalTextFitOrStack` | passed, 27.2 s |
| C15 | smaller | `PlacesReviewTests.testBackRoutesKeepTheCategoryAndTheDraft` (extra) | failed, 20.2 s: a tab's height, 43.99999999999997, is not ≥ 44 |

**What the captures show.**
- **The 390-pt footer at the default text.** Common Ground and Afterglow sit side by side.
  Fieldwork's whole schedule sits above View place, with the paper and the perforation intact.
  Upcoming starts with View place below the fold; one scroll brings the whole button above the
  Back area, and a real tap on it opens Fieldwork at its beginning.
- **The 440-pt largest text (Now).** Browsing scrolled down shows the whole schedule above View
  place, with the paper below it. The detail it opens starts at its beginning, not at browsing's
  offset.
- **Gestures (390 pt).**
  - A cancelled swipe leaves Afterglow's detail as it was.
  - Completed swipes go back one stage each: detail → Later, explanation → Common Ground, browsing
    → Signal, with Social · Chat first kept.
  - After the band change, Common Ground reads "Not available for Dating".
  - Under the Reduce Motion preview, a swipe goes detail → Later.

**Not shown by this build:**
- the 440-pt default-text footers, including the approved layout (C3 was cut off);
- every largest-text footer on 390 pt, and on 440 pt apart from Now;
- where the detail and the explanation start at the largest text on 390 pt;
- the detail's last line and the explanation's privacy and demo lines at the largest text (both
  widths);
- the seven screens (C9).

**Why the largest-text checks failed: a hypothesis, not verified.** No frames were logged inside
the scroll loops and no largest-text run was recorded, so where each loop stopped scrolling is
unknown.
- **Established.** The scroll helper drags at 96 % of the width: 16–18 pt from the trailing edge,
  where the scroll indicator is (the recording shows it at x 384–387 on the 390-pt phone). I moved
  the drags there in this correction, from the leading margin, to keep them clear of the new back
  swipe. Build 6ab8639c's largest-text test scrolled with leading-margin drags: 44 and 80 drags,
  and the test passed.
- **The hypothesis.** On a page as long as the largest text makes it, iOS lets a touch on the
  indicator grab it and scrub the page, so a drag that lands on it moves the page back up.
  Scrolling would then work until the indicator reaches the drags' starting height, and then
  stall.
- **What fits it.**
  - C1's browse scroll reached View place after 14 drags, but the detail's last line never came
    into view in 40 more.
  - C13 reached its tab in 2 drags, then 40 more did not reach View place.
  - The press-to-press intervals in the loops of C2, C12 and C13 alternate between about 1.1 and
    1.6 s. C1's detail loop does not.
- **What it does not explain.** C2 gave up after 40 drags on the same 440-pt Now page that C1's
  first loop scrolled through in 14. The only difference is that C2 tapped the Now tab first. There
  is no evidence that any of C2's or C12's drags moved the page at all.
- **Against a layout fault.** The layout has no fixed heights that could clip the scrollable
  content. Where C1's browse scroll stopped, View place appears to clear the Back area by more than
  C2's 12 pt, with more content below it. That is estimated from the capture's pixels; the top of
  the Back button's frame cannot be seen.
- **Why C3 ran out of time.** The main device's first test started about 343 s into its 600-s
  run. C1 and C2 then took 246 s, about 160 s of it in the two stalled loops, which left C3 11 s.

**After the build (test-only, not verified on a Mac):**
- the scroll drags move to the middle of the page, clear of both edges;
- a scroll that gives up attaches the frames and the screen;
- the 44-pt target checks allow floating-point error (`44 − 0.001`).

No product file changed after `358f59f1`. There is no second correction build; one needs a new
authorisation.

**Reconciliation.**
- Of the 56 required earlier executions (13 places, 16 signal, 27 regressions), this build ran 6:
  C4–C8 and C15, by test and device. C15 failed. The other 50 are listed in the review package's
  index.
- The earlier results stand at their own commits:
  - places: 13 of 13 at `ea14c001` (build 6ab8639c);
  - signal: `1085af3d`;
  - regressions: `b06707ec` (build 6ab81e22).
- The full regression sweep is pending.

## 7. Not verified by automation

- The largest-text footers, the stage starts at the largest text on 390 pt, and the detail's and
  the explanation's last lines at the largest text (§6: failed or not produced).
- The 440-pt default-text footers, including the approved layout (§6: C3 was cut off).
- The test repairs made after the build (§6).
- VoiceOver, including the escape gesture (most likely one stage too far from a detail or the
  explanation).
- The system Reduce Motion setting.
- Composing keyboards.
- Physical-device smoothness and gestures.
- The full regression sweep.
- Visual approval, which is the founder's.
