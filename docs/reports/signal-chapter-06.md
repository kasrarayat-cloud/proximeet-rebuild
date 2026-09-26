# Chapter 06 — approved Signal, native implementation report

Date: 2026-09-26. Not production-ready.

**Status:** implemented and statically checked on Linux. The macOS results are reported with
each build's own artifacts, since a commit cannot contain its own build's result.

## 1. Workspace and dependency

| | |
| --- | --- |
| Base | `3e4f5f0d4cd35888ab8d9e36f60ff125f9ae4f9d`, the Wristband. Real-device accessibility and motion checks remain outstanding for every earlier chapter |
| Branch and worktree | `signal/approved-20260926T131402Z` at `/home/proximeet/proximeet-cloud-signal-20260926T131402Z`, created with `git worktree add` |
| Design authority | `docs/design/signal-approved/`, copied from `PROXIMEET_SIGNAL_APPROVED_HANDOFF.zip`. The zip's SHA-256 is `08690caa…6b8b`, as expected, and all 24 files match its `SHA256SUMS.txt`. The four bands, the fonts and the licence are byte-identical to those already bundled, so only the blank tag, the documents and the references were added |
| Workflow | `proximeet-signal-review` (manual, unsigned simulator, 28 minutes, two scopes on one commit). See `docs/verification/signal-mac-review.md` |

## 2. Route and behaviour

Welcome → … → Guest List card → Continue preview → Wristband (an intent) → **Continue preview** →
Signal.

- **The entry.** The Wristband's Continue preview now opens Signal, in place of its "End of this
  preview." message. `DemoFlow.continueFromWristband` moves on only from the band scene with an
  intent, through the same `advance(from:)` requirement check as every other route.
- **No intent, no Signal.** Continue preview stays disabled without an intent. Signal is never
  pushed, and nothing defaults to Social. The DEBUG fixtures `signal` and `signal-selected`
  refuse to launch without an explicit `-ProximeetFixtureBand`.
- **One optional approach.** `DemoDraft.signal: ApproachSignal?` is nil on a fresh draft, and then
  exactly one of `chatFirst` or `okayToSayHello`. There are no per-band values and no booleans.
  - `DemoFlow.chooseApproach` works only on the Signal scene with an intent.
  - Choosing the current approach returns false and changes nothing.
  - The rows, the radios, the tag's pose and icon, the summary (`SignalSummary`: "[Intent] band ·
    Choose your approach" or "· [Preference]") and Continue preview all derive from the carried
    intent and this one value.
- **Continue preview** is disabled until an approach is chosen. It then shows "End of this
  preview." with OK and stays; Places does not exist. `RepeatTapGuard` swallows the repeats of a
  double tap, so alerts and routes never stack.
- **Back.** Both the header arrow and the bottom Back return to the actual Wristband.
  - Re-entry keeps the approach, attached at once.
  - Changing the band keeps the approach.
  - Editing the introduction on the Guest List keeps both values and shows the new words.
  - Nothing is recreated from fixtures.
- **A preference is not consent.** Choosing an approach sends or accepts no Wave, opens no chat,
  creates no match and grants no permission. The existing same-intent and mutual-consent rules
  are unchanged, and the legacy rules engine was not extended.
- **Memory only.** A relaunch starts fresh. Nothing is written, sent, logged or analysed.
  `ApproachSignal` and `SignalSummary` are not `Codable`.

## 3. Screen (440 × 956, `LAYOUT_SPEC.json`)

