# Proximeet — Social Objects demo

A fresh SwiftUI iPhone app for the Proximeet entrance flow. It moves from Welcome through Birthday, Demo Pass, Guest List, Band and Signal to Ready for check-in. The design centers on woven intent bands and metal signal tags.

This is an offline, in-memory demo. It does not authenticate anyone, verify identity or age, check into a venue, show real people, access location or provide chat. Data disappears when the demo is reset or the app process ends.

## Verification status

As of 24 September 2026: 53 domain tests pass on Linux; all 24 app Swift files pass syntax parsing; all 11 local project checks pass. **An Apple SDK build, simulator/device run and native visual acceptance have not happened.** The first four scenes, icons, materials and app branding still need visual refinement. This is not TestFlight-ready.

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

This branch is a fresh orphan history on `redesign/social-objects`, currently local to the VPS at `/home/proximeet/proximeet-rebuild`. The original project and a verified recovery archive remain separate. No push, CI run, deployment or Apple upload has been performed. The old repository's third-party Xcode Cloud linkage must be addressed before using a push-based release path.
