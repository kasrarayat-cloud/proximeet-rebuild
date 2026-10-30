# Wave Leave test correction review

The candidate reuses a fresh accessibility snapshot for static assertions in `testLeaveFromEveryWaveContext`, addressing repeated UI automation queries in the test that timed out. All 18 contexts and every existing assertion remain in the source. Native compilation, UI behavior and elapsed time remain unverified; no measured speed improvement is claimed.

Prepared for the coordinating assistant on 2 October 2026. Visible identity is GPT-6-based Codex; the exact runtime model variant and reasoning effort are not exposed. The separate candidate follows the user's authorized destination in place of CLAUDE.md's older work-directory instruction. No project AGENTS.md was present. This report is added at the path required by CLAUDE.md; the implementation change is confined to `ProximeetUITests/WaveReviewTests.swift`.

## Baseline integrity

Archive: `/home/proximeet/Proximeet-Wave-Sol-Baseline-20261002.zip`.

Archive SHA-256: `43d6a336d116ec283cb88d8f86ca96039f9c5892cf9efb119443a75af9a486d7`.

Extracted baseline: `/home/proximeet/proximeet-wave-leave-review-kp70vkx1/baseline`. Writable source candidate: `/home/proximeet/proximeet-wave-leave-review-kp70vkx1/candidate`. Review artifacts: `/home/proximeet/proximeet-wave-leave-review-kp70vkx1/review`.

Extraction rejected absolute or parent-traversal paths, duplicate names, symbolic links and special files; created a new directory; read every ZIP entry to validate its CRC; and restored declared file modes. All 621 listed source/evidence files matched both transfer/manifest.json and transfer/SHA256SUMS, including sizes and modes. All 341 source paths and hashes matched evidence/OptimizedMain-frozen-products-supplement.json exactly. The three transfer metadata files are not self-listed in those manifests; their integrity is bound by the verified archive. A complete 624-file baseline inventory supports the final preservation check.

Historical patches are already applied and were left untouched. Native products and raw xcresult bundles remain on the Mac; the selected text evidence is sufficient to establish the timeout, not native success.

| File | Baseline SHA-256 | Candidate SHA-256 |
| --- | --- | --- |
| ProximeetUITests/WaveReviewTests.swift | `7c0009a8cb0902e1b45b19e4b5f25b9f41b52cd8a39cda73f67bb5c7b6c889d9` | `1ecb0b1d9f3c89195c242d59cb641aeacc59a2a57195d8e1cb2e2fb70b2051ba` |
| ProximeetUITests/RoomReviewTests.swift | `5e1009adc4bf2bf0b042760151808e2424c943a29449ab2e1715d7cc4cae24e1` | `5e1009adc4bf2bf0b042760151808e2424c943a29449ab2e1715d7cc4cae24e1` |

The changed-file manifest also hashes this newly added report; it has no baseline counterpart.

## Implementation and snapshot lifetime

Only Leave's three assertion callsites enable `reuseSnapshot: true`. assertScreen and assertOverlay still read the current tree on each call. Their local assertion facade then reuses that tree's identifying properties, labels, types, frames, enabled state and selection state for the original static assertions. Every other caller uses the default live path. There is no stored snapshot cache or test-instance flag.

The first snapshot follows the fixture's existing live readiness wait and settle. The ended snapshot follows the actual Leave tap and existing live ended-screen wait and settle. Places keeps its existing live destination waits and obtains its own fresh tree after Return to Places. The wrapper is confined to a helper call and cannot survive into the next tap or reveal.

Lookup preserves the first matching container's descendant subtree, including nested panels and excluding later duplicate containers and the application root. It preserves XCTest's identifying-property matching and returns the actual element identifier. Apple's [matching API documentation](https://developer.apple.com/documentation/xcuiautomation/xcuielementquery/matching(_:identifier:)) identifies identifier, title, label, value and placeholderValue as matching properties.

Missing snapshot elements throw into the existing XCTFail handlers. Failed app.snapshot calls retain their visible XCTFail. No snapshot error is suppressed or converted to a success. Existing soft assertion blocks, including the venue aggregate and sentence-case checks, remain intact.

Monotonic elapsed diagnostics print and attach each context's started, checked-before-leave, checked-ended and completed phases, including context and whole-test elapsed seconds. Completion is recorded after termination. Original screenshots and the final per-context completion table retain their names and contents.

## Assertion equivalence for all contexts

The source audit found all 217 XCTest assertion/failure expressions identical in text and order. The fixture table is byte-identical. The following common checks apply to every row, with screen/panel checks applied exactly where the original helpers applied them:

- Preserve the live readiness wait, settle, visible Leave label, live reveal/tap behavior, and real Leave tap.
- Preserve identifiers, approved labels/case/normalization, element types, enabled and selected states, frame width/height thresholds, chrome, decorative-ring assertions and attachments, panel controls and hidden-underlay checks.
- Obtain a fresh ended-state snapshot after the unchanged live wait. Preserve the exact Wave ended destination, all approved ended text, enabled Return to Places and its height check, and the live zero-alert check.
- Preserve absence of Safety, Back, Leave, panels, Room, Places, invitation, venue ticket, invitation actions and sample names/identity text or values in the ended state. Preserve the explicit no-active-invitation copy.
- Preserve the original per-context ended screenshot, actual Return tap, live Places headline/Now selection/ticket/Room-absence waits, explanation absence and fresh tree absence of Room/Wave.
- Preserve the original completion-table entry and final attachment; add phase timing evidence for each context.

| Order | Context | Viewer | Additional checks before Leave | Review result |
| --- | --- | --- | --- | --- |
| 1 | `demo-menu` | Alex/Social/Chat first | Menu headline/role/boundary, visible Back, all three enabled choices, nothing started, sample names absent. | Preserved in source |
| 2 | `out-confirm` | Alex/Social/Chat first | Outgoing direction and ticket, counterpart copy/preferences, Send only, no Demo cases or Accept. | Preserved in source |
| 3 | `out-pending` | Alex/Social/Chat first | Outgoing direction and ticket, counterpart copy/preferences, Demo cases and Withdraw only, no Accept. | Preserved in source |
| 4 | `out-withdrawn` | Alex/Social/Chat first | Approved state-specific closed-screen copy, Back to demo menu; invitation/ticket/actions/sample identities absent. | Preserved in source |
| 5 | `in-review` | Alex/Social/Chat first | Incoming direction and ticket, counterpart copy/preferences, Demo cases and Accept/Decline only; exactly one Accept. | Preserved in source |
| 6 | `in-declined` | Alex/Social/Chat first | Approved state-specific closed-screen copy, Back to demo menu; invitation/ticket/actions/sample identities absent. | Preserved in source |
| 7 | `in-accepted` | Alex/Social/Chat first | Incoming accepted direction and ticket, counterpart copy/preferences, Demo cases and About private chat only, no Accept. | Preserved in source |
| 8 | `unavailable` | Alex/Social/Chat first | Approved state-specific closed-screen copy, Back to demo menu; invitation/ticket/actions/sample identities absent. | Preserved in source |
| 9 | `blocked` | Alex/Social/Chat first | Approved state-specific closed-screen copy, Back to demo menu; invitation/ticket/actions/sample identities absent. | Preserved in source |
| 10 | `allowance-unavailable` | Alex/Social/Chat first | Approved closed-screen copy, Back to demo menu, no invitation or names; no numeric app content; system-scroll metadata evidence retained. | Preserved in source |
| 11 | `in-withdrawn` | Alex/Social/Chat first | Approved state-specific closed-screen copy, Back to demo menu; invitation/ticket/actions/sample identities absent. | Preserved in source |
| 12 | `global-safety` | Alex/Social/Chat first | Preview label, global safety title/explanation, Close + Leave only; all sample names and hidden underlay absent. | Preserved in source |
| 13 | `jules-safety` | Alex/Business/Okay to say hello | Business viewer/Jules safety title/explanation, Block Jules + Preview report + Back + Leave only; Maya and hidden underlay absent. | Preserved in source |
| 14 | `report-jules-harassment` | Alex/Business/Okay to say hello | Report Jules title/explanation, all three labelled >=44pt reason rows; harassment alone selected; Close preview + Leave only, no submission, no Maya or underlay. | Preserved in source |
| 15 | `chat-info` | Alex/Social/Chat first | Chat information copy, Back + Leave only, no text composer/submission/sample names/underlay. | Preserved in source |
| 16 | `conditions-out` | Alex/Social/Chat first | Controls label and conditions copy, Show expired example + Back + Leave only; no submission/sample names/underlay. | Preserved in source |
| 17 | `conditions-in` | Alex/Social/Chat first | Controls label and conditions copy, Show expired example + Show sender withdrawn + Back + Leave only; no submission/sample names/underlay. | Preserved in source |
| 18 | `conditions-accepted` | Alex/Social/Chat first | Controls label and conditions copy, Show expired example + Back + Leave only; no submission/sample names/underlay. | Preserved in source |

These are source equivalence findings. They do not establish that the final previously timed-out context now passes natively.

## Shared helper impact

Changed shared code consists of the opt-in facade in assertScreen/assertOverlay; assertion-input types for assertMenu/assertInvitation/assertClosed and six primitive assertion helpers; and readTree/WaveNode/WaveTreeEntry metadata capture. Existing assertion expressions and live interaction helpers are unchanged. All 34 assertion-facade property mappings match WaveUI. These helpers are private to this file; no other test class calls them.

Every affected Wave test caller is listed below. Their default reading path remains live; only Leave enables the snapshot path.

- `testRealJourneyFromTheRoomProfileThroughTheWaveAndBack`
- `testBusinessJulesJourneyAndReentry`
- `testBothApproachesForEachIntent`
- `testCaptureApprovedScreensAndOverlays`
- `testDuplicateAndStaleActionsChangeNothing`
- `testRolesNeverChange`
- `testInterruptedAcceptanceNeverEndsJoined`
- `testBlocksInBothOrdersUseTheOneRoomSet`
- `testLeaveFromEveryWaveContext`
- `testEdgeSwipesFollowTheVisibleBack`
- `testLargestTextKeepsWaveScreensReachable`
- `testLargestTextKeepsWavePanelsReachable`
- `testReduceMotionPreviewAcceptJoinsWithoutAMove`
- `testIneligibleAndOtherIntentNeverReachTheWave`

The focused native correction and three required unrun tests exercise the new path and several default branches. Regression coverage for every affected caller remains required in the separate strict full-plan verification, including both large-text tests, blocked menus, reports, ring captures, stale actions and gestures.

## Checks performed

Commands ran from the candidate unless an absolute review path is shown:

```sh
swiftc -frontend -parse ProximeetUITests/WaveReviewTests.swift
python3 -B scripts/generate_project.py --check
python3 -B scripts/validate_project.py
swift test --package-path ProximeetDomain --scratch-path /home/proximeet/proximeet-wave-leave-review-kp70vkx1/review/domain-build
python3 /home/proximeet/proximeet-wave-leave-review-kp70vkx1/review/assertion_equivalence.py
python3 /home/proximeet/proximeet-wave-leave-review-kp70vkx1/review/run_snapshot_harness.py
git apply --check /home/proximeet/proximeet-wave-leave-review-kp70vkx1/review/wave-leave-snapshot.patch  # baseline source directory
git apply --reverse --check /home/proximeet/proximeet-wave-leave-review-kp70vkx1/review/wave-leave-snapshot.patch  # candidate directory
```

Results: Swift syntax PASS; generator up to date; project validation 13 checks and 0 failures; Linux domain/source suite 258 tests and 0 failures. Existing unused-result warnings appeared in unchanged domain test files.

