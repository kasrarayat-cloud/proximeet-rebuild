# Rebuild lead status — 2026-09-24

## Current checkpoint: native 3D app builds; interaction verification failed

The native Band → Signal → Ready increment is committed and pushed as `44f0cb6` in the new repository. It includes the mobile USDZ (22,112 triangles; 3.45 MB), compiled studio lighting, actual native selections, interruptible attachment, drag rotation and UI tests. Codex authored this increment. The previous detailed authoring proof and legacy project remain preserved.

Codemagic build 3 compiled the app with Xcode 26.6 for iPhone 17 Pro Max / iOS 26.5. All 53 Mac domain tests passed; model and lighting bundle gates passed; 12 fixture PNGs and the fixture movie were generated. The overall run FAILED in 13m 31s: the normal test timed out on initial model readiness, while the reduced-motion path reached Ready but exceeded the runner allowance and was included in the final failed verdict. There is no passing UI suite and no native visual approval.

The runner allowance is corrected to 600 seconds per test without removing checks or changing the 30-minute workflow cap. It has not been rerun. The initial model-ready predicate remains unchanged until its captured state is inspected. Cloud-browser artifact downloading failed; direct HTTPS retrieval without an authenticated session returned 401. No credentials were extracted. The required next input is `proximeet-rebuild_3_artifacts.zip` (80.27 MB), downloaded by the founder from the existing build page and attached to the conversation. This contains the actual screenshots, recording and failure diagnostics needed for the next fix. See [the complete native 3D verification record](native-3d-verification.md).

TestFlight has not been uploaded. The Apple signing/team setup and physical-device performance remain unverified. The first four onboarding scenes retain the prior design; no backend or live account features were added.


## Current direction: editable 3D band proof

The owner rejected the flat tinted-PNG band approach and approved an editable 3D band with an integrated metal plate. Codex authored the working Blender generator and refinements after two actual Opus 5.5 attempts produced no source and were stopped. The four source/helper files are now preserved under `assets/three_d/`, with destination hashes verified against the lead's working copies.

The v4 mounted hero rendered successfully on Windows Blender 4.5.14 LTS using RTX 5070 OptiX: frame 100, 900 × 900, 64 samples, exit 0, visually inspected after the Boolean engraving fix. The full 48-sample motion render and encoding completed with exit 0; independent decoding verified 120 frames at 900 × 900, 24 fps and exactly 5 seconds. The lead inspected the approach, attachment and final hold, and both deliverables passed transfer checksum verification. This is a detailed editable authoring proof, not mobile-ready geometry or a native iPhone implementation. No app code, cloud build, Apple signing or TestFlight operation is part of this asset pass. See [the 3D proof evidence and source provenance](signature-3d-proof.md).

## Native app checkpoint: reviewed build 2

Actual Opus 5.5 ultracode implemented the six-screen Social Objects material pass with three production assets; the lead corrected B1 layout, metal selection alignment and Ready. Linux checks passed, followed by Codemagic build 2 on `0f21dea`: native compilation, 53 Mac tests, 12 screenshots and a fixture entrance movie in 6m 4s. The previous concurrency warnings are gone. The owner supplied this build's archive; all 12 capture hashes match and the lead and independent reviewer inspected every PNG plus the decoded 16.23-second reel.

At the captured default size, no clipping was observed, all B1/B2 choices and CTAs fit, and Ready is readable. Remaining showcase gaps are flat paper and verbose copy on Pass/Guest List, shallow bands with overlaid lettering, the hanging B2 tag and narrow Welcome artwork. B1's stagger is visible; Welcome's opening scale obscures its app settle, and the preselected B2 fixture demonstrates no tap or attachment transition. The reel contains separate launches with Home/black interludes, not an interactive walkthrough. AX5 shows the top of a longer scroll; interaction and full accessibility remain unverified. Verdict: an improved, reviewable native prototype, without final founder approval or TestFlight readiness. See [native and visual evidence](visual-mac-verification.md), [source evidence](visual-refinement.md) and [the prepared next assignment](../tasks/task03-showcase-polish.md).

## Cloud setup update (first-run checkpoint)

