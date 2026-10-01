# Wave chapter 09: Build 9 failed — audited native evidence

Updated: 1 October 2026. **Native verification remains FAILED. Build 9 completed on the repaired source.**

## Current result — supersedes the historical plan below

Build **9** (`2a82205c-c26b-46e9-8abf-9837e9573c48`) ran the manual Wave Verification workflow at
`5aed3e0a2335f14d127718f6789fc5bf043bb970`, branch `wave/approved-20260930T173856Z`.
Xcode 26.6 (17F113), iOS 26.5: Main iPhone 17 Pro Max **269/280**, Small iPhone 17e **7/7**:
**276/287 native tests passed; 11 failed.** All expected identities ran once, with no skips, omissions,
repeats or budget cutoff. The eight separate D2 source readers **passed 8/8 on Apple's macOS build host**
at that exact commit, confirmed from the full Main build log. They are not included in the 287.

Apple reports **49 minutes elapsed and 73 compute minutes**. The one additional authorized native run
has been used; no automatic retry, archive, TestFlight delivery, Codemagic run or billing/security change
was performed. Before publication, actual workflow inspection found Wave and Room manual-only on their
specific branches; TestFlight's branch trigger was restricted to `testflight/internal-20260928`.

- Main's 250 domain tests, 16 Places/Room UI tests and 3 Wave UI tests passed. The other 11 Wave methods
  still fail the unchanged rings-absence assertion. The accessibility-boundary hypothesis did not resolve
  it. Each exact diagnostic contains an unnamed, childless XCTest Other node tagged `wave.rings`; ten
  are the separate pose, one is joined. This does not establish VoiceOver focus/speech or justify claiming
  the test invalid. Keep the strict assertion and identifier pending a focused native investigation.
- Small's former scroll-helper failure is resolved in this native run. Paired app/screen captures show
  Leave fully visible, and its real tap reaches the ended state with Return to Places.
- Visual defect confirmed on both phones: at largest accessibility text, the accepted invitation's
  purpose overlaps its intent/approach. Small's original recording also shows it. A reviewed candidate
  patch is at `docs/verification/wave-build9-layout-candidate.patch`; it is **unapplied and not natively
  verified**. It preserves the approved layout system and adds a same-snapshot separation assertion.
- Main's approved default capture loop stopped before its first capture (**0/24**). W1 has **1/12**
  journey captures and a **51.128-second incomplete original recording**. Largest-text evidence has
  **49/49 selected captures per phone**; that does not replace the missing default set or walkthrough.
- The ten unique Main compiler warning locations are in tests (four unused-result warnings and six
  previously recorded actor-isolation warnings). No negative-frame warning text appeared in the examined
  Main build/runtime and Small runtime logs; that limited absence is not a device or production sign-off.

The exact compiled simulator app is retained from Build 9's Main Test Products artifact (41,450,968 bytes),
with `com.goseng.proximeet`, iPhoneSimulator platform and SDK iphonesimulator26.5. A compatible interactive
Mac/iOS simulator is required to perform VoiceOver/Accessibility Inspector work; this workspace has no
such surface. No new cloud build is needed merely to obtain that app. See the focused investigation plan
in `docs/verification/wave-build9-rings-diagnosis.txt`. No grounded additional rings source fix is claimed.

Evidence is packaged as **Wave-Build9-Review.zip**, with unchanged selected screenshots/recordings,
exact native log audit, missing-capture inventory, failure snapshots/provenance, simulator test products,
and the unapplied layout patch. **Wave-Build9-Report.html** is a self-contained readable report.
VoiceOver, system Reduce Motion, motion quality, real-device testing, founder visual review and production
readiness remain pending. The tested product/test source has not changed after Build 9.

## Historical Build 8 report and pre-Build 9 authorization

The text below is retained as historical context. Its future-tense repair/run statements have been
superseded by the completed Build 9 result and consumed one-run authorization above.

# Wave chapter 09: Build 8 and the repair candidate

Updated: 1 October 2026. **Native verification remains FAILED. The repair candidate has not run.**

## Current result and continuation

Build **8** (`b0f3f615-1b68-42b1-bcbc-000df4be40c2`) ran the published branch
`wave/approved-20260930T173856Z` at `0fe14dc3fe934950e1fa3f72035dc9959e3a9c5c`.
Both native builds compiled. Main passed **269/280**, Small **6/7**: **275/287**, with 12 failed methods.
All 287 expected unique identities and destinations were represented; the retained logs show no repeated
starts or ends, skipped results or `RUN_BUDGET_SPENT` marker. Apple's displayed use was **71 compute
minutes**, with **48 minutes** elapsed. This is the failed baseline, not evidence for the repaired source.

- Main: all 250 domain tests and the 16 Places/Room UI methods passed; 3/14 Wave methods passed.
  The other 11 stopped at the same strict check finding `wave.rings` somewhere in the XCTest snapshot.
  That evidence does not establish whether VoiceOver can focus or speak the rings. The original snapshot
  collector did not retain the information needed to distinguish a structural wrapper from an exposed element.
- Small: four Places methods, one Room method and the Wave panels method passed. The Wave largest-text
  screens method had two scroll-helper failures: its five candidate touch-down positions all overlapped
  expanded controls. A preceding drag did move content; final reachability was not established there.
- W1 and the approved-screen inventory stopped early at the rings assertion. There is no complete Wave
  walkthrough or complete approved-state capture set from Build 8.
- A blocked-menu end still shows a blank Leave area, while the sampled recording at 40.0 seconds shows
  Leave. This remains unresolved; neither a persistent drawing defect nor a capture artifact is established.

Evidence is retained in `Wave-Build8-Review.zip`, including the result inventory, runtime audit, exact
failure descriptions, selected captures, the original Small recording and its provenance. No archive or
TestFlight delivery followed Build 8.

## Bounded repair candidate