The assertion audit passes with 217 unchanged expressions, all 18 contexts, preserved live interaction/capture/isolation helper bodies, and exactly three Leave-only opt-in callsites. The Swift 6.3.3 harness extracts 19 declarations/helpers verbatim and compiles with strict concurrency and warnings as errors. It passes instrumented checks for zero live queries on static cached reads; missing-node and snapshot failure propagation; label/enabled/frame failures; selected state; all five identifying-property matches; actual identifiers; first-panel/nested/duplicate/root scope; and separately acquired readings after transitions. Each harness command is bounded to 30 seconds. This harness uses stubs and does not establish native XCTest API compilation or Apple snapshot behavior.

Patch forward and reverse checks pass. Applying the patch in an isolated copy with umask 022 reproduces all 342 candidate files and their modes; all 624 baseline files and the archive remain unchanged. Machine-readable integrity, assertion, harness, source-check and patch-application results accompany the patch in review/. No native/cloud suite, push, deployment or Chat + Keep work was performed.

## Preserved native evidence status

RecoveryMain04-verification-summary.json records Leave failed solely for exceeding 15 minutes, with invocation exit 65. The first 17 contexts completed their Leave/Places checks. The final conditions-accepted launch began around 890.67 seconds and became idle around 891.77 seconds; its completion is unproved.

The two large-text tests passed individually in that failed invocation: panels 279.742 seconds and screens 723.362 seconds. Preserve these individual results. The real journey, Reduce Motion and roles tests never ran in the planned subsequent recovery invocation. Neither selected recovery results nor this source correction satisfies the strict successful Main280/Small7 invocation requirement.

## Proposed bounded native verification

The coordinator performs this plan after reviewing the patch. It is a proposal and has not been launched. Use an equivalent fresh iPhone 17 Pro Max simulator at 440 by 956 points with default text size, and the retained recovery toolchain where available: Xcode 26.6, macOS 26.3.1, iOS simulator 26.5. Record any environment difference.

1. Freeze the reviewed candidate hashes. Use candidate-owned source, DerivedData, logs and result bundles; preserve all frozen products and evidence. Reserve 300 seconds total for setup, hashing and exports. Verify baseline integrity before and after.
2. Rebuild edited tests with build-for-testing, scheme Proximeet and unchanged WaveVerificationMain plan, without signing. Use a 600-second external invocation cap. Frozen test products cannot exercise the patch.
3. Run Leave once using test-without-building and only its original identity, parallel testing disabled. Keep the existing 900-second test allowance, plan flags and run guard. Use a 1200-second external invocation cap for launch/result-handling overhead. No retries or timeout overrides.
4. Require exact one start/pass, no skipped/failed/expected-failure tests, all 18 original screenshots, all 18 completed timing records and the original completion table. A missing final-context completion or timeout fails this gate. Report measured candidate duration and compare query activity with the retained timeout log; the original full completion duration is unknown.
5. Run one separate selected invocation for testRealJourneyFromTheRoomProfileThroughTheWaveAndBack, testReduceMotionPreviewAcceptJoinsWithoutAMove and testRolesNeverChange, with a fresh equivalent simulator and unchanged allowances. Cap the invocation at 3000 seconds. Require exactly three passes, no skips/retries/omissions, preserved captures and actual Reduce Motion pixel/anchor/control evidence at the required geometry. An explanatory pixel-check note is insufficient evidence.
6. Stop at the first failure or exhausted cap, preserve outputs and report the failed gate. The three xcodebuild invocation caps total 4800 seconds; including the separate 300-second setup/hash/export allowance, the proposed focused verification bound is 5100 seconds (85 minutes).

Invocation shape, using fresh candidate-owned paths:

```sh
xcodebuild test-without-building \
  -project Proximeet.xcodeproj -scheme Proximeet \
  -testPlan WaveVerificationMain \
  -destination 'platform=iOS Simulator,id=<new-simulator-id>' \
  -derivedDataPath '<candidate-derived-data>' \
  -resultBundlePath '<new-result-bundle>' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:ProximeetUITests/WaveReviewTests/testLeaveFromEveryWaveContext
```

The three-test invocation replaces the final selection with three only-testing arguments. The external watchdog records timeout/termination evidence and never converts a partial result into success.

## Separate strict full run requirement

The focused invocations do not close the original contract. Unmodified Main280 and Small7 must each complete in successful full-plan invocations, every expected identity exactly once, with no failed/skipped/expected-failure/retried/omitted identity and no RUN_BUDGET_SPENT. Keep Main's 6240-second and Small's 2160-second guards and the original combined 9600-second compute bound including two 600-second action allowances. Keep all plans, test identities, captures and candidate provenance unchanged.

D2's eight source-reading tests are additional. Preserve the Main build-host hook evidence: D2_BEGIN, eight D2_PASSED records and successful D2_RESULT. Linux source checks are useful evidence but do not replace the required native invocation records. Any future native/cloud run remains separately coordinated; this task starts none.

## Room Notes optimization review — 2 October 2026

The user reports that the prior Wave Leave candidate passed native verification. The Wave review above records its earlier preparation status and is preserved verbatim as historical text. This assignment preserves that candidate and its review/evidence/products, and prepares a separate Room Notes correction for review. Room Notes native compilation, UI behavior and elapsed time have not been measured here. No speed improvement is claimed.

Visible identity is GPT-6-based Codex; the exact runtime model variant and reasoning effort are not exposed. Applicable CLAUDE.md was read; no applicable AGENTS.md was found. The user's separate-candidate instruction supplies the working location in place of CLAUDE.md's historical directory. Only RoomReviewTests.swift implements the correction; this report is appended at the required destination. No app code, design, signing, test identity, test plan, allowance, historical patch or original evidence is changed. No push, native/cloud run, deployment or Chat + Keep work was performed.

### Provenance and changed files

Parent candidate: `/home/proximeet/proximeet-wave-leave-review-kp70vkx1/candidate`.

New immutable baseline: `/home/proximeet/proximeet-room-notes-review-qsozkg7z/baseline`.

New writable candidate: `/home/proximeet/proximeet-room-notes-review-qsozkg7z/candidate`.

Review directory: `/home/proximeet/proximeet-room-notes-review-qsozkg7z/review`.

The baseline is a complete 342-file copy of the preserved Wave candidate. It retains all 341 archive source paths plus the prior required report. The archive's original provenance and transfer checks remain as recorded above. The verified original archive hash remains `43d6a336d116ec283cb88d8f86ca96039f9c5892cf9efb119443a75af9a486d7`.

| File | Room baseline SHA-256 | Room candidate SHA-256 |
| --- | --- | --- |
| ProximeetUITests/RoomReviewTests.swift | `5e1009adc4bf2bf0b042760151808e2424c943a29449ab2e1715d7cc4cae24e1` | `39a93056f14a00e5a647ab030a6415ffdee7a0cfeac7ac38347443d4b7707b48` |
| ProximeetUITests/WaveReviewTests.swift, preserved | `1ecb0b1d9f3c89195c242d59cb641aeacc59a2a57195d8e1cb2e2fb70b2051ba` | `1ecb0b1d9f3c89195c242d59cb641aeacc59a2a57195d8e1cb2e2fb70b2051ba` |

The changed-file hash manifest includes both the Room test and this appended report. The report's baseline hash is `077d72075f252beca72c4cf6bd65695be59e28caf2f5a59fb8d9e38ddc520c52`; its candidate hash is external to this report to avoid a self-reference.

### Implementation and fresh readings

Only `testNotesFilteringAndBothBlockOrders` and its exclusively called `assertAfterBlock`/`assertBlocksSurvive` helpers enable snapshot reuse. Eleven source callsites expand into the original 34 People/Notes page checks. Each check keeps its live selected-tab readiness wait, then acquires one fresh app snapshot. A local assertion facade uses that snapshot for identifiers, labels, existence, selected state, enabled state and frames, and the same tree content/type/value for the original absence checks. The original RoomNode and readTree definitions remain byte-identical. Other tests retain the default live path and its original per-element snapshots.

The snapshot is local to one assertion helper call; it cannot survive a tab change, block, launch, Safety close, profile Back or report-preview return. Existing waits and settling after these transitions remain exact. Actual taps, reveal/hittability checks, waits, four profile/report blocked-sample tree checks, captures and all pixel checks remain live/unchanged.

Snapshot lookup matches XCTest's five identifying properties (identifier, title, label, string value and placeholder), excludes the application root and selects the first matching descendant. It returns the actual identifier for diagnostic and absence logic. Missing cached elements throw into the existing assertion failure handlers. A failed app.snapshot emits XCTFail and returns a non-nil empty tree, so failure never silently falls back to live assertions or becomes a pass. Existing soft assertion failure behavior is unchanged.

Monotonic diagnostics print `ROOM_NOTES_ELAPSED` and add keepAlways text attachments after each of the 34 complete page checks. Their durations include the live wait and existing screenshot pixel check. One start record and four cumulative block-survival completion records identify progress through both launches. Every existing screenshot and named capture remains unchanged.

### Assertion equivalence and scenario checklist

The audit finds all 226 original XCTest assertion/failure expressions identical in order and content. One new XCTFail explicitly exposes snapshot-reader errors. All 13 Room test identities remain intact, including the target's identity and existing 900-second allowance. The audit compares original target transitions/control flow after removing only the new diagnostics/opt-in arguments, and original People/Notes assertions after removing only the facade plumbing.

People checks retain the selected-tab live wait, both tab labels/selection/44-point heights, framing, each visible actor's own card label/44-point height, blocked-card absence, block-dependent boundary, filtered-empty title/explanation only when both are blocked, and absence of the empty card otherwise. Notes checks retain framing, host note and icebreaker (including their existing composite-element alternatives), exact visible Jules note and Safety label/height/width when unblocked, and note/Safety absence with the exact hidden-notes boundary when Jules is blocked. Every page retains Leave label/enabled/height, Proximeet/Demo/Safety chrome and Safety width/enabled/height, full-tree types/identifiers/labels/values, no empty-room claim, all blocked sample identity/data/identifier absence, and its original screenshot pixel check.

