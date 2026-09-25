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

Tests: `BirthdayEntryTests`, 28 cases with an injected today of 2026-09-25. They cover:

- the exact eighteenth birthday, and the day before and after;
- year-only subtraction being wrong;
- partial dates;
- 31 April;
- 29 February in 2001 (invalid), 2000 and 2024 (valid);
- two-digit and pre-1900 years;
- one component chosen: the other two stay unset and nothing is committed;
- future dates, and today itself;
- the 1 March policy, in both leap and non-leap years;
- edits: an eligible date edited to an under-18 date and to an incomplete one;
- re-evaluation after a new day;
- flow integration: no advance, Back keeps the draft, reset clears it.

## 4. Screen

`BirthdayView` builds the approved composition at 440 × 956, following `LAYOUT_SPEC.json`:

- the header, with Back and the Bold 22 wordmark. The wordmark is set on Figma's 24 pt line at
  the top of its box at y = 70, not centred in the 44 pt row;
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
- The wheels are clipped to their 150 pt window in SwiftUI. The picker keeps its own taller
  height, so its row spacing is unchanged.
- **At rest, a wheel is built to draw only the rows the approved design shows.** This is
  unverified until the correction build's captures show it.
  - An unset wheel draws its placeholder alone (DD / MMM / YYYY, as in the approved empty
    state).
  - A set wheel draws its previous, selected and next values. Its other rows are drawn clear.
  - A finger turning a wheel reveals that wheel's rows, in place (a reload would pull the wheel
    back under the finger), and only that wheel's. It returns to its approved rows when it
    settles.
  - While it turns, every row takes the selected lift, so the value that settles does not
    jump.
- **The lifts are chosen to put the values where the approved board does.** The row positions come from Figma's text
  boxes, measured centres (points) on the board:

  | Row | Board centre | Lift |
  | --- | --- | --- |
  | Previous | 468.7 | 5.75 pt |
  | Selected | 516.0 | 5.5 pt |
  | Next | 568.7 | 0.75 pt |

  The design places the previous value 48 pt above the selected one and the next value 52 pt
  below it, while UIPickerView spaces its rows symmetrically. So each value is drawn at a lift
  computed from attempt 4's measurements (section 7, the correction). The selected row's lift
  corrects its measured offset directly. The neighbours' lifts assume that the wheel's curve
  moves them by about 0.8 of the lift. Only the next build can show whether they land at 468.7
  and 568.7.
