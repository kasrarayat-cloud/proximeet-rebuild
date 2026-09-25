# Chapter 02 — approved Birthday, native implementation report

Date: 2026-09-25. Not production-ready. **Status:** implemented and statically checked on Linux.
The macOS results are in section 7.

## 1. Workspace

| | |
| --- | --- |
| Base | `28b8ae243a87984ed115833e73da9e2447e87579` (the verified Welcome, build `6ab6b13cd142fb59eea4ca4d` PASS) |
| Branch | `birthday/approved-20260925T185523Z` |
| Design authority | `docs/design/birthday-approved/`, copied from handoff `chapters/02-birthday` (ZIP SHA-256 `0a6f9ef2…5111b`); every file matches its `SHA256SUMS.txt` |
| Workflow | `proximeet-birthday-review` (manual, unsigned simulator), described in `docs/verification/birthday-mac-review.md` |

## 2. Route

Welcome → **More options** → a native choice: an alert titled "More options".

- It keeps the honest message "This prototype doesn’t include other sign-in methods yet."
- It offers **Continue the demo (no account)** and **Cancel**.
- It is an alert and not a confirmation dialog on purpose. On iOS 26, a confirmation dialog
  attached to its button opens as a popover from that button and leaves out its Cancel action.
  An alert always shows Cancel.
- Choosing the demo calls `DemoSession.begin()`, which pushes Birthday.
- Cancel changes nothing.
- The Apple notice is unchanged.

Birthday's **Back** pops to Welcome. Welcome is the navigation root, so it is never rebuilt and
its once-only pose study does not replay. The date draft lives in `DemoDraft.birthdayEntry`,
which is memory only. It survives Back and a later return in the same run. `reset()` clears it.

Adult **Continue** re-checks the date against today first. When the date is still eligible, it
shows a native alert, "Pass is next." with "This prototype stops here for now." and OK, and the
app stays on Birthday. Continue never advances the flow and never sets `dateOfBirth`. The
legacy Pass, its timer, and any signed-in or verification state stay unreachable from this
route. This is self-declaration, not verification.

## 3. Rules (ProximeetDomain, `BirthdayEntry.swift`)

- **Years before 1900 are refused** (`BirthdayEntry.earliestYear`, `.yearOutOfRange`). A
  two-digit year is refused rather than read as a guess at the century. The year wheel starts
  at the same year, so a checked date can always be shown on the wheels.
- **`CivilDate`** is a strict proleptic-Gregorian civil date. It is failable, so 31 April,
  29 February in a non-leap year, month 13 and day 0 are refused, never normalised or clamped.
  Today is the device's local calendar day (`CivilDate.day(of:in:)`).
- **`BirthdayEntry`** keeps the **draft** components (day, month and year, each optional)
  apart from the **committed** date.
  - Any change to a component clears the committed date, so Continue turns off immediately.
  - `commit(today:)` classifies the entry as empty, incomplete, impossible, year out of range, future,
    under 18 or eligible.
  - Only an eligible entry can continue.
- **Eligibility** is reached at the exact eighteenth birthday: `today >= birthday + 18 years`
  on the calendar, never a difference in days or a subtraction of years.
- **29 February (provisional policy).** In a non-leap year the anniversary of a 29 February
  birth is **1 March**, so such a person turns 18 on 1 March. This needs product and legal
  confirmation before production. It lives in one place, `CivilDate.anniversary(adding:)`.
- **Re-evaluation.** The committed date is re-checked when Birthday appears, when the app
  becomes active again (for example, the day changed while it was in the background) and
  before Continue acts. A draft that is still being edited is left alone.
- **Nothing is persisted, sent or logged.** The domain source guard still forbids the clock,
  timers, `Codable` and `UserDefaults` in the package.

Tests: `BirthdayEntryTests`, 27 cases with an injected today of 2026-09-25. They cover:

- the exact eighteenth birthday, and the day before and after;
- year-only subtraction being wrong;
- partial dates;
- 31 April;
- 29 February in 2001 (invalid), 2000 and 2024 (valid);
- two-digit and pre-1900 years;
- future dates, and today itself;
- the 1 March policy, in both leap and non-leap years;
- edits: an eligible date edited to an under-18 date and to an incomplete one;
- re-evaluation after a new day;
- flow integration: no advance, Back keeps the draft, reset clears it.

## 4. Screen

`BirthdayView` builds the approved composition at 440 × 956, following `LAYOUT_SPEC.json`:

- the header, with Back and the Bold 22 wordmark;
- the ExtraBold 56/59 headline, "First, your birthday.";
- the eligibility line;
- the graphite console;
- "Enter date instead";
- the guidance line;
- the Continue button.

