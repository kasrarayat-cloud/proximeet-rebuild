# Proximeet — Wristband chapter review

Status: Chapter 5 Wristband visual design and five-state intent selector were approved by the founder on 25 September 2026: “on wrist section its perfect i approve it”. Guest List, Welcome, Birthday and Pass designs are also approved. This approval covers the displayed app design, not a physical wearable, manufacturing or a hardware purchase. No app code changed.

Figma review: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=45-166
Start frame: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=42-112

## Direction

A current intent becomes a woven wristband. The four objects share an oval silhouette, stainless clasp, camera angle and lighting, while color and weave distinguish Social, Dating, Business and Activity. The stage, Manrope typography, ivory action button and cyan demo badge continue the approved chapters. The bands are decorative raster artwork; every label, explanation, selection control and icon is native editable Figma content.

The headline is “Choose your / kind of hello.” with “One intent for this moment.” This is a present choice, not a permanent personality label.

| Intent | Material direction | Native icon | Explanation |
|---|---|---|---|
| Social | Coral, basket weave | People | Meet people. Share a moment. |
| Dating | Orchid, herringbone | Heart | Explore a romantic connection. |
| Business | Blue, rib weave | Briefcase | Exchange ideas and opportunities. |
| Activity | Amber, chevron weave | Lightning bolt | Find someone to do things with. |

The native labels are required. Color or texture alone must never identify an intent. Selected tiles add a checkmark, contrasting border and an explicit “Selected” summary.

## States and behavior

| State | Figma frame | Primary |
|---|---|---|
| No intent selected | 42:112 | Continue preview disabled |
| Social selected | 42:113 | Continue preview enabled visually, unwired |
| Dating selected | 42:114 | Continue preview enabled visually, unwired |
| Business selected | 42:115 | Continue preview enabled visually, unwired |
| Activity selected | 42:116 | Continue preview enabled visually, unwired |

Initial entry shows all four bands at equal scale. There is no default selection. Tapping a tile opens the matching selected state. Only one intent can be selected. Tapping the already-selected tile has no action; the other three choices remain available. Nothing advances automatically.

The review board shows the empty, Social and Dating screens plus all four materials. Business and Activity each have a complete native screen on the same Figma page.

Continue preview is deliberately unwired because Chapter 6 Signal is not yet designed or approved. It does not navigate to a production feature, show a successful account state or submit anything. A future bounded implementation may show a dismissible end-of-preview message while staying here, subject to its approved handoff.

Back returns to the unchanged approved Guest List preview copy 44:485 on this page. Its Continue returns to the empty Wristband state. This is a Figma review fixture, not application state persistence. Original approved Guest List screens are unchanged.

## Boundaries

Every state carries DEMO and “Choosing a band doesn’t make you visible.” Selecting an intent does not verify age or identity, create an account, check in, disclose location, enable discoverability or grant anyone permission to approach or message. Approach preference belongs to the next Signal chapter. Mutual Wave/Keep rules remain separate.

The current review stores no real profile data. The Guest List return copy contains the already-labeled fictional Alex example.

## Motion

Implemented: click-triggered 220 ms ease-out dissolve between complete choice states. No auto-advance, looping motion, simulated verification or timer exists.

Proposed future motion: a restrained 0.65–0.85 second clasp closure after a deliberate confirmation. This is not implemented. The supplied art already shows a closed clasp and has no separated hardware layers, open pose or 3D rig; continuous closure requires separate production assets or a model. Do not pretend that scaling/crossfading these bitmaps is a physical clasp animation.

The fallback is the current short dissolve or an instant change with Reduced Motion. Selection must remain available without waiting for animation. No runtime frame-rate, device, VoiceOver or Reduce Motion testing has been performed by this Figma review.

## Layout and accessibility intent

Logical canvas 440 × 956. Header x24/y64. Main text x32/y148, 376 wide; 48 px ExtraBold headline with 56 px line height. Hero x32/y328, 376 × 200. A selected band is 376 × 181, centered inside the hero; the empty hero gives each band a 182 × 88 tile.

Selection summary begins y536. Native two-by-two choices begin x32/y602; each tile is 182 × 78 with a 12 px gap. Names are 16 px SemiBold with 24 px vector icons; short hints 12 px. Selected helper summary is 18 px, supporting explanation 14 px. Privacy boundary is y779, 14 px with a 20 px line height.

Primary x32/y812, 376 × 60. Secondary Back x32/y883, 376 × 44. Header Back is also 44 px. Use native single-choice semantics in a later app: speak each intent, selected/not selected, and its explanation. Preserve the chosen intent in memory when navigating back within the prototype.

The native implementation must adapt for safe areas and Dynamic Type, with scrollable content and safe-area actions when needed. Fixed Figma coordinates are visual reference only. Keep text on dark tile surfaces for contrast; do not put small white labels on solid coral/amber backgrounds.

## Art and delivery

All four originals are 1254 × 1254 RGBA:

- Social: generated_images/exec-802cf47d-e0dd-4b9c-bf73-0860b1465ead.png
- Dating: generated_images/exec-1463674a-ea85-44a0-8fab-8864e9d83ab7.png
- Business: generated_images/exec-77d622ac-7367-4110-8fa7-4cfa173694f4.png
- Activity: generated_images/exec-a8105b2b-c644-4e3e-916a-9174b9e183ba.png

Common visible-silhouette crop with margin: [22, 335, 1235, 920].
Delivery copies: 540 × 260 JPEG, quality 76, composited on RGB(5,6,6), under proximeet-work/wristband/*-delivery.jpg.
Figma uses FIT image fills. Retain original alpha artwork and apply the common crop in implementation. The delivery JPEG is an editor reference, not the only production source.

Image hashes:

- Social: 1f9eda118305d2db5ce3f30f630fcc8ddf350ed2
- Dating: 63b3b4e4f438be3ab91813215d8f74095e54d345
- Business: 2955f53ffb65a990f38a2ec0883bc33d87af9727
- Activity: eca9740f63b7c508b474da9116cbb2e3aa5e4b73

## Review evidence and next chapter

Review board 45:166 is 1480 × 1620. The first screenshot exposed blank image fills. Attaching image bytes directly to the named image nodes resolved all 18 instances; the post-fix screenshot shows the three review screens and four materials clearly. Root reviewed the corrected board and requested two final readability changes: privacy text is now 14 px and the outer caption explicitly says Continue destination pending Signal. The post-fix board has no text overlap and is PROXIMEET_WRISTBAND_REVIEW.png.

Page: 42:111. Approved Guest List return reference: 44:485. Guest List approval record: 40:206 on its original page.

The bounded approved Wristband Claude handoff is now prepared as PROXIMEET_WRISTBAND_APPROVED_HANDOFF.zip, with PROXIMEET_WRISTBAND_CLAUDE_PROMPT.md and the measured WRISTBAND_LAYOUT_SPEC.json. It requires the approved first four chapters to exist before implementation and uses a minimal native end-of-preview message while Signal remains unapproved. The founder approval annotation is 51:190, outside the app frames on page 42:111.

The founder asked to discuss future wearable ideas after approving this chapter; those ideas are a separate proposed track in PROXIMEET_PULSE_CONCEPT.md and are not requirements in the app handoff. Chapter 6 Signal remains the next design chapter. No automatic app coding, repository changes, deletion, build, signing, deployment, hardware purchase or TestFlight action was performed. The review PNG and Figma board retain their historical review caption; this dated approval record supersedes that caption.
