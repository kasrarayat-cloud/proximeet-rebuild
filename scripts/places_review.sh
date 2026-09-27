#!/usr/bin/env bash
# Proximeet — runtime review of the approved Places (chapter 07) and of every earlier chapter's
# checks, in the iOS Simulator. Manual and unsigned. Codemagic workflow: proximeet-places-review
# (codemagic.yaml). See docs/verification/places-mac-review.md.
#
#   PLACES_REVIEW_SCOPE=places|signal|regressions bash scripts/places_review.sh <stage>
#
# Scopes (the run input PLACES_REVIEW_SCOPE; each runs as its own build, and every result says which
# build and which commit supplied it). What each scope runs, on which device, in which order and
# within which bound comes from docs/verification/places-review-manifest.tsv:
#   places       the Places review: the recorded full journey from Welcome through Signal into
#                Places, the seven screens (on the iPhone 17 Pro Max and the smaller iPhone), all
#                twelve intent-venue combinations, Back routes with the retained category and draft,
#                the band change, missing choices and the guarded explanation, the Birthday gate on
#                the way back, relaunch, rapid taps and interruptions, the Reduce Motion preview flag
#                and the largest text size on two widths
#   signal       the 16 Signal executions of build 6ab7e942, with Continue preview now opening
#                Places (the intentional endpoint change)
#   regressions  the 27 required executions of the Signal regression correction (build 6ab81e22):
#                the Wristband, the Guest List, the Pass, Birthday and Welcome, with its time-gated
#                repeat of the paste test
#   correction   the targeted Places correction (after build 6ab8639c): the adaptive ticket footer
#                on both widths at the default and the largest text, one-stage back gestures and
#                controls (with a cancelled swipe), where a detail and the explanation start, the
#                five Signal and interaction tests whose endpoint changed, a short recording of the
#                corrected scrolling and back swipes, and time-gated re-runs of earlier Places tests
#                (kind "extra": run only when they fit; if they run they must pass)
# Automatic retries are off in every scope: a test that fails, even once, is a failure; a skipped,
# interrupted or missing required execution is a failure.
#
# Stages:
#   checkpoint    source gate. The approved assets (Welcome poses, Manrope fonts and licence, the
#                 Birthday housing, the Pass artwork, the Guest List card art, the four band
#                 artworks, the blank Signal tag, the three Places scenes, the approved references)
#                 must match docs/verification/places-approved-files.sha256 and their handoff
#                 provenance; every other file must match docs/verification/places-review-files.sha256
#                 (which excludes only itself); no other file may exist; earlier deletions stay
#                 absent; the Signal guard still holds for the approved route's sources, the Places
#                 guard for Places' own (no clock, location, camera, scanning, network, persistence,
#                 logging, timer or visibility API), and the approved screens never use the legacy
#                 intent tint. Run inputs PLACES_EXPECTED_COMMIT (full 40-hex SHA) pins HEAD and
#                 PLACES_REVIEW_SCOPE names the scope; both required on Codemagic (CM_BUILD_ID set).
#                 Also records the time budget's start. Runs anywhere.
#   destinations  list installed simulators; report whether iPhone 17 Pro Max was selected; start
#                 the first boots of the selected simulator and the scope's other device (device B,
#                 cloned from it before either boots, or a smaller iPhone) behind the compilation
#   ui-review     compile the UI test harness; give the other device its own copy of the build
#                 products; run the scope's main and other-device runs in parallel (device B is
#                 deleted after the run). The places scope records its full journey first; the
#                 compact video is made in the background once the recording ends. Every xcodebuild
#                 is bounded by time and interrupted (SIGINT) at its bound so it can close its result
#                 bundle before it is killed (the UI deadline is 1380 s after the checkpoint, or the
#                 run input). Every execution is judged against the manifest by
#                 scripts/places_review_results.py
#   compact-video half-size re-encode of the recording, trimmed to the app (places scope)
#   verdict       automated results, kept apart from outstanding manual review
#   package-review  scripts/places_review_package.py: Places-Review.zip, Places-Screens.zip,
#                 Places-walkthrough-compact.zip (and the loose .mp4 when re-encoded) and
#                 Places-walkthrough-original.zip (places scope), or Places-Signal-Review.zip /
#                 Places-Regressions-Review.zip; each with an offline index.html and its SHA-256
#   enforce       fail the build unless the verdict says PASS (run last)
#
# Outputs go to build/artifacts/places/, logs to build/artifacts/logs/places-<stage>*.log, and
# PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or downloaded and no
# simulator runtime is installed. Written for the macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
OUT="$ARTIFACTS/places"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DEVICE_B_ENV="$META/places-device-b.env"
SMALL_ENV="$META/places-smaller.env"
T0_FILE="$META/places-t0.txt"
SCOPE_FILE="$META/places-scope.txt"
DERIVED_DATA="$ROOT/build/DerivedData"
DERIVED_DATA_B="$ROOT/build/DerivedDataB"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/places-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/places-review-files.sha256"
DELETIONS="docs/verification/places-review-deletions.txt"
RUN_MANIFEST="docs/verification/places-review-manifest.tsv"
CHECKPOINT_RESULT="$OUT/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
DEVICE_B_NAME="iPhone 17 Pro Max (places review B)"
SMALLER_IPHONES="iPhone 17e|iPhone 16e|iPhone SE (3rd generation)|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
# The UI work must end this many seconds after the checkpoint stage began (47-58 s into the build on
# this host type). After it come an interrupted xcodebuild's grace (TEST_GRACE_SECONDS), its export
# (the two result summaries, at most RESULTS_SECONDS each, and the attachments, at most
# EXPORT_SECONDS), then the verdict, the packages and publishing; build 6ab81e22 needed 8 s for those
# after its UI review. At the worst: 58 + 1380 + 75 + (20 + 20 + 60) + about 30 = 1643 s, about 27:25,
# inside the workflow's 28 minutes. A normal run ends minutes before the deadline.
UI_DEADLINE_SECONDS=1380
# A lower deadline for a build with a shorter limit: the run input PLACES_UI_DEADLINE_SECONDS, 600 to
# 1380, digits only (the workflow proximeet-places-review-short, 24 minutes, sets 1110: at the worst
# 72 + 1110 + 75 + 100 + about 40 = 1397 s). The source gate rejects any other value.
case "${PLACES_UI_DEADLINE_SECONDS:-}" in
    ''|*[!0-9]*|0*) ;;
    *)
        if [ "$PLACES_UI_DEADLINE_SECONDS" -ge 600 ] && [ "$PLACES_UI_DEADLINE_SECONDS" -le 1380 ]; then
            UI_DEADLINE_SECONDS="$PLACES_UI_DEADLINE_SECONDS"
        fi
        ;;
esac
# xcodebuild needs 13-57 s to close its result bundle after its last test on this host type; an
# interrupted run gets 75 s before SIGKILL.
TEST_GRACE_SECONDS=75
EXPORT_SECONDS=60
RESULTS_SECONDS=20
# The regressions scope's planned paste repeat runs only while this much time is left before the
# deadline (build 6ab81e22's measurements: the repeat run about 165 s at worst, the required
# hardware-key run after it about 105 s, 30 s spare).
REPEAT_GATE_SECONDS=300
TEST_TIMEOUTS="-test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 360"
TEST_BOUND="bounded_test"
SETTLE_SECONDS=3
STATUS_BARS=""
RECORDER_PID=""
BOOTED_BY_US=""
DEVICE_B_CREATED=""
B_PID=""
COMPACT_PID=""
ENCODER_PID=""
LAST_RUN_STATUS=0

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce) ;;
    *)
        echo "usage: PLACES_REVIEW_SCOPE=places|signal|regressions $0 checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$OUT"
LOG="$LOGS/places-$STAGE${PLACES_LOG_SUFFIX:-}.log"
: > "$LOG"
# The scope recorded by the checkpoint (the checkpoint itself reads the run input).
SCOPE="$(cat "$SCOPE_FILE" 2>/dev/null || true)"
[ -n "$SCOPE" ] || SCOPE="${PLACES_REVIEW_SCOPE:-places}"

