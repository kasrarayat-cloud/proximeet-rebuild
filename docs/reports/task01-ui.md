# Task 01B — native SwiftUI demo and B1/B2 report

Date: 24 September 2026 · Base: commit `4d5bc4c` (reviewed domain). Finalized by the lead after independent review and local generation. Prepared for a local commit; nothing pushed, signed, uploaded or sent to CI.

## Evidence summary

| Area | Status |
|---|---|
| SwiftUI source (24 files, full flow, B1/B2 detail) | **Implemented**, source only |
| Syntax parse of all 24 files (`swiftc -frontend -parse`) | **PASS**. Syntax only: no type checking, no Apple SDK |
| Type check / native compile against the iOS SDK | **NOT RUN**. No Mac. The Linux type-check of the two non-SwiftUI files was blocked (see Blocked actions) |
| Project generation (`generate_project.py`, `generate_app_assets.py`) | **PASS**. The lead reviewed and ran both scoped scripts; direct exit 0. The project, assets and manifest exist on disk |
| `validate_project.py` on disk | **PASS**, independently run by the lead after review fixes: 11 checks, 0 failed, direct exit 0 |
| Earlier `validate_project.py --rendered` | Historical worker check: 10 executed, 0 failed; check 10 skipped. Superseded by the complete on-disk check above |
| Domain tests | Not re-run. `ProximeetDomain` is unchanged since the reviewed commit `4d5bc4c` |
| Simulator/device run, screenshots, VoiceOver, haptics, performance, TestFlight | **NOT RUN** |
| Visual approval / Figma or PDF fidelity | **NOT CLAIMED** |

## Lead verification and review closure

The lead generated the project/assets after reading the scripts and receiving an independent project-wiring review. The worker's narrow command allowlist was left unchanged. Final direct-exit checks after the fixes:

- `python3 scripts/validate_project.py --no-plutil`: 11 checks, 0 failed, exit 0.
- `swiftc -frontend -parse <all 24 app Swift files>`: exit 0, no diagnostics. This is syntax only, not Apple SDK type checking.
- `git diff --exit-code HEAD -- ProximeetDomain`: exit 0, confirming the independently tested domain is unchanged.
- `git diff --check`: exit 0.

The source scan covers app production sources; the separately executed domain source-guard tests cover domain production sources. The lead's earlier independent domain run passed 53 XCTest cases with no warnings. Final logs are private ignored files in `.claude-run/lead-native-final-*.log` and `.claude-run/lead-domain-test.log`.

Independent native review confirmed the profile-save, reset, navigation and calendar contracts. The lead closed three small findings: the B1 latch has static geometry under Reduce Motion; B2 securing uses the shared policy to skip decorative arrivals for VoiceOver; and the editor preview now uses an empty Guest List fixture where saving is allowed. No domain behavior changed.

Claude wrote the implementation and report draft using Opus 5.5 / ultracode. The lead stopped that owned run after source delivery while a duplicate review was pending, then finalized these fixes and this report. A process success status is not evidence of native acceptance.

The lead viewed the generated icon: it is a coherent interim four-band illustration, not approved final brand artwork. App screens, motion, haptics and device accessibility have not been visually or physically verified.

## Changed files

Source files, all new under `Proximeet/`:

