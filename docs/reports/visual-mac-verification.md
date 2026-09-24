# Visual refinement: Mac verification — 24 September 2026

[Codemagic build 2](https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6ab4e00058faadc97272fc47) passed in **6m 4s** on source `0f21deac21b76377969cf32bf7a4cac12d15389a`, branch `redesign/social-objects` in the new private rebuild repository.

## Verified through the build UI

- Xcode 26.6 native Debug simulator compilation: **BUILD SUCCEEDED**, exit 0, 24 seconds. iPhone 17 / iOS 26.5, arm64, signing disabled.
- The full 1,051-line compiler log was loaded and inspected. The previous ArcSeat/LiftCurvePose concurrency warnings are absent. The only warning shown is skipped AppIntents metadata extraction because there is no AppIntents dependency.
- macOS host domain tests: **53 XCTest cases, 0 failures**, swift test exit 0. The separate Swift Testing runner having zero tests does not negate XCTest.
- Checked-in project validation passed; the current validator has 12 checks.
- The full capture log reports **12 native PNGs, each 1206x2622**: Welcome, Birthday, Pass, empty and filled Guest List, unselected and selected Band, unselected and selected Signal, Ready, app-level Reduce Motion preview and actual simulator AX5 text size.
- The AX5 setting was successfully applied, captured and restored to the original `large` text size. This is a captured state, not a complete accessibility test.
- `12-fixture-entrances.mp4` was recorded from the native simulator; the script confirmed a nonempty file and wrote its checksum. It contains independent Welcome/Band/Signal fixture entrances, not an interactive end-to-end walkthrough.
- Artifacts: `Proximeet-Debug-iphonesimulator-0f21deac21b7.zip` (5.57 MB) and `proximeet-rebuild_2_artifacts.zip` (21.49 MB).
- Billing after the run showed **10 / 500** free macOS minutes used in total, no enabled subscription and no previous transactions.

## Visual review of the supplied artifacts

The owner supplied the build 2 archive. The lead and an independent visual reviewer inspected all 12 native PNGs from the same source `0f21dea`; every capture hash matches its manifest and every image is 1206 × 2622 pixels. The earlier retrieval problem is resolved. The supplied `proximeet-rebuild_2_artifacts.zip` has SHA-256 `5a9f57aca6ff02535a5e40c2a0380f537f6b34b095697fe0749c4b1c49824e29`; the movie hash also matches its capture manifest.

| Scene | Observed result and remaining showcase gap |
|---|---|
| Welcome | Appealing miniature-world artwork, but the composition is narrow and the disclosure takes substantial space. |
| Birthday | Native picker and surrounding content are readable at the captured default text size. |
| Demo Pass and Guest List | Readable, truthful paper surfaces, including the entered-name roster. Flat panel treatment and verbose copy remain the largest gaps from the showcase. |
| Band (B1) | All four choices and the CTA fit. The loops appear flatter and more horizontal than the target; the lettering looks overlaid rather than part of the strap. |
| Signal (B2) | Clear, functional hierarchy; the hero, all four options and CTA fit. The selected tag hangs below the band rather than reading as the target's front-mounted plate. |
| Ready | The assembled object, summary and actions are readable. |
| AX5 Signal | The capture shows the top of a longer scroll. It does not establish that scrolling, focus or every action works at that size. |

No clipping was observed at the captured default text size. This does not establish small-phone fit, interactive behavior or full accessibility conformance.

## Decoded motion review

The H.264 reel is 16.23 seconds long with 226 decoded frames. It shows independent DEBUG fixture launches, with a leading frame from the previous B2 state, Home transitions and brief black startup surfaces between scenes. It is not an interactive end-to-end walkthrough, and the frame count is not a rendering-performance measurement.

B1 rows brighten from top to bottom, then remain stable. The operating system's opening scale dominates Welcome's first frames, so the app's proposed settle cannot be isolated. B2 arrives with Chat first already selected and attached, then stays stable; no tap or attachment transition is demonstrated. No persistent rendering issue was observed after settling.

## Verdict and next work

This is a reviewable, improved native prototype. It is not final founder approval or TestFlight readiness. The next bounded design pass should prioritize Pass/Guest List material and copy, band depth and integrated lettering, the B2 plate attachment, and Welcome proportions. See [the prepared showcase-polish assignment](../tasks/task03-showcase-polish.md). Real interaction, system accessibility behavior, device haptics and performance still require separate evidence.

This remains an offline onboarding demo. No Apple signing, TestFlight upload, production deployment or legacy repository push occurred. The original code and verified recovery archives remain preserved. Documentation-only commits after the tested revision do not change the compiled app.
