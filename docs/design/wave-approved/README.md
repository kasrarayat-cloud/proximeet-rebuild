# Proximeet — approved Wave handoff

The founder approved Chapter 9 with “approve” on 24 September 2026 at 22:31:36 PDT / 25 September 2026 UTC. This is a bounded local invitation demo. No real Wave, push notification, production consent entitlement, private chat or retained connection is created.

## Use with Claude

1. Implement and review all eight approved chapters through Room first, including its central block state and explicit demo gates.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the folder's absolute path.
4. Return Claude's full report for review. The prompt covers Wave and minimal Room integration only.

No app code, repository, build, signing, deployment or TestFlight was changed to prepare this package. No automatic app coding agent was invoked.

## Approved design

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=76-387

Page: 74:567. Review: 76:387. Approval annotation outside app frames: 84:498. The unchanged `reference/wave-review.png` is the historical approval board; the dated approval above supersedes its outer review status, which is not app copy.

| State | Node |
| --- | --- |
| Demo menu | 74:568 |
| Outgoing confirmation / pending / withdrawn | 74:569 / 74:570 / 74:571 |
| Incoming review / declined / accepted | 74:572 / 74:573 / 74:574 |
| Unavailable / blocked / allowance unavailable | 74:575 / 74:576 / 74:577 |
| Session ended / incoming sender withdrawn | 74:578 / 74:579 |
| Seven safety, report, chat-information and demo-condition overlays | 74:580 through 74:586 |

`LAYOUT_SPEC.json` includes twelve screens, seven overlays, four report-reason variants, one integration reference and both ring masters: 513 measured native nodes. Styles, ellipse materials, transforms, text, vector paths, component-instance subtrees and reactions are fully recorded. Screens use 440 × 956 reference bounds; root x/y are canvas positions. Adapt native layout to actual safe areas, long draft names, differing approaches and Dynamic Type.

## Identity and Room integration

The reference viewer is fictional Alex. Use the actual current viewer ID/display name and preserved draft. Social can target eligible unblocked Maya; Business can target eligible unblocked Jules. The eligible Room profile action becomes Preview Wave demo, opening the explicit menu without resetting Room phase, run ID or blocks. Other-intent actors retain their no-Wave boundary. Waiting, ended, blocked or otherwise ineligible Room state cannot enter an active invitation.

The outgoing fixture is viewer → counterpart; only the counterpart could accept it, and this sender-facing demo does not simulate that response. The incoming fixture is counterpart → viewer and may be accepted by the viewer only while valid/pending. They have different immutable IDs. New explicit starts create fresh invitation identities; they do not switch accounts or turn an outgoing ID into an incoming one.

The same-page Places shortcut is only a Figma review convenience. Native Leave ends the underlying Room and Wave state, then Return to Places opens real Places Now. Re-entry follows the existing eligible Places and explicit Room/populated/profile sequence. Starting another Wave fixture never revives an ended Room or restores a blocked participant.

`fixtures/WAVE_DEMO_CONTRACT.json` records guards, transitions, actual-intent counterpart mapping, report reasons and integrated-state rules. These local guards do not satisfy or implement production server authorization.

## Actions and terminal behavior

Send demo Wave commits one compose → pending transition; there is no delivery. Pending cannot reopen stale compose or resend/refund through Back. Outgoing never has Accept. Withdrawal closes its immutable ID.

Accept is valid only for the current pending invitation's actual recipient, distinct from its sender, with the same eligible current venue/intent, active populated Room and no block/invalidation. Decline, sender withdrawal, expiry, block and Room end prevent a stale Accept. The joined result is local demonstration agreement only; About private chat opens information, without creating chat or Keep.

There is no numeric allowance, refill period, cooldown or refund policy. Available/no-allowance are explicitly chosen demo conditions. No timer or real clock opens a session or restores an allowance.

Closed states do not restore old invitations. Generic unavailability avoids disclosing another person's block/leave/suspension. Contextual blocking updates the shared Room blocked set, preserving existing blocks and removing that actor's card/profile/note and pending/accepted Wave. Reports are local unsent choices with no Submit/receipt/transmission. Closing an overlay restores its caller only if current central state still permits it.

Leave and disappear is immediate and terminal from every reachable context. Clear active/modal routes before animation; stale Back, gestures, callbacks and menu controls cannot restore an ended run. All data stays in memory for this bounded prototype. No network, permissions, production flags, notifications, backend work, logs/analytics/disk writes or hardware are required.

## Native ring geometry and motion

The rings are native ellipses with a measured six-stop steel gradient, 12-point rim stroke, 1-point inner highlight and shadow. Each 112 × 118 ring group contains a 100 × 106 rim at x6/y6 and an 88 × 94 highlight at x12/y12. The 376 × 128 container has separate origins x54/y6 and x210/y6, rotation 0°. Joined origins are x110/y6 and x154/y6 with Figma rotations −7°/+7°. Preserve supplied transform matrices and anchor conventions.

The actual matching hierarchy in incoming review and accepted is `Wave invitation/Halo rings/Halo ring 1` and `Wave invitation/Halo rings/Halo ring 2`; each retains children Brushed metal rim and Inner steel highlight. `validation/motion-match-readback.json` records those actual instance IDs/paths, avoiding confusion with differently named master components.

Only valid recipient acceptance triggers the 800 ms ease-out two-dimensional join. Ordinary transitions use 240 ms dissolves. Reduce Motion uses an immediate joined emblem or restrained crossfade. State, block and Leave updates never wait for decoration. No physical 3D interlock, rig, automatic reply, playback verification or native frame-rate result is supplied.

## Assets and fonts

`assets/common-ground.png` is the unchanged approved 1254 × 1254 RGBA scene. Apply crop `[46,83,1211,1218]`, preserve alpha/FIT framing, and compare `reference/common-ground-delivery.png`, 288 × 281 with alpha. `source/COMMON_GROUND_ART_PROVENANCE.json` records the original generation/source. No new raster asset was generated for Wave. All invitation shapes, rings, initials, labels and controls remain native; do not use screenshot UI.

`fonts/` contains licensed Manrope static weights, original variable font, source metadata and OFL license. Preserve the license.

## Audit limits

Run `python3 validation/audit_design_graph.py` to repeat the read-only Figma graph checks. It checks the isolated Social/Alex/Maya fixture: 74 routes, one recipient acceptance edge, outgoing self-accept exclusion, pending/terminal paths, local report variants and ring states. It does not prove native Business adaptation, atomic transitions, production security or the stricter central Room continuity required by this handoff. In particular, isolated fixture restarts in Figma are not permission to unblock an integrated Room participant.

Motion evidence confirms names, authored settings and resting poses—not playback or device performance. See `CLAUDE_PROMPT.md` for native verification and honest unavailable-check reporting. `SHA256SUMS.txt` covers every other file in this ZIP and excludes itself.