| Order | Block stage | Page | Return path | Preserved named capture |
| --- | --- | --- | --- | --- |
| 1 | before-any-block | people | initial populated launch | Existing pixel check only |
| 2 | before-any-block | notes | select Notes | Existing pixel check only |
| 3 | maya-first | people | after block | room-blocks-maya-first-people-fixture |
| 4 | maya-first | notes | after block -> Notes | room-blocks-maya-first-notes-fixture |
| 5 | maya-first | people | after block -> Notes -> People again | Existing pixel check only |
| 6 | maya-first | notes | survival -> Notes | Existing pixel check only |
| 7 | maya-first | people | survival -> tabs -> People | Existing pixel check only |
| 8 | maya-first | people | survival -> global safety close from People | Existing pixel check only |
| 9 | maya-first | people | survival -> visible profile's Back | Existing pixel check only |
| 10 | maya-first | people | survival -> closed selected report -> safety Back -> profile Back | Existing pixel check only |
| 11 | maya-first | notes | survival -> global safety close from Notes | Existing pixel check only |
| 12 | maya-then-jules | people | after block | room-blocks-maya-then-jules-people-fixture |
| 13 | maya-then-jules | notes | after block -> Notes | room-blocks-maya-then-jules-notes-fixture |
| 14 | maya-then-jules | people | after block -> Notes -> People again | Existing pixel check only |
| 15 | maya-then-jules | notes | survival -> Notes | Existing pixel check only |
| 16 | maya-then-jules | people | survival -> tabs -> People | Existing pixel check only |
| 17 | maya-then-jules | people | survival -> global safety close from People | Existing pixel check only |
| 18 | maya-then-jules | notes | survival -> global safety close from Notes | Existing pixel check only |
| 19 | jules-first | people | after block | room-blocks-jules-first-people-fixture |
| 20 | jules-first | notes | after block -> Notes | room-blocks-jules-first-notes-fixture |
| 21 | jules-first | people | after block -> Notes -> People again | Existing pixel check only |
| 22 | jules-first | notes | survival -> Notes | Existing pixel check only |
| 23 | jules-first | people | survival -> tabs -> People | Existing pixel check only |
| 24 | jules-first | people | survival -> global safety close from People | Existing pixel check only |
| 25 | jules-first | people | survival -> visible profile's Back | Existing pixel check only |
| 26 | jules-first | people | survival -> closed selected report -> safety Back -> profile Back | Existing pixel check only |
| 27 | jules-first | notes | survival -> global safety close from Notes | Existing pixel check only |
| 28 | jules-then-maya | people | after block | room-blocks-jules-then-maya-people-fixture |
| 29 | jules-then-maya | notes | after block -> Notes | room-blocks-jules-then-maya-notes-fixture |
| 30 | jules-then-maya | people | after block -> Notes -> People again | Existing pixel check only |
| 31 | jules-then-maya | notes | survival -> Notes | Existing pixel check only |
| 32 | jules-then-maya | people | survival -> tabs -> People | Existing pixel check only |
| 33 | jules-then-maya | people | survival -> global safety close from People | Existing pixel check only |
| 34 | jules-then-maya | notes | survival -> global safety close from Notes | Existing pixel check only |

Maya-first uses a profile block; Maya-then-Jules uses Jules's note Safety action. The second populated launch resets the run, blocks Jules from his profile, then blocks Maya from her profile. Each of the four stages retains People→Notes→People, Safety opened/closed from both pages and its live return/absence waits. With one actor blocked, the other actor's profile/Back and selected report→Safety→profile→People are retained. The four original profile/report trees still assert blocked-sample absence before returning. There are 21 People checks, 13 Notes checks, four block actions, four survival scenarios, eight named captures and 34 original page pixel checks.

Machine-readable per-page assertions and the four additional profile/report tree contexts are included in `review/assertion-equivalence.json`.

### Shared helper impact and necessary regression coverage

The shared helpers changed are assertPeople/assertNotes (opt-in argument/local facade), assertTabs (facade argument), assertChrome (a live forwarder plus facade overload), and assertText/assertButton (private assertion-reading protocol instead of XCUIElement-only input). The two block helpers are exclusive to the target. All original assertions remain exact. RoomUI, RoomNode, readTree, block, navigation, waiting, reveal, capture, pixel and leak-detection helpers remain byte-identical. All 16 static facade identifiers and dynamic card/tab identifiers equal RoomUI's existing queries.

Every transitive caller of changed shared helpers is listed below. Only the Notes target reaches the snapshot path; the other 11 retain live reads. Native regression coverage must include all 12 callers, including large text, Reduce Motion, reports, Leave, gestures, reentry and approved captures. The unchanged full plans provide that coverage when their complete successful-invocation gates pass. `testIneligibleAndStaleEntryIsRefused` has no path to the changed helpers.

- `testRealJourneyFromTheExplanationThroughTheRoomAndBack`: `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.
- `testEntryNeedsBothDeliberateGates`: `assertButton`, `assertChrome`, `assertPeople`, `assertTabs`, `assertText`.
- `testSocialCompatibilityAndBothApproaches`: `assertButton`, `assertChrome`, `assertPeople`, `assertTabs`, `assertText`.
- `testBusinessCompatibility`: `assertButton`, `assertChrome`, `assertPeople`, `assertTabs`, `assertText`.
- `testNotesFilteringAndBothBlockOrders`: `assertAfterBlock`, `assertBlocksSurvive`, `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.
- `testReportPreviewIsLocalAndRestoresItsCaller`: `assertButton`, `assertChrome`, `assertNotes`, `assertTabs`, `assertText`.
- `testLeaveFromEveryContext`: `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.
- `testBackGesturesInTheRoom`: `assertButton`, `assertChrome`, `assertPeople`, `assertTabs`, `assertText`.
- `testTerminalReentryResetsTheDemo`: `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.
- `testCaptureApprovedStatesAndOverlays`: `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.
- `testLargestTextKeepsRoomReachable`: `assertButton`, `assertText`.
- `testReduceMotionPreviewRoom`: `assertButton`, `assertChrome`, `assertNotes`, `assertPeople`, `assertTabs`, `assertText`.

### Local checks actually performed

Commands ran from the new candidate unless another cwd is indicated. Full logs/results and reproducible harness/audit scripts accompany the patch.

```sh
swiftc -frontend -parse ProximeetUITests/RoomReviewTests.swift
python3 -B scripts/generate_project.py --check
python3 -B scripts/validate_project.py
swift test --package-path ProximeetDomain --scratch-path /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/domain-build
python3 /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/assertion_equivalence.py
python3 /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/run_snapshot_harness.py
git apply --check /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/room-notes-snapshot.patch  # new baseline cwd
git apply --reverse --check /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/room-notes-snapshot.patch  # new candidate cwd
python3 -B /home/proximeet/proximeet-room-notes-review-qsozkg7z/review/finalize_review.py  # new review root; integrity and isolated application checks
```

Swift syntax PASS; project generation up to date; project validation 13 checks/0 failures; Linux domain/source tests 258 passed/0 failed. Existing unused-result warnings appeared in unchanged domain tests. The assertion audit passes the preservation checks above. The separate instrumented Swift 6.3.3 harness extracts 32 candidate declarations/helper bodies verbatim, compiles under strict concurrency with warnings as errors, and checks cached static reads, live default behavior, failure propagation, property failures, identifier matching and freshness. These checks use Linux stubs and do not establish native XCTest compilation, Apple snapshot behavior, simulator rendering or improved runtime. Harness details/results are included separately.

Forward/reverse patch checks and application to an isolated baseline copy reproduce candidate file hashes and modes. The new 342-file baseline and all 2747 files in the prior Wave root remain unchanged, including prior evidence, products and reports. The four test plans and RunBudget remain byte-identical. The report keeps the entire prior Wave report as an exact prefix. Final integrity and changed-file manifests accompany the patch.

### Historical Room Notes evidence and remaining native checks

The unchanged `OptimizedMain.log` records the Notes identity starting at line 6105 and exceeding the 15-minute allowance at line 7188. This is a timeout, not proof that the later scenarios pass within 900 seconds. The separate `RecoveryMainNotesExtended.log` records a selected pass at line 1970 in 1446.969 seconds after its invocation explicitly overrode default/maximum allowances to 1800 seconds. Its verification JSON states `strict_main_gate_satisfied: false`. Preserve that extended selected pass as distinct evidence; it does not validate this correction or the original allowance.

The coordinator performs native verification after patch review. Proposed focused bound is 2700 seconds (45 minutes): up to 300 seconds setup/hashing/exports, 1200 seconds fresh build-for-testing, and 1200 seconds one selected test invocation. Stop at the first failure or external-cap exhaustion; preserve partial results as failures. Use separate candidate-owned DerivedData/evidence/result paths and a fresh equivalent default-text iPhone 17 Pro Max simulator at 440×956 points. Prefer the retained toolchain (Xcode 26.6/macOS 26.3.1/iOS simulator 26.5) and record differences.

Build the candidate with scheme Proximeet and unchanged WaveVerificationMain plan, without signing. Run exactly `ProximeetUITests/RoomReviewTests/testNotesFilteringAndBothBlockOrders` once, serially, retaining its existing 900-second allowance, plan flags and RunBudget guard. Do not add timeout overrides, retries, skips or alternative test identities. Frozen products cannot exercise the edited test.

```sh
xcodebuild test-without-building \
  -project Proximeet.xcodeproj -scheme Proximeet \
  -testPlan WaveVerificationMain \
  -destination 'platform=iOS Simulator,id=<fresh-simulator-id>' \
  -derivedDataPath '<candidate-derived-data>' \
  -resultBundlePath '<new-room-notes-result-bundle>' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:ProximeetUITests/RoomReviewTests/testNotesFilteringAndBothBlockOrders
