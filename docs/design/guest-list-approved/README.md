# Proximeet — approved Guest List handoff

The founder approved Chapter 4's introduction/card prototype on 2026-09-25: “i approve”. This package contains design assets and implementation instructions. It does not create an account, verified identity or visible profile.

## Use with Claude

1. Implement and review the approved Welcome, Birthday and explicit Pass demo chapters first. This package assumes those native SwiftUI dependencies exist; it does not combine chapters.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the absolute path to the extracted folder.
4. Return Claude's full report for review. This prompt covers Guest List and its minimal approved Pass navigation integration only.

No app code, repository, build, signing, TestFlight or deployment was changed to create this package. No automatic coding agent was invoked.

## Approved reference

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=36-260

Guest List page: 35:111. Empty editor: 36:134. Fictional Alex example: 36:169. Card preview: 36:204. Shared card: 36:126. The reference frame is 440 × 956 logical units. `LAYOUT_SPEC.json` records native geometry, typography and controls. All form content and card overlays must remain native UI.

`reference/guest-list-review.png` is the historical three-state approval reference. Its outer review caption may still say “design proposal awaiting approval”; the founder's approval above supersedes that dated presentation status. The app screens themselves remain the approved reference. The Figma fixture is a click-through demonstration and does not provide real text entry. The implementation handoff explicitly requires working native text fields and togglable interests.

## Form and navigation scope

Begin with an empty display name, empty optional introduction and no interests selected. Name is required; the optional introduction allows 120 user-perceived characters; optional interests allow up to three. Coffee, Live music and Outdoors are the entire illustrative catalog for this bounded prototype, not a confirmed production catalog. Do not prefill Alex or the founder's personal data. The example is fictional.

Pass Complete's temporary review endpoint now opens the approved Guest List editor. Back from the editor returns to actual Pass Complete while preserving the introduction's in-memory draft for this session. Preview and Edit introduction keep the same draft and selection. A card with no optional opener/interests remains intentional, without empty separators or invented filler.

Figma deliberately leaves the card's Continue preview unwired. The implementation responds with a minimal native message, “End of this preview.”, while staying on the card. This is an implementation endpoint, not a new chapter. Wristband requires its own separate approval and handoff.

Every state retains DEMO PROFILE and “This preview doesn’t make you visible to anyone.” Nothing in this flow performs verification, check-in, real sign-in, location lookup, server profile creation, networking or visibility changes. Drafts remain in memory; do not persist them across relaunch or log their contents.

## Artwork and fonts

`assets/guest-list-card.png` is the original 1457 × 1079 RGBA generated artwork from `exec-383c83d7-c4a4-4119-b004-741f76445ac5.png`. Use the exact visible-silhouette crop `[66, 93, 1436, 988]` before fitting it into the 392 × 256.46 shared card component. The preview's component origin is x24/y371 in the 440 × 956 reference.

`reference/guest-delivery.jpg` is the exact optimized 540 × 353 image used in Figma, composited on RGB(5,6,6). Use the original alpha artwork for implementation and the JPEG to compare framing. Paper, clip, cyan fabric and holder are raster decoration, not a production 3D model. Native name, initials, opener and interest labels overlay the paper. Do not display the whole-screen review image as the app interface or regenerate the approved illustration.

`fonts/` contains Manrope static Regular, Medium, SemiBold, Bold and ExtraBold weights, the original variable font, source metadata and OFL license. Preserve the license and recorded font names.

## Motion and adaptive layout

Figma implements a click-triggered 220 ms ease-out dissolve. A 450 ms flat-card insert/settle is proposed optional native motion, not a measured runtime animation or 3D paper simulation. Move decoration and card content together; Reduce Motion keeps them stationary. Do not animate while typing or delay controls until motion ends.

The app must support native text editing, accessible validation, keyboard avoidance, hardware keyboard focus, VoiceOver and Dynamic Type. Long names and optional content reflow instead of clipping; decorative framing may adapt when readable text needs more room. See `CLAUDE_PROMPT.md` for Unicode handling, validation, meaningful checks and honest reporting of unavailable macOS/device verification.

`SHA256SUMS.txt` covers every other file in this ZIP. `ART_PROMPT.json` records provenance and approval; it is not an instruction to regenerate the artwork.
