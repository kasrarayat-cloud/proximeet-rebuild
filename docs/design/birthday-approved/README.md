# Proximeet — approved Birthday handoff

Birthday visual design was approved by the founder on 2026-09-24: “approve lets go next perfect”.

## Use with Claude

1. First implement and review the approved Welcome chapter using PROXIMEET_WELCOME_APPROVED_HANDOFF.zip. This package assumes that implementation exists; it does not silently combine both chapters.
2. Extract this ZIP into a task folder Claude can read.
3. Paste CLAUDE_PROMPT.md into Claude Code and give it the absolute path of the extracted folder.
4. Return Claude's complete report for review. The prompt covers Birthday only, with no destructive reset, push, build dispatch, signing or deployment.

This package contains design assets and instructions. The assistant did not edit the app or run Claude to create it.

## Approved reference

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=23-195

Page16:114; empty19:111; adult19:112; under-18 19:113. The canvas is440x956 logical design units, with a376x266 decorative housing at(32,378). LAYOUT_SPEC.json contains full native typography and geometry.

Figma only cycles three illustrative example dates. Implementation must provide actual accessible date entry, not hard-code those examples. Preserve the date across wheel and typed entry modes, reject invalid/future dates, and evaluate the exact18th-birthday boundary using civil dates. The prompt identifies the provisional February29 policy for confirmation before production.

## Artwork and fonts

assets/birthday-housing.png is the original1254x1254 transparent generated artwork. The approved Figma delivery copy used crop(25,204,1214,1045), derived with alpha>120 to exclude faint margin artifacts, then proportionally resized and composited on RGB(5,6,6). The crop is recorded in LAYOUT_SPEC.json. Use the original artwork with this equivalent crop for correct alignment. Date labels, values, selected lane, buttons and state copy remain native UI.

reference/birthday-housing-delivery.jpg shows the exact optimized background used in the Figma composition. reference/birthday-review.png is the full three-state layout reference, not an app background image.

fonts/ includes the supplied Manrope static weights, original variable font, OFL.txt and FONT_SOURCE.json. Preserve the license and use the recorded PostScript names.

## Approval and verification boundaries

Birthday is self-declared information, not age or identity verification. No verification status, authentication success or backend entitlement follows from entering an adult date. Under-18 users cannot continue; corrections must be ordinary input editing, not bypass guidance. Never auto-advance. Back stays available.

The next Pass chapter remains a separate design proposal. Do not route into a legacy fake verification timer or implement the next chapter from this package.

SHA256SUMS.txt covers every other file in this ZIP. ART_PROMPT.json records provenance, not an instruction to regenerate the approved art.
