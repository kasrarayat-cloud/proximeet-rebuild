# Proximeet — approved Signal implementation prompt

Paste into Claude Code with `PROXIMEET_SIGNAL_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 6: Signal only**, as a native SwiftUI prototype matching the approved approach selector and bounded two-dimensional tag motion. The founder approved it with **“approve go next”** on 24 September 2026 at 20:03 PDT / 25 September 2026 UTC. Approval covers twelve visual states: four carried intents, each with no approach chosen, Chat first or Okay to say hello. The optional physical Pulse wearable remains separate. Report your actual model/effort only if visible; do not invent it.

## Confirm dependencies and repository

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, native architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **Welcome, Birthday, Pass, Guest List and Wristband** are genuinely implemented in the intended SwiftUI branch. Birthday needs real date entry and its eligibility gate; Pass needs explicit user-controlled demo steps without timer-based verification success; Guest List needs editable fields and draft preservation; Wristband needs an initially empty single-choice intent with all four choices and working Back navigation. Design files, legacy onboarding and static sample controls do not establish these dependencies. If a chapter is missing, report it and ask the founder to run that chapter's approved handoff first. Do not silently implement multiple chapters, replace frameworks or regenerate approved designs.

Preserve existing work in an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes and report any dependency on uncommitted work before proceeding. If repository identity or architecture differs, report the blocker. Limit changes to Signal and the minimal Wristband navigation/draft integration it needs. No deletion/reset, push, merge, CI/Codemagic dispatch, Apple setup, signing, build upload, deployment, TestFlight, hardware purchase or paid service invocation. Run an already available local native build only when supported; do not launch a cloud build.

## Read the approved package

Figma review: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=54-411

| Carried intent | No preference | Chat first | Okay to say hello |
| --- | --- | --- | --- |
| Social | `50:191` | `50:192` | `50:193` |
| Dating | `50:194` | `50:195` | `50:196` |
| Business | `50:197` | `50:198` | `50:199` |
| Activity | `50:200` | `50:201` | `50:202` |

Page `50:190`; review `54:411`; approval annotation `58:478`. Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `reference/signal-review.png`, `ART_PROMPT.json` and `SHA256SUMS.txt`. The measured specification contains all 492 native nodes, exact text styles, strokes/radii, vector paths/networks, transforms and prototype reactions. Match it at the 440 × 956 reference size, then adapt for safe areas, orientation and Dynamic Type. Root-frame x/y are Figma canvas positions, not app margins.

The historical board and review records may say awaiting approval. The dated approval above supersedes that outer caption, which is not app copy. The Figma return fixtures are not a working native draft model.

Retain **“A hello,\non your terms.”**, **“Let people know how to begin.”**, **“DEMO”**, **“You stay private until venue check-in.”**, **“Continue preview”** and **“Back”**. The privacy line describes the product boundary; this bounded prototype has no real visibility or venue service.

## Carry intent and choose approach

Use the actual existing typed Wristband intent. Signal does not choose a default Social band or infer intent from other profile data. An absent intent cannot enter Signal; retain/return to Wristband until one is deliberately chosen. The Social review screenshots are examples, not default application data.

Keep approach as **one optional typed value**, separate from intent: no preference, Chat first or Okay to say hello. Do not use independent Boolean flags, infer it from intent, or keep separate preferences per band. First entry in a fresh onboarding draft has no approach selected. Both choices remain equally prominent and available:

| Choice | Exact explanation |
| --- | --- |
| Chat first | Start with a Wave. Chat after you both agree. |
| Okay to say hello | Open to a brief hello. No pressure to continue. |

Initially show the carried band with the blank tag resting separately, both native radio indicators unselected and Continue preview disabled. Summary is **“[Intent] band · Choose your approach”**. Selecting a row immediately commits that single approach, displays its native icon on the tag, applies the selected row/radio treatment, changes summary to **“[Intent] band · [Preference]”**, and enables Continue preview. Selecting the other row replaces the choice. Tapping the active row is a no-op: it neither clears the choice nor replays motion. No selection advances automatically.

Derive labels, selected traits, tag icon, resting/attached pose and CTA state from that same draft value. Do not update the model only after animation. A visible helper/accessibility hint must communicate that an approach is required while Continue is disabled, without requiring a tap on the disabled button or announcing an initial error.

A preference is not continuing consent. Either person may change their mind. Choosing either row sends no Wave, accepts no Wave, opens no chat, creates no match and grants no permission to approach or message. The later Wave still requires deliberate initiation and the other person's acceptance before chat. Preserve same-intent restrictions and existing consent rules; this chapter does not repair or extend the rules engine.

## Artwork and exact tag placement

Reuse `assets/wristband-social.png`, `assets/wristband-dating.png`, `assets/wristband-business.png` or `assets/wristband-activity.png` according to the actual draft. These are unchanged approved 1254 × 1254 RGBA originals. Apply their common crop **`[22, 335, 1235, 920]`**, preserve alpha and fit without stretching. The 540 × 260 `reference/*-delivery.jpg` images show exact Figma framing on RGB(5,6,6).

Use `assets/signal-tag.png`, the separate original 1254 × 1254 RGBA blank tag, cropped to **`[41, 154, 1216, 1060]`**. Preserve its hollow loop and transparency; compare with `reference/tag-delivery.png`, 176 × 136 RGBA. Never bake an icon, label or selected marker into this image. The supplied native chat/hello vector shapes remain overlaid and editable in code, with 25 × 25 reference bounds at tag-local x31.5/y31.

The hero origin is x32/y326 with 376 × 216 bounds. The band stays at hero-local x0/y10, 376 × 181. The 88 × 68 tag begins at x279/y124 with Figma rotation −9° and finishes at x144/y129, rotation 0°. Use the recorded relative transform matrices and top-left origin as the geometry reference; do not blindly copy Figma's angle sign into a differently anchored native transform. The band remains stationary. Keep tag artwork and its native icon in one transformed group so the symbol stays aligned.

Do not regenerate or recolor the art, substitute generic icons, use emoji/font codepoints, or render whole-screen screenshots as UI. Native text, controls, radio indicators and icons are independent of raster decoration. Bundle supplied Manrope static fonts and preserve `fonts/OFL.txt` and provenance. No additional motion library is needed for this bounded native two-dimensional transition.

## Navigation and draft preservation

Replace Wristband's temporary end-of-preview action with entry into Signal carrying its selected intent. This is the only earlier chapter's destination that changes. Preserve Guest List content, all earlier demo boundaries and the current onboarding draft.

Both Signal Back actions return to the actual Wristband screen with its selected intent. Returning forward preserves the existing approach and attached tag pose; do not replay the first-choice movement merely because the view appears. **If the user goes back, changes the band, then returns, carry the new intent while retaining the same approach.** Changing Social to Dating, for example, changes the band and summary intent, while Chat first remains Chat first. Earlier Guest List edits must also preserve both intent and approach. Do not recreate the draft on each navigation or reset it to the Figma fixture's empty state.

Keep the full draft in memory for this prototype session only. No server, disk, analytics, logs, backups or account storage writes. Relaunch starts a fresh draft unless a later approved persistence contract changes that scope. Intent/preference does not set verification, membership, entitlement, check-in, location, presence or discoverability flags.

Until Places receives its own approved implementation handoff, Signal Continue preview presents a minimal dismissible native **“End of this preview.”** message with OK and stays on the selected Signal screen. The Figma CTA is intentionally unwired; this endpoint gives honest feedback. Repeated taps must not stack alerts or duplicate routes. Do not implement Places, check-in, other people's profiles, rooms, Wave, chat or Keep. No real sign-in, verification SDK, network requests, location/camera permissions, Bluetooth, NFC, pairing, Apple Watch integration or production notifications are needed. Pulse is not part of this chapter.

## Motion, accessibility and checks

For the deliberate transition from no approach to a selected approach, reproduce the **500 ms ease-out two-dimensional tag translation/straightening** between the supplied transforms. Figma authors this as Smart Animate. When switching between the two selected preferences, retain the attached pose and use the approved **220 ms ease-out dissolve**. No loops, auto-triggered selections or repeated attachment movement. With **Reduce Motion, show the final pose and state immediately**.

This is layered two-dimensional movement, not a physical clip, 3D arc, clasp articulation or real hardware connection. The art has no rig, depth model or separated mechanical parts. Do not claim frame rate, device smoothness or video verification from the Figma authoring settings.

Controls remain responsive throughout. Rapidly changing choices, continuing, navigating back or enabling Reduce Motion during a transition must leave the model and final visual state consistent. Cancel/reconcile decorative animation rather than disabling controls or relying on its completion callback to authorize selection.

Expose native single-choice labels, explanations and selected traits to VoiceOver; hide decorative band/tag images and avoid redundant readings of the same icon/summary. Maintain logical focus order and focus on the chosen row during state updates. Use accessible textual/selected-state cues as well as the radio and border; color alone is insufficient. Preserve at least 44-point targets. The reference choice rows are 376 × 84 and primary action 376 × 60. Let explanations wrap, rows grow and content scroll for larger Dynamic Type; keep Back and Continue reachable with actual safe areas. Decoration may yield space to readable controls.

Run meaningful available checks covering all four carried intents × three approach states, no default, both first choices, both direction changes, selected-tap no-op, matching summary/icon/CTA, return/re-entry, changing intent without losing approach, earlier Guest List edits, end-preview/duplicate-tap behavior, rapid changes and animation interruption. Confirm no Wave/chat/verification/visibility side effects. Use fictional fixtures only in previews/tests. Run available local native compilation and an already accessible simulator/device; do not dispatch a cloud build. Report macOS compilation, iOS runtime, VoiceOver, Dynamic Type, Reduce Motion, lifecycle/animation interruption and motion checks as **not run** when unavailable. Source inspection and static screenshots are not runtime verification.

Return branch/worktree/base commit, dependency evidence, changed files, actual state/navigation behavior, asset/font mapping, checks/results, unavailable checks, reproducible preview steps and precise deviations. Stop after this bounded Signal prototype.
