# Proximeet — Room chapter review

Status: Chapter 8 Room was approved by the founder with “approve go next” on 24 September 2026 at 21:46:12 PDT / 25 September 2026 UTC. Chapters 1–7, through Places, are also approved. Approval covers explicit fictional demo entry, privacy waiting, introduction cards, read-only notes and local safety controls. The approved Room Claude handoff is prepared; no app code, build or service was implemented.

## Direction

The Common Ground venue ticket becomes a compact room header. The approved miniature café remains recognizable while the main space opens for personal introduction cards. Ivory paper, restrained metal details, Manrope typography and the dark stage continue the Social Objects direction. People have stable cards and clear words for their intent and approach; there is no swipe ranking, proximity radar or popularity display.

The review carries a fictional Social / Chat first example. It must not become a hardcoded native default. A later app must retain the user's actual intent and approach and derive compatibility from them. Common Ground permits Social and Business in the fixed Thursday 8 PM demo snapshot established in Places.

## Explicit demo entry

Room is introduced through a separate, deliberate demo entry. It explains that the people and session are fictional and that no real check-in, identity verification, location access or camera scan runs. Entering the demo must never set production verified/presence/membership flags or satisfy a production authorization guard.

The privacy waiting example contains no attendee names, avatars, participant messages, profile links or exact counts. A plainly labeled demo control chooses the populated fixture for review; it is not a normal way to bypass a production crowd threshold. No elapsed timer or automatic success opens the room.

Production remains governed by the founder blueprint: the backend authorizes a current verified venue session, privacy thresholds and later consent transitions. Client-side preview state is no substitute. This Figma review does not prove any backend behavior.

## Fictional participants and room notes

Two illustrative introduction cards are shown, not a total attendee count or a numeric privacy policy:

| Sample | Intent | Approach | Relationship to Social example |
|---|---|---|---|
| Maya | Social | Chat first | Same-intent Wave information may be viewed |
| Jules | Business | Okay to say hello | No Wave action |

Use abstract initials, not real photos or identities. Names, introductions and messages are fictional. “People” or “Sample introductions” must not become “Everyone here”, “Only two” or an exact attendance count. The populated fixture assumes a sufficient crowd separately; it does not establish a production threshold of two.

Room notes include a host announcement, an icebreaker and a read-only public sample from Jules. Social and Business participants can share the same allowed venue room; same-intent restrictions still govern Waves. No phone numbers, email addresses, external links, payment requests or private conversation are included.

Public posting/composition, topic threads, rate limits, moderation workflows and live updates remain part of the broader Room scope. This review covers reading the example notes and reaching contextual safety controls, not a functioning public messaging service.

## Wave boundary

The same-intent profile offers “How Waves work”, opening an information overlay. It explains that a Wave is an invitation and chat opens only after the other person accepts, with sending reserved for the next preview. It does not send an invitation, create a pending Wave, match people, accept consent or open chat.

The Business profile has no Wave action for the reviewed Social fixture and explains that Waves stay within the selected intent. In the bounded native implementation, compatibility must instead derive from the actual carried intent: Social can view Maya's Wave information and Business can view Jules's. The incompatible actor gets the approved Back to people action and same-intent explanation. This still never sends a Wave. Approach preference remains separate from intent and consent. “Okay to say hello” is not an obligation to meet or continue.

## Safety and state continuity

A safety control stays reachable in waiting, the room and profiles. Participant-specific controls are attached to profiles and the public sample message. A report preview can show reasons, but it explicitly says nothing is submitted; there is no fabricated report receipt, moderation queue or staff notification.

Blocking within the demo visibly removes that sample person's introduction, profile routes and any sample message. Maya's block does not remove Jules's note; Jules's block removes both his card and his note. Host context remains. When both are hidden, the empty state says there are no sample introductions to show; it must not claim the actual venue is empty or below its crowd threshold.

The design uses four visibility fixtures: neither blocked, Maya blocked, Jules blocked and both blocked. Each has appropriate People and Room notes states. Profiles exist only for still-visible actors. Contextual overlays and return paths must preserve the caller's visibility fixture, preventing Back or a tab switch from restoring a blocked actor.

“Leave and disappear” is immediate, without a confirmation step or request for a reason. It lands on a terminal ended state. That state cannot navigate Back into an active sample room; returning to Places or explicitly starting a new demo is the only way forward. A real expiry, venue closure, suspension or safety revocation would also invalidate the room and its routes; this fixed review must not imply a live countdown or a client-extendable production session.

## Artwork and implementation boundary

