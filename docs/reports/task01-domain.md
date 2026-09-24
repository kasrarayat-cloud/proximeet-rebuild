# Task 01A — ProximeetDomain report

Date: 24 September 2026 · Scope: `ProximeetDomain` package and its tests only. No SwiftUI, Xcode project, assets or visual work in this pass. Nothing committed, pushed or sent anywhere.

## Result

| Check | Outcome |
|---|---|
| Linux build, clean (`swift package clean` then `swift test`) | **PASS**. 0 warnings, 0 errors (Swift 6.3.3, tools-version 5.9, Swift 5 language mode, `StrictConcurrency` enabled) |
| XCTest | **53 / 53 passed**, 0 failures |
| Mutation checks (8 deliberate changes in 3 batches, all reverted) | Each batch failed with relevant assertions; final restored-source suite passed. Not 8 independent runs. |
| Swift 5.9 / Xcode 15 compile | **NOT RUN**. No 5.9 toolchain or Apple SDK on this VPS |
| iOS simulator/device, SwiftUI, Xcode project | **NOT RUN**. Out of scope for this pass |

## Commands and outcomes

Run from `/home/proximeet/proximeet-rebuild`:

```
swift --version
# Swift version 6.3.3 (swift-6.3.3-RELEASE), Target: x86_64-unknown-linux-gnu

swift package --package-path ProximeetDomain clean
swift test --package-path ProximeetDomain --jobs 2
# Build complete! (12.53s)
# BirthdayEligibilityTests   Executed 11 tests, with 0 failures
# DemoFlowInvariantTests     Executed  2 tests, with 0 failures
# DemoFlowTests              Executed 26 tests, with 0 failures
# DomainSourceGuardTests     Executed  2 tests, with 0 failures
# GuestProfileTests          Executed 12 tests, with 0 failures
# All tests                  Executed 53 tests, with 0 failures (0 unexpected)
# Swift Testing: "Test run with 0 tests" (expected: the suite uses XCTest only)
```

No `warning:` or `error:` lines appeared in the clean build output.

## Files

```
ProximeetDomain/Package.swift                     tools 5.9, iOS 17 / macOS 14, one library product
Sources/ProximeetDomain/
  BandIntent.swift          4 intents: title + neutral summary        (retained from earlier pass)
  ApproachSignal.swift      4 signals: title + neutral summary        (retained)
  BirthdayEligibility.swift injected date + calendar, Gregorian-normalised, day-based   (retained)
  GuestProfile.swift        validated-only profile, ProfileIssue list, whitespace/invisible-char normalisation
  DemoScene.swift           7 scenes and their fixed `next` order
  DemoDraft.swift           in-memory draft (DOB, profile, band, signal) + per-scene requirements
  DemoFlow.swift            navigation path + all transitions, reset, derived readiness
  ReadyForCheckIn.swift     summary; PassMark (only .demo "DEMO"); DraftVisibility (only "Demo — not visible to anyone")
Tests/ProximeetDomainTests/
  TestFixtures.swift, BirthdayEligibilityTests.swift, GuestProfileTests.swift,
  DemoFlowTests.swift, DemoFlowInvariantTests.swift, DomainSourceGuardTests.swift
```

Changes to earlier scaffolding: removed the not-yet-used `ProximeetDesignTokens` target from `Package.swift`. Also removed the empty directories I had created before the interruption (`Proximeet/`, `scripts/`, and the tokens source/test directories). They contained no files. The four retained source files are unchanged.

## Model in brief

- `DemoFlow` is a value type with `path: [DemoScene]` above the Welcome root, plus `draft: DemoDraft`. Both have `private(set)`/`internal(set)` setters, so app code can change them only through the actions.
- Actions are `begin`, `submitBirthday(_:using:)`, `continueFromPass`, `saveProfile(firstName:interests:)`, `continueFromGuestList`, `selectBand`, `confirmBand`, `selectSignal`, `confirmSignal`, `goBack`, `returnTo(_:)`, `adoptNavigationPath(_:)` and `reset`.
- Every forward move goes through a single guard. The current scene must be the source, and `draft.meetsRequirements(for: next)` must hold. Neither check depends on UI button state.
- `adoptNavigationPath` accepts only pops (a strict prefix of the current path). This lets a future `NavigationStack` binding handle system back gestures without being able to skip validation.
- `readiness` is recomputed from the draft on every read and is non-nil only on the ready scene. It has no stored "ready" flag that could go stale.
- There are no `async` APIs, timers, clock reads, `Codable` conformances, persistence, networking, presence or authentication. The birthday check's reference date and calendar are injected by the caller.