```

Require exactly one native start/pass, no failure/skip/retry/expected failure, both launches, all four blocks, all 34 completed page diagnostics, four block-survival completions and eight original named captures, with intact pixel-check and blocked-sample absence evidence. Export the console log, summary/tests JSON and preserved raw xcresult. Report measured candidate duration; only native measurements can support a speed claim. The existing baseline's full 900-second completion time is unknown.

Regression coverage for the 12 shared-helper callers and strict verification remain separately coordinated. Selected correction success does not satisfy Main280/Small7. The unchanged full Main280 and Small7 must each finish as successful invocations with every required identity exactly once, no failed/skipped/expected-failure/retried/omitted identity, and no RUN_BUDGET_SPENT. Retain Main's 6240-second and Small's 2160-second guards and the original combined 9600-second bound with two 600-second action allowances. Preserve Main's D2_BEGIN, eight D2_PASSED and successful D2_RESULT host-hook records. Linux checks do not replace them. This task launches none of these runs.

## Aggregate UI harness runtime review — 2 October 2026

This candidate batches repeated static accessibility assertions across the shared Room/Wave helpers and their capture, matrix, report and largest-text paths. All original test bodies, actions, waits, holds, scenarios, screenshots, pixel checks and assertions remain intact. It gives the coordinator a concrete measurement hypothesis for the unchanged Main guard; it does not establish native speed or full-suite completion.

The required reduction is 5,850.880 seconds (48.3925%) from the mixed successful Main30 UI total of 12,090.880 to its unchanged 6,240-second guard. The seven priority identities alone cannot close it: even their impossible zero-cost elimination leaves 7,325.713 seconds. The patch therefore reaches 25 shared-helper callers. Manual source expansions estimate 4,236 fewer successful static API accesses: Room 2,036 and Wave 2,200. These counts mix element snapshots and property reads; they are not measured round trips or seconds. No full-plan fit is claimed.

Prepared by GPT-6-based Codex. The exact runtime model variant/effort is not exposed. Applicable CLAUDE.md was read; no applicable AGENTS.md was found. The user's separate-candidate instruction supersedes the older work-directory restriction. This scoped report is appended to the entire prior report as an exact byte prefix. The app, design, signing, test plans, identities, allowances, RunBudget and D2 implementation are unchanged. No native/cloud suite, push, CI dispatch, deployment, signing, upload, TestFlight or Chat + Keep work occurred.

### Starting source, completed history and missing attachment

Starting complete source: `/home/proximeet/proximeet-room-notes-review-qsozkg7z/candidate` (342 files). New immutable baseline: `/home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/baseline`. Writable complete candidate: `/home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/candidate`. Review artifacts: `/home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review`.

The three user-specified starting hashes match exactly:

| Path | Starting SHA-256 | Ending SHA-256 |
| --- | --- | --- |
| ProximeetUITests/RoomReviewTests.swift | `39a93056f14a00e5a647ab030a6415ffdee7a0cfeac7ac38347443d4b7707b48` | `c8f940fa4ce139f104d8b6156faf1e6ceb138865e2cf6261d953bc647fad61f7` |
| ProximeetUITests/WaveReviewTests.swift | `1ecb0b1d9f3c89195c242d59cb641aeacc59a2a57195d8e1cb2e2fb70b2051ba` | `f90ea9872f4e8f9cc41e6097606989f513f1eaeb38dd512b7865b22ef2d4020e` |
| docs/reports/task01.md | `a5a1f292e3031756b18232ef98cda9934412fa612a59467457410dd213fc9f46` | Recorded externally in changed-file-hashes.json to avoid self-reference. |

Only these three files change. Starting/ending inventories record every source file's hash, mode and size. Both prior review roots, their compiled Linux products, evidence, patches and reports are preserved with before/after inventories. Frozen Mac native products and raw results are not touched.

The coordinator reports the Notes candidate compiled natively and passed exactly once in 726.912 seconds under the original 900-second allowance, with all 34 pages/34 numeric pixel notes/39 elapsed diagnostics/four stages/two launches/orders/eight captures and no failures/skips/retries/runtime warnings. Wave's earlier Leave 545.019, Journey 465.514, Reduce Motion 111.565 and Roles 477.826 are successful selected history. All their source behavior remains; shared plumbing changes mean these passes are not proof for this candidate.

The newly attached aggregate verification bundle is not exposed through a visible filesystem path or attachment reference. Requested access remains: its report, `main-budget-estimate-after-notes.json`, independent audit and primary budget-source exports, or the containing archive's local path. The user was asked for that path while source work continued. Their contents have not been invented or claimed read. This is a material provenance gap in the requested evidence review.

Available evidence was independently inspected: OptimizedMain and RecoveryMain01/02/03/04 native logs and primary test JSON exports in the retained Mac-transfer evidence. Twenty-five successful historical primary records plus the five current selected durations supplied by the user sum 12,090.879529 seconds, matching the reported rounded aggregate. `native-operation-cost-evidence.json` records each identity/source/duration and inspected evidence hashes. These disjoint mixed-run results do not establish a successful full invocation. Reconcile the missing aggregate attachment before accepting an evidence-complete budget forecast.

### What disappears and what remains live

Wave's assertScreen/assertOverlay already obtained a fresh app snapshot for tree/ring/control/negative assertions. After independently auditing every caller and the action-free helper bodies, their default now uses that same local tree for approved labels, actual identifiers, types, existence, frames, enabled/selected state and report reasons. Screen/overlay helper bodies are byte-identical; only the parameter defaults change. Leave's explicit opt-ins, 18 contexts, original completion evidence and diagnostics remain unchanged. Its estimated incremental operation saving is zero.

Room's Entry/Waiting/StillWaiting/Ended/Profile/GlobalSafety/ActorSafety/Report/WaveMenu helpers each acquire one fresh local tree. Ended/Profile/WaveMenu retain their existing live readiness checks before acquisition; callers' existing waits and settling remain unchanged for all other helpers. Nested Venue/Chrome/Panel helpers consume the local assertion facade. Their standalone Venue/Chrome overloads acquire their own current tree. People/Notes now default to static reuse after the original live selected-tab wait. The original `reuseSnapshot` opt-in retains Notes elapsed behavior; the new `useSnapshot` flag enables other settled callers without adding unrelated Notes attachments. The original Notes test/block helpers and recordNotesElapsed body remain exact, so its 39 diagnostics are preserved.

The Room facade now mirrors all 48 original static properties and three indexed queries, plus scoped inPanel. The new reader carries DFS ancestor indices. Panel lookup selects the first matching descendant container, excludes that container itself and searches only its descendants; later duplicate sibling panels and leaked underlay identifiers cannot satisfy scoped controls. Both facades preserve identifier/title/label/string-value/placeholder matching and the actual element identifier, excluding the application root. Original RoomUI/RoomNode/readTree and WaveUI/readTree are unchanged. Missing cached nodes and snapshot errors remain visible failures; a failed Room tree is non-nil/empty and never triggers a live fallback.

Each capture column check independently takes a fresh tree inside its original soft-failure closure. It eliminates repeated existence/frame/identifier queries while preserving every geometry expression and screenshot. It deliberately does not retain a previous helper's tree: assertShown/underlay/column may still acquire separate trees, each with its own current-state ownership. Snapshot errors keep that soft scope and captures continue exactly as before.

Largest-text checks retain every reveal, drag, settling sample, control exclusion and live hittability test. After each successful reveal, one fresh element snapshot supplies the current item's static label/enabled/frame assertions. Enabled-button hittability stays live before that snapshot. Disabled choices remain untapped. No item reading crosses the next reveal, scroll, transition, overlay or sampling boundary. Snapshot errors now explicitly XCTFail. Horizontal bounds, app frames, purpose/preference overlap snapshots, failure captures, paired blocked-menu screenshots and real largest-text Leave/Places/Signal proofs remain unchanged.

All navigation, waits, input/focus/keyboard handling, taps/gestures/stale actions, quiet waits/approved holds, launch/relaunch/termination, alert counts, animation ring samples, pixel reads and screenshots remain live. Reveal/settledRevealLook/revealLook, sampleAccept, ring structures/attachments, Room motion reads and existing leak predicates are byte-identical. Places' three Main identities and every other app/domain source remain unchanged.

### Operation-cost map and feasibility

Source successful-route counts exclude lazy XCTest failure messages. The native log audit distinguishes direct Find Any/exists activities from application-find activities, which can represent app.frame, snapshot, screenshots or framework work. Adjacent activity timestamps are not exclusive query durations or recoverable savings.

| Path | Repeated work removed | Work retained/added |
| --- | --- | --- |
| Room settled helpers | Entry9 extra snapshots; Waiting13 extra static accesses; unblocked People24 and Notes26; Profile16; Report22; panel/chrome/venue static reads, per fresh assertion state. | One local tree, original readiness, negative predicates and pixel reads. Existing Notes 34 page trees remain equivalent. |
| Room capture | Source expansion estimates609 fewer accesses over 25 fixtures, including column reads. | All25 launches,26 named captures, separate underlay trees and fresh column trees. |
| Room report identity | Estimates298 fewer static accesses across the10 previews and other return states. | Every selection/dim tap/close/reopen/actor/caller restoration and failure expression. |
| Wave core | 88 newly cached screen states +26 overlay states across callers estimate1,838 fewer accesses. | Original fresh readTree, ring assertions/attachments, all negative/control/type checks and live readiness/actions. |
| Wave capture | Removes193 extra element snapshots +48 reason-row properties; column's233 static reads become23 fresh root snapshots (net210). | All23 fixture launches,24 named captures, ring evidence, pixels and separate column tree. |
| Wave approaches | Removes206 extra element snapshots +72 reason-row properties plus active-invitation live properties. | Four intent/approach rows,14 screen/eight overlay states, all safety/report/reopen actions and extra spoken-preference checks. |
| Wave largest text | Passing static reads298 become146 post-reveal snapshots (net152). | All146 items:75 texts/68 enabled buttons/three disabled choices,68 live hittability checks and71 live app-frame reads; reveal sampling unchanged. |
| Room largest text | Passing static reads90 become45 post-reveal snapshots, plus settled profile/panel-return savings in its source expansion. | Six inspections (23 text/22 button rows),three way-back proofs and three actual Leaves, all holds/captures/pixels. |

Room's per-identity source total is2,036 and Wave's2,200. Detailed fixed-loop formulas and limits are in room-operation-cost-map.json and wave-expanded-costs.json. These manually expanded API-access estimates are useful review targets, not dynamic framework counts.

Historical native examples support focusing here: the first new Room report spends approximately24.32–52.90 seconds on its23 state operations before the next action; Wave's first outgoing confirmation repeats its root-reading state through7.80–43.05 seconds; its report repeats18 direct element/existence activities through75.02–101.60 seconds. No action is removed from those intervals. The capture/matrix log query gaps contain substantial repeated work but also essential live reads and adjacent overhead; they are not summed as predicted savings.

The guard needs5,850.880 seconds removed. Dividing by the net4,236 source accesses gives a screening threshold of about1.381 seconds saved per eliminated net access. Historical direct-query intervals commonly span roughly1–2 seconds, so this is a plausible cost hypothesis worth measuring. It is not a calibrated prediction: access types differ, snapshots include traversal work, XCTest may cache internally, and the historical timing mix is not one invocation.

Holding the already-batched Notes and Leave and five unchanged-source identities at historical durations leaves approximately2,120.829 seconds in that group, and9,970.051 seconds among the paths needing new savings. That remaining group would need about58.6846% reduction. Therefore a comfortable fit is not established by these safe source changes. If current native measurements do not recover the required gap with headroom, this correction has not made Main fit; report the residual and stop before another full Main attempt. Coverage, fixtures and guards must not be weakened to compensate.

### Scenario/assertion/capture equivalence

All13 Room and14 Wave test bodies are byte-identical. All444 original XCTest assertion/failure expressions remain in their original per-function order (Room227/Wave217). Only the two explicit settled-element snapshot error failures are new. Fixture/copy/enum/viewer/counterpart/launch-argument/largest-item tables, all capture/attachment names, action order and budget calls remain exact.

| Scenario family | Preserved coverage |
| --- | --- |
| Main/Small | Main30 UI+250 domain=280; Small7; all four plan bytes/default900/maximum1200; Main6240/Small2160 guards; eight separate native D2 identities. |
| Room capture | All25 approved states, all block sets, profiles/global and actor safety/report reasons; original extra no-reason capture and geometry/pixels. |
| Room Notes | Both launches/block orders and four block routes;21 People+13 Notes pages;34 numeric pixels;39 diagnostics;four completed stages;eight original captures;profile/report/tree absence and survival paths. |
| Room reports | Both actors, all reason states/replacements/no-deselect/dim/reopen/from-note/back returns;no submission/active privacy/hidden-sample checks. |
| Room compatibility | Both Social approaches and Business mirror;same/other intent;actual actor words/preferences/actions;real Wave-menu entry and back. |
| Room largest/motion/terminal | Six item lists and three Back/three Leave proofs;gesture cancellation/completion;terminal reentry;motion pixels and input journeys intact. |
| Wave capture/matrix | All23 fixtures/24 captures;four both-approach rows;counterpart/report selection/reopening;all identifiers/roles/preferences/case/types/state/frame rules. |
| Wave Leave | All18 contexts and final completion evidence;real Leave/Places taps;no prompt;hidden controls/underlay/person names/active invitation checks;captures/elapsed records exact. |
| Wave largest | All20 checks/146 items;blocked disabled controls;purpose-preference same-snapshot overlap;paired screenshots;two real terminal journeys. |
| Wave stale/motion/roles/journeys | Every double/stale tap,interruption,edge-swipe,typed journey,role row,acceptance pixel anchor/four immediate samples/control/settled frames retained. |

Machine-readable per-test scenarios, original assertions and capture catalogs accompany the patch: room-scenario-equivalence-checklist.json, room-equivalence-audit.json and wave-equivalence-audit.json. The source equivalence proof does not establish that snapshot timing is natively equivalent. Room's unchanged opacity transitions/synchronous accessibility hiding and animation-disabled Leave/Block support the selected boundaries; transient geometry/idleness assumptions remain native checks (room-snapshot-freshness-rationale.json).

### Every affected helper caller

The candidate call graph identifies12 Room and13 Wave affected identities. Neither Ineligible identity reaches changed helpers; the three Places Main methods are unchanged. Primitive snapshot/reading plumbing is covered through each listed caller. Broad regression must cover all 25; historical passes do not discharge it.

| Identity | Changed helpers reached |
| --- | --- |
| `RoomReviewTests/testRealJourneyFromTheExplanationThroughTheRoomAndBack` | `assertActorSafety`, `assertChrome`, `assertEnded`, `assertEntry`, `assertNotes`, `assertPanel`, `assertPeople`, `assertProfile`, `assertReport`, `assertVenue`, `assertWaiting`, `assertWaveMenu`, `readAssertionTree` |
| `RoomReviewTests/testEntryNeedsBothDeliberateGates` | `assertChrome`, `assertEntry`, `assertGlobalSafety`, `assertPanel`, `assertPeople`, `assertStillWaiting`, `assertVenue`, `assertWaiting`, `readAssertionTree` |
| `RoomReviewTests/testSocialCompatibilityAndBothApproaches` | `assertChrome`, `assertPeople`, `assertProfile`, `assertVenue`, `assertWaveMenu`, `readAssertionTree` |
| `RoomReviewTests/testBusinessCompatibility` | `assertChrome`, `assertPeople`, `assertProfile`, `assertVenue`, `assertWaveMenu`, `readAssertionTree` |
| `RoomReviewTests/testNotesFilteringAndBothBlockOrders` | `assertChrome`, `assertNotes`, `assertPeople`, `readAssertionTree` |
| `RoomReviewTests/testReportPreviewIsLocalAndRestoresItsCaller` | `assertActorSafety`, `assertChrome`, `assertNotes`, `assertPanel`, `assertProfile`, `assertReport`, `readAssertionTree` |
| `RoomReviewTests/testLeaveFromEveryContext` | `assertActorSafety`, `assertChrome`, `assertEnded`, `assertEntry`, `assertGlobalSafety`, `assertNotes`, `assertPanel`, `assertPeople`, `assertProfile`, `assertReport`, `assertVenue`, `assertWaiting`, `readAssertionTree` |
| `RoomReviewTests/testBackGesturesInTheRoom` | `assertActorSafety`, `assertChrome`, `assertEnded`, `assertPanel`, `assertPeople`, `assertProfile`, `assertStillWaiting`, `readAssertionTree` |
| `RoomReviewTests/testTerminalReentryResetsTheDemo` | `assertChrome`, `assertEnded`, `assertEntry`, `assertNotes`, `assertPeople`, `assertVenue`, `assertWaiting`, `readAssertionTree` |
| `RoomReviewTests/testCaptureApprovedStatesAndOverlays` | `assertActorSafety`, `assertChrome`, `assertEnded`, `assertEntry`, `assertGlobalSafety`, `assertNotes`, `assertPanel`, `assertPeople`, `assertProfile`, `assertReport`, `assertVenue`, `assertWaiting`, `readAssertionTree`, `softlyColumn` |
| `RoomReviewTests/testLargestTextKeepsRoomReachable` | `assertActorSafety`, `assertEnded`, `assertPanel`, `assertProfile`, `assertReachableButton`, `assertReport`, `assertUnclipped`, `readAssertionTree`, `readElementForAssertion` |
| `RoomReviewTests/testReduceMotionPreviewRoom` | `assertChrome`, `assertGlobalSafety`, `assertNotes`, `assertPanel`, `assertPeople`, `assertProfile`, `assertVenue`, `assertWaiting`, `readAssertionTree` |
| `WaveReviewTests/testBlocksInBothOrdersUseTheOneRoomSet` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testBothApproachesForEachIntent` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testBusinessJulesJourneyAndReentry` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testCaptureApprovedScreensAndOverlays` | `assertScreen`, `assertOverlay`, `softlyColumn` |
| `WaveReviewTests/testDuplicateAndStaleActionsChangeNothing` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testEdgeSwipesFollowTheVisibleBack` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testInterruptedAcceptanceNeverEndsJoined` | `assertScreen` |
| `WaveReviewTests/testLargestTextKeepsWaveScreensReachable` | `assertScreen`, `assertUnclipped`, `assertReachableButton`, `assertReachableDisabledButton` |
| `WaveReviewTests/testLeaveFromEveryWaveContext` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testRealJourneyFromTheRoomProfileThroughTheWaveAndBack` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testReduceMotionPreviewAcceptJoinsWithoutAMove` | `assertScreen` |
| `WaveReviewTests/testRolesNeverChange` | `assertScreen`, `assertOverlay` |
| `WaveReviewTests/testLargestTextKeepsWavePanelsReachable` | `assertUnclipped`, `assertReachableButton`, `assertReachableDisabledButton` |