utc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
summary_line() { printf '%s  %-17s %s\n' "$(utc_now)" "$1" "$2" >> "$SUMMARY"; }
note() { printf '%s\n' "$*" | tee -a "$LOG"; }

run() {
    printf '\n$ %s\n' "$*" | tee -a "$LOG"
    set +e
    "$@" 2>&1 | tee -a "$LOG"
    local command_status="${PIPESTATUS[0]}" tee_status="${PIPESTATUS[1]}"
    set -e
    if [ "$command_status" -eq 0 ] && [ "$tee_status" -ne 0 ]; then
        command_status="$tee_status"
    fi
    printf '[exit %s] %s\n' "$command_status" "$*" | tee -a "$LOG"
    return "$command_status"
}

# bounded <seconds> <command...>: the command is ended by SIGALRM (exit 142) after <seconds>. The
# alarm survives exec, so it applies to the command itself.
bounded() {
    local seconds="$1"
    shift
    if [ "$seconds" -lt 1 ]; then
        seconds=1
    fi
    perl -e '$t = shift @ARGV; alarm $t; exec { $ARGV[0] } @ARGV or die "exec failed: $!\n"' "$seconds" "$@"
}

# bounded_test <seconds> <command...>: for an xcodebuild test run. The command runs in its own
# process group. At <seconds> the group gets SIGINT, as from Ctrl-C, which xcodebuild answers by
# stopping its tests and closing its result bundle; only if it is still running
# TEST_GRACE_SECONDS later does the group get SIGKILL; after a stop, whatever is left of the group
# gets SIGKILL too, so no helper is left holding the log pipe.
# Exits 142 when the bound was reached (as bounded does), otherwise with the command's own status.
bounded_test() {
    local seconds="$1"
    shift
    if [ "$seconds" -lt 1 ]; then
        seconds=1
    fi
    perl -e '
        use POSIX ();
        my ($limit, $grace) = (shift @ARGV, shift @ARGV);
        my $pid = fork();
        die "fork failed: $!\n" unless defined $pid;
        if ($pid == 0) {
            # The device B lane is a background job, which starts with SIGINT ignored; the command
            # gets the default back, so the stop below reaches it.
            $SIG{INT} = "DEFAULT";
            $SIG{QUIT} = "DEFAULT";
            POSIX::setsid();
            exec { $ARGV[0] } @ARGV or die "exec failed: $!\n";
        }
        my ($deadline, $stopped, $killed) = (time + $limit, 0, 0);
        # Signals meant for this stage reach the group too: SIGINT stops it as the bound would;
        # SIGTERM or SIGHUP kill it.
        my $end = sub { kill "-KILL", $pid; exit 143; };
        $SIG{TERM} = $end;
        $SIG{HUP} = $end;
        $SIG{INT} = sub { $deadline = 0 unless $stopped; };
        while (1) {
            my $done = waitpid($pid, POSIX::WNOHANG());
            if ($done == $pid) {
                my $status = $?;
                if ($stopped) {
                    kill "-KILL", $pid;
                    exit 142;
                }
                exit(($status & 127) ? 128 + ($status & 127) : ($status >> 8));
            }
            exit 1 if $done < 0;
            my $now = time;
            if (!$stopped && $now >= $deadline) {
                ($stopped, $deadline) = (1, $now + $grace);
                print STDERR "bounded_test: stopping at ${limit} s (or on SIGINT); SIGINT to process group $pid, SIGKILL after ${grace} s more\n";
                kill "-INT", $pid;
            } elsif ($stopped && !$killed && $now >= $deadline) {
                $killed = 1;
                print STDERR "bounded_test: still running ${grace} s after SIGINT; SIGKILL to process group $pid\n";
                kill "-KILL", $pid;
            }
            select(undef, undef, undef, 0.5);
        }
    ' "$seconds" "$TEST_GRACE_SECONDS" "$@"
}

# Seconds left before the UI deadline (a large number when the start was not recorded).
remaining() {
    local t0 now
    t0="$(cat "$T0_FILE" 2>/dev/null || true)"
    now="$(date +%s)"
    case "$t0" in
        ''|*[!0-9]*) echo 100000 ;;
        *) echo $((t0 + UI_DEADLINE_SECONDS - now)) ;;
    esac
}

# budget <natural bound>: the smaller of the bound and the time left.
budget() {
    local left
    left="$(remaining)"
    if [ "$left" -lt "$1" ]; then echo "$left"; else echo "$1"; fi
}

# simctl finalises the movie on SIGINT (Xcode 12.3 notes). Bounded, so a stuck recorder cannot
# hang the build.
stop_recorder() {
    local waited=0
    if [ -n "$RECORDER_PID" ]; then
        kill -INT "$RECORDER_PID" 2>/dev/null || true
        while kill -0 "$RECORDER_PID" 2>/dev/null && [ "$waited" -lt 30 ]; do
            sleep 0.5
            waited=$((waited + 1))
        done
        if kill -0 "$RECORDER_PID" 2>/dev/null; then
            note "WARNING: the recorder ignored SIGINT for 15 s; terminating it (the movie may be incomplete)."
            kill -TERM "$RECORDER_PID" 2>/dev/null || true
        fi
        wait "$RECORDER_PID" 2>/dev/null || true
        RECORDER_PID=""
    fi
}

