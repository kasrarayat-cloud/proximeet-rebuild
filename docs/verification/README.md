# Verification

How chapters are verified on real Apple tooling. Nothing here runs by itself.

| File | Purpose |
| --- | --- |
| `welcome-mac-review.md` | The Welcome run: the manual, unsigned simulator workflow `proximeet-welcome-review` in the root `codemagic.yaml`, plus the source gate, steps, artifacts, prerequisites, triggers and sources |
| `welcome-runtime-review.md` | What the run must show, with automated checks kept apart from manual visual and VoiceOver review |
| `welcome-approved-files.sha256` | SHA-256 of the frozen Welcome: every file under `Proximeet/`, `Proximeet.xcodeproj/`, `ProximeetDomain/` and `docs/design/welcome-approved/` |
| `welcome-review-files.sha256` | SHA-256 of every other tracked file, except itself |
| `welcome-review-deletions.txt` | Files the Welcome change removed; the gate confirms they are absent |
| `birthday-mac-review.md` | The Birthday run: the manual, unsigned simulator workflow `proximeet-birthday-review`, its source gate, steps and `Birthday-Review.zip` |
| `birthday-approved-files.sha256` | SHA-256 of the approved assets: Welcome poses, Manrope faces and licence, the Birthday housing, and `docs/design/welcome-approved/` and `docs/design/birthday-approved/` |
| `birthday-review-files.sha256` | SHA-256 of every other file, except itself |
| `pass-mac-review.md` | The Pass run: the manual, unsigned simulator workflow `proximeet-pass-review`, its source gate, steps and downloads |
| `pass-approved-files.sha256` | SHA-256 of the approved assets: Welcome poses, Manrope faces and licence, the Birthday housing, the Pass artwork, and the three `docs/design/*-approved/` folders |
| `pass-review-files.sha256` | SHA-256 of every other file, except itself |
| `pass-review-deletions.txt` | Files removed by the approved chapters (Welcome's, and the legacy `DemoPassView.swift`); the Pass gate confirms they are absent |
| `guest-list-mac-review.md` | The Guest List run: the manual, unsigned simulator workflow `proximeet-guest-list-review`, its source gate, steps and downloads |
| `guest-list-approved-files.sha256` | SHA-256 of the approved assets: those of the Pass, the Guest List card art, and the four `docs/design/*-approved/` folders |
| `guest-list-review-files.sha256` | SHA-256 of every other file, except itself |
| `guest-list-review-deletions.txt` | Files removed by the approved chapters; the Guest List gate confirms they are absent |
| `wristband-mac-review.md` | The Wristband run: the manual, unsigned simulator workflow `proximeet-wristband-review`, its source gate, steps, the Guest List keyboard follow-up and downloads |
| `wristband-approved-files.sha256` | SHA-256 of the approved assets: those of the Guest List, the four Wristband artworks, and the five `docs/design/*-approved/` folders |
| `wristband-review-files.sha256` | SHA-256 of every other file, except itself |
| `wristband-review-deletions.txt` | Files removed by the approved chapters, now including the legacy `BandSelectionView.swift`; the Wristband gate confirms they are absent |
| `signal-mac-review.md` | The Signal run: the manual, unsigned simulator workflow `proximeet-signal-review`, its two scopes on one commit, source gate, steps, integration checks and downloads |
| `signal-approved-files.sha256` | SHA-256 of the approved assets: those of the Wristband, the blank Signal tag, and the six `docs/design/*-approved/` folders |
| `signal-review-files.sha256` | SHA-256 of every other file, except itself |
| `signal-review-deletions.txt` | Files removed by the approved chapters, now including the legacy `SignalSelectionView.swift`; the Signal gate confirms they are absent |
| `places-mac-review.md` | The Places run: the manual, unsigned simulator workflow `proximeet-places-review` (with its 24-minute twin `proximeet-places-review-short` and its 35-minute twin `proximeet-places-review-35`, which also publishes a runnable preview copy of the app), its scopes (places, signal, regressions, the targeted correction, the sweep, gate_finish and sweep_finish), the infrastructure rerun (a run whose test runner failed to initialize, or whose simulator was not found, runs once more; not a retry), the recovery (build 2, the correction on `808950f`, where C10–C15 passed and the iPhone 17 Pro Max's runner never started a test; then gate_finish and sweep_finish, the last two builds), its row-level reconciliation with two verdicts, the rows left pending (B2–B9 and the optional B14) and why, source gate, steps and downloads |
| `places-review-manifest.tsv` | Every execution of every scope (places, signal, regressions, the targeted correction, the sweep, and the recovery's last two builds: gate_finish, C1–C9 with extras, and sweep_finish): device, run, bound and kind; the harness runs it and the results parser judges it |
| `places-recovery-coverage.tsv` | Every row the recovery reconciles (C1–C15, the 56 earlier required executions and the optional B14) and the build, scope and run expected to execute it: build 2 (correction), 3 (gate_finish), 4 (sweep_finish), or pending (B2–B9, B14). A row is covered by a passed execution of the same test on the same device class in the same run type at a commit whose product and test files equal `808950f`'s; the stated exceptions are P1 (short holds, not recorded) and the M rows on device B (main's clone) |
| `places-correction-before/` | 1× copies of build 6ab8639c's defect captures, with `provenance.json` (each original's name and SHA-256), shown beside the correction's captures |
| `places-approved-files.sha256` | SHA-256 of the approved assets: those of Signal, the three Places scenes, and the seven `docs/design/*-approved/` folders |
| `places-review-files.sha256` | SHA-256 of every other file, except itself |
| `places-review-deletions.txt` | Files removed by the approved chapters; the Places gate confirms they are absent |

The harness consists of:
- `scripts/welcome_review.sh`: the steps checkpoint, destinations, captures, ui-review and verdict;
- `scripts/birthday_review.sh`: the Birthday steps, including package-review and enforce;
- `ProximeetUITests/BirthdayReviewTests.swift`: skipped unless the runner gets `PROXIMEET_BIRTHDAY_REVIEW=1`;
- `scripts/pass_review.sh` and `scripts/compact_video.swift`: the Pass steps and the compact walkthrough video;
- `ProximeetUITests/PassReviewTests.swift`: skipped unless the runner gets `PROXIMEET_PASS_REVIEW=1`;
- `scripts/guest_list_review.sh`: the Guest List steps, reusing `scripts/compact_video.swift`;
- `ProximeetUITests/GuestListReviewTests.swift`: skipped unless the runner gets `PROXIMEET_GUEST_LIST_REVIEW=1`;
- `scripts/wristband_review.sh`: the Wristband steps, with a second iPhone 17 Pro Max for the regressions and a time budget;
- `ProximeetUITests/WristbandReviewTests.swift`: skipped unless the runner gets `PROXIMEET_WRISTBAND_REVIEW=1`;
- `scripts/signal_review.sh`: the Signal steps, with a `signal` and a `regressions` scope (`SIGNAL_REVIEW_SCOPE`) run as two builds on one commit;
- `ProximeetUITests/SignalReviewTests.swift`: skipped unless the runner gets `PROXIMEET_SIGNAL_REVIEW=1`;
- `ProximeetUITests/BandSignalInteractionTests.swift`: ungated; the approved Wristband → Signal interaction, now ending in Places;
- `scripts/places_review.sh`, `scripts/places_review_results.py`, `scripts/places_review_package.py` and
  `scripts/places_source_manifests.py`: the Places steps, driven and judged by `places-review-manifest.tsv`
  (`PLACES_REVIEW_SCOPE`), its packages and its source-gate manifests;
- `scripts/places_recovery_reconcile.py`: reconciles any number of builds' results row by row by
  `places-recovery-coverage.tsv`, counting only builds whose `git_head` is product-equivalent to
  `808950f` (it prints every head's `git diff --name-only`); prints two verdicts, TARGETED CORRECTION
  (C1–C15: PASS or FAIL) and FULL REGRESSION (the 56 earlier required executions: PASS, INCOMPLETE
  with the uncovered rows, or FAIL); `--assume-product-equivalent` is a test mode for stubbed heads;
- `ProximeetUITests/PlacesReviewTests.swift`: skipped unless the runner gets `PROXIMEET_PLACES_REVIEW=1`;
- `ProximeetUITests/WelcomeReviewTests.swift`: skipped unless the runner gets `PROXIMEET_WELCOME_REVIEW=1`;
- `scripts/analyze_welcome_review.py`: off-machine analysis that needs ffmpeg; `--self-test` checks it against the approved references only.
