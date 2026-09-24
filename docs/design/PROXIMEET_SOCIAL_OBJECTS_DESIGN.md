# Proximeet — Social Objects

**Proposed visual direction · 24 September 2026**

**Review note:** the three concept boards are arranged as **1 / 5 / 6**, then **2 / 3 / 4**, then **7–10**. The companion Figma journey follows **1–10**. These are two presentation orders for the same sequence.

This direction supersedes the earlier restrained visual proposal. It preserves the existing welcome, date of birth, pass, guest list, band, and signal sequence, then extends its visual language into Places, the room, Waves, and conversation. It is a design proposal, not a record of approval for final visuals or changes to product rules.

## The direction

Proximeet should feel like receiving a beautifully designed invitation to participate in the place around you. Its distinctive identity is already present in the concepts: an access pass, a guest list, a fabric wristband, and an approach tag. **Social Objects turns those separate ideas into one coherent family of dimensional objects.**

The ambition is youthful, expressive, and visually rich. Large compositions, believable materials, deliberate lighting, and purposeful motion supply the spectacle. The artwork can be bold while the next action remains obvious.

The band represents the session’s intent; the tag communicates how the person wants to be approached. Both remain recognizable throughout the journey. Their shared clasp, offset notch, edge treatment, and material detail become a visual signature that is more memorable than another colored app background.

This is broader than nightlife. The welcome and venue artwork should include cafés, creative spaces, events, games, and activity settings. The scenes should feel inhabited and socially inviting without relying on identifiable people, a radar metaphor, or visual popularity rankings.

## What the deliverables demonstrate

The generated concept boards are **raster art direction**: they demonstrate composition, atmosphere, material ambition, and a proposed visual hierarchy. They do not demonstrate working controls, accurate live data, native accessibility, physical simulation, or device performance.

