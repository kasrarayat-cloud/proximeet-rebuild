# Welcome — runtime review checklist (chapter 01)

What a real macOS build and iOS Simulator run must show before Welcome is called verified.
The authority is `docs/design/welcome-approved/` (LAYOUT_SPEC.json, the settled reference and
the motion study). The recipe that produces the evidence is `welcome-mac-review.md`; the run's own summary is `welcome/verdict.txt`, which keeps app compilation, test-harness compilation, runtime assertions and outstanding manual review apart.

**Nothing here has been run yet.** Linux checks, a syntax parse, an independent source review
and the 53 `ProximeetDomain` tests are **not** an iOS compile or runtime result. Those tests
cover the domain package only, not Welcome's UI. The legacy HaloCore package lives in a
different repository and is not covered by any of this.

Each check has an evidence source and a verdict. **A** is an automated gate or measurement from
the run. **M** is a manual human review of the artifacts or the running app. A check passes only
with its evidence attached. Screenshots are evidence of what was on screen, not proof that the
design is approved; the founder's eyes remain the authority for how it looks.

## 1. Build and source identity

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 1.1 | The checkout is exactly the reviewed revision, not the base `7af76fa` | `welcome_review.sh checkpoint`: the frozen Welcome files (`welcome-approved-files.sha256`) and every other tracked file (`welcome-review-files.sha256`) match; no extra file; the deletions are absent; optional `WELCOME_EXPECTED_COMMIT` equals HEAD. Without the pin, compare `git_head` with the reviewed SHA | A + M |
| 1.2 | Xcode is the pinned 26.6 | `codemagic_verify.sh metadata` fails on any other Xcode | A |
| 1.3 | The checked-in project is valid and unchanged by generation | `codemagic_verify.sh validate` (13 checks) | A |
| 1.4 | The app compiles for the simulator, unsigned | `codemagic_verify.sh build`: `BUILD SUCCEEDED`, bundle `com.proximeet.demo` | A |
| 1.5 | The build log has no new warnings from Welcome files | Search `logs/build.log` for `WelcomeView.swift`, `Manrope.swift`, `Adaptations.swift`, `ProximeetApp.swift` | M |
| 1.6 | The UI test harness compiles, separately from the app | `welcome_review.sh ui-review` step 1 (`build-for-testing`), recorded as `welcome-ui-build` | A |

## 2. Settled screen against the approved reference

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 2.1 | Rows at the approved positions on the 440 × 956 point screen: button 32,772 376×60; More options 32,844 376×44; headline line boxes 570–688 (centre 629; its accessibility frame is the glyph extent, 561.25 high and 135.5 tall, because the glyphs overflow the tight 59 pt lines); supporting line centre 716.5; "18+ only" centre 220,921; wordmark x 48 (±1.5 pt) | `WelcomeReviewTests.testDefaultGeometry`, and `geometry-default.json`. On any other window size the test **skips**, which is not a pass | A |
| 2.2 | Elements are in approved order and never overlap | same test, `assertOrderedWithoutOverlap` | A |
| 2.3 | Each region's pixels are close to `reference/welcome-settled.png` (mean grey difference ≤ 10), and the page, button and cyan dot colours are within 12 per channel | `analyze_welcome_review.py` on `01-welcome-settled.png` | A (heuristic) |
| 2.4 | Side-by-side visual match: hierarchy, hero placement and silhouette (not cropped or stretched), spacing, colours | Compare `01-welcome-settled.png` with the reference at the same size | M |
| 2.5 | Nothing extra: no banner, badge, navigation bar or demo label on Welcome | Screenshot | M |

## 3. Bundled Manrope

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 3.1 | All five faces register | The Debug app **asserts** at launch if any Manrope face is unavailable, so the Debug simulator launch surviving to Welcome proves registration (Release builds skip the assertion) | A |
| 3.2 | The glyphs rendered are Manrope, not the system font | Region difference and ink bounding boxes of brand, headline, supporting line, button label and "18+ only" within 3 pt of the reference (`analyze_welcome_review.py`). A system-font fallback changes glyph shapes and widths | A (heuristic) |
| 3.3 | Letterforms by eye | Compare, e.g., the headline "a", "e" and "." and the "Proximeet" wordmark against the reference | M |
| 3.4 | The OFL licence ships in the app | `Assets.car` contains the `Manrope-OFL` data set; check the built app, e.g. with `xcrun assetutil --info Proximeet.app/Assets.car` (tool availability not confirmed from here) | M |

## 4. The 2D pose sequence and Reduce Motion

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 4.1 | It starts closed, blends linearly to opening over about 0.45 s and to settled over about 0.55 s, then holds | `analyze_welcome_review.py` on `welcome-motion.mp4`. Frames before the launch are ignored. The **CONSISTENT** verdict requires: the first app frame near closed; phases monotonic; blend durations within 0.30–0.60 s and 0.40–0.70 s; at least 3 frames per blend; each blend within 0.05 of a straight line; every frame a pose (residual ≤ 20). The closed hold may be partly hidden by the iOS launch animation, so its length is reported, not gated | A (frame-timestamp resolution) |
| 4.2 | It does not loop or regress after settling | same analysis, `regressed_after_settled` false | A |
| 4.3 | It reads as the approved study, a crossfade of three illustrations, with no scale or position change | Watch `welcome-motion.mp4` next to `reference/welcome-motion-study.mp4` | M |
| 4.4 | The Reduce Motion preview shows the settled pose from the first app frame | `welcome-reduce-motion.mp4` analysis: every app frame after launch is the settled pose, with residual ≤ 20; and the XCTest `reduce-motion-preview-first-look` capture. The `02-…` screenshot is taken seconds later, so it is a layout check only | A |
| 4.5 | The **system** Reduce Motion setting does the same | Settings › Accessibility › Motion › Reduce Motion on the simulator, relaunch, watch | M |
| 4.6 | Controls work during the motion | On the simulator, tap "Continue with Apple" within the first second after launch and confirm the notice appears. XCTest waits for the app to go idle before tapping, so `testHonestNotices` cannot prove this; it only records how long after launch its tap landed | M |
| 4.7 | Leaving the screen completes the motion and nothing replays | Not reachable yet (Welcome has no route away); re-test when the Birthday route exists | Deferred |

