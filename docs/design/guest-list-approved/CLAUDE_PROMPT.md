# Proximeet — approved Guest List implementation prompt

Paste into Claude Code with `PROXIMEET_GUEST_LIST_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 4: Guest List only**, as a native SwiftUI prototype matching the approved introduction editor and personal card. The founder approved this design on 25 September 2026: **“i approve”**. Provide working native text entry and interest selection; the Figma fixture is a visual reference. Report your actual model/effort only if visible; do not invent it.

## Confirm dependencies and repository

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **A Place Opens Welcome**, **Birthday** and explicit user-controlled **Pass** demo are actually implemented in the intended native SwiftUI branch. Verify Birthday has real date entry and its eligibility gate, and Pass has no timer-based verification success. Design files, legacy onboarding and static sample pickers do not establish these dependencies. If any chapter is missing, report it and ask the founder to run its approved handoff first. Do not silently implement multiple chapters, switch frameworks or regenerate approved designs.

Preserve existing work in an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes; report any dependency on uncommitted work before proceeding. If repository identity or native architecture differs, report the blocker. Limit edits to Guest List and minimal integration with the approved Pass route. No destructive reset/deletion, push, merge, CI/Codemagic dispatch, Apple setup, signing, deployment, TestFlight or paid service invocation.

## Use the supplied approved design

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=36-260

| Reference | Node |
| --- | --- |
| Page / review board | `35:111` / `36:260` |
| Empty editor / fictional example / personal card | `36:134` / `36:169` / `36:204` |
| Shared demo header / personal card | `36:111` / `36:126` |

Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `reference/guest-list-review.png`, `ART_PROMPT.json` and `SHA256SUMS.txt`. Match native copy, typography, colors, spacing, strokes, radii and artwork overlays in the measured specification. The review board's outer “awaiting approval” caption is historical and is superseded by this approval record; it is not app copy.

Use `assets/guest-list-card.png`, the original 1457 × 1079 RGBA artwork, cropped exactly to `[66, 93, 1436, 988]`. Match `reference/guest-delivery.jpg`: its 540 × 353 optimized image is composited on RGB(5,6,6). Figma's shared card is 392 × 256.46, with FIT decoration across its bounds and preview origin x24/y371. Use the original alpha artwork for implementation and preserve the crop/aspect ratio, aligning all native overlays with it. Do not use a whole-screen screenshot as UI or regenerate the approved art. The paper, clip, holder and cyan tab are raster decoration, not a 3D rig.

Bundle the supplied licensed Manrope static fonts and preserve `fonts/OFL.txt`. All text, fields, chips, initials, buttons and feedback remain native UI. Use the specified 440 × 956 reference for visual comparison, adapting to actual safe areas, available width, keyboard and Dynamic Type rather than hardcoding a fixed screen.

## Implement a real, bounded introduction form

Initial entry is an **empty draft**. Never prefill Alex, the founder's name, personal data or a previous user's data. The Alex example, opener and three selected interests belong only to explicitly fictional previews/tests.

Retain the editor headline **“A little about you.”**, support **“Give your hello a starting point.”**, field labels/placeholders and **“Preview my card”** action. In every state retain **“DEMO PROFILE”** and **“This preview doesn’t make you visible to anyone.”**

- **Name:** required display name, not a legal-name check. Only reject a value that is empty after trimming whitespace/newlines. Preserve internal spaces, punctuation, accents, non-Latin scripts and user spelling. Do not impose first/last-name structure, ASCII-only validation, an invented maximum or capitalization that rewrites input. Normalize leading/trailing whitespace for the displayed card without continually rewriting the active text field. Long names must wrap/reflow, remain available to accessibility and never spill beyond the card; the reference art may grow or yield to an accessible layout when needed.
- **Introduction:** optional, maximum **120 user-perceived characters**. Count extended grapheme clusters with Swift `String.count`, not UTF-8 bytes or UTF-16 code units. Keep the visible current-count/120 counter. Permit composition and paste without slicing text or dropping an emoji/combining sequence; when over limit, retain the draft, explain the limit inline with accessible feedback and prevent preview until corrected. Do not silently truncate or mutate text while the user types. Whitespace-only content may render as an omitted optional opener.
- **Interests:** optional, up to three. The complete catalog for this bounded prototype is exactly **Coffee**, **Live music**, **Outdoors**, in that order. Each chip independently toggles and exposes selected state through accessibility and an additional native semantic/state cue, not color alone. Do not invent a production catalog, fetch interests or turn these choices into inferred intent. All zero-to-three selections are valid.

Enable Preview my card only with a nonblank name and valid introduction length. Do not require an opener or interest. Disabled actions must have a discoverable reason through the field's validation/help state; do not rely on tapping a disabled button to explain a problem. Keep name validation gentle before interaction and avoid announcing errors on every keystroke. The counter may update silently; announce crossing the limit once and the restored valid state when appropriate.

Preview shows **“Your first hello.”**, **“A small card. A real starting point.”** and native initials/name/opener/interests on the paper, followed by **“Your introduction, ready to edit.”** Use the first user-perceived character of the first nonblank name token as the initials avatar, preserving its script; do not assume Latin letters or split a grapheme. This placeholder is not identity or age evidence. Long content must wrap and reflow without clipping, overflowing artwork or tiny text. At larger text sizes allow the native card layout to expand beyond the decorative composition; readability wins over a fixed paper height.

When optional content is absent, use intentional spacing and omit its unused line/divider. Never show an empty separator, dangling slash, filler biography or synthetic interest. Build separators only between selected interest labels. Keep the user's raw edit draft intact in memory when entering or leaving preview.

## Navigation and prototype boundary

Replace Pass Complete's temporary **“End of this preview.”** action with entry into the now-approved Guest List editor. This is the only earlier-chapter behavior changed. Keep the Pass demo states, explicit no-verification copy and Birthday gate intact. Do not infer actual verification from the route.

Editor Back (header or bottom action) returns to the actual Pass Complete screen; revisiting Guest List preserves the current in-memory draft for that onboarding session. Preview Back and **“Edit introduction”** return to the editor with all raw text and selections preserved. Treat this as navigation, not a new Pass entry that accidentally restarts its demo. Figma's duplicate Pass frame is a same-page prototype reference only, not an additional app screen.

The card's **“Continue preview”** shows a minimal dismissible native message **“End of this preview.”** with OK and stays on the card. This is a documented functional endpoint where Figma is intentionally unwired. Do not implement Wristband, Signal, Places, check-in, profiles of others, rooms or chat. Wristband remains a separate approval and implementation handoff.

Keep the introduction in memory only for the active prototype session. Do not write a profile to a server, disk, analytics, logs, backups or account storage. No networking, real sign-in, verification SDK, permissions, location, camera, document upload, visibility change, matching or chat is required. Do not set `isVerified`, membership, entitlement, presence or discoverability flags. Reusing a draft does not authorize persistence after app relaunch. Do not promise production privacy or retention behavior beyond the actual prototype scope.

## Motion, accessibility and verification

The approved Figma navigation is a user-triggered **220 ms ease-out dissolve**. The proposed **450 ms card insert/settle** is optional implementation direction: a bounded native 2D translation/settle of the whole paper plus native content as one unit. Do not claim an existing 3D simulation or measured frame rate, introduce a motion library, spin the card, or animate continuously while typing. With Reduce Motion keep the card stationary and use an instant update or brief dissolve. Actions never wait on animation completion; prevent repeated taps from duplicating routes.

Use native keyboard entry, persistent field labels, focus progression Name → Introduction, hardware Tab/Shift-Tab and appropriate Return/Done dismissal without swallowing intentional multiline input. Use a scrollable editor with safe-area inset controls and keyboard avoidance. Scroll focused fields into view. Back, chips and secondary actions require at least 44-point targets; the reference primary is 60 points high. Keep every field, message and action reachable at larger Dynamic Type. Support VoiceOver labels, selected states, logical reading order and predictable focus after editor/preview navigation. Hide decorative housing from accessibility and avoid reading initials and the same name redundantly.

Run meaningful available checks for blank and international names, 120/121-grapheme introduction boundaries including composed characters and emoji, unchanged pasted/composing drafts, zero-to-three interests, optional-empty rendering, draft preservation across editor/preview/Back, Pass integration, duplicate-tap behavior and no verification/visibility mutation. Use fixtures only in previews/tests. Check available native build tools; use an already accessible simulator/device when possible, without dispatching cloud builds. Report macOS compilation, iOS runtime, keyboard, VoiceOver, Dynamic Type and motion checks as **not run** when unavailable. Source inspection and screenshots are not runtime verification.

Return branch/worktree/base commit, dependency evidence, changed files, actual navigation/form behavior, asset/font mapping, executed checks/results, unavailable checks, reproducible preview steps and precise deviations. Stop after this bounded Guest List prototype.