finish() {
    local status=$? udid
    stop_recorder
    if [ -n "$B_PID" ]; then
        kill -TERM "$B_PID" 2>/dev/null || true
        wait "$B_PID" 2>/dev/null || true
        B_PID=""
    fi
    if [ -n "$COMPACT_PID" ]; then
        kill -TERM "$COMPACT_PID" 2>/dev/null || true
        COMPACT_PID=""
    fi
    if [ -n "$ENCODER_PID" ]; then
        kill -TERM "$ENCODER_PID" 2>/dev/null || true
        ENCODER_PID=""
    fi
    for udid in $STATUS_BARS; do
        xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
    done
    for udid in $BOOTED_BY_US; do
        xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    done
    if [ -n "$DEVICE_B_CREATED" ]; then
        xcrun simctl shutdown "$DEVICE_B_CREATED" >/dev/null 2>&1 || true
        xcrun simctl delete "$DEVICE_B_CREATED" >/dev/null 2>&1 || true
    fi
    if [ "$status" -eq 0 ]; then
        summary_line "places-$STAGE" "PASS"
    else
        summary_line "places-$STAGE" "FAIL (exit $status), see $LOG"
        echo "places_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
    fi
    exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

load_simulator() {
    if [ ! -f "$SIM_ENV" ]; then
        note "ERROR: $SIM_ENV is missing; run 'bash scripts/codemagic_verify.sh select-simulator' first."
        return 1
    fi
    # shellcheck source=/dev/null
    . "$SIM_ENV"
    note "Simulator: $SIM_NAME, $SIM_RUNTIME_NAME ($SIM_RUNTIME_BUILD), UDID $SIM_UDID"
}

check_app() {
    if [ ! -x "$APP_PATH/Proximeet" ]; then
        note "ERROR: no built app at $APP_PATH; run 'bash scripts/codemagic_verify.sh build' first."
        return 1
    fi
}

require_checkpoint_match() {
    if ! grep -qx 'result=MATCH' "$CHECKPOINT_RESULT" 2>/dev/null; then
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/places_review.sh checkpoint' first. Nothing is tested for an unverified source."
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
# The run manifest
# ---------------------------------------------------------------------------------------

# The scope's runs on <device> (main, b or small), in manifest order.
manifest_runs() {
    awk -F '\t' -v scope="$SCOPE" -v device="$1" '!/^#/ && $1 == scope && $3 == device && !seen[$4]++ { print $4 }' \
        "$RUN_MANIFEST"
}

# manifest_field <run> <column>: the column (5 bundle, 6 seconds) of the run's first row.
manifest_field() {
    awk -F '\t' -v scope="$SCOPE" -v run="$1" -v col="$2" '!/^#/ && $1 == scope && $4 == run { print $col; exit }' \
        "$RUN_MANIFEST"
}

# The run's -only-testing arguments.
manifest_tests() {
    awk -F '\t' -v scope="$SCOPE" -v run="$1" \
        '!/^#/ && $1 == scope && $4 == run { printf "-only-testing:ProximeetUITests/%s ", $7 }' "$RUN_MANIFEST"
}

# The run's kinds, one word each ("required", "repeat").
manifest_kinds() {
    awk -F '\t' -v scope="$SCOPE" -v run="$1" '!/^#/ && $1 == scope && $4 == run && !seen[$8]++ { printf "%s ", $8 }' \
        "$RUN_MANIFEST"
}

# Whether the scope has rows for <device>.
scope_uses() {
    awk -F '\t' -v scope="$SCOPE" -v device="$1" '!/^#/ && $1 == scope && $3 == device { found = 1 } END { exit found ? 0 : 1 }' \
        "$RUN_MANIFEST"
}

# ---------------------------------------------------------------------------------------
# checkpoint
# ---------------------------------------------------------------------------------------

stage_checkpoint() {
    date +%s > "$T0_FILE"
    rm -f "$CHECKPOINT_RESULT"
    run python3 - "$FROZEN_MANIFEST" "$REVIEW_MANIFEST" "$DELETIONS" "$CHECKPOINT_RESULT" "$RUN_MANIFEST" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys

frozen_path, review_path, deletions, out_path, run_manifest = sys.argv[1:6]


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def sha256(path):
    with open(path, "rb") as data:
        return hashlib.sha256(data.read()).hexdigest()


def load(path):
    entries = {}
    with open(path) as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line and not line.startswith("#"):
                digest, name = line.split("  ", 1)
                entries[name] = digest
    return entries


problems = []
frozen, review = load(frozen_path), load(review_path)
for name in sorted(set(frozen) & set(review)):
    problems.append("listed twice   " + name)
expected = dict(review, **frozen)
for name, digest in sorted(expected.items()):
    if not os.path.isfile(name):
        problems.append("missing        " + name)
    elif sha256(name) != digest:
        problems.append(("changed (approved asset)  " if name in frozen else "differs        ") + name)

# Provenance: the approved assets must also equal the hashes recorded in the handoff records. The
# Places handoff's SHA256SUMS.txt covers the three venue scenes, the Manrope faces and the licence;
# the Signal handoff's the blank tag and the four band artworks (byte-identical to the Wristband's);
# the Guest List handoff's the card art; the Pass handoff's the pass artwork; the Birthday handoff's
# the housing; Welcome's FONT_SOURCE.json and every later record must agree on the faces.
assets = "Proximeet/Resources/Assets.xcassets/"
provenance, bundled = {}, ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")


def sums(path):
    return dict(reversed(line.strip().split("  ", 1)) for line in open(path) if line.strip())


try:
    places = sums("docs/design/places-approved/SHA256SUMS.txt")
    signal = sums("docs/design/signal-approved/SHA256SUMS.txt")
    wristband = sums("docs/design/wristband-approved/SHA256SUMS.txt")
    guest = sums("docs/design/guest-list-approved/SHA256SUMS.txt")
    pass_sums = sums("docs/design/pass-approved/SHA256SUMS.txt")
    birthday = sums("docs/design/birthday-approved/SHA256SUMS.txt")
    for folder, name in (("PlaceCommonGround", "common-ground.png"), ("PlaceAfterglow", "afterglow.png"),
                         ("PlaceFieldwork", "fieldwork.png")):
        provenance[assets + "%s.imageset/%s" % (folder, name)] = places["assets/" + name]
    provenance[assets + "SignalTag.imageset/signal-tag.png"] = signal["assets/signal-tag.png"]
    for intent in ("Social", "Dating", "Business", "Activity"):
        name = "wristband-%s.png" % intent.lower()
        provenance[assets + "Wristband%s.imageset/%s" % (intent, name)] = signal["assets/" + name]
        if wristband.get("assets/" + name) != signal["assets/" + name]:
            problems.append("Signal and Wristband band records disagree  " + name)
    provenance[assets + "GuestListCard.imageset/guest-list-card.png"] = guest["assets/guest-list-card.png"]
    provenance[assets + "PassArtwork.imageset/pass-artwork.png"] = pass_sums["assets/pass-artwork.png"]
    provenance[assets + "BirthdayHousing.imageset/birthday-housing.png"] = birthday["assets/birthday-housing.png"]
    provenance[assets + "Manrope-OFL.dataset/OFL.txt"] = places["fonts/OFL.txt"]
    fonts = {f["file"]: f["sha256"] for f in json.load(open("docs/design/welcome-approved/FONT_SOURCE.json"))["fonts"]}
    for face in bundled:
        name = "Manrope-%s.ttf" % face
        provenance[assets + "Manrope-%s.dataset/%s" % (face, name)] = places["fonts/" + name]
        if any(record.get(key) != places["fonts/" + name] for record, key in
               ((fonts, name), (birthday, "fonts/" + name), (pass_sums, "fonts/" + name), (guest, "fonts/" + name),
                (wristband, "fonts/" + name), (signal, "fonts/" + name))):
            problems.append("Welcome, Birthday, Pass, Guest List, Wristband, Signal and Places font records disagree  " + name)
    for record, label in ((pass_sums, "Pass"), (guest, "Guest List"), (wristband, "Wristband"), (signal, "Signal")):
        if record.get("fonts/OFL.txt") != places["fonts/OFL.txt"]:
            problems.append("%s and Places licence records disagree  fonts/OFL.txt" % label)
    # The approved Places copy itself: every handoff file copied into the repository matches its record.
    for key, digest in sorted(places.items()):
        if key.startswith(("assets/", "fonts/")):
            continue
        path = "docs/design/places-approved/" + key
        if not os.path.isfile(path):
            problems.append("approved Places handoff file missing  " + path)
        elif sha256(path) != digest:
            problems.append("differs from the Places handoff record  " + path)
except (OSError, ValueError, KeyError) as error:
    problems.append("provenance records unreadable: %r" % (error,))
for name, digest in sorted(provenance.items()):
    if name not in frozen:
        problems.append("approved asset not in the frozen manifest  " + name)
    elif os.path.isfile(name) and sha256(name) != digest:
        problems.append("differs from the approved handoff  " + name)

# The approved route (Signal, Wristband, Guest List, Pass): the Signal guard, unchanged. No
# verification, visibility, membership, entitlement, presence, capture, network, persistence,
# logging or timer API in their sources.
guarded_sources = ["Proximeet/Scenes/SignalView.swift", "Proximeet/Scenes/WristbandView.swift",
                   "Proximeet/Scenes/GuestListView.swift", "Proximeet/Scenes/PassView.swift",
                   "Proximeet/Components/RepeatTapGuard.swift", "Proximeet/App/DemoSession.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/ApproachSignal.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/WristbandChoice.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/GuestIntroduction.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/GuestListDemo.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/PassDemo.swift"]
guard_forbidden = ["isVerified", "verified", "Verified", "isVisible", "Discoverable", "discoverable",
                   "membership", "Membership", "isMember", "entitlement", "Entitlement", "presence", "Presence",
                   "checkIn", "checkedIn", "access granted", "AVCapture", "LAContext", "LocalAuthentication",
                   "PhotosPicker", "UIImagePickerController", "VNDocumentCamera", "CLLocation", "CoreLocation",
                   "CoreBluetooth", "CBCentralManager", "CoreNFC", "NFCNDEF", "WatchConnectivity", "WCSession",
                   "UNUserNotificationCenter", "URLSession", "URLRequest", "UserDefaults", "@AppStorage",
                   "@SceneStorage", "FileManager", "Keychain", "SecItem", "print(", "NSLog", "os_log", "Logger(",
                   "Timer", "asyncAfter", "Task.sleep", "CADisplayLink", "TimelineView", "repeatForever"]
for path in guarded_sources:
    if not os.path.isfile(path):
        problems.append("guarded source missing  " + path)
        continue
    text = open(path, encoding="utf-8").read()
    for token in guard_forbidden:
        if token in text:
            problems.append("Signal guard: %s contains %r" % (path, token))

# Places' own sources: explanation only. The visible sentences say what a later, real check-in
# would ask and what is not done here ("Demo · no location or camera used."); no source may read a
# clock, a calendar or a locale's time, ask for location, the camera or a scanner, reach the
# network, persist, log, schedule, or mark anyone checked in, present, visible or verified.
places_sources = ["Proximeet/Scenes/PlacesView.swift", "ProximeetDomain/Sources/ProximeetDomain/Places.swift",
                  "Proximeet/Components/PlacesEdgeBack.swift"]
places_forbidden = ["Date(", "Date.now", "Calendar", "TimeZone", "Locale", "DateFormatter", "Clock", "Timer",
                    "asyncAfter", "Task.sleep", "CADisplayLink", "TimelineView", "repeatForever",
                    "CLLocation", "CoreLocation", "CLMonitor", "MapKit", "AVCapture", "AVFoundation", "VisionKit",
                    "DataScanner", "VNDetect", "CoreImage", "CIDetector", "CoreBluetooth", "CoreNFC", "LAContext",
                    "requestWhenInUseAuthorization", "requestAlwaysAuthorization", "requestAccess",
                    "UNUserNotificationCenter", "URLSession", "URLRequest", "UserDefaults", "@AppStorage",
                    "@SceneStorage", "FileManager", "Keychain", "SecItem", "print(", "NSLog", "os_log", "Logger(",
                    "isVerified", "isVisible", "isPresent", "isCheckedIn", "checkedIn", "Discoverable",
                    "discoverable", "isMember", "membership", "entitlement", "reservationID", "bookingID"]
for path in places_sources:
    if not os.path.isfile(path):
        problems.append("guarded Places source missing  " + path)
        continue
    text = open(path, encoding="utf-8").read()
    for token in places_forbidden:
        if token in text:
            problems.append("Places guard: %s contains %r" % (path, token))

# One intent mapping: the approved screens use the canonical Wristband colours and art, never the
# legacy tint (whose Social is cyan) that only the legacy, DEBUG-only later scenes still use.
for path in ("Proximeet/Scenes/SignalView.swift", "Proximeet/Scenes/WristbandView.swift",
             "Proximeet/Scenes/PlacesView.swift"):
    text = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
    for token in (".tint", "Palette.social", "Palette.dating", "Palette.business", "Palette.activity"):
        if token in text:
            problems.append("intent colour guard: %s uses the legacy %r" % (path, token))

listed = git("ls-files", "--cached", "--others", "--exclude-standard")
if listed is None:
    problems.append("git unavailable: the checkout cannot be listed, so extra files cannot be ruled out")
    present = []
else:
    present = [p for p in listed.splitlines() if p and os.path.lexists(p)]
for name in sorted(present):
    if name != review_path and name not in expected:
        problems.append("unexpected     " + name)

absent = 0
with open(deletions) as handle:
    for name in (line.strip() for line in handle):
        if name and not name.startswith("#"):
            if os.path.lexists(name):
                problems.append("present        " + name + " (an approved chapter deleted it)")
            else:
                absent += 1

scopes = {line.split("\t")[0] for line in open(run_manifest, encoding="utf-8") if line.strip() and not line.startswith("#")}
scope = os.environ.get("PLACES_REVIEW_SCOPE", "").strip()
if scope not in scopes:
    if os.environ.get("CM_BUILD_ID") or scope:
        problems.append("PLACES_REVIEW_SCOPE must be one of %s (got %r)" % (", ".join(sorted(scopes)), scope))
    scope = scope or "places"

deadline = os.environ.get("PLACES_UI_DEADLINE_SECONDS", "")
if deadline and not (re.fullmatch(r"[1-9][0-9]{2,3}", deadline) and 600 <= int(deadline) <= 1380):
    problems.append("PLACES_UI_DEADLINE_SECONDS must be 600 to 1380 seconds (got %r)" % deadline)

head = git("rev-parse", "HEAD") or "unavailable"
pin = os.environ.get("PLACES_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("PLACES_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but PLACES_EXPECTED_COMMIT is %s" % (head, pin))
elif os.environ.get("CM_BUILD_ID"):
    problems.append("PLACES_EXPECTED_COMMIT is unset on Codemagic: the reviewed commit is not pinned")

lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("PLACES_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
    "scope=" + scope,
    "ui_deadline_seconds=" + (deadline or "1380 (default)"),
    "frozen_manifest_sha256=" + sha256(frozen_path),
    "review_manifest_sha256=" + sha256(review_path),
    "run_manifest_sha256=" + sha256(run_manifest),
    "approved_assets_checked=%d" % len(frozen),
    "provenance_checked=%d" % len(provenance),
    "other_files_checked=%d" % len(review),
    "files_present=%d" % len(present),
    "deletions_confirmed=%d" % absent,
    "result=" + ("MATCH" if not problems else "MISMATCH"),
]
lines += ["problem=" + p for p in problems]
with open(out_path, "w") as out:
    out.write("\n".join(lines) + "\n")
print("\n".join(lines))
if problems:
    print("This checkout is not the reviewed Places revision. Do not review it as such.")
    sys.exit(1)
PY
    sed -n 's/^scope=//p' "$CHECKPOINT_RESULT" > "$SCOPE_FILE"
    summary_line "places-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^scope=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations and ui-review
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/places-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/places-runtimes-available.json"
    local status=0 smaller b_udid
    run python3 - "$META/places-devices-available.json" "$META/places-runtimes-available.json" \
        "$SIM_UDID" "$PRIMARY_TARGET" "$OUT/destination.txt" <<'PY' || status=$?
import json
import sys

devices_path, runtimes_path, selected_udid, primary, out_path = sys.argv[1:6]
devices = json.load(open(devices_path)).get("devices", {})
runtimes = {r.get("identifier"): r for r in json.load(open(runtimes_path)).get("runtimes", [])}
iphones, selected, primary_available = [], None, []
for runtime_id, entries in sorted(devices.items()):
    runtime = runtimes.get(runtime_id, {})
    label = "%s (%s)" % (runtime.get("name", runtime_id), runtime.get("buildversion", "?"))
    for device in entries:
        if device.get("isAvailable") is not True or not device.get("name", "").startswith("iPhone"):
            continue
        iphones.append("%s | %s | %s" % (device["name"], label, device["udid"]))
        if device["udid"] == selected_udid:
            selected = (device["name"], label)
        if device["name"] == primary:
            primary_available.append(label)
lines = ["primary_target=" + primary,
         "primary_target_installed=" + ("yes on " + ", ".join(primary_available) if primary_available else "NO"),
         "selected=" + ("%s on %s" % selected if selected else "unknown UDID " + selected_udid),
         "primary_target_selected=" + ("yes" if selected and selected[0] == primary else "NO"),
         "installed_iphones=%d" % len(iphones)]
lines += ["iphone=" + entry for entry in iphones]
open(out_path, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if selected and selected[0] == primary else 1)
PY

    # Devices. Build 6ab84ede showed that a simulator restarted after its first boot is not ready for
    # 3.5 to 5.7 minutes; build 6ab85be6 that a device first booted while the other runs tests needs
    # about 15 minutes to reach its first test (and slows the other). A second first boot during the
    # compilation costs it about two minutes instead. So both devices boot now, behind the
    # compilation and the domain tests, and neither is ever restarted: the selected simulator and the
    # scope's other device (device B, cloned from it now before either boots, or the smaller
    # iPhone). Nothing is deleted here; ui-review deletes device B when it ends.
    printf 'memory_bytes=%s\ncpus=%s\n' "$(sysctl -n hw.memsize 2>/dev/null || echo unknown)" \
        "$(sysctl -n hw.ncpu 2>/dev/null || echo unknown)" > "$META/places-host.txt"
    run cat "$META/places-host.txt" || true
    rm -f "$SMALL_ENV" "$DEVICE_B_ENV"
    if scope_uses b; then
        run xcrun simctl shutdown "$SIM_UDID" || true
        if b_udid="$(xcrun simctl clone "$SIM_UDID" "$DEVICE_B_NAME" 2>>"$LOG")" && [ -n "$b_udid" ]; then
            printf 'DEVICE_B_UDID=%s\n' "$b_udid" > "$DEVICE_B_ENV"
            note "Device B: $DEVICE_B_NAME, cloned from $SIM_UDID before either boots: $b_udid."
            summary_line "places-device-b" "cloned $b_udid from $SIM_UDID ($SIM_NAME, $SIM_RUNTIME_NAME) before either boots"
        else
            note "WARNING: device B could not be cloned; its runs will follow the selected simulator's."
            summary_line "places-device-b" "NOT CLONED; its runs follow the selected simulator's"
        fi
    fi
    if scope_uses small; then
        smaller="$(smaller_iphone)" || smaller=""
        if [ -n "$smaller" ]; then
            printf 'SMALL_UDID=%s\nSMALL_NAME=%q\n' "$(printf '%s' "$smaller" | cut -f1)" "$(printf '%s' "$smaller" | cut -f2)" > "$SMALL_ENV"
            note "Smaller iPhone: $(printf '%s' "$smaller" | cut -f2) ($(printf '%s' "$smaller" | cut -f1))."
        else
            note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        fi
    fi
    run xcrun simctl boot "$SIM_UDID" || true
    if [ -f "$DEVICE_B_ENV" ]; then
        run xcrun simctl boot "$b_udid" || true
    elif [ -f "$SMALL_ENV" ]; then
        run xcrun simctl boot "$(printf '%s' "$smaller" | cut -f1)" || true
    fi
    return "$status"
}

status_bar() {
    if run xcrun simctl status_bar "$1" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4; then
        STATUS_BARS="$STATUS_BARS $1"
    else
        note "NOTE: status bar override unavailable on $1; captures show the live status bar."
    fi
}

smaller_iphone() {
    xcrun simctl list -j devices available > "$META/places-simctl-devices.json"
    python3 - "$META/places-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
import json
import sys

devices_path, runtime, main_udid, preferences = sys.argv[1:5]
devices = json.load(open(devices_path)).get("devices", {}).get(runtime, [])
available = {d["name"]: d["udid"] for d in devices
             if d.get("isAvailable") is True and d["udid"] != main_udid}
for name in preferences.split("|"):
    if name in available:
        print("%s\t%s" % (available[name], name))
        break
PY
}

# export_results <xcresult> <attachments dir>
export_results() {
    local result="$1" dir="$2"
    [ -d "$result" ] || return 0
    bounded "$RESULTS_SECONDS" xcrun xcresulttool get test-results summary --path "$result" > "${result%.xcresult}-summary.json" 2>>"$LOG" || true
    bounded "$RESULTS_SECONDS" xcrun xcresulttool get test-results tests --path "$result" > "${result%.xcresult}-tests.json" 2>>"$LOG" || true
    if bounded "$EXPORT_SECONDS" xcrun xcresulttool export attachments --path "$result" --output-path "$dir" >> "$LOG" 2>&1; then
        note "Exported XCTest attachments to $dir."
    else
        note "NOTE: attachment export unavailable for $result; the per-test results are in the log and summary."
    fi
}

# xctest <udid> <derived data> <result bundle> <seconds> <-only-testing arguments...>: one bounded
# test-without-building run with every review flag set for the test runner and short holds.
xctest() {
    local udid="$1" derived="$2" result="$3" seconds="$4"
    shift 4
    if [ "$seconds" -lt 30 ]; then
        note "SKIPPED (time budget): too little time left for $*."
        return 124
    fi
    # shellcheck disable=SC2086
    run "$TEST_BOUND" "$seconds" env TEST_RUNNER_PROXIMEET_PLACES_REVIEW=1 TEST_RUNNER_PROXIMEET_SIGNAL_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_WRISTBAND_REVIEW=1 TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_PASS_REVIEW=1 TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 TEST_RUNNER_PROXIMEET_SHORT_HOLDS=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$derived" \
        "$@" -parallel-testing-enabled NO $TEST_TIMEOUTS -resultBundlePath "$result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building
}

# destination_lost <log line mark>: xcodebuild could not find the simulator at all (build 6ab7dbf0:
# exit 70 straight after a run; no test ran). That is neither a test failure nor a retry: the
# simulator is booted again and the same tests run once more. Both runs are listed, the first as
# "infra"; a second exit 70 fails the verdict like any other run.
destination_lost() {
    tail -n +"$(($1 + 1))" "$LOG" | grep -q "Unable to find a device matching the provided destination specifier"
}

reboot_destination() {
    note "xcodebuild could not find $1 (exit 70; no test ran). Booting it again and running the same tests once."
    note "simctl: $(xcrun simctl list devices 2>&1 | grep "$1" || echo "$1 not listed")"
    run xcrun simctl boot "$1" || true
    run bounded "$(budget 180)" xcrun simctl bootstatus "$1" -b || true
}

# lane_run <name> <udid> <derived data> <bundle> <natural seconds> <-only-testing...>: one bounded run,
# its exit recorded in $OUT/runs.txt as "<name> <bundle> <exit> no" (no retry), its attachments
# exported.
lane_run() {
    local name="$1" udid="$2" derived="$3" bundle="$4" seconds="$5" status=0 mark
    shift 5
    rm -rf "${OUT:?}/${bundle:?}.xcresult"
    mark="$(wc -l < "$LOG" | tr -d ' ')"
    xctest "$udid" "$derived" "$OUT/$bundle.xcresult" "$(budget "$seconds")" "$@" || status=$?
    if [ "$status" -eq 70 ] && destination_lost "$mark"; then
        printf '%s %s %s %s\n' "${name}_destination_unavailable" "$bundle" "$status" "infra" >> "$OUT/runs.txt"
        reboot_destination "$udid"
        rm -rf "${OUT:?}/${bundle:?}.xcresult"
        status=0
        xctest "$udid" "$derived" "$OUT/$bundle.xcresult" "$(budget "$seconds")" "$@" || status=$?
    fi
    printf '%s %s %s %s\n' "$name" "$bundle" "$status" "no" >> "$OUT/runs.txt"
    LAST_RUN_STATUS="$status"
    export_results "$OUT/$bundle.xcresult" "$OUT/attachments-$bundle"
    return 0
}

# journey_run <udid> <derived data> <bundle> <natural seconds>: the places scope's recorded full
# journey. The recorder is confirmed active before the test starts, and the app is closed first. It
# keeps its full holds and is never retried (a retry would not be the recorded run). The compact
# video is made in the background from the journey's own start marker.
journey_run() {
    local udid="$1" derived="$2" bundle="$3" seconds="$4" movie="$OUT/places-walkthrough-original.mp4"
    local waited=0 status=0 recording_started mark attempt=1
    while :; do
        run xcrun simctl terminate "$udid" "$BUNDLE_ID" || true
        rm -f "$movie" "$movie.log"
        xcrun simctl io "$udid" recordVideo --codec=h264 --force "$movie" > "$movie.log" 2>&1 &
        RECORDER_PID=$!
        waited=0
        while ! grep -q "Recording started" "$movie.log" 2>/dev/null && [ "$waited" -lt 40 ]; do
            kill -0 "$RECORDER_PID" 2>/dev/null || break
            sleep 0.25
            waited=$((waited + 1))
        done
        recording_started="$(python3 -c 'import time; print("%.3f" % time.time())')"
        if grep -q "Recording started" "$movie.log" 2>/dev/null; then
            printf '%s\n' "$recording_started" > "$OUT/recording-started.txt"
            summary_line "places-recording" "confirmed active before the journey"
        else
            note "WARNING: simctl did not confirm 'Recording started'; the journey still runs, unrecorded."
            summary_line "places-recording" "NOT CONFIRMED"
            stop_recorder
            rm -f "$movie"
        fi
        rm -rf "${OUT:?}/${bundle:?}.xcresult"
        mark="$(wc -l < "$LOG" | tr -d ' ')"
        status=0
        # shellcheck disable=SC2046
        run "$TEST_BOUND" "$(budget "$seconds")" env TEST_RUNNER_PROXIMEET_PLACES_REVIEW=1 xcodebuild \
            -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
            -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$derived" \
            $(manifest_tests journey) -parallel-testing-enabled NO \
            $TEST_TIMEOUTS -resultBundlePath "$OUT/$bundle.xcresult" \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building || status=$?
        stop_recorder
        if [ "$status" -eq 70 ] && [ "$attempt" -eq 1 ] && destination_lost "$mark"; then
            printf 'journey_destination_unavailable %s %s infra\n' "$bundle" "$status" >> "$OUT/runs.txt"
            reboot_destination "$udid"
            attempt=2
            continue
        fi
        break
    done
    printf 'journey %s %s no\n' "$bundle" "$status" >> "$OUT/runs.txt"
    if [ -s "$movie" ]; then
        shasum -a 256 "$movie" > "$movie.sha256"
    fi
    export_results "$OUT/$bundle.xcresult" "$OUT/attachments-$bundle"
    local method
    method="$(manifest_field journey 7)"
    method="${method##*/}"
    sed -n 's/.*PLACES_WALKTHROUGH_START \([0-9][0-9.]*\).*/\1/p' "$LOG" | tail -n 1 > "$OUT/walkthrough-started.txt"
    sed -n 's/.*PLACES_WALKTHROUGH_APP_READY \([0-9][0-9.]*\).*/\1/p' "$LOG" | tail -n 1 > "$OUT/walkthrough-app-ready.txt"
    sed -n "s/.*${method}]' [a-z]* (\([0-9][0-9.]*\) seconds).*/\1/p" "$LOG" | tail -n 1 \
        > "$OUT/walkthrough-duration.txt"
    if [ -s "$movie" ] && [ "$SCOPE" = "places" ]; then
        PLACES_LOG_SUFFIX=-during-ui-review PLACES_REVIEW_SCOPE="$SCOPE" bash scripts/places_review.sh compact-video > /dev/null 2>&1 &
        COMPACT_PID=$!
    fi
}

# run_lane <device> <udid> <derived data>: the scope's runs for that device, in manifest order. A
# run made only of planned repeats starts only while REPEAT_GATE_SECONDS are left.
run_lane() {
    local device="$1" udid="$2" derived="$3" name bundle seconds left gate
    for name in $(manifest_runs "$device"); do
        bundle="$(manifest_field "$name" 5)"
        seconds="$(manifest_field "$name" 6)"
        if [ "$name" = "journey" ]; then
            journey_run "$udid" "$derived" "$bundle" "$seconds"
            continue
        fi
        gate=0
        case "$(manifest_kinds "$name")" in
            "repeat ") gate="$REPEAT_GATE_SECONDS" ;;
            "extra ") gate=$((seconds + 60)) ;;
        esac
        if [ "$gate" -gt 0 ]; then
            left="$(remaining)"
            if [ "$left" -lt "$gate" ]; then
                note "The optional run $name is left unrun: ${left}s left, under ${gate}s."
                printf '%s %s %s %s\n' "$name" "$bundle" none time >> "$OUT/runs.txt"
                continue
            fi
        fi
        # shellcheck disable=SC2046
        lane_run "$name" "$udid" "$derived" "$bundle" "$seconds" $(manifest_tests "$name")
    done
}

# The smaller iPhone's runs (after the selected simulator's lane). smaller.txt records the device.
smaller_segment() {
    local udid name left run_name
    if [ ! -f "$SMALL_ENV" ]; then
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        printf 'device=none installed\n' > "$OUT/smaller.txt"
        for run_name in $(manifest_runs small); do
            printf '%s %s none device\n' "$run_name" "$(manifest_field "$run_name" 5)" >> "$OUT/runs.txt"
        done
        return 2
    fi
    # shellcheck source=/dev/null
    . "$SMALL_ENV"
    udid="$SMALL_UDID"
    name="$SMALL_NAME"
    left="$(remaining)"
    if [ "$left" -lt 180 ]; then
        note "SKIPPED (time budget): ${left}s left, too little to boot $name."
        printf 'device=%s (%s)\ntests=not run (time budget)\n' "$name" "$udid" > "$OUT/smaller.txt"
        for run_name in $(manifest_runs small); do
            printf '%s %s none time\n' "$run_name" "$(manifest_field "$run_name" 5)" >> "$OUT/runs.txt"
        done
        return 1
    fi
    note "Smaller iPhone: $name ($udid)."
    printf 'device=%s (%s)\n' "$name" "$udid" > "$OUT/smaller.txt"
    run xcrun simctl boot "$udid" || true
    BOOTED_BY_US="$BOOTED_BY_US $udid"
    run bounded "$(budget 240)" xcrun simctl bootstatus "$udid" -b || return 1
    status_bar "$udid"
    run_lane small "$udid" "$DERIVED_DATA"
    printf 'tests_xcodebuild_exit=%s (see the per-test results)\n' "$LAST_RUN_STATUS" >> "$OUT/smaller.txt"
    run xcrun simctl shutdown "$udid" || true
    return 0
}

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    check_app
    local build_status b_udid="" b_log="$LOGS/places-ui-review-device-b.log" waited=0 small_udid=""
    local second="" second_udid="" second_derived="$DERIVED_DATA"
    rm -rf "${OUT:?}"/*.xcresult "${OUT:?}"/attachments-* "${OUT:?}"/places-walkthrough-* \
        "${OUT:?}"/*-summary.json "${OUT:?}"/*-tests.json
    rm -f "$OUT/recording-started.txt" "$OUT/runs.txt" "$OUT/smaller.txt" "$b_log" "$OUT/walkthrough-started.txt" \
        "$OUT/walkthrough-duration.txt" "$OUT/compact-video.txt"
    : > "$OUT/runs.txt"
    export NSUnbufferedIO=YES
    note "Scope: $SCOPE. UI deadline: $(remaining)s left of the ${UI_DEADLINE_SECONDS}s budget."
    awk -F '\t' -v scope="$SCOPE" '!/^#/ && $1 == scope' "$RUN_MANIFEST" > "$OUT/manifest-rows.tsv"

    # 1. The second device (device B, cloned in destinations, or the smaller iPhone) has been booting
    #    since destinations, like the selected simulator.
    if [ -f "$DEVICE_B_ENV" ]; then
        # shellcheck source=/dev/null
        . "$DEVICE_B_ENV"
        b_udid="$DEVICE_B_UDID"
        DEVICE_B_CREATED="$b_udid"
        second="b"
        second_udid="$b_udid"
    fi
    if [ -f "$SMALL_ENV" ]; then
        # shellcheck source=/dev/null
        . "$SMALL_ENV"
        small_udid="$SMALL_UDID"
        if [ -z "$second" ]; then
            second="small"
            second_udid="$small_udid"
            printf 'device=%s (%s)\n' "$SMALL_NAME" "$small_udid" > "$OUT/smaller.txt"
        fi
    fi
    if [ -n "$second_udid" ]; then
        BOOTED_BY_US="$BOOTED_BY_US $second_udid"
    fi

    # 2. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run bounded "$(budget 600)" xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "places-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "places-ui-build" "PASS (UI test harness compiled)"

    # 3. The other device runs from its own copy of the build products (a clone on APFS), so the two
    #    xcodebuild processes never share a DerivedData folder.
    if [ -n "$second" ]; then
        rm -rf "${DERIVED_DATA_B:?}"
        if run cp -Rc "$DERIVED_DATA" "$DERIVED_DATA_B" || run ditto "$DERIVED_DATA" "$DERIVED_DATA_B"; then
            second_derived="$DERIVED_DATA_B"
        else
            note "WARNING: the build products could not be copied for the other device; its runs follow the selected simulator's."
            second=""
        fi
    fi
    run bounded "$(budget 420)" xcrun simctl bootstatus "$SIM_UDID" -b || true
    status_bar "$SIM_UDID"
    if [ -n "$second" ]; then
        (
            trap - EXIT INT TERM
            LOG="$b_log"
            : > "$LOG"
            note "Second device ($second, $second_udid), scope $SCOPE."
            run bounded "$(budget 420)" xcrun simctl bootstatus "$second_udid" -b || true
            status_bar "$second_udid"
            run_lane "$second" "$second_udid" "$second_derived"
        ) &
        B_PID=$!
        summary_line "places-parallel" "$second $second_udid runs its $SCOPE runs beside the selected simulator's"
    fi

    # 4. The selected simulator's runs (the places scope's recorded journey first).
    run_lane main "$SIM_UDID" "$DERIVED_DATA"

    # 5. Without its device, device B's runs happen here, after the selected simulator's; the smaller
    #    iPhone's runs follow the selected simulator's when device B took the parallel lane (no scope
    #    uses both today), or are recorded as having no device.
    if scope_uses b && [ "$second" != "b" ]; then
        run_lane b "$SIM_UDID" "$DERIVED_DATA"
    fi
    if scope_uses small && [ "$second" != "small" ]; then
        run xcrun simctl shutdown "$SIM_UDID" || true
        if smaller_segment; then
            summary_line "places-smaller" "ran: $(tr '\n' ' ' < "$OUT/smaller.txt")"
        else
            summary_line "places-smaller" "segment exit $?: $(tr '\n' ' ' < "$OUT/smaller.txt" 2>/dev/null)"
        fi
    fi

    # 6. The second device's results, and the compact video.
    if [ -n "$B_PID" ]; then
        note "Waiting for the second device ($(remaining)s left)."
        wait "$B_PID" || true
        B_PID=""
        if [ "$second" = "small" ]; then
            summary_line "places-smaller" "ran beside the selected simulator: $(tr '\n' ' ' < "$OUT/smaller.txt")"
        fi
    fi
    if [ -n "$COMPACT_PID" ]; then
        waited=0
        while kill -0 "$COMPACT_PID" 2>/dev/null && [ "$(remaining)" -gt -30 ]; do
            sleep 0.5
            waited=$((waited + 1))
        done
        if kill -0 "$COMPACT_PID" 2>/dev/null; then
            note "WARNING: the compact video is still being made at the deadline; the workflow's own step retries it."
            kill -TERM "$COMPACT_PID" 2>/dev/null || true
        fi
        wait "$COMPACT_PID" 2>/dev/null || true
        COMPACT_PID=""
    fi
    run cat "$OUT/runs.txt"

    # 7. What actually ran, judged against the manifest, execution by execution.
    python3 scripts/places_review_results.py "$RUN_MANIFEST" "$SCOPE" "$OUT/runs.txt" "$OUT/ui-review-tests.txt" \
        "$OUT/executions.tsv" "$SIM_UDID" "$b_udid" "$small_udid" "$LOG" ${second:+"$b_log"} \
        > "$OUT/ui-review-counts.txt" 2>>"$LOG" || note "ERROR: scripts/places_review_results.py failed; the results are incomplete."
    # The second device's log joins this one only now, after the parse, so no result is read twice.
    if [ -n "$second" ]; then
        cat "$b_log" >> "$LOG" 2>/dev/null || true
    fi
    run cat "$OUT/ui-review-tests.txt"
    summary_line "places-ui-run" "$(cat "$OUT/ui-review-counts.txt")"
    grep -qx 'result=PASS' "$OUT/ui-review-tests.txt"
}

# ---------------------------------------------------------------------------------------
# compact-video
# ---------------------------------------------------------------------------------------

stage_compact_video() {
    local movie="$OUT/places-walkthrough-original.mp4" compact="$OUT/places-walkthrough-compact.mp4"
    local start=0 end="" took marker ready started pid waited=0 status=1 cap
    if [ "$SCOPE" = "correction" ]; then
        note "Scope correction: its short recording is delivered unedited; no re-encode is made on the Mac."
        printf 'result=NOT APPLICABLE (the correction delivers its short recording unedited)\n' > "$OUT/compact-video.txt"
        return 0
    fi
    if [ "$SCOPE" != "places" ]; then
        note "Scope $SCOPE records nothing; there is no walkthrough to compact."
        printf 'result=NOT APPLICABLE (scope %s records nothing)\n' "$SCOPE" > "$OUT/compact-video.txt"
        return 0
    fi
    if grep -q '^result=' "$OUT/compact-video.txt" 2>/dev/null && [ -s "$compact" ] && [ -s "$compact.sha256" ]; then
        note "Already made during ui-review:"
        run cat "$OUT/compact-video.txt" "$compact.sha256"
        return 0
    fi
    rm -f "$compact" "$OUT/compact-video.txt"
    if [ ! -s "$movie" ]; then
        note "No recording to compact."
        printf 'result=NOT PRODUCED (no recording)\n' > "$OUT/compact-video.txt"
        return 2
    fi
    # The trim starts at the app's first screen when the test marked it; it ends at the test's own
    # start plus its duration.
    ready="$(cat "$OUT/walkthrough-app-ready.txt" 2>/dev/null || true)"
    marker="$(cat "$OUT/walkthrough-started.txt" 2>/dev/null || true)"
    if [ -z "$marker" ]; then
        marker="$(sed -n 's/^walkthrough_started_epoch=//p' "$OUT/ui-review-tests.txt" 2>/dev/null || true)"
    fi
    started="$(cat "$OUT/recording-started.txt" 2>/dev/null || true)"
    took="$(cat "$OUT/walkthrough-duration.txt" 2>/dev/null || true)"
    case "$marker" in
        ''|unknown|*[!0-9.]*) marker="" ;;
    esac
    if [ -n "$marker" ] && [ -n "$started" ]; then
        # The test's own start marker is printed before it launches the app; the trim starts 0.5 s
        # before it and ends 1.5 s after the test's recorded duration: the app from launch to the
        # journey's last hold, without the simulator's home screen before or after.
        case "$ready" in
            ''|*[!0-9.]*) ready="$marker" ;;
        esac
        start="$(python3 -c "import sys; print('%.2f' % max(0.0, float(sys.argv[1]) - float(sys.argv[2]) - 0.5))" "$ready" "$started")"
        if [ -n "$took" ]; then
            end="$(python3 -c "import sys; print('%.2f' % (float(sys.argv[1]) - float(sys.argv[2]) + float(sys.argv[3]) + 1.5))" "$marker" "$started" "$took")"
        fi
    fi
    # Bounded by the UI deadline (30 s past it at most), so the verdict, the packages and
    # publishing still fit in the workflow's 28 minutes.
    cap=$(( $(remaining) + 30 ))
    note "Trim: ${start}s to ${end:-the last app frame}s (walkthrough start ${marker:-unknown}, duration ${took:-unknown}, recording start ${started:-unknown}); up to ${cap}s to encode."
    if [ "$cap" -lt 45 ]; then
        note "WARNING: no time left to re-encode."
    else
        # shellcheck disable=SC2086
        xcrun swift scripts/compact_video.swift "$movie" "$compact" "$start" $end > "$OUT/compact-video.out" 2>> "$LOG" &
        pid=$!
        ENCODER_PID=$pid
        while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt $((cap * 2)) ]; do
            sleep 0.5
            waited=$((waited + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            note "WARNING: the re-encode did not finish within ${cap} s; stopping it."
            kill -TERM "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        elif wait "$pid"; then
            status=0
        fi
    fi
    ENCODER_PID=""
    cat "$OUT/compact-video.out" >> "$LOG" 2>/dev/null || true
    if [ "$status" -eq 0 ] && [ -s "$compact" ]; then
        printf 'result=RE-ENCODED\nmethod=AVFoundation export: %s\ntrim=%ss to %s (from the recording start; the app only)\n' \
            "$(tail -n 1 "$OUT/compact-video.out")" "$start" "${end:-the end}" > "$OUT/compact-video.txt"
    else
        cp "$movie" "$compact"
        printf 'result=FALLBACK COPY (not re-encoded, not trimmed)\n' > "$OUT/compact-video.txt"
        note "WARNING: the re-encode failed; the compact file is a copy of the original, labelled as such."
    fi
    shasum -a 256 "$compact" > "$compact.sha256"
    run cat "$OUT/compact-video.txt" "$compact.sha256"
}

# ---------------------------------------------------------------------------------------
# verdict
# ---------------------------------------------------------------------------------------

stage_verdict() {
    run python3 - "$SUMMARY" "$META" "$OUT" "$SCOPE" <<'PY'
import json
import os
import re
import sys

summary_path, meta, out, scope = sys.argv[1:5]
last = {}
if os.path.isfile(summary_path):
    for line in open(summary_path, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split(None, 2)
        if len(parts) >= 2:
            last[parts[1]] = parts[2] if len(parts) > 2 else ""


def status(label):
    return last.get(label, "NOT RUN")


def passed(label):
    return last.get(label, "").startswith("PASS")


def kv(path):
    values = {}
    if os.path.isfile(path):
        for line in open(path):
            key, sep, value = line.rstrip("\n").partition("=")
            if sep:
                values.setdefault(key, value)
    return values


tools, source = kv(os.path.join(meta, "tools.txt")), kv(os.path.join(out, "source-checkpoint.txt"))
destination, tests = kv(os.path.join(out, "destination.txt")), kv(os.path.join(out, "ui-review-tests.txt"))
compact, smaller = kv(os.path.join(out, "compact-video.txt")), kv(os.path.join(out, "smaller.txt"))
simulator = json.load(open(os.path.join(meta, "simulator.json"))) if os.path.isfile(os.path.join(meta, "simulator.json")) else {}
movie = os.path.join(out, "places-walkthrough-original.mp4")
covered = {
    "places": "the 13 Places executions of docs/verification/places-review-manifest.tsv: the recorded journey, the "
              "seven screens on two widths, all twelve intent-venue combinations, Back routes with the retained "
              "category and draft, the band change, missing choices and the guarded explanation, the Birthday gate "
              "on the way back, relaunch, rapid taps and interruptions, the Reduce Motion preview flag, the largest "
              "text on two widths",
    "signal": "the 16 Signal executions of docs/verification/places-review-manifest.tsv (build 6ab7e942's, with "
              "Continue preview now opening Places)",
    "regressions": "the 27 required executions of docs/verification/places-review-manifest.tsv (build 6ab81e22's): "
                   "the Wristband, the Guest List, the Pass, Birthday, Welcome",
    "correction": "the required executions of the correction scope in docs/verification/places-review-manifest.tsv: the "
                  "ticket footer on both widths at the default and the largest text, one-stage back gestures and controls "
                  "(a cancelled swipe included), where a detail and the explanation start, the five Signal and interaction "
                  "tests whose endpoint changed, and the recorded correction walkthrough",
}.get(scope, "unknown scope")
required = {
    "source gate (exact reviewed revision, approved assets, Signal and Places guards, intent colour guard)":
        source.get("result") == "MATCH",
    "scope recorded by the source gate matches this run (%s)" % scope: source.get("scope") == scope,
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target") == "iPhone 17 Pro Max"
        and destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "domain tests on the Mac (swift test)": passed("domain-tests"),
    "test-harness compilation (build-for-testing)": passed("places-ui-build"),
    "UI tests executed and passed (%s; no retries; none skipped, interrupted or missing; every run exited 0)" % covered:
        tests.get("result") == "PASS" and tests.get("scope") == scope,
}
if scope in ("places", "correction"):
    required["journey recording confirmed and saved"] = last.get("places-recording", "").startswith("confirmed") \
        and os.path.isfile(movie) and os.path.getsize(movie) > 0
lines = [
    "Places review verdict, scope '%s' (automated results only; manual review is listed separately)" % scope,
    "",
    "Build       Codemagic %s; this verdict covers only the '%s' scope, at the source below. The other scopes "
    "run as their own builds; each names its commit." % (os.environ.get("CM_BUILD_ID", "(not on Codemagic)"), scope),
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"), tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"), simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"), destination.get("selected", "?")),
    "Devices     %s" % tests.get("devices", "?"),
    "Device B    %s" % status("places-device-b"),
    "Smaller     %s" % (smaller.get("device", "not run") if smaller else "not used in this scope"),
    "",
    "Required automated results:",
]
lines += ["  %-150s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += ["    XCTest detail: %s unique test cases, %s executions (passed %s, failed %s, skipped %s, interrupted %s); "
          "review flags seen: %s" % (tests.get("unique_test_cases", "?"), tests.get("executions", "?"), tests.get("passed", "?"),
                                     tests.get("failed", "?"), tests.get("skipped", "?"), tests.get("interrupted", "?"),
                                     tests.get("flag_markers_in_log", "?")),
          "    manifest: " + tests.get("manifest", "?"),
          "    required: " + tests.get("required_passed", "?"),
          "    first attempts: " + tests.get("first_attempt_required", "?"),
          "    retries: " + tests.get("retries", "?") + "; tests executed more than once in one run: " + tests.get("retried", "?"),
          "    optional runs (repeats and extras: not unique tests, not retries; if they run they must pass): "
          + tests.get("repeats", "?"),
          "    infrastructure reruns (simulator not found, no test ran): " + tests.get("infrastructure_reruns", "?")]
path = os.path.join(out, "ui-review-tests.txt")
if os.path.isfile(path):
    lines += ["    " + line.strip() for line in open(path)
              if re.match(r"^\w+Tests\.test\w+\[", line) or line.startswith("xcodebuild_exit")]
lines += ["", "Supplementary (reported, not required):"]
if scope == "places":
    lines += ["  compact walkthrough video: " + compact.get("result", "NOT RUN")]
lines += [
    "  unsigned simulator app zip (simulator only; not installable on a device): " + status("package"),
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/places-approved/reference (the founder decides)",
    "  VoiceOver: the ticket's parts and its View place button, the tabs' selection, the disabled action's reason (its "
    "hint), focus after each stage change and after Back, and the escape gesture (not handled by Places)",
    "  system Settings > Accessibility > Reduce Motion (only the app's preview flag was tested) and larger text on a device",
    "  landscape and iPad (the app is portrait-only on iPhone; other orientations are untested)",
    "  composing keyboards (Japanese, Chinese, Korean) and the software keyboard on a device",
    "  motion smoothness on a device (simulator recordings drop frames and have variable frame timing)",
]
ok = all(required.values())
if scope == "correction":
    lines += ["", "This is a targeted correction run. It does not re-execute the 13 earlier Places executions or the 43",
              "earlier-chapter executions (signal and regressions) except those listed above by test and device; the",
              "full regression sweep is pending."]
    verdict = "PASS (targeted correction; full regression sweep pending; manual review still outstanding)" if ok \
        else "FAIL (scope correction)"
else:
    verdict = "PASS (scope %s; manual review still outstanding)" % scope if ok else "FAIL (scope %s)" % scope
lines += ["", "AUTOMATED VERDICT: " + verdict]
open(os.path.join(out, "verdict.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if ok else 1)
PY
}

# ---------------------------------------------------------------------------------------
# package-review and enforce
# ---------------------------------------------------------------------------------------

stage_package_review() {
    local status=0 title
    run python3 scripts/places_review_package.py "$ROOT" "$OUT" "$ARTIFACTS" "$SCOPE" || status=$?
    case "$SCOPE" in
        places) title="Places-Review" ;;
        signal) title="Places-Signal-Review" ;;
        correction) title="Places-Correction-Review" ;;
        *) title="Places-Regressions-Review" ;;
    esac
    summary_line "places-package" "$(unzip -l "$ARTIFACTS/$title.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in $title.zip; $(tr '\n' ' ' < "$OUT/package-links.txt" 2>/dev/null)"
    return "$status"
}

stage_enforce() {
    run cat "$OUT/verdict.txt" || true
    if grep -q '^AUTOMATED VERDICT: PASS' "$OUT/verdict.txt" 2>/dev/null; then
        note "Automated verdict PASS; manual review remains outstanding."
    else
        note "ERROR: the automated verdict is not PASS (or no verdict was produced)."
        return 1
    fi
}

case "$STAGE" in
    checkpoint) stage_checkpoint ;;
    destinations) stage_destinations ;;
    ui-review) stage_ui_review ;;
    compact-video) stage_compact_video ;;
    verdict) stage_verdict ;;
    package-review) stage_package_review ;;
    enforce) stage_enforce ;;
esac