Performance, frame rate and memory on a device are **not** measured by any of this.

## 5. Honest button notices

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 5.1 | "Continue with Apple" shows "Apple sign-in isn’t connected" / "This prototype doesn’t connect to Apple yet. Nothing was sent or saved." with only OK | `testHonestNotices`. It assumes SwiftUI alerts appear as XCTest alerts, which is common practice but not documented by Apple; on failure it attaches a screenshot and the accessibility tree | A |
| 5.2 | "More options" shows "More options aren’t available" / "This prototype doesn’t include other sign-in methods yet." with only OK | same | A |
| 5.3 | Neither navigates anywhere or changes state; Welcome stays | same: no navigation bar, the button is still hittable | A |
| 5.4 | No Apple authentication request is made | Source: no `AuthenticationServices` import or `ASAuthorization` call anywhere in the app (`grep`); runtime: no system sign-in sheet appears | A + M |
| 5.5 | Notice wording and tone | Read the two screenshots `notice-*` | M |

## 6. Safe areas, smaller screens and large text

| # | Check | How | Kind |
| --- | --- | --- | --- |
| 6.1 | The **62-point status-area assumption** | See §8.1 | A + M |
| 6.2 | "18+ only" clears the home indicator | `01-welcome-settled.png` bottom 40 pt | M |
| 6.3 | A smaller installed iPhone: hero scales down centred, nothing overlaps, all controls visible | `04-welcome-smaller-iphone.png` (only if one is installed) | M |
| 6.4 | Largest accessibility text: every element inside the width, ordered, no overlap, controls ≥ 44 pt tall, lower controls reachable by scrolling, notice still works | `testLargestTextSize` + `largest-text-*` attachments, and `03-welcome-largest-text-top.png` (simctl `content_size`, undocumented but worked in build 2). The test **skips** if its undocumented launch argument did not enlarge the text; a skip is not a pass | A + M |
| 6.5 | Headline wraps at word boundaries only; wordmark shrinks rather than truncates | Large-text screenshots | M |

## 7. VoiceOver and other system accessibility (manual only)

| # | Check | How |
| --- | --- | --- |
| 7.1 | Reading order: Proximeet, "Make room for a hello." (heading), supporting line, Continue with Apple (button), More options (button), 18+ only | Accessibility Inspector or VoiceOver on the simulator |
| 7.2 | The hero and the cyan dot are not announced | same |
| 7.3 | Notices are announced and dismissible with VoiceOver | same |
| 7.4 | Increase Contrast and Bold Text don't break the layout | Simulator settings, screenshot |

## 8. Assumptions to confirm or disprove at runtime

### 8.1 The 62-point status-area assumption

**Claim.** On the iPhone 17 Pro Max the top safe-area inset is at most 62 pt, so the brand row sits at y 64 as designed. The code places the row at `max(top inset + 2, 64)`.

**Confirmed by:**
- `testDefaultGeometry` measuring the wordmark centre at y 80 ±1.5 on a 440 × 956 window (the row top is 64), and
- the screenshot showing the row clear of the Dynamic Island.

**Disproved by:**
- a row centre below 81.5. The test then fails, and its message gives the implied inset (row top − 2), or
- the Dynamic Island overlapping the row in the screenshot.

**Limit.** XCTest cannot read the safe area directly, so if the inset is below 62 its exact value is not measured. To read it, pause the app in Xcode and use Debug › View Debugging › Capture View Hierarchy on the hosting view (manual).

### 8.2 The Apple logo

**Implementation.** The SF Symbol `apple.logo`, fitted to a 14 × 16 pt ink box inside the approved 22 × 26 pt mark box. The Figma source has a vector mark that the handoff does not supply.

**Confirmed by:**
- `analyze_welcome_review.py` region `apple_mark`: ink bounding box within 3 pt of the reference, and a low region difference, and
- a manual look at `01-welcome-settled.png` at 3× for shape, weight and colour against the reference.

**Disproved by:** a missing or placeholder symbol, a different size or position, or a visibly different glyph.

**Open whatever the result: guideline compliance.** A matching pixel check shows the build equals the approved design. It does not settle compliance. Apple's HIG for custom Sign in with Apple buttons requires:

- the logo artwork downloaded from Apple Design Resources ("never create a custom Apple logo"), which an SF Symbol is not;
- a logo and title that are both black or white, on a black or white button (the approved button is #050606 on #F6F7F2);
- title and button height in the system's proportions (the HIG gives 43% of the button height as the system-font example, not a universal number for every typeface; the approved label is 18 pt in a 60 pt button).

"Continue with Apple" and a custom font are allowed. That decision belongs to the founder, before real sign-in or an external TestFlight build. See `welcome-mac-review.md` §8.

## 9. Not in scope for this run

- Birthday or any route from Welcome. The later route is More options → "Continue the demo (no account)" → the approved Birthday, with Back returning to a settled Welcome and the Birthday draft kept in memory, creating no authentication or verification state. **It is not implemented and must not be tested or exposed by this run.** The legacy Birthday screen is not part of this review.
- Real authentication, signing, device installs, TestFlight, performance, haptics.
