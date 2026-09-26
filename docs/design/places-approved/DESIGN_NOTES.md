# Proximeet — Places chapter review

Status: Chapter 7 Places was approved by the founder with “thats perfect i approve” on 24 September 2026 at 21:05 PDT / 25 September 2026 UTC. Chapters 1–6, through Signal, are also approved. This approval covers seven app states, fictional fixed-snapshot discovery and an explanation-only check-in screen. The approved Places Claude handoff is prepared; no app code was implemented and no build was run.

Figma review: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=60-455

Now entry: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=58-480

## Direction

Places is the first venue discovery chapter. A miniature architectural scene rises above an ivory venue ticket. Warm plaster, walnut, upholstered seating and studio materials extend the approved Social Objects language into spaces people might choose to visit. The same near-black stage and Manrope typography connect the chapter to onboarding.

The illustration invites exploration; native text carries the schedule, venue name, permitted intents, host context and actions. The ticket is a visual metaphor, not a booking, admission pass or reservation. There is no live venue inventory in this prototype.

## Fictional demo fixtures

All three venue names, hosts, scenes, rules and schedules are fictional examples. The schedule is a consistent sample snapshot at Thursday 8 PM, not the user's clock or live availability. Los Angeles, if shown, is an example city rather than an inferred device location.

| Tab | Venue | Session | Permitted intents | Character |
|---|---|---|---|---|
| Now | Common Ground | 6–10 PM | Social, Business | An intimate neighborhood café |
| Later | Afterglow | 9–11 PM | Social, Dating | A quiet vinyl listening lounge |
| Upcoming | Fieldwork | Saturday, 10 AM–1 PM | Activity, Business | A shared ceramics and creative studio |

The review uses a clearly documented Social / Chat first example carried from Signal. The bounded native handoff retains the user's actual intent and approach preference. A venue's permitted modes never overwrite that intent. For example, the Social fixture does not match Fieldwork's Activity / Business session; the UI explains that mismatch without silently selecting another band. Native check-in-preview eligibility must require both a matching actual intent and an open session in the fixed fictional snapshot. Only Social or Business at Common Ground can open this chapter's explanation; all Later/Upcoming check-in-preview actions remain disabled for every intent.

## Scope and flow

Seven approved screens cover Now, Later and Upcoming discovery, one detail per venue, and the Now venue's check-in explainer. Each browse tab has an explicit View place action. Details expose the same session and modes, host context and concise venue rules. Back returns to the originating browse category. First native entry from Signal opens Now; returning from actual Signal preserves the selected Places category and onboarding draft within the session.

The Now detail can open a check-in explanation. Later and Upcoming clearly display their future schedules and cannot claim an open session or issue a check-in. There are no crowd counts, participant avatars, people maps, live radar, individual distances or presence dots. Browsing never makes the user visible.

The check-in screen explains the intended sequence: a one-time foreground location check at the venue and a rotating QR supplied by that venue. It does not ask for system permissions, access location/camera, create a real or mock scannable credential, run a timer, show successful verification or enter a room. It remains explicitly a demo. Actual verification, permissions, errors, anti-spoofing and a temporary presence session belong to a later implemented check-in flow.

Its primary action is “Explore other places”, returning to the Now browse screen. “Back to place” returns to the Common Ground detail. This gives the bounded preview a working exit without implying successful entry. The camera explanation describes scanning; it must not imply that an operating-system permission is automatically revoked after the scan.

Participant visibility requires a valid venue session. Chat still requires a deliberate Wave and acceptance; approach preference is not blanket consent. The venue ticket becoming a Room header remains a later transition after check-in, not evidence that entering a venue detail has checked someone in.

No app-wide bottom navigation is introduced in this bounded design slice. The founder blueprint's Places, Room, Connections, Messages and You destinations remain the larger information architecture; adding unexplored destinations here would be outside this chapter's review.

The blueprint also includes a venue-only map. This review focuses on discovery tickets, venue details and the check-in explanation; it does not fabricate a geographic map or real addresses for these fictional venues. Map design remains part of the broader Places scope.

## Artwork

