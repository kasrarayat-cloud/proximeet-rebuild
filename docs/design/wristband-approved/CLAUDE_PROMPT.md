# Proximeet — approved Wristband implementation prompt

Paste into Claude Code with `PROXIMEET_WRISTBAND_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 5: Wristband only**, as a native SwiftUI prototype matching the approved five-state intent selector. The founder approved this design on 25 September 2026 UTC: **“on wrist section its perfect i approve it”**. This is approval of the app screen and decorative material family. The future physical wearable concept, Pulse, is separate. Report your actual model/effort only if visible; do not invent it.

## Confirm dependencies and repository

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **A Place Opens Welcome**, **Birthday**, explicit user-controlled **Pass** demo and **Guest List** are actually implemented in the intended native SwiftUI branch. Birthday must have real date entry and its eligibility gate; Pass must have explicit demo controls and no timer-based verification success; Guest List must have genuine editable fields, its optional introduction/interests and preserved in-memory draft. Design files, legacy onboarding and static sample controls do not establish these dependencies. If a chapter is missing, report it and ask the founder to run its approved handoff first. Do not silently implement multiple chapters, switch frameworks or regenerate approved designs.

Preserve existing work in an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes; report any dependency on uncommitted work before proceeding. If repository identity or native architecture differs, report the blocker. Limit edits to Wristband and minimal integration with the approved Guest List route. No destructive reset/deletion, push, merge, CI/Codemagic dispatch, Apple setup, signing, deployment, TestFlight, hardware purchase or paid service invocation.

## Use the supplied approved design

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=45-166

| Reference | Node |
| --- | --- |
| Page / review board | `42:111` / `45:166` |
| Empty / Social / Dating | `42:112` / `42:113` / `42:114` |
| Business / Activity | `42:115` / `42:116` |
| Founder approval annotation | `51:190` |

Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `reference/wristband-review.png`, `ART_PROMPTS.json` and `SHA256SUMS.txt`. Match native copy, typography, geometry, colors, strokes, radii, icons and selection indicators in the measured specification. Its five complete node trees include exact vector paths and text styles. The review board's outer awaiting-approval caption is historical; this dated approval record supersedes it. That caption is not app copy.

The supplied original RGBA artworks are `assets/wristband-social.png`, `assets/wristband-dating.png`, `assets/wristband-business.png` and `assets/wristband-activity.png`. Each is 1254 × 1254. Apply the **same crop `[22, 335, 1235, 920]`** to all four, retaining alpha, then fit without stretching. Compare with the exact 540 × 260 JPEGs in `reference/`, which are composited on RGB(5,6,6). Use the originals in the app; the JPEGs establish framing. In the empty state all four bands have equal 182 × 88 reference bounds. A selected state shows only its chosen band in 376 × 181 bounds, centered vertically inside the 376 × 200 hero.

Do not regenerate the artwork, recolor one image programmatically, substitute stock bands or use a whole-screen screenshot as UI. Color and weave intentionally differ: coral basket weave, orchid herringbone, blue rib and amber chevron. The object art has no text or symbols. Every label, tile, icon, checkmark, explanation and action remains native UI. Preserve the native vector appearance using the supplied paths; do not replace icons with emoji or font codepoints.

Bundle the supplied licensed Manrope static fonts and preserve `fonts/OFL.txt`. Use the 440 × 956 logical reference for comparison, adapting for actual safe areas, available width and Dynamic Type. It is not a fixed device screen contract.

## Implement genuine single-choice state

Use one optional typed intent value for this onboarding draft: no selection, Social, Dating, Business or Activity. Do not use four independently selected Boolean flags. **First entry in a fresh session has no default selection.** Do not infer an intent from Guest List content, name, age, prior screenshots or a sample fixture.

Keep the headline **“Choose your\nkind of hello.”**, support **“One intent for this moment.”**, persistent **“DEMO”**, and privacy copy **“Choosing a band doesn’t make you visible.”**

| Intent | Tile hint | Selected explanation |
| --- | --- | --- |
| Social | People & moments | Meet people. Share a moment. |
| Dating | Romantic connection | Explore a romantic connection. |
| Business | Ideas & work | Exchange ideas and opportunities. |
| Activity | Do something | Find someone to do things with. |

Keep this row order: Social/Dating, then Business/Activity. Empty summary is **“Your moment. Your choice.”** and **“Pick the band that fits right now.”** Selecting any tile immediately sets that single intent, swaps to its large artwork, adds the native selected check and border, and changes the summary to **“[Intent] · Selected”** with the matching explanation. All four tiles remain available. Selecting a different tile replaces the old value; tapping the already-selected tile does nothing and does not clear it. There is no automatic advance, timer, backend write or haptic hardware event.

**“Continue preview”** is disabled while no intent is selected and enabled after any choice. The visible choice helper and accessibility description must explain the requirement without depending on tapping a disabled control. Avoid announcing an error before the user interacts. Store only the enum as source of truth; derive the artwork, labels, selected traits and CTA state from it so they cannot disagree.

## Navigation and prototype boundary

Replace Guest List card's temporary **“End of this preview.”** action with entry into the approved Wristband screen. This is the only earlier-chapter behavior changed. Preserve the user's actual introduction and its raw edit draft; never substitute the fictional Alex fixture.

Both Wristband Back actions return to the actual Guest List card preview, not a cloned static screen or a new Guest List instance. Revisiting Wristband in the same onboarding session preserves the chosen intent, including no selection if none was made. Returning further to the Guest List editor, editing the introduction and coming forward again must not reset that intent or rerun Pass. Figma's same-page Guest List clone is only a navigation reference; its reset-to-empty behavior is not the native state contract.

Until Chapter 6 has its own approved implementation handoff, Wristband **“Continue preview”** displays a minimal dismissible native message **“End of this preview.”** with OK and stays on the selected Wristband state. The Figma CTA is intentionally unwired; this endpoint supplies honest feedback without implementing an unapproved chapter. Repeated taps must not stack alerts or duplicate routes. Do not implement Signal, Places, venue check-in, profiles of others, rooms, Wave, chat or Keep.

The intent belongs to the in-memory prototype draft only. Do not write it or Guest List content to disk, server, logs, analytics, account storage or backups. Relaunch starts a fresh unselected draft unless a later approved persistence contract explicitly changes that scope. Selecting a band does not verify age/identity, sign in, check in, set presence/discoverability, reveal location or grant approach/message consent. Approach preference is a separate future Signal choice. Existing same-intent Wave and mutual-consent rules must not be weakened or bypassed.

No networking, real sign-in, verification SDK, permissions, location, camera, Bluetooth, Core Bluetooth, NFC, wearable pairing, Apple Watch integration or production notifications are needed. Pulse is a future hardware idea, not part of this app chapter. Do not set verification, membership, entitlement, presence or visibility flags.

## Motion, accessibility and verification

The approved prototype uses user-triggered **220 ms ease-out dissolves** between choice states. Reproduce a restrained native 2D transition with layout stable during the update. All four supplied objects already have a closed clasp. The proposed future 0.65–0.85 second closure is **not implemented or achievable as a real closure with these assets**: no open pose, separated hardware or 3D rig is supplied. Do not animate a bitmap scale and call it a physical clasp simulation; do not add a motion library, loop, spin or frame-rate claim.

With Reduce Motion use an instant state change or a brief dissolve without object movement. Keep controls responsive during transition, permit rapid changes and show the final requested choice consistently. Selection and navigation must not wait for an animation callback.

Use native accessible single-choice controls with intent labels, explanations and selected traits. Each tile has a textual name, icon, border and selected check: color or weave alone must never communicate state. Keep the current selection discoverable to VoiceOver without speaking the same decorative artwork twice. Hide the band illustrations from accessibility. Maintain logical reading order and focus on the chosen tile; announce the changed selection concisely rather than re-reading the full screen. Avoid unsolicited haptics as a substitute for visible/accessibility feedback.

The reference tiles are 182 × 78, primary 376 × 60, header Back and bottom Back at least 44 points high. Preserve minimum 44-point targets. Use a scrollable content layout and safe-area controls where needed. At larger Dynamic Type, allow a one-column choice layout and wrapping copy instead of clipping or shrinking text to fit the fixed artwork arrangement. Decorative hero size may yield to readable controls. Every choice, helper, privacy line and action must remain reachable in landscape and larger text sizes.

Run meaningful available checks for an initially empty draft, all four selections, every change from one selected intent to another, selected-tile no-op, matching summary/artwork/CTA state, draft preservation across Guest List preview/editor and back, end-preview feedback, duplicate taps and rapid selection updates. Confirm these actions do not mutate verification, visibility or consent flags. Use fictional data only in previews/tests. Inspect available native build tools and use an already accessible simulator/device when possible, without dispatching cloud builds. Report macOS compilation, iOS runtime, VoiceOver, Dynamic Type, Reduce Motion and device motion checks as **not run** when unavailable. Source inspection and screenshots are not runtime verification.

Return branch/worktree/base commit, dependency evidence, changed files, actual selection/navigation behavior, asset/font mapping, executed checks/results, unavailable checks, reproducible preview steps and precise deviations. Stop after this bounded Wristband prototype.