```
App/ProximeetApp.swift          @main; DEBUG-only launch fixtures; Reduce Motion preview override
App/DemoSession.swift           @Observable wrapper over DemoFlow (no SwiftUI import); reset generation
App/RootView.swift              NavigationStack(path:) bound to the domain path; keyed on reset generation
App/DebugFixtures.swift         #if DEBUG launch arguments + explicitly fictional fixtures ("Fixture")
DesignSystem/Palette.swift      Social Objects tokens, Figma metal gradients, CSS-angle helper
DesignSystem/Typography.swift   Scaled type roles (SF Pro Condensed Heavy / SF Pro)
DesignSystem/Adaptations.swift  @Adaptive accessibility context, motion score, arc/lift modifiers
DesignSystem/Controls.swift     Primary (56 pt), secondary/destructive (48 pt), edit link (44 pt), object press
DesignSystem/Materials.swift    NotchedPlate (offset-notch signature), MetalSurface, grain, graphite aperture
DesignSystem/ScreenScaffold.swift  Nav bar brand/step, scrolling body, action dock, header, notices
Components/IntentStyle.swift    Intent colours, interim SF Symbols, Figma taglines
Components/Fabric.swift         Procedural woven strap (ribs, weft, shading, highlight, stitching)
Components/Clasp.swift          B1 band clasp; B2 stage clasp with latch
Components/BandOption.swift     B1 band object button
Components/SignalTag.swift      B2 tag choice + hero tag
Components/BandStage.swift      Persistent secured band + seated tag (B2 and Ready)
Scenes/WelcomeView.swift, BirthdayView.swift, DemoPassView.swift, GuestListView.swift,
Scenes/ProfileEditorSheet.swift, BandSelectionView.swift, SignalSelectionView.swift,
Scenes/ReadyForCheckInView.swift
```

Scripts, all new: `scripts/generate_project.py`, `scripts/generate_app_assets.py` and `scripts/validate_project.py`. All three use only the Python standard library and are deterministic.

The lead generated these files from the reviewed scripts:

```
Proximeet.xcodeproj/project.pbxproj
Proximeet.xcodeproj/project.xcworkspace/contents.xcworkspacedata
Proximeet.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
Proximeet.xcodeproj/xcshareddata/xcschemes/Proximeet.xcscheme
Proximeet/Resources/Assets.xcassets/{Contents.json, AccentColor.colorset/Contents.json, AppIcon.appiconset/{Contents.json, AppIcon-1024.png}}
Proximeet/Resources/PrivacyInfo.xcprivacy
```

The domain, design specification and worker permissions are unchanged. The lead added a review-closure record and updated status documentation. `docs/reports/task01-domain.md` is untouched in this native increment.

## Integration contracts

- **Profile save.** `ProfileEditorSheet` calls `session.saveProfile` and dismisses **only** on `.saved`.
  - `.invalid` keeps every visible edit, shows each issue next to its field, moves focus to the first one and announces it.
  - `.unavailable` shows an inline message.
  - Cancel discards the edits, and the prior valid profile stays.
  - Guest List's "Continue to band" is a separate action that exists only once a saved profile exists. `continueFromGuestList()` is never called after a save attempt.
  - The domain still enforces this regardless of the UI.
- **Birthday calendar.** `BirthdayView` holds one `DemoSession.birthdayCalendar()` (Gregorian, current time zone). That same value is injected into the `DatePicker` (`\.calendar`, `\.timeZone`) and passed to `BirthdayEligibility`.
- **Back navigation.** `NavigationStack(path: $session.path)`; the setter calls `DemoFlow.adoptNavigationPath`, which accepts only pops. Forward moves happen only through validated domain actions.
- **Reset.** `DemoSession.reset()` clears the flow and increments `resetGeneration`. The whole `NavigationStack` is keyed on that number, so picker selections, form text and dialogs are discarded too. Reset is offered on Ready, and on Welcome once any data exists; both ask for confirmation.
- **Edits from Ready.**
  - "Edit profile" opens the same sheet in place.
  - "Change band" and "Change signal" call `returnTo(.band)` or `returnTo(.signal)`, which removes readiness until the user confirms again.
  - Existing values stay preselected.

## B1 and B2

