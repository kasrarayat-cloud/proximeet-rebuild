# Proximeet — Social Objects demo

A fresh SwiftUI iPhone app for the Proximeet entrance flow. It moves from Welcome through Birthday, Demo Pass, Guest List, Band and Signal to Ready for check-in. The design centers on woven intent bands and metal signal tags.

This is an offline, in-memory demo. It does not authenticate anyone, verify identity or age, check into a venue, show real people, access location or provide chat. Data disappears when the demo is reset or the app process ends.

## Verification status

As of 24 September 2026: the first Codemagic Mac run passed on `70a2a8479a29aa5edf258ac98226fd35026b6bd8` (Xcode 26.6, 53 macOS domain tests). The owner supplied its screenshot archive; the lead reviewed all four native PNGs against the Social Objects showcase. That review led to the current material/layout refinement, custom generated artwork, full entrance capture set and a native fixture entrance reel. The refinement passes 12 Linux project checks, app Swift syntax parsing, shell syntax and 53 domain tests; its new Mac run and visual review are still pending. This is an offline demo and is not TestFlight-ready.

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

The active cloud checkout is `/home/proximeet/proximeet-cloud`, an independent clone of the fresh orphan branch `redesign/social-objects`. Source commit `96fd33b` is pushed to the new private repository `kasrarayat-cloud/proximeet-rebuild`. Codemagic is connected only to this new repository on the personal free plan; no paid subscription is enabled. The manual-only unsigned simulator workflow has completed one successful run; see [cloud verification evidence](docs/reports/codemagic-setup.md).

The original checkout, its remote, the initial rebuild worktree and verified recovery archive remain separate. The original repository's third-party Xcode Cloud linkage and Apple credentials are not used by this rebuild. No signing, deployment or Apple upload has been performed.
