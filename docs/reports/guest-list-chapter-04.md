# Chapter 04 — approved Guest List, native implementation report

Date: 2026-09-26. Not production-ready. **Status:** implemented and statically checked on Linux;
the macOS results are reported with each build's own artifacts, since a commit cannot contain
its own build's result.

## 1. Workspace and dependency

| | |
| --- | --- |
| Base | `19d90333ff9180942850b102e2c75f1bcaa75978`: the Pass, with no visual blocker found for chapter progression. Real-device accessibility and motion checks remain outstanding for Welcome, Birthday and Pass |
| Branch and worktree | `guest-list/approved-20260926T025922Z` at `/home/proximeet/proximeet-cloud-guest-list-20260926T025922Z`, created with `git worktree add` |
| Design authority | `docs/design/guest-list-approved/`, copied from `chapters/04-guest-list/PROXIMEET_GUEST_LIST_APPROVED_HANDOFF.zip` (SHA-256 `b7fcab20…6563`, as expected). Every file matches its `SHA256SUMS.txt` |
| Workflow | `proximeet-guest-list-review` (manual, unsigned simulator); see `docs/verification/guest-list-mac-review.md` |

## 2. Route and behaviour

Welcome → More options → "Continue the demo (no account)" → Birthday → Continue → Pass → Try
the demo → Finish preview → **Continue preview** → Guest List.

- **The entry.** Pass Complete's Continue preview now opens the Guest List editor. It replaces
  the temporary "End of this preview." notice on the Pass. `DemoFlow.continueFromCompletedPass`
  moves on only from the pass scene and only for a completed `PassDemo`. The Birthday gate and
  the explicit Pass demo are unchanged; `.guestList` requires the same eligible committed date
  as `.demoPass`.
- **Two stages.** A domain value, `GuestListDemo`, held by the view, so every entry starts at the
  editor:

  | Stage | Headline | Support | Primary | Secondary | Header Back |
  | --- | --- | --- | --- | --- | --- |
  | editor | A little about you. | Give your hello a starting point. | Preview my card → card (only when previewable) | Back → Pass | → Pass |
  | card | Your first hello. | A small card. A real starting point. | Continue preview → "End of this preview." (OK; stays) | Edit introduction → editor | → editor |

  Each action names its own stage and does nothing from the other.
- **The draft** is `DemoDraft.introduction` (`GuestIntroduction`): the raw name, the raw opener
  and the selected interests. It starts empty; it is never prefilled. It lives in memory for the
  demo run: Back to the Pass and re-entry keep it, leaving the Pass for Birthday and coming back
  keeps it, and a relaunch or reset clears it. Nothing is written to disk, sent, logged or
  analysed. No verification, visibility, membership, entitlement, presence or discoverability
  state exists or is set.
- **Returning does not reset the Pass.** The Pass stays in the navigation stack below the Guest
  List, so Back finds it still complete. A new entry from Birthday is a new Pass screen and
  starts at its intro.
- **Rapid repeated taps** are handled as on the Pass: `RepeatTapGuard` swallows touches UIKit
  reports as repeats (`tapCount > 1`), now except inside text fields, which keep their own double
  and triple taps.
- **No later chapter.** Continue preview on the card only shows "End of this preview.". Wristband
  is not implemented.

**Every state** shows DEMO PROFILE and "This preview doesn’t make you visible to anyone.".

## 3. The form

- **Name** (required). Only whitespace or newlines is blank (Unicode White_Space, checked by whole
  characters). No surname, length, script or character rule, and no rewriting: the field has no
  autocorrection or automatic capitalisation. Punctuation, accents, scripts and inner spaces are kept. The card trims only
  the edges. Long names wrap on the card.
- **Introduction** (optional). At most 120 user-perceived characters, counted with
  `String.count`. The count shows `n / 120`. Pasted and composed text is never cut: over the
  limit the text stays, inline help says "Keep it to 120 characters to preview your card." and
  Preview waits. Crossing the limit and returning within it are each announced once. A
  whitespace-only opener is left off the card.
