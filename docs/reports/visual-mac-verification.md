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

## Visual review still pending

The browser's normal artifact download failed at the storage redirect and reached a Chrome error page. No archive synchronized locally. No alternate network path or access bypass was attempted. The lead returned to the permitted completed build page.

The new PNGs and movie therefore **have not been visually inspected**. Download `proximeet-rebuild_2_artifacts.zip` from the build page and provide it to complete the side-by-side review. Do not infer final visual approval, clean system chrome, motion quality, frame rate, small-phone fit, VoiceOver behavior or device haptics from the successful build/capture process.

This remains an offline onboarding demo. No Apple signing, TestFlight upload, production deployment or legacy repository push occurred. The original code and verified recovery archives remain preserved. Documentation-only commits after the tested revision do not change the compiled app.
