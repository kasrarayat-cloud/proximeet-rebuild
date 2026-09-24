# Codemagic: first unsigned native verification

## Current visual refinement: PASS

Build 2 passed on `0f21dea` in 6m 4s with 53 Mac tests, 12 native captures and a fixture entrance recording. The two concurrency warnings are absent. New image/movie review is pending because the browser artifact download failed. See [build 2 evidence](visual-mac-verification.md). The historical first-build evidence follows.

## First cloud verdict: PASS

[Codemagic build 1](https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6ab4d1f52f2d1907d24566bd), ID `6ab4d1f52f2d1907d24566bd`, finished successfully on 24 September 2026 in **4m 22s**. It checked out clean source `70a2a8479a29aa5edf258ac98226fd35026b6bd8` from `redesign/social-objects`.

- Machine: virtual Apple M2, macOS 26.5.1 (25F80).
- Xcode: 26.6 (17F113), Apple Swift 6.3.3, iPhoneSimulator SDK 26.5 (23F81a).
- Checked-in project validation passed. Mac host XCTest completed 53 tests with 0 failures and `swift test` exit 0. The separate Swift Testing runner discovered 0 tests; that does not negate the 53 XCTest results.
- Native `xcodebuild` returned exit 0 and `BUILD SUCCEEDED` for Debug, arm64, iPhone 17 on iOS 26.5 (23F77), with signing disabled. Compilation took 20 seconds in the workflow. The observed log includes an AppIntents metadata warning because the app does not link AppIntents; this is not a claim of a warning-free build.
- Simulator boot, installation and four fixture launches/captures completed with exit 0. Each PNG was recorded as 1206 x 2622; process-liveness checks passed.
- Collected in the Codemagic build: `Proximeet-Debug-iphonesimulator-70a2a8479a29.zip` (797.34 KB) and `proximeet-rebuild_1_artifacts.zip` (5.02 MB). Codemagic's standard Publishing phase collected these CI artifacts; the workflow has no App Store or external publishing configuration.
- Billing UI after this run displayed **4 / 500** free macOS minutes and no paid subscription or prior transactions. No payment method or subscription was enabled.

The lead inspected the build overview, tool metadata, test verdict, compiler verdict and capture logs through Codemagic. The artifact link navigated the cloud browser to a failed storage download; no archive synchronized locally. Further inspection of the browser error page was blocked by the browser URL policy. The lead returned to the permitted build result page, without using an alternate download route. The owner subsequently uploaded `proximeet-rebuild_1_artifacts.zip` directly. The lead inspected all four native PNGs, and an independent archive check verified each SHA-256 against `captures.tsv`. **The first build is visually reviewed but is not visually approved.** See [the comparison](showcase-comparison.md) for concrete layout/material gaps. The full compiler log also exposes two distinct strict-concurrency warnings in `Adaptations.swift` (ArcSeat and LiftCurvePose); the next pass addresses them. The simulator package is also available there for a future authorized browser-preview service.

Still pending: full entrance-flow interaction, small/large displays, system accessibility settings, motion/performance and device checks, shared-scheme simulator tests, final design approval, owner-team signing and TestFlight. This remains an offline demo, not the complete product. The first build established native compilation. Its reviewed screenshots and compiler warnings now inform a separate source/CI refinement; the passing verdict above applies only to the recorded commit.

## Authoring checkpoint

Prepared 24 September 2026 for the independent cloud clone and private `kasrarayat-cloud/proximeet-rebuild` repository. The CI code was authored by actual Claude Code 2.1.281 using `claude-opus-5-5`, requested `ultracode`, with ordinary `acceptEdits`. The lead reviewed and pushed the workflow as `70a2a8479a29aa5edf258ac98226fd35026b6bd8`.

## Workflow

Select `proximeet-simulator-verification` manually in Codemagic on `redesign/social-objects`. It uses `mac_mini_m2`, pinned Xcode `26.6`, and a 30-minute maximum. Automatic triggers, publishing, notifications, signing credentials and integrations are absent. The existing Apple/Xcode Cloud repository is not used.

Seven stages record source/tool metadata, validate the checked-in project, run `swift test` on the macOS host, select an installed iPhone deterministically, build the Debug app for that simulator, zip the simulator bundle, and capture native fixture screenshots. Selection prefers iPhone 17, then the highest available compatible iOS runtime, with stable name/UDID tie-breakers. It never downloads a simulator runtime.

Every stage is `bash scripts/codemagic_verify.sh <stage>`. Accepted stages in order: `metadata`, `validate`, `domain-tests`, `select-simulator`, `build`, `package`, `captures`. Required command failures propagate through logging and fail the workflow. Per-stage PASS/FAIL entries refer only to stages that actually execute.

## Artifacts and limits

Download `build/artifacts/`: stage logs and summary; exact source, tool and simulator metadata; the zipped Debug simulator `.app` with its checksum; and B1, B2, Ready, and B2 reduced-motion-preview PNGs with capture metadata. DerivedData is excluded. The zip preserves executable permissions and is a simulator bundle, not an IPA or a TestFlight-installable build. Browser-preview compatibility and any preview upload remain separate work.

PNG capture uses the installed native app and existing DEBUG fixtures. These images still require human visual review. Process-liveness checks do not prove the intended screen is unobscured. The reduced-motion sample uses an app launch override, not the system setting. Captures do not establish device performance, accessibility compliance, real sign-in, verification, presence or messaging. The first workflow deliberately omits shared-scheme simulator tests; it covers host domain tests plus native app compilation and fixture launches.

## Authoring checks and pending evidence

Independent Linux checks passed: `bash -n scripts/codemagic_verify.sh`; installed PyYAML parsing plus machine/version/manual-only/artifact-scope checks; `python3 scripts/validate_project.py --no-plutil` (11/11); and `git diff --check`. These are not evidence of a successful Mac build.

Claude's own Bash checks were denied by its unchanged tool-permission setup in the new clone. The lead's delegated reviewer performed the scoped Linux checks above without changing those permissions. No cloud build was invoked by the coding worker or this authoring reviewer. Consult the actual Codemagic run for native results; Xcode compilation, simulator launches and screenshots were still pending when this handoff was prepared.

Official configuration references checked: [YAML workflow configuration](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/) and [Xcode 26.6 machine image](https://docs.codemagic.io/specs-macos/xcode-26-6/). The latter lists Xcode 26.6 (17F113), M2 and installed iOS 26.5/iPhone 17 simulators.
