# Native 3D Band → Signal verification — 2026-09-24

## Scope

This increment replaces the flat Band and Signal hero with one shared RealityKit model, native intent and signal controls, interruptible plate attachment, horizontal drag rotation, and the same selected object on Ready. The first four onboarding scenes retain their preceding design. The product remains an offline in-memory demo; no authentication, identity verification, location, presence, backend or chat has been added.

Codex authored this increment and its asset conversion. The earlier Opus-authored app remains the base; this work is not represented as an Opus execution.

## Asset and source evidence

- The detailed editable authoring proof remains intact. The derived USDZ has 22,112 triangles and is 3,446,467 bytes, including three 2048-pixel woven-fabric maps.
- USDZ SHA-256: `de87c07e6f9975be84d63be1240f6d2586ec905c2839fc1e5afff5e9b61b81b6`.
- Studio EXR SHA-256: `d5946b6d3922dc56490f5beae6a29cab32178f83fc3ded51965f8fb5e8141b83`.
- The export was checked for metres, Y-up, a +Z plate face, a pivot at the plate centre, named entities and embedded textures. Surface/material fidelity still depends on the native renderer.
- Source selection applies synchronously through the existing domain. The decorative 0.51-second plate animation is cancelled on replacement. Reduced motion presents the selected plate without that movement.
- Linux domain suite: 53 XCTest cases passed with zero failures at 17:24 UTC. All 13 independent project checks, generated-project consistency, Bash syntax and diff-whitespace checks passed after integration. This is separate from an Apple SDK build.

## Native verification

Frozen source `44f0cb64505cbc573decfc8b9896a216f401535e` was committed and pushed to the new repository. Manual [Codemagic build 3](https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6ab55fafd8488eadf9a3c4d2) ran on that exact commit. All 53 domain tests passed on the Mac. Native Xcode 26.6 compilation passed in 33 seconds for iPhone 17 Pro Max / iOS 26.5 (23F77), with code signing disabled. The built USDZ hash matches the reviewed asset and the compiled `SignatureStudio.realityenv` exists at 979,721 bytes. Simulator installation, app launch, 12 fixture PNG captures and the fixture movie succeeded. The overall run **failed** after 13 minutes 31 seconds in the interaction test stage (exit 65).

The workflow runs two XCTest UI methods while recording the same simulator. Tests exercise all four intents, all four signals, replacement, confirmation, the actual bundled model loading, and the app-level reduced-motion override.

`testBandSignalInteraction` failed its initial 30-second model-ready value predicate. It never reached its normal-motion selection assertions. `testReducedMotionStillUpdatesImmediately` executed assertions through Ready and logged a pass at 149.733 seconds, but exceeded the runner's 120-second allowance and was included in the final failure. There is no passing UI suite at this checkpoint.

## Uploaded evidence review and bounded correction

The founder supplied the complete build 3 artifact archive on 2026-09-24. The first failure's accessibility debug description explicitly reports `Loading 3D preview`. The first-test recording shows a spinner at 40 seconds and the complete woven band appearing around 49 seconds; the model remains visible through 105 seconds. The readiness predicate begins around 45 seconds and fails around 75 seconds without a second evaluation logged. This supports delayed accessibility sampling during a slow model startup, rather than a universally broken asset or an indefinitely stalled load.

The B1 Social fixture contains the cyan woven band. The reduced-motion interaction attachment contains the green Activity band, metal plate and eye glyph. The selected Social/Chat first and AX5 timed fixtures have blank hero areas and must not be presented as successful completed renders. The actual renderer is still flatter and more frontal than the target reference; metal reflections and the hero presentation need further art direction. This is reviewed native evidence, not final visual approval.

The simulator took approximately 3–8 seconds per accessibility query and 15–20 seconds for some taps while recording. The runner allowance is now 600 seconds per test. The exact model-ready predicate remains required, with a bounded 90-second sampling deadline and screenshot/accessibility diagnostics on failure. No app source, material or asset changed for this correction. All 13 project checks and diff checks pass. The 30-minute workflow cap remains. A new native run is required for the updated test source.

Archive: `proximeet-rebuild_3_artifacts.zip`, 84,164,925 bytes. Primary visual evidence: `06-b1-band-selected-social.png`, attachment `7AF79553-2248-4EC1-987D-A0489A5DD6F9.png`, and first-test recording `CC41B621-F166-4AAF-8A61-CECF59112E2A.mp4`. Static fixture captures are separate launches, not a successful interactive walkthrough.

The app-level reduced-motion override is not evidence that the device's system accessibility settings were changed or verified. Simulator footage does not establish physical-device frame rate, temperature, battery usage, touch feel or haptics.

## Distribution boundary

The active repository is `kasrarayat-cloud/proximeet-rebuild`, branch `redesign/social-objects`. Its workflow is manual and unsigned. The legacy repository, recovery archive, founder evidence and third-party Apple credentials remain outside this increment. No TestFlight upload is part of this verification. A signed device build requires the owner's own Apple team and distribution setup.
