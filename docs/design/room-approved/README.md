# Proximeet — approved Room handoff

The founder approved Chapter 8 with “approve go next” on 24 September 2026 at 21:46:12 PDT / 25 September 2026 UTC. This covers a deliberate fictional demo, privacy waiting, sample cards, read-only room notes and local safety controls. It does not provide production membership, verification, Wave sending, real reports or chat.

## Use with Claude

1. Implement and review the approved Welcome, Birthday, explicit Pass demo, Guest List, Wristband, Signal and Places chapters first.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the folder's absolute path.
4. Return Claude's full report for review. The prompt covers Room and minimal Places entry/return integration only.

No app code, repository, build, signing, deployment or TestFlight was changed to prepare this package. No automatic app coding agent was invoked.

## Approved references and measured layout

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=68-465

Page: 66:111. Review: 68:465. Approval annotation outside the app frames: 74:566. The specification includes fifteen full-screen states, eight overlays, four report-reason component variants and two integration references: 712 native nodes in total. It records exact component-instance styles, text, vector paths, transforms, fills, radii and reactions.

| Group | Reference nodes |
| --- | --- |
| Entry / waiting / ended | 66:112 / 66:113 / 66:114 |
| People / notes, neither blocked | 66:115 / 66:116 |
| People / notes, Maya blocked | 66:119 / 66:120 |
| People / notes, Jules blocked | 66:122 / 66:123 |
| People / notes, both blocked | 66:125 / 66:126 |
| Maya profiles, unblocked / Jules blocked | 66:117 / 66:124 |
| Jules profiles, unblocked / Maya blocked | 66:118 / 66:121 |
| Safety, actor safety, unsent report and Wave-info overlays | 66:127 through 66:134 |

Reference screens are 440 × 956 logical units; overlays have their own measured bounds. Node x/y are parent-relative, except roots positioned on the Figma canvas. Adapt native layout for safe areas, orientation and Dynamic Type.

`reference/room-review.png` is the unchanged historical approval board. Its outer awaiting-approval status is superseded by the dated approval above and is not app copy. The Social / Chat first example is not a native default.

## Entry and privacy boundaries

The approved Common Ground explanation's primary becomes Preview room demo, opening the new entry screen. Preserve actual Places navigation and its fixed fictional Thursday 8 PM eligibility; do not copy Figma's simplified return shortcuts or inert tabs. Common Ground permits Social and Business. Carry the real draft's intent/approach; missing or incompatible choices cannot bypass entry.

Only Enter room demo starts a new local run in waiting. Only the visibly labeled Show populated example demo control reveals the populated fixture. No elapsed timer, verification result or animation completion substitutes for either action. Keep demo state separate from every production membership/verification/presence guard.

Waiting contains no actor names, initials, messages, counts, profile routes or hidden accessibility announcements. The populated example has two illustrative cards, not a total crowd or a production threshold. No actual check-in, camera, location, server inventory or privacy-threshold evaluation runs.

## Shared state and safety contract

`fixtures/ROOM_DEMO_CONTRACT.json` gives the fictional actors, note copy, allowed intents, actual-intent information-action matrix, four block fixtures and route/state rules. Use central typed native state rather than separate copies of the fixture per screen.

Maya is Social / Chat first; Jules is Business / Okay to say hello. Stable cards open valid profiles. Same-intent actors may open How Waves work, which remains information only. Thus Business enables Jules's information action and makes Maya incompatible; never hardcode the reviewed Social action assignments. Approach remains separate from consent.

People and Room notes share one block set. Maya's block removes her card/profile; Jules's removes his card/profile/public note. Existing blocks cannot regress when switching tabs, closing a nested report/safety overlay, navigating Back or processing stale callbacks. Host notes remain. Both blocked means no sample introductions to show, not that the venue is empty or below its threshold. Blocking returns to filtered People, matching the approved graph.

Report previews contain three genuine local reasons and explicit nothing-submitted wording. There is no submit action, receipt, transmission or moderation queue. Close returns through its actual caller and preserves blocks. Reason selection is local to its presentation and does not leak between actors.

Leave and disappear is immediate from waiting, active screens and overlays. It ends the demo and clears routes before animation. Ended cannot return to active content through Back, gestures, sheet dismissal or delayed work. Return to Places opens real Places Now with the onboarding draft intact. A new run requires the full explicit entry sequence and resets fictional blocks only at Enter room demo.

No real networking, production flags, account writes, disk/log/analytics persistence, permission requests, scanning, live clock, notifications, hardware, public composition, matching, Wave sending or chat. Production session expiry and server authorization remain separate future work.

## Artwork and fonts

`assets/common-ground.png` is the unchanged approved 1254 × 1254 RGBA original. Apply crop `[46, 83, 1211, 1218]`, preserve alpha and FIT aspect ratio. `reference/common-ground-delivery.png` is the exact 288 × 281 indexed transparent Figma delivery. `ASSET_MAP.json` and `source/COMMON_GROUND_ART_PROVENANCE.json` record its source and mapping.

This miniature is raster decoration, not a 3D model or real venue image. Paper cards, initial avatars, names, text, ticket shapes and controls remain native. Do not regenerate art or use a screen image as UI. `fonts/` contains licensed Manrope static weights, original variable font, source metadata and OFL license.

## Motion, audit and runtime limits

Use bounded 500 ms two-dimensional entry-ticket-to-header motion and 240 ms tab/navigation transitions. Reduce Motion uses an immediate state or restrained crossfade. Blocks, Leave and state changes never wait for animation. No rig or native frame-rate result is supplied.

`validation/graph-readback.json` and `validation/state-ledger.json` capture the reviewed Figma graph. `validation/verification.json` is its existing audit record. Run `python3 validation/audit_design_graph.py` for a read-only repeat of the bounded graph checks. It checks block monotonicity, waiting privacy, terminal Leave, overlay callers and local unsent report variants for the **Social design fixture**. It does not exercise a native app, Business adaptation, production authorization or device accessibility.

See `CLAUDE_PROMPT.md` for required implementation checks and honest reporting of unavailable native runtime verification. `SHA256SUMS.txt` covers every other file in this ZIP and excludes itself.
