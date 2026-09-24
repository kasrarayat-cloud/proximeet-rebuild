# Visual refinement — Social Objects material pass (source only)

Date: 24 September 2026. Base: `1db1e6f` plus uncommitted lead changes. Author: Claude Code, `claude-opus-5-5`, ultracode, ordinary permissions. Nothing committed, pushed, built, signed or dispatched.

**Evidence status.** This is a source change. It is **not** a native compile, simulator or device run, motion measurement or visual approval. Every Linux check I tried was denied by the session's permission policy (listed below), so **no automated check ran in this pass**. The lead must run the scoped checks and the Codemagic workflow.

## Lead review checkpoint

After the Opus worker exited successfully, the lead made bounded corrections: four wide shallow B1 rows (310-point object width; captions grow independently; native words retain their height), a rim aligned with the visible metal, a compact Ready paper summary with trailing edit actions, a fictional Alex filled-roster fixture, and a native simulator entrance recording. All model transitions remain unchanged. The authoring details below preserve the worker checkpoint where they differ.

Independent Linux checks now passed: 12/12 project validation; all 24 app Swift files parsed; both shell scripts passed bash syntax checks; 53 domain tests passed with zero failures; no domain source diff; whitespace check clean. These do not establish native compilation, visual approval, device performance or motion quality. The forthcoming Mac run must supply that next evidence.

## What changed

Scenes: all six entrance scenes and Ready keep their product semantics and domain transitions. The domain package is untouched.

- **Headlines**: `SceneHeader` is centred, mixed-case, heavy, normal-width system type. The `hero` role is 36 pt (Dynamic Type, relative to `.largeTitle`), with `-0.5` tracking. Forced uppercase and condensed width are gone. Callers write the preferred break as `\n` for controlled two-line wrapping at normal size; larger sizes keep wrapping and nothing truncates. The VoiceOver label replaces the break with a space.
- **B1**: four complete oval loops in a 2 × 2 grid (one column at accessibility sizes). Each loop is:
  - `WovenBandNeutral` multiplied (`colorMultiply`) by its own intent colour;
  - a white native intent word on the front strap;
  - a native dark graphite side clasp that latches on selection;
  - a contact shadow, with a local intent light spill when selected.

  The tagline sits outside the loop as scalable text. Selection shows a thin intent rim, a Carbon-on-intent check, a small lift and the clasp latch. The buttons, labels and values ("Social band", "Friends & crews. Meet new people…") and all four meanings are preserved.
