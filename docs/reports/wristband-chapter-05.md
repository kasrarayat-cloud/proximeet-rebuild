# Chapter 05 — approved Wristband, native implementation report

Date: 2026-09-26. Not production-ready. **Status:** implemented and statically checked on Linux;
the macOS results are reported with each build's own artifacts, since a commit cannot contain
its own build's result.

## 1. Workspace and dependency

| | |
| --- | --- |
| Base | `54b8a59440c9cb0f465f090f07a0ebb705b1ddce`: the Guest List, accepted for chapter progression. Real-device accessibility and motion checks remain outstanding for Welcome, Birthday, Pass and Guest List |
| Branch and worktree | `wristband/approved-20260926T062403Z` at `/home/proximeet/proximeet-cloud-wristband-20260926T062403Z`, created with `git worktree add` |
| Design authority | `docs/design/wristband-approved/`, copied from `chapters/05-wristband/PROXIMEET_WRISTBAND_APPROVED_HANDOFF.zip` (SHA-256 `c6ff0e0a…f4f2`, as expected). Every file matches its `SHA256SUMS.txt`. The fonts and licence are byte-identical to the bundled ones, so only the documents and references were copied |
| Workflow | `proximeet-wristband-review` (manual, unsigned simulator, 28 minutes); see `docs/verification/wristband-mac-review.md` |

## 2. Route and behaviour

Welcome → More options → "Continue the demo (no account)" → Birthday → Continue → Pass → Try the
demo → Finish preview → Continue preview → Guest List → Preview my card → **Continue preview** →
Wristband.

- **The entry.** The Guest List card's Continue preview now opens the Wristband, replacing its
  "End of this preview." notice. `DemoFlow.continueFromGuestListCard` moves on only from the card
  stage of a previewable introduction on the Guest List scene.
- **One intent.** The single source of truth is `DemoDraft.band`, an optional `BandIntent`: nil
  on a fresh run, then exactly one of Social, Dating, Business, Activity. Nothing is ever
  inferred or preselected. `DemoFlow.chooseIntent` replaces any other choice at once; choosing
  the current intent again returns false and changes nothing (it never clears). Every tile's
  selected state, the hero, the summary and Continue preview are derived from that one value
  (`WristbandSummary`, `BandIntent.wristbandHint` / `wristbandExplanation`), so they cannot
  disagree. All four choices stay available.
- **Continue preview** is disabled with no intent. Once one is chosen it shows "End of this
  preview." with OK and stays on the Wristband. Signal is not implemented; the legacy
  `confirmBand` now needs the legacy profile, so the approved route cannot reach it.
- **Back** (the header arrow or the bottom Back) returns to the actual Guest List card below,
  with its introduction; the intent is kept. Editing the introduction and coming forward again
  shows the new words and keeps the intent. Re-entry without a choice stays unselected.
- **Memory only.** The intent lives for the demo run; a relaunch or reset clears it. Nothing is
  written to disk, sent, logged or analysed.
- **Nothing conferred.** Choosing an intent sets no verification, check-in, presence,
  visibility, discoverability, location, membership, entitlement or consent state; none exists.
  Every state shows DEMO and "Choosing a band doesn’t make you visible.".
- **Rapid repeated taps** are handled as on the Pass and Guest List: `RepeatTapGuard` swallows
  touches UIKit reports as repeats, so a double tap cannot stack alerts or skip a route. Rapid
  separate taps on different tiles leave the last one chosen.

## 3. Screen (440 × 956, `LAYOUT_SPEC.json`)