**B1 (Band).**
- **Layout:** headline "Which band tonight?" with supporting line "One intent. Your kind of connection." as in Figma, followed by four woven bands (Social #35D7FF, Dating #FF56B8, Business #FFD542, Activity #70F455).
- **Each band:** a Carbon uppercase word, the Figma tagline and a metal clasp holding the intent icon.
- **Selection** changes the object itself:
  - it lifts (scale 1.02, not under Reduce Motion) and gains a local colour light spill (not under Reduce Transparency);
  - the latch engages, a 2 pt Porcelain ring appears (3 pt with Increase Contrast), and a check mark sits next to the word.
- **VoiceOver:** "Social band, Friends & crews", with the Selected trait.
- **CTA:** "Choose Social", derived from the actual choice ("Select a band", disabled, when nothing is chosen). It calls `confirmBand()`, which moves straight to Signal.

**B2 (Signal).**
- **Layout:** headline "Make your hello clear." and the intent as subtitle.
- **The same band** appears on the stage in its **secured pose**, with the clasp closed.
- **Four machined tags:** Come say hi / Chat first / With my crew / Just looking, each with a native label and the domain's neutral description.
- **Selecting a tag** seats that tag's hero on the band's clasp immediately.
- **Below the tags:** "Chosen signal: X", a preview line using the real first name, band and signal, and "Demo — not visible to anyone". CTA "Set my signal" leads to Ready.

**Ready.** "Ready for check-in." The "Demo — not visible to anyone" banner, the persistent band and tag, and the real name, interests, band and signal, each with an edit link. There is no check-in, venue, presence or verification action.

**Copy changes from Figma.**
- B1 footer "Select any band · locks only when you join a session" is **omitted**; not ratified.
- B2 footer "Visible only after venue check-in" is **replaced** with the demo visibility notice.
- The 11 pt Figma supporting text is raised to scalable 15 pt roles.
- The headline uses a 44 pt base in SF Pro Condensed Heavy (Figma: 48 pt Barlow Semi Condensed); this needs a native render comparison.

## Motion (proposed targets; nothing measured)

| Trigger | Standard | Reduce Motion |
|---|---|---|
| Band screen arrival | Offset of 18 pt and opacity from 0.35, 0.42 s per band with 0.08 s stagger (≈0.66 s total). Bands are visible and tappable from the first frame. Plays once per screen instance; skipped under VoiceOver | Everything appears at once |
| Band selection | 0.18 s snappy emphasis | 0.12 s ease, no scale |
| Band confirmed → secured pose on B2 | Lift and curve (3D tilt, narrower scale, 22 pt lift) settling over 0.75 s; clasp closes at 0.42 s and finishes at 0.72 s | Static secured pose, 0.18 s opacity crossfade |
| Signal selected → tag seated | One arc from below-left with a slight rotation, then settling on the clasp, 0.55 s | 0.15 s opacity crossfade, no translation or rotation |

State always changes first, synchronously in the domain; animations only decorate it. Navigation never waits for them. There are no `TimelineView`, `repeatForever`, timers, `asyncAfter` or completion handlers, and the validator guardrails check for them. Delays are part of the animation curve, so nothing runs after the view has gone. The secured pose is keyed to each B2 view instance; its behavior when returning from Ready remains part of native navigation acceptance.

Haptics:
- `.selection` fires when a band is chosen.
- A light impact fires when a tag is seated.
- There is no success haptic and no haptic on navigation.

## Accessibility implementation

- **Type:** every text role uses `@ScaledMetric` relative to a text style, with wrapping and no minimum scale factors. Nav bar brand, step and DEMO badge are capped at xxxLarge and support the Large Content Viewer.
- **Layout at accessibility text sizes:**
  - bottom actions move from the pinned dock to the end of the scrolling content;
  - tags become a single column and the welcome grid becomes one column.
- **VoiceOver:**
  - headlines have the header trait;
  - bands and tags have labels, values, hints and the Selected trait;
  - the band stage is a single element ("Social band, secured, with the Chat first tag attached");
  - pass, guest entry and summary rows are combined;
  - decorative metal, fabric and icons are hidden;
  - rejected birthday dates and profile errors are announced.
- **Targets:** primary actions have a minimum height of 56 pt, secondary 48 pt and edit links 44 × 44. Bands are at least 65 pt tall, and tags at least 100 pt.
- **Increase Contrast:** lighter supporting text (#D6DADD), thicker selection rings and outlines, Porcelain borders on notices and summary, and half-strength weave texture.
- **Reduce Transparency:** no colour light spill or glow. The action dock, notices and cards are opaque.
- **Contrast:** text sits on static regions. There are no moving highlights, and selection is never shown by colour alone (ring, check mark and Selected trait).
- **Previews:** they use `.dynamicTypeSize(.accessibility5)` and the app's own `prefersReducedMotionPreview` key. No get-only accessibility environment key is written anywhere.

## Fidelity gaps (interim implementation choices)

- **Icons:** the Figma SVG downloads failed validation (HTML was returned), so these SF Symbols are **interim semantic substitutes** matching the described glyphs:
  - bands: `person.2` (people), `heart`, `briefcase`, `mountain.2` (activity);
  - tags: `hand.raised` (wave), `bubble.left` (chat), `person.2` (crew), `eye`;
  - action arrow: `arrow.right`.
  - Final icon fidelity is unresolved.
- **Typography:** SF Pro Condensed Heavy replaces Barlow Semi Condensed ExtraBold, and SF Pro replaces Inter. A native render comparison is pending.
- **Materials:** fabric, aluminium and grain are procedural native studies; they are not the photoreal artwork in the PDF. The one bounded Metal effect the brief mentions is deliberately not implemented in this increment, and the guardrails would have to change to allow `import Metal`.
- **Welcome worlds** are SF Symbol tiles, not bespoke miniature environments.
- **App icon** is original procedural interim artwork produced by `scripts/generate_app_assets.py`: four woven bands with aluminium clasps on Carbon. Nothing is external, from Figma or from the legacy app.

## Project configuration

- **Settings:** objectVersion 60 (compatibility "Xcode 15.0"), one target `Proximeet` (iPhone, portrait, iOS 17.0), Swift 5 mode with `SWIFT_STRICT_CONCURRENCY = complete`, and a generated Info.plist with display name "Proximeet Demo".
- **Declarations:** dark interface style, `ITSAppUsesNonExemptEncryption = NO`, no usage descriptions, no entitlements and no capabilities.
- **Bundle ID `com.proximeet.demo` is provisional.** It must be registered under the owner's Apple team before any distribution. `DEVELOPMENT_TEAM` is absent. The simulator needs no team; a device needs one chosen locally in Xcode, and that choice must not be committed.
- **Build phases:** Sources, Frameworks and Resources only. There are no scripts, remote packages, analytics, workflows or publishing automation.
- **Local package:** `XCLocalSwiftPackageReference` to `ProximeetDomain`, with product `ProximeetDomain` linked.
- **Shared scheme:** `Proximeet`. Build uses the app; test uses `ProximeetDomainTests` (`container:ProximeetDomain`). It also has seven DEBUG fixture launch arguments, all disabled by default.
- **Privacy manifest:** no tracking, no tracking domains, no collected data and no required-reason APIs. This matches an offline, in-memory app.

## Earlier worker commands and outcomes (historical)

```
swiftc -frontend -parse <all 24 files under Proximeet/>          → exit 0, no diagnostics (syntax only)
python3 scripts/validate_project.py --no-plutil                     → 11 checks, 10 failed (generated files absent; guardrails PASS)
python3 scripts/validate_project.py --rendered --no-plutil          → 11 checks, 0 failed (check 10 skipped; in-memory, nothing written)
```

## Worker permission limits (historical)

These limits applied to the Claude worker. The lead subsequently generated the reviewed project/assets under the owner's existing rebuild authorization; no worker permission was changed. The type-check below remains unrun. Optional workflow review remained blocked, and separate read-only reviewers were used.

- `python3 scripts/generate_app_assets.py` → "This command requires approval" (this session and the helper agent)
- `python3 scripts/generate_project.py` (and `--check`) → "This command requires approval" (this session and the helper agent)
- `swiftc -typecheck -swift-version 5 -strict-concurrency=complete -D DEBUG -I ProximeetDomain/.build/x86_64-unknown-linux-gnu/debug/Modules Proximeet/App/DemoSession.swift Proximeet/App/DebugFixtures.swift` → "This command requires approval". This would have fully type-checked the two app files that don't import SwiftUI.
- Workflow tool (optional multi-agent review) → "Review dynamic workflow before running". Replaced by self-review and one read-only reviewer agent.
- Compound shell commands (`… ; echo …`) → approval required. They were re-run as single allow-listed commands.

## Mac build and capture sequence (NOT RUN here)

The branch is local to the VPS. Transfer this exact committed worktree to the connected Mac without relying on an unpushed GitHub branch. Open `Proximeet.xcodeproj` and use the shared `Proximeet` scheme.

1. Record `xcodebuild -version`, `xcrun simctl list devices available`, and `xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -showdestinations`.
2. Select an available iPhone simulator by its actual destination identifier. Run Debug `xcodebuild build` and `xcodebuild test` with that destination and a local DerivedData path. No Apple team is needed for simulator verification.
3. Run the complete flow from Welcome and capture B1, B2 and Ready on small and large displays. DEBUG launch fixtures are documented in `Proximeet/App/DebugFixtures.swift`; they are disabled in the shared scheme by default.
4. Inspect the system Accessibility settings and repeat with largest text, Reduce Motion, Increase Contrast and Reduce Transparency. Use the simulator's advertised controls for the installed runtime; record the exact device/runtime and commit.
5. Check VoiceOver behavior, haptics and frame pacing on an actual device before claiming them verified.

The app-level `-ProximeetReduceMotionPreview YES` flag is useful for quick captures but does not replace testing the real system setting. App icon, typography, custom glyphs and material fidelity need visual refinement against the Figma/PDF direction. Only after native acceptance should the owner's Apple team, unique bundle ID, signing and TestFlight distribution be configured.

## Acceptance checklist (to be run on a Mac or device; all unchecked)

- [ ] Clean build of scheme `Proximeet` for the iOS 17 simulator with no errors. List any strict-concurrency warnings.
- [ ] `xcodebuild test` runs `ProximeetDomainTests` from the scheme.
- [ ] Full flow on iPhone SE: Welcome → Birthday → Demo Pass → Guest List → Band → Signal → Ready. No clipped text, and the action dock never covers content.
- [ ] Birthday: exactly 18 today is accepted; one day short is rejected with a message; the picker cannot select future dates.
- [ ] Profile: blank, duplicate or over-long values keep the sheet open with errors next to the fields. Cancel keeps the prior profile; Save closes the sheet only on success.
- [ ] Back gesture on every screen keeps the entered values. "Change band" and "Change signal" on Ready return with the values preselected.
- [ ] Reset from Ready and from Welcome clears everything, including the birthday picker and form text on re-entry.
- [ ] Largest accessibility text (AX5): all screens scroll, tags form one column, actions sit inline, and no text is truncated or overlapping.
- [ ] VoiceOver: logical order on B1/B2/Ready; bands and tags announce name, description and Selected; the band stage reads as one element; errors are announced; no decorative element gets focus.
- [ ] Reduce Motion: B1 shows no lift or scale; B2 shows a static secured pose with an opacity crossfade; the tag change is opacity-only; the resulting states are identical to normal motion.
- [ ] Increase Contrast and Reduce Transparency: stronger rings and outlines, lighter supporting text, no glows. Text contrast stays readable on every surface.
- [ ] Rapid taps across bands or tags always end on the last tap; B1 → B2 navigation is immediate while animations run.
- [ ] Haptics on a device: selection tick when a band is chosen, light impact when a tag is seated, nothing on navigation.
- [ ] Performance on a device (frame pacing through the B1 → B2 transition and tag seating) and memory, recorded with the device and commit.
- [ ] Visual review against the Figma B1/B2 screenshots and the Social Objects PDF, with icon, font and material gaps recorded.