The source is reconstructed from the exact GitHub archive of the Build 8 commit. Only these product/test
changes are proposed:

1. `WaveView.swift`: put dynamic page hiding on explicit accessibility containers. Give decorative rings
   an explicit ignored-child boundary, retaining `wave.rings` before the final hidden modifier. This is a
   semantic repair hypothesis that needs native validation; modifier ordering is not a proven root cause.
   Existing text continues to convey invitation state. No art, layout, typography, navigation or motion changes.
2. `WaveReviewTests.swift`: keep the original rings-absence assertion and identifier. If it fails, retain
   the exact assertion snapshot, node roles/labels/frames/descendants and a screenshot for diagnosis.
3. Add a page-only trailing-gutter scroll candidate, 16 pt inside the scroller and away from the left edge
   Back gesture, after existing candidates. Preserve the 10-pt control exclusion, vertical bounds,
   movement/stall checks and 40-attempt limit.
4. At the blocked menu's largest-text end, keep the app alive for paired app/screen captures, record Leave
   geometry, then actually tap Leave and check the ended screen. Hittability and a successful tap are not
   substitutes for reviewing whether the text was drawn.
5. `ci_scripts/ci_pre_xcodebuild.sh`: run the eight D2 source readers on the macOS build host once in the
   existing Wave Main `build-for-testing` phase. Exact workflow, phase and plan gates prevent extra work in
   Small and other workflows. The command has a five-minute timeout; zero, missing, repeated, skipped or
   failing tests fail the hook. D2 remains separate from the 287 simulator executions.

All 14 Wave UI methods and both plans remain selected. The 800-ms recipient-acceptance-only ring join,
240-ms dissolves, Reduce Motion behavior, approved Room/Wave visual system and offline demo rules stay
unchanged. Nothing here is a native pass, motion review, VoiceOver result or founder visual sign-off.

## Authorized next action and limits

The founder authorized the repair and **one further manual Wave Verification build, up to 160 compute
minutes**, with “ok then do it stop waitig for me” and repeated continuation instructions. The lead performs
the accessible publishing, trigger inspection, start, monitoring and artifact review steps. No new approval
is required for those already authorized steps. Do not start automatic retries, Codemagic, an archive or
TestFlight distribution. Inspect current Apple workflow triggers before publishing the repaired branch.

The UI budgets remain 104 minutes Main and 36 minutes Small. D2 uses part of the existing setup allowance;
it adds no action. The five-minute D2 timeout and UI guards do **not** bound all Apple setup/upload time.
Monitor actual usage and cancel before the authorization limit is exceeded. An incomplete or budget-cut
run is not verification success. A repaired-source native run is pending; the current browser requires Apple
sign-in before trigger inspection or start. Source checks are recorded with the packaged candidate; this
report does not carry old candidate passes forward.

VoiceOver, system Reduce Motion, motion quality and device visual review remain manual and pending.
The earlier Guest List negative-frame warning and largest-text INTRODUCTIONS wrapping stay recorded.

## Historical implementation record — 30 September 2026

The following record is preserved as originally reported. Its local-only, no-native-run, VPS-only D2,
no-Apple-access and founder-only action statements describe that date. They are superseded for this
continuation by the current result and runbook above; they must not be read as today's status.


Date: 2026-09-30. Not production-ready.

**Status:** implemented in source on an isolated local branch and checked on Linux, in two candidates: the
first (`124c6a4`), and a second on top of it that builds the founder's decisions of 30 September 2026 (§3a).
**Native compilation, simulator runs, VoiceOver, system Reduce Motion, motion quality and device behaviour
have not been run.** The founder then authorized one bounded Xcode Cloud verification build (§5). It has not
started: the founder asked for the App Store Connect start conditions to be inspected before the push, and
this machine has no App Store Connect access (no API key, no Apple sign-in, no connector), so the push is
held. No push, CI, Codemagic, Apple configuration, upload or signing change was made. Nothing here is
founder visual approval of the native Wave, and nothing here says the Wave's automated checks passed: they
have never run.

## 1. Baseline and provenance

| | |
| --- | --- |
| Base | Verified Room commit `1a5f97e0fe73168e5f63e392182507e457209964` on `origin/room-repair/xcode-checks-20260930` (= the Room repair candidate `062ea35` + three commits: distinct journey inputs in three UI tests, and the local-package reference that lets Xcode discover `ProximeetDomainTests`) |
| Wave branch | `wave/approved-20260930T173856Z`, worktree `/home/proximeet/proximeet-cloud-wave-20260930T173856Z`, created with `git worktree add` from `1a5f97e`; two local commits (the first candidate `124c6a4`, then the second candidate), not pushed |
| Not used as base | `testflight/internal-20260928` (still `67bf1a9`, per the current instructions); `redesign/social-objects`; `origin/verification/room-d2-1a5f97e-20260930` (a CI-only branch whose `.github/workflows` file would fail validator check 11) |
| Verified Room outcome (read from GitHub check runs on `1a5f97e`, not from the repository, whose Room report still shows the earlier pending status) | RoomVerificationMain success 14:51–15:42 UTC; RoomVerificationSmall success 14:51–15:17 UTC; Proximeet TestFlight Archive success 16:16–16:22 UTC (all 30 September). The "247 checks" and the delivered 0.1.0 (7) are the founder's figures |
| Handoff | The prompt's `Proximeet-Wave-Implementation-20260930.zip` is not on this machine. The complete approved handoff was taken from the master `PROXIMEET_ALL_TEN_APPROVED_HANDOFFS.zip` (SHA-256 `365df942…117f7`; its `SHA256SUMS.txt` 13 of 13 OK): `chapters/09-wave/PROXIMEET_WAVE_APPROVED_HANDOFF.zip`, SHA-256 `ecc5667d…6e106` (matches `HANDOFF_INDEX.json` order 9); inner `SHA256SUMS.txt` 23 of 23 OK, no unlisted files. A second extracted copy on the VPS is byte-identical |
| Handoff copy in the repository | `docs/design/wave-approved/`: README, DESIGN_NOTES, CLAUDE_PROMPT, `fixtures/WAVE_DEMO_CONTRACT.json`, the two reference boards and the handoff's own `SHA256SUMS.txt` (6 of the copied files match it; the art, fonts, specs and validation are not copied), exactly as the Room's `docs/design/room-approved/`. The source gate (`scripts/places_source_manifests.py`) now lists it with the approved files |
| Figma | page 74:567, review 76:387, approval annotation 84:498; founder "approve" 24 September 2026 22:31:36 PDT |

