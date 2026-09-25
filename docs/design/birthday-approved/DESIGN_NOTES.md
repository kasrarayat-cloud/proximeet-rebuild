# Proximeet — Birthday chapter review

Status: Birthday visual design approved by the founder on 24 September 2026: “approve lets go next perfect”. Welcome remains approved. Approval covers this screen and its intended input states; the example-state Figma interaction is not a working unrestricted date picker or age-verification service.

Figma file: https://www.figma.com/design/9ZkCIlu9AqAD1f92UDuMAF
Birthday page: 16:114. Review board: 23:195.

| State | Frame | Example date | Continue |
|---|---|---|---|
| Empty | 19:111 | DD / MMM / YYYY | Disabled |
| Adult | 19:112 | 12 May 1997 | Enabled |
| Under 18 | 19:113 | 12 May 2012 | Disabled |

The example dates are illustrative and are not the user's birthday. Entering a birthday supplies self-declared information; it does not verify identity or age. The under-18 state gives a gentle eligibility message, keeps Back available, and does not suggest evading the age gate.

## Design and editable content

440 × 956 logical design frame. Manrope throughout, matching approved Welcome. Graphite housing, a cotton-paper edge and cyan textile tab connect the chapters. The housing is generated decoration; all day/month/year labels, values, guidance, error copy, and controls remain native editable Figma elements. Continue stays fixed at y=812 with a 60 px target. Back and the typed-entry alternative have 44 px targets. Body text is at least 16 px.

## Review interaction

In the Figma prototype, tapping the date module cycles through the three sample states with a 180 ms dissolve. This is a limited review interaction, not a working unrestricted date picker. Continue never advances automatically. The date module stays stationary for reduced motion.

## Intended entry and validation behavior

“Enter date instead” opens the platform's accessible typed date-entry interface with labeled day, month and year fields. Preserve the entered date when switching between typed entry and the wheel. Support keyboard and assistive technology, announce selected values and errors, and avoid gesture-only entry.

Validate after a complete date is committed, not while scrolling through intermediate values. Reject impossible and future dates. Handle leap years and the exact 18th-birthday boundary using calendar dates in the relevant local calendar. Do not rely on raw year subtraction or treat a birthday as a UTC timestamp. Under-18 users cannot continue. Production validation remains to be implemented and tested.

No claim is made about whether the birthday appears on a public profile; that privacy behavior requires a product decision.
