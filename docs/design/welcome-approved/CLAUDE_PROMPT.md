# Proximeet — approved Welcome implementation prompt

Paste the prompt below into Claude Code after attaching `PROXIMEET_WELCOME_APPROVED_HANDOFF.zip` (or its extracted contents). It authorizes implementation of this screen only.

---

Implement the **approved Proximeet Welcome screen** as a faithful, reviewable native visual prototype. Work autonomously within the boundaries below; complete the implementation and available local verification, then report the result. Do not expand into the next chapter.

If your actual model and effort setting are visible, report them briefly. Do not infer or claim a model or mode you cannot see.

## 1. Approval and scope

The founder approved this Welcome design with: **“Perfect i approve go to next chapter.”** The design review notes have been updated to record that approval.

Approved direction: **A Place Opens**. A tactile ivory invitation opens into a connected miniature café, music room, and planted terrace, with a brushed steel clasp and cyan woven loop. Preserve the exact approved artwork, visual hierarchy, materials, composition, typography, colors, spacing, and restrained pacing.

This assignment implements **Welcome only**. The next onboarding chapter is still being designed. Do not design or implement it, migrate the app, build a new product architecture, or revive the old template/six-room hero. The visual reset does not authorize deleting the existing app.

## 2. Inspect and preserve the repository

The previously reported checkout is `/home/proximeet/proximeet-cloud`, with origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git` and branch `redesign/social-objects`. These are historical pointers, **not verified current state**.

Before editing:

- Read applicable repository instructions, including `AGENTS.md` if present. Inspect the actual path, origin, branch, commit, working-tree status, project structure, dependencies, and app entry/navigation flow. Do not print secrets.
- Confirm this is the intended Proximeet repository and that its actual iOS app is native **SwiftUI**. Earlier work used SwiftUI and RealityKit. A separate founder planning draft mentioned Flutter, but that migration is not approved. If the repository is missing, mismatched, or uses a different app architecture, report the precise blocker and stop implementation rather than choosing another repository or migrating frameworks.
- Preserve all existing files and uncommitted work. Make changes in a new isolated branch and worktree from an explicitly reported, locally available commit. Do not silently omit necessary uncommitted dependencies; if that prevents a safe isolated implementation, explain the specific dependency and stop. Never reset, clean, wipe, overwrite the original checkout, or discard history.
- Limit changes to Welcome, its assets, and the smallest necessary integration with the existing entry flow. Reuse existing conventions and avoid unrelated refactors or dependencies.

Do not push, merge, trigger CI or Codemagic, alter signing/entitlements, configure Apple services, deploy, or submit to TestFlight. Keep the work locally reviewable.

## 3. Exact design and assets

Figma file: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF

| Approved reference | Figma node |
| --- | --- |
| Closed Welcome | `1:33` |
| Mid-opening Welcome | `1:34` |
| Settled Welcome | `1:35` |
| Editable motion study | `1:36` |
| Review board | `10:87` |

Use Figma inspection and asset export only if those capabilities are available in your environment. Figma MCP is not a prerequisite. Otherwise use the attached exact asset bundle, reference images, and motion study. If neither route provides the approved artwork and usable layout references, finish repository discovery, then request those specific missing files before editing the screen. Never fill that gap with replacement art.

Read the extracted `PROXIMEET_WELCOME_APPROVED_HANDOFF.zip` bundle:

- `README.md` — approval, provenance, and production boundaries.
- `LAYOUT_SPEC.json` — approved native layout measurements and style values, usable without Figma access.
- `reference/welcome-settled.png` — settled-screen layout reference.
- `reference/welcome-key-poses.png` — pose/layout comparison reference.
- `reference/welcome-motion-study.mp4` — four-second 2D timing reference.
- `ART_PROMPTS.json` — asset provenance, not an instruction to regenerate the art.
- `SHA256SUMS.txt` — source-file integrity checks.
- `fonts/` — Manrope static weights 400/500/600/700/800, original variable font, original OFL license, and `FONT_SOURCE.json` with PostScript names and provenance.

If the separate `PROXIMEET_WELCOME_DESIGN_REVIEW.md` is also supplied, use its direction and production boundaries; this prompt supplies the current approval status.

The selected source artwork consists of three generated transparent RGBA PNG poses at 1254 × 1254 pixels. Verify the supplied files and dimensions. Use these exact assets:

| Pose | Bundle path | Original generated file |
| --- | --- | --- |
| Closed | `assets/welcome-closed.png` | `exec-f69a5e17-502a-4fdb-a1ca-60ea029e8b3d.png` |
| Opening | `assets/welcome-opening.png` | `exec-66856eed-7165-4d8c-bb6c-bb46174a708e.png` |
| Settled | `assets/welcome-settled.png` | `exec-3168a650-3f41-4542-97ab-9cce3bfaa761.png` |

Preserve their supplied identity. Prefer the original transparent PNGs over Figma's compressed embedded artwork. Screen exports are layout references only: **author text, controls, accessibility, and layout natively in SwiftUI**. Do not put a full-screen screenshot into the app. Do not redraw or approximate the hero with primitive geometry, cartoon shapes, procedural illustration, placeholder rooms, SF Symbols, or generated substitutes. Keep the original asset canvas, aspect ratio, margins, and pose alignment intact; reproduce the approved placement without stretching or clipping.

## 4. Build the native Welcome

Use these exact strings and the approved line break:

```text
Proximeet

