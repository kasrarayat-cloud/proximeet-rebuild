# Proximeet — Pass chapter review

Status: Pass visual design and its explicit user-controlled demo were approved by the founder on 25 September 2026: “i approve thsi as well”. Welcome and Birthday directions are also approved and preserved. This approval covers the three-state prototype design; it does not establish real verification, an implemented app, or approval of Guest List.

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=29-154

## Explicit demo boundary

This chapter previews the age-check experience. No age or identity verification is performed. Every state has a persistent DEMO badge, native DEMO PASS label and visible no-verification copy. The 18+ graphic is an age-category graphic, not a verified badge, admission decision or valid pass. No automatic success timer, verified state, access-granted copy, confetti or provider claim exists.

The ivory card, brushed steel clip and cyan textile loop are decoration-only artwork. All words, labels and controls are native editable Figma elements. The artwork is a concept visual, not a production 3D model or rig.

## Review states and native interactions

| State | Frame | Primary action | Exit |
|---|---|---|---|
| Intro | 27:111 | Try the demo → 27:112 | Leave demo → Birthday reference |
| User-controlled progress | 27:112 | Finish preview → 27:113 | Cancel → Intro |
| Demo complete | 27:113 | Continue preview — destination pending | Leave demo → Birthday reference |

Back on every state returns to the unchanged approved Birthday reference, frame 30:189. Its Continue returns to the demo intro. Figma requires navigation targets on the same page, so this approved copy is a prototype return reference; the original Birthday screens remain untouched.

Every transition requires a click. Start and finish use a 220 ms transition with a subtle 6 px pass lift/settle. Cancel and exits use a 180 ms dissolve. No timer or automatic advancement is configured. Reduced-motion intent is to keep the pass stationary and change states instantly or with a brief dissolve.

“Continue preview” is deliberately unwired in the approved Figma review. Guest List is outside this approval and remains a separate design chapter. The bounded implementation handoff may respond with a minimal native review-end message while keeping the Demo complete state; it must not invent a next chapter or grant access.

## Future real verification

No verification provider has been selected, and no real integration is implemented. A future real verification flow must use a validated server-side provider callback to update real verification status. A demo action, delay, local timer or birthday entry must not produce a real verification result. This approved demo makes no vendor, document-handling, biometric, retention or privacy claim.

## Figma map

- Pass page: 26:282
- Review board: 29:154
- Shared pass artwork and native type: 28:118
- Shared DEMO header: 28:111
- Native start action: 28:143
- Native finish action: 28:164
- Native Cancel action: 28:166
- Native forward placeholder: 28:185
- Birthday approval note: 26:279
- Pass approval note: 33:217 (25 September 2026)

440 × 956 logical design frame. Manrope typography follows the approved chapters. Primary action remains fixed at y=812 with a 60 px target; Back and secondary exits have 44 px targets. Body copy is 16 px.

## Implementation handoff

Use `PROXIMEET_PASS_APPROVED_HANDOFF.zip` and its `CLAUDE_PROMPT.md` only after the approved Welcome and Birthday chapters are actually implemented. The package is design and implementation guidance, not app code. It contains the original decoration, exact delivery reference, native-layout specification, licensed fonts, and a checksum manifest. No app code, remote build, signing configuration or deployment was changed to prepare this handoff.