**Dependency evidence (read in source at `1a5f97e`).** Welcome ("More options" → "Continue the demo (no
account)" → `session.begin()`), Birthday (wheel and typed input; `continueFromBirthday(today:)` re-checks an
injected civil date), Pass (intro → progress → complete), Guest List (real text fields bound to the draft
introduction), Wristband (`chooseIntent`), Signal (`chooseApproach`; Places needs both), Places (fixed
snapshot "Fictional venues · demo Thursday, 8 pm"; eligibility = intent match and open), and Room (entry and
populated gates, one central blocked set, local unsent reports, terminal Leave, Return to Places at Now)
all exist and are wired as approved. There is no stable viewer ID in the code; the Wave uses the single fixed
`WaveParticipant.viewer` identity (accepted by the founder on 30 September 2026, §3a) and reads the actual
Guest List name once when the Wave opens.

**Assets and fonts.** No new art or fonts. The handoff's `assets/common-ground.png` (1254 × 1254 RGBA) is
byte-identical to `Proximeet/Resources/Assets.xcassets/PlaceCommonGround.imageset/common-ground.png`, used
through `PlacesArt` with the approved crop [46, 83, 1211, 1218]; the five static Manrope faces and
`OFL.txt` are byte-identical to the bundled `Manrope-*.dataset` files (the handoff's variable face is not
needed). The rings are native ellipse strokes; no image, screenshot UI or effect was added. No envelope or
clasp concept, no ring-reflection experiment, no regenerated art, no font change.

## 2. What was implemented

- **Domain** (`ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift`, new; `RoomDemo.swift`, integration):
  - `WaveDemo` lives inside the Room run that opened it (`RoomRun.wave`), so the Wave shares the run's identity,
    populated phase and its one central blocked set, and one Leave ends both.
  - Invitations are typed values with an immutable ID (`WaveInvitationID(run, sequence)`, issued per explicit start,
    never reused), Room run ID, sender, recipient, venue, intent, direction and a single `status`; no `isSent` or
    `isAccepted` flags. Self-addressed or foreign-run invitations are rejected at construction.
  - Every action (`RoomRun.perform(WaveAction)`) re-reads central eligibility at action time: the run is active and
    populated, the counterpart is unblocked and shares the viewer's intent, and the venue is Common Ground. Stale
    and repeated handles (an old invitation ID, a screen, an overlay kind) change nothing.
  - Acceptance validates the contract's nine guards atomically (same Wave ID, same run, pending, viewer is the
    recipient, sender differs, run populated and active, same venue, same intent, no block or invalidation).
    There is no sender-facing Accept anywhere.
  - Withdraw, decline, sender-withdrawn, expired, block and Leave close the invitation; a closed invitation never
    changes again and is kept, append-only, for the life of the run (`RoomRun.closedInvitations`).
  - "Show no-allowance example" is an explicit demo condition with no Send action; there is no count, quota,
    refill, refund, cooldown or timer.
  - A Wave block writes the same central set: Maya loses her card and profile; Jules also loses his public
    note; the other sample's note is unchanged. The Block carries its actor and its run, and acts only for
    them. After a block the menu's three starts are disabled and nothing unblocks; no menu control can revive
    an ended run.
