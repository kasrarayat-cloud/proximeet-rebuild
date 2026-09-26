# Proximeet — Signal chapter review

Status: Chapter 6 Signal was approved by the founder with “approve go next” on 24 September 2026 at 20:03 PDT / 25 September 2026 UTC. Approval covers twelve app states, carried intent, two approach preferences and bounded two-dimensional tag motion. Chapters 1–5, through Wristband, are also approved. This is an approved Figma design and implementation handoff; no app code, real account, check-in, message, Bluetooth connection, build or deployment was created.

Figma review: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=54-411

Social example entry: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=50-191

## The idea

The band says what kind of connection fits this moment. A small brushed-steel tag says how a hello should begin. The actual chosen band carries forward, preserving its color, weave, silhouette and clasp. The tag is an app metaphor. It is separate from the optional future physical Pulse wearable concept.

The headline is “A hello, / on your terms.” The two choices follow the founder blueprint’s content examples:

| Preference | Meaning |
|---|---|
| Chat first | Start with a Wave. Chat after you both agree. |
| Okay to say hello | Open to a brief hello. No pressure to continue. |

There is no preselected preference. Both choices have equal prominence. The native text, icon and selected control identify the preference; material and color are decorative support.

## Product behavior

- Carry the chosen Social, Dating, Business or Activity intent from Wristband. A Social example in a review must not become an implementation default.
- Initially show the carried band with a blank, unattached tag and disabled Continue preview.
- Choose one preference, show its native icon on the tag, and enable Continue preview. Choosing the other preference replaces it. Tapping the active preference is a no-op.
- Never advance automatically. Preserve the draft intent and preference when navigating back in the bounded implementation. Returning to Wristband and changing intent must retain the existing approach preference; returning to Signal shows the new band with the same preference and attached pose.
- The displayed preference expresses a current preference, not a promise or continuing consent. Either person can change their mind.
- Selecting a preference does not send a Wave, accept a Wave, open chat, check in, enable discoverability or grant access to permissions. Chat still requires a deliberate Wave and the other person’s acceptance.
- No participant visibility before venue check-in. DEMO remains visible. No real person data is used.
- Continue stops at the end of the current design preview while Places is unapproved. A clickable design must not imply a functioning venue service.

## Artwork

The four bands are the unchanged approved Wristband artwork. The new tag is a separate transparent raster asset, with a blank steel face and small hollow attachment loop. Preference icons and all readable text are native Figma elements.

Tag original: `generated_images/exec-7e2d5ee6-48f9-49bb-8226-12d3f67f9b5b.png`, 1254 × 1254 RGBA. Delivery crop: [41, 154, 1216, 1060]. Delivery: 176 × 136 transparent PNG. The original and delivery are decorative images, not CAD, a functional electronic device or a 3D rig. Full generation prompt and provenance accompany this review.

## Motion and accessibility

The separate tag supports a restrained two-dimensional movement from its resting position to the band. It does not supply a true three-dimensional clip, clasp articulation, perspective change or physical occlusion. The original Social Objects proposal’s 0.45–0.65 second lift/arc/clip remains a production choreography target that would need additional assets or a rig to reproduce fully.

Authored in Figma: a 500 ms ease-out Smart Animate transition on the first selection, translating and straightening the separate tag; a 220 ms ease-out dissolve when switching preferences. Both are triggered by a tap. There are no looping animations or automatic transitions. The transition configuration and resting poses have been inspected; motion has not been video-verified or measured on an iPhone.

Reduced Motion should show the selected attached pose immediately. Selection and navigation must not wait for decorative motion. A later app should expose native single-choice semantics, selected state and clear labels to VoiceOver, preserve a logical reading order, and adapt to Dynamic Type and safe areas. A fixed Figma frame is a visual reference, not proof of those runtime behaviors.

## Source grounding

- *Proximeet Founder Operating Blueprint*, page 13: “Chat first” / “Okay to say hello” content examples and consent/accessibility principles.
- *Proximeet Social Objects Showcase*, page 5: a machined tag attaches to the selected band; no live visibility before check-in; no chat before mutual acceptance.
- Same showcase, page 6: Signal lift/arc/clip target and reduced-motion attached pose.
- Founder approval of Chapter 5: “on wrist section its perfect i approve it”, recorded 25 September 2026 UTC. Signal subsequently received its own approval, recorded above. Neither approval includes physical hardware.

## Review record

The final native Figma composition is `PROXIMEET_SIGNAL_REVIEW.png`, 1480 × 1570. It shows the three Social examples and the attached tag across all four materials. Root visual review found no missing art, clipped copy or overlapping controls. The complete page contains twelve 440 × 956 frames, not only the three displayed on the board.

| Carried intent | Unselected | Chat first | Okay to say hello |
|---|---|---|---|
| Social | 50:191 | 50:192 | 50:193 |
| Dating | 50:194 | 50:195 | 50:196 |
| Business | 50:197 | 50:198 | 50:199 |
| Activity | 50:200 | 50:201 | 50:202 |

Page: 50:190. Review board: 54:411. Native reusable choice components: 52:207, 52:215, 52:225 and 52:232. All twelve frames use Manrope; 24 band/tag bindings were checked. Helpers and privacy text are 14 px. Choice rows are 376 × 84. Primary action is 376 × 60. Header Back and secondary Back are at least 44 px.

Back targets unchanged Wristband copies on the new page: Social 52:247, Dating 52:434, Business 52:621, Activity 52:808. These are review fixtures. Their Continue enters the corresponding intent's unselected Signal example; they do not implement persistent approach drafts or the original Wristband's full navigation. The future native app must preserve draft values as described above. Original approved Wristband frames remain unchanged.

All selected-state taps are no-ops on the active option; the alternative remains available. Continue preview is deliberately unwired in every Figma state while Places remains unapproved. The bounded native handoff specifies a dismissible “End of this preview.” message with OK and preserves the selected Signal state. No demo endpoint should be interpreted as a real service.

The approved bounded handoff is PROXIMEET_SIGNAL_APPROVED_HANDOFF.zip, with PROXIMEET_SIGNAL_CLAUDE_PROMPT.md and SIGNAL_LAYOUT_SPEC.json. It requires genuine implementation of the approved first five chapters before integrating Signal. Its only earlier destination change replaces Wristband's temporary endpoint with Signal, carrying the actual selected intent and preserving both draft values. Places requires a separate approved handoff.

Founder approval annotation 58:478 sits outside the app frames on page 50:190. The historical review PNG and outer Figma review captions retain their original review status; this dated approval supersedes those captions. The original twelve app frames and review PNG are unchanged. Pulse remains a separate future hardware proposal and is not a requirement in this package.