| Element | Where |
| --- | --- |
| Header | As on the Wristband: Back 44 × 44, the wordmark, DEMO |
| Headline | "A hello, / on your terms." ExtraBold 48/56, −1.92, at (32, 148) |
| Support | "Let people know how to begin." Regular 17/26 at y 274 |
| Hero | 376 × 216 at (32, 326). The band, stationary, 376 × 181 at (0, 10), cropped from the original at [22, 335, 1235, 920]. The tag is 88 × 68, cropped from `signal-tag.png` at [41, 154, 1216, 1060] with its alpha and hollow loop. It rests at (279, 124), turned by the spec's matrix, and attaches at (144, 129), straight |
| Tag icon | 25 × 25 at tag-local (31.5, 31), #202526, 1.77 pt. Native vectors that move with the tag |
| Summary | SemiBold 15/24, centred, y 547 |
| Privacy | "You stay private until venue check-in." Regular 14/20, centred, y 572 |
| Rows | y 602 and 698, 376 × 84, #111415, radius 18. Symbol 28 pt, name SemiBold 17/24, explanation Regular 14/20 in a 262-pt column, radio 20 pt. Selected: #242A2B with a 1.5 pt #7A8585 inside border, content shifted 1.5 pt, radio filled #F6F7F2 with its tick |
| Primary | Continue preview 376 × 60 at y 812: #F6F7F2 on #050606, or disabled #1F2424 with #737D7A |
| Back | 376 × 44 at y 883 |

The approved board was measured by rendering the handoff's frames and outlining the fonts. The
review tests check the rendered screen against those anchors: the text bands, the rows and
radios, the tag's pose, the icon's ink signature and the band's colour.

## 4. Motion and accessibility

- **First choice** (none → one): 500 ms ease-out. The tag translates and straightens onto the
  band, which does not move, and its icon rides with it.
- **Change between choices:** 220 ms ease-out. The tag stays attached; the icon, the row
  treatment and the radio dissolve.
- **No replay.** The active row and re-entry change nothing, so nothing animates. Re-entry draws
  the attached pose.
- **Reduce Motion and VoiceOver:** no animation; the final state appears at once.
- **Interruptions.** The model changes before any animation, so no timer or animation callback
  authorizes anything. A change to Reduce Motion, or the app becoming active again, ends a
  movement in flight by redrawing the hero at its model pose without animation. Back, Continue
  and rapid switching act on the model and are consistent by construction. The UI tests cover
  rapid switching, Continue, Back and background/resume during the movement. A change to the
  system Reduce Motion setting during the movement cannot be driven by XCUITest and is a manual
  check.
- **Accessibility.**
  - The rows are native buttons with the selected trait, labelled "[Name]. [Explanation]".
  - The group is labelled "Choose one approach".
  - A change announces "[Name] selected".
  - The hero, the tag, the icons and the radios are hidden from VoiceOver.
  - Disabled Continue preview has the hint "Choose an approach first.", and the visible summary
    already says "Choose your approach".
  - Targets: rows at least 84 pt, primary 60, Back 44.
  - At larger sizes the rows grow and wrap, the icons and radios grow at most 1.5×, the headline
    wraps between words, and the page scrolls.
  - At accessibility sizes a row's symbol and radio share a line above its words, which then
    have the row's full width, so no word breaks inside itself on a smaller phone. The reference
    layout is unchanged at standard sizes.

## 5. Integration findings (addressed in code; the runtime evidence is in the build artifacts)

1. **Age gate.** The domain already blocked forward routes structurally. It is now hardened:
   once the approved Birthday entry has been touched, an old adult `dateOfBirth` from the legacy
   input can no longer authorize the Pass (`DemoDraft.meetsRequirements(for: .demoPass)`).
   Returning to Birthday with an under-18, incomplete, impossible, future or uncommitted date
   keeps every draft and blocks:
   - Birthday's Continue;
   - the completed Pass and the legacy Pass route;
   - the Guest List card;
   - the Wristband;
   - choosing an approach and Signal's Continue;
   - any pushed path.

   A corrected date needs an explicit Continue and opens the Pass at its intro. A relaunch
   clears everything. The leap-day policy is unchanged. Covered by `AgeGateReturnTests` (5,
   domain) and the full-journey UI test.
2. **Colours.** Signal uses the Wristband's canonical style and art, where Social is coral. The
   summary is white, as approved, so it carries no intent colour. The legacy `.tint` / `Palette`
   mapping (Social cyan) is used only by DEBUG-only legacy scenes that the approved route cannot
   reach; those scenes were left unchanged, with no global recolour. The DEMO label's cyan is
   unrelated and kept. The source gate now forbids the legacy intent colours in `SignalView` and
   `WristbandView`, and each state's band is classified by its pixels.