The café miniature is the unchanged approved Common Ground illustration, originally generated for Places. Its original 1254 × 1254 RGBA source is `generated_images/exec-f03e538e-de2f-45bb-9998-f139909e2f99.png`; crop [46, 83, 1211, 1218]; Figma delivery `proximeet-work/places/common-ground-delivery.png`, 288 × 281 with alpha. Names, personal cards, text, symbols and controls remain native editable Figma elements. No new portrait or real-person photograph is required.

Artwork is raster decoration, not 3D geometry. The proposed ticket-to-header movement is a bounded two-dimensional Figma transition. No native build, device frame rate, VoiceOver, Dynamic Type or runtime authorization result is implied. Reduce Motion must give a clear immediate state or simple crossfade. Controls and model state must not wait for decorative animation.

## Source grounding

- *Proximeet Social Objects Showcase*, pages 5–6: venue ticket becomes a room header; stable people cards; no Wave action for other intents; no visibility before check-in; no chat before mutual acceptance.
- *Proximeet Founder Operating Blueprint*, pages 9 and 11–13: minimum crowd threshold, public text lobby, host announcements, icebreakers, report/block attached to profiles and messages, immediate Leave and Disappear, session expiry, initial avatars for prototypes and clear accessibility semantics.
- Same blueprint, page 17: current verified venue session required; incompatible/blocked users cannot receive Waves; blocking overrides prior connection state; production backend authorizes membership and expiry.

## Review record

The approved package is PROXIMEET_ROOM_APPROVED_HANDOFF.zip, with PROXIMEET_ROOM_CLAUDE_PROMPT.md and ROOM_LAYOUT_SPEC.json. It requires genuine implementation of the first seven approved chapters. The minimal earlier integration changes the eligible Common Ground explanation's primary to Preview room demo, opening the separate entry gate. It preserves actual Places detail/category navigation and does not adopt the simplified Figma reference's shortcuts or inert controls.

Only Enter room demo starts a new local run in waiting; only the labeled Show populated example control exposes the fictional populated fixture. The actual intent/approach remains intact. Room entry is allowed only for Common Ground's permitted Social/Business intents in the fixed fictional snapshot. Reports remain unsent, blocks remain applied through the run, and Leave is terminal. Wave sending requires a separate approved handoff.

Figma file: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=68-465

Room page: `66:111`. Review board: `68:465`. Review image: `PROXIMEET_ROOM_REVIEW.png`, 1480 × 2020. Fifteen full-screen states and eight overlays are authored on the new Room page; previous approved screens are preserved. A same-page Places reference supports demo entry and return navigation.

| State | Figma node | Hidden sample actors |
|---|---|---|
| entry | 66:112 | Not applicable |
| waiting | 66:113 | None |
| ended | 66:114 | Not applicable |
| people-0 | 66:115 | None |
| notes-0 | 66:116 | None |
| people-1 | 66:119 | Maya |
| notes-1 | 66:120 | Maya |
| people-2 | 66:122 | Jules |
| notes-2 | 66:123 | Jules |
| people-3 | 66:125 | Maya and Jules |
| notes-3 | 66:126 | Maya and Jules |
| maya-0 | 66:117 | None |
| maya-2 | 66:124 | Jules |
| jules-0 | 66:118 | None |
| jules-1 | 66:121 | Maya |

Eight overlays cover global safety, four actor/visibility safety contexts, two unsent report previews and Wave information. Report reasons use four component variants (none selected and three selectable local reasons). They never route to a submission endpoint.

The extracted Figma interaction graph passed its bounded review: all twelve active starting fixtures preserve existing blocked actors across reachable states until the demo ends; waiting cannot expose participant identities without the labeled populated-example control; ended cannot return to an active room without explicit new entry; overlay close restores the caller. This validates the designed navigation graph, not an implemented app, backend or security boundary.

Root and independent visual reviews found no blocking layout defects. Body copy is at least 14 points in full-size app frames, Manrope is used throughout, and interactive targets are at least 44 points. The small existing DEMO badge is 11 points. Exact native text scaling, contrast in device conditions, VoiceOver and focus order still require implementation and device validation.

The Figma motion proposal uses a 500 ms entry ticket-to-header transition and 240 ms tab transitions. These are two-dimensional presentation transitions; no 3D rig, video capture or measured native performance is claimed. Reduce Motion is an implementation requirement, not a validated native capability in this review.

Founder approval annotation 74:566 sits outside all app frames on page 66:111. The historical review PNG and outer review captions retain their original review status; this dated approval supersedes those captions. Original reviewed app frames and the review PNG are unchanged. The packaged Figma graph audit covers the Social fixture; native Business compatibility and runtime safety/accessibility remain implementation checks.