## Invariant → test map

| Requirement | Tests |
|---|---|
| Forward actions reject absent/invalid data, independent of UI | `testForwardActionsAreRejectedOutsideTheirScene`, `testBirthdayMustBeSubmittedAndEligibleToReachThePass`, `testGuestListRequiresAValidProfileBeforeContinuing`, `testBandCannotBeConfirmedWithoutASelection`, `testSignalCannotBeConfirmedWithoutASelection`, `testAfterResetEveryStepNeedsFreshInput`, invariant fuzz |
| Injected date + Gregorian calendar; future and under-18 rejected; exact 18th accepted | `testExactEighteenthBirthdayIsEligible`, `testDayBeforeEighteenthBirthdayIsUnderage`, `testFutureDateIsRejected`, `testBornEarlierTodayIsUnderageNotFuture`, `testTimeOfDayNeverDecidesTheResult`, `testInjectedReferenceDateDecidesNotTheClock`, `testInjectedTimeZoneDecidesWhichDayAnInstantIsOn`, `testNonGregorianCalendarIsNormalisedToGregorian` (Japanese, Buddhist) |
| Leap-day behaviour documented and tested | `testLeapDayBirthdayBecomesEligibleOnFirstOfMarch`, `testTwentyEighthOfFebruaryBirthdayIsUnaffectedByLeapRule` |
| No claim of verified age | `BirthdayCheck.eligible.message` says the date "is self-entered and has not been checked"; `testDomainCopyMakesNoVerificationPresenceOrAccountClaims` |
| First name + 3 non-blank distinct interests, trimmed | all of `GuestProfileTests` (blank, invisible-only, count ≠ 3, duplicates incl. case/spacing/zero-width, limits, joiners kept, multi-issue ordering) |
| Rejected profile saves preserve the last valid saved profile; readiness follows navigation | `testInvalidProfileEditOnSummaryKeepsTheLastValidProfile`, `testReturningToAnEarlierSceneWithdrawsReadinessUntilReconfirmed`, invariant fuzz (readiness ⇔ ready scene, and matches draft) |
| One of four intents / signals; missing can't confirm; repeated selection replaces | `testEveryBandAndSignalCombinationSurvivesConfirmation` (all 16), `testRepeatedSelectionsKeepOnlyTheLatestChoice`, `testRepeatedConfirmationDoesNotAdvanceTwice` |
| Back navigation retains drafts | `testBackNavigationRetainsTheDraftAtEveryStep`, `testNavigationCanOnlyPopNeverSkipOrRewrite` |
| Edits appear in summary | `testBandEditAppearsInSummary`, `testSignalEditAppearsInSummary`, `testProfileEditOnSummaryAppearsImmediately`, `testProfileEditOnGuestListReachesSummary` |
| Reset clears personal data and selections | `testResetFromEverySceneClearsAllPersonalDataAndSelections`, `testAfterResetEveryStepNeedsFreshInput` |
| No persistence/presence/auth/network/verification side effects | `testDraftStateHasNoPersistenceConformance`, `testReadySummaryIsDemoOnlyAndEndsTheJourney` (DEMO only, not visible, no scene after ready, no forward action changes state), `DomainSourceGuardTests` (source scan with comments stripped) |
| Independent of animation/elapsed time | `testTransitionsAreImmediateAndRepeatable`, `testSameActionSequenceAlwaysProducesTheSameState`, `testInjectedReferenceDateDecidesNotTheClock`, `DomainSourceGuardTests` (no `Date()`, `Date.now`, timers, dispatch, `async`/`await`) |

The invariant fuzz runs 40 seeds × 400 random actions, deterministic SplitMix64. It mixes out-of-order, repeated and invalid actions with pops and attempted push/rewrite paths. After every step it checks four things: the path is in journey order, every scene on the path has its data, any stored birthday is eligible, and readiness exists only on the ready scene and matches the draft.

## Mutation check