The active cloud checkout is now `/home/proximeet/proximeet-cloud`, with its own Git metadata and remote. Baseline `96fd33b` is pushed to the new private repository `kasrarayat-cloud/proximeet-rebuild` on default branch `redesign/social-objects`. The legacy origin is unchanged. Codemagic personal registration is complete; its GitHub App is restricted to the new repository. The first manual unsigned simulator run passed on `70a2a8479a29aa5edf258ac98226fd35026b6bd8` in 4m 22s: Xcode 26.6 native compilation, 53/53 Mac host domain tests, simulator installation and four fixture captures. The account subsequently showed 4 of 500 free macOS minutes used and no paid subscription. The owner subsequently supplied the capture archive. The lead visually reviewed all four native PNGs and independently checked their hashes against the capture manifest. The comparison exposed flat band geometry, oversized Signal cards and typography differences from the supplied showcase; the first B1 capture also has a system notification. This is not final visual approval. A dedicated refinement pass is in progress; see [showcase comparison](showcase-comparison.md). See [cloud verification evidence](codemagic-setup.md) and the [build result](https://codemagic.io/app/6ab4d02869609bf0cdd94b08/build/6ab4d1f52f2d1907d24566bd). No Apple signing/upload or legacy CI was invoked.

The sections below preserve the pre-cloud implementation checkpoint. References there to no push or the initial worktree describe that checkpoint, not the current remote state.

## Current result

A fresh native SwiftUI demo and pure Swift domain are implemented on orphan branch `redesign/social-objects`, in `/home/proximeet/proximeet-rebuild`. The first domain commit is `4d5bc4c`; the native increment is being committed locally with this report. No legacy product source, HaloCore code, CI workflow, signing identity or credential was copied into the new app.

The six entrance scenes are functional in source through Ready for check-in. B1/B2 have the detailed Social Objects visual treatment: woven intent bands, metal clasps and signal tags, a shared secured band, and adaptive motion. The first four scenes are functional scaffolds. The entire app is an explicitly labeled offline, in-memory demo. There is no real authentication, identity/age verification, location, presence, backend or chat.

The implementation is not yet a native-verified app or an approved final design. Custom icon fidelity, typography, miniature welcome worlds, material polish and final app branding remain design work. TestFlight is not ready.

## Verified evidence

- Lead's independent Linux command `swift test --package-path ProximeetDomain --jobs 2`: direct exit 0, 53 XCTest cases, 0 failures and no warnings. The domain is unchanged in the native increment.
- Final lead syntax parse of all 24 app Swift files: exit 0, no diagnostics. This is parsing only, not type checking or an Apple SDK compile.
- Final lead `python3 scripts/validate_project.py --no-plutil`: all 11 on-disk checks passed, direct exit 0. This covers generated project wiring, source/resource membership, local package linkage, scheme, settings, asset format, privacy declarations, reproducibility and an app-source guardrail scan. Separate domain source-guard tests cover domain production sources.
- `git diff --exit-code HEAD -- ProximeetDomain` and `git diff --check`: direct exit 0 before staging.
- Independent read-only reviewers inspected the native source, generator and actual project/scheme. Profile saves dismiss only on success; reset clears local form state; navigation uses the guarded domain path; birthday picker and eligibility share a calendar/timezone.
- Three review findings were fixed by the lead: reduced-motion latch geometry, VoiceOver arrival policy, and the editor preview's invalid scene fixture. The final checks above include these changes.
- The generated interim icon was viewed. App screen screenshots, animation timings, accessibility behavior, haptics and performance have not been verified on Apple hardware or a simulator.

Evidence logs remain private ignored files under `.claude-run/`; full implementation and acceptance details are in `task01-domain.md` and `task01-ui.md`.

## Native and distribution gates

No Mac is connected. A compatible Xcode environment must build and type-check the exact committed source, resolve the package test target, and capture the full flow at small/large displays and accessibility settings. Device haptics and performance need device evidence. Only then should signing and TestFlight use the owner's own Apple team and a confirmed unique bundle identifier. `com.proximeet.demo` is provisional; no developer team is configured.

No push, workflow dispatch, CI run, deployment, signing or Apple upload was performed. The old repository's external Xcode Cloud linkage and stored third-party Apple credentials were not activated or modified. They still require an ownership/automation decision before any future push or release path uses that repository.

## Recovery and provenance

The original checkout remains `/home/proximeet/proximeet`, inspected clean at `7bf6c0cef67c9a20b8fe86a767fa58fb07040044`. The live remote branch was observed at `67ae15dca5d014023922955c50e7569a54e083ce`; the new branch has not been pushed.

`/home/proximeet/proximeet-recovery-2026-09-24/manifest.json` records a complete project archive, compared against its source, and an archive of surviving project transcripts. Recovery files are private on the VPS. `/home/proximeet/handoff-evidence-2026-09-23/` was left unchanged; its retention remains the owner's decision.

Implementation used the existing Claude Max login and actual model `claude-opus-5-5`, with `--effort ultracode` and ordinary `acceptEdits` permissions. Environment: Linux, user `proximeet`, Git 2.43.0, Swift 6.3.3, Python 3.12.3, Claude Code 2.1.281. Session: `2bfdc050-bd40-44b8-b368-95e78b3e13bd`. No bypass permission mode or permission changes were used.

The initial broad run was narrowed into domain and native passes. The domain pass completed; its report was corrected to distinguish eight deliberate mutations in three batches and the exact suite counts. Claude wrote the native source, generator scripts and report draft. The lead gracefully stopped only that owned native run while a duplicate review was pending, after independent review had finished, then generated the reviewed outputs and closed the bounded findings directly. The old unrelated Claude session was left untouched.

Optional Claude Workflow reviews were blocked by their normal approval requirement. Separate read-only reviews and direct checks supplied the review evidence; no blocked workflow was bypassed. The worker's narrow command allowlist did not permit the generator commands, so the lead ran those specific reviewed scripts under the owner's existing rebuild authorization without altering the worker permissions.

Exact Figma B1/B2 structure and reference screenshots were retrieved. SVG download validation failed; semantic SF Symbol substitutes are explicitly interim. Reference screenshots were not embedded as app UI.