### Local validation actually performed

All checks use the new review/candidate paths. Native XCTest/SwiftUI compilation, simulator behavior, rendering and speed remain unverified for this candidate.

```sh
swiftc -frontend -parse ProximeetUITests/RoomReviewTests.swift ProximeetUITests/WaveReviewTests.swift
python3 -B scripts/generate_project.py --check
python3 -B scripts/validate_project.py
env CLANG_MODULE_CACHE_PATH=/home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/domain-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/domain-swift-cache swift test --package-path ProximeetDomain --scratch-path /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/domain-build --cache-path /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/swiftpm-cache --config-path /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/swiftpm-config --security-path /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/swiftpm-security
python3 -B review/test_inventories.py
python3 -B review/aggregate_native_log_audit.py
python3 -B review/audit_room_equivalence.py
python3 -B review/wave_equivalence_audit.py
python3 review/run_room_snapshot_harness.py
python3 review/run_wave_snapshot_harness.py
python3 -B review/finalize_review.py
git apply --check /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/aggregate-ui-harness.patch  # immutable new baseline cwd
git apply --reverse --check /home/proximeet/proximeet-aggregate-harness-review-qq_hfhss/review/aggregate-ui-harness.patch  # new candidate cwd
```

The first four commands run from candidate; review-prefixed commands run from the new root. Evidence audit uses its recorded local roots and exports. Source syntax PASS; generator up-to-date; project validator 13 checks/0 failures; Linux package 258 tests/0 failures. Existing unused-result warnings are in unchanged domain tests. Inventory normalization initially needed to strip () from three skip identities; the corrected reproducible checker verifies Main250+8D2 and does not alter plans/source.

Independent equivalence audits pass. The Room Swift6 strict-concurrency/warnings-as-errors harness extracts 52 declarations/helpers and covers all 48 facade properties/three indexed helpers, panel duplicate/nested/first-container/root scope, five identifying properties, all blocked sets, current state/report selection, fresh largest items/live hittability, missing/snapshot-error behavior and original Notes diagnostics. The Wave harness covers its original facade plus column/largest helpers, baseline passing-access counters with lazy XCTest messages, local freshness, errors/scopes/metadata and unchanged source catalogs. Both compile caches are isolated under this review. Harness-only setup fixes are recorded in their JSON results; production source was not changed by those fixes.

Patch forward/reverse checks and isolated application reproduce all candidate hashes/modes/sizes. Final manifests verify unchanged baseline/prior roots,339 untouched candidate files,all test-plan/RunBudget/native-hook paths and exact prior report prefix. Full logs/exact subprocess command vectors accompany the review bundle. Linux stubs and operation counts do not prove Apple SDK semantics, native behavior or speed.

### Bounded representative native proposal

This is for coordinator review and has not been executed. The canonical matrix is native-regression-matrix.json; earlier per-agent proposals are source-audit suggestions only. Freeze the complete ending inventory, use candidate-owned products/evidence and a fresh equivalent440×956 default-text iPhone simulator per serial selected invocation. Keep the unchanged WaveVerificationMain plan/flags, all source-requested allowances and the6240 RunBudget. No default/maximum override,retry,parallelism,skipped identity or altered fixture. Rebuild fresh products (external cap600 seconds); reserve300 seconds total for setup/hashing/exports.

Each selected identity runs once, with all its original scenarios. Outer caps below are hard diagnostic invocation ceilings chosen around retained mixed historical times and overhead; they do not change internal900/1200 allowances. Stop at first assertion failure, test/guard failure or external-cap exhaustion. Preserve partial evidence as failure; do not retry or continue a known failing gate. Five UI caps total8600 seconds; build/setup/export ceiling900 gives a combined proposed9500-second ceiling (158min20s). This proposal is distinct from the unchanged strict full Main/Small9600-second compute contract.

| Batch | Complete selected identities | Outer cap | Changed paths checked |
| --- | --- | --- | --- |
| A | `RoomReviewTests/testCaptureApprovedStatesAndOverlays`, `RoomReviewTests/testEntryNeedsBothDeliberateGates`, `RoomReviewTests/testBusinessCompatibility`, `RoomReviewTests/testReportPreviewIsLocalAndRestoresItsCaller` | 1900 s | all Room settled states/panel scopes/columns; still waiting; Wave-menu crossing and same/other intent; report selection/closing/reopening |
| B | `WaveReviewTests/testCaptureApprovedScreensAndOverlays`, `WaveReviewTests/testBothApproachesForEachIntent` | 1900 s | all Wave screens/overlays/control rows/rings/columns; both intent and approach rows |
| C | `RoomReviewTests/testLargestTextKeepsRoomReachable`, `WaveReviewTests/testLargestTextKeepsWaveScreensReachable`, `WaveReviewTests/testLargestTextKeepsWavePanelsReachable` | 1800 s | fresh post-reveal text and enabled button snapshots; disabled buttons; overlap assertions; actual largest-text Leaves/Places/Signal |
| D | `RoomReviewTests/testNotesFilteringAndBothBlockOrders`, `WaveReviewTests/testLeaveFromEveryWaveContext` | 1500 s | preserved Notes 34 pages/34 pixel notes/39 elapsed diagnostics/four stages/eight captures; all 18 Leave contexts/final completion/no-prompt/person/invitation/destinations |
| E | `RoomReviewTests/testReduceMotionPreviewRoom`, `WaveReviewTests/testRealJourneyFromTheRoomProfileThroughTheWaveAndBack`, `WaveReviewTests/testReduceMotionPreviewAcceptJoinsWithoutAMove`, `WaveReviewTests/testRolesNeverChange` | 1500 s | unchanged Room/Wave animation and pixel sampling followed by changed state checks; real journey/focus handling; all role matrix assertions |

Use xcodebuild test-without-building with project Proximeet.xcodeproj,scheme Proximeet,testPlan WaveVerificationMain,parallel-testing-enabled NO,CODE_SIGNING_ALLOWED=NO,new destination/DerivedData/resultBundle paths, and one -only-testing:ProximeetUITests/<identity> argument per selected row. Build-for-testing uses the same plan/destination and separate new DerivedData. External watchdogs must record termination/timeouts; caps never turn partial completion into success.

Require exact selected start/pass sets,no skips/failures/expected failures/retries/runtime warnings,all original captures/pixel assertions and scenario diagnostics. For Notes require all 34 numeric pixel notes/39 elapsed records/four completions/eight captures/both launches/orders; for Wave Leave require every one of18 contexts and the final completion table/destinations/no-prompt/absence checks. Motion validation requires numeric anchor/sample/control pixel evidence at the specified geometry; an explanatory note alone does not satisfy it. Export console,summary/tests JSON and preserve raw xcresult and candidate hashes.

This15-identity proposal covers every changed helper path and the earlier selected corrections; ten other affected callers remain broader regression work. Before projecting another Main attempt, measure all 25 affected identities from this candidate and retain explicit provenance for the five unchanged-source identities. A new disjoint estimate still does not prove full-run success. Require headroom for runner/start/finish overhead,native variance,whole-minute allowance rounding and the60-second minimum-start rule; if the projected current total is over6240,stop and report the residual gap.

