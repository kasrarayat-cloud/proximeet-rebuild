#!/usr/bin/env bash
# Proximeet — runtime review of the approved Wristband (chapter 05) in the iOS Simulator, with the
# Guest List keyboard follow-up. Manual and unsigned. Codemagic workflow: proximeet-wristband-review
# (codemagic.yaml). See docs/verification/wristband-mac-review.md.
#
#   bash scripts/wristband_review.sh <stage>
#
# Stages:
#   checkpoint    source gate. The approved assets (Welcome poses, Manrope fonts and licence, the
#                 Birthday housing, the Pass artwork, the Guest List card art, the four Wristband
#                 artworks, the approved references) must match
#                 docs/verification/wristband-approved-files.sha256 and their handoff provenance;
#                 every other file must match docs/verification/wristband-review-files.sha256 (which
#                 excludes only itself); no other file may exist; earlier deletions stay absent; the
#                 Wristband, Guest List and Pass sources carry no verification, visibility, capture,
#                 network, persistence, logging or timer API. Run input WRISTBAND_EXPECTED_COMMIT
#                 (full 40-hex SHA) pins HEAD; required on Codemagic (CM_BUILD_ID set), optional
#                 elsewhere. Also records the time budget's start. Runs anywhere.
#   destinations  list installed simulators; report whether iPhone 17 Pro Max was selected; start
#                 the first boots of the selected simulator and of a smaller iPhone behind the
#                 compilation
#   ui-review     compile the UI test harness; clone the booted iPhone 17 Pro Max ("device B",
#                 deleted after the run, so it starts warm); then, in parallel: on the selected
#                 one, the recorded Wristband walkthrough, the other Wristband tests and the
#                 Birthday, Welcome and three Pass regressions; on device B, the Guest List tests
#                 (the keyboard Done/Back check included) and the Pass walkthrough, and last the
#                 Guest List tests that send hardware key events. Then, on the smaller iPhone, the
#                 keyboard Done/Back check again and supplementary fixture captures. The compact
#                 video is made in the background once the recording ends. Every xcodebuild is
#                 bounded by time; a failed test other than the recorded walkthrough is retried
#                 once and reported as such. Zero
#                 executed tests, or any final failure or skip of a required test, fails the stage
#   compact-video half-size re-encode of the recording, trimmed to the app
#   verdict       automated results, kept apart from outstanding manual review
#   package-review  build/artifacts/Wristband-Review.zip (offline index.html), Wristband-Screens.zip,
#                 Wristband-walkthrough-compact.zip/.mp4, Wristband-walkthrough-original.zip and the
#                 archive's SHA-256
#   enforce       fail the build unless the verdict says PASS (run last)
#
# Outputs go to build/artifacts/wristband/, logs to build/artifacts/logs/wristband-<stage>*.log, and
# PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or downloaded and no
# simulator runtime is installed. Written for the macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
OUT="$ARTIFACTS/wristband"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DEVICE_B_ENV="$META/wristband-device-b.env"
T0_FILE="$META/wristband-t0.txt"
DERIVED_DATA="$ROOT/build/DerivedData"
DERIVED_DATA_B="$ROOT/build/DerivedDataB"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/wristband-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/wristband-review-files.sha256"
DELETIONS="docs/verification/wristband-review-deletions.txt"
CHECKPOINT_RESULT="$OUT/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
DEVICE_B_NAME="iPhone 17 Pro Max (review B)"
SMALLER_IPHONES="iPhone 17e|iPhone 16e|iPhone SE (3rd generation)|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
# The UI work must end this many seconds after the checkpoint stage began (about a minute into the
# build), leaving the verdict, the packages and publishing inside the workflow's 28 minutes (the
# compact video is made during the UI work).
UI_DEADLINE_SECONDS=1440
SMALL_ENV="$META/wristband-smaller.env"
WALKTHROUGH="WristbandReviewTests/testWalkthroughRouteChoicesBackReentryEndpoint"
WRISTBAND_TESTS="testWalkthroughRouteChoicesBackReentryEndpoint testEveryChangeBetweenIntentsKeepsEverythingInAgreement testRapidChangesLeaveTheLastChoice testEndpointDuplicateTapsAndBack testRelaunchStartsUnselected testReduceMotionPreviewChangesWithoutMovement testLargestTextKeepsEveryChoiceReachable"
WELCOME_TESTS="testHonestNotices testReduceMotionPreviewLaunch testDefaultGeometry"
# Hardware key events (Tab, or the ⌘V paste fallback) can leave the simulator without its
# on-screen keyboard, so those tests run last on their device, in their own pass.
GUEST_LIST_HARDWARE_KEY_TESTS="testBlankInternationalAndLongNames testOpenerLimitBoundariesAndPreservedPaste testHardwareTabAndShiftTabMoveBetweenFields"
GUEST_LIST_TESTS="testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint testInterestsToggleIndependentlyAndOptionalContentIsOmitted testKeyboardFocusOrderReachabilityAndDismissal testKeyboardDoneAndBackStayIndependent testRepeatedTapsNeverDuplicateOrSkipARoute testRelaunchResetsTheDraftAndNothingIsConferred testReduceMotionPreviewKeepsTheCardStationary testLargestTextReflowsAndKeepsEverythingReachable"
# Pass is split between the two simulators to balance them.
PASS_TESTS_B="testWalkthroughStartFinishEndpointLeaveReentryCancelBack"
PASS_TESTS_MAIN="testGateRapidTapsWaitingAndResumeNeverAdvanceOnTheirOwn testReduceMotionPreviewKeepsThePassStationary testLargestTextKeepsTheDemoLabelWholeAndControlsReachable"
BIRTHDAY_TESTS="testWalkthroughEntryCorrectionContinueBack testTypedEntryPreservesComponentsAndKeyboard"
KEYBOARD_CHECK="testKeyboardDoneAndBackStayIndependent"
TEST_TIMEOUTS="-test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 360"
# One retry for a failed test (build 1 lost a Birthday test to "Timed out while acquiring background
# assertion" at launch). Every attempt is parsed and reported; only the final outcome counts.
RETRY="-retry-tests-on-failure -test-iterations 2"
WARMUP_SMALL_SECONDS=8
SETTLE_SECONDS=3
STATUS_BARS=""
RECORDER_PID=""
BOOTED_BY_US=""
DEVICE_B_CREATED=""
B_PID=""
COMPACT_PID=""
ENCODER_PID=""
LAUNCH_PID=""

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce) ;;
    *)
        echo "usage: $0 checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$OUT"
LOG="$LOGS/wristband-$STAGE${WRISTBAND_LOG_SUFFIX:-}.log"
: > "$LOG"

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
        summary_line "wristband-$STAGE" "PASS"
    else
        summary_line "wristband-$STAGE" "FAIL (exit $status), see $LOG"
        echo "wristband_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
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
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/wristband_review.sh checkpoint' first. Nothing is tested for an unverified source."
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
# checkpoint
# ---------------------------------------------------------------------------------------