- **Interests** (optional). Exactly Coffee, Live music, Outdoors, in that order, each toggled on
  its own; zero to three are valid. Selected chips have the accessibility selected state and a
  check mark.
- **Preview my card** is enabled only with a nonblank name and an opener within the limit. The
  reason is discoverable: after the name has been edited or left blank, help under it says "Add a
  name to preview your card."; the fields' hints say what is required; and the disabled action's
  hint repeats the reason.
- **The initial** is the first user-perceived character of the first nonblank name token,
  unchanged, so no script is assumed and no grapheme is split.

## 4. Screens (440 × 956, `LAYOUT_SPEC.json`)

| Element | Where |
| --- | --- |
| Header | Back 44 × 44 at (24, 64); wordmark Bold 22/32 at x 84; DEMO PROFILE 128 × 32 at (285, 70), radius 8, cyan at 45 % outline, Bold 11/24, 0.9 tracking |
| Headline | ExtraBold 48/51.84 at (32, 154) |
| Support | Regular 16/24, #A8B0AD, at y 274 (a 48-pt box) |
| Name | label SemiBold 16/24 at y 340; field 376 × 56 at y 372, #111415, radius 18, #7A8585 stroke, Regular 18 |
| Introduction | label at y 444; field 376 × 88 at y 476, Regular 17; count Medium 12/16 at y 572, right-aligned |
| Interests | label Medium 14/24 at y 604; chips 116 × 44 at y 636, 8 apart |
| The card | 392 × 256.46 at (24, 371); initial disc 44 at (61, 442); name ExtraBold 38/41.04 at (118, 440); opener Medium 18/24 at y 500; rule at y 561; interests SemiBold 14/24 at y 571; "Your introduction, ready to edit." at y 658 |
| Boundary | Regular 16/24, centred, at y 739, broken after "you" as in the design |
| Primary | 376 × 60 at y 812; #F6F7F2 with #050606, or disabled #1F2424 with #737D7A |
| Secondary | 376 × 44 at y 880, Medium 16 white |

**The card art** is the handoff's `guest-list-card.png`, byte-identical in the bundle, cropped at
runtime to [66, 93, 1436, 988] and fitted to the card's width (392 × 256.09, centred in the
392 × 256.46 card, as Figma's FIT). The initial, name, opener, rule and interests are native and
move with the art as one unit. The content is centred in the paper's writing area (69 to 224 pt),
so a card without optional lines is balanced rather than top-heavy. When the text needs more
room (a long name, larger text), the card grows and only a plain band of paper is stretched, so
the clip, the woven tab and the holder keep their shape.

**The editor** is a scroll view. The two actions sit in a safe-area inset: at rest they are at
Figma's y 812 and 880 (32 pt above the screen edge, which reaches 2 pt into the home indicator's
area on this phone), and with the keyboard they rise above it. The focused field is scrolled
into view. Return in Name moves to Introduction; Return in Introduction adds a line; Done above
the keyboard, a scroll or hardware Tab leaves the field; hardware Tab and Shift-Tab move between
the two fields.

**Motion** uses native SwiftUI only.

