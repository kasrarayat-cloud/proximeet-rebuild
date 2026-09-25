# Proximeet — approved Birthday implementation prompt

Paste into Claude Code with `PROXIMEET_BIRTHDAY_APPROVED_HANDOFF.zip` attached or extracted.

---

Implement **Birthday only** as a native SwiftUI prototype matching the approved design. The founder approved it on 24 September 2026: **“approve lets go next perfect”**. The accompanying Birthday notes record this approval. Report your actual model/effort only if visible; do not invent it.

## Check the dependency first

Historical repository: `/home/proximeet/proximeet-cloud`; origin `https://github.com/kasrarayat-cloud/proximeet-rebuild.git`; branch `redesign/social-objects`. Inspect actual repository instructions, origin, branch, HEAD, changes, architecture, and navigation without exposing secrets. These pointers do not establish current state.

Confirm the approved **A Place Opens Welcome** has actually been implemented in the intended branch, with the approved assets and native controls. A design file or an old Welcome screen is insufficient. If missing, report the dependency and instruct the founder to run `PROXIMEET_WELCOME_CLAUDE_PROMPT.md` / the Welcome bundle's `CLAUDE_PROMPT.md` first. **Do not silently implement both chapters.**

If the repository is mismatched or is not the expected native SwiftUI app, report the blocker; do not migrate to Flutter. Preserve existing work in an isolated new branch/worktree based on a reported local commit containing approved Welcome. Preserve dirty changes; report any dependency on uncommitted work before proceeding. Limit edits to Birthday and minimal existing navigation integration. No destructive reset/deletion, push, merge, CI/Codemagic, signing, Apple setup, deployment, or TestFlight.

## Use the approved source

Figma: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF

| Reference | Node |
| --- | --- |
| Birthday page | `16:114` |
| Empty / adult / under-18 | `19:111` / `19:112` / `19:113` |
| Review board / date console | `23:195` / `21:193` |

Read bundle `README.md`, `LAYOUT_SPEC.json`, `reference/birthday-review.png`, `ART_PROMPT.json`, and `SHA256SUMS.txt`. Use `assets/birthday-housing.png`, originating from `exec-6c365340-f3df-49db-b2be-879ff539ae97.png`, and supplied licensed Manrope fonts in `fonts/`. Preserve licenses. Inspect Figma if available; do not require Figma MCP. If exact assets/references are unavailable, request the bundle rather than substituting artwork.

The 440 × 956 design uses generated **decoration behind native controls**. Reproduce its housing placement, type, colors, spacing, and state copy. Never bake the screen or date values into an image, redraw the housing procedurally, or substitute Inter. Figma's three sample dates and 180 ms dissolve demonstrate states; they are not a real picker or user data.

Use the approved headline “First, your birthday.” and explanation “Proximeet is for adults 18 and over.” State guidance is “Select your day, month and year.”, “Check your date before continuing.”, or “You need to be 18 or older to join Proximeet.” as appropriate.

## Implement actual input and eligibility

Start with **unset day, month, and year** (`DD / MMM / YYYY`), never a selected example/default birthday. Provide native accessible wheel selectors with Day/Month/Year labels. “Enter date instead” switches to minimal native labeled day/month/year fields, matching the supplied typography; avoid designing a new visual chapter. Preserve entered components when switching modes. Support keyboard, focus, VoiceOver values, and error announcements; no gesture-only entry.

Keep draft components separate from the committed date. A completed, settled wheel selection can commit the draft; typed entry commits with the keyboard Done/submit action. Validate after that commit, not during intermediate dragging or each keystroke, and do not require an extra unapproved inline button to unlock Continue. Incomplete, invalid, future, and committed under-18 dates keep Continue disabled. While the date is actively being edited, Continue stays disabled until the next complete commitment. Use concise native feedback for invalid/future dates; allow ordinary correction without bypass instructions. Never advance automatically.

Store the value as **date-only Gregorian civil components**, using the device's local civil date for “today”; a birthday is not a UTC instant. Locale changes may localize month names, without silently changing calendar semantics. Validate month lengths and leap years before constructing a calendar date; reject normalization of impossible dates. Compute the exact eighteenth birthday by calendar rules, not raw year subtraction or elapsed seconds.

For February 29 births reaching 18 in a non-leap year, use **March 1 provisionally** and document that product policy needs confirmation before production. Jurisdiction and final locale/date policy are unspecified; make no legal-compliance claim. The supplied product threshold is 18.

Birthday entry is self-declaration, **not age/identity verification**. Do not set `isVerified`, mark an “18+ Pass” accepted, fabricate authentication/backend success, or persist/log actual birthdays. Keep prototype date state in memory. Make no public-profile privacy promise.

## Layout, navigation, and checks

Keep Back always available with a 44-point target; typed-entry targets at least 44 points; Continue 60 points high, matching y=812 at the reference size. Adapt safely for smaller screens, keyboard, safe areas, Dynamic Type, VoiceOver, and Reduce Motion. Keep the housing stationary; do not animate validation unnecessarily.

Continue may use only a verified existing route that respects the current approval boundary; otherwise show a clearly identified prototype destination stating Pass is pending design. Do not route into a legacy timer that falsely marks age verification successful. Do not design Pass or other chapters, alter authentication, or connect providers.

Check available local build tools and test calendar validation: unset/partial, impossible/future, leap years, exact-18 birthday ±1 day, and the provisional February-29 boundary. Review input-mode preservation, correction, disabled actions, and accessibility where executable. No Mac, simulator, device, or CI run is assumed: report unavailable checks as **not run**, and never claim device performance or verified accessibility without evidence.

Hand back branch/worktree/base commit, changed files, actual navigation behavior, asset mapping, checks/results, unavailable checks, reproduction steps, and precise remaining deviations/policy decisions. Stop after Birthday.