Strict successful Main280 and Small7 invocations remain open separately, each with every original identity once and no failures/skips/retries/expected failures/omissions/RUN_BUDGET_SPENT. Preserve Main6240/Small2160 and the original total9600 compute bound including two600-second action allowances. Preserve D2_BEGIN,eight native D2_PASSED records and successful D2_RESULT. Broader regressions and physical VoiceOver remain open. No selected measurement,source audit or Linux result substitutes for these gates.


## Guest List keyboard accessory workaround candidate — 28 October 2026

Status: isolated candidate prepared for native evaluation, not an adopted correction or a delivered build. The published aggregate harness branch remains unchanged.

The unchanged diagnostic prefix passed with the debugger detached and reproduced `Invalid frame dimension (negative or non-finite).` exactly once. Runtime UUID-matched symbolication identifies SwiftUI `InputAccessoryBar.body.getter` calling SwiftUICore `_FrameLayout.init(width:height:alignment:)` during keyboard accessory intrinsic sizing. The app frames resolve only to generated entry points. No offending numerical dimension or causal app arithmetic was captured; the evidence does not justify a negative-padding correction.

Three separate narrower candidates were rebuilt and each passed this diagnostic while retaining the same exact warning: removing Guest List's toolbar Spacer; guarding Birthday's toolbar by the current scene; and registering Guest List's toolbar only while a field is focused. The Spacer removal additionally moved Done from trailing to centered. These variants are rejected as standalone warning corrections and are not combined here as unexplained fixes.

This candidate bypasses Guest List's SwiftUI keyboard accessory contribution. A native Done Button retains its action and accessibility identifier in a separately reserved trailing bottom safe-area row, shown while either field is focused. Its label has a minimum 44-point target. The existing actions sit above that row, with an 8-point gap replacing the obsolete 36-point allowance for the floating accessory. Birthday retains its original toolbar while Birthday is current; the scene guard prevents that retained screen from contributing an accessory after navigation to Guest List.

The native Done text row intentionally differs from the system floating capsule. At ordinary text size, its 44-point row replaces 36 points of floating-toolbar clearance. The existing unfocused rest-padding expression remains exact, but native unfocused-layout equality has not yet been measured. No keyboard-height subtraction, overlay, logging suppression, warning filter change, or keyboard safe-area override is introduced.

All original aggregate UI tests, assertions, test plans, time allowances, app interactions and assets are unchanged. The old diagnostic-prefix additions from R15 are not part of this production-source candidate. Reports remain append-only.

Pending native evidence: rebuild the exact app change in an isolated diagnostic copy and run the same detached prefix once with passive warning collection. If that succeeds, verify actual Done activation/identifier/placement, Name and Introduction editing, Return progression, multiline input, dismissal/reopening, Back separation, hardware keyboard behavior, small-screen/largest-text reachability and the three affected real journeys. Preserve failures and do not count diagnostic prefix passes as full-journey or aggregate verification.

Strict successful Main280/Small7 invocations, the eight native D2 checks, physical VoiceOver, visual approval and build delivery remain separate open gates. No measured warning resolution, production readiness, TestFlight upload or new delivered build is claimed by this candidate preparation.

Source preparation: exact edits are recorded in the accompanying `source-forward.diff` and SHA-256 inventory. Native diagnostic evidence remains on the rented Mac. Local receipts summarize observed results; no blocked diagnostic archive was transferred or reconstructed.


### Diagnostic result recorded before production-source regression

The same app edits were rebuilt natively in the isolated R15 diagnostic copy. Build exit 0 (23.1568 s); selected test exit 0 with a valid xcresult, exactly one passed test, zero failed/skipped tests. The 143.9353-second coordinator completed normal result finalization. Passive logging started before test launch and recorded zero exact invalid-frame warnings through the complete 15-second post-tap observation and test completion; test stdout also contained zero. In contrast, the unchanged source and each of the three narrow toolbar variants recorded one warning in the same prefix. This supports this workaround for that reproduction, not a general warning-free or full-journey claim.

The screenshot was inspected by both the native controller and root through the Mac image reader: software keyboard, Name caret and one trailing plain Done row are visible, with separation from Back. The screenshot was not copied into the workspace. The prefix does not activate Done, type the introduction or validate hardware keyboard/VoiceOver. Those remain pending.

Native result root: `/Users/user299580/ProximeetDiagnostics/guest-list-safearea-detached-20261028-13163d4b`. Diagnostic coordinator SHA-256: `4f08025b8cb3902804faf42f5d6a4e6c0b339f5f84b7d45a383d30fbf09bcd86`. Observed result receipt is `native-log-capture/safearea-ab-20261028/observed-outcome.json` in the coordinator workspace; raw evidence remains on the Mac.

Exact completed selected-test command (the owned simulator was subsequently shut down and deleted):

```sh
xcodebuild test-without-building -xctestrun /Users/user299580/ProximeetDiagnostics/guest-list-safearea-detached-20261028-13163d4b/Diagnostic.xctestrun -destination platform=iOS\ Simulator,id=2C1FB8B1-5AAC-4250-817B-0B6EAF32EF85 -resultBundlePath /Users/user299580/ProximeetDiagnostics/guest-list-safearea-detached-20261028-13163d4b/Diagnostic.xcresult -parallel-testing-enabled NO -only-testing:ProximeetUITests/WaveReviewTests/testDiagnosticGuestListNameWarningPrefix
```

This complete production-source candidate retains the original aggregate Room/Wave test bytes instead of R15's diagnostic additions. Its app-file hashes match the warning-free prefix: GuestListView `9880af521372f3d77c1d61e0dfcd0a5d888c3550951cade45877732df980a5c2`, BirthdayView `23482ca2a4937cacfbefc8ae4ccfc844f6255bbe38f571729260a419f0d69e49`. Of 342 baseline files, only those two app files and this appended report differ; the other 339 remain byte-exact.

Next is an explicit WaveVerificationMain build and a separately named derived xctestrun selecting existing Birthday/Guest List software tests. Canonical plans remain byte-exact: they do not include those classes, and merely adding command-line only-testing filters does not establish they ran. Preserve native default900/maximum1200 allowances, review flags and guard values; compare actual start/pass identities and reject zero/skipped/retried tests or fallback-only Done evidence. Successful full Wave Main280 will cover the three original affected journeys without redundant selected reruns; Small7, eight native D2 identities and a separate hardware-keyboard invocation remain required. Do not label the previous harness-only published commit as this modified app candidate, or claim an unset-environment D2 hook exit as a native D2 pass.


### Birthday typed-entry recurrence and expanded candidate

The first selected regression on the complete original-test candidate, `BirthdayReviewTests/testTypedEntryPreservesComponentsAndKeyboard`, completed a valid one-test pass with xcodebuild exit 0 in a 200.48-second invocation. Its passive log retained two exact invalid-frame runtime Faults with the same SwiftUICore/SwiftUI offsets and InputAccessoryBar stack. Activities resolve the real `birthday.keyboardDone` control and keyboard dismissal, rather than merely falling back to Return. The software-regression sequence stopped at this warning gate before its second identity. That passing functional result is not a warning-free pass and is retained against the prior source snapshot.

This new isolated candidate extends the same native Done-row approach to Birthday typed entry. It removes Birthday's keyboard ToolbarItemGroup and places the original submitTyped action and birthday.keyboardDone identifier in a trailing, focus-conditional safe-area row with a minimum 44-point target. The row belongs to Birthday's scroll view; it adds no global toolbar contribution on subsequent screens, so the earlier active-scene toolbar guard is no longer needed. Wheel entry, mode switching, birthday validation, drafts, announcements, Return submission and navigation action bodies remain unchanged. The Guest List app file is byte-exact to the warning-free prefix candidate.

This is a new code candidate, not a retry of the unchanged failed warning gate. Rebuild once, then run the same five existing software/Birthday identities once each in separate invocations under their original 900/1200-second native allowances, 1200-second external caps and a separate 6600-second focused-phase ceiling. Stop at a failing execution/result/preservation or runtime-fault gate. Canonical plans and original tests remain unchanged. Actual Birthday layout, submission and warning behavior for this expanded candidate are pending; do not infer them from source inspection. The prior diagnostic, failed warning gate, candidate and reports remain preserved.


### Isolated largest-text property-read experiment — 28 October 2026

This is a separate complete performance candidate based on the pinned two-app-file keyboard Done workaround candidate. It changes only `ProximeetUITests/RoomReviewTests.swift`, `ProximeetUITests/WaveReviewTests.swift` and this report append. Production source, existing native products, app behavior, plans and budgets are not modified by its preparation. No native run or measured speed improvement is claimed.

The authoritative `Proximeet-Aggregate-Native-Verification-20261002.zip` has SHA-256 `ba0f57304cc2f3c3bad0156577e6f70af8b38915448ac6f148f9b9ac74908e7a`. Its reviewed Room/Wave test bytes match this candidate's starting test files. BatchC retained durations were Room largest text 528.549768 s, Wave largest screens 600.142262 s and Wave largest panels 216.853696 s. Timestamped native logs repeatedly show a separate target-property lookup after a fresh reveal reading; for example Wave global-safety title t10.30→11.59 s and explanation t11.70→13.03 s. These intervals justify an isolated experiment, not an extrapolated saving or full-suite projection.

Both `readElementForAssertion` helpers now obtain one fresh `app.snapshot()` at exactly the previous property-read boundary. They walk its descendants in the existing audited preorder, excluding the application root, and return the first match across identifier, title, label, String value and optional placeholder. Non-String values remain empty as in the existing adapters. The five callers all use unscoped `app.descendants(matching: .any).matching(identifier:).firstMatch`; no panel-scoped or typed query is routed through the replacement. Matching scope/type and first-descendant ordering therefore remain the same as those audited adapters. Missing lookup throws the existing snapshot-lookup error and reaches the unchanged catch/XCTFail/nil path. Snapshot errors still fail. There is no live-query fallback or default-geometry success.

Text and disabled-control reads remain after `reveal`; enabled-control reads remain after both `reveal` and its existing live `isHittable` assertion. Reveal's own movement samples, settling checks, 40-look bound, drag geometry, live waits, tap spacing and failure paths remain exact. No snapshot is carried across an item, gesture, wait or transition. Screenshot/pixel operations and all original test bodies, assertion expressions, captures and action sequences remain unchanged. This experiment deliberately does not consolidate other snapshots, reduce holds, change allowance values or edit app files.

Affected existing identities are exactly:

- `RoomReviewTests/testLargestTextKeepsRoomReachable`: its text/button loops call `assertUnclipped` and `assertReachableButton`, the only two Room callers of the changed lookup.
- `WaveReviewTests/testLargestTextKeepsWaveScreensReachable` and `WaveReviewTests/testLargestTextKeepsWavePanelsReachable`: both call `checkAtLargestText`, whose three item cases call `assertUnclipped`, `assertReachableButton` and `assertReachableDisabledButton`, the only three Wave callers. The extra Leave proofs and all unrelated helpers remain unchanged.

Local verification command: `python3 -B scripts/validate_project.py --no-plutil`, run in the isolated candidate, exited 0 with all 13 project checks passing. This validates project consistency, not Swift/XCTest compilation. `swiftc` is unavailable in the local environment; no syntax/type-check or Linux domain-test result is claimed. The adjacent review receipts record exact source/candidate hashes, 27 original test-body preservation, unchanged assertion/failure expressions, allowed-edit normalization, complete 342-file comparison and forward/reverse patch reproduction. The original report text remains an exact prefix. An independent source reviewer found no blocking issue in the two helper changes and five call sites; native equivalence remains unverified.