The three scene originals are 1254 × 1254 RGBA generated with the built-in image tool. They contain no people or UI text. `PROXIMEET_PLACES_ART_PROMPTS.json` records the full prompts, original paths, crop rectangles and optimized transparent delivery copies. The original alpha PNGs are the future native source; the smaller indexed PNGs are Figma transfer references.

These are detailed raster illustrations of miniature architecture. They are not interactive 3D models, room scans, real venue photographs or supplied geometry. All names, schedule labels, mode chips, rules and controls remain native editable Figma elements.

## Motion and accessibility

Authored transitions are 240 ms ease-out dissolves for schedule changes and navigation back, and a 500 ms Smart Animate ticket expansion from browsing into venue detail. These are two-dimensional Figma transitions between raster art and native ticket layouts, not a 3D model unfolding. The proposed later ticket-to-Room transition from the Social Objects source is not implemented here. Motion must be interruptible; Reduce Motion should use an instant state change or a simple crossfade. Transition authoring and resting layouts were inspected; no motion video, native build or iPhone performance measurement is claimed.

Keep meaningful text readable, interactive targets at least 44 points, controls labeled beyond color alone, and selection visible. Native implementation must adapt to Dynamic Type, safe areas and smaller screens. Decorative scenes should be hidden from VoiceOver when the native venue name and description already communicate their meaning. Fixed Figma layouts are references, not accessibility or device-performance test results.

## Source grounding

- *Proximeet Founder Operating Blueprint*, pages 9–11: place before person; venue cards with schedule, permitted modes and host context; Now/Later/Upcoming; no map of people; foreground venue check followed by rotating QR; temporary presence; privacy-preserving threshold before seeing participants.
- *Proximeet Social Objects Showcase*, pages 5–6: a venue ticket becomes a room header after check-in; no live visibility before check-in; proposed ticket/header choreography.
- Current founder-approved Welcome, Birthday, Pass, Guest List, Wristband and Signal designs establish the material, type and motion language used in this review.

## Review record

Review board 60:455 on page 58:479 is 1480 × 1670. The final image is `PROXIMEET_PLACES_REVIEW.png`. It displays Now discovery, Common Ground detail and the check-in explanation, followed by the Later and Upcoming venue scenes. All seven full frames exist on the page.

| State | Figma frame |
|---|---|
| Now / Common Ground | 58:480 |
| Later / Afterglow | 58:481 |
| Upcoming / Fieldwork | 58:482 |
| Common Ground detail | 58:483 |
| Afterglow detail | 58:484 |
| Fieldwork detail | 58:485 |
| Common Ground check-in explanation | 58:486 |

The native ticket component set is 59:443, with three venues × two layouts. Tabs are reusable native components. All screen typography is Manrope. The shared 440 × 956 frame, 376-wide content, 44-point navigation targets and 60-point primary actions follow the approved chapters. Scene art uses FIT image fills and remains separate from names, mode chips, schedule labels and other readable content.

Browse Back returns to an unchanged Social / Chat first Signal copy, 59:117, on the Places page. That copy's Continue opens Now. It is a static review fixture; its other controls are inert and it does not establish a native state-persistence contract. Original approved Signal frames remain unchanged.

Visual inspection caught dark mode-chip labels on dark chip fills in the first export. The labels were changed to ivory and inspected again. Root and independent review found the corrected composition readable with no missing art, clipped text or overlapping controls. The Afterglow board caption says “Later session · starts at 9 pm” rather than claiming that this fixed preview will unlock itself at a real time.

The approved bounded package is PROXIMEET_PLACES_APPROVED_HANDOFF.zip, with PROXIMEET_PLACES_CLAUDE_PROMPT.md and PLACES_LAYOUT_SPEC.json. It requires the first six approved chapters to be genuinely implemented. Its only earlier destination change replaces Signal's temporary endpoint with Places. Mismatch/future-state labels are derived from actual intent and static availability within the existing approved layout; no band or approach is overwritten.

Founder approval annotation 64:566 sits outside the app frames on page 58:479. The historical review PNG and outer Figma captions retain their original review status; this dated approval supersedes those captions. The original seven app frames and review PNG are unchanged. Room and a functioning check-in require separate approved handoffs and are not included here.
