# Proximeet — approved Signal handoff

The founder approved Chapter 6 with “approve go next” on 24 September 2026 at 20:03 PDT / 25 September 2026 UTC. This covers twelve app states and bounded two-dimensional tag motion. The optional future Pulse wearable is separate.

## Use with Claude

1. Implement and review the approved Welcome, Birthday, explicit Pass demo, Guest List and Wristband chapters first. This handoff assumes those native SwiftUI dependencies exist.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the extracted folder's absolute path.
4. Return Claude's full report for review. This prompt covers Signal and minimal Wristband navigation/draft integration only.

No app code, repository, build, signing, deployment, TestFlight or hardware purchase was changed to prepare this package. No automatic app coding agent was invoked.

## Approved reference

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=54-411

Page: 50:190. Review board: 54:411. Approval annotation outside the app frames: 58:478.

| Carried intent | No preference | Chat first | Okay to say hello |
| --- | --- | --- | --- |
| Social | 50:191 | 50:192 | 50:193 |
| Dating | 50:194 | 50:195 | 50:196 |
| Business | 50:197 | 50:198 | 50:199 |
| Activity | 50:200 | 50:201 | 50:202 |

`LAYOUT_SPEC.json` measures all 492 native nodes across these twelve states, including text, styles, root fills, layout, transforms, vectors and reactions. Coordinates are relative to each recorded parent; root x/y locate frames on the Figma canvas. Reference screens are 440 × 956 logical units and must adapt to actual safe areas, orientation and Dynamic Type.

`reference/signal-review.png` is the unchanged historical approval board. It shows the three Social examples and attached tags across all four band materials. Its awaiting-approval caption is superseded by the dated founder approval above; that caption is not app copy.

## State and navigation contract

Signal carries the actual selected Wristband intent. Social examples are not a default. A fresh draft starts with no approach selected. Choose exactly one of Chat first or Okay to say hello; tapping the active choice is a no-op. Only a deliberate choice enables Continue. Selection never advances automatically or grants ongoing consent.

Wristband's previous endpoint now enters Signal. Back returns to the actual Wristband draft. Re-entry retains approach; changing the band retains approach while updating its artwork and summary. Earlier Guest List edits must preserve both values. Figma's same-page return copies reset approach for review navigation; that fixture behavior is not the native contract.

Continue shows a dismissible native “End of this preview.” message with OK and stays on the selected Signal state until Places has its own approved handoff. Figma leaves Continue unwired. Repeated taps must not stack alerts or routes.

The draft remains only in memory during this prototype session. Nothing sends or accepts a Wave, opens chat, creates an account, verifies age, checks in, discovers a real participant, writes data or enables permissions. DEMO and “You stay private until venue check-in.” remain visible. The latter expresses a product boundary, not proof of a functioning venue service. Approach preference does not override the later mutual Wave/acceptance requirement.

## Assets and fonts

| Decoration | Original | Exact Figma reference |
| --- | --- | --- |
| Social band | assets/wristband-social.png | reference/social-delivery.jpg |
| Dating band | assets/wristband-dating.png | reference/dating-delivery.jpg |
| Business band | assets/wristband-business.png | reference/business-delivery.jpg |
| Activity band | assets/wristband-activity.png | reference/activity-delivery.jpg |
| Blank steel tag | assets/signal-tag.png | reference/tag-delivery.png |

All originals are 1254 × 1254 RGBA. The four unchanged approved bands share crop `[22, 335, 1235, 920]`; their delivery references are 540 × 260 JPEGs composited on RGB(5,6,6). The blank tag uses crop `[41, 154, 1216, 1060]`; its 176 × 136 delivery PNG retains transparency. Use the original alpha sources for implementation, preserving aspect ratio and hollow openings.

The hero is x32/y326, 376 × 216. Band bounds inside it are x0/y10, 376 × 181. The tag is 88 × 68: resting x279/y124 with Figma rotation −9°, selected x144/y129 with rotation 0°. The exact relative matrices are in the specification; note that Figma and native rotation conventions/anchors may differ. Selected native glyph bounds are tag-local x31.5/y31, 25 × 25. Move tag art and glyph together; all controls, words and icons remain native rather than baked into raster art.

`ART_PROMPT.json` records the tag's provenance, unchanged band reuse and approval. It is not an instruction to regenerate. `fonts/` contains Manrope Regular, Medium, SemiBold, Bold and ExtraBold static fonts, original variable font, source metadata and OFL license. Preserve the license and recorded names.

## Motion and verification scope

First selection: 500 ms ease-out tag translation/straightening. Switching selected preference: 220 ms ease-out dissolve at the attached pose. Selected-tile taps do not replay motion, and returning to an existing selection does not replay first attachment. Reduce Motion displays the final state immediately. Controls and model updates never wait for decorative animation.

This is layered two-dimensional motion, not a 3D clip or hardware connection. No rig, depth model or separated mechanical layers are provided. VoiceOver semantics, large-text reflow, animation interruption and native runtime behavior remain implementation requirements; the Figma review did not verify them on an iPhone.

See `CLAUDE_PROMPT.md` for state tests, accessible controls and honest reporting of unavailable native checks. `SHA256SUMS.txt` covers every other file in this ZIP and excludes itself.