3. **Test coverage.**
   - **Guest List baseline** (`6ab75905`): 20 unique UI tests, executed 20 times.
   - **Wristband run** (`6ab78983`): 27 unique tests, 28 executions. It ran only three of
     Welcome's four tests: `testLargestTextSize` had been dropped from the list to save time, and
     the report said "three".
   - **Signal:** that test is restored. The two scopes cover all 41 UI test methods (43
     executions: the keyboard check and Signal's largest-text test run on two sizes), and every
     unique case and per-device execution is listed separately.
   - **`BandSignalInteractionTests`** drove the retired legacy band and signal screens and would
     have failed. It is rewritten for the approved Wristband → Signal flow. Its legacy Ready-scene
     and 3D assertions are retired; the Wristband and Signal review tests replace them.
4. **Return-route evidence.** `guest-list-keyboard-back-corner-440pt` showed the Pass intro
   because it was a direct launch: under the fixture `guest-list-filled`, the Pass is a new
   screen at its intro. Those captures are now named `-direct-launch`. A new full-journey test
   opens the editor from the completed Pass. With the keyboard open, Back returns to the actual,
   complete Pass, and the draft is kept. Done and Back stay separate on both sizes.

## 6. Tests

- **Domain** (`swift test`, Linux): 154 tests, 0 failures.
  - Of these, 132 were existing. A few were adapted to the two approved approaches:
    `DemoFlowTests`, `DemoFlowInvariantTests`, and `WristbandRouteTests` for
    `canContinueFromWristband`.
  - 17 are new in `SignalRouteTests`: the route, no default, all twelve states, every change,
    no-ops, rapid changes, the words, Back, intent changes, introduction edits, re-entry, the
    endpoint, reset, nothing conferred, and not persistable.
  - 5 are new in `AgeGateReturnTests`.
- **UI:** `SignalReviewTests` (10), the new Guest List full-journey keyboard test, the rewritten
  `BandSignalInteractionTests` (2), and the updated Wristband and Guest List expectations. The
  Wristband's Continue preview now opens Signal; the Guest List direct-launch captures are
  labelled.

## 7. macOS results

Reported with each build's artifacts (`Signal-Review.zip`, `Signal-Regressions-Review.zip`,
`results/verdict.txt`) and in the delivery message, not in this file.

## 8. Decisions, assumptions and deviations

1. **The existing `ApproachSignal`** now has exactly the two approved cases, with the approved
   titles and explanations. `chatFirst` is kept, and `okayToSayHello` is new. The legacy
   `comeSayHi`, `withMyCrew` and `justLooking` are removed, together with their legacy screen
   `SignalSelectionView`. The DEBUG-only legacy `ReadyForCheckInView` previews use the new
   cases.
2. **The tick is drawn where the approved frames draw it.** It is slightly right of the disc's
   centre (a 16-pt frame at 6.5, 2), as on the board, rather than being re-centred.
3. **The tag's rotation.** Figma reports −9°, but its relative matrix turns the tag clockwise on
   screen. The app reproduces the matrix: +9° about the top-left corner, then the offset.
4. **Line breaks of the explanations** are left to iOS's wrapping in the 262-pt column, not
   forced. The board breaks after "both" and after "to" ("…after you both / agree.", "…No
   pressure to / continue."). Whether iOS matches this is checked on the captures, since Linux
   cannot lay the text out.
5. **The selection announcement** ("[Name] selected") is posted on each change, and the selected
   trait is set. Whether VoiceOver reads both is a manual check, as on the Wristband.
6. **The disabled action's hint** "Choose an approach first." is new, short copy for
   accessibility. The visible requirement is the approved summary.
7. **Portrait only**, as on the earlier chapters. Landscape and iPad are untested.
8. **The legacy `confirmSignal`** now needs the legacy profile, like `confirmBand`, so the
   approved route cannot reach the legacy Ready scene.
9. **Two builds per candidate.** All of the tests do not fit in one 28-minute build, so the run
   input `SIGNAL_REVIEW_SCOPE` splits them, and both scopes run on the same pinned commit. Every
   build and minute is counted, and each result names its build.