The separate [Figma file](https://www.figma.com/design/yUPcuFY2ZJpTqyPpu7blen) contains ten journey compositions with editable text, controls, vector objects and layouts. Its native material studies are simpler than the photoreal artwork. Use the PDF boards as the intended material-quality reference and the Figma study to examine the structure. These are complementary deliverables, not pixel-identical versions of a completed app.

The [click-through prototype](https://www.figma.com/proto/yUPcuFY2ZJpTqyPpu7blen?node-id=5-3&starting-point-node-id=5%3A3) adds navigation, band and tag choices, sample Wave/Keep states, and safety/exit destinations. After the entrance, it explicitly uses a fictional Social session; it does not implement the complete consent state machine. The ten main compositions and corrected guest-list, Wave and chat views were visually reviewed. B2 has a 0.45-second seating animation configured and checked by API readback; a playback video was not exported. The remaining choreography in this report is a specification for implementation.

Venue names, people, messages, attendance cues, and event details in this study are fictional examples. New copy is proposed and may differ from the current build. In particular, a demo pass must say **DEMO** and must not suggest that a real age or identity check succeeded.

## The ten scenes

| Scene | Visual composition and intended behavior |
|---|---|
| **1. Welcome — Split Worlds** | Keep the six social worlds. Replace flat symbol illustrations with bespoke miniature environments, each with convincing depth and a distinct source of light. Arrange them into the recognizable 2×3 composition around a clear central brand area. The sign-in action stays stable and legible while the environments establish possibility. |
| **2. Date of birth** | Place the date selection inside a sculpted graphite aperture. The selected date is crisp; adjacent values recede with restrained perspective. Use familiar native interaction and a straightforward eligibility explanation. Rich materials should never turn age eligibility into a game or obscure the selected value. |
| **3. The pass** | A substantial white pass turns toward the viewer above a dark stage. Its edge, cutout, small attachment, and sharply printed identity feel deliberately manufactured. A decisive stamp provides the signature moment. Prototype copy clearly describes a demo check, and the resulting mark remains DEMO. |
| **4. The guest list** | A precision aluminium clip holds bright roster stock. Strong typographic hierarchy and generous rows replace cramped receipt-like text. Editing opens a comfortable native sheet. On completion, the person’s actual entered name and interests settle into their row; fixture entries do not imply real attendees. |
| **5. Choose a band** | Four substantial woven bands occupy the screen directly. Each has a distinct textile structure, visible word, icon, and intent color. The clasp attaches convincingly to the fabric. Selecting a band gives that object emphasis without flooding the entire screen. The secured state uses a bespoke band composition rather than an enlarged, soft wrist photograph. |
| **6. Set a signal** | Four machined tags offer Come say hi, Chat first, With my crew, and Just looking. Labels and explanations remain readable interface text. The selected tag clips into the persistent band. A preview explains its consequence. Before check-in, the state is ready for check-in—not broadcasting or visible to other people. |
| **7. Places** | Venue artwork opens into an expansive cover with the same physical ticket edge used earlier. Give place identity, purpose, and check-in precedence. Use honest activity descriptions; show no exact low attendance, person distance, or people on maps. The selected venue ticket becomes the room’s identity after successful check-in. |
| **8. The room** | The venue cover compresses into the room header, with the person’s compact band and tag always reachable. A host note or icebreaker gives the gathering context. Participant cards are stable and readable. Preserve D57’s cross-intent visibility: other intents can be visible, but an incompatible card has no Wave action and clearly explains why. |
| **9. Wave and Handshake** | A Wave is a clear invitation with pending and withdrawal states. Motion should confirm the action without creating urgency. Only mutual acceptance earns the larger Handshake moment, in which two complementary object elements join. Declined, withdrawn, expired, and blocked states must remain equally coherent. |
| **10. Chat and Keep** | The joined object becomes a compact header detail above an excellent text conversation. The opening can be expressive; reading and composing remain steady. Leave, Block, and Report are accessible. Keep and Let it expire receive clear, balanced treatment. Persistence requires both people’s decisions; a single person’s choice must not imply a permanent connection. |

The existing intent-lock and approach-preference policies need explicit implementation semantics. A dramatic transition must never silently decide when a session starts, who becomes visible, or whether contact is allowed.

## Color, typography, and materials

These are exact working tokens for the design study. They are proposals, not a claim that every combination already passes contrast testing.

| Token | Value | Use |
|---|---|---|
| Carbon | `#080A0B` | Main stage |
| Graphite | `#171A1D` | Recessed interface surface |
| Alloy shadow | `#25292D` | Raised neutral surfaces and object shadows |
| Porcelain | `#F5F6F2` | Primary text and neutral action fill |
| Quiet text | `#AAB0B5` | Supporting text on dark surfaces |
| Social | `#35D7FF` | Social intent |
| Dating | `#FF56B8` | Dating intent |
| Business | `#FFD542` | Business intent |
| Activity | `#70F455` | Activity intent |
| Danger | `#FF6B7B` | Destructive and safety actions |

Use Carbon text on bright intent fills. Pair every intent with its word and icon. Color is semantic information, not background decoration. Text over reflective material needs a stable, contrast-tested region; moving highlights should not sweep through critical instructions.

The editable Figma study uses **Barlow Semi Condensed ExtraBold** for headlines and **Inter** for interface text; these rendered correctly in the design environment. For the native iOS implementation, evaluate SF Pro's condensed display treatment with SF Pro body text and SF Mono sparingly for pass identifiers. Preserve the intended proportions and compare actual renders before making that substitution. Avoid the current uniformly rounded treatment. Baseline roles: hero 38/40 pt, screen title 32/36 pt, section 20/25 pt, body 17/24 pt, supporting 15/21 pt, and button 17/22 pt. These are reference sizes, implemented with Dynamic Type scaling rather than locked geometry. Do not use miniature legal or explanatory text to rescue a composition.

Use a 4 pt spacing system, typically 24 pt side margins, 16 pt related-item spacing, and 32 pt between groups. Controls should provide at least a 44 pt target; primary actions normally occupy 56 pt height before text scaling. Large text may require taller controls and a single-column tag layout.

The material family contains dense woven fabric, bead-blasted aluminium, smoked translucent polymer, and thick bright pass stock. Use close detail where it matters: fabric edges, stitching, the attachment point, and contact shadows. Avoid generic glass panels, rainbow chrome across entire screens, and decorative orbital objects. A small local light spill can connect a colored band to its stage without compromising the interface.

## Motion score

Timing ranges below are proposed choreography targets. They are not measured results. Controls must respond immediately; decorative completion must not delay navigation or obscure the current state.

| Trigger | Standard motion | Target duration | Reduce Motion |
|---|---|---:|---|
| First welcome appearance | Six environments settle into the shared composition | 800–1,100 ms total | Immediate composition with 150–200 ms opacity reveal |
| Date adjustment | Native wheel movement with a concise selection response | Interactive; feedback within 120 ms | Native accessible picker; no added depth movement |
| Demo pass completion | Turn, stamp contact, short settle | 650–850 ms | Static DEMO mark with 150 ms crossfade and announcement |
| Guest entry saved | Insert row, align stock, seat clip | 450–650 ms | Row appears with 150 ms crossfade |
| Band screen entry | W3-inspired measured arrival | 600–850 ms | All bands appear together |
| Band confirmed | Lift, curve, close clasp, settle | 650–850 ms | Selected pose crossfade; identical confirmation state |
| Signal selected | T1-inspired lift, single arc, clip contact | 450–650 ms | Attached-tag state crossfade, without translation or rotation |
| Venue check-in completed | Ticket contracts into the room header | 450–650 ms | Header and room crossfade with unchanged focus order |
| Wave sent or withdrawn | Short material pulse, then stable status | 180–280 ms | Immediate status update with optional brief opacity change |
| Mutual Handshake | Complementary elements join, then resolve into chat | 700–950 ms | Joined emblem and clear acceptance announcement |
| Keep choice saved | Small seal/contact response | 180–260 ms | Immediate state change |

Animation should explain continuity: the same band survives B1, B2, and the room. Avoid replaying the entire entrance after a routine edit. Idle movement should be sparse, stop when offscreen, and never compete with reading. Haptics support a meaningful action; success haptics are reserved for the appropriate confirmed event.

## Native implementation path

Build the interface in SwiftUI using shared typography, surfaces, action controls, band states, tag states, and room cards. Use custom art assets for complicated material detail, then compose them with native layout, masks, modest transforms, and transition states. This direction does **not** require a general-purpose 3D engine or continuous physical simulation.

Use one bounded Metal effect: a subtle specular sweep restricted to the selected tag or clasp. It must not distort labels or become an always-running full-screen effect. SwiftUI animation handles the object’s translation, scale, and opacity. The iOS 17 baseline must retain the complete experience; where a newer system treatment is unavailable, use a static material asset and a simple native transition. The product’s meaning and available actions must remain identical.

Native navigation and sheets should remain recognizable. System materials may be used where appropriate, but they should not replace the bespoke object identity. The design should still work with Reduce Transparency, Increase Contrast, VoiceOver, and large text.

The relevant official implementation references are Apple’s [WWDC 2026 session 322](https://developer.apple.com/videos/play/wwdc2026/322/), [WWDC 2023 session 10157](https://developer.apple.com/videos/play/wwdc2023/10157/), and [WWDC 2025 session 219](https://developer.apple.com/videos/play/wwdc2025/219/). [Figma Motion](https://www.figma.com/blog/introducing-figma-motion/) provides a reference for communicating choreography in the design file. The public [Partiful flow on Mobbin](https://mobbin.com/explore/flows/33876a8f-23bc-4dba-be26-245021ae7877) is a social-event reference, not evidence of access to private Mobbin content or a template to copy.

## Remaining delivery gates

Before visual implementation is accepted, create a consistent asset family at sufficient native resolution: six welcome environments, pass layers, roster/clip layers, four bands, clasps, and four tags. Record provenance and usage rights, provide transparent edges where needed, and check that the objects share camera angle, light direction, scale, and texture quality. Do not enlarge the existing low-resolution wrist crop into a production hero.

Verify real entered profile data in previews, honest demo labels, check-in visibility boundaries, cross-intent disabled actions, signal changes, and all pending/withdrawn/blocked states. Review normal and large text, small phones, VoiceOver order and announcements, contrast during animation, and reduced-motion parity.

Measure frame pacing, memory, scrolling, keyboard interaction, and thermal behavior on real supported devices. A simulator recording or attractive exported reel cannot establish native smoothness. Report the exact commit and device for performance evidence. Figma transitions communicate intent; they are not proof that SwiftUI matches it.

## First visual implementation slice

Start with **B1 and B2 together**: band selection, secured band, tag selection, attached-tag confirmation, and the real-data preview. This pair proves the entire object language, shared geometry, semantic color, native typography, motion, and accessibility behavior in a compact scope.

Deliver one normal-motion capture, one Reduce Motion capture, large-text screenshots, and device measurements alongside the exact code revision. Then propagate the verified materials and components backward into the pass, guest list, birthday, and welcome, and forward into Places, the room, Wave, and chat. Final visual approval should be based on that complete, usable slice rather than a render alone.