Eight mutations were applied in three batches: exact-birthday + forward guards; leap-day + path validation + underage reset; readiness + reset + invalid profile. Each batch produced relevant failing assertions, then its edits were reverted. These were not eight isolated mutation runs. The lead independently reran the final restored package: direct process exit 0, 53 XCTest cases passed, no warnings.

| Mutant | Caught by |
|---|---|
| Exact 18th birthday rejected (`>=` → `>`) | 6 birthday tests + `testBirthdayMustBeSubmittedAndEligibleToReachThePass` |
| Leap-day 18th on 28 Feb instead of 1 Mar | `testLeapDayBirthdayBecomesEligibleOnFirstOfMarch` |
| Forward moves ignore draft requirements | 4 gating tests + reset test + invariant fuzz |
| Navigation accepts any proposed path | `testNavigationCanOnlyPopNeverSkipOrRewrite` + invariant fuzz |
| Under-18 result keeps the rest of the draft | `testUnderageResultAfterEarlierAcceptanceClearsTheWholeDraft` |
| Readiness available off the ready scene | `testReturningToAnEarlierSceneWithdrawsReadinessUntilReconfirmed` + invariant fuzz |
| Reset clears only the path | both reset tests |
| Invalid profile accepted | profile validation tests + `testInvalidProfileEditOnSummaryKeepsTheLastValidProfile` |

## Decisions for lead review

1. **`confirmBand()` moves straight to Signal.** There is no separate "secured but still on Band" state. The secured-band pose can be a UI treatment on arrival at Signal. If you want a two-step Band screen (secure, then Continue), a flag needs adding here.
2. **A rejected birthday is handled by severity.** An under-18 result clears the whole draft. A future date clears only the stored date of birth. In both cases the flow stays on Birthday.
3. **Profile edits are accepted on Guest List and in place on Ready.** Band and signal edits use `returnTo(.band)` / `returnTo(.signal)`. This removes readiness until the guest confirms forward again, with the retained values pre-selected.
4. **The date of birth stays in memory for the run** so the Birthday screen can show it after back navigation. It is excluded from `ReadyForCheckIn` and cleared by reset.
5. **Provisional profile rules.**
   - First name and each interest are limited to 30 characters (grapheme count).
   - Duplicate interests are compared with `lowercased()` after normalisation. Diacritics and `ß`/`ss` are not folded.
   - Characters made only of control/format scalars, such as a standalone zero-width space, are removed. Joiners inside emoji or words are kept.
   - No character-class restrictions, such as banning digits, were added, to avoid setting product policy.
6. **Domain copy is proposed wording.** This covers intent/signal summaries, birthday messages and profile issue messages. The notice is exactly "Demo — not visible to anyone", and the pass mark is exactly "DEMO".

## Blocked actions and remaining gaps

- **Blocked:** a read-only multi-agent review via the Workflow tool returned "Review dynamic workflow before running" and did not run. I didn't route around it. I reviewed the code myself and ran the mutation check above instead. The one real defect this found (an invisible-only name counted as non-blank) is fixed and tested.
- **Blocked:** a compound shell command with a `/tmp` redirect needed approval. I dropped it and ran the allow-listed commands separately instead.
- **Swift 5.9 / Xcode 15:** not compiler-verified. I used only 5.9-era language features and XCTest, but this was checked by review, not by compiling.
- `.enableExperimentalFeature("StrictConcurrency")` produced no warnings on 6.3.3. It has not been tried on Xcode 15.
- **`DomainSourceGuardTests` finds the sources via `#filePath`.** Host `swift test` is verified. Simulator behavior has not been tested; physical-device source access is unavailable, so these host source scans must be skipped or kept out of device test runs.
- **Not in this pass:** no app target, Xcode project or scheme, and no UI, accessibility, motion, haptics or visual work. Native build, screenshots, device behaviour and TestFlight are all **NOT RUN**.

## Lead review note

The lead independently confirmed the direct test process exited 0 with 53 passing XCTest cases. Transactional profile saves are accepted for this demo: invalid input does not replace the last valid saved profile. The SwiftUI integration must keep invalid edits visible and advance/dismiss only on `.saved`; otherwise it could navigate using old saved data. Confirming Band may move directly to Signal, where the same band takes its secured pose. No additional founder decision is needed for these reversible implementation choices.
