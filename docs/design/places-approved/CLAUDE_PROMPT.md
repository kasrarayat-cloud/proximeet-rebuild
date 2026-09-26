# Proximeet — approved Places implementation prompt

Paste into Claude Code with `PROXIMEET_PLACES_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Chapter 7: Places only**, as a native SwiftUI prototype matching the seven approved discovery, venue-detail and check-in-explanation screens. The founder approved them with **“thats perfect i approve”** on 24 September 2026 at 21:05 PDT / 25 September 2026 UTC. This approval covers fictional venue browsing and an explanation-only check-in screen. It does not authorize a functioning check-in, presence session or Room. Report your actual model/effort only if visible; do not invent it.

## Confirm dependencies and repository

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, native architecture and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **Welcome, Birthday, Pass, Guest List, Wristband and Signal** are genuinely implemented in the intended SwiftUI branch. Birthday needs real date entry and its gate; Pass needs explicit demo controls without timer-based verification success; Guest List needs real text entry and preserved draft; Wristband needs an initially empty typed single-choice intent; Signal needs the actual carried intent, no initial approach default, two genuine choices and preservation when the band changes. Design files, legacy onboarding and static fixtures do not establish these dependencies. If any chapter is missing, report it and ask the founder to run that approved handoff first. Do not silently implement multiple chapters, replace frameworks or regenerate approved designs.

Preserve work in an isolated new branch/worktree based on a reported local commit containing those dependencies. Preserve dirty changes and report any reliance on uncommitted work before proceeding. Report an unexpected repository or native architecture as a blocker. Limit edits to Places and minimal approved Signal navigation/draft integration. No deletion/reset, push, merge, CI/Codemagic dispatch, Apple setup, signing, build upload, deployment, TestFlight or paid service invocation. Use only already available local build/simulator tools; do not launch a cloud build.

## Read the approved package

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF?node-id=60-455

| State | Node |
| --- | --- |
| Now / Common Ground | `58:480` |
| Later / Afterglow | `58:481` |
| Upcoming / Fieldwork | `58:482` |
| Common Ground / Afterglow / Fieldwork detail | `58:483` / `58:484` / `58:485` |
| Common Ground check-in explanation | `58:486` |

Page `58:479`; review `60:455`; approval annotation `64:566`. Read `README.md`, `DESIGN_NOTES.md`, `LAYOUT_SPEC.json`, `reference/places-review.png`, `ART_PROMPTS.json` and `SHA256SUMS.txt`. The specification records all seven complete native node trees, resolved component-instance styles, text, geometry, ticket radii, icons, image bindings and reactions. Match the 440 × 956 reference, adapting for actual safe areas, orientation and Dynamic Type. Root x/y locate Figma frames on the canvas; they are not app margins.

The unchanged historical board may still say awaiting approval; this dated approval supersedes that outer caption. The approved design uses a clearly documented Social / Chat first fixture. Preserve its visual language while deriving actual user state; never copy Social into the live draft or treat the Figma Signal return copy as app state.

## Use three fixed fictional venue fixtures

This is a **fixed fictional Thursday, 8 PM snapshot**, with no relationship to the device clock, calendar date, timezone or actual availability. Do not use Date.now, timers, background refresh or remote data to open a session. “Today” and “Tonight” refer only to the displayed demo snapshot. Keep **“Fictional venues · demo Thursday, 8 pm”** and **“DEMO”** visible as specified.

| Category | Venue | Schedule | Permitted intents | Availability in this snapshot |
| --- | --- | --- | --- | --- |
| Now | Common Ground | Today · 6–10 pm | Social, Business | Open |
| Later | Afterglow | Tonight · 9–11 pm | Social, Dating | Future; disabled |
| Upcoming | Fieldwork | Saturday · 10 am–1 pm | Activity, Business | Future; disabled |

All names, hosts, descriptions, scenes and schedules are fictional. Retain exact native host/brief/rule copy in the specification. Do not fetch venues, infer a city from the device, add addresses or distances, create reservations or show live attendance. The venue ticket is a metaphor, not admission or booking evidence.

Implement Now/Later/Upcoming as genuine category state. Each tab filters this fixed catalog to its corresponding venue; switching replaces the ticket, name, modes and schedule coherently. The selected tab has a native selected-state cue; tapping it again is a no-op. All three categories and venue details remain browsable regardless of intent compatibility. Do not hide incompatible sessions or silently switch the user's band. No app-wide bottom navigation, map, empty-state catalog expansion or extra destinations are part of this handoff.

## Derive eligibility from actual intent and static availability

Read the existing typed intent and approach from the same preserved onboarding draft. Do not default to Social/Chat first or overwrite either value with a venue's modes. If a required prior choice is absent, return to its approved choice screen rather than inventing a value.

Derive **canPreviewCheckIn = venue is open in the fixed snapshot AND venue permits the actual intent**. This permits the explainer only for Social or Business at Common Ground. It never permits a preview for Dating/Activity at Common Ground, for any intent at Afterglow, or for any intent at Fieldwork in this snapshot.

Use the existing ticket/helper/button layout for all four intents, without a visual redesign:

- If the intent does not match, show **“Your [Intent] band doesn’t match this session.”** in the existing browse/detail boundary position and disable the detail primary with **“Not available for [Intent]”**. Keep the venue's schedule visible. Mismatch takes precedence over the future-session button label, matching the approved Social/Fieldwork example.
- For a matching browse fixture, retain **“Your profile stays private until check-in.”** For a matching detail, retain **“Sample session · not a reservation”**.
- For a matching open Common Ground session, enable **“Preview check-in”**. For matching future Afterglow, disable **“Opens at 9 pm”**. For matching future Fieldwork, disable **“Opens Saturday”**, the fixture's existing authored availability label. No actual clock unlocks either action.

Disabled controls must truly prevent navigation and have discoverable reasons through nearby text/accessibility descriptions. Do not make a disabled tap the only way to learn why it is unavailable. Guard the destination as well as the button so a stale route cannot bypass intent/availability requirements. Changing a band through earlier screens recomputes eligibility from the new intent while retaining approach. Neither intent nor approach is a consent grant.

## Navigation and explanation-only endpoint

Replace Signal's temporary end-of-preview action with Places browsing. First entry opens **Now**. Retain the selected Places category in memory during this prototype session, including when going back to actual Signal and returning. Preserve the entire existing onboarding draft. The static Social / Chat first Signal clone in Figma is a review fixture, not an additional native screen.

Wire each actual active control:

- Browse header Back and bottom Back return to actual Signal with intent and approach intact.
- A venue ticket's **“View place →”** opens that venue's detail. The whole ticket may share this action as one accessible control; avoid duplicate or nested buttons announcing the same action twice.
- Detail header Back and **“Back to places”** return to the originating category and selected ticket. Do not reset Later or Upcoming to Now.
- Eligible **“Preview check-in”** opens only the Common Ground explanation.
- Explainer header Back and **“Back to place”** return to Common Ground detail. **“Explore other places”** explicitly returns to Now browsing.

The check-in screen retains **“Arrive.\nThen connect.”**, **“A place opens when you’re really there.”**, Common Ground's fictional context, the two explanatory steps, **“You stay private until both checks pass.”** and **“Demo · no location or camera used.”** These explain a future product flow; neither check runs in this prototype.

Do not request permissions, access foreground/background location, start a camera, create a scanner, generate a real or mock scannable credential, run a verification timer, show pass/fail/success, mark attendance, create a temporary presence session or enter a Room. The QR artwork is only the supplied explanatory icon. The camera wording describes scanning and must not claim an OS permission is automatically revoked afterward. Do not add a “simulate success”, “enter room” or bypass button.

Browsing, viewing a detail and reading this explainer never make anyone visible. No participant avatars/counts, people maps, radar, distances, matches, Wave, chat or Keep are included. Later participant visibility requires a valid venue session, and later chat still requires a deliberate Wave and acceptance. A future approved Room handoff must establish its own explicitly bounded entry contract; this package grants none.

Keep the draft and browsing state in memory only. No server, disk, analytics, logs, backups, account writes, live venue inventory, networking, real sign-in, verification SDK, Bluetooth/NFC, wearable features or notifications. Do not set verification, entitlement, check-in, membership, presence or discoverability flags. Repeated taps must not duplicate routes.

## Assets, motion and accessibility

Use the three original 1254 × 1254 RGBA scenes: `assets/common-ground.png`, `assets/afterglow.png` and `assets/fieldwork.png`. Apply their exact individual crops from `ART_PROMPTS.json`/`LAYOUT_SPEC.json`; preserve alpha and FIT aspect ratios. Compare framing against the three `reference/*-delivery.png` indexed transparent copies. These miniature architectural illustrations are raster decoration, not supplied 3D models, room scans or real photographs. Do not regenerate them, stretch them, replace them with stock art or use whole-screen screenshots as UI.

Keep names, schedules, host copy, rules, modes, tabs, ticket geometry and actions native. Preserve the corrected ivory mode-chip labels on dark chip fills. Native vector paths and resolved component styles are in the specification. Bundle the supplied Manrope static fonts and preserve `fonts/OFL.txt` and provenance.

Reproduce **240 ms ease-out dissolves** for category changes and return navigation, and a bounded **500 ms two-dimensional ticket expansion** from browse to detail. Move native ticket content with its artwork so their registration stays coherent. Figma calls the latter Smart Animate; it is not a physical 3D building unfolding. There is no supplied rig or implemented ticket-to-Room transition. Do not add a motion library, looping animation, auto-navigation or a device frame-rate claim.

Reduce Motion uses an instant change or a simple crossfade without expansion. Model state and actions remain immediate; rapid category changes or Back interrupt/reconcile decorative motion rather than waiting for completion. Preserve the final requested category/detail consistently.

Use native tab/button semantics, logical VoiceOver order and clear selected/disabled descriptions. Hide decorative scene art when venue names/descriptions already convey its meaning. Preserve at least 44-point targets and readable text beyond color alone. Reference content is 376 points wide; primary actions are 60 points high. Allow longer intent-specific helpers, descriptions and larger Dynamic Type to wrap and expand with scrollable content and safe-area controls instead of clipping, shrinking text or overlapping the ticket art. Keep all controls reachable on smaller screens and in landscape.

Run meaningful available checks for three category filters, the full four-intent × three-venue eligibility matrix, matching/mismatch copy, disabled future actions, correct venue/detail mapping, both Back paths, re-entry category/draft preservation, band-change recomputation, explainer exits, duplicate taps and interrupted motion. Confirm no route or action mutates consent/verification/presence flags or triggers permission/network calls. The static snapshot must behave identically across device times and timezones. Use fictional fixtures only. Run available local native compilation and an already accessible simulator/device; do not dispatch cloud builds. Report macOS compilation, iOS runtime, VoiceOver, Dynamic Type, Reduce Motion and motion/device checks as **not run** when unavailable. Source inspection and screenshots are not runtime verification.

Return branch/worktree/base commit, dependency evidence, changed files, actual filtering/eligibility/navigation behavior, asset/font mapping, executed checks/results, unavailable checks, reproducible preview steps and deviations. Stop after this bounded Places prototype.
