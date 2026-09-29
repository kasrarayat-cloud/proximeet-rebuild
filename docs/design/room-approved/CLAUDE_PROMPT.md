# Proximeet — approved Room implementation prompt

Paste into Claude Code with `PROXIMEET_ROOM_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 8: Room only**, as a bounded native SwiftUI demo matching the approved entry, privacy waiting, introduction cards, read-only notes and local safety interactions. The founder approved it with **“approve go next”** on 24 September 2026 at 21:46:12 PDT / 25 September 2026 UTC. Fifteen full screens, eight overlays and four local report-reason variants define the reference. This is not a live room, production authorization or real moderation service. Report your actual model/effort only if visible; do not invent it.

## Verify the first seven chapters

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **Welcome, Birthday, Pass, Guest List, Wristband, Signal and Places** are genuinely implemented in the intended SwiftUI branch. Verify real Birthday input/gate, explicit Pass demo controls without timer-based verification, editable Guest List, initially empty typed intent/approach choices, preserved drafts, and Places' fixed fictional Thursday 8 PM catalog with actual-intent eligibility. Static screenshots, legacy onboarding or design files are not implementation evidence. If a dependency is missing, report it and ask the founder to run its approved handoff first. Do not silently implement several chapters or change frameworks.

Preserve work in an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes and report reliance on uncommitted work. Report an unexpected repository/native architecture as a blocker. Limit edits to Room and minimal approved Places entry/return integration. No destructive deletion/reset, push, merge, CI/Codemagic dispatch, Apple setup, signing, upload, deployment, TestFlight, paid service or automatic cloud build. Use only already available local build/simulator tools.

## Approved design and assets

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=68-465

Page `66:111`; review `68:465`; approval annotation `74:566`. Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `ASSET_MAP.json`, `fixtures/ROOM_DEMO_CONTRACT.json`, `reference/room-review.png` and `SHA256SUMS.txt`. The measured specification includes all screens/overlays, report variants and two integration references, with resolved component styles, native text, vector paths, geometry and reactions. `validation/` contains the extracted Figma graph and a bounded design-graph audit; it does not validate an app or backend.

The unchanged historical review may say awaiting approval. The dated founder approval supersedes that outer caption, which is not app copy. Match the approved 440 × 956 screens while adapting for actual safe areas, orientation and Dynamic Type. Root x/y are canvas positions. Reference overlays are separate native sheets/panels, not whole-screen screenshot textures.

Use the unchanged original `assets/common-ground.png`, 1254 × 1254 RGBA, cropped to **`[46, 83, 1211, 1218]`**. Preserve alpha and FIT framing; compare `reference/common-ground-delivery.png`, 288 × 281 indexed PNG with alpha. The large entry ticket becomes the compact venue header; this is raster scene decoration inside native ticket geometry. No 3D model, rig, portrait generation or real photograph is supplied. Keep all cards, fictional initials, names, symbols, text and controls native. Do not regenerate art or replace the UI with screenshots. Bundle the supplied Manrope static fonts and preserve `fonts/OFL.txt` and provenance.

## Explicit demo entry, never production membership

Carry the user's actual typed intent and approach from the existing draft. The Social / Chat first review is a fixture, not a default. Common Ground permits **Social or Business** in the existing fixed Thursday 8 PM snapshot. Dating/Activity or missing prior choices cannot enter this Room demo through a stale/deep route; retain the Places eligibility gate and route back to the appropriate existing choice/discovery screen. Do not switch a band, infer an approach or unlock a future session. No actual device clock or countdown runs.

The minimal integration change is to Common Ground's existing explanation-only check-in screen: its primary becomes **“Preview room demo”**, opening the new Room entry screen. Preserve its honest no-location/no-camera copy and Back-to-place behavior. Preserve actual Places category/detail navigation; do not copy the simplified same-page Figma reference's inert tabs or shortcut from a browse ticket directly to the explanation. The original production-like checks remain unimplemented.

The entry screen retains **“Come in.\nStay yourself.”**, **“Try the Room with fictional people.”**, actual **“[Intent] · [Approach]”**, and **“This demo does not verify a venue visit\nor make you visible.”** Its Back returns to the real Common Ground explanation. Only a deliberate **“Enter room demo”** starts a new local demo run, initially in **waiting**. Merely opening the entry screen must not start/reset a run or expose a participant.

Use a separate typed demo phase/session model, isolated from production authorization. Suggested phases are entry, waiting, populated and ended, with local actor/block/tab/overlay state. No demo value may set or satisfy production `isVerified`, verified-venue-session, check-in, membership, presence, entitlement or discoverability guards. Demo fixture state is not a server token or security credential.

## Privacy waiting and fictional content

Waiting shows the approved blank privacy envelope and explanation, with no participant names, initials, messages, counts, profiles or hidden accessibility announcements. Safety and immediate Leave remain reachable. Only the clearly labeled **“DEMO CONTROL” / “Show populated example”** deliberately chooses the populated fixture. No timer, animation completion, navigation shortcut or successful-verification story opens it. This control must exist only in the explicit demo flow; it is not a production privacy-threshold bypass.

The populated fixture shows stable, clearly fictional introduction cards:

| Actor ID | Name / initials | Intent | Approach |
| --- | --- | --- | --- |
| maya | Maya / ML | Social | Chat first |
| jules | Jules / JR | Business | Okay to say hello |

Preserve their exact introductions, interests and profile copy from the specification. Keep **“SAMPLE INTRODUCTIONS”** and demo wording. These are two illustrative cards, not the total crowd or a production minimum of two. The populated fixture assumes a sufficient crowd separately; never derive threshold satisfaction from the number of visible sample cards. Do not label the venue empty when filtering removes them.

People and Room notes are genuine local tabs sharing one demo state. Room notes retain the fictional host announcement, host icebreaker and Jules's read-only public sample message. Both allowed intents may read these notes. There is no composer, Send, reaction, reply, topic thread, live update or posting/moderation service. No real contacts, external links, payment requests or private conversation are included.

Cards open their visible actor's profile; profile Back returns to filtered People. Derive access from the current central state, not a captured unfiltered screen. Same-intent compatibility determines only the **information action** in this chapter: Social can view Maya's **“How Waves work”**; Business can view Jules's. For an incompatible actor, use the approved **“Back to people”** action and same-intent explanation instead. Keep the actual user's header and actor's own intent/approach accurate; do not hardcode Maya as always compatible or Jules as always incompatible. Reuse approved action/helper styling without a redesign.

The Wave overlay is information only: **“A Wave is\nan invitation.”**, **“Chat opens only after the other person accepts.”**, **“Sending Waves comes in the next preview.”** Closing returns to the same valid profile and block state. It cannot send, create pending state, accept, match, notify or open chat. An approach preference is not continuing consent or an obligation to meet. Wave implementation needs its own approved handoff.

## Local safety, block state and unsent reports

Keep the global safety control available in waiting and the active room; profiles and Jules's public note have actor-context safety controls. Use the native reference overlays. Global safety Close returns to its caller; actor safety Back returns to its calling profile or note/tab. Nested report Close returns to actor safety, then Back to that same caller. Preserve current tab, phase and block state throughout; do not reconstruct a default unblocked screen on dismissal.

Maintain one typed blocked-actor set for the **current demo run**. The reference maps Maya to bit 1 and Jules to bit 2 solely to describe four fixtures: neither blocked, Maya blocked, Jules blocked, both blocked. Native UI should derive cards, notes, profiles and actions from that shared set rather than independent Boolean copies in each view.

**“Block [Name] in demo”** immediately adds that actor, closes relevant overlay/profile routes and returns to filtered People, as the approved graph specifies. Never clear an existing block when adding another. Maya's block hides her card/profile but leaves Jules's note; Jules's block hides his card, profile and public note. Host announcement and icebreaker remain. Blocking both shows **“No sample introductions\nto show.”** and **“Your demo blocks are still applied.”**, not a claim that the venue is empty or below its crowd threshold.

Filter blocked actors from rendered UI, accessibility, profile navigation, actor menus and any information action. Stale routes/overlay callbacks must recheck the central state and never reopen a blocked actor. Tab changes, Back, report selection/Close, generic safety and scene redraws cannot restore an actor. There is no unblock control. Blocks remain applied through the run; only a new explicit **Enter room demo** after termination resets this fictional fixture. This deliberately bounded reset is not production account-level blocking or its retention policy.

**“Preview report”** opens an unsent local reason selector for the named actor. Reasons are exactly **Unwanted attention**, **Harassment or harmful content**, and **Something else**, with no initial selection. Use genuine optional single-choice state; selecting another replaces the first, and selecting the active reason is a no-op. Keep **“Choose a sample reason.\nExample only — nothing is submitted.”** There is no Send/Submit, receipt, timestamp, moderation queue or staff notification. Keep reason selection local to the current report presentation and do not leak it to another actor. Closing discards the unsent presentation without changing block state. Do not log, persist or transmit it.

## Leave is immediate and terminal

**“Leave and disappear”** stays reachable from waiting, both tabs, profiles, safety, report and Wave-info overlays. It ends the local demo immediately without a confirmation or reason. Invalidate the run, clear actor/profile and overlay navigation, hide sample content and show **“DEMO SESSION ENDED” / “You’ve left\nthe room.”** State changes occur before decorative animation and must win over late callbacks.

The ended screen has no active-room Back route. System gestures, navigation history, sheet dismissal, delayed completion handlers or stale deep links must not restore an ended run. **“Return to Places”** returns to actual Places Now browsing, with the onboarding draft intact. Places remains fully functional; do not replace it with the inert Figma return clone. Entering again must follow the eligible explanation → Room entry → deliberate Enter room demo → waiting sequence, then the separate populated-fixture control. No automatic resume or reset-on-appearance may bypass these gates.

Production expiry, closure, suspension and safety revocation would require server authorization/invalidation. Do not implement a fake live timer, client-renewable session or fabricated production checks here. The displayed demo-until-10-PM label belongs to the fixed fictional snapshot.

Keep demo state and the existing draft in memory only; app relaunch must not restore active membership. No network requests, real people, accounts, server writes, disk/log/analytics persistence, location/camera permissions, QR scanning, notifications, Bluetooth/NFC, hardware or real moderation. This chapter changes no production consent rules or backend implementation.

## Motion, accessibility and checks

Reproduce a bounded **500 ms ease-out two-dimensional entry-ticket-to-header transition** and **240 ms ease-out tab/navigation transitions**. Keep art and native labels registered. No 3D unfolding, rig, motion library, looping animation or measured frame-rate claim. Reduce Motion uses an immediate state or restrained crossfade. Model updates, blocks and Leave never wait for motion; interrupted transitions must settle into the latest valid state.

Use native labeled buttons/tabs/radio choices, selected-state and disabled semantics, logical VoiceOver order and predictable modal focus. Hide decorative venue art and avoid duplicate avatar/name readings. Waiting/ended/blocked content must be absent from accessibility as well as visually hidden. Keep at least 44-point targets and all actions reachable with safe areas, scrolling and larger Dynamic Type. Reference body copy is at least 14 points; the existing DEMO badge is 11. Expand text and panels rather than clipping, shrinking readable copy or covering Leave.

Run meaningful available checks for both permitted user intents and both approach values; reject missing/incompatible entry; require both explicit demo gates; verify waiting exposes no actor information. Test all four block sets across People/notes/profiles, both block orders, actor-menu/report dismissal and stale routes. Verify report selection never submits, both actual-intent compatibility cases, filtered empty wording, and immediate Leave from every reachable context. Exercise system Back/gesture, delayed-callback and re-entry paths so an ended run never revives. Verify no production authorization/visibility flag or permission/network call is touched. The supplied Figma graph audit covers the reviewed Social fixture only; native Business behavior, runtime guards and device accessibility still need implementation tests.

Run an available local native build and already accessible simulator/device without dispatching cloud builds. Report macOS compilation, iOS runtime, VoiceOver, Dynamic Type, Reduce Motion, gesture/modal/lifecycle interruption and device-motion checks as **not run** when unavailable. Source inspection and screenshots are not runtime/security verification.

Return branch/worktree/base commit, prerequisite evidence, changed files, actual demo/entry/block/report/leave behavior, asset/font mapping, executed checks/results, unavailable checks, reproducible preview steps and precise deviations. Stop after this bounded Room prototype.
