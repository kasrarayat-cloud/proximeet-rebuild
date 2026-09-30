# Proximeet — Wave chapter review

Status: Chapter 9 Wave was approved by the founder with “approve” on 24 September 2026 at 22:31:36 PDT / 25 September 2026 UTC. Chapters 1–8, through Room, are also approved. The approved Wave Claude handoff is prepared. No app code, build, notification delivery or real conversation authorization was implemented.

## Direction

A private invitation becomes the chapter's physical object: an ivory paper slip carrying the other person's name, shared venue and intent. Two restrained metal Halo rings remain separate until an incoming invitation is deliberately accepted. The joined emblem represents mutual agreement, not a delivery receipt, compatibility score or instruction to approach someone.

The existing near-black stage, Manrope typography, ivory stock and Social coral continue the approved Social Objects direction. Common Ground's miniature stays in the venue header. The rings, invitation, names, controls and status text are native editable Figma elements. No new photographic portrait, raster hero or 3D rig is required.

Pending is calm. There is no pulsing demand for an answer, countdown pressure, heart score, confetti, read receipt or “online now” claim. The invitation can be withdrawn. A recipient can choose not to accept without explaining why.

## Two independent examples

The current fictional actor is Alex. Alex and Maya both have Social intent and Chat first approach. Common Ground allows Social and Business in the fixed Thursday 8 PM snapshot inherited from Places and Room, with the example session ending at 10 PM. This is a fixed demonstration, not the device's current time or a live presence claim. The fictional Social / Chat first values must not replace the user's actual intent or approach in a later native implementation. Compatibility must be derived from the real current draft and target; the reviewed Maya fixture cannot be offered to an incompatible Business user.

The demo menu explicitly starts either a new outgoing example or a new incoming example. These are distinct fictional Wave identities, not two roles in one transaction:

| Example | Sender | Recipient | Acceptance authority |
|---|---|---|---|
| Outgoing | Alex | Maya | Maya, whose response is not simulated by a sender-facing Accept control |
| Incoming | Maya | Alex | Alex, through the incoming invitation's Accept action |

The outgoing example covers confirmation, pending and withdrawal. It never exposes an Accept action to Alex. The incoming example covers review, acceptance, decline and unavailability. Returning to the menu and explicitly starting the incoming example creates a different fixture; it must not mutate the outgoing Wave's recipient or allow its sender to accept it.

All identities, invitations and results are fictional. No notification is delivered and no production verification, membership, presence or conversation entitlement is set. The demo label and “nothing is sent” explanation remain visible in the relevant flows. Demo conditions are clearly separated from ordinary product actions.

The bounded native handoff uses the actual viewer draft and existing central Room run/block state. Social can target an eligible unblocked Maya; Business can target an eligible unblocked Jules. Alex/Maya remain reference names only. Viewer and counterpart approaches need not match and must not be falsely labeled as shared. Each explicit Wave start gets a fresh immutable identity, but it never resets Room phase, clears a block or revives an ended Room. A standalone Figma example restart is not a native permission to restore the same blocked actor.

## Invitation and pending

Confirmation preserves the recipient, shared venue, intent and approach preference. Sending a demo Wave means an invitation to a temporary text conversation, not permission to meet, a guarantee of a reply or a retained connection.

Pending has a clear withdrawal action. It must not return through a stale confirmation screen that permits a duplicate send or refunds an allowance by navigation. A terminal withdrawn example cannot later be accepted. Starting another independent example is explicit.

The blueprint requires a limited Wave allowance, but does not specify its numeric quota, refill period or refund policy. The design therefore shows available and unavailable demo conditions without inventing a production limit or timer. A future implementation must obtain actual remaining allowance from the authoritative policy/service. It must not adopt an arbitrary daily count from this review.

## Incoming and mutual agreement

Only the designated recipient of an active pending Wave may accept it. The incoming example offers clear Accept and Decline Wave actions. Declining does not require a reason. The private choice does not create a recipient-to-sender rejection notification in this preview.

The rings join only after the recipient's acceptance. The resulting copy describes both people's agreement to a temporary chat. An informational action explains the next chapter; this design does not yet create a message composer, send messages, retain a relationship or implement Keep Connection.

Approach preference remains separate from consent. Chat first does not pre-accept an invitation. Okay to say hello does not authorize a private conversation or require continued interaction. Other intents have no Wave action, as established in the approved Room design.

## Unavailable and terminal states

The review includes withdrawn, declined, expired/unavailable, blocked, allowance-unavailable and ended examples. A withdrawn, declined, expired or blocked Wave cannot reach the old accepted state. Generic unavailability avoids claiming whether the other person blocked, left, was suspended or changed their mind unless the viewer performed the action themselves.

An incoming sender-withdrawn example cannot be accepted. A stale Accept tap in a future application must be revalidated against the current server state, rather than trusting the screen that happened to be displayed. At acceptance, both participants must still share the same current intent and venue, have valid venue membership, remain unblocked and have an active pending invitation.

Blocked state hides the blocked person's identity and routes. It cannot restore the old profile, invitation, notes or accepted result through Back, tabs or an overlay. In production, blocking is symmetric for visibility and communication and overrides previous connections.

Native blocking updates the same central Room block set, preserving prior blocks and hiding the actor across Room and Wave. Blocking Jules also removes his public sample note. New Wave example controls must keep that block applied. Only the prior Room chapter's separate, explicit new Room run can reset its fictional fixture; the Wave menu cannot bypass that entry contract.