First proposed native experiment: rebuild this isolated candidate once, then run the unchanged `WaveReviewTests/testLargestTextKeepsWavePanelsReachable` once, selected explicitly from WaveVerificationMain on the verified 440×956 destination used for the retained comparison. Preserve that test's original 900-second default, all runtime guards, no-retry policy, captures and controls; its existing test body asks for no allowance extension. Use the coordinator's existing bounded build and invocation controls, unique products/results and complete passive warning collection. The actual destination, build paths and source revision must be recorded at execution; no ready-made command here invents them. Stop on failure, warning, missing evidence or changed source. Compare actual per-item property-read activity and the complete native duration with the retained 216.853696 s observation while disclosing toolchain/device differences. Source counts or a passing local check are not speed measurements.

Room largest text and Wave largest screens remain separate affected native regressions if the first experiment supports continuing. Historical and mixed timing rows still do not establish Main6240 feasibility; all missing affected coverage, invocation overhead, strict Main280/Small7, native D2 and physical VoiceOver gates remain separate. The prior software diagnostic outcomes and all previous evidence remain unchanged by this performance candidate.


### Focused production-source keyboard regressions — 28 October 2026

The expanded Birthday and Guest List Done-row candidate completed seven selected native software-keyboard scenarios: five on a 440-point-wide iPhone and two distinct 390 × 844-point small-screen scenarios. Every scenario ran once and produced a valid passing xcresult, one exact start/pass identity, and zero failures, skips, expected failures, retries, exact invalid-frame warnings or captured app runtime issues. These are selected regressions, not canonical WaveVerificationMain or WaveVerificationSmall executions.

| Original test identity | 440-point invocation | 390 × 844 invocation |
| --- | ---: | ---: |
| `BirthdayReviewTests/testTypedEntryPreservesComponentsAndKeyboard` | 178.8094 s, passed | 164.2371 s, passed |
| `BirthdayReviewTests/testWalkthroughEntryCorrectionContinueBack` | 224.6295 s, passed | Not selected |
| `GuestListReviewTests/testKeyboardFocusOrderReachabilityAndDismissal` | 186.8352 s, passed | Not selected |
| `GuestListReviewTests/testKeyboardDoneAndBackStayIndependent` | 187.4094 s, passed | 193.8373 s, passed |
| `GuestListReviewTests/testKeyboardBackOnTheRealRouteReturnsToTheCompletePass` | 159.1449 s, passed | Not selected |

The fresh production WaveVerificationMain build completed with exit 0 in 22.9585 seconds. The five-test phase completed through cleanup in 1,385.2698 seconds against its separate 6,600-second ceiling. The small-screen phase completed through final review in 685.8753 seconds against its separate 3,000-second ceiling and reused the verified production products. Original native default/maximum allowances of 900/1,200 seconds and all other generated xctestrun fields were preserved; each separately named derived selection changed only UI `OnlyTestIdentifiers` and used a matching command-line filter. The canonical plans and original test source remained unchanged.

Native activities resolved the actual `birthday.keyboardDone` and `guestList.keyboardDone` controls and their tap event synthesis. Birthday's typed-entry scenario recorded three software-keyboard dismissals on each size without Return fallback. Guest List preserved the name and multiline introduction, Return focus progression, independent Back behavior and the complete Pass on the real Back route. Its Done target measured 44 × 44 points with an 8-point gap from Back at both sizes. Small-screen profile, app captures and the app-width note established 390 × 844 points; the queried default content size was `large`. Keyboard captures were visually reviewed on the Mac.

All seven scenarios used production app files with SHA-256 Birthday `9cdf0f12f66029b0d8c4f984b5bd98ea60eef20960da3083e249a0293e5f7220` and Guest List `9880af521372f3d77c1d61e0dfcd0a5d888c3550951cade45877732df980a5c2`. The report stayed pinned throughout at `6853e096d5ff44221f38a539c206539b903b6fb6a9cc873405a4d4085f895c73`. This results append is subsequent documentation, not a claim that the earlier runs used its later report hash or a later Git commit. The other 339 aggregate-baseline files remained byte-exact. Source preservation and cleanup were verified after each invocation; the pre-existing user simulator was preserved.

Raw native evidence remains under `/Users/user299580/ProximeetDiagnostics/keyboard-done-production-20261028-29ab574c` on the Mac, in `focused-software-1` through `focused-software-5` and `small-software-1` through `small-software-2`. The exact executed command vectors are retained in the native coordinator receipts. Local observation summaries are `native-log-capture/keyboard-done-regression-20261028/five-test-observed-summary.json` and `native-log-capture/keyboard-done-small-20261028/two-small-test-observed-summary.json`, with separate receipts for every invocation. No raw diagnostic archive was transferred or reconstructed.

At this checkpoint the separate diagnostic software probes for interactive dismissal and largest text on Birthday and Guest List remain pending. Those probes use an isolated diagnostic test copy and earn no canonical Main280/Small7 coverage. Hardware-keyboard behavior, physical VoiceOver, unfocused visual equivalence, founder visual approval, native D2, strict full Main280/Small7 verification and new signed build delivery remain unproven by these seven scenarios. A warning-free observation in the exercised scenarios is not a general warning-free-app claim.

Aggregate runtime readiness also remains open. The authoritative aggregate-native bundle dated 2 October records 14 of the 25 affected Room/Wave identities measured, with a 3,964.943887-second test-duration sum. Its mixed replacement-only ledger totals 8,821.032885 seconds across the 30 historical Main UI rows, 2,581.032885 seconds above the unchanged 6,240-second guard before overhead; this is bookkeeping, not a current-app forecast. Eleven affected identities still lack measurements from the optimized harness. The seven keyboard scenarios overlap none of those 25. The fourteen measurements predate these app edits and retain that provenance; the three historical Places/Room/Wave full journeys retain their warning findings. The earlier expectation that full Main alone could cover all three journeys remains conditional on the separate coverage, timing, overhead and headroom gate, which this focused phase does not satisfy.



### Subsequent diagnostic keyboard evidence — 28 October 2026

This section updates the pending diagnostic statuses in the earlier seven-result checkpoint. Diagnostic methods live only in separate diagnostic source copies and are not included in this publication. The production app hashes remain Birthday `9cdf0f12f66029b0d8c4f984b5bd98ea60eef20960da3083e249a0293e5f7220` and Guest List `9880af521372f3d77c1d61e0dfcd0a5d888c3550951cade45877732df980a5c2`.

`BirthdayReviewTests/testDiagnosticDoneInteractiveDismissalKeepsUncommittedBirthday` passed once, with a valid one-test result, exit 0 and a 170.753060-second invocation. Exact invalid-frame warnings and captured runtime events/Faults were zero. On the verified 390 × 844-point app, one drag from (16,462) to (16,804) was followed by keyboard absence, no Done row, the uncommitted date 12/5/1997 retained and Continue still disabled. Refocusing restored the year caret, keyboard and Done; an actual `birthday.keyboardDone` tap then dismissed the keyboard/row and enabled Continue. This establishes the observed post-drag and final-action states, not continuous keyboard tracking or direct focus-state introspection. The diagnostic build exited 0 in 23.911876 seconds. Evidence: `native-log-capture/keyboard-done-diagnostics-20261028/diagnostic-1-observed-outcome.json`; native result root `/Users/user299580/ProximeetDiagnostics/keyboard-done-diagnostic-20261028-61be3c42/diagnostic-software-1`.

The first `GuestListReviewTests/testDiagnosticDoneInteractiveDismissalKeepsGuestDraft` attempt is retained as a failure: xcodebuild exit 65, one failed test, 147.120993-second invocation. Its proposed start (16,315) failed `The drag starts inside the scroll view.` before any drag was synthesized. The original attempt did not capture that scroll frame or export a screenshot. Runtime warnings/events/Faults were zero. It therefore does not establish a Guest List dismissal failure or success. The sequence stopped, and the result was preserved at `native-log-capture/keyboard-done-diagnostics-20261028/diagnostic-2-observed-outcome.json`, with native result root ending `61be3c42/diagnostic-software-2`.

The corrected isolated diagnostic selects the unique scroll owner of the actual Guest List fields instead of relying on the first scroll view in the accessibility tree. Its observed owner frame was (0,0,390,844); a separate non-owner scroll view measured (0,509,390,44). This supports the new diagnostic's ownership basis without retroactively inventing the old attempt's unrecorded frame. The app files and all original test bodies were unchanged by the diagnostic correction.

That corrected Guest interactive invocation passed once with a valid one-test result, exit 0, 193.979215 seconds, zero exact warnings and zero captured runtime events. One actual drag from (16,191) to (16,804) was followed by keyboard/Done absence with `Alex` and `Keep this draft.` and the route preserved. Refocusing showed the opener caret, software keyboard and trailing Done separate from Preview and Back; one exact `guestList.keyboardDone` tap passed the final keyboard/Done absence assertions. Done measured 44 × 44 points with the previously observed 8-point separation from Back. The replacement diagnostic build exited 0 in 23.536959 seconds. This is a corrected probe with a different ownership mechanism, not a silent repeat of the unchanged failing probe. Evidence: `native-log-capture/guest-geometry-diagnostics-20261028/interactive-observed-outcome.json`; native result root `/Users/user299580/ProximeetDiagnostics/guest-geometry-diagnostic-20261028-d5a9c6e1/guest-software-1`.

`BirthdayReviewTests/testDiagnosticLargestTextBirthdayDoneIsReachable` passed once with a valid one-test result, exit 0 and a 204.256943-second invocation; exact warnings and captured runtime events/Faults were zero. On 390 × 844 points, headline height grew from 135.666672 to 373 points, the numeric fields and year caret were visible, Done measured approximately 120.667 × 63.333 points and its exact control was activated once. The commit and reachable-Continue assertions passed. Larger visible text and measured headline growth support that the larger presentation was applied; this is not independent app category-enum introspection. Evidence: `native-log-capture/keyboard-done-largest-20261028/birthday-largest-observed-outcome.json`; native result root ending `61be3c42/largest-software-1`.

The lead's largest-text Birthday screenshot review also observed top copy behind the status bar. A same-scenario baseline has not been established, so this observation is not classified as either a new regression or a pre-existing condition. The focused control assertions and screenshots are not whole-screen visual approval. Physical VoiceOver and hardware-keyboard behavior remain untested by these software probes.

At preparation of this publication copy, `GuestListReviewTests/testDiagnosticLargestTextGuestDoneIsReachable` was still running in the corrected diagnostic root at `guest-software-2` (controller PID 97919). No result, timing, warning-free claim or visual approval for that invocation is asserted here. Its completed observation must be appended separately before the final publication manifest is frozen. The separate staging slot is outside tracked source.

All completed diagnostic invocations retained their native results and screenshots on the Mac, verified owned-simulator cleanup and preserved the production inventories and pre-existing user simulator. No raw evidence archive was transferred or reconstructed. Diagnostic-only passes earn no Main280/Small7 credit.

### First native largest-text helper experiment result

The combined performance candidate retains both app fixes and changes only the two narrow Room/Wave property-read helpers described above, plus this append-only report. Its fresh native build exited 0 in 24.164859 seconds. `WaveReviewTests/testLargestTextKeepsWavePanelsReachable` then started and passed exactly once with xcodebuild exit 0 and a valid one-test result. The actual xcresult test duration was 191.813725 seconds, versus the retained 216.853696-second observation: 25.039971 seconds lower (11.546942%). These are different-day single observations, not a paired same-day baseline or an isolated causal speed estimate.

