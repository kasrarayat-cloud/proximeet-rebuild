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

The harness consists of:
- `scripts/welcome_review.sh`: the steps checkpoint, destinations, captures, ui-review and verdict;
- `scripts/birthday_review.sh`: the Birthday steps, including package-review and enforce;
- `ProximeetUITests/BirthdayReviewTests.swift`: skipped unless the runner gets `PROXIMEET_BIRTHDAY_REVIEW=1`;
- `ProximeetUITests/WelcomeReviewTests.swift`: skipped unless the runner gets `PROXIMEET_WELCOME_REVIEW=1`;
- `scripts/analyze_welcome_review.py`: off-machine analysis that needs ffmpeg; `--self-test` checks it against the approved references only.