| Element | Where |
| --- | --- |
| Header | Back 44 × 44 at (24, 64), the approved vector arrow (14 × 12 at 39, 80, 1.8 pt); wordmark Bold 22/32 at x 84; DEMO 128 × 32 at (285, 70), radius 8, cyan at 45 % outline, Bold 11/24, 0.9 tracking |
| Headline | "Choose your / kind of hello." ExtraBold 48/56, −1.92 tracking, at (32, 148) |
| Support | "One intent for this moment." Regular 17/26, #A8B0AD, at y 274 |
| Hero | 376 × 200 at (32, 328). No intent: the four bands at an equal 182 × 88, two by two, 12 apart. An intent: only its band, 376 × 181, centred |
| Summary | y 536: "Your moment. Your choice." (white) or "[Intent] · Selected" in the intent's colour, SemiBold 18/26; the explanation Regular 14/22 at y 564 |
| Choices | Social / Dating at y 602, Business / Activity at y 692, 182 × 78, 12 apart; #111415, radius 16; selected #242A2B with a 1.5 pt border in the intent's colour; icon 24 pt (the approved vector paths, 1.8 pt), name SemiBold 16/24, hint Regular 12/20, the selected check (14 pt disc, #050606 tick) |
| Privacy | "Choosing a band doesn’t make you visible." Regular 14/20, centred, at y 779 |
| Primary | Continue preview 376 × 60 at y 812; #F6F7F2 with #050606, or disabled #1F2424 with #737D7A |
| Back | 376 × 44 at y 883, Medium 16/24 white |

**The bands** are the handoff's four originals, byte-identical in the bundle, cropped once at
runtime to the common box [22, 335, 1235, 920] with their alpha kept, and fitted without
stretching. They are decoration and hidden from accessibility. Every word, icon, check and
control is native. No colour was changed and nothing was regenerated.

**Layout.** A scroll view with the two actions in a safe-area inset, 29 pt above the screen's
bottom edge at rest as in Figma. The hero scales with the available width on narrower phones.
At larger text the headline wraps between its words rather than shrinking; the choices become
one column when two no longer fit side by side; everything stays reachable by scrolling. DEMO
stops growing at the largest non-accessibility size so it is never truncated, and the wordmark
gives way first, as on the Guest List.

