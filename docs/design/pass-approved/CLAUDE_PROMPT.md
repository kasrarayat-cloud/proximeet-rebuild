# Proximeet — approved Pass implementation prompt

Paste into Claude Code with `PROXIMEET_PASS_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 3: Pass only**, as a native SwiftUI prototype matching the approved three-state design. The founder approved it on 25 September 2026: **“i approve thsi as well”**. This is a user-controlled demonstration of an age-check experience. It performs **no age or identity verification**. Report your actual model/effort only if visible; do not invent it.

## Confirm the dependency and repository

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture, and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **A Place Opens Welcome** and **Birthday** are actually implemented in the intended native SwiftUI branch, including real date entry and eligibility handling. A design file, old onboarding screen, or mock example picker is insufficient. If a dependency is missing, report it and ask the founder to run the appropriate approved Welcome or Birthday handoff first. Do not silently implement multiple chapters, switch frameworks, or regenerate their approved designs.

Preserve existing work in an isolated new branch/worktree based on a reported local commit containing the approved dependencies. Preserve dirty changes and report any dependency on uncommitted work before proceeding. If repository identity or native architecture does not match, report the blocker. Limit edits to Pass and its minimal existing navigation integration. No destructive reset/deletion, push, merge, CI/Codemagic dispatch, Apple account setup, signing, deployment, TestFlight, or paid service invocation.

## Use the supplied approved design

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=29-154

| Reference | Node |
| --- | --- |
| Pass page / review board | `26:282` / `29:154` |
| Intro / progress / complete | `27:111` / `27:112` / `27:113` |
| Shared artwork and native card text | `28:118` |
| Shared DEMO header | `28:111` |

Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `reference/pass-review.png`, `ART_PROMPT.json`, and `SHA256SUMS.txt`. Use the original `assets/pass-artwork.png` and bundled licensed Manrope fonts. Preserve `fonts/OFL.txt`. Figma access is useful but is not required when this bundle is complete. Request missing exact assets rather than substituting artwork or typography.

The reference is 440 × 956 logical units. Match measured colors, type, line breaks, spacing, target sizes, artwork placement, and native overlays in `LAYOUT_SPEC.json`. Use the original raster decoration with the source framing/crop and aspect ratio recorded there; compare against `reference/pass-delivery.jpg`. Never use a whole-screen screenshot as the interface. The paper, clip, fabric loop and backing are raster decoration, not a 3D rig. All card typography, headers, messages and controls must be native UI. Do not add a shader, particle effect, scanning beam, camera permission, fabricated biometric animation, or a new motion library.

Retain the **DEMO** badge, **18+**, **DEMO PASS**, and **PROXIMEET** native overlays in all states. The 18+ graphic describes an age category; it is not a credential. Keep this exact body copy visible in every state: **“No age or identity verification is performed.”** Do not use “verified”, “access granted”, a verification checkmark, or a provider claim.

## Implement a bounded, explicit state machine

| State | Headline / support | Primary action | Secondary action |
| --- | --- | --- | --- |
| Intro | “Your next chapter.” / “Preview the age-check experience.” | “Try the demo” → Progress | “Leave demo” → Birthday |
| Progress | “Demo in progress.” / “You control this preview.” | “Finish preview” → Complete | “Cancel” → Intro |
| Complete | “Demo complete.” / “You have finished the demo.” | “Continue preview” → review-end feedback only | “Leave demo” → Birthday |

Represent these as local demo presentation states such as `intro`, `progress`, and `complete`. Transitions happen only from the user's corresponding action. Time elapsed, animation completion, app backgrounding, screen appearance, restoration, and a previously entered adult birthday must never finish the preview automatically. Do not delay enabling Finish preview. Avoid duplicate navigation on repeated taps. Cancel resets to Intro without leaving Pass. Back is always available and returns to the actual Birthday screen, preserving its existing in-memory draft/selection. Leave demo does the same. A later re-entry to Pass starts at Intro.

Birthday's Continue enters Pass only through the approved Birthday eligibility gate. Reuse that gate; do not loosen it or create a new date policy. Do not route into the legacy timer-based verification stub. Use the actual Birthday screen for return navigation; the duplicate Birthday frame in Figma only exists to support its same-page prototype links.

Figma deliberately leaves “Continue preview” unwired. Complete that placeholder with minimal native review-end feedback reading **“End of this preview.”**, dismissible with an ordinary OK action, while staying on Complete. This is an implementation convenience for the review endpoint, not a newly approved chapter. Do not implement or route to Guest List, Places, a live room, authentication success or any gated production feature from this handoff. Report the review-end feedback as the intentional functional difference from Figma.

Keep demo state in memory. Do not set or mutate `isVerified`, age credentials, an account entitlement, or a persisted “passed” flag. No networking, verification SDK/provider, document upload, camera, biometric capture, analytics capture, real sign-in, server call or private-data logging is needed. If the existing app couples a demo transition to a real-status flag, disconnect only the minimal prototype route and report that boundary; do not rebuild backend architecture. Make no promises about future vendors, document retention or compliance.

## Motion, accessibility and verification

Reproduce the restrained 220 ms start/finish transition and 6-point pass lift/settle from the measured reference, using native animation. The paper and its native text move as one unit. Cancel and exits use a 180 ms dissolve where compatible with existing navigation. Motion never gates the actions. With Reduce Motion, keep the pass stationary and update instantly or with a brief dissolve. No idle loop or automatic transition.

Match the reference primary action at y=812, height 60, while adapting for safe areas, shorter devices and larger text. Back and secondary actions need at least 44-point targets. Maintain legible native copy, adequate contrast, focus order and VoiceOver state announcements. Hide decorative artwork from accessibility; convey the demo category once without reading redundant decorative words repeatedly. Announce progress and completion as **demo** states, never verified states. Allow scrolling when Dynamic Type requires it, with all controls reachable; do not clip important text to preserve the reference composition.

Inspect available local build tools and run meaningful checks for explicit start/finish/cancel, Back/Leave preserving Birthday state, re-entry resetting Intro, no automatic advancement, and no verified-state mutation or network calls. Avoid tests that merely mirror text literals or image coordinates. Use an available simulator/device only if already accessible; do not dispatch cloud builds. Report unavailable macOS compilation, simulator, device, VoiceOver and motion-performance checks as **not run**. Screenshots and source inspection alone are not runtime verification.

Return branch/worktree/base commit, changed files, dependency evidence, actual navigation behavior, asset/font mapping, executed checks and results, unavailable checks, reproducible preview steps, and precise deviations. Stop after this bounded Pass demo.