stage_checkpoint() {
    date +%s > "$T0_FILE"
    rm -f "$CHECKPOINT_RESULT"
    run python3 - "$FROZEN_MANIFEST" "$REVIEW_MANIFEST" "$DELETIONS" "$CHECKPOINT_RESULT" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys

frozen_path, review_path, deletions, out_path = sys.argv[1:5]


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
# Wristband handoff's SHA256SUMS.txt covers the four band artworks, the Manrope faces and the
# licence; the Guest List handoff's covers the card art; the Pass handoff's the pass artwork; the
# Birthday handoff's the housing; Welcome's FONT_SOURCE.json and the Birthday, Pass and Guest List
# records must agree on the faces.
assets = "Proximeet/Resources/Assets.xcassets/"
provenance, bundled = {}, ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")


def sums(path):
    return dict(reversed(line.strip().split("  ", 1)) for line in open(path) if line.strip())


try:
    handoff = sums("docs/design/wristband-approved/SHA256SUMS.txt")
    guest = sums("docs/design/guest-list-approved/SHA256SUMS.txt")
    pass_sums = sums("docs/design/pass-approved/SHA256SUMS.txt")
    birthday = sums("docs/design/birthday-approved/SHA256SUMS.txt")
    for intent in ("Social", "Dating", "Business", "Activity"):
        name = "wristband-%s.png" % intent.lower()
        provenance[assets + "Wristband%s.imageset/%s" % (intent, name)] = handoff["assets/" + name]
    provenance[assets + "GuestListCard.imageset/guest-list-card.png"] = guest["assets/guest-list-card.png"]
    provenance[assets + "PassArtwork.imageset/pass-artwork.png"] = pass_sums["assets/pass-artwork.png"]
    provenance[assets + "BirthdayHousing.imageset/birthday-housing.png"] = birthday["assets/birthday-housing.png"]
    provenance[assets + "Manrope-OFL.dataset/OFL.txt"] = handoff["fonts/OFL.txt"]
    fonts = {f["file"]: f["sha256"] for f in json.load(open("docs/design/welcome-approved/FONT_SOURCE.json"))["fonts"]}
    for face in bundled:
        name = "Manrope-%s.ttf" % face
        provenance[assets + "Manrope-%s.dataset/%s" % (face, name)] = handoff["fonts/" + name]
        if any(record.get(key) != handoff["fonts/" + name] for record, key in
               ((fonts, name), (birthday, "fonts/" + name), (pass_sums, "fonts/" + name), (guest, "fonts/" + name))):
            problems.append("Welcome, Birthday, Pass, Guest List and Wristband font records disagree  " + name)
    for record, label in ((pass_sums, "Pass"), (guest, "Guest List")):
        if record.get("fonts/OFL.txt") != handoff["fonts/OFL.txt"]:
            problems.append("%s and Wristband licence records disagree  fonts/OFL.txt" % label)
except (OSError, ValueError, KeyError) as error:
    problems.append("provenance records unreadable: %r" % (error,))
for name, digest in sorted(provenance.items()):
    if name not in frozen:
        problems.append("approved asset not in the frozen manifest  " + name)
    elif os.path.isfile(name) and sha256(name) != digest:
        problems.append("differs from the approved handoff  " + name)

# The Wristband, Guest List and Pass route: no verification, visibility, membership, entitlement,
# presence, capture, network, persistence, logging or timer API in their sources. The visible
# sentences "Choosing a band doesn't make you visible.", "This preview doesn't make you visible to
# anyone." and "No age or identity verification is performed." say what is not done; none is a flag.
guarded_sources = ["Proximeet/Scenes/WristbandView.swift", "Proximeet/Scenes/GuestListView.swift",
                   "Proximeet/Scenes/PassView.swift", "Proximeet/Components/RepeatTapGuard.swift",
                   "Proximeet/App/DemoSession.swift",
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
            problems.append("Wristband guard: %s contains %r" % (path, token))

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

head = git("rev-parse", "HEAD") or "unavailable"
pin = os.environ.get("WRISTBAND_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("WRISTBAND_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but WRISTBAND_EXPECTED_COMMIT is %s" % (head, pin))
elif os.environ.get("CM_BUILD_ID"):
    problems.append("WRISTBAND_EXPECTED_COMMIT is unset on Codemagic: the reviewed commit is not pinned")

lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("WRISTBAND_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
    "frozen_manifest_sha256=" + sha256(frozen_path),
    "review_manifest_sha256=" + sha256(review_path),
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
    print("This checkout is not the reviewed Wristband revision. Do not review it as such.")
    sys.exit(1)
PY
    summary_line "wristband-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/wristband-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/wristband-runtimes-available.json"
    local status=0 smaller
    run python3 - "$META/wristband-devices-available.json" "$META/wristband-runtimes-available.json" \
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

    # The first boots (minutes of data migration) start now, behind the compilation and the domain
    # tests: the selected simulator, which device B is later cloned from, and the smaller iPhone.
    rm -f "$SMALL_ENV"
    run xcrun simctl boot "$SIM_UDID" || true
    smaller="$(smaller_iphone)" || smaller=""
    if [ -n "$smaller" ]; then
        printf 'SMALL_UDID=%s\nSMALL_NAME=%q\n' "$(printf '%s' "$smaller" | cut -f1)" "$(printf '%s' "$smaller" | cut -f2)" > "$SMALL_ENV"
        run xcrun simctl boot "$(printf '%s' "$smaller" | cut -f1)" || true
    else
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
    fi
    return "$status"
}

# ---------------------------------------------------------------------------------------
# ui-review
# ---------------------------------------------------------------------------------------

launch() {
    local udid="$1" output status
    shift
    LAUNCH_PID=""
    set +e
    output="$(xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" ${1+"$@"} 2>&1)"
    status=$?
    set -e
    note "$output"
    note "[exit $status] xcrun simctl launch --terminate-running-process $udid $BUNDLE_ID ${*-}"
    [ "$status" -eq 0 ] || return "$status"
    LAUNCH_PID="${output##*: }"
    case "$LAUNCH_PID" in
        ''|*[!0-9]*)
            note "ERROR: no process ID in the simctl launch output."
            return 1
            ;;
    esac
}

require_alive() {
    if ! ps -p "$LAUNCH_PID" >/dev/null 2>&1; then
        note "ERROR: the app process $LAUNCH_PID is not running; the capture would not show the app."
        return 1
    fi
}

screenshot() {
    local udid="$1" name="$2" label="$3" png width height digest
    png="$OUT/$name"
    rm -f "$png"
    require_alive || return 1
    run xcrun simctl io "$udid" screenshot --type=png "$png" || return 1
    require_alive || return 1
    if [ ! -s "$png" ]; then
        note "ERROR: $png is missing or empty."
        return 1
    fi
    width="$(sips -g pixelWidth "$png" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$png" | awk '/pixelHeight/ { print $2 }')"
    digest="$(shasum -a 256 "$png" | awk '{ print $1 }')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$udid" "$(utc_now)" "$width" "$height" "$digest" \
        "$label" >> "$OUT/captures.tsv"
}

# fixture <udid> <file> <fixture name> <label>: relaunch on a fixture and capture after it settles.
fixture() {
    local udid="$1" file="$2" name="$3" label="$4"
    launch "$udid" -ProximeetFixture "$name" || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "$file" "FIXTURE (-ProximeetFixture $name): $label"
}

guarded() {
    local label="$1" status
    shift
    if "$@"; then
        status=0
    else
        status=$?
    fi
    case "$status" in
        0) summary_line "$label" "PASS" ;;
        2) summary_line "$label" "SKIPPED" ;;
        *) summary_line "$label" "FAIL, see $LOG" ;;
    esac
    return 0
}

