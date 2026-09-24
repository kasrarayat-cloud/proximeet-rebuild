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

`testBandSignalInteraction` failed its initial 30-second model-ready value predicate. The first test never reached its normal-motion selection assertions. `testReducedMotionStillUpdatesImmediately` executed its assertions through Ready and logged a pass at 149.733 seconds, but exceeded the runner's 120-second allowance, caused a restart and was listed among the final failing tests. Consequently there is **no passing UI suite**. Cold model initialization or slow accessibility snapshots are plausible explanations for the first failure, not a confirmed diagnosis. The same model-ready checks did succeed in the later reduced-motion path.

The observed simulator took approximately 3–8 seconds per accessibility query and 15–20 seconds for some taps while recording. The runner allowance has therefore been corrected to 600 seconds per test, with the workflow's 30-minute cap retained and no assertions removed. Bash syntax and diff checks pass; this follow-up has not been rerun. The app source and 30-second readiness assertion remain unchanged pending the captured evidence.

## Evidence access and required next step

Codemagic published `proximeet-rebuild_3_artifacts.zip` (80.27 MB), `BandSignal.xcresult.zip` (75.87 MB), and the unsigned simulator app (8.97 MB). The archive includes the captured screens, recording, logs and exported XCTest attachments. The cloud browser's artifact navigation/download failed into an internal error page; the browser URL policy rejected reading that non-HTTP page. The documented file-download control also failed to produce a local file. An ordinary HTTPS request to the artifact URL on the owner's VPS returned 401; no browser credentials, cookies or tokens were extracted.

The founder should download `proximeet-rebuild_3_artifacts.zip` from the verified build page and attach it to the conversation. Inspect the first failure's `signature.hero` debug descriptions and screenshot, plus the reduced-motion Signal capture, before changing the readiness deadline or app loading code. Native visual quality is **not reviewed**. Do not describe the static fixture captures as a successful interactive walkthrough or as a verified physical-iPhone result.

The app-level reduced-motion override is not evidence that the device's system accessibility settings were changed or verified. Simulator footage does not establish physical-device frame rate, temperature, battery usage, touch feel or haptics.

## Distribution boundary

The active repository is `kasrarayat-cloud/proximeet-rebuild`, branch `redesign/social-objects`. Its workflow is manual and unsigned. The legacy repository, recovery archive, founder evidence and third-party Apple credentials remain outside this increment. No TestFlight upload is part of this verification. A signed device build requires the owner's own Apple team and distribution setup.