**Motion** uses native SwiftUI only. A tap changes the choice at once, with Figma's 220 ms
ease-out dissolve between bands, summary and check; nothing moves and the layout is stable.
Reduce Motion (the system setting or the app's preview flag) uses a 120 ms dissolve without
movement; VoiceOver gets no animation. No action waits for an animation. There is no clasp
animation, loop or 3D.

**Accessibility.** Each tile is a button with its name as the label, its hint (for example
"People & moments") as the hint, and the selected trait. Each real change posts one concise
announcement ("Social selected"); choosing the chosen tile again posts nothing. What VoiceOver
actually speaks, and whether it combines the announcement with the trait change, has not been
checked (a manual check; decision 4). A tile's size never changes when it is chosen, so choosing
cannot rearrange the grid or move focus. Back, the tiles and the bottom Back are at least 44 pt;
the primary action is 60 pt. With no intent, the visible helper ("Pick the band that fits right now.") and the disabled
action's hint ("Choose a band first.") explain what is needed, without an error before anything
is tapped.

## 4. The Guest List keyboard follow-up

On build `6ab75905` (iPhone 17 Pro Max, iOS 26.5), the recorded frames show the keyboard's
floating Done at {352.67, 569, 62.33 × 36} and the editor's Back at 32–408 × 545–589, against a
safe-area edge at 597: the two hit regions overlapped at x 352.67–408, y 569–589, the reported
bottom-right corner of Back. The smallest public-API correction: while a field is focused, the
editor's actions keep 36 pt more room above the keyboard (`keyboardDoneClearance`), so Back ends
at 553 and Done begins 16 pt below it. The targets keep their size, keyboard avoidance and the
draft are unchanged, and the keyboard-closed layout is untouched (the padding applies only while
a field is focused). `testKeyboardDoneAndBackStayIndependent` checks it on the iPhone 17 Pro Max
and on a smaller iPhone.

## 5. Tests

- **Domain** (`swift test`, on Linux here): 132 tests, 0 failures: the 117 existing ones,
  unchanged, and 15 new ones in `WristbandRouteTests`. They cover: only the card opens the
  Wristband (a blank or over-limit introduction, the editor or a legacy route cannot); a fresh
  run starts unselected; all four intents from none; all 12 changes between intents plus the
  four repeats (the chosen tile does nothing); rapid changes leave the last; choosing is
  scene-only; the approved words; Back and re-entry keep the intent, and re-entry without a
  choice stays unselected; editing the introduction keeps it; reset clears it; the legacy routes
  cannot reach Signal; nothing is conferred; the draft is not persistable.
- **UI** (`WristbandReviewTests`, seven tests; see the verification doc), and one new Guest List
  test, `testKeyboardDoneAndBackStayIndependent`, on two sizes.
- **Guest List:** only the endpoint expectation changed (intentionally): the walkthrough, the
  relaunch test and the rapid-tap test now expect Continue preview on the card to open the
  Wristband, whose Back returns to the card. With `PROXIMEET_SHORT_HOLDS=1` (unrecorded runs
  only) pauses are capped at 0.6 s. The Pass, Birthday and Welcome tests are unchanged.

## 6. macOS results

Reported with each build's artifacts (`Wristband-Review.zip`, `results/verdict.txt`) and in the
delivery message, not in this file.

## 7. Decisions, assumptions and deviations

1. **The existing `BandIntent` and `DemoDraft.band`** are the one typed optional value; no
   second state was added. The legacy `BandSelectionView` is removed; the `.band` scene is the
   approved Wristband. The DEBUG fixtures `band` and `band-selected` therefore show it too.
2. **The artwork is cropped at runtime** from the unchanged originals rather than exported as
   cropped copies, so the bundle holds exactly the approved files.
3. **A selected tile's content moves 1.5 pt in**, as Figma counts the inside border in the
   tile's padding; the tile's size does not change.
4. **The selection announcement** ("[Intent] selected") is posted on each change; the selected
   trait is also set. Whether VoiceOver reads both is a manual check.
5. **The disabled action's hint** "Choose a band first." is new, short copy for accessibility;
   the visible explanation is the approved helper.
6. **The headline wraps** at larger text sizes instead of keeping Figma's two lines by
   shrinking. At the default size each line is about 278 pt, well inside 376.
7. **Portrait only.** The project supports portrait alone, so there is no landscape layout to
   verify; a test turns the device and checks the screen stays as it was.
8. **Legacy code.** `BandSignalInteractionTests` and the original `proximeet-simulator-verification`
   workflow drive the retired band screen (`band.confirm`). No chapter workflow runs them; they
   would now fail and are left as they were, outside this chapter's scope.
9. **One earlier-chapter change besides the endpoint, ordered by the lead.** The handoff's
   `CLAUDE_PROMPT.md` names the card endpoint as the only earlier-chapter behaviour to change.
   This assignment also ordered the Guest List keyboard follow-up (section 4) and, if Done and
   Back overlapped, the smallest public-API layout correction. They did overlap on build
   `6ab75905`, so the editor's actions keep 36 pt more room while a field is focused. Nothing
   else in the Guest List changed.
10. **An ineligible Birthday re-check keeps the drafts.** Going back to Birthday and entering an
    under-18 date blocks the route as before, but the introduction and the intent stay in memory
    for the run, as the introduction already did in chapter 04. Not changed here; worth a
    decision with Signal.
11. **Parallel regressions.** To fit the 28-minute limit, the Guest List and Pass tests run on a
    second iPhone 17 Pro Max on the same runtime, created for the run and deleted after it, while
    the Wristband, Birthday and Welcome tests run on the selected one. Both are 440 × 956.
12. **Tile geometry.** Figma gives each name an 89-pt column and moves a selected tile's content
    1.5 pt in. The app keeps both on the reference phone (the check at x 146.5 in a selected
    tile), but the column is a maximum, not a minimum, the check is always laid out and only
    fades in, and the shift is an offset. So a tile's size does not depend on the selection (on
    narrower phones two columns still fit, and choosing never switches to one column), and at the
    largest sizes a row never overflows. The icon and check grow at most 1.5× with Dynamic Type;
    the words grow fully. The 1.5 pt shift is applied at once, never animated, so nothing slides
    in either motion setting. At accessibility sizes the icon and check share a line above the name,
    so a name never breaks inside the word. Two tiles share a row only when both fit at equal
    widths (a small layout measures the wider tile), otherwise the choices are one column.
13. **For Signal: the legacy palette.** The DEBUG-only later scenes (Signal, Ready) still tint
    Social with the legacy cyan `Palette.social` (#35D7FF), while the approved Wristband's Social
    is coral #F2877F and cyan is the DEMO label's colour. The approved route cannot reach those
    scenes; the colours need reconciling before chapter 06 connects Signal.