status_bar() {
    if run xcrun simctl status_bar "$1" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4; then
        STATUS_BARS="$STATUS_BARS $1"
    else
        note "NOTE: status bar override unavailable on $1; captures show the live status bar."
    fi
}

smaller_iphone() {
    xcrun simctl list -j devices available > "$META/wristband-simctl-devices.json"
    python3 - "$META/wristband-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
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
    xcrun xcresulttool get test-results summary --path "$result" > "${result%.xcresult}-summary.json" 2>>"$LOG" || true
    if bounded 90 xcrun xcresulttool export attachments --path "$result" --output-path "$dir" >> "$LOG" 2>&1; then
        note "Exported XCTest attachments to $dir."
    else
        note "NOTE: attachment export unavailable for $result; the per-test results are in the log and summary."
    fi
}

# xctest <udid> <derived data> <result bundle> <seconds> <-only-testing arguments...>: one bounded
# test-without-building run with every review flag set for the test runner.
xctest() {
    local udid="$1" derived="$2" result="$3" seconds="$4"
    shift 4
    if [ "$seconds" -lt 30 ]; then
        note "SKIPPED (time budget): too little time left for $*."
        return 124
    fi
    # shellcheck disable=SC2086
    run bounded "$seconds" env TEST_RUNNER_PROXIMEET_WRISTBAND_REVIEW=1 TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_PASS_REVIEW=1 TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 TEST_RUNNER_PROXIMEET_SHORT_HOLDS=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$derived" \
        "$@" -parallel-testing-enabled NO $TEST_TIMEOUTS $RETRY -resultBundlePath "$result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building
}

only() {
    local class="$1" test
    shift
    for test in "$@"; do
        printf -- '-only-testing:ProximeetUITests/%s/%s ' "$class" "$test"
    done
}

# The Guest List tests with the on-screen keyboard and the Pass walkthrough, then the hardware-key
# tests, on <udid> with <derived data>. Writes exit codes to $OUT/device-b-exits.txt.
regressions_chain() {
    local udid="$1" derived="$2" rest_status=0 keys_status=0
    local rest_result="$OUT/RegressionsB.xcresult" keys_result="$OUT/GuestListHardwareKeysB.xcresult"
    rm -rf "$rest_result" "$keys_result"
    # shellcheck disable=SC2046
    xctest "$udid" "$derived" "$rest_result" "$(budget 1000)" \
        $(only GuestListReviewTests $GUEST_LIST_TESTS) $(only PassReviewTests $PASS_TESTS_B) || rest_status=$?
    export_results "$rest_result" "$OUT/attachments-b"
    # shellcheck disable=SC2046
    xctest "$udid" "$derived" "$keys_result" "$(budget 420)" \
        $(only GuestListReviewTests $GUEST_LIST_HARDWARE_KEY_TESTS) || keys_status=$?
    export_results "$keys_result" "$OUT/attachments-b-keys"
    printf 'rest=%s\nkeys=%s\n' "$rest_status" "$keys_status" > "$OUT/device-b-exits.txt"
}