Leave and disappear ends the demo immediately. The ended state returns to Places; it cannot return directly to an active Wave. A new demonstration requires explicit entry. Real session expiry, venue closure, suspension and safety revocation must also invalidate access; a client must never extend its own production lifetime.

## Safety and report preview

Safety and immediate exit remain reachable during active examples, including the accepted result. Contextual blocking acts on Maya in the demonstration. The report preview offers local reason selection and clearly states that nothing is submitted. Closing it returns to its caller without changing the invitation state or accepting anything.

This review provides no report receipt, moderation queue, evidence upload or emergency-monitoring claim. Production reporting and evidence handling remain governed by the founder blueprint and later implementation work.

## Motion and accessibility

The proposed signature movement joins the rings in 800 ms after acceptance, within the approved Social Objects choreography range of 700–950 ms. Ordinary transitions use 240 ms. No animation runs to manufacture a reply. Decorative movement must remain interruptible; safety actions and state changes must not wait for it.

Reduce Motion should use an immediate joined emblem or restrained crossfade, with the same explicit text. Meaningful text and controls use at least 14 points in full-size reference frames and 44-point targets; the small inherited DEMO badge is a separate label. Native Dynamic Type, VoiceOver, focus order and device performance require later implementation and testing. A Figma transition or static screenshot does not establish any native frame rate or runtime behavior.

## Source grounding

- *Proximeet Social Objects Showcase*, page 5: a Wave remains pending until mutual agreement; no private chat before mutual acceptance; both people must separately choose Keep.
- Same showcase, page 6: Handshake joins only after both agree; proposed 700–950 ms choreography; reduced-motion joined static emblem; these are targets, not measured device performance.
- *Proximeet Founder Operating Blueprint*, pages 10–13: deliberate Wave confirmation, remaining allowance, pending, mutual Handshake, temporary text-only chat, persistent safety, immediate exit and accessible states. Production transitions are server-authorized.
- Same blueprint, page 17: current verified venue membership, compatible intent, no blocked recipient, no conversation without active mutual agreement, no client-extended lifetime, and block overriding all prior connection state.

## Review record

The approved package is PROXIMEET_WAVE_APPROVED_HANDOFF.zip, with PROXIMEET_WAVE_CLAUDE_PROMPT.md and WAVE_LAYOUT_SPEC.json. It requires genuine implementation of the first eight approved chapters. The eligible same-intent Room profile action becomes Preview Wave demo and opens the explicit example menu while preserving the central run, block set and actual draft. The standalone Places return shortcut is a Figma review fixture, not an implementation route. Chat and Keep remain informational until their separate approved handoff.

Figma file: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=76-387

Wave page: `74:567`. Review board: `76:387`. Review image: `PROXIMEET_WAVE_REVIEW.png`, 1480 × 2020. Twelve full-screen states and seven overlays are authored on the new Wave page. The original approved chapter screens are preserved. A same-page Places reference supports the explicit ended-demo return.

| State | Figma node | Invitation | Ring state |
|---|---|---|---|
| demo-menu | 74:568 | No active invitation | separate |
| out-confirm | 74:569 | outgoing | separate |
| out-pending | 74:570 | outgoing | separate |
| out-withdrawn | 74:571 | outgoing | absent |
| in-review | 74:572 | incoming | separate |
| in-declined | 74:573 | incoming | absent |
| in-accepted | 74:574 | incoming | joined |
| unavailable | 74:575 | No active invitation | absent |
| blocked | 74:576 | No active invitation | absent |
| allowance-unavailable | 74:577 | No active invitation | absent |
| session-ended | 74:578 | No active invitation | absent |
| in-withdrawn | 74:579 | incoming | absent |

Seven overlays cover global safety, Maya's contextual safety, an unsent report preview, private-chat information, and distinct demo-condition controls for outgoing, incoming and accepted examples. The report selector has four local component variants (no reason selected and three selectable reasons). Nothing is submitted.

Root and independent visual reviews found no blocking defects. The review and pending rings are separate; only the incoming accepted frame joins them. The board labels outgoing and incoming examples separately, and Alex remains the viewer throughout. Native card text, controls and material shapes remain editable.

The actual Figma reaction readback contains 74 routes. Its bounded navigation audit passed: exactly one edge enters accepted, from Alex's incoming recipient Accept action; no outgoing sender action accepts a Wave; pending cannot reopen confirmation for a duplicate send; all seven closed/invalid fixtures cannot reach an active invitation without explicit new-example controls; blocked Maya stays hidden until a new explicit demo; overlay Close preserves its caller; report choices stay local. There are no automatic triggers or URL actions.

Readback confirms an 800 ms Smart Animate action on recipient acceptance and 240 ms dissolve transitions elsewhere. The resting ring poses are separate in review/pending and joined only in accepted. Body text is at least 14 points and interactive targets at least 44 points; the small inherited DEMO badge remains 11 points. These findings cover the designed Social fixture and its Figma navigation, not a native app or production authorization.

Motion settings and static visual review do not establish native runtime, backend security, device accessibility, actual animation playback or measured frame rate.

Founder approval annotation 84:498 sits outside all app frames on page 74:567. The historical review PNG and outer review captions retain their original status; this dated approval supersedes those captions. Original reviewed screens and the PNG remain unchanged. The packaged graph audit describes the isolated Social fixture, including explicit independent fixture restarts. The integrated native handoff additionally requires central Room block/run continuity across those controls; the graph alone does not validate that integration.
