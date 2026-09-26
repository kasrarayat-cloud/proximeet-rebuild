# Chapter 03 — approved Pass, native implementation report

Date: 2026-09-26. Not production-ready. **Status:** implemented and statically checked on Linux;
the macOS results are reported with each build's own artifacts, since a commit cannot contain
its own build's result.

## 1. Workspace and dependency

| | |
| --- | --- |
| Base | `f33870ec087054dbf6ab2957a36c66fcafd4a340`: the corrected Birthday, accepted for chapter progression. Its native-picker rendering differences and its outstanding manual checks stand as recorded in `docs/reports/birthday-chapter-02.md` |
| Branch and worktree | `pass/approved-20260926T002322Z` at `/home/proximeet/proximeet-cloud-pass-20260926T002322Z`, created with `git worktree add` |
| Design authority | `docs/design/pass-approved/`, copied from `chapters/03-pass/PROXIMEET_PASS_APPROVED_HANDOFF.zip` (SHA-256 `03234996…e3a6`, as expected). Every file matches its `SHA256SUMS.txt` |
| Workflow | `proximeet-pass-review` (manual, unsigned simulator); see `docs/verification/pass-mac-review.md` |

## 2. Route and behaviour

Welcome → More options → "Continue the demo (no account)" → Birthday → **Continue** → Pass.

- **The gate.** Birthday's Continue now opens Pass. It replaces the temporary "Pass is next."
  notice, and it goes through the existing gate: the committed date is re-checked against
  today, and only an eligible date advances (`DemoFlow.continueFromBirthday`). Incomplete,
  impossible, future, pre-1900 and under-18 dates stay on Birthday. The date policy, including
  the provisional 29 February rule, is unchanged. A repeated Continue returns `nil` off
  Birthday, so it cannot push Pass twice.
- **Three states.** The states come from a domain value, `PassDemo`, held by the view, so every
  entry starts at the intro:

  | Stage | Headline | Support | Primary | Secondary |
  | --- | --- | --- | --- | --- |
  | intro | Your next chapter. | Preview the age-check experience. | Try the demo → progress | Leave demo → Birthday |
  | progress | Demo in progress. | You control this preview. | Finish preview → complete | Cancel → intro |
  | complete | Demo complete. | You have finished the demo. | Continue preview → "End of this preview." (OK; stays) | Leave demo → Birthday |

  Each action names its own transition and does nothing from any other stage. A stale or
  repeated action can therefore never skip a stage. Finish preview is available as soon as
  progress shows.
- **Back and Leave demo** call `DemoFlow.leavePass()`, which pops only from Pass. It returns to
  the actual Birthday screen, which is still in the navigation stack with its wheels, draft and
  check intact.
- **Rapid repeated taps** are handled without a timed wait. While Pass is on screen,
  `RepeatTapGuard` swallows touches that UIKit itself reports as the repeated taps of a
  multi-tap (`UITouch.tapCount > 1`):
  - a double tap on Try the demo cannot also press Finish preview;
  - a double tap on Continue cannot also start the demo;
  - a double tap on Back cannot also press Birthday's Back while Pass slides away.

  First taps are never delayed.
- **Nothing advances on its own.** There is no timer, animation completion, appearance,
  background/resume, restoration or stored birthday that advances the demo. Nothing is
  persisted, logged or sent.
- **The legacy onward route is disconnected.** The old `DemoPassView`, whose button led to
  Guest List, is removed from this route. `continueFromPass` remains only for the DEBUG
  fixtures of later, unapproved scenes. The DEBUG `pass` fixture now opens Pass through
  Birthday's gate with 12 May 1997.

**The boundary.** Every state shows DEMO, 18+, DEMO PASS, PROXIMEET and the sentence "No age
or identity verification is performed." The 18+ graphic names the demo's category; it is not
a credential.

- There is no "verified", "access granted", checkmark or provider wording. The source gate
  checks the Pass sources for such wording, and for entitlement, capture, network, persistence
  and timer APIs.
- No verification, authentication or entitlement flag exists or is set. `PassDemo` is not
  persistable, and a domain test shows the demo changes nothing in the draft or the path.

## 3. Screen (440 × 956, `LAYOUT_SPEC.json`)

| Element | Where |
| --- | --- |
| Header | Back 44 × 44 at (24, 64); wordmark Bold 22/32 at x 84; DEMO label 80 × 32 at (320, 70), radius 8, cyan #38DBE5 at 45 % outline, Bold 16/24 text |
| Headline | ExtraBold 56/59, −2.2, at (32, 154) |
| Support | Regular 16/24, #A8B0AD, at y 288 |
| The pass | Artwork box (20, 330), 400 × 400; lifted to 324 in progress |
| Claim | Medium 16/24, #A8B0AD, at y 739, broken after "verification" as in the design |
| Primary | 376 × 60 at y 812, #F6F7F2, radius 18, SemiBold 18 |
| Exit | 376 × 44 at y 880, Medium 16 white |