# The keyboard Done/Back check and three fixture captures on the smaller iPhone.
smaller_segment() {
    local udid name result="$OUT/KeyboardSmaller.xcresult" status=0 left
    if [ ! -f "$SMALL_ENV" ]; then
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        printf 'device=none installed\nkeyboard_exit=not run\n' > "$OUT/smaller.txt"
        return 2
    fi
    # shellcheck source=/dev/null
    . "$SMALL_ENV"
    udid="$SMALL_UDID"
    name="$SMALL_NAME"
    left="$(remaining)"
    if [ "$left" -lt 150 ]; then
        note "SKIPPED (time budget): ${left}s left, too little to boot $name."
        printf 'device=%s (%s)\nkeyboard_exit=not run (time budget)\n' "$name" "$udid" > "$OUT/smaller.txt"
        return 1
    fi
    note "Smaller iPhone: $name ($udid)."
    printf 'device=%s (%s)\nkeyboard_exit=not run (boot)\n' "$name" "$udid" > "$OUT/smaller.txt"
    run xcrun simctl boot "$udid" || true
    BOOTED_BY_US="$BOOTED_BY_US $udid"
    run bounded "$(budget 240)" xcrun simctl bootstatus "$udid" -b || return 1
    status_bar "$udid"
    rm -rf "$result"
    xctest "$udid" "$DERIVED_DATA" "$result" "$(budget 240)" $(only GuestListReviewTests $KEYBOARD_CHECK) || status=$?
    export_results "$result" "$OUT/attachments-small"
    printf 'device=%s (%s)\nkeyboard_exit=%s\n' "$name" "$udid" "$status" > "$OUT/smaller.txt"
    run xcrun simctl install "$udid" "$APP_PATH" || return 1
    launch "$udid" -ProximeetFixture wristband || return 1
    sleep "$WARMUP_SMALL_SECONDS"
    guarded wb-fix-smaller-empty fixture "$udid" 01-wristband-smaller-empty.png wristband "the empty Wristband on $name"
    guarded wb-fix-smaller-social fixture "$udid" 02-wristband-smaller-social.png wristband-social "Social on $name"
    guarded wb-fix-smaller-activity fixture "$udid" 03-wristband-smaller-activity.png wristband-activity "Activity on $name"
    run xcrun simctl shutdown "$udid" || true
    return "$status"
}

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    check_app
    local build_status walk_status=0 main_status=0 small_status=0 waited=0 recording_started
    local movie="$OUT/wristband-walkthrough-original.mp4" b_udid="" b_log="$LOGS/wristband-ui-review-device-b.log"
    local walk_result="$OUT/WristbandWalkthrough.xcresult" main_result="$OUT/WristbandReview.xcresult"
    rm -rf "$OUT"/*.xcresult "$OUT"/attachments-* "$movie" "$movie.log" "$OUT/recording-started.txt" \
        "$OUT/device-b-exits.txt" "$OUT/smaller.txt" "$OUT"/0*-wristband-*.png "$b_log" \
        "$OUT/walkthrough-started.txt" "$OUT/compact-video.txt" "$OUT/wristband-walkthrough-compact.mp4" \
        "$OUT/wristband-walkthrough-compact.mp4.sha256"
    printf 'file\tsimulator\tcaptured_utc\tpixel_width\tpixel_height\tsha256\tnote\n' > "$OUT/captures.tsv"
    export NSUnbufferedIO=YES
    note "UI deadline: $(remaining)s left of the ${UI_DEADLINE_SECONDS}s budget."

    # 1. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run bounded "$(budget 600)" xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests/WristbandReviewTests -only-testing:ProximeetUITests/GuestListReviewTests \
        -only-testing:ProximeetUITests/PassReviewTests -only-testing:ProximeetUITests/BirthdayReviewTests \
        -only-testing:ProximeetUITests/WelcomeReviewTests \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "wristband-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "wristband-ui-build" "PASS (UI test harness compiled)"

    # 2. The first boots started in destinations. The smaller iPhone finishes its data migration and
    #    waits shut down, so its later boot is quick. Device B is a clone of the selected simulator
    #    after its first boot, so it starts warm; it runs from its own copy of the build products
    #    (a clone on APFS), so the two xcodebuild processes never share a DerivedData folder.
    run bounded "$(budget 420)" xcrun simctl bootstatus "$SIM_UDID" -b || true
    if [ -f "$SMALL_ENV" ]; then
        # shellcheck source=/dev/null
        . "$SMALL_ENV"
        run bounded "$(budget 300)" xcrun simctl bootstatus "$SMALL_UDID" -b || true
        run xcrun simctl shutdown "$SMALL_UDID" || true
    fi
    run xcrun simctl shutdown "$SIM_UDID" || true
    rm -f "$DEVICE_B_ENV"
    if b_udid="$(xcrun simctl clone "$SIM_UDID" "$DEVICE_B_NAME" 2>>"$LOG")" && [ -n "$b_udid" ]; then
        DEVICE_B_CREATED="$b_udid"
        printf 'DEVICE_B_UDID=%s\n' "$b_udid" > "$DEVICE_B_ENV"
        note "Device B: $DEVICE_B_NAME, cloned from $SIM_UDID after its first boot: $b_udid."
        summary_line "wristband-device-b" "cloned $b_udid from $SIM_UDID ($SIM_NAME, $SIM_RUNTIME_NAME)"
        rm -rf "$DERIVED_DATA_B"
        if ! run cp -Rc "$DERIVED_DATA" "$DERIVED_DATA_B" && ! run ditto "$DERIVED_DATA" "$DERIVED_DATA_B"; then
            note "WARNING: the build products could not be copied for device B; everything runs on $SIM_NAME."
            b_udid=""
        fi
    else
        b_udid=""
        note "WARNING: device B could not be cloned; the tests run in sequence on $SIM_NAME."
        summary_line "wristband-device-b" "NOT CLONED; tests run in sequence"
    fi
    run xcrun simctl boot "$SIM_UDID" || true
    if [ -n "$b_udid" ]; then
        run xcrun simctl boot "$b_udid" || true
    fi
    run bounded "$(budget 240)" xcrun simctl bootstatus "$SIM_UDID" -b || true
    status_bar "$SIM_UDID"
    if [ -n "$b_udid" ]; then
        run bounded "$(budget 240)" xcrun simctl bootstatus "$b_udid" -b || true
        status_bar "$b_udid"
        (
            trap - EXIT INT TERM
            LOG="$b_log"
            : > "$LOG"
            note "Device B ($b_udid): Guest List and Pass, then the Guest List hardware-key tests."
            regressions_chain "$b_udid" "$DERIVED_DATA_B"
        ) &
        B_PID=$!
        summary_line "wristband-parallel" "device B $b_udid runs Guest List and the Pass walkthrough beside the Wristband, Birthday, Welcome and three Pass tests"
    fi

    # 3. The recorded walkthrough on the selected simulator: the recorder is confirmed active before
    #    the test starts, and the app is closed first. compact-video trims the lead-in.
    run xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
    xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 --force "$movie" > "$movie.log" 2>&1 &
    RECORDER_PID=$!
    while ! grep -q "Recording started" "$movie.log" 2>/dev/null && [ "$waited" -lt 40 ]; do
        kill -0 "$RECORDER_PID" 2>/dev/null || break
        sleep 0.25
        waited=$((waited + 1))
    done
    recording_started="$(python3 -c 'import time; print("%.3f" % time.time())')"
    if grep -q "Recording started" "$movie.log" 2>/dev/null; then
        printf '%s\n' "$recording_started" > "$OUT/recording-started.txt"
        summary_line "wristband-recording" "confirmed active before the walkthrough"
    else
        note "WARNING: simctl did not confirm 'Recording started'; the walkthrough still runs, unrecorded."
        summary_line "wristband-recording" "NOT CONFIRMED"
        stop_recorder
        rm -f "$movie"
    fi
    # The recorded walkthrough keeps its full holds: it is the one test meant to be watched. Not
    # retried (a retry would not be the recorded run). The bound leaves room after the test for the
    # result bundle to be written: build 1 lost its attachments when a 300-s bound ended xcodebuild
    # 44 s after the test passed.
    if run bounded "$(budget 480)" env TEST_RUNNER_PROXIMEET_WRISTBAND_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"ProximeetUITests/$WALKTHROUGH" -parallel-testing-enabled NO $TEST_TIMEOUTS \
        -resultBundlePath "$walk_result" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
        walk_status=0
    else
        walk_status=$?
    fi
    stop_recorder
    if [ -s "$movie" ]; then
        shasum -a 256 "$movie" > "$movie.sha256"
    fi
    export_results "$walk_result" "$OUT/attachments-walkthrough"
    # The compact video is made now, in the background, from the walkthrough's own start marker.
    sed -n 's/.*WRISTBAND_WALKTHROUGH_START \([0-9][0-9.]*\).*/\1/p' "$LOG" | head -n 1 > "$OUT/walkthrough-started.txt"
    if [ -s "$movie" ]; then
        WRISTBAND_LOG_SUFFIX=-during-ui-review bash scripts/wristband_review.sh compact-video > /dev/null 2>&1 &
        COMPACT_PID=$!
    fi

    # 4. The other Wristband tests and the Birthday, Welcome and three Pass regressions on the
    #    selected simulator.
    # shellcheck disable=SC2046
    xctest "$SIM_UDID" "$DERIVED_DATA" "$main_result" "$(budget 900)" \
        $(only WristbandReviewTests $(printf '%s\n' $WRISTBAND_TESTS | grep -v '^testWalkthrough')) \
        $(only BirthdayReviewTests $BIRTHDAY_TESTS) $(only PassReviewTests $PASS_TESTS_MAIN) \
        $(only WelcomeReviewTests $WELCOME_TESTS) || main_status=$?
    export_results "$main_result" "$OUT/attachments-main"

    # 5. Without device B, its share runs here, after the Wristband tests.
    if [ -z "$b_udid" ]; then
        regressions_chain "$SIM_UDID" "$DERIVED_DATA"
    else
        # The selected simulator is done; free its memory for the smaller iPhone.
        run xcrun simctl shutdown "$SIM_UDID" || true
    fi

    # 6. The smaller iPhone: the keyboard Done/Back check and supplementary captures.
    if smaller_segment; then
        small_status=0
    else
        small_status=$?
    fi
    case "$small_status" in
        0) summary_line "wristband-smaller" "PASS ($(tr '\n' ' ' < "$OUT/smaller.txt"))" ;;
        *) summary_line "wristband-smaller" "exit $small_status ($(tr '\n' ' ' < "$OUT/smaller.txt" 2>/dev/null))" ;;
    esac

    # 7. Device B's results, and the compact video.
    if [ -n "$B_PID" ]; then
        note "Waiting for device B ($(remaining)s left)."
        wait "$B_PID" || true
        B_PID=""
    fi
    if [ -n "$COMPACT_PID" ]; then
        waited=0
        while kill -0 "$COMPACT_PID" 2>/dev/null && [ "$waited" -lt 360 ] && [ "$(remaining)" -gt 0 ]; do
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
    run cat "$OUT/captures.tsv"

    # 8. What actually ran, per device, from xcodebuild's per-test lines (to a file: bash 3.2
    #    misparses heredocs inside $( )).
    python3 - "$LOG" "$b_log" "$OUT/ui-review-tests.txt" "$walk_status" "$main_status" "$small_status" \
        "$OUT/device-b-exits.txt" "$b_udid" "$WRISTBAND_TESTS" "$WELCOME_TESTS" \
        "$GUEST_LIST_TESTS $GUEST_LIST_HARDWARE_KEY_TESTS" "$PASS_TESTS_B" "$BIRTHDAY_TESTS" \
        "$KEYBOARD_CHECK" "$SIM_UDID" "$PASS_TESTS_MAIN" > "$OUT/ui-review-counts.txt" <<'PY'
