# Verification

How chapters are verified on real Apple tooling. Nothing here runs by itself.

| File | Purpose |
| --- | --- |
| `welcome-mac-review.md` | The Welcome run: the manual, unsigned simulator workflow `proximeet-welcome-review` in the root `codemagic.yaml`, plus the source gate, steps, artifacts, prerequisites, triggers and sources |
| `welcome-runtime-review.md` | What the run must show, with automated checks kept apart from manual visual and VoiceOver review |
| `welcome-approved-files.sha256` | SHA-256 of the frozen Welcome: every file under `Proximeet/`, `Proximeet.xcodeproj/`, `ProximeetDomain/` and `docs/design/welcome-approved/` |
| `welcome-review-files.sha256` | SHA-256 of every other tracked file, except itself |
| `welcome-review-deletions.txt` | Files the Welcome change removed; the gate confirms they are absent |

The harness consists of:
- `scripts/welcome_review.sh`: the steps checkpoint, destinations, captures, ui-review and verdict;
- `ProximeetUITests/WelcomeReviewTests.swift`: skipped unless the runner gets `PROXIMEET_WELCOME_REVIEW=1`;
- `scripts/analyze_welcome_review.py`: off-machine analysis that needs ffmpeg; `--self-test` checks it against the approved references only.