All 14 captures were retained at 1320 × 2868 pixels, matching 440 × 956 points. Exact invalid-frame warnings and captured runtime events/Faults were zero. The original RunBudget record was `0 s of6240 s; allowance900 s`; live button lookup and all original guards/captures remained. Adjacent activity timestamps for the global-safety title were 17.95→18.10 seconds and explanation 18.24→18.45, compared with retained 10.30→11.59 and 11.70→13.03 intervals. These are neighboring XCTest activity timestamps, not isolated profiler measurements. No target-specific title/explanation lookup lines appeared, live button lookup remained, and 84 scroll diagnostic lines were retained.

The invocation coordinator took 303.027334 seconds; the phase took 486.379185 seconds against its 2,400-second ceiling. The observed toolchain was Xcode 26.6 (17F113), macOS 26.3.1 and iOS 26.5 (23F77). Cleanup, all current source inventories and the old diagnostic inventory were verified. Evidence: `native-log-capture/keyboard-done-performance-20261028/observed-outcome.json`; native root `/Users/user299580/ProximeetDiagnostics/keyboard-done-performance-20261028-e7b4a318`.

This supersedes the earlier experiment-preparation statement that no native run existed. It covers one of the three affected largest-text identities. `RoomReviewTests/testLargestTextKeepsRoomReachable` and `WaveReviewTests/testLargestTextKeepsWaveScreensReachable` remain pending on these helper changes. No global speedup or Main6240 fit is inferred, and the earlier mixed duration ledger remains historical bookkeeping rather than a forecast for this combined candidate. Full Main280/Small7, native D2, remaining coverage/overhead/headroom reconciliation, hardware keyboard, physical VoiceOver and whole visual approval remain open.

### Internal build delivery status

An internal build may support founder review and physical-device checks while the remaining QA gates are openly tracked. It would not itself establish full verification or visual approval. The supported local-export alternative under review is a temporary export-options plist outside tracked source with `manageAppVersionAndBuildNumber=true`, retaining internal-only distribution, the existing team and symbol options. Xcode may then manage the uploaded build number, which must be read from the actual resulting archive/upload receipt rather than guessed. No source version/build-number change is part of this publication payload.

The Apple browser session remains unavailable at this checkpoint. Current signing/account access, successful archive/export/upload, Apple processing and internal-group distribution are unverified. No new signed build, TestFlight availability or installation is claimed. No signing credentials or account secrets were read or included in this source.

### Completed corrected Guest largest-text evidence and local source freeze — 28 October 2026

This append completes the Guest result that was still running at the preceding staging checkpoint; the earlier text and the original failed diagnostic remain unchanged. `GuestListReviewTests/testDiagnosticLargestTextGuestDoneIsReachable` started and passed exactly once, with xcodebuild exit 0 and a valid one-test result, in a 331.458572-second invocation. Exact invalid-frame warnings, captured runtime issue events and runtime issue Faults were all zero. Its native result root is `/Users/user299580/ProximeetDiagnostics/guest-geometry-diagnostic-20261028-d5a9c6e1/guest-software-2`; the observed receipt is `native-log-capture/guest-geometry-diagnostics-20261028/largest-observed-outcome.json`.

On the verified 390 × 844-point app, headline height increased from 117.506653 to 184.78 points. Two actual Q insertions and their deletions restored the exact original drafts while the software keyboard remained present during editing. Both exact `guestList.keyboardDone` activations passed. Done measured approximately 120.667 × 63.333 points at (237.333,445.667), distinct from Preview at (32,218,326,144.333) and Back at (32,370.333,326,67.333); the keyboard frame was (0,553,390,233). The unique scroll owner measured (0,0,390,844). The corrected diagnostic identifies that owner as the unique ScrollView ancestor of both exact input-field identifiers, instead of assuming the first ScrollView owns the form. This ownership change belongs only to the diagnostic test copy; the app files and original test methods remain exact.

All 11 captures were retained at 1170 × 2532 pixels. The inspected typed-Q captures showed the caret/input, software keyboard and distinct Preview/Back/Done controls. Name was fully exposed; the multiline opener frame (49,57,294,188) had an asserted visible editable region (49,62,294,131), while lower opener content could lie behind the footer. These observations establish real editing and reachable controls in the inspected states, not full multiline containment or whole-screen parity. Measured headline growth supports the larger presentation, without independently reading the app's category enum. The previously recorded Birthday largest-text copy behind the status bar remains an unresolved visual observation with no same-scenario baseline; neither visual limitation is erased by a passing probe.

The corrected Guest phase built once (exit 0, 23.536959 seconds) and ran two selected invocations: interactive dismissal in 193.979215 seconds and largest text in 331.458572 seconds. Both passed; the phase took 764.078480 seconds within its 3,600-second cap. The phase receipt is `native-log-capture/guest-geometry-diagnostics-20261028/phase-observed-summary.json`. Owned simulators were removed, no native jobs remained, production/prior diagnostic inventories and the preceding performance inventory were unchanged, and the user's existing simulator state was preserved. Raw native evidence remains on the Mac; no raw archive transfer is claimed.

The keyboard evidence now comprises 11 accepted software scenarios: five original scenarios at 440 points, two original scenarios at 390 points, and four separate diagnostic scenarios (interactive dismissal and focused largest text on each screen). This is a scenario count, not 11 distinct original test identities. The first Guest interactive diagnostic remains a separate failed invocation (exit 65, 147.120993 seconds) whose geometry guard stopped it before a gesture; the corrected probe does not rewrite that result. The separate Wave largest-panels performance pass is not included in this keyboard total. Diagnostic-only scenarios earn no canonical Main280/Small7 credit.

This final staging step changes only the report after the already reviewed four app/test files. The complete 342-file inventory and Git modes are recomputed against the retained published tree for `01968680e5d3c1d7f5a993b58e5a71eb0b1d1b12`, preserving the five-path publication scope and the executable mode of `scripts/signal_review.sh`. The resulting commit is a local candidate, not a published revision or delivered build. Remote publication of the two app files is blocked by automatic approval review because the recorded explicit GitHub authorization covers RoomReviewTests.swift, WaveReviewTests.swift and task01.md. No alternate transfer is attempted.

Room largest-text and Wave largest-screens regressions on the helper changes, current aggregate coverage and overhead/headroom reconciliation, strict Main280/Small7, native D2, hardware-keyboard Done and the separate original Tab scenario, physical VoiceOver, and whole visual approval remain open. Signing/account access, actual archive/export/upload and its build number, Apple processing and internal distribution also remain unverified. No new signed build, TestFlight availability or installation is claimed.


### Four private invitation designs — 29 October 2026

The owner approved the four-screen visual proposal and requested implementation and the next build. This candidate starts from the complete 342-file tree of the published keyboard-Done build (`d033e533b6695ab70a2f7c36f955cd6554f5438b`, tree `8104201453b86597ed5206c12377af8073526b3e`). The previous candidate and its successful TestFlight 0.1.0 (9) delivery remain preserved.

The invitation now has Business stationery, Social conversation bubbles, Activity terrain/trail markers, or Dating rings, with each intent's semantic color and approved outgoing copy. All artwork is native SwiftUI decoration. The recipient-choice line, DEMO disclosures, sender/recipient identities and existing invitation lifecycle remain explicit. See `docs/design/private-invitations-20261029.md` for the approved copy and implementation decisions.

To make all four designs reachable in this demo, Common Ground now permits all four intents. The existing Social/Business sample pair is preserved; Activity/Dating have a separate Sam/Riley pair. Actual intent, open-session eligibility, same-intent invitation and recipient-consent checks remain. No network, live invitation delivery, group membership or Chat + Keep capability was added.

Source implementation, local project validation, native compilation, native UI behavior, screenshot review and upload are reported separately. At this initial report append, implementation is present and native verification is starting; no new build/upload success is claimed. The later receipt will name the actual tested source manifest and uploaded build number. Historical reports and pending gates above are retained as history, not rewritten into current evidence.


### First native invitation verification and targeted corrections — 29 October 2026

The first complete invitation candidate contained 346 files. Its payload SHA-256 was `6f1e1902d9c553b351316c64c38b002418fb9ed14fae053a67a1dc48ee5be479`; the retained native root is `/Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final`. All 13 project checks passed. The native pure-Swift suite passed 263/263 in a 14.5-second command; native build-for-testing exited 0 in 24.0 seconds. An earlier domain snapshot had one old eligible-intent count assertion (2 instead of 4); changing only that expected count preserved the route loops and resolved it. The early failure remains retained.

The four-test large-device invocation exited 65 in 501.59 seconds: `WaveReviewTests/testRealJourneyFromTheRoomProfileThroughTheWaveAndBack` passed in 287.374 seconds; both new focused tests stopped at the strict Business artwork `children.isEmpty` assertion, and the adapted Dating Reduce Motion test failed its final bright-ring probe (0.228395, required >0.5). No captured runtime issue or invalid-frame warning occurred. All 346 candidate and 342 baseline files were unchanged; the owned simulator was deleted. This is one passed journey and three failed tests, not a successful four-test verification.

The next revision explicitly hides the decorative briefcase SF Symbol leaves, retains the strict artwork assertions with diagnostic subtree evidence, and calibrates the Dating pixel geometry against the actual native captures. It also removes 27 points of discretionary vertical spacing from active invitations: native images showed the primary button partly below the initial scroll viewport. Readable text, card content, disclosure, control targets and artwork size remain. Social's distinct bubbles and Dating's pink-lit rings were reviewed in actual native captures. A Dating app screenshot omitted the footer/chrome, while a retained recording frame showed them visibly drawn; that screenshot mismatch is not classified as app invisibility.

Exact internal commands for the first native compile and domain test (the controller supplied `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`):

```sh
/usr/bin/xcrun swift test --package-path /Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final/source/ProximeetDomain --scratch-path /Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final/domain/Build --jobs 4
/usr/bin/xcodebuild build-for-testing -project /Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final/source/Proximeet.xcodeproj -scheme Proximeet -configuration Debug -testPlan WaveVerificationMain -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final/DerivedData -resultBundlePath /Users/user299580/ProximeetDiagnostics/private-invitations-native-20261029-d77e25b4final/build/Build.xcresult ARCHS=arm64 CODE_SIGNING_ALLOWED=NO
```

The generated native test selection changed only the selected UI target/test identities; original 900/1,200-second method allowances and the source test plans stayed intact. Actual test command vectors, owned simulator identity and result bundle paths are recorded in that root's `test-large/receipt.json`; source/evidence copies remain immutable. The revision's successful native UI, smaller-device screenshots, archive and internal upload are still pending at this report append. Their receipts must identify the subsequent manifest and cannot rewrite the failed first invocation.


### Business decorative-image correction after native evidence — 29 October 2026

The second native snapshot (`d77e25b4r2`, payload `1d83b34e0e00a598f0853986831e411351f17904ce2ff79b855f300b2b598421`) again passed all 263 domain tests and native compilation. Its two functional tests failed the same strict artwork structure check. The new diagnostic attachment established the actual cause: each Business artwork root contained two Image nodes with identifier `briefcase` and label `Briefcase`, despite explicit leaf and parent accessibility hiding. This is captured XCTest structure, not a claim about a physical VoiceOver session. The run stopped before its regression/small phases and archive/upload; the failed evidence remains retained.

The corrective source change replaces the decorative SF Symbol with a 19-point stroked native briefcase Path, preserving its color and visible role on the stationery. The artwork file now contains no Image views. The strict accessibility assertions remain unchanged. The previously measured Dating probe correction and 27-point spacing adjustment remain. The next native snapshot must compile this actual change and pass the four-intent functional, existing journey/motion, and smaller-device selections before archive/upload.