import os
import re
import sys

(main_log, b_log, out_path, walk_exit, main_exit, small_exit, b_exits_path, b_udid,
 wristband, welcome, guest_list, pass_b, birthday, keyboard, main_id, pass_main) = sys.argv[1:17]
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?(WelcomeReviewTests|BirthdayReviewTests|PassReviewTests|GuestListReviewTests|WristbandReviewTests)[ ./](test\w+)(?:\(\))?\]?' (passed|failed|skipped)(?: \(([\d.]+) seconds\))?")

# Each run's lines are attributed to a simulator by the xcodebuild destination that `run` printed
# before them ("$ ... -destination platform=iOS Simulator,id=<UDID> ...").
outcomes = {}
history = {}
durations = {}
markers = set()
walk_start = None


def scan(path, default_device):
    global walk_start
    device = default_device
    if not os.path.isfile(path):
        return
    for line in open(path, encoding="utf-8", errors="replace"):
        started = re.search(r"^\$ .*-destination platform=iOS Simulator,id=([0-9A-F-]{36})", line)
        if started:
            device = started.group(1)
        match = pattern.search(line)
        if match:
            key = (device, "%s.%s" % (match.group(1), match.group(2)))
            outcomes[key] = match.group(3)
            history.setdefault(key, []).append(match.group(3))
            if match.group(4):
                durations[key] = match.group(4)
        for marker in ("WRISTBAND_REVIEW_FLAG_SEEN", "GUEST_LIST_REVIEW_FLAG_SEEN", "PASS_REVIEW_FLAG_SEEN",
                       "BIRTHDAY_REVIEW_FLAG_SEEN", "WELCOME_REVIEW_FLAG_SEEN"):
            if marker in line:
                markers.add(marker.split("_REVIEW")[0].lower())
        begun = re.search(r"WRISTBAND_WALKTHROUGH_START (\d+(?:\.\d+)?)", line)
        if begun and walk_start is None:
            walk_start = begun.group(1)


scan(main_log, "main")
if b_log != main_log:
    scan(b_log, "b")
devices = sorted({device for device, _ in outcomes})
b_exits = {}
if os.path.isfile(b_exits_path):
    for line in open(b_exits_path):
        key, _, value = line.strip().partition("=")
        b_exits[key] = value


def names(cls, tests):
    return ["%s.%s" % (cls, t) for t in tests.split()]


lines, missing = [], []
# Required: every Wristband, Birthday and Welcome test on the selected simulator; every Guest List and
# Pass test on device B (or the selected simulator without it); the keyboard check on a smaller iPhone.
required_main = (names("WristbandReviewTests", wristband) + names("BirthdayReviewTests", birthday)
                 + names("WelcomeReviewTests", welcome) + names("PassReviewTests", pass_main))
required_b = names("GuestListReviewTests", guest_list) + names("PassReviewTests", pass_b)
required_small = names("GuestListReviewTests", keyboard)


def passed_on(name, predicate):
    return any(outcome == "passed" and n == name and predicate(device) for (device, n), outcome in outcomes.items())


small_ids = sorted(d for d in devices if d not in (main_id, b_udid, "main", "b"))
small_id = ", ".join(small_ids)
for name in required_main:
    if not passed_on(name, lambda d: d == main_id):
        missing.append("%s on the selected iPhone 17 Pro Max" % name)
for name in required_b:
    if not passed_on(name, lambda d: d == (b_udid or main_id)):
        missing.append("%s on %s" % (name, "device B" if b_udid else "the selected simulator"))
for name in required_small:
    if not passed_on(name, lambda d: d not in (main_id, b_udid) and d not in ("main", "b")):
        missing.append("%s on the smaller iPhone" % name)
counts = {k: sum(1 for v in outcomes.values() if v == k) for k in ("passed", "failed", "skipped")}
executed = counts["passed"] + counts["failed"]
exits = {"walkthrough": walk_exit, "wristband_birthday_welcome": main_exit, "smaller": small_exit,
         "device_b_rest": b_exits.get("rest", "not run"), "device_b_keys": b_exits.get("keys", "not run")}
# A retry is a failed attempt followed by a final pass on the same simulator.
retried_on = {device for (device, name), runs in history.items() if "failed" in runs[:-1] and runs[-1] == "passed"}
retried = sorted("%s[%s] %s" % (name, device if device not in (main_id, b_udid) else ("main" if device == main_id else "deviceB"),
                                " then ".join(runs))
                 for (device, name), runs in history.items() if "failed" in runs[:-1])
# xcodebuild exits 65 when any attempt failed, a retried one included. So 65 is accepted only for a
# run whose simulator shows a test that failed and then passed; the recorded walkthrough (never
# retried) must exit 0, and any other exit (65 without a retried test, a timeout, a skip for time)
# fails the stage.
segments = {"wristband_birthday_welcome": {main_id}, "device_b_rest": {b_udid or main_id},
            "device_b_keys": {b_udid or main_id}, "smaller": set(small_ids)}
ok = (executed > 0 and counts["failed"] == 0 and not missing
      and all(str(v) == "0" or (str(v) == "65" and segments.get(k, set()) & retried_on)
              for k, v in exits.items()))
label = {main_id: "main", b_udid: "deviceB"} if b_udid else {main_id: "main"}
for (device, name), outcome in sorted(outcomes.items(), key=lambda item: (item[0][1], item[0][0])):
    runs = history.get((device, name), [outcome])
    lines.append("%s[%s]=%s%s%s" % (name, label.get(device, "smaller:" + device), outcome,
                                    (" (%s s)" % durations[(device, name)]) if (device, name) in durations else "",
                                    (" after a retry: " + " then ".join(runs)) if "failed" in runs[:-1] else ""))
lines += ["discovered=%d" % len(outcomes), "executed=%d" % executed,
          "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
          "required_passed=" + ("yes" if not missing else "no (" + "; ".join(missing) + ")"),
          "retried=" + ("; ".join(retried) if retried else "none"),
          "flag_markers_in_log=" + " ".join(sorted(markers)),
          "walkthrough_started_epoch=%s" % (walk_start or "unknown"),
          "devices=main %s; device B %s; smaller %s" % (main_id, b_udid or "not used", small_id or "not used")]
lines += ["xcodebuild_exit_%s=%s" % item for item in sorted(exits.items())]
lines += ["result=" + ("PASS" if ok else "FAIL")]
open(out_path, "w").write("\n".join(lines) + "\n")
print("executed %d of %d discovered (passed %d, failed %d, skipped %d; %d retried after a failure); required passed: %s; exits %s; %s"
      % (executed, len(outcomes), counts["passed"], counts["failed"], counts["skipped"], len(retried),
         "yes" if not missing else "no", ",".join("%s:%s" % item for item in sorted(exits.items())),
         "PASS" if ok else "FAIL"))
PY
    # Device B's log joins this one only now, after the parse, so no result is read twice.
    if [ -n "$b_udid" ]; then
        cat "$b_log" >> "$LOG" 2>/dev/null || true
    fi
    run cat "$OUT/ui-review-tests.txt"
    summary_line "wristband-ui-run" "$(cat "$OUT/ui-review-counts.txt")"
    grep -qx 'result=PASS' "$OUT/ui-review-tests.txt"
}

