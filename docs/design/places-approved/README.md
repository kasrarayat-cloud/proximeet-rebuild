# Proximeet — approved Places handoff

The founder approved Chapter 7 with “thats perfect i approve” on 24 September 2026 at 21:05 PDT / 25 September 2026 UTC. This package covers seven fictional venue-discovery, detail and explanation-only check-in screens. It does not provide a functioning check-in or Room entry.

## Use with Claude

1. Implement and review the approved Welcome, Birthday, explicit Pass demo, Guest List, Wristband and Signal chapters first. This handoff assumes those native SwiftUI dependencies genuinely exist.
2. Extract this ZIP into a task folder Claude can read.
3. Paste `CLAUDE_PROMPT.md` into Claude Code and provide the folder's absolute path.
4. Return Claude's full report for review. This prompt covers Places and minimal approved Signal navigation/draft integration only.

No app code, repository, build, signing, deployment or TestFlight was changed to prepare this package. No automatic app coding agent was invoked.

## Approved references

https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=60-455

Page: 58:479. Review: 60:455. Approval note outside the app frames: 64:566.

| State | Frame |
| --- | --- |
| Now / Common Ground | 58:480 |
| Later / Afterglow | 58:481 |
| Upcoming / Fieldwork | 58:482 |
| Common Ground detail | 58:483 |
| Afterglow detail | 58:484 |
| Fieldwork detail | 58:485 |
| Common Ground check-in explanation | 58:486 |

`LAYOUT_SPEC.json` measures all 387 native nodes, including complete component-instance trees, resolved text/paint/layout styles, vector paths, ticket geometry and reactions. Root x/y are Figma canvas positions; descendants are parent-relative. Reference screens are 440 × 956 logical units and must adapt for actual safe areas, orientation and Dynamic Type.

The unchanged `reference/places-review.png` is the historical approval board. It shows Now browsing, Common Ground detail, the check-in explanation and the other two venue scenes. Outer awaiting-approval captions are superseded by the dated approval above and are not app copy. Its Social / Chat first example must not become a native default.

## Fixed snapshot and actual draft

The entire catalog is a fictional Thursday at 8 PM. There is no device-clock or timezone dependency, timer, live availability, network inventory or location lookup. All venue names, hosts, scenes and schedules are fictional. “Today” and “Tonight” refer to the visible sample snapshot.

| Category | Venue | Schedule | Permitted intents | Snapshot availability |
| --- | --- | --- | --- | --- |
| Now | Common Ground | Today · 6–10 pm | Social, Business | Open |
| Later | Afterglow | Tonight · 9–11 pm | Social, Dating | Future |
| Upcoming | Fieldwork | Saturday · 10 am–1 pm | Activity, Business | Future |

Each category genuinely filters this fixed catalog to its venue. All categories/details stay browsable even when incompatible with the actual carried intent. Retain the existing intent and approach; no fallback Social/Chat first and no automatic mode changes.

Check-in-preview eligibility requires both an open snapshot session and a matching actual intent. Thus only Social or Business at Common Ground can open the explanation. All other combinations have disabled detail primaries. Mismatch uses “Your [Intent] band doesn’t match this session.” and “Not available for [Intent]” in the approved helper/button positions. Matching future sessions use “Opens at 9 pm” or “Opens Saturday”, remaining disabled. See the specification's complete twelve-combination matrix and prompt for label precedence.

## Navigation and endpoint

Signal's prior endpoint now opens Places, initially Now. Retain category and the onboarding draft in memory across Back to actual Signal and re-entry. A venue ticket/View place action opens its matching detail; both detail Back controls return to its originating category. Do not duplicate the static Figma Signal return fixture in the app.

Eligible Preview check-in opens only the explanation. Its header Back and Back to place return to Common Ground detail. Explore other places returns explicitly to Now browsing. No action requests permissions, starts location/camera/scanning, generates a credential, runs verification, displays success, sets presence or enters a Room.

Keep DEMO and all native privacy/demo copy. The explanation describes a future location check and venue QR; it does not perform them or claim that OS permission is automatically revoked after scanning. No people, avatars, counts, maps, real addresses, distances, booking, app-wide navigation or later social features are part of this bounded package. Drafts and browsing state remain only in memory, without logs, analytics, disk, server or account writes.

## Artwork and fonts

| Scene | Original | Crop, XYXY | Figma delivery reference |
| --- | --- | --- | --- |
| Common Ground | assets/common-ground.png | [46,83,1211,1218] | reference/common-ground-delivery.png |
| Afterglow | assets/afterglow.png | [5,105,1249,1186] | reference/afterglow-delivery.png |
| Fieldwork | assets/fieldwork.png | [8,39,1247,1163] | reference/fieldwork-delivery.png |

All originals are 1254 × 1254 RGBA. Delivery PNGs are indexed transparent transfer references; preserve original alpha for native implementation. Apply each exact crop then FIT without stretching. The shared scene slot is 344 × 248, inside native ticket components. The detailed miniature architecture is raster decoration, not supplied 3D geometry, a room scan or a real venue photograph. Do not regenerate it or use a screenshot as UI.

All labels, schedules, permitted-mode chips, rules, tabs, buttons, icons and ticket surfaces remain native. Preserve ivory chip labels on dark chip fills. `ART_PROMPTS.json` records source provenance and approval; it is not a regeneration request. `fonts/` contains licensed Manrope static weights, original variable font, source metadata and OFL license.

## Motion and verification scope

Use 240 ms ease-out dissolves for category changes/Back and a bounded 500 ms two-dimensional ticket expansion for browse-to-detail. Keep art and native ticket content registered together. Reduce Motion removes expansion in favor of an instant change or simple crossfade. Transitions must remain interruptible and never delay model changes or actions.

These Figma transitions do not prove 3D unfolding, native performance or device behavior. No ticket-to-Room motion is supplied. See `CLAUDE_PROMPT.md` for meaningful state/navigation/eligibility checks, accessibility requirements and honest reporting when native verification cannot run.

`SHA256SUMS.txt` covers every other file in this ZIP and excludes itself.