The whole screen is scaled by `s = min(376, width − 64) / 376`, so smaller phones keep the
proportions. The page scrolls rather than overlapping.

**Housing.** `BirthdayHousing` holds the handoff's `birthday-housing.png`, byte-identical and
lossless. It is decoration: hidden from VoiceOver and stationary. It is cropped to the spec's
box (25, 204)–(1214, 1045) of 1254², drawn at 376 × 266. Nothing in the console is a picture of
text. The labels, values, lane, separators and cyan-strap housing are live views over the
art, as the handoff asks.

**Wheels.** One native `UIPickerView` with three components, `BirthdayWheels`.

- Its rows are 50 pt apart in a 150 pt window.
- Row styles:
  - the selected value is Manrope SemiBold 30, white;
  - the rows either side are Regular 26, #616B6E;
  - the placeholder row is SemiBold 24, #A8B0AD, reading DD, MMM or YYYY.
- Row 0 is "not set", so the screen starts unset.
- VoiceOver reads the components as Day, Month and Year, reads full month names, and reads
  the placeholder as "Not set".
- A value is committed only in `didSelectRow`, once a wheel settles. No confirm button, no
  auto-advance.
- Continue turns off as soon as a finger starts turning a wheel, and stays off until that
  wheel settles. A drag observer runs alongside the picker without taking part in its
  gestures.