# ---------------------------------------------------------------------------------------
# compact-video
# ---------------------------------------------------------------------------------------

# A half-size re-encode of the recording, trimmed to the app (by frame brightness, with the
# walkthrough's start marker as the fallback). AVFoundation, through scripts/compact_video.swift;
# the original is untouched. If the re-encode fails, the fallback is a labelled copy. ui-review
# starts this stage in the background as soon as the recording ends; the workflow's own step then
# reports that result, or makes it if it is missing.
stage_compact_video() {
    local movie="$OUT/wristband-walkthrough-original.mp4" compact="$OUT/wristband-walkthrough-compact.mp4"
    local start=0 marker started pid waited=0 status=1
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
    marker="$(cat "$OUT/walkthrough-started.txt" 2>/dev/null || true)"
    if [ -z "$marker" ]; then
        marker="$(sed -n 's/^walkthrough_started_epoch=//p' "$OUT/ui-review-tests.txt" 2>/dev/null || true)"
    fi
    started="$(cat "$OUT/recording-started.txt" 2>/dev/null || true)"
    if [ -n "$marker" ] && [ "$marker" != "unknown" ] && [ -n "$started" ]; then
        start="$(python3 -c "import sys; print('%.2f' % max(0.0, float(sys.argv[1]) - float(sys.argv[2]) - 0.5))" "$marker" "$started")"
    fi
    note "Trim start: ${start}s (walkthrough start $marker, recording start $started)."
    xcrun swift scripts/compact_video.swift "$movie" "$compact" "$start" > "$OUT/compact-video.out" 2>> "$LOG" &
    pid=$!
    ENCODER_PID=$pid
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 360 ]; do
        sleep 0.5
        waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        note "WARNING: the re-encode did not finish within 180 s; stopping it."
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    elif wait "$pid"; then
        status=0
    fi
    ENCODER_PID=""
    cat "$OUT/compact-video.out" >> "$LOG" 2>/dev/null || true
    if [ "$status" -eq 0 ] && [ -s "$compact" ]; then
        printf 'result=RE-ENCODED\nmethod=AVFoundation export: %s\n' "$(tail -n 1 "$OUT/compact-video.out")" > "$OUT/compact-video.txt"
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
    run python3 - "$SUMMARY" "$META" "$OUT" <<'PY'
import json
import os
import sys

summary_path, meta, out = sys.argv[1:4]
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
movie = os.path.join(out, "wristband-walkthrough-original.mp4")
required = {
    "source gate (exact reviewed revision, approved assets, Wristband guard)": source.get("result") == "MATCH",
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target") == "iPhone 17 Pro Max"
        and destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "domain tests on the Mac (swift test)": passed("domain-tests"),
    "test-harness compilation (build-for-testing)": passed("wristband-ui-build"),
    "UI tests executed and passed (Wristband, Guest List incl. keyboard Done/Back on two sizes, Pass, Birthday, Welcome; none skipped)":
        tests.get("result") == "PASS",
    "interaction recording confirmed and saved": last.get("wristband-recording", "").startswith("confirmed")
        and os.path.isfile(movie) and os.path.getsize(movie) > 0,
}
lines = [
    "Wristband review verdict (automated results only; manual review is listed separately)",
    "",
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"), tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"), simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"), destination.get("selected", "?")),
    "Devices     %s" % tests.get("devices", "?"),
    "Device B    %s" % status("wristband-device-b"),
    "Smaller     %s" % smaller.get("device", "not run"),
    "",
    "Required automated results:",
]
lines += ["  %-120s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += ["    XCTest detail: executed %s, passed %s, failed %s, skipped %s; review flags seen: %s" % (
    tests.get("executed", "?"), tests.get("passed", "?"), tests.get("failed", "?"), tests.get("skipped", "?"),
    tests.get("flag_markers_in_log", "?"))]
lines += ["    required: " + tests.get("required_passed", "?")]
lines += ["    retried (failed, then run once more): " + tests.get("retried", "?")]
path = os.path.join(out, "ui-review-tests.txt")
if os.path.isfile(path):
    lines += ["    " + line.strip() for line in open(path) if "ReviewTests." in line or line.startswith("xcodebuild_exit")]
lines += [
    "",
    "Supplementary (reported, not required):",
    "  smaller iPhone fixture captures (not interactions): empty %s | Social %s | Activity %s" % (
        status("wb-fix-smaller-empty"), status("wb-fix-smaller-social"), status("wb-fix-smaller-activity")),
    "  compact walkthrough video: " + compact.get("result", "NOT RUN"),
    "  unsigned simulator app zip (simulator only; not installable on a device): " + status("package"),
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/wristband-approved/reference (the founder decides)",
    "  VoiceOver: the single-choice reading, the selection announcement, focus after each choice and after Back",
    "  system Settings > Accessibility > Reduce Motion (only the app's preview flag was tested) and larger text on a device",
    "  the software keyboard and composing input on a device; the Guest List keyboard on other phone sizes",
    "  motion smoothness on a device (simulator recordings drop frames and have variable frame timing)",
]
ok = all(required.values())
lines += ["", "AUTOMATED VERDICT: " + ("PASS (manual review still outstanding)" if ok else "FAIL")]
open(os.path.join(out, "verdict.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if ok else 1)
PY
}

# ---------------------------------------------------------------------------------------
# package-review and enforce
# ---------------------------------------------------------------------------------------

stage_package_review() {
    run python3 - "$ROOT" "$OUT" "$ARTIFACTS" <<'PY'
import hashlib
import html
import json
import os
import shutil
import sys
import zipfile

root, out, artifacts = sys.argv[1:4]
out_zip = os.path.join(artifacts, "Wristband-Review.zip")
ref = os.path.join(root, "docs/design/wristband-approved/reference")
entries, missing = [], []


def add(name, source, required=True):
    if os.path.isfile(source):
        entries.append((name, source))
        return name
    if required:
        missing.append(name)
    return None


def read(path):
    return open(path, encoding="utf-8", errors="replace").read() if os.path.isfile(path) else ""


def kv(path):
    values = {}
    for line in read(path).splitlines():
        key, sep, value = line.partition("=")
        if sep:
            values.setdefault(key, value)
    return values


board = add("approved/wristband-review.png", os.path.join(ref, "wristband-review.png"))
deliveries = {intent: add("approved/%s-delivery.jpg" % intent, os.path.join(ref, "%s-delivery.jpg" % intent))
              for intent in ("social", "dating", "business", "activity")}
compact = add("captures/wristband-walkthrough-compact.mp4", os.path.join(out, "wristband-walkthrough-compact.mp4"))
original = add("captures/wristband-walkthrough-original.mp4", os.path.join(out, "wristband-walkthrough-original.mp4"))
fixture_files = ("01-wristband-smaller-empty.png", "02-wristband-smaller-social.png", "03-wristband-smaller-activity.png")
fixtures = {key: add("fixtures/" + key, os.path.join(out, key), required=False) for key in fixture_files}
for key in ("verdict.txt", "ui-review-tests.txt", "destination.txt", "source-checkpoint.txt", "captures.tsv",
            "compact-video.txt", "smaller.txt", "device-b-exits.txt", "wristband-walkthrough-original.mp4.sha256",
            "wristband-walkthrough-compact.mp4.sha256", "WristbandWalkthrough-summary.json", "WristbandReview-summary.json",
            "RegressionsB-summary.json", "GuestListHardwareKeysB-summary.json", "KeyboardSmaller-summary.json"):
    add("results/" + key, os.path.join(out, key), required=key == "verdict.txt")
add("results/summary.txt", os.path.join(artifacts, "summary.txt"))
for folder, prefix in (("metadata", "results/metadata/"), ("logs", "logs/")):
    directory = os.path.join(artifacts, folder)
    for name in sorted(os.listdir(directory)) if os.path.isdir(directory) else []:
        if name.endswith((".txt", ".log", ".json", ".env")) and os.path.isfile(os.path.join(directory, name)):
            add(prefix + name, os.path.join(directory, name))
app_dir = os.path.join(artifacts, "app")
apps = sorted(n for n in os.listdir(app_dir) if n.endswith((".zip", ".sha256"))) if os.path.isdir(app_dir) else []
for name in apps:
    add("app/" + name, os.path.join(app_dir, name))
if not any(n.endswith(".zip") for n in apps):
    missing.append("app/Proximeet-Debug-iphonesimulator-*.zip")


def walk(node):
    if isinstance(node, dict):
        exported, readable = node.get("exportedFileName"), node.get("suggestedHumanReadableName")
        if exported and readable:
            yield str(exported), str(readable)
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value)


shots, notes, used = {}, [], set()
for folder in ("attachments-walkthrough", "attachments-main", "attachments-b", "attachments-b-keys", "attachments-small"):
    directory = os.path.join(out, folder)
    try:
        pairs = list(walk(json.load(open(os.path.join(directory, "manifest.json")))))
    except (OSError, ValueError):
        pairs = [(n, n) for n in sorted(os.listdir(directory))] if os.path.isdir(directory) else []
    for exported, readable in pairs:
        source = os.path.join(directory, exported)
        extension = os.path.splitext(exported)[1].lower()
        if extension in (".png", ".jpg", ".jpeg", ".txt", ".json") and os.path.isfile(source):
            base = readable.split("_0_")[0]
            safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in base)
            if not safe.lower().endswith(extension):
                safe += extension
            stem, candidate, n = safe[:-len(extension)], safe, 1
            while candidate in used:
                n += 1
                candidate = "%s-%d%s" % (stem, n, extension)
            used.add(candidate)
            name = add("xctest/" + candidate, source)
            if extension in (".png", ".jpg", ".jpeg"):
                shots.setdefault(base, name)
            elif extension == ".txt":
                text = read(source)
                if text.startswith(("Keyboard open (", "Tap at Back's bottom-right corner")):
                    notes.append("%s: %s" % (folder.replace("attachments-", ""), text.strip()))

verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
head = kv(os.path.join(out, "source-checkpoint.txt")).get("git_head", "unknown")
compact_note = kv(os.path.join(out, "compact-video.txt")).get("result", "not produced")
smaller_device = kv(os.path.join(out, "smaller.txt")).get("device", "not run")


def img(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (name, html.escape(caption), html.escape(caption))


def approved(index, caption):
    # The board is 1480 x 1620 at 1x, frames at x 40 / 520 / 1000, y 186; shown at 0.75.
    if not board:
        return '<p class="missing">Approved reference missing.</p>'
    x = [30, 390, 750][index]
    return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -139.5px"></div>'
            '<figcaption>%s</figcaption></figure>') % (board, x, html.escape(caption))


def spec_only(caption):
    return '<figure><div class="crop spec"><p>%s</p></div><figcaption>Approved design</figcaption></figure>' % html.escape(caption)


def shot(key, caption):
    return img(shots.get(key), caption)


def prefixed(prefix):
    return sorted((k, v) for k, v in shots.items() if k.startswith(prefix))


def hero(key, intent):
    # The selected band: 376 x 181 at (32, 338) on the 440 x 956 screen, beside the delivery reference.
    name = shots.get(key)
    left = ('<figure><div class="hero" style="background-image:url(%s)"></div><figcaption>This run: the %s band as drawn '
            '(screen crop 32, 338, 376 x 181)</figcaption></figure>' % (name, intent)) if name else \
        '<p class="missing">%s: not produced in this run.</p>' % intent
    ref_name = deliveries.get(intent)
    right = ('<figure><img class="delivery" src="%s" alt="approved %s delivery"><figcaption>Approved delivery reference '
             '(540 x 260 on RGB 5,6,6)</figcaption></figure>' % (ref_name, intent)) if ref_name else \
        '<p class="missing">Approved %s delivery reference missing.</p>' % intent
    return '<div class="row">%s%s</div>' % (left, right)


def video(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>%s</figcaption>'
            '</figure>') % (name, html.escape(caption))


def row(*cells):
    return '<div class="row">%s</div>' % "".join(cells)


state_rows = "".join([
    row(shot("wristband-empty", "This run (XCTest, real route): no intent; Continue preview disabled"), approved(0, "Approved design: empty")),
    row(shot("wristband-social", "This run: Social, chosen by a real tap"), approved(1, "Approved design: Social")),
    row(shot("wristband-dating", "This run: Dating"), approved(2, "Approved design: Dating")),
    row(shot("wristband-business", "This run: Business"),
        spec_only("Business: on the approved board only as material; its native state is Figma 42:115 (LAYOUT_SPEC.json)")),
    row(shot("wristband-activity", "This run: Activity"),
        spec_only("Activity: on the approved board only as material; its native state is Figma 42:116 (LAYOUT_SPEC.json)")),
])
keyboard_rows = row(*[img(v, "Guest List, keyboard open: " + k.replace("guest-list-keyboard-", "").replace("-", " "))
                      for k, v in prefixed("guest-list-keyboard-done-back-") + prefixed("guest-list-keyboard-back-corner-")])
