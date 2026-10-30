# Private invitation redesign — 30 October 2026

The owner reviewed build 0.1.0 (10) and reported that the artwork did not match the concept and showed no visible motion. The revised four-screen board and separate interactive motion study were presented; the owner then authorized implementation, verification and the next internal TestFlight delivery without further approval requests.

The board is the visual target. The browser motion study used simplified materials to demonstrate timing; it is not a native screenshot or the final material reference.

| Intent | Sculpture | Accent | Outgoing headline |
| --- | --- | --- | --- |
| Business | Two thick, beveled ivory and chrome cards with the actual participants' names | Yellow | An idea worth sharing. |
| Social | Two substantial ivory conversation bubbles, metallic edges and a clear gap | Cyan | Good company starts here. |
| Activity | A smooth raised S-shaped dark trail, luminous edge and two separate pearl-metal tokens | Lime | Make a plan. Move together. |
| Dating | Two solid curved rose and silver petals facing inward, separated by a gap | Rose | A little chemistry. |

Dating has no rings or closed loops. Activity has no jagged mountain terrain or map pins. Materials must show dimensional surfaces, bevels, highlights and changing reflections in the actual app. A static screenshot alone cannot establish motion.

## Motion and state

The scene moves gently when it first becomes visible, before any action: floating/turning sculptural objects and changing highlights, with Activity tokens moving in their own bounded sections of the trail. Sending does not produce a response or acceptance animation. Waiting must not imply typing or a real recipient's activity.

The accepted pose follows the existing incoming Accept action; it never causes or delays the state change. Leave and Block remove the counterpart and scene immediately. The menu stationery carries no names, including after Block. Motion pauses behind an overlay, outside the visible area or while the app is inactive. Reduced Motion and VoiceOver use static scene poses; existing accessible text carries the full invitation meaning. The artwork has no accessible children or controls.

## Layout and retained meaning

Keep the black ground, compact intent badge, sculptural hero, ivory invitation card, clear recipient-choice text, colored primary button and persistent Leave. The default card title uses scalable 24/32 typography; longer words wrap naturally on smaller screens and at larger text sizes. Do not force text to fit with truncation or a non-scaling font.

The actual sender/recipient direction, fictional venue/session, viewer's own preference, counterpart's preference, DEMO badge and contextual disclosure remain. These additional existing details mean the production screen is not a literal reproduction of the compact concept's metadata. All information and actions must remain reachable by scrolling; the fixed Leave action stays immediately available.

The product remains a fictional local demo. This redesign adds no real invitation delivery, notifications, chat, tracking, account access or group membership.

## Verification and delivery

Review actual native renders for all four silhouettes and materials, including smaller-screen Social and Activity. Compare rendered frames before Accept to demonstrate motion and verify static Reduced Motion poses. Run the four-intent outgoing, incoming/decline/leave and largest-text tests, plus the existing Room-to-Wave journey and adapted accepted-pose motion check. Preserve test allowances and prior failed evidence.

Bind the published source to the verified native files, then archive and upload the app and matching symbols to the already-authorized private repository and internal TestFlight destination. Report actual build number and upload result separately from Apple processing or tester availability. Historical aggregate and physical-device gates are not satisfied by these targeted feature tests.
