# Proximeet — approved Wristband handoff

The founder approved Chapter 5 on 2026-09-25 UTC: “on wrist section its perfect i approve it”. This package covers the five-state app intent selector and its decorative material family. Pulse is a separate future hardware concept and is not an implementation requirement here.

## Use with Claude

1. Implement and review the approved Welcome, Birthday, explicit Pass demo and Guest List chapters first. This package assumes those native SwiftUI dependencies exist; it does not combine chapters.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the absolute path to the extracted folder.
4. Return Claude's full report for review. This prompt covers Wristband and minimal approved Guest List navigation integration only.

No app code, repository, build, signing, deployment, TestFlight or hardware purchase was changed to create this package. No automatic coding agent was invoked.

## Approved references

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=45-166

Page: 42:111. Empty: 42:112. Social: 42:113. Dating: 42:114. Business: 42:115. Activity: 42:116. Approval annotation outside the app frames: 51:190. Review board: 45:166.

The reference screen is 440 × 956 logical units. `LAYOUT_SPEC.json` records all 270 native nodes across five states, including root fills, geometry, styles, text, vector paths/networks and prototype reactions. Coordinates are relative to each node's recorded parent; root x/y locate frames on the Figma canvas and are not app margins. Adapt actual layout for safe areas, available width, accessibility and orientation.

`reference/wristband-review.png` is the historical approval reference: it displays empty, Social and Dating screens plus all four materials. Business and Activity have complete native states in the specification and Figma. Outer review captions may still say awaiting approval; the dated founder approval above supersedes them. They are not app copy.

## State and navigation contract

Start a fresh session with no intent selected. Exactly one of Social, Dating, Business or Activity may then be selected; there is no default. The selected tile remains selected when tapped again. Other tiles change the single choice. Nothing advances automatically. Keep all four choices available and all summaries, artwork, selection indicators and CTA state derived from the same enum.

Guest List card's previous endpoint now opens Wristband. Either Back action returns to the actual Guest List card, retaining its introduction and the current intent in memory. Editing the introduction and revisiting Wristband must preserve both drafts. The Figma Guest List return clone is a static fixture, not the native navigation or persistence contract.

Continue preview is disabled while unselected. Once selected, it presents a minimal native “End of this preview.” message with OK and stays on the screen. This is the implementation endpoint while Signal has no approved handoff; Figma intentionally leaves the CTA unwired. Do not build future chapters from this package.

Every state retains DEMO and “Choosing a band doesn’t make you visible.” An intent is not verification, check-in, presence, discoverability or permission to approach/message. Keep it only in memory for this prototype session. No real profile creation, persistence, networking, location, Bluetooth, NFC, pairing, Apple Watch or production notifications are included.

## Artwork and fonts

The four original generated alpha artworks are:

| Native intent | Original in package | Exact Figma delivery reference |
| --- | --- | --- |
| Social | assets/wristband-social.png | reference/social-delivery.jpg |
| Dating | assets/wristband-dating.png | reference/dating-delivery.jpg |
| Business | assets/wristband-business.png | reference/business-delivery.jpg |
| Activity | assets/wristband-activity.png | reference/activity-delivery.jpg |

Each original is 1254 × 1254 RGBA. Use the common crop `[22, 335, 1235, 920]`, retaining alpha, and fit without distorting aspect ratio. The optimized references are 540 × 260 JPEGs composited on RGB(5,6,6). Empty-state bounds are 182 × 88 per artwork; selected artwork uses 376 × 181 centered in a 376 × 200 hero. Preserve the equal unselected sizes and consistent selected framing.

Do not regenerate, recolor or replace these assets, or render a screenshot as the app. Bands are raster decoration; native labels, icons, checkmarks, buttons and explanations remain independent. `ART_PROMPTS.json` records provenance and approval, not an instruction to regenerate. Its historical scratch paths identify sources; the package-relative asset mapping above is the implementation source.

`fonts/` contains licensed Manrope static Regular, Medium, SemiBold, Bold and ExtraBold weights, the original variable font, OFL license and source metadata. Preserve the license and recorded PostScript names. The measured specification contains resolved text properties and exact native icon vector paths/networks.

## Motion and accessibility

Figma provides a click-triggered 220 ms ease-out dissolve. The original art already shows closed clasps; it contains no open pose, separated layers or 3D rig. The earlier proposed clasp closure is not available in these assets. Use the restrained native state dissolve and an instant change or short dissolve for Reduce Motion. No looping motion or animation-dependent selection is needed.

The app must preserve native selected semantics, VoiceOver labels, minimum 44-point touch targets, readable contrast and Dynamic Type. At larger text sizes allow wrapping and a one-column choice layout with reachable controls. No device, runtime, accessibility or frame-rate result is implied by the Figma review. See `CLAUDE_PROMPT.md` for available checks and honest reporting when macOS/iOS verification cannot run.

`SHA256SUMS.txt` covers every other file in this ZIP; the manifest excludes itself.
