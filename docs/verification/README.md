# Verification

Material for verifying chapters on real Apple tooling. Nothing in this folder runs by itself;
in particular `codemagic-welcome-review.yaml` is an inert proposal, because Codemagic reads
only the root `codemagic.yaml`.

| File | Purpose |
| --- | --- |
| `welcome-mac-review.md` | The recipe: one manual, unsigned iOS Simulator run of the checkpointed Welcome, with prerequisites, triggers, artifacts and sources |
| `welcome-runtime-review.md` | What that run must show; automated checks are separated from manual visual and VoiceOver review |
| `codemagic-welcome-review.yaml` | The proposed manual Codemagic workflow (no triggering, no signing) |
| `welcome-review-files.sha256` | SHA-256 of every file the Welcome change adds or modifies; `scripts/welcome_review.sh checkpoint` checks it |
| `welcome-review-deletions.txt` | Files the Welcome change removes; the gate confirms they are absent |

Harness:
- `scripts/welcome_review.sh` runs the stages.
- `ProximeetUITests/WelcomeReviewTests.swift` holds the XCTest review. It skips unless `TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1` is set.
- `scripts/analyze_welcome_review.py` does the off-machine analysis and needs ffmpeg. `--self-test` runs it against the approved references.