- UIPickerView fades the rows outside its centre to about 37%. A neighbour is therefore drawn
  in #D2E6EA, which renders as the approved #616B6E.
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
| `swift test --package-path ProximeetDomain` | 81 tests, 0 failures (53 existing + 28 Birthday) |
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
  the adult state its previous value, is drawn visibly. The thresholds were measured on these
  two builds' captures:

  | What | Attempt 1 (visible) | Attempt 2 (invisible) |
  | --- | --- | --- |
  | Values, pixels above 100 | 1,500–3,700 | 0 |
  | Previous values, pixels above 45 | 611–2,085 (these were attempt 1's dimmest, the defective ones) | 0 |

  The test requires more than 150 value pixels and more than 60 previous-value pixels. The
  result of the next build is not recorded here, because a commit cannot contain its own
  build's result.

**Attempt 3:** build `6ab6db53d7b32e57ee0d9a2b`, commit `a2cf63cdf6cf311fc70108b1efc939a3d8add5ce`,
11 min 15 s.

- **Automated verdict: PASS**, 6 of 6 UI tests, including the new on-screen visibility check.
  Lit pixels per wheel: values 2,410–4,991, previous values 1,765–3,461.
- **Inspected by eye:**
  - the capsule was gone, and the approved lane showed once;
  - the values were drawn in white, on the reference's baseline;
  - the neighbours were close to the reference's brightness;
  - "birthday." stayed whole at the largest text size.
- **One deviation left:** part-rows (for example "10 Mar 1995") showed at the window's top and
  bottom edges, most visibly on the smaller iPhone. UIPickerView sizes itself taller than its
  150 pt frame, so clipping inside UIKit did not reach them. The next commit clips the window
  in SwiftUI instead. Its result is reported with its own build, not in this file.

**Attempt 4:** build `6ab6df017f26dea8bc58699b`, commit `308204cea43735d87eab93ebafc6e266968c310a`,
10 min 8 s.

- **Automated verdict: PASS**, 6 of 6 UI tests.
- **Delivered for visual review.** The founder did not approve three deviations:
  1. the faint "1 Jan 1900" under the empty placeholders;
  2. a part-row at the date window's bottom edge;
  3. a vertical shift of 3–4 pt.

### The correction (founder's review of attempt 4)

**Measured first, at 440 × 956.** The screenshots (1320 × 2868 px, scale 3) were compared with
the approved board (frames at 0.75 scale; its frame top at 123 px is confirmed by Continue at
732 px and the housing at 407 px). Text was compared by where the glyphs start and end, the
same way on both.

- **Crisp anchors were already on spec.** In points:
  - Continue: 812–872;
  - housing: 378–644;
  - column separators: 504–536;
  - Back arrow: 80–92.7 (Figma's vector is 80–92).
- **Text anchors also matched the board to within 0.7 pt**, including the safe-area-dependent
  header: headline 164.0–277.3, eligibility line 294.3, "Enter date instead" 698.3, guidance
  745.3. Welcome's geometry test confirms the top safe-area inset is at most 62 pt.
- **The one shifted element was the wordmark.** Its capitals started at 78.3 against 74.7 on
  the board. The cause was a text baseline, not a layout offset. Figma sets Bold 22 on a
  24 pt line at the top of its box at y = 70, which gives capitals from 74.6. The app centred
  the word in the 44 pt header row, which gives 78.6. It is now set on Figma's line box. No
  global offset is applied, and the reference is untouched.
- **The wheel rows** were within 1 pt at the top and 3 pt high at the bottom. The centres were
  469.7 / 517.0 / 565.7 against the board's 468.7 / 516.0 / 568.7. The lifts in section 4
  correct them.
- **The part-row at the bottom edge** was the tops of the row after next (595.3–596, against
  the window's edge at 596). At rest those rows are now drawn clear. The next build's
  captures show whether that removes the part-row.
- **The faint "1 Jan 1900"** was an unset wheel drawing its next row. At rest an unset wheel's
  other rows are now drawn clear, which is unverified until the next build. The model was
  already unset. A new domain test confirms it:
  a new entry has no day, month or year, choosing a day sets nothing else, and checking fills
  nothing in.

**New checks on the rendered screen.** Accessibility strings alone do not prove that text was
drawn:

- the empty state draws nothing around the three placeholders;
- the day alone draws its neighbours, while month and year stay unset in the model, in the
  accessibility tree and on screen, and Continue stays off;
- a real finger drag turns the day without setting or drawing month or year;
- a short drag on the unset month, released back onto it, leaves the placeholder alone
  again;
- the window's top and bottom edge strips are clear;
- ten rendered anchors match the approved board's measurements.

Each band is measured inside Figma's column boxes. XCUITest reports the picker's own
320 pt frame, which takes in the housing's lit bezel. Simulated on attempt 4's screenshots,
the new checks fail on exactly the three reported defects and pass everything else.

The check added after attempt 2, that values are visible, is kept.

The result of the correction build is reported with its own artifacts, not in this file.

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
7. **Rows are revealed when a finger starts turning a wheel.** A revealed wheel that comes
   to rest exactly on its selected row returns to its approved rows, even when UIKit does not
   report `didSelectRow`. The check runs when the finger lets go and again after each scroll
   step, observed through the wheels' scroll offsets, until the wheel rests. It uses no
   timer.
8. **One edge case with the drag observer.** A wheel that is flung and coasts back to the
   exact row it started on may not report `didSelectRow`. Continue then stays off until any
   wheel moves again. The observer only reads public `UIScrollView.isDecelerating`, and it
   uses no timers.
9. **A static review before the first build** found these, and they were fixed before
   pushing:
   - the More options popover without Cancel;
   - the missing lane in wheel mode;
   - Continue left on during a drag;
   - two-digit years;
   - duplicate attachment names in the review zip;
   - two-line guidance squeezed into one line box.
