# Proximeet — Social Objects demo

A fresh SwiftUI iPhone app for the Proximeet entrance flow: Welcome, Birthday, Demo Pass, Guest List, Band and Signal, ending at Ready for check-in. The design centers on woven intent bands and metal signal tags.

Welcome is the founder-approved chapter 01 design ("A Place Opens"), Birthday the approved chapter 02, Pass chapter 03, Guest List chapter 04 and Wristband chapter 05. Welcome → More options → "Continue the demo (no account)" opens Birthday; an eligible date and Continue open Pass, a user-controlled demo of an age-check experience that performs no age or identity verification. Its Continue preview opens the Guest List (a first name, an optional introduction and interests, previewed as a card), whose Continue preview opens the Wristband: one intent for this moment, which makes no one visible. The Wristband's Continue preview ends with "End of this preview." Back returns one step at a time. Signal and later scenes are reachable only through the DEBUG `-ProximeetFixture` launch arguments. See [the Welcome report](docs/reports/welcome-chapter-01.md), [the Birthday report](docs/reports/birthday-chapter-02.md), [the Pass report](docs/reports/pass-chapter-03.md), [the Guest List report](docs/reports/guest-list-chapter-04.md), [the Wristband report](docs/reports/wristband-chapter-05.md) and the [Mac verification](docs/verification/README.md).

This is an offline, in-memory demo. It does not authenticate anyone, verify identity or age, check into a venue, show real people, access location or provide chat. Data disappears when the demo is reset or the app process ends.

## Verification status

As of 24 September 2026: the Social Objects refinement passed Codemagic build 2 on source `0f21deac21b76377969cf32bf7a4cac12d15389a` in 6m 4s. Xcode 26.6 compiled the native simulator app, 53 macOS domain tests passed, and the prior concurrency warnings are gone. The owner supplied the artifact archive; all 12 screenshot hashes match and the lead and independent reviewer inspected the images and decoded entrance reel. At the captured default size, all Band/Signal choices and CTAs fit and Ready is readable. Material depth, integrated lettering, Pass/Guest List treatment and Welcome proportions still need polish. The reel shows independent fixture launches, not an interactive walkthrough; AX5 is a captured scroll state, not a full accessibility test. This is an improved, reviewable offline prototype, without final founder approval or TestFlight readiness. See [native and visual evidence](docs/reports/visual-mac-verification.md).

See [lead status](docs/reports/LEAD_STATUS.md), [domain evidence](docs/reports/task01-domain.md), [native implementation and acceptance checklist](docs/reports/task01-ui.md), and [design direction](docs/design/PROXIMEET_SOCIAL_OBJECTS_DESIGN.md).

## Layout

- `Proximeet/`: app, design system, components, scenes and resources.
- `ProximeetDomain/`: pure Swift state transitions, validation and tests.
- `Proximeet.xcodeproj/`: generated project and shared `Proximeet` scheme.
- `scripts/`: deterministic standard-library Python generators and a separate project validator.
- `docs/`: design references, implementation assignments and evidence reports.

## Local checks

```bash
swift test --package-path ProximeetDomain --jobs 2
python3 scripts/validate_project.py --no-plutil
```

The generator outputs are committed. When source membership or assets change, regenerate and validate:

```bash
python3 scripts/generate_app_assets.py
python3 scripts/generate_project.py
python3 scripts/validate_project.py --no-plutil
```

SwiftUI and the iOS SDK require a Mac with compatible Xcode. Open `Proximeet.xcodeproj`, select the `Proximeet` scheme and an installed iPhone simulator, then build and run. Verify the full flow before using the DEBUG-only fixture arguments documented in `Proximeet/App/DebugFixtures.swift`. Fixtures are disabled by default and excluded from Release.

The target supports iOS 17 and later. The provisional bundle identifier is `com.proximeet.demo`; no developer team is configured. Simulator work should precede owner-team signing and TestFlight setup.

## Worktree and release boundary

The active cloud checkout is `/home/proximeet/proximeet-cloud`, an independent clone of the fresh orphan branch `redesign/social-objects`. Source commit `96fd33b` is pushed to the new private repository `kasrarayat-cloud/proximeet-rebuild`. Codemagic is connected only to this new repository on the personal free plan; no paid subscription is enabled. The manual-only unsigned simulator workflow has completed two successful runs; see [cloud setup evidence](docs/reports/codemagic-setup.md) and [the reviewed second build](docs/reports/visual-mac-verification.md).

The original checkout, its remote, the initial rebuild worktree and verified recovery archive remain separate. The original repository's third-party Xcode Cloud linkage and Apple credentials are not used by this rebuild. No signing, deployment or Apple upload has been performed.
