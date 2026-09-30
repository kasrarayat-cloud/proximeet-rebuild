#!/usr/bin/env python3
"""Write the Places source-gate manifests for the checkout (run from anywhere; last, after every edit).

    python3 scripts/places_source_manifests.py [--check]

docs/verification/places-approved-files.sha256 lists the approved assets: the Welcome poses, the
Manrope faces and licence, the Birthday housing, the Pass artwork, the Guest List card art, the four
Wristband artworks, the blank Signal tag, the three Places scenes, and the approved handoff copies of
every chapter (the Room's, docs/design/room-approved, and the Wave's, docs/design/wave-approved, included).
docs/verification/places-review-files.sha256 lists every other file of the checkout
(tracked or untracked, not ignored) except itself. scripts/places_review.sh checkpoint checks both.
With --check nothing is written; the exit is 1 when either manifest is out of date.
"""
import hashlib
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FROZEN = "docs/verification/places-approved-files.sha256"
REVIEW = "docs/verification/places-review-files.sha256"
ASSETS = "Proximeet/Resources/Assets.xcassets/"
APPROVED = [ASSETS + d + "/" for d in (
    "WelcomeClosed.imageset", "WelcomeOpening.imageset", "WelcomeSettled.imageset", "BirthdayHousing.imageset",
    "Manrope-Regular.dataset", "Manrope-Medium.dataset", "Manrope-SemiBold.dataset", "Manrope-Bold.dataset",
    "Manrope-ExtraBold.dataset", "Manrope-OFL.dataset", "PassArtwork.imageset", "GuestListCard.imageset",
    "WristbandSocial.imageset", "WristbandDating.imageset", "WristbandBusiness.imageset", "WristbandActivity.imageset",
    "SignalTag.imageset", "PlaceCommonGround.imageset", "PlaceAfterglow.imageset", "PlaceFieldwork.imageset")] + [
    "docs/design/welcome-approved/", "docs/design/birthday-approved/", "docs/design/pass-approved/",
    "docs/design/guest-list-approved/", "docs/design/wristband-approved/", "docs/design/signal-approved/",
    "docs/design/places-approved/", "docs/design/room-approved/", "docs/design/wave-approved/"]


def sha(path):
    with open(path, "rb") as data:
        return hashlib.sha256(data.read()).hexdigest()


def main(argv):
    os.chdir(ROOT)
    check = "--check" in argv[1:]
    listed = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                            capture_output=True, text=True, check=True).stdout.split("\n")
    files = sorted(f for f in listed if f and os.path.isfile(f) and "/__pycache__/" not in f and not f.endswith(".pyc"))
    frozen = [f for f in files if any(f.startswith(d) for d in APPROVED)]
    for prefix in APPROVED:
        if not any(f.startswith(prefix) for f in frozen):
            print("nothing under " + prefix)
            return 1
    review = sorted(set(f for f in files if f not in frozen and f != REVIEW) | {FROZEN})
    frozen_text = ("# Places approved assets: the Welcome poses, the Manrope faces and licence, the Birthday housing, the\n"
                   "# Pass artwork, the Guest List card art, the four Wristband artworks, the blank Signal tag, the three\n"
                   "# Places scenes, and the approved Welcome, Birthday, Pass, Guest List, Wristband, Signal, Places and\n"
                   "# Room handoff copies. Checked by scripts/places_review.sh checkpoint; written by\n"
                   "# scripts/places_source_manifests.py.\n") + "".join("%s  %s\n" % (sha(f), f) for f in frozen)
    if check:
        current = open(FROZEN).read() if os.path.isfile(FROZEN) else ""
        if current != frozen_text:
            print("out of date: " + FROZEN)
            return 1
    else:
        with open(FROZEN, "w") as out:
            out.write(frozen_text)
    review_text = ("# Every other file of the reviewed Places revision, except this manifest itself. Checked by\n"
                   "# scripts/places_review.sh checkpoint (the commit is pinned by the run input); written by\n"
                   "# scripts/places_source_manifests.py.\n") + "".join(
        "%s  %s\n" % (sha(f) if os.path.isfile(f) else "0" * 64, f) for f in review)
    if check:
        current = open(REVIEW).read() if os.path.isfile(REVIEW) else ""
        if current != review_text:
            print("out of date: " + REVIEW)
            return 1
        print("up to date: approved %d, review %d" % (len(frozen), len(review)))
        return 0
    with open(REVIEW, "w") as out:
        out.write(review_text)
    print("approved %d, review %d" % (len(frozen), len(review)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