Make room
for a hello.

Real places. New people. Your way.

Continue with Apple

More options

18+ only
```

Match the settled reference first. Preserve safe areas and the full hero silhouette. Prioritize the founder's iPhone 17 Pro Max layout, while allowing smaller supported iPhone widths and larger text without overlap or inaccessible controls. The approved Figma composition uses **Manrope**, including utility text. Use the supplied Manrope static font files for the inspected weights; retain `fonts/OFL.txt` with the bundled fonts. Register and use the PostScript names recorded in `fonts/FONT_SOURCE.json`. Do not silently substitute Inter or assume SF Pro was the approved artwork font. The included original variable font and provenance allow inspection of the static weight instances. If the actual runtime cannot load a font, repair registration first and report any remaining fidelity deviation explicitly. Preserve native Apple sign-in control conventions where compatible with the approved design, and document a material mismatch rather than silently redesigning it.

Treat the hero as decorative, hidden from VoiceOver. Give all actual controls appropriate accessible names and targets. Keep meaningful copy and controls readable with Dynamic Type. Text and buttons must be present and usable immediately, throughout motion. The illustration does not indicate actual venues, live attendance, nearby users, or permission to infer location.

## 5. Honest motion prototype

The existing materials are **three static generated poses**, plus a **2D timing study**. They are not a 3D mesh, rig, mechanically continuous paper fold, or verified production animation. Figma also contains static artwork within an editable composition.

Implement the approved study faithfully as a lightweight, explicitly documented **2D pose transition** using the supplied images:

- Hold the closed pose for approximately 0.4 seconds.
- Transition through the opening pose to the settled pose over the following approximately 1.0 second, matching the reference clip's placement, scale, and pacing.
- Keep the settled pose visible afterward. Do not loop indefinitely.
- Keep the UI stable and interactive. Cancel or complete the decorative motion immediately when the user navigates away; avoid detached timers or animations continuing after dismissal.
- Respect Reduce Motion by displaying the settled image immediately with no unfolding sequence. Provide the settled image as the safe fallback if motion cannot run.

Do not describe pose crossfades as continuous 3D unfolding or claim physical continuity. A custom rigged RealityKit/3D asset or a newly authored rendered animation requires a separate future approval and is outside this implementation. Do not invent that production asset in code.

## 6. Buttons and navigation must tell the truth

Inspect the existing authentication and navigation code before wiring actions.

- If a working Apple authentication integration already exists, reuse its established flow without changing backend, signing, entitlements, or account setup. Do not mark it verified unless it is actually exercised in the available environment.
- If Apple authentication is absent or unavailable, retain the approved button visually, but make its prototype action clear to the reviewer when tapped: present a concise native notice that Apple sign-in is not connected in this prototype. Do not fabricate a token, account, authenticated session, or success state.
- Reuse a known existing next-screen route only when it is verified in the repository and appropriate. If a demo continuation is needed, label that action clearly as a demo and route to that known screen or a minimal native destination stating that the next chapter is pending design. Do not invent Chapter 2's UI, copy, onboarding choices, or product behavior.
- Wire “More options” to an existing verified options flow if present. Otherwise give a clearly identified prototype notice on activation; do not invent providers or imply working authentication. Treat “18+ only” as informational text unless an established, approved flow already defines otherwise.

Keep prototype explanations in the tap response and reviewer handoff; do not add an unapproved banner that changes the settled Welcome composition.

## 7. Verify only what is available, then hand back the work

The founder uses Windows and an iPhone 17 Pro Max and has no Mac. Codemagic is available, but the Apple account/signing setup is not configured. This task does not authorize using CI to bypass local limitations.

Run appropriate existing local checks that are available in your environment and directly cover the changed code. If Xcode and an iOS simulator are available, build locally and inspect Welcome against the approved reference, including the settled screen, pose sequence, Reduce Motion, large text, and tap behavior. Capture local screenshots/video only when you can actually run it. If those tools are unavailable, do the meaningful source/asset checks you can, explicitly report the iOS build and visual runtime checks as **not run**, and leave exact local reproduction steps for a future capable environment. Do not claim simulator success, real-device testing, 60 fps performance, accessibility verification, or working Apple sign-in without evidence.

Finish with a concise handoff containing:

1. Verified repository origin, base commit, new branch, worktree path, and the Welcome entry point.
2. Files changed and how the approved original assets map into the app.
3. What was implemented visually and what each button actually does.
4. Confirmation that the animation is a 2D pose study; any remaining production-asset limitation.
5. Checks actually run, their results, and checks not run with the specific reason.
6. Review artifacts if genuinely produced, plus concise commands/steps to review the local implementation.
7. Any precise unresolved blocker or fidelity deviation. Do not claim Welcome is production-ready.

Stop after this bounded Welcome implementation and handoff. Leave the next chapter for its separate design review.