- **Shared object**: `BandAssembly` (loop, word, clasp and optional plate mount) draws the same `BandGeometry` proportions in B1 (bare), B2 (146 pt loop, about 319 × 175 pt with the plate) and Ready (92 pt loop, about 201 × 110 pt).
- **B2**:
  - The hero is the larger secured band. A *smaller* landscape plate, the same `SignalPlateBlank` artwork at the plate face aspect, hangs from a link ring under the clasp. It shows its icon only and is seated by the existing arc transition.
  - The four choices are compact landscape plates, 171 × 90 pt at a 402 pt screen width (the artwork's 1.904:1 face). Each shows only a native icon and short title. Selection is a thin intent-colour rim plus a check; there is no white double ring.
  - Only the selected option's full explanation appears below the grid, followed by "Demo — not visible to anyone". The full descriptions remain the plates' accessibility values.
  - Estimated normal iPhone 17 budget: the hero, all four plates and the pinned CTA fit, with header + hero + grid ≈ 535 pt of about 650 pt of visible scroll height. These are estimates, not a render.
- **Welcome**: the complete `SocialWorldsWelcome` tableau is fitted, never cropped, with a height of 48% of the visible container (34% at accessibility sizes) via `containerRelativeFrame`. A 2% native edge fade blends its #030607 ground into Carbon. Native headline, notice and CTA sit below. The image has a short VoiceOver label.
- **Birthday**: `GraphiteAperture` is now a sculpted graphite bezel with a recessed well, an inner shadow and a static depth falloff above and below the selected row; the falloff is removed under Increase Contrast. The picker stays fully native.
- **Demo Pass**: a new `PaperSheet` (bright notched stock, fibre grain, contact shadow) is held by an aluminium `PaperClip`, with the native DEMO stamp. Copy: "Self-entered and 18+ for this demo. Not checked by anyone." and "This demo on this phone. Not a ticket."
- **Guest List**: a clipped bright paper roster that holds only the real saved entry, with a native edit link. There are no fixture attendees. The editor sheet is unchanged.
- **Ready**: the compact assembled band and plate, the "Demo — not visible to anyone" notice, and a bright paper summary with Carbon edit links. Reset is now a quiet 44 pt text action (`QuietActionStyle`), still behind the destructive confirmation dialog. The copy says it is a local demo with no real place or check-in, and that this is the end of the demo.
- **Motion**: finite and state-keyed only; the model is always updated first.
  - Welcome settles over 0.9 s, or reveals by opacity in 0.18 s under Reduce Motion.
  - Pass and roster paper settle over 0.5 s.
  - The B2 securing lift/curve and clasp close, and the plate arc seat, keep their durations.
  - VoiceOver skips entrances. Reduce Motion gives stable poses and crossfades.
  - There are no timers, loops or delayed state mutations.
- **Strict concurrency**:
  - `LiftCurvePose` is linear in progress, so it is now a plain `ViewModifier`: the standard modifiers interpolate it exactly, and there is no custom `Animatable` or isolation crossing.
  - `ArcSeat` needs its non-linear arc, so it is declared `nonisolated struct ArcSeat: ViewModifier, Animatable` with an explicit `@MainActor body`.
  - No build setting, checking level or suppression was changed. `nonisolated` on a type needs a Swift 6.1+ compiler; CI's Xcode 26.6 ships Swift 6.3. Whether the warnings are actually gone is unverified until a native build.
- **DEBUG fixtures**: new `welcome`, `birthday` and `pass` stages are built only through public transitions.
  - `birthday` submits the fixture date, then `returnTo(.birthday)`, so the wheel deterministically shows 17 May 1995 rather than the capture day.
  - Fixture dates are at 12:00 UTC so the day is the same across ±11 h time zones.

Files changed by me:

```
Proximeet/App/DebugFixtures.swift
Proximeet/Components/{BandOption,BandStage,Clasp,Fabric,IntentStyle(comment only),SignalTag}.swift
Proximeet/DesignSystem/{Adaptations,Controls,Materials,Palette,ScreenScaffold,Typography}.swift
Proximeet/Scenes/{BandSelection,Birthday,DemoPass,GuestList,ReadyForCheckIn,SignalSelection,Welcome}View.swift
scripts/codemagic_verify.sh
scripts/validate_project.py   (new check 12; existing checks untouched)
codemagic.yaml                (captures step label only; trigger/machine/Xcode/time/signing unchanged)
docs/reports/visual-refinement.md
```

- No Swift file was added or removed, so `generate_project.py` did not need to run and the pbxproj is unchanged.
- The procedural strap, clasp, hero-tag and roster views, and the unused Figma tag gradients, were removed.
- `ProfileEditorSheet.swift`, `DemoSession.swift`, `RootView.swift`, `ProximeetApp.swift` and `ProximeetDomain/` are unchanged.
- I did not touch the lead's imagesets, `docs/visual-assets/`, `docs/reports/{LEAD_STATUS,codemagic-setup,showcase-comparison}.md`, `scripts/capture_fixture_reel.sh` or `task01*.md`.

## Capture script

`captures` now:

1. installs, then makes one **uncaptured warmup launch** (`-ProximeetFixture welcome`), waits 15 s and checks the process is still alive;
2. captures 01 welcome, 02 birthday (fixture date, labelled), 03 pass, 04 guest list, 05 B1, 06 B1 selected, 07 B2, 08 B2 selected, 09 Ready;
3. captures 10, the B2 **app-level Reduce Motion preview override**, labelled as not the system setting;
4. captures 11, B2 at simulator text size `accessibility-extra-extra-extra-large`, **only if** `simctl ui <udid> content_size` reports a readable size. Otherwise that capture is skipped and recorded as SKIPPED.

When the text size is changed, the original value is restored and read back. The `EXIT` trap also restores it if a failure interrupts the capture; a failed restore fails the stage. Captures remain raw `simctl io screenshot` PNGs with process-liveness checks, TSV metadata and logs. `launch_app` uses `${1+"$@"}` for bash 3.2 with `set -u`.

## Assets and provenance (delivered by the lead during this pass)

| Name used in code | Imageset file | Mapping |
|---|---|---|
| `Image(decorative: "WovenBandNeutral")` | `woven-band-neutral.png`, 1774 × 887 RGBA | `colorMultiply(intent)`, clipped to opaque bounds + 8 px to drop faint margin flecks. Word at image (0.48, 0.76) per the lead's note; clasp at about x 0.93 |
| `Image(decorative: "SignalPlateBlank")` | `signal-plate-blank-v2.png`, 1609 × 978 RGBA | The opaque face (47–1561 × 89–884, 1.904:1) is mapped onto each frame and the transparent margin is clipped. Undistorted at the face aspect; stretched vertically, never cropped, in taller large-text frames |
| `Image("SocialWorldsWelcome")` | `social-worlds-welcome.png`, 1024 × 1536 RGB | Aspect fit, 2% edge fade, no crop |

- **Provenance**: `docs/visual-assets/asset-manifest.json` has sizes, SHA-256 and "Built-in image_gen output copied without pixel alteration". `docs/visual-assets/production-prompts.json` has the prompts and a showcase PDF page 2 reference.
- These assets were generated specifically for this rebuild at the owner's request using the built-in image tool. No external stock artwork or screenshot crops were used as production UI.
- I viewed all three PNGs read-only to calibrate geometry. I generated, edited and substituted no artwork.

## Checks

| Check | Result |
|---|---|
| `python3 scripts/validate_project.py --no-plutil` | **DENIED**, not run |
| `bash -n scripts/codemagic_verify.sh` | **DENIED**, not run |
| `git diff --check` | **DENIED**, not run |
| `swiftc -frontend -parse` (all app Swift files) | **DENIED**, not run |
| `swift test --package-path ProximeetDomain` | Not attempted: the domain is unchanged, and the fixtures are app-only, so the package tests do not cover them |
| Grep-tool scans of `Proximeet/` for the validator's forbidden APIs and dishonest phrases | Done manually, clean. Only the lowercase negations "nothing is verified" (pre-existing) and "saved, shared or verified" appear; the case-sensitive `VERIFIED` rule and phrase list do not flag them. This is not a substitute for the validator |
| Manual read-through of every changed Swift file for API and typing mistakes | Done. It is not compilation |
| Native build, strict-concurrency warning count, simulator captures, VoiceOver, Reduce Motion (system), Increase Contrast, Reduce Transparency, device motion/haptics/performance | **NOT RUN** |

Expected when the lead runs the validator (unverified): 12 checks. The new check 12 should pass because all three imagesets exist and their `Contents.json` filenames match files on disk. Checks 1–11 are unaffected, since there are no new sources and no generator changes.

## Exact permission denials

Each was automatically denied ("requires approval"; no approval surface). None was retried or worked around with an equivalent command.

1. `for f in Proximeet/App/*.swift; do echo "=== $f"; cat -n "$f"; done`, plus the same loop for `Components`, `DesignSystem` and `Scenes`. Reason given: "Contains simple_expansion". I read the files with the Read tool instead.
2. `python3 - <<'PY' …` (read-only PNG header inspection of `.claude-run/asset-transfer/woven-band-neutral.png.b64`). This was superseded once the imageset arrived.
3. `cd /home/proximeet/proximeet-cloud && python3 scripts/validate_project.py --no-plutil`
4. `bash -n /home/proximeet/proximeet-cloud/scripts/codemagic_verify.sh`
5. `git -C /home/proximeet/proximeet-cloud diff --check`
6. `cd /home/proximeet/proximeet-cloud && swiftc -frontend -parse Proximeet/App/*.swift Proximeet/Components/*.swift Proximeet/DesignSystem/*.swift Proximeet/Scenes/*.swift`
7. `git -C /home/proximeet/proximeet-cloud status --short`. The changed-file list above comes from an earlier permitted `git status` plus my own edits.

## Remaining concrete risks

- **Compilation is unproven.** The highest-risk constructs are:
  - `nonisolated struct ArcSeat` (needs Swift ≥ 6.1);
  - `if case .mounted(let signal) = mount` inside a `ZStack` builder;
  - `Text("\(Text(...).fontWeight(.semibold)): …")` interpolation;
  - `containerRelativeFrame` inside the scroll view.
- **Geometry is estimated from the artwork, not rendered.** Word, clasp, ring and plate positions come from the lead's notes and a visual read of the PNGs; confirm them on the first native captures (constants are in `BandGeometry`).
- **White strap words on bright tints** (cyan, yellow, green) rely on a dark text shadow and fall below text-contrast guidance on their own. The accessible name and external subtitle carry the meaning, and Increase Contrast adds a Carbon backing. Review this visually, and decide whether a default backing is wanted.
- **The strap word scales with the object, not with Dynamic Type.** It grows with the one-column layout at accessibility sizes, but not at xxxLarge.
- **Plates at accessibility sizes** (one column, min 180 pt) stretch the plate face vertically or horizontally. Normal sizes are undistorted.
- **Estimates to check on device.** The Welcome image's share of the visible container, and whether `containerRelativeFrame` measures above or below the action dock, affect the no-scroll estimate. The B2 no-scroll budget is also an estimate; confirm both on iPhone 17 and on a small phone.
- **Simulator text size.** `simctl ui … content_size` output format and names are assumed; if they are unreadable, capture 11 is skipped honestly rather than faked.
- **Docs.** The shared scheme's disabled fixture arguments still list only the older subset; the new fixtures work through launch arguments. The current validator has 12 checks.