**The pass** is `PassArtwork`: the handoff's `pass-artwork.png`, byte-identical and uncropped
(the full 1254² source), fitted to the 400 × 400 box.

- The native card text sits at the Figma card coordinates: "18+" ExtraBold 88/100 #050606,
  "DEMO PASS" ExtraBold 24/32 #06575E, a #14383B rule at 30 %, and "PROXIMEET" Medium 16/24
  with 2 pt tracking. Each line sits on Figma's line box at the top of its text box, so
  "DEMO PASS" is not centred in its 36 pt box. On the board its ink measures 562.7–580.0.
- The art and its text move as one unit.
- On narrower screens the pass scales to the width, and the page scrolls when needed.
- The pass's type is part of the printed object, so it scales with the pass rather than with
  Dynamic Type. The headline, copy and actions follow Dynamic Type.

**Motion** uses native SwiftUI animation only; there is no new library.

- Start and finish: 220 ms ease-out. The text cross-dissolves and the pass lifts 6 pt, then
  settles.
- Cancel: a 180 ms ease-out dissolve. The text and the pass cross-dissolve to the intro (the
  pass is re-created, so it dissolves into place rather than gliding).
- Back and Leave demo use the system navigation pop. A 180 ms dissolve would need a custom
  navigation transition, which is not compatible with the existing navigation (see
  section 6).
- Every state change happens at once. The animation never gates an action, and an interrupted
  animation settles to the current state.
- Reduce Motion (the system setting, or the app's preview flag) keeps the pass stationary,
  with a brief dissolve. VoiceOver gets no animation.

**Accessibility.**

- The artwork is decoration. The pass is one element, "Demo pass, 18 plus". The printed
  PROXIMEET is not read, because the header wordmark already names the brand. The DEMO label
  is hidden, because the pass and the headline already say "demo".
- Each stage change is announced as a demo state, for example "Demo in progress. You control
  this preview."
- Back and the secondary action are at least 44 pt tall.

## 4. Tests

- **Domain** (`swift test`): 92 tests, 0 failures, including 10 `PassDemoTests` and the
  intentionally changed Birthday Continue test. They cover:
  - the stages and stale actions;
  - Cancel;
  - immediate Finish;
  - the continue-preview endpoint;
  - re-entry;
  - that the demo cannot be persisted and changes nothing in the draft or the path;
  - that only an eligible committed date opens Pass;
  - leaving back to Birthday with its draft;
  - that a repeated Continue or Back does not repeat.
- **UI** (`PassReviewTests`, three tests; see the verification doc): the real route, the gate,
  rapid taps, waiting, background/resume, Reduce Motion (preview flag), and screen-pixel
  comparisons with the approved board.
- **Birthday:** `BirthdayReviewTests` keep all their checks. Only the walkthrough's Continue
  expectation changed (intentionally): Continue opens Pass, and Back returns with the date
  kept.
- **Welcome:** `WelcomeReviewTests` are unchanged.

## 5. macOS results

Reported with each build's artifacts (`Pass-Review.zip`, `results/verdict.txt`) and in the
delivery message, not in this file.

## 6. Decisions, assumptions and deviations

1. **The review endpoint.** "Continue preview" shows the native message "End of this preview."
   with OK and stays on Complete. This is the handoff's functional completion of Figma's
   unwired placeholder, not a new chapter.
2. **Exits use the system pop, not a dissolve.** Figma's 180 ms dissolve on Back and Leave demo
   would need a custom navigation transition; the existing navigation stack's push and pop is
   kept. Cancel, which stays on Pass, uses the 180 ms dissolve.
3. **Rapid-tap guard.** It works from UIKit's own multi-tap count: no timer, no delay, and no
   effect on VoiceOver. A deliberate second tap at the same spot within the system's multi-tap
   interval is treated as a repeat. A separate tap is honoured at once.
4. **The DEMO label is hidden from VoiceOver.** This avoids reading "demo" three times. The
   label stays visible in every state.
5. **Card type does not follow Dynamic Type.** It is part of the printed pass, as Birthday's
   console is. All other text scales, and the page scrolls.
6. **The Birthday gate is untouched, and its expectations change only where intended.** The
   `.demoPass` requirement accepts the approved committed-adult check. The legacy stored date is
   kept for the DEBUG fixtures of later scenes.
