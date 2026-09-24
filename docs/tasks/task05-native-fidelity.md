# Next native fidelity pass — evidence from build 3

This assignment is prepared from the actual uploaded simulator archive. It is not an implementation or a claim of completed polish. The frozen verification source is 229efef; product source and assets match 44f0cb6.

## Required result

Keep the existing offline Band → Signal → Ready flow and domain behavior. Improve the actual native hero toward the supplied Social Objects reference. New mockups and replacement rendering frameworks are not the deliverable.

## Evidence to address

- The loaded Band, reduced-motion Signal and Ready render correctly. Several six-second fixture captures are blank, so timed fixture output is not a reliable readiness gate.
- Each new SignatureBandHero creates an ARView and reloads both the USDZ and studio environment. Scene transitions in the recorded simulator show repeated loading.
- The renderer reports model readiness without confirming the studio environment finished loading. Compiled lighting resources alone do not prove that a capture used them.
- The plate has a bright bevel but a nearly uniform dark front. The exported BrushedSilver_PBR material contains constant silver colour, metallic=1 and roughness=.34; it has no brushed texture.
- At default size, the Activity tagline wraps and makes its card taller than Business. AX5 has a single column without visible horizontal clipping, but offscreen confirmation reachability is not proven.

## Bounded implementation order

1. Share a main-actor resource store for a pristine model prototype and studio environment, coalescing concurrent requests. Clone the model hierarchy per scene before applying tint, plate state and glyph. Keep domain state synchronous, support independent subscriber cancellation, and never mutate the prototype. Measure results; caching does not eliminate all ARView or GPU setup.
2. Record model completion and lighting completion separately. Visual evidence must wait for both, or explicitly show degraded lighting if the environment fails. Product choices must remain usable while the preview loads.
3. Calibrate a broad neutral reflection across the metal face in the actual native camera. Retain the dark/light contrast that gives the bevel depth. Do not solve this solely by making every material brighter.
4. Add restrained horizontal roughness grain and, if needed, a low-amplitude normal texture to the plate with explicit UVs. Preserve the editable source, named entities, plate pivot and ordinary PBR texture pipeline. Recheck the mobile asset package.
5. Equalize Band card row heights without clipping scalable text. Verify selection indicators, scrolling and confirmation at accessibility text sizes.

## Acceptance evidence

- Exact committed source; independent source checks and Mac compilation.
- Actual native Band colours, all Signal choices, reselection and Ready carry-through.
- Cold loading and repeat navigation recorded separately; do not equate XCTest query latency with physical-device performance.
- Normal motion and reduced motion shown separately. Automated taps separated by seconds do not establish rapid animation interruption.
- Native close-ups of woven fabric, reflected light and brushed metal; compare the same camera and screen size with the target.
- No claim of physical-iPhone frame rate, haptics, TestFlight readiness or final founder approval from simulator evidence alone.

Do not modify legacy source, recovery/private evidence, account settings, signing or credentials. No backend, sign-in, location or chat belongs in this pass.