- Editor ↔ card: a 220 ms ease-out dissolve, started only by a tap.
- The card: a 450 ms flat insert and settle (24 pt, art and text together) as it appears.
- Back to the Pass uses the system navigation pop, as the Pass's own exits do.
- Nothing animates while typing, and no action waits for an animation.
- Reduce Motion (the system setting or the app's preview flag) keeps the card stationary with a
  brief dissolve. VoiceOver gets no animation.

**Accessibility.**

- The visible field labels are not read twice: each field carries its label.
- The card is one element: the name, the opener and "Interests: …", read once. The initial and
  the paper are decoration.
- After Preview or Edit, VoiceOver focus moves to the new headline.
- Back, the chips and the secondary action are at least 44 pt; the primary action is 60 pt.
- Text follows Dynamic Type, the card's included; the DEMO PROFILE label stops growing at the
  largest non-accessibility size so it is never truncated.

## 5. Tests

- **Domain** (`swift test`, on Linux here): 117 tests, 0 failures. That is the 92 existing tests,
  unchanged, and 25 new ones in `GuestIntroductionTests` and `GuestListRouteTests`. They cover:
  - blank, international, punctuated and long names;
  - edge-only trimming;
  - the initial across scripts, combining sequences, Hangul jamo and emoji;
  - the 120/121 boundaries for ASCII, emoji, ZWJ families, flags, composed characters, jamo and
    CJK;
  - a preserved over-limit paste;
  - zero to three interests, in catalog order;
  - name-only cards;
  - the stages and stale actions;
  - that only a completed Pass opens the Guest List;
  - Back, re-entry and reset;
  - that the route confers no verification, visibility or later chapter.
- **UI** (`GuestListReviewTests`, ten tests; see the verification doc). Pastes use the system
  pasteboard and the edit menu, so the keyboard's own substitutions play no part. Pixel checks
  compare the rendered screen with the approved board and with the glyph extents of the bundled
  faces; where the 1× board blurs a detail of the art (the holder lip), the 3× art is the
  reference.
- **Pass:** only the walkthrough's endpoint expectation changed (intentionally): Continue preview
  opens the Guest List, and its Back returns to the complete Pass. The other Pass, Birthday and
  Welcome tests are unchanged.

## 6. macOS results

Reported with each build's artifacts (`Guest-List-Review.zip`, `results/verdict.txt`) and in the
delivery message, not in this file.

## 7. Decisions, assumptions and deviations

1. **A check mark on selected chips.** The handoff requires a selected-state cue that is not
   colour alone; the board's chips differ only by fill. A small check mark sits at the chip's
   leading edge; the label stays centred where the board has it.
2. **Field help copy.** The board shows no validation text. The handoff requires a discoverable
   reason for the disabled action and accessible over-limit feedback, so two short sentences
   were added: "Add a name to preview your card." (shown only after the name was edited or left
   blank) and "Keep it to 120 characters to preview your card.".
3. **The fictional opener's line break.** Figma breaks "Always up for coffee / and a good story."
   by hand. The app never inserts breaks into a guest's text, so the same 38 characters wrap at
   the 303-pt column after "good".
4. **Card layout without optional content.** The remaining lines are centred in the writing
   area. The rule appears only with interests, as the interest line's rule. Separators appear
   only between selected interests; a line that would not fit becomes one interest per line.
5. **The card grows** for long names or larger text, stretching only a plain band of the paper.
   This is adapted decoration, not new artwork.
6. **The opener keeps Figma's 24-pt lines.** Manrope Medium 18's natural line is 24.59 pt, so the
   opener block takes Figma's height and its lines are centred on it (within 0.3 pt for two
   lines).
7. **No autocorrection** in either field, and no automatic capitalisation in Name, so the system
   never rewrites a guest's words (the handoff rules out capitalisation that rewrites input).
8. **Tab in Introduction** leaves the field instead of typing a tab character.
9. **The tap guard exempts text fields**, so word and paragraph selection still work there.
10. **Card type follows Dynamic Type**, unlike the Pass's printed card, because the handoff asks
    for the card to reflow and grow with larger text.
11. **The initial is not case-mapped**; it is the grapheme as entered.
12. **Legacy code.** The legacy `GuestListView` is replaced. `GuestProfile`, `saveProfile`,
    `continueFromPass()` and `ProfileEditorSheet` remain only for the DEBUG fixtures of later,
    unapproved scenes. The approved Guest List cannot reach them.
13. **DEBUG fixtures** `guest-list`, `guest-list-filled`, `guest-list-card` and
    `guest-list-name-only` pass through the same gate; the Pass screen below a fixture's Guest
    List is a new view at its intro. Only the real route leaves it complete. Alex exists only in
    fixtures and tests.
