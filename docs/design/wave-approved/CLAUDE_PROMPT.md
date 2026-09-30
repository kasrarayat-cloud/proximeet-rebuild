# Proximeet — approved Wave implementation prompt

Paste into Claude Code with `PROXIMEET_WAVE_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 9: Wave only**, as a bounded native SwiftUI demo matching the approved invitation, pending, recipient acceptance, closed states and safety interactions. The founder approved it with **“approve”** on 24 September 2026 at 22:31:36 PDT / 25 September 2026 UTC. This covers twelve screens, seven overlays, four report-reason variants and the native ring transition. Nothing is delivered to another person, and Chat/Keep remains information only. Report your actual model/effort only if visible; do not invent it.

## Verify the first eight chapters

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **Welcome, Birthday, Pass, Guest List, Wristband, Signal, Places and Room** genuinely exist in the intended SwiftUI branch. Verify real inputs and preserved draft; no timer-based verification; actual typed intent/approach; Places' fixed snapshot and intent eligibility; and Room's explicit entry/populated gates, central blocked-actor state, unsent reports and terminal Leave. Design files, legacy onboarding and static fixtures are not implementation evidence. If any dependency is missing, report it and ask the founder to run its approved handoff first. Do not silently implement multiple chapters, switch frameworks or regenerate approved designs.

Use an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes and report reliance on uncommitted work. Report an unexpected repository/native architecture as a blocker. Limit edits to Wave and minimal Room integration. No deletion/reset, push, merge, CI/Codemagic dispatch, Apple setup, signing, upload, deployment, TestFlight, paid service or cloud build. Use only already available local build/simulator tools.

## Read the measured design

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=76-387

Page `74:567`; review `76:387`; approval annotation `84:498`. Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `ASSET_MAP.json`, `fixtures/WAVE_DEMO_CONTRACT.json`, `reference/wave-review.png` and `SHA256SUMS.txt`. The specification records all native screen/overlay trees, report variants, ring masters, gradients, ellipse geometry, shadows, transforms, labels and reactions. `validation/` includes the Figma graph audit and actual matching-layer motion evidence. These validate the reviewed design fixture, not an app, server or security boundary.

Match the approved 440 × 956 reference while adapting for safe areas, orientation, real draft names and Dynamic Type. Root x/y are Figma canvas positions. The unchanged historical review's outer awaiting-approval caption is superseded by the dated approval above and is not app copy.

## Integrate with the actual Room state

The existing same-intent Room profile information action becomes **“Preview Wave demo”**, opening the approved Wave demo menu with that eligible sample actor as the counterpart. Preserve the central Room run ID, populated phase, block set, actual user intent/approach and participant identities. Do not instantiate a second unfiltered Room or reset its state to reach the menu.

Common Ground still permits Social/Business in the fixed fictional Thursday 8 PM snapshot. Social may use unblocked Maya; Business may use unblocked Jules. The other-intent profile keeps its approved Back-to-people boundary, with no Wave action. Missing/incompatible draft values, a waiting/ended Room, a blocked actor or a stale profile route cannot enter an active Wave example. Recheck these conditions at the menu and at each action, not only when rendering a button. No device clock or real membership verification runs.

Alex is only the reviewed current-viewer name. Use the current demo viewer's stable ID and the actual Guest List display name without overwriting their draft. The viewer remains the same actor throughout; never switch to the counterpart's account. Use actual counterpart name/intent/approach in invitation and safety copy. Adapt Maya references to Jules for an eligible Business draft using the same layout. Header copy carries the viewer's actual intent/approach; invitation preference copy identifies the counterpart's values without falsely claiming that both approaches match. Different approaches are allowed; same intent is required. Use “you” where needed for readable role copy, without changing identity or authority.

The standalone Figma Places return fixture shortcuts directly to Wave for design review. **Do not implement that shortcut.** After leaving, return to real Places Now; reaching Wave again requires the existing eligible Places → explicit Room entry → populated example → valid profile path. Preserve the functioning earlier screens and all their guards.

## Two independent Wave identities, one viewer

Use typed local invitation state with immutable ID, Room run ID, sender ID, recipient ID, venue ID, direction and status. Source fixture IDs `wave-demo-outgoing-01` and `wave-demo-incoming-01` demonstrate independence; native explicit starts must create fresh distinct local IDs, never reuse or mutate a closed Wave into another direction.

| Explicit example | Sender | Recipient | Viewer can accept? |
| --- | --- | --- | --- |
| Start outgoing example | Current viewer | Eligible counterpart | No |
| Start incoming example | Eligible counterpart | Current viewer | Only while valid and pending |

Keep the menu's **“Choose a new, independent demo.\nNo invitation is sent to anyone.”** boundary and clear demo controls. Starting incoming is a separate fictional invitation, not a role switch or a way for the outgoing sender to accept their own Wave. Merely returning to the menu starts nothing.

**A new Wave example resets only its local invitation fixture.** It cannot reset Room phase, unblock an actor, replenish a real allowance, restore prior consent or revive an ended run. If central eligibility is absent, show the existing generic unavailable/blocked state or disable example-start controls with a concise reason in the existing helper area. Keep a blocked counterpart's identity hidden. A new explicit Room run may reset fictional blocks only under the prior approved Room contract; the Wave menu cannot do so.

## Confirmation, pending and allowance

Outgoing confirmation presents the actual counterpart, shared venue/intent and accurate approach preference. **“Send demo Wave”** makes one local compose → pending transition after current eligibility and demo-allowance availability are checked. No network request, push, delivery/read receipt or real invitation is created. Keep the explicit **“Nothing is sent.”** boundary.

Use one current state, not independently writable `isSent`/`isAccepted` flags. Repeated taps are idempotent. Replace/remove the stale confirmation route after sending so Back, gestures or delayed callbacks cannot reopen compose, resend the same Wave or manufacture a refund. There is no sender-facing Accept control anywhere in outgoing pending, safety or demo conditions. **“Withdraw Wave”** closes that pending outgoing ID; it cannot later reach accepted or private-chat information.

The source requires a limited allowance but defines **no numeric quota, refill period or refund policy**. Model only explicitly labeled available/unavailable **demo conditions**. **“Show no-allowance example”** shows the approved unavailable screen and no Send action. Do not invent a daily count, decrement ledger, cooldown, refund on withdrawal, timer or production allowance service. Explicitly choosing a separate example is fixture selection, not a real allowance refill.

## Recipient-only acceptance

The incoming example starts as a distinct pending invitation addressed to the current viewer. **“Accept Wave”** is the only transition into accepted. At action time, atomically validate that the same current Wave ID/run is pending; current viewer ID equals recipient ID and differs from sender ID; both fixture participants still belong to the same eligible venue and share their current intent; the central Room remains populated/active; and no relevant block or invalidation exists. Do not trust an old screen or enable acceptance merely because direction text says incoming. Reject malformed self-addressed fixtures.

**“Decline Wave”** closes the pending incoming ID without a reason or notification to its fictional sender. **“Show sender withdrawn”** in the labeled incoming demo conditions closes that ID before any later Accept can succeed. Withdrawal, decline, expiry/unavailability, block or Room end must win over stale Accept callbacks. Repeated Accept cannot create another agreement or replay a second transition.

Only after a valid recipient action commits the local accepted state do the rings join and **“You both said yes.”** appear. This is fictional mutual agreement, not production entitlement. **“About private chat”** remains the supplied information overlay: Chat and Keep are the next chapter. Do not create a composer, conversation ID/production access flag, message, retained connection or Keep action. Closing information restores accepted only if the same invitation and Room still remain valid; otherwise show their current terminal state.

## Terminal conditions, blocking and Leave

Implement withdrawn, declined, sender-withdrawn, generic unavailable, blocked, no-allowance and session-ended states with approved copy and no counterparty identity on closed/blocked screens. Generic unavailability must not disclose whether another person blocked, left, was suspended or changed their mind. The viewer's own explicit withdrawal/block and the specifically labeled sender-withdrawn fixture may use their corresponding clear copy.

Demo cases are visibly labeled static review controls. **“Show expired example”** invalidates the current invitation, including an accepted example; no live timer runs. If the current Room/venue becomes ineligible, invalidate access in central state as well. Returning through menus or new-example controls cannot renew that Room. Retain immutable IDs/terminal status internally even when the generic screen displays no invitation details; never mutate the old closed object back to pending or accepted.

**“Block [Counterpart] in demo”** updates the **same central Room blocked-actor set**, preserving every existing block. Invalidate that actor's pending/accepted Wave and any open actor/report/chat-info route immediately. Remove their Room card, profile and public note as required by the Room contract. Blocking Jules therefore also removes his sample note; blocking Maya does not remove Jules's note. Do not only hide the current Wave screen. No Back, tab, report Close, new Wave example or stale callback may restore the blocked participant or joined result.

**“Leave and disappear”** ends the underlying Room run and all its Wave state immediately from every reachable screen/overlay, without a confirmation or reason. Clear active and modal navigation before decorative motion. Ended has no active Back route; system gestures, sheet dismissal and late callbacks cannot revive it. **“Return to Places”** goes to actual Places Now with the onboarding draft intact, not the isolated Figma shortcut. An explicit new Room run is required before another active Wave example.

Production membership, session expiry, venue closure, blocks and consent transitions must ultimately be server-authorized. This bounded demo does not implement them, satisfy those guards or repair the historical rules package. Keep demo types/state separate from production verification, presence, entitlement and conversation authorization.

## Safety and unsent reports

Global safety, contextual counterpart safety and immediate Leave remain available as designed, including after acceptance. Use actual actor context; Business reports target Jules, not hardcoded Maya. Nested overlay Close returns through the real caller while reading current central Room/Wave state. Never restore a captured pending/accepted screen that has since become invalid.

Report reasons are exactly **Unwanted attention**, **Harassment or harmful content**, and **Something else**, with no initial choice. Use local optional single-choice state; selecting the active reason is a no-op. Keep **“Example only — nothing is submitted.”** Closing discards that unsent presentation without changing invitation status or block state. Selection does not leak to another actor or new presentation. No Submit, report receipt, evidence upload, queue, staff notification, logging or transmission exists.

## Native ring motion, assets and accessibility

The rings are native ellipse strokes, not raster art. Match the measured six-stop steel gradient, 12-point rim stroke, 1-point inner highlight, shadows and transform matrices. Each ring group is 112 × 118; rim ellipse is 100 × 106 at local x6/y6; inner highlight is 88 × 94 at x12/y12. In the 376 × 128 ring container, separate group origins are x54/y6 and x210/y6 at rotation 0°. Joined origins are x110/y6 and x154/y6 with Figma rotations −7° and +7°. Preserve the supplied relative matrices/anchors rather than assuming native angle conventions.

Acceptance uses **800 ms ease-out two-dimensional translation/rotation**. The actual matching paths in both states are `Wave invitation/Halo rings/Halo ring 1` and `Wave invitation/Halo rings/Halo ring 2`, each containing `Brushed metal rim` and `Inner steel highlight`. Keep stable native identities so positions interpolate rather than replacing the whole group. Rings remain separate while unaccepted, and appear joined only for a still-valid accepted result. Do not auto-join on screen appearance or simulate a reply. This is a graphic metaphor, not a physical 3D interlock.

Other authored navigation uses **240 ms ease-out dissolves**. Reduce Motion uses an immediate joined emblem or restrained crossfade with identical state text. Commit selection/acceptance/closure before decoration; allow interruption and make block/Leave/invalidation win over animation completion. No loop, countdown pressure, confetti, motion library or native frame-rate claim.

Reuse `assets/common-ground.png`, the approved 1254 × 1254 RGBA original with crop `[46, 83, 1211, 1218]`, preserving alpha/FIT framing. Compare `reference/common-ground-delivery.png`, 288 × 281 with alpha. Native invitation, text, controls, initial avatars and ring materials remain editable code; no screenshot UI or regenerated scene. Bundle licensed Manrope static fonts and preserve `fonts/OFL.txt` and provenance.

Use native labeled buttons, accessible selected/disabled reasons and predictable modal focus. Keep sender/recipient/direction clear to VoiceOver; hide decorative rings/venue art instead of repeating the same meaning. Blocked/ended content must be absent from accessibility as well as visually hidden. Targets remain at least 44 points. Let long actual names, differing approaches and larger Dynamic Type wrap/grow with scrolling and safe-area controls; never clip roles, shrink critical copy or cover Leave.

## Verification and report

Test both permitted actual intents, both approach values and eligible counterpart selection without defaulting to Social/Maya/Alex. Cover distinct IDs and immutable roles, sender self-accept rejection, malformed self-addressed input, only pending-recipient acceptance, duplicate Send/Accept, pending Back-to-compose prevention, withdrawal/decline/expired/sender-withdrawn stale Accept, and invalidation during/after ring motion. Test central Room blocks in both directions, Jules's note removal, new-example attempts after block/end, actual Places return and required Room re-entry. Verify reports never submit, overlays preserve current state, and no numeric allowance/refund policy appears.

Run the supplied read-only design graph audit, then meaningful native state/navigation checks. The Figma audit permits isolated fixture restarts; it does **not** prove the stricter integrated Room block/run guards required above. Its motion evidence proves matching layer names, settings and resting poses only—not playback, performance or security.

Run an available local native build and already accessible simulator/device without cloud dispatch. Report macOS compilation, iOS runtime, VoiceOver, Dynamic Type, Reduce Motion, gesture/lifecycle interruption and motion/device checks as **not run** when unavailable. No network, real accounts, permissions, camera/location, analytics/log/disk writes, hardware, notifications, backend changes or actual chat is required.

Return branch/worktree/base commit, dependency evidence, changed files, actual identity/transition/Room-integration behavior, asset/font mapping, executed checks/results, unavailable checks, reproducible preview steps and precise deviations. Stop after this bounded Wave prototype.
