# Private invitations — approved 29 October 2026

The owner approved the four-screen concept and asked to build all four designs. This replaces the shared romantic ring metaphor with intent-specific private, one-to-one invitation artwork. It does not add group membership, invitation links, live delivery, accounts or chat.

| Intent | Native artwork | Outgoing headline | Purpose |
| --- | --- | --- | --- |
| Business | Two metallic-edged ivory cards, yellow detail | An idea worth sharing. | A private hello about ideas and opportunities. |
| Social | Two dimensional ivory speech bubbles, cyan edges | A little company. | A private hello for coffee and conversation. |
| Activity | Dark terrain, a green trail and two metallic markers | A plan to join. | A private hello for a walk, workout, or game. |
| Dating | Two metallic rings with pink inner reflections | A spark to explore. | A private hello to see if the interest is mutual. |

The native implementation uses Manrope, the existing intent colors, an ivory invitation card, a word-and-symbol intent badge, a colored primary action and the existing outlined Leave action. The compact venue context, DEMO badge and “Nothing is sent” disclosure remain. The recipient's choice is written below the outgoing card. The artwork is decorative, excluded from accessibility and hit testing, and never decides invitation state.

The approved illustration is a design direction, not a screenshot of the app. The implementation uses native scalable shapes and material gradients rather than baking text or controls into a bitmap. Business artwork uses neutral stationery marks; real participant names remain readable native text in the invitation.

## Four usable fictional examples

Common Ground now welcomes all four intents in its existing open demo snapshot. Social and Business retain Maya and Jules. Activity and Dating use Sam and Riley. Each room contains its own two-person fictional sample; another-intent sample cannot receive a Wave. Future venue sessions remain unavailable. No selected intent or approach changes implicitly.

The invitation still belongs to its current Room run, sender and recipient. Only an eligible incoming recipient can accept. Sending does not accept an outgoing invitation. Decline, withdrawal, blocking and leaving remain terminal; stale identifiers cannot reopen a closed invitation. Consent is never inferred from sharing an intent or from an animation.

## Accessibility and motion

Text scales and wraps in a vertically scrolling page. Actions retain minimum 44-point targets. Leave remains outside the scrolling content. Intent is expressed by a word and icon as well as color. Accept changes domain state immediately; normal motion brings paired objects together, Reduce Motion crossfades, and VoiceOver uses no animation. Activity's trail brightens on acceptance without moving its markers.

## Verification scope

New focused native scenarios cover all four outgoing compositions and withdrawal, incoming acceptance and decline, terminal Leave, and largest text with Reduce Motion on a smaller phone. The existing Wave tests retain their identities with explicit updates for superseded copy, artwork geometry and newly eligible intents. Pure Swift tests exercise the new sample pairs and consent/terminal-state guards.

Results are recorded in the appended implementation report and native receipts. These targeted scenarios do not substitute for the separately open full Main280/Small7, physical VoiceOver, hardware keyboard or end-to-end live-service verification.
