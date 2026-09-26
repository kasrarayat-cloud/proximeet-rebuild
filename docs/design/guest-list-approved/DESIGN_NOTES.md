# Proximeet — Guest List chapter review

Status: Chapter 4 Guest List was approved by the founder on 25 September 2026: “i approve”. This covers the three-state introduction/card prototype and its bounded form choices. Welcome, Birthday and Pass designs are also approved. Design approval does not establish an implemented app, production identity rules or approval of Wristband.

Figma review: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=36-260
Start frame: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=36-134

## Design

Your introduction becomes a small personal card. Black stage, Manrope typography, ivory cotton paper, brushed steel and a cyan woven tab connect this chapter to the approved chapters.

The editor gives space to a name, an optional opener and a few interests. Its paper-card preview is readable at the screen's natural size, with an initials avatar so a photo is not required in this proposal. All text, form labels, control surfaces, initials and interest labels are native editable Figma nodes. The paper housing is decorative raster artwork, not a production 3D model or rig.

## Approved prototype data choices

- Name required to enable Preview my card. This is a display name; no surname or legal name is required.
- Introduction optional, maximum 120 user-perceived characters in this prototype.
- Interests optional, maximum three in this prototype.
- These are approved prototype constraints, not a claim about existing production rules.
- Coffee, Live music and Outdoors form the illustrative three-option prototype catalog. They are not a confirmed or complete production catalog.
- Alex and “Always up for coffee and a good story.” are fictional sample data. The sample is 38 characters.
- Intent belongs to the next Wristband chapter, and approach preference to Signal. They are not added to this form.
- No birthday, contact details or actual founder profile data appear here.

## Three review states

| State | Frame | Action |
|---|---|---|
| Empty introduction | 36:134 | Primary disabled. Clicking the name field loads the clearly labeled Alex review fixture. |
| Fictional Alex example | 36:169 | Preview my card opens 36:204. |
| Personal card preview | 36:204 | Edit introduction or Back returns to 36:169. Continue preview is deliberately unwired. |

Figma interaction is a click-through fixture, not working freeform text entry or editable chip selection. The board labels this explicitly. Back from either editor returns to an unchanged approved Pass copy, 36:229; that reference's primary action returns to the empty editor. Figma requires navigation targets on the same page. Approved original Pass screens were not changed.

Continue preview has no chapter destination until Wristband is designed and approved. The bounded native implementation handoff may show a dismissible “End of this preview.” message while staying on the card. It does not authorize a Wristband implementation. This review itself contains no chapter after Guest List.

## Motion

Implemented Figma navigation uses a 220 ms ease-out dissolve, triggered only by a click. No automatic advancement exists.

The proposed app transition is a 450 ms paper-card insert/settle: move the complete artwork and native card content together as a flat group. This is a motion direction for later implementation, not measured runtime behavior or a continuous 3D paper simulation. Reduced Motion keeps the card stationary and uses an instant state change or brief dissolve. Do not add looping motion while someone types.

## Prototype boundary

Every state carries a DEMO PROFILE badge and “This preview doesn’t make you visible to anyone.” No check-in, location lookup, membership, identity verification, age verification, discoverability, other people list or chat is activated. The initials avatar is a visual placeholder, not an identity or age signal. The Pass demo cannot produce real verification.

## Layout and accessibility intent

Logical design frame is 440 × 956. Header at x24/y64. Primary action at x32/y812, 376 × 60. Name input is 376 × 56. Introduction input is 376 × 88. Interest chips are 116 × 44. Back and secondary actions have 44 px targets. Native body text is 16 px or larger; interest chips and card interest line are 14 px. Manrope headline is 48 px.

Use a scrollable form and safe-area inset actions in the app, not fixed vertical coordinates when the keyboard is showing or Dynamic Type increases. Focus should move Name → Introduction; Return/Done should dismiss the keyboard as appropriate. Scroll the focused field above the keyboard. Keep labels visible and use native text-entry accessibility semantics. Preserve the draft when switching editor/preview. The paper decoration may shrink or be hidden in compact keyboard layouts. UI notes are requirements for later work, not claims of implemented or tested iOS behavior.

## Art provenance and exact delivery framing

Original: generated_images/exec-383c83d7-c4a4-4119-b004-741f76445ac5.png
Original dimensions: 1457 × 1079, RGBA.
Delivery crop box: [66, 93, 1436, 988], using the visible alpha silhouette.
Optimized delivery: proximeet-work/guest-list/guest-delivery.jpg, 540 × 353, composited on RGB(5,6,6), JPEG quality 76.
Figma image hash: 601bd43bfa538e365faa5e1503c34e73b18d4d19.
Shared card component: 36:126, 392 × 256.46. Decoration is FIT in the complete component bounds. Preview instance x24/y371.
Retain the original alpha artwork for later implementation and match this crop. Do not use a whole-screen screenshot as app UI.

## Figma map

- Approval note: 40:206 (25 September 2026)
- Page: 35:111
- Review board: 36:260
- Empty / example / preview: 36:134 / 36:169 / 36:204
- Shared demo header: 36:111
- Name input: 36:118
- Introduction input: 36:120
- Unselected / selected interest components: 36:122 / 36:124
- Personal card component: 36:126
- Approved Pass return reference: 36:229

## Implementation handoff

Use `PROXIMEET_GUEST_LIST_APPROVED_HANDOFF.zip` and its `CLAUDE_PROMPT.md` after the approved Welcome, Birthday and Pass chapters are actually implemented. The supplied board is the historical approval reference; any “awaiting approval” wording in its outer review caption records its original presentation, superseded by the status above. App copy and approved screen contents are unchanged.

The handoff replaces Pass's temporary review endpoint with the now-approved Guest List prototype. It does not set verification or account status. It requires real native text entry and interest selection, an initially empty draft, Unicode-aware introduction counting, accessible validation and preservation of in-memory edits when moving between the editor and card. The Alex fixture belongs only to previews/tests and must never prefill the user's form.

Original chapter screens remain untouched. No app code, repository, build, signing, TestFlight or deployment was changed to create these design assets and instructions.