sections = [
    ("Walkthrough: the real route, all four choices, the chosen tile again, Back to the card, editing, re-entry, end of preview",
     row(video(compact, "Compact walkthrough (%s)" % compact_note), video(original, "Original simulator recording, unedited"))),
    ("The five states beside the approved design", state_rows),
    ("The bands: the approved crop, fitted without stretching", "".join(
        hero("wristband-" + intent, intent) for intent in ("social", "dating", "business", "activity"))),
    ("Route, re-entry and the end of the preview",
     row(shot("wristband-back-card", "Back: the actual Guest List card"),
         shot("wristband-reentry-kept", "Edited introduction, then re-entry: Activity kept"),
         shot("wristband-endpoint", "Continue preview: “End of this preview.” with OK"),
         shot("wristband-after-double-back", "Double tap on Back: the card, once"),
         shot("wristband-after-relaunch-empty", "After relaunch: no intent"),
         shot("wristband-after-all-changes", "After every change between intents"),
         shot("wristband-after-rapid-changes", "Rapid changes: the last choice"),
         shot("wristband-device-turned-portrait-only", "Device turned: portrait only"))),
    ("Reduce Motion (the app's preview flag, not the system setting)",
     row(shot("wristband-reduce-motion-preview-dating", "Preview flag: Dating, in place"))),
    ("Largest accessibility text size (XCTest)",
     row(shot("wristband-largest-text-top", "Header and headline"), shot("wristband-largest-text-choices", "One column of choices"),
         shot("wristband-largest-text-bottom", "Scrolled: privacy line and both actions"))),
    ("Smaller iPhone (%s): supplementary fixture captures, not interactions" % smaller_device,
     row(*[img(fixtures[key], "FIXTURE: " + key[3:-4].replace("-", " ")) for key in fixture_files])),
    ("Guest List keyboard follow-up: Done and Back with the keyboard open (iPhone 17 Pro Max and the smaller iPhone)",
     keyboard_rows + ("<pre>%s</pre>" % html.escape("\n\n".join(notes)) if notes else "")),
    ("Guest List, Pass, Birthday and Welcome regressions",
     row(shot("guest-list-continue-wristband", "Guest List card: Continue preview opens the Wristband"),
         shot("guest-list-card", "Guest List card"), shot("guest-list-after-double-back", "Guest List: double tap on Back"),
         shot("pass-continue-guest-list", "Pass: Continue preview opens the Guest List"),
         shot("birthday-continue-opens-pass", "Birthday's Continue opens Pass"), shot("welcome-default-settled", "Welcome geometry test"))),
]
body = "".join("<h2>%s</h2>%s" % (html.escape(title), content) for title, content in sections)
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Wristband review</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:376px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
img.delivery{width:376px;height:181px}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1215px}
.crop.spec{display:flex;align-items:center;justify-content:center;background:#1b1b1b;color:#aaa;padding:0 20px;box-sizing:border-box}
.hero{width:376px;height:181px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:440px 956px;background-position:-32px -338px}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:780px}</style></head><body>
<h1>Proximeet Wristband: iOS Simulator review</h1>
<p><b>%s</b></p>
<p class="note">Source <code>%s</code>. Real captures from this Codemagic simulator run (iPhone 17 Pro Max, 440 × 956 pt) next
to the unchanged approved design. Screens from XCTest come from real taps and typing; screens marked FIXTURE are
supplementary launches into a prepared state. Alex and Sam are fictional sample data. The intent stays in memory for the
run; choosing one makes no one visible, verifies nothing and grants no permission to approach or message. Automated checks
are not visual approval, which is the founder's decision. The simulator app cannot be installed on an iPhone.</p>
%s
<p class="note">The Reduce Motion screens use the app's preview flag, not the system setting. VoiceOver, composing input,
the system Reduce Motion setting and on-device motion are manual checks.</p>
<h2>Result</h2><pre>%s</pre>
<p>Unsigned simulator app (simulator only): %s</p>
<p>Details: %s</p>
<p class="missing">%s</p>
</body></html>""" % (
    html.escape(headline), html.escape(head), body, html.escape(verdict),
    " ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries if n.startswith("app/") and n.endswith(".zip"))
    or "not produced",
    " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
               if n.startswith(("results/", "logs/")) or (n.startswith("xctest/") and n.endswith((".txt", ".json")))),
    ("Not produced in this run: " + ", ".join(missing)) if missing else "")
os.makedirs(artifacts, exist_ok=True)
with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
    bundle.writestr("Wristband-Review/index.html", page)
    for name, source in entries:
        bundle.write(source, "Wristband-Review/" + name)
print("Wristband-Review.zip: %d files%s" % (len(entries) + 1, ("; missing: " + ", ".join(missing)) if missing else ""))

# The archive's checksum (a zip cannot hold its own) and the small separate downloads.
digest = hashlib.sha256(open(out_zip, "rb").read()).hexdigest()
open(out_zip + ".sha256", "w").write("%s  %s\n" % (digest, os.path.basename(out_zip)))
print("Wristband-Review.zip sha256 %s" % digest)
sources = dict(entries)
try:
    simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
except (OSError, ValueError):
    simulator = {}
readme = ("%s\nProximeet Wristband, source %s. Real iOS Simulator captures from the XCTest runs (real taps and typing, not "
          "fixtures, unless a file name says FIXTURE) on %s, %s. Alex and Sam are fictional sample data; choosing an intent "
          "makes no one visible and verifies nothing. The approved references and the full verdict (results/verdict.txt) "
          "are in Wristband-Review.zip. Automated checks are not visual approval.\n"
          % (headline, head, simulator.get("device_name", "an unrecorded simulator"),
             simulator.get("runtime_name", "an unrecorded runtime")))
screens = [("wristband-empty", "Wristband-1-empty-XCTest.png"),
           ("wristband-social", "Wristband-2-social-XCTest.png"),
           ("wristband-dating", "Wristband-3-dating-XCTest.png"),
           ("wristband-business", "Wristband-4-business-XCTest.png"),
           ("wristband-activity", "Wristband-5-activity-XCTest.png"),
           ("wristband-endpoint", "Wristband-6-end-of-preview-XCTest.png"),
           ("wristband-largest-text-top", "Wristband-7-largest-text-top-XCTest.png"),
           ("wristband-largest-text-choices", "Wristband-8-largest-text-choices-XCTest.png"),
           ("wristband-largest-text-bottom", "Wristband-9-largest-text-bottom-XCTest.png")]
with zipfile.ZipFile(os.path.join(artifacts, "Wristband-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
    bundle.writestr("README.txt", readme)
    for key, target in screens:
        name = shots.get(key)
        if name and name in sources:
            bundle.write(sources[name], target)
        else:
            bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
    for index, key in enumerate(fixture_files, start=10):
        if fixtures.get(key):
            bundle.write(sources[fixtures[key]], "Wristband-%d-smaller-iphone-%s-FIXTURE.png" % (index, key[3:-4].replace("wristband-smaller-", "")))
        else:
            bundle.writestr("Wristband-%d-smaller-iphone-FIXTURE.MISSING.txt" % index, "Not produced in this run.\n")
    keyboard = prefixed("guest-list-keyboard-done-back-") + prefixed("guest-list-keyboard-back-corner-")
    for key, name in keyboard:
        bundle.write(sources[name], "Guest-List-keyboard-%s-XCTest.png" % key.replace("guest-list-keyboard-", ""))
    if not keyboard:
        bundle.writestr("Guest-List-keyboard.MISSING.txt", "Not produced in this run.\n")
    if notes:
        bundle.writestr("Guest-List-keyboard-frames.txt", "\n\n".join(notes) + "\n")
made = ["Wristband-Screens.zip"]
if compact:
    label = ("Compact walkthrough: %s. Half-size re-encode, trimmed to the app by frame brightness. The unedited recording "
             "is in Wristband-walkthrough-original.zip.\n" % compact_note)
    with zipfile.ZipFile(os.path.join(artifacts, "Wristband-walkthrough-compact.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + label)
        bundle.write(sources[compact], "Wristband-walkthrough-compact.mp4")
    shutil.copyfile(sources[compact], os.path.join(artifacts, "Wristband-walkthrough-compact.mp4"))
    made += ["Wristband-walkthrough-compact.zip", "Wristband-walkthrough-compact.mp4"]
if original:
    with zipfile.ZipFile(os.path.join(artifacts, "Wristband-walkthrough-original.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + "The unedited simulator recording of the walkthrough.\n")
        bundle.write(sources[original], "Wristband-walkthrough-original.mp4")
    made.append("Wristband-walkthrough-original.zip")
print("Separate downloads: " + ", ".join(made))
PY
    summary_line "wristband-package" "$(unzip -l "$ARTIFACTS/Wristband-Review.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in Wristband-Review.zip"
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