- **Session** (`DemoSession`): `openWaveDemo(_:)` (reads the actual Guest List name once, trimmed),
  `performWave(_:_:)`, `closeWaveDemo(_:)` (the menu's Back) and `wave`, all through the existing
  run-ID-guarded `updateRoomRun`.
- **Room integration** (`RoomView.swift`): the same-intent profile action is now "Preview Wave demo" (the
  founder's hint "Opens a fictional Wave demo. Nothing is sent.") and opens the Wave menu with that sample as the counterpart; the other
  intent keeps "Back to people" and the same-intent explanation. When the run carries a Wave, the Room page is
  replaced by `WaveView`. Room's former Wave-information panel (66:134) has no entry point any more and is
  removed with its fixture and tests (Room's reachable overlays go from 8 to 7).
- **View** (`Proximeet/Scenes/WaveView.swift`, new): all 12 screens, 7 overlays and 4 report-reason variants,
  built from the live Room system (buttons, headline, labels, chrome, ticket layout, reason rows, tokens) with
  Wave's measured sizes where they differ; native ellipse rings; accessibility identifiers `wave.*` and
  `wavePanel.*`. The menu wears the 75:119 Back chrome, and once the counterpart is blocked shows its three
  choices disabled beside one generic line (§3a). The join is the only 800-ms ease-out move and runs only after a valid recipient acceptance has
  been committed; every other change is a 240-ms ease-out dissolve; with Reduce Motion the rings take their
  joined pose without the move.
- **Fixtures** (DEBUG only): `-ProximeetFixture wave-*` for every screen, with `-ProximeetWavePanel`,
  `-ProximeetWaveReason`, `-ProximeetWaveFrom`, `-ProximeetWaveAfterBlock`, `-ProximeetRoomBlocked` and
  `-ProximeetFixtureName`; each state is reached only through the actions a guest would take.

**The 12 screens** (Figma key = `WaveScreen` raw value; the DEBUG fixture is `wave-<key>`, except the menu's,
`wave-menu`): `demo-menu`, `out-confirm`, `out-pending`, `out-withdrawn`, `in-review`, `in-declined`,
`in-accepted`, `in-withdrawn`, `unavailable`, `blocked`, `allowance-unavailable`, `session-ended`. The blocked screen
(74:576) is reached by blocking over an active invitation. **The 7 overlays:** global safety, counterpart safety,
the report preview (no reason, and the three reasons: 4 variants), private-chat information, demo conditions.

**Integration behaviour, by contract clause, with the evidence that exists today:**

| Clause | Where it holds | Linux evidence | Native row (not run) |
| --- | --- | --- | --- |
| Entry only from an eligible profile's "Preview Wave demo", carrying the actual name, intent and approach; Social → unblocked Maya, Business → unblocked Jules | `RoomRun.openWaveDemo`, `DemoSession.openWaveDemo`, `RoomView` profile action | domain tests | W1, W2, W3, W13 |
| Shares the Room run identity, populated state and the one blocked set | `RoomRun.wave` | domain tests | W8 |
| Two independent immutable invitations; outgoing never accepts itself; only the valid pending recipient accepts | `WaveInvitation`, `acceptanceRefusal` | domain tests, including a randomised sequence test | W6 |
| Duplicate or stale actions, withdraw, decline, block, expiry or Room end never create acceptance; every invitation control re-validates the current run | `RoomRun.perform`, `WaveDemo.apply` | domain tests | W5, W7 |
| Commit state before decoration; Block and Leave interrupt the join | `WaveView` (state first, animation after; block and Leave replace the page) | app type-check only | W7, W9, W12 |
| Menu resets never clear blocks or revive an ended Room; the menu's Back returns to the still-valid Room with its state and blocks | `RoomRun.perform`, `closeWaveDemo`, `isConsistent` | domain tests | W2, W8, W9, W10 |
| Leave ends Room and Wave at once; Return to Places opens the actual Now with choices and the draft kept | `RoomRun.leave`, existing Places return | domain tests | W1, W9 |
| Report is an unsent local preview | `WaveOverlay.report` | domain tests | W4, W11b |
| No send, chat, notification, backend, timer or numeric allowance | the sources | validator check 11 (with the new Wave-only scan) and `DomainSourceGuardTests` | D2 |

## 3. Design comparison with the current Room, and decisions

Wave extends the Room system rather than replacing it:
- **Reused unchanged:** header (Wave 75:111/119/130 = Room 67:111/119/130), DEMO badge, shield and chevron,
  compact venue ticket (its third line now also carries the viewer's name), report panel and its four reason
  variants (Wave 75:627–657 = Room 67:816–846), button family (filled 60/56/52, outlined 56/52/48/44, radius 18,
  SemiBold 16), the 72 % dim with modal panels, the status-bar ground strip and the rule that no bar is built under
  an overlay.
- **New to the system, from the approved measurements:** the brushed-metal rings; the invitation card; the demo
  menu; the closed invitation paper (back sheet 264 × 136 tilted 3°, front 288 × 135, seal 60 × 34, which differ
  from Room's envelope); the Bold 14/24 context row; the centred ExtraBold 28/40 invitation title in ink;
  Regular 16/25 closed explanations; 30/38 panel titles; the demo-conditions panels; the 800-ms join.
- **Colour:** every Wave colour except the ring metal is an existing Room token; no intent colour decorates the
  Wave (the design notes' "Social coral" appears on no Wave node).
- **To access Room's components,** file-scope `private` types in `RoomView.swift` were made internal (access level
  only). Three Room components that hard-code Room identifiers or copy got Wave variants instead (ticket, DEMO
  badge, envelope).

Decisions where the handoff is silent, as made for the first candidate (each a recorded deviation or choice,
not a founder approval). Decisions 2, 3 and 8 are superseded by the founder's own of 30 September (§3a):
1. **Room's Wave-information panel removed.** The handoff turns the profile's information action into "Preview Wave
   demo"; the panel it opened (66:134, including the approved line "Sending Waves comes in the next preview.") has
   no entry point, so it is removed.
2. **Back from the menu.** *Superseded: the menu now has the visible 75:119 Back (§3a, decision 1).* The design has
   no route from the Wave menu back to the Room; a back swipe or VoiceOver escape on the menu returned to the Room
   profile (or to filtered People if the counterpart is blocked). Out-confirm's designed Back returns to the menu;
   closed screens' outer Back returns to the menu; pending, review and accepted have no outer Back; the ended
   screen's outer Back goes to Places, as Room's does. These still hold.
3. **Blocked counterpart and new examples.** *Superseded (§3a, decision 2):* the three starts are now disabled
   after a block, with one generic line; they no longer show the blocked screen.
4. **Leave inside the Wave** shows the Wave's ended screen (74:578); Leave from the plain Room still shows Room's.
5. **Closed invitations** are kept in memory for the run's life.
6. **Panel Close** uses Room's 240-ms dissolve (Figma CLOSE carries no transition).
7. **Invitation preference line** shows the counterpart's own intent and approach; the header ticket shows the
   viewer's name, intent and approach. Different approaches are allowed.
8. **Uppercase name lines** ("OUTGOING · YOU ARE {NAME}") read in sentence case to VoiceOver. *The rest is
   superseded (§3a, decision 4):* no name is compared any more; the direction line keeps the typed name
   ("MAYA → MAYA · INCOMING") and VoiceOver reads the viewer as "you" by identity.
9. **No initials avatars** are drawn: the approved spec has no avatar node although the asset map mentions them.
10. **The demo-conditions panels** keep their measured 5-pt bottom padding and scroll at larger text.
11. **Ring rendering:** Figma's shadow blur 7 is drawn as SwiftUI radius 3.5, and the joined rotation pivots on each
    ring's top-left corner as the matrices specify; both need a native capture to confirm.

## 3a. The founder's decisions of 30 September, as built

The founder resolved seven open items of §3 on 30 September 2026, and accepted the Wave-information
panel's removal (below). Each is built as stated, on top of
`124c6a4`, and each is recorded here as an integration adjustment, not as founder visual approval.

| # | Decision (founder) | What the code does now | Evidence today (Linux) | Native row (not run) |
| --- | --- | --- | --- | --- |
| 1 | Use the existing visible, accessible Back pattern to return from the Wave menu to the still-valid Room; the swipe may do the same; keep Room state and blocks | The menu wears the 75:119 chrome (the out-confirm pattern: 44 × 44 chevron "Back", then the header "Wave", DEMO, Safety) instead of 75:111. Back and the edge swipe both call `RoomRun.closeWaveDemo()` through `DemoSession.closeWaveDemo(_:)` (run-ID guarded), with the 240-ms dissolve. The run keeps its identity, phase, blocks, closed invitations and start count; the profile that opened the Wave shows again, or the filtered People once that person is blocked | `testTheMenuBackReturnsToTheStillValidRoom`, `testOuterBackFollowsTheVisibleBackOnly` | W2 (Back and re-entry), W10 (swipe = Back), W11a (Back at the largest text) |
| 2 | Keep the three example buttons' distinct labels; after blocking, disable them and show one generic "Connection blocked" explanation that does not expose the blocked person | Starts are refused once the counterpart is blocked (`WaveExample.blockedStart` is gone, and no identity is issued). The menu keeps "Start outgoing example", "Start incoming example" and "Show no-allowance example", disabled, with the hint "Unavailable. Connection blocked.", and the boundary line becomes "Connection blocked. / New examples are unavailable in this demo." (new copy; it names nobody). The approved blocked screen 74:576 is still reached by blocking over an active invitation | `testNewExamplesNeverUnblockOrRevive`, `testMenuStartsRecheckEligibilityEachTime` | W7, W8, W4 (capture), W11a |
| 3 | Keep closed invitation IDs and statuses in memory for the Room session; never revive them | Unchanged: `RoomRun.closedInvitations` is append-only for the run's life; the menu Back keeps it | `testClosedInvitationsAreRetainedAppendOnlyForTheWholeRun`, `testTheMenuBackReturnsToTheStillValidRoom` | D1 (not visible in the UI) |
| 4 | "You" identifies the current viewer by actor ID, never by matching names; keep the actual Guest List name and draft | The name comparison is removed. The slip's line is written from the invitation's own participants (sender, then recipient) with the actual Guest List name, as the approved design does ("MAYA → MAYA · INCOMING" for a guest who typed Maya). VoiceOver reads the participant that is `.viewer` as "you", with the name: "From Maya to you (Maya). Incoming." The draft is never written | `testAViewerNamedLikeTheCounterpartKeepsTheirOwnIdentity`, `testTheWaveNeverWritesTheFlowOrDraft` | W6 (a guest named Maya), W1–W3 (exact spoken lines) |
| 5 | Add the spoken hint "Opens a fictional Wave demo. Nothing is sent." | On "Preview Wave demo", from `RoomCopy.previewWaveDemoHint` | the copy is pinned in the domain tests; speech itself is a manual check | VoiceOver (manual) |
| 6 | A queued Block may affect only its original actor in the same valid Room run; the report panel must prevent touches reaching controls underneath | `WaveAction.blockCounterpart(actor, run:)` carries both; the run refuses it for any other actor, any other run, a closed safety, an ended run or a second time. Only the top overlay is ever drawn; the report card and the dim take every touch, and the page below takes none | `testAQueuedBlockAffectsOnlyItsActorInItsRun`, `testOverlaysFreezeTheScreenBelow` | W5 (a tap where Block was, under the report, changes nothing) |
| 7 | The fixed viewer ID is acceptable if it is distinct from counterpart IDs, independent of names, and every invitation validates the current Room run | `WaveParticipant.viewer` is distinct from every `.sample(actor)` by construction and never derived from a name; every invitation control now re-validates `invitation.roomRunID == run` as well as the invitation | `testTheFixedViewerIdentityIsDistinctAndNameIndependent`, `testEveryInvitationControlRevalidatesTheRun` | D1; W6 (roles never change) |

**The Room keeps seven panels.** The founder accepted the removal of the superseded Wave-information panel
(66:134) on 30 September 2026: *"Removing the superseded Room information panel is acceptable. Record the
seven remaining Room panels and preserve Wave's information content."*
The Room's remaining panels are the approved 66:127 global safety, 66:128 and 66:129 Maya's safety,
66:130 and 66:131 Jules's safety, and the unsent report previews 66:132 (Maya) and 66:133 (Jules), with
their four report-reason variants.

**The retired panel's information is kept in the Wave's approved copy:**

| Retired Room copy (66:134) | Where the Wave says it now |
| --- | --- |
| "How Waves work" (the profile's action) | "Preview Wave demo", which opens the Wave itself |
| "A Wave is / an invitation." | "A Wave invites a conversation." (out-confirm 74:569) |
| "Chat opens only after the other person accepts." | "Maya chooses whether to accept." (74:569), "Only Maya can accept." (74:570), "A temporary private chat can open next." (74:574) and the private-chat information panel 74:583 ("Both people have agreed in this incoming demo. Private Chat and Keep are the next chapter.") |
| "Sending Waves comes in the next preview." | Superseded: the Wave demo is that preview, and every active screen says "Nothing is sent." |
| "Back to profile" | The menu's visible Back (decision 1) |

None of the Wave's own information content was removed: the menu's explanation, the four boundaries,
the chat information panel and the three demo-conditions panels are unchanged.

**Still open for the founder** (the build follows the choice named; each can be changed cheaply):
- the two visible changes the 30 September decisions brought to the approved menu (74:568): its header now
  shows Back and "Wave" instead of the "Proximeet" wordmark; and the blocked menu's new copy ("Connection
  blocked. / New examples are unavailable in this demo.") and disabled choices, whose filled buttons use the
  other screens' approved disabled colours but whose disabled outline ("Show no-allowance example") has no
  approved reference;
- the new hints "Returns to the Room. Nothing is sent." (the menu's Back) and "Unavailable. Connection
  blocked." (each disabled choice), heard but not seen;
- two deliberate, separate taps on the confirmation's Back leave the Wave (the menu's Back sits in the same
  place); a rapid double tap stops at the menu;
- the DEBUG-only launch option `-ProximeetFixtureName`, which exists to capture long names at the largest text;
- the approved Block explanation (74:581) says blocking hides the person's "card and invitation"; blocking Jules
  also removes his public note. The approved copy is kept unchanged;
- "Show expired example" closes the current invitation (an accepted one included) but does not end the Room: the
  fixed Thursday snapshot keeps the Room eligible, and the contract ends the Room only when the Room itself is
  ineligible.

## 4. Checks executed, with their evidence

All on the Linux VPS (Ubuntu, Swift 6.3.3), on the working files of each candidate before its commit. None is
a native compile or a simulator run.

| Check | Command | First candidate (`124c6a4`) | Second candidate |
| --- | --- | --- | --- |
| Design graph audit (the reviewed design fixture only) | `python3 validation/audit_design_graph.py` in the handoff | exit 0, `"passed": true`, `"errors": []`; 12 states, 7 overlays, 74 routes, one accept edge (75:419, in-review, SMART_ANIMATE 800 ms), 4 report-reason variants, all other authored navigation 240-ms dissolve | the same (the handoff is unchanged) |
| Domain tests | `swift test --package-path ProximeetDomain` in a scratch copy holding `ProximeetDomain/` and `Proximeet/` | `Executed 254 tests, with 0 failures (0 unexpected)` | `Executed 258 tests, with 0 failures (0 unexpected)`: 47 `WaveDemoTests` (4 new, 8 rewritten for the decisions) |
| D2, the source-reading domain tests | the same, `--filter` on the eight D2 tests | `Executed 8 tests, with 0 failures (0 unexpected)` | `Executed 8 tests, with 0 failures (0 unexpected)` (the committed candidate itself is re-run after the commit, from `git archive`, and reported with its SHA) |
| App type-check (not a native compile) | the Linux rig: the app's Swift files against SwiftUI / UIKit / CoreGraphics / Accessibility stub modules, strict concurrency | `Debug: 0 errors, 0 warnings; Release: 0 errors, 0 warnings` | the same; the rig was shown to catch the old `.blockCounterpart` form and a `closeWaveDemo()` without its run ID (2 planted errors, 2 reported) |
| UI-test type-check (not a native compile) | every `ProximeetUITests` file against an XCTest shim (extended with the real `XCUIScreen.main.screenshot()`, `navigationBars` and `XCTAttachment(data:uniformTypeIdentifier:)`) | exit 0, 0 errors; 6 pre-existing `reviewFlag` warnings (Birthday, Pass, Welcome tests) | the same, with `RunBudget.swift` included |
| Project generator | `python3 -B scripts/generate_project.py --check` | `up to date` | `up to date` (the project now lists `RunBudget.swift`) |
| Project validator | `python3 -B scripts/validate_project.py` | `13 checks, 0 failed` | `13 checks, 0 failed`; check 7 adds `Wave compute budget: WaveVerificationMain 6240 s + WaveVerificationSmall 2160 s + 2 x 600 s … = 9600 s <= 9600 s (160 min)` and `RunBudget.begin opens setUpWithError in every Wave-selected UI test class`; eight broken variants of the plans and guard were each rejected on a scratch copy |
| Source gate | `python3 -B scripts/places_source_manifests.py`, then `--check`, then `scripts/places_review.sh checkpoint` | `up to date: approved 119, review 217`; `result=MATCH` | `up to date: approved 119, review 218`; `result=MATCH` (run last, after every edit) |
| Independent reviews | three read-only reviewers (the founder's decisions and the contract; whether the native UI tests can pass; guardrails and honesty), then the `guardrail-auditor` on the full diff against `1a5f97e` | the auditor: FAIL on this report's wording, then PASS | the three reviewers: PASS each, with should-fix items (stale counts and comments, a session-level test for the menu's Back, the hints pinned, a double tap on the confirmation's Back), all applied; then the `guardrail-auditor`: FAIL twice on documentation wording only (an estimate left from the first candidate; the untested compute guard stated as holding the build at 160, in five places; the panel removal not attributed to the founder), each fix applied exactly as it named; the product code passed every guardrail in both passes |

**What the Linux checks cannot see.** SwiftUI layout and rendering, the accessibility tree, the 800-ms join and
the 240-ms dissolves, VoiceOver speech, Dynamic Type metrics, safe areas, the real XCTest runtime and every
UI-test assertion. The type-checks use stub modules that model only the declarations the app uses.

**Found in the first candidate's hardening review and changed in source** (none is verified natively; each is
PENDING a native run and, for the view, a capture): at the largest text the incoming review's Decline could
never be revealed by the tests (the reveal helper now uses that screen's 10-pt bar padding; unverified until
W11a and W14a run); by code reading the rings would sit up to 8.5 pt above the approved alignment below 440 pt
(fixed height, top alignment, a width floor, no hit testing; unverified until a native capture at 390 pt); a
selected reason read "Selected" twice (the selected trait alone now; VoiceOver speech unverified); taps that
trusted `isHittable` under the bar (every tap now measures and reveals first); the validator had no
Wave-specific scan (added, with a known-answer fixture); two new domain tests read the repository's files
(both Main plans skip them; they run on the VPS as D2).

## 5. The native test manifest, the authorized build, and why it has not started

- **Manifest:** `docs/verification/wave-xcode-cloud-manifest.tsv`, 39 rows.
  - **WaveVerificationMain** (iPhone 17 Pro Max, 440 × 956): W1–W10, W11a, W11b, W12, W13 (all 14
    `WaveReviewTests`), R1–R13 (all 13 `RoomReviewTests`), P1, P4, C1 (the Places tests that go through the
    Room) and D1 (the domain target minus the 8 D2 tests): **30 UI + 250 domain = 280 tests**.
  - **WaveVerificationSmall** (iPhone 17e, else 16e, 390 × 844): W14a, W14b (both largest-text Wave tests),
    R14, C15, P9, C12, C11: **7 tests**.
  - **D2** on the VPS: 8 source-reading domain tests, run once there and not among the 250.
- **The count, reconciled.** The first candidate expected **283** native executions (276 + 7). The decisions
  added four domain tests and no UI test method, so this candidate expects **287**: 280 + 7. The domain
  target has 258 tests, 250 on the simulator and 8 on the VPS; nothing is counted twice.
- **Coverage asked for, and the rows that carry it:** every screen and panel (W4 captures, now with the blocked
  menu; W11a/W11b/W14a/W14b reachability); both intents and both approaches (W1, W2, W3); long names and
  largest text (W11, W14 with `-ProximeetFixtureName`); safe areas and modal isolation (W4, W11, W14; W5: a tap
  where Block was, under the report, reaches nothing); Leave everywhere (W9); immutable roles and "you" by
  identity (W6, with a guest named Maya); stale and duplicate actions (W5); interrupted acceptance (W7);
  blocks in both orders, the disabled menu and Jules's note removal (W8); the menu's visible Back and re-entry
  (W2, W10); Places return with the draft (W1, W9); ineligible and other-intent profiles never reach the Wave
  (W13); back swipes (W10); Reduce Motion preview (W12). Room and Places regressions: R1–R14, P1, P4, P9, C1,
  C11, C12, C15.
- **Left out, with the justification the founder asked for:** the 16 Room-plan regression rows C2, C3, P2, C9,
  C4–C8 (440 pt) and P10–P13, C10, C13, C14 (390 pt). An independent read of every row found that none opens
  the Room (so none can reach the Wave), that with `-ProximeetFixtureName` absent every changed shared fixture
  function returns exactly what it returned at 1a5f97e, that `DemoSession` only gained members, that no Places,
  Signal, Wristband, component, design-system or app-entry file changed, and that the only edit to their
  classes, the compute guard's first line, does nothing unless a Wave plan's budget variable is set. The full
  paragraph, with its file and line evidence, is in the runbook §2.
- **Authorized (30 September 2026):** pushing only this branch, creating the manual **Wave Verification**
  workflow, and **one** build of at most **160 compute minutes** across its actions; no automatic retry,
  Codemagic, billing change, archive or TestFlight distribution. Estimated at **about 107–161 compute minutes**
  (Main about 81–121 min, Small about 26–40 min, scaled from the Room build on 1a5f97e: 77.38 compute minutes).
- **The compute guard.** Nothing on this machine can cancel an Xcode Cloud build, so the tests are designed to stop themselves:
  `ProximeetUITests/RunBudget.swift` gives Main's UI tests 104 minutes and Small's 36, with 10 minutes an action
  allowed for everything else (the Room's build suggests 4–6), so 160 in all, a target the guard aims at, not a
  guarantee (validator check 7). A test that
  would start past its budget is designed to fail at once with `RUN_BUDGET_SPENT` (unverified until the run). At the upper estimates it would stop the
  last-ordered Wave tests first (on Main W1, the recorded walkthrough, W12 and W6; on Small W14a), which would
  make the run insufficient; the guard does not bound the time outside the UI tests, and only Apple's meter
  shows the real count.
- **Why it has not started.** The founder asked for the App Store Connect workflow triggers to be inspected
  before the push, by my own tools. None reaches App Store Connect: there is no API key and no Apple sign-in on
  this machine and no connector for it, and the standing rules forbid signing in or requesting Apple
  credentials. The same holds for creating the workflow, starting or cancelling the build, reading Apple's
  usage meter and downloading its screenshots and recordings. What GitHub can show was read instead
  (30 September 2026, 22:13Z): none of the 11 pushes or branch creations since Xcode Cloud was connected
  started a build within five minutes; nine never got an Xcode Cloud run, among them three new branches; the
  two that did started 18 minutes to nearly 2 hours later, consistent with a manual Start Build; there are no
  pull requests or tags. That contradicts an any-branch trigger on either existing workflow (Room
  Verification, Proximeet TestFlight), but cannot rule out one scoped to `wave/*`, or a change made after the
  last Xcode Cloud activity (16:22:28Z). It is evidence, not the inspection asked for, so the push is held.
- **The steps that remain** (runbook §5): the founder confirms the start conditions and creates the manual
  workflow; the lead pushes, proves the push with `git ls-remote` and watches ten minutes for any build that
  starts by itself; the founder presses Start Build at the candidate; the lead reads both actions' check runs
  on GitHub to the end and reports them; the founder downloads the result bundles (screenshots, recordings,
  logs) for the lead. No second build without a new authorization.
- **Xcode Cloud cannot run:** the 8 D2 source-reading tests (its test environment has no repository), and
  nothing in §7 below.

## 6. The preview path

There is no hosted preview. Codemagic is disabled and Appetize is not a delivery path; no Wave build exists.
- **In a native build that contains this commit** (a Debug run from Xcode, or a later internal build): Welcome →
  More options → Continue the demo (no account) → Birthday → Pass → Guest List (the name typed here is the one
  the Wave shows) → Wristband Social (or Business) → Signal → Places → Common Ground → Preview room demo →
  Enter room demo → Show populated example → View card on Maya's introduction (Jules's for Business) →
  **Preview Wave demo**; the menu's Back returns to that profile.
- **DEBUG shortcuts** (Xcode scheme arguments): `-ProximeetFixture wave-menu` (or any of the 12 `wave-*` keys),
  with `-ProximeetWavePanel`, `-ProximeetWaveReason`, `-ProximeetWaveFrom`, `-ProximeetWaveAfterBlock menu | room`
  (after `wave-blocked`: the disabled menu, or the Room's filtered People), `-ProximeetRoomBlocked` and
  `-ProximeetFixtureName`, as documented at the top of `DebugFixtures.swift`.
- **After the authorized build:** the result bundles keep every test's captures and screen recording
  (`keepAlways`). The motion walkthrough is W1's recording (the whole real route with full holds), with W2, W8
  and W10 for the menu's Back and the blocked menu. It will be the first time anyone sees the native Wave.

## 7. The honest remaining manual checks

None of these is covered by any automated row, and each is **PENDING FOUNDER**:
- **Native compilation and every automated row**: nothing has run on an Apple system.
- **VoiceOver:** reading order, focus after a panel closes and after the menu's Back, the modal panels, the
  decorative rings staying silent, "you (name)" in the direction line, the sentence-case labels, and the hints
  (on "Preview Wave demo", on the menu's Back and on the disabled choices). The tests check the accessibility
  tree, not speech, and XCUITest cannot read hints.
- **The system Reduce Motion setting:** the tests use the app's preview flag, not the setting.
- **Motion quality:** the 800-ms ring join on Accept, the 240-ms dissolves (the menu's Back included), and the
  ring shadow and pivot (decision 11), judged on video.
- **The device:** install, performance and feel on the founder's iPhone, and the founder's visual approval of
  the native Wave against the approved board, including the menu's new header and the blocked menu (its
  generic line may wrap to three lines on the 390-pt phone).

**Known baseline issues, carried and not caused by the Wave:** the Guest List negative-frame warning (it
predates the Room; whether it is gone is only known after a native run), and the largest-text wrapping of the
INTRODUCTIONS label.

## 8. Changed files (against `1a5f97e`, both candidates together)

| File | Against `1a5f97e` | Of which the second candidate (against `124c6a4`) |
| --- | --- | --- |
| `ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift` | new, +774 | +97 −38: participant-based lines, disabled starts, the Block's actor and run, run re-validation, the menu's chrome |
| `ProximeetDomain/Sources/ProximeetDomain/RoomDemo.swift` | +167 −30 | +19 −5: the Block's guard, `waveCounterpartBlocked`, the hint |
| `ProximeetDomain/Tests/ProximeetDomainTests/WaveDemoTests.swift` | new, +2,317 | +275 −57: four new tests, eight rewritten |
| `ProximeetDomain/Tests/ProximeetDomainTests/RoomDemoTests.swift` | +48 −11 | – |
| `Proximeet/Scenes/WaveView.swift` | new, +1,339 | +153 −54: the menu's Back, the blocked menu and `WaveChoiceStyle`, the direction line by participant, the Block's payload, the report card's hit area |
| `Proximeet/Scenes/RoomView.swift` | +116 −88 | +5 −3: the hint constant, a comment |
| `Proximeet/App/DemoSession.swift` | +33 | +7: `closeWaveDemo(_:)` |
| `Proximeet/App/DebugFixtures.swift` | +257 −25 | +28 −32: `-ProximeetWaveAfterBlock menu \| room`, the Block's payload |
| `ProximeetUITests/WaveReviewTests.swift` | new, +3,420 | +334 −85: the decisions' checks in the existing 14 methods |
| `ProximeetUITests/RunBudget.swift` | new, +155 | new: the compute guard |
| `ProximeetUITests/RoomReviewTests.swift` | +109 −102 | +9 −5: the guard, comments |
| `ProximeetUITests/PlacesReviewTests.swift`, `ProximeetUITests/PlacesCorrectionTests.swift` | +1 each | +1 each: the guard's first line |
| `TestPlans/WaveVerificationMain.xctestplan`, `TestPlans/WaveVerificationSmall.xctestplan` | new | +4 each: the budget variable |
| `TestPlans/RoomVerificationMain.xctestplan` | +3 −1: skips the two chapter-09 source readers | – |
| `Proximeet.xcodeproj/project.pbxproj`, `…/xcschemes/Proximeet.xcscheme` | regenerated: the new sources and the two plans | +4: `RunBudget.swift` |
| `scripts/validate_project.py` | +222 −13 | +96: the budget and guard checks |
| `scripts/generate_project.py`, `scripts/places_source_manifests.py` | the plans; the handoff copy | – |
| `docs/design/wave-approved/` | new: the approved handoff copy (§1) | – |
| `docs/verification/wave-xcode-cloud-manifest.tsv`, `docs/verification/wave-xcode-cloud-verification.md` | new | rewritten for the authorized build |
| `docs/verification/places-approved-files.sha256`, `docs/verification/places-review-files.sha256` | regenerated last; the review manifest also refreshes two base entries that were already out of date at `1a5f97e` (`ProximeetUITests/PlacesReviewTests.swift`, `ProximeetUITests/SignalReviewTests.swift`) | regenerated last |
| `docs/reports/wave-chapter-09.md` | this report | – |

Bundle identifier `com.goseng.proximeet` and Goseng automatic signing are unchanged (validator check 6; package
link and build phases, checks 4–5). The Release demo entry (`WelcomeView.swift`) is not in the diff. No Places,
Signal, Wristband, component, design-system or app-entry file changed.

## 9. Not done

- **Held, pending the start-condition inspection (§5):** the push, and with it the workflow, the build, its
  results, screenshots and motion walkthrough.
- **Not authorized:** a second build or any retry, the archive, TestFlight distribution, Codemagic, any change
  to billing, signing, other workflows or the default branch.
- **Out of scope:** Chat and Keep, not started.