- The approved selected lane (#242A2B at 76%, 308 × 58, radius 8) is drawn behind the wheels.
  UIKit's own selection bar is hidden, so there is exactly one lane. On iOS 26 that bar is a
  glass capsule drawn above the rows. It is found by its shape (it spans the wheels and is
  shorter than them), never by a private class name.
- The wheels are clipped to their 150 pt window, so only the previous, selected and next
  rows show. Values sit 4.5 pt above the middle of their row, as on the approved board.
- UIPickerView fades the rows outside its centre to about 37%. A set wheel's neighbours are
  therefore drawn in #D2E6EA, which renders as the approved #616B6E. An unset wheel keeps
  #616B6E, so its next value is only a faint hint. The approved empty state shows no
  neighbours at all; the faint hint is kept deliberately, because it shows that the control
  turns.
- Years run from 1900 to the current year.

**Typed entry.** "Enter date instead" switches to three labelled number-pad fields (Day, Month,
Year). "Use date wheels" switches back.

- The components carry over both ways. A typed value that no wheel row can show (for example
  day 35) is kept in the draft and shows as not set on the wheel.
- Each keystroke is an edit, so Continue turns off.
- The keyboard toolbar's **Done**, return, and switching back to the wheels each commit and
  check the date. Done also dismisses the keyboard.

**Guidance** (`birthday.guidance`):

- empty or incomplete: "Select your day, month and year.";
- eligible: "Check your date before continuing.";
- under 18: "You need to be 18 or older to join Proximeet." in #FFB087;
- impossible: "That date doesn’t exist. Check the day and month.";
- future: "That date is in the future. Check the year.";
- year before 1900: "Check the year. Use four digits, from 1900."

VoiceOver hears a status change only when a checked result changes. It never hears each wheel
tick or keystroke.

**Larger text.** The headline, eligibility line, guidance and Continue scale with Dynamic Type.
At the largest sizes, "birthday." shrinks to fit on its line rather than breaking mid-word.
The console's labels and values are capped at xxxLarge, because a larger wheel row cannot fit
the approved housing. That is a documented limit, not an oversight. The page scrolls at the
largest sizes.

## 5. Tests on the Mac

The Birthday test file, `ProximeetUITests/BirthdayReviewTests.swift`, uses real taps and wheel
adjustments through the real route. `testWalkthroughEntryCorrectionContinueBack` covers:

- the unset start;
- a partial date keeping Continue off;
- 12 May 1997 enabling Continue;
- the Pass notice, which stays on Birthday;
- a correction to 2012, which turns Continue off with the under-18 guidance;
- Back to Welcome;
- the draft kept on return.

`testTypedEntryPreservesComponentsAndKeyboard` covers:

- the wheel's day carrying over into the typed fields;
- typing keeping Continue off;
- Done dismissing the keyboard and checking the date;
- the wheels showing the typed date;
- 31 April refused;
- a future year refused.

`WelcomeReviewTests` keeps the geometry, reduce-motion and Apple-notice tests. Its old "More
options aren’t available" expectation was **intentionally replaced** by the new choice: the
test checks the demo button, the honest message and Cancel, and that Cancel leaves Welcome
unchanged.

## 6. Checks on Linux (Swift 6.3.3)

| Command | Result |
| --- | --- |
| `swift test --package-path ProximeetDomain` | 80 tests, 0 failures (53 existing + 27 Birthday) |
| `python3 scripts/generate_project.py --check` | up to date (adds `BirthdayWheels.swift` and `BirthdayReviewTests.swift`) |
| `python3 scripts/validate_project.py --no-plutil` | 13 checks, 0 failed; check 12 resolves `BirthdayHousing` |
| `swiftc -parse` on the changed Swift files | no syntax errors (**syntax only**) |
| `bash -n` on the harness | OK |

None of these compile SwiftUI or UIKit. Only the macOS run can.

## 7. macOS results

All runs: `proximeet-birthday-review` on mac_mini_m2, Xcode 26.6 (17F113), iPhone 17 Pro Max
on iOS 26.5 (23F77). Each is pinned with `BIRTHDAY_EXPECTED_COMMIT`, and each build record's
commit hash was checked against the push.

**Attempt 1:** build `6ab6d0be9e08eb95444d2932`, commit `88f41f8b95ff02e8568e6b7565bfa70580203da7`,
18 min 43 s.

- **Automated verdict: PASS.** Every step passed. The source gate matched. The app, the test
  harness and the domain tests compiled and passed on the Mac.
- **UI tests:** 6 of 6 executed and passed, 0 skipped. These were both Birthday tests and all
  four Welcome tests.
- **Recording:** the walkthrough was recorded, 56 s.
- **Inspected by eye against the approved board:** the route, the notices, Back, the kept
  draft, typed entry and the guidance were all correct. The console had four fidelity
  defects:
  1. iOS 26's glass selection capsule was drawn over the approved lane, dimming the selected
     value.
  2. The wheels drew part-rows outside their window, under the labels.
  3. The values sat about 4.5 pt below the design.
  4. The neighbouring values rendered at about 37% of #616B6E.

  At the largest text size, the full stop of "birthday." wrapped onto a line of its own.

  Fixes were made in code for attempt 2. Only its captures could show whether they worked.

**Attempt 2:** build `6ab6d70fd87c7a5efac39927`, commit `5daa98a1ff451fb5d78ce61654fbf7661360dcf2`,
10 min 57 s.

- **Automated verdict: PASS**, 6 of 6 UI tests.
- **The fixes that worked:** the capsule was gone, the lane was right, and "birthday." stayed
  whole at the largest size.
- **A regression the tests could not see:** every wheel value was invisible. The shape rule
  for the selection bar had also hidden the views that hold the rows on iOS 26. The wheels
  were still in the accessibility tree, so every test passed.

Two changes came from that:

- The bar is now hidden only when it holds no rows, and that decision is re-made on every
  layout pass. The intent is that a wrong call cannot stick; only the next build's captures
  can show whether that holds.
- The walkthrough now checks the pixels on screen. It fails unless each wheel's value, and in
  the adult state its previous value, is drawn visibly. The thresholds come from these two
  builds: visible values light 1,500 to 3,700 pixels, and the invisible wheels lit none.

## 8. Decisions and assumptions

1. **Native wheels via `UIPickerView`**, not SwiftUI `Picker(.wheel)`. The UIKit delegate
   reports when a wheel settles, which is the commit moment the brief asks for. It also gives
   per-row styling and native VoiceOver adjustable wheels.
2. **The placeholder is a real row (row 0).** A wheel can therefore be set back to "not set",
   and the unset state is visible and announced rather than implied.
3. **Continue shows the Pass-pending notice** and does not navigate, because Pass is not built.
4. **The legacy `submitBirthday` path** is kept for the DEBUG fixtures of later scenes. No
   screen reachable from Welcome calls it.
5. **The 29 February policy** above is provisional.
6. **Supplementary fixtures** `birthday-adult` (12 May 1997) and `birthday-under18`
   (12 May 2012) are checked against a fixed today of 2026-09-24. They are DEBUG launch
   arguments and are labelled as fixtures in every capture.
7. **One edge case with the drag observer.** A wheel that is flung and coasts back to the
   exact row it started on may not report `didSelectRow`. Continue then stays off until any
   wheel moves again. The observer only reads public `UIScrollView.isDecelerating`, and it
   uses no timers.
8. **A static review before the first build** found these, and they were fixed before
   pushing:
   - the More options popover without Cancel;
   - the missing lane in wheel mode;
   - Continue left on during a drag;
   - two-digit years;
   - duplicate attachment names in the review zip;
   - two-line guidance squeezed into one line box.
