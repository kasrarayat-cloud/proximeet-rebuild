# Proximeet — approved Pass handoff

The founder approved the three-state Pass design on 2026-09-25: “i approve thsi as well”. This package is an explicit user-controlled prototype demonstration, not age or identity verification.

## Use with Claude

1. Implement and review the approved Welcome and Birthday chapters first. This package assumes those native implementations exist; it does not combine chapters.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the absolute path to the extracted folder.
4. Return Claude's full report for review. This prompt covers Pass and its minimal approved navigation integration only.

The assistant prepared design assets and instructions. No app code, remote build, signing configuration or deployment was changed to create this package.

## Approved reference

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=29-154

Pass page: 26:282. Intro: 27:111. Progress: 27:112. Complete: 27:113. The reference frame is 440 × 956 logical units. `LAYOUT_SPEC.json` records the native geometry and typography. The illustration is decoration; all labels, status copy, buttons and card typography are native UI.

Every transition is user-controlled. Try the demo opens Progress; Finish preview opens Complete; Cancel returns to Intro. Back and Leave demo return to the actual Birthday screen while preserving its in-memory draft. Re-entering Pass starts at Intro. No automatic timer or verified-state mutation exists.

Figma deliberately leaves Continue preview unwired. The implementation prompt completes that placeholder with a minimal native message, “End of this preview.”, while remaining on Complete. This functional endpoint is a documented implementation convenience, not a newly approved visual chapter. Guest List and all production access remain outside this package.

## Artwork and fonts

`assets/pass-artwork.png` is the original 1254 × 1254 transparent generated illustration, originating from `exec-4ad06890-2132-4b5c-a473-7d60dc88399a.png`. Use the full square source without cropping: `[0, 0, 1254, 1254]`. It fits an untransformed 400 × 400 local artwork box in Figma. `LAYOUT_SPEC.json` records its position in each state and all native overlay coordinates. Keep the paper and native typography aligned as one unit during motion.

`reference/pass-delivery.jpg` is the exact optimized 480 × 480 image used by Figma. `reference/pass-review.png` is the three-state visual reference, not a background to display as the interface. The artwork is a raster concept illustration, not a production 3D model or rig. `ART_PROMPT.json` records provenance and approval, not an instruction to regenerate it.

`fonts/` contains Manrope static Regular, Medium, SemiBold, Bold and ExtraBold weights, the original variable font, license and source metadata. Preserve `OFL.txt` and use the recorded font names.

## Approval and implementation boundaries

Every state retains DEMO, DEMO PASS, and “No age or identity verification is performed.” The 18+ graphic is an age-category graphic, not a credential. Do not set an account entitlement, authentication success or verification flag from this demo. Do not connect networking, camera, biometric capture, document upload, a verification provider or telemetry as part of this work.

A real verification integration is a separate future task, requiring a validated authoritative result; no such provider has been selected or implemented by this package. No vendor, retention, privacy or compliance promise is made.

The reference motion is a small native 2D lift/settle and dissolve. Reduce Motion keeps the pass stationary. No shader, complex animation SDK, 3D rig or extra purchase is required to implement this approved prototype.

`SHA256SUMS.txt` covers every other file in this ZIP. See `CLAUDE_PROMPT.md` for exact implementation scope, dependency checks, verification requirements and report format.
