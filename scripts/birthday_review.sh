#!/usr/bin/env bash
# Proximeet — runtime review of the approved Birthday (chapter 02) in the iOS Simulator.
# Manual and unsigned. Codemagic workflow: proximeet-birthday-review (codemagic.yaml).
# See docs/verification/birthday-mac-review.md.
#
#   bash scripts/birthday_review.sh <stage>
#
# Stages:
#   checkpoint    source gate. The approved assets (Welcome poses, Manrope fonts and licence,
#                 the Birthday housing, the approved references) must match
#                 docs/verification/birthday-approved-files.sha256, and their provenance hashes
#                 in the handoff records; every other file must match
#                 docs/verification/birthday-review-files.sha256 (which excludes only itself);
#                 no other file may exist; Welcome's deletions stay absent. Optional run input
#                 BIRTHDAY_EXPECTED_COMMIT (full 40-hex SHA) pins HEAD. Runs anywhere.
#   destinations  list installed simulators; report whether iPhone 17 Pro Max was selected
#   captures      supplementary DEBUG-fixture screenshots (labelled as fixtures): empty, adult,
#                 under-18, largest text, and a smaller installed iPhone
#   ui-review     compile the UI test harness; record the real walkthrough test (entry,
#                 correction, Continue, Back); then run the typed-entry test and the Welcome
#                 regression tests. Zero executed tests, or any failure, fails the stage
#   verdict       automated results, kept apart from outstanding manual review
#   package-review  build/artifacts/Birthday-Review.zip with an offline index.html
#   enforce       fail the build unless the verdict says PASS (run last)
#
# Outputs go to build/artifacts/birthday/, logs to build/artifacts/logs/birthday-<stage>.log,
# and PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or
# downloaded, no simulator runtime is installed, and no device is created. Written for the
# macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
OUT="$ARTIFACTS/birthday"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DERIVED_DATA="$ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/birthday-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/birthday-review-files.sha256"
DELETIONS="docs/verification/welcome-review-deletions.txt"
CHECKPOINT_RESULT="$OUT/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
LARGE_CONTENT_SIZE="accessibility-extra-extra-extra-large"
SMALLER_IPHONES="iPhone SE (3rd generation)|iPhone 17e|iPhone 16e|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
WALKTHROUGH="ProximeetUITests/BirthdayReviewTests/testWalkthroughEntryCorrectionContinueBack"
# Tests that must run and pass. Welcome geometry is asserted on the 440 x 956 reference, which
# the primary target provides; Welcome's large-text test may skip if its launch argument has no
# effect, and is reported either way.
REQUIRED_PASSING_TESTS="BirthdayReviewTests.testWalkthroughEntryCorrectionContinueBack BirthdayReviewTests.testTypedEntryPreservesComponentsAndKeyboard WelcomeReviewTests.testHonestNotices WelcomeReviewTests.testReduceMotionPreviewLaunch WelcomeReviewTests.testDefaultGeometry"
WARMUP_SECONDS=15
SETTLE_SECONDS=4
RESTORE_CONTENT_SIZE=""
STATUS_BAR_OVERRIDDEN=""
RECORDER_PID=""
SMALL_BOOTED_UDID=""
LAUNCH_PID=""

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|captures|ui-review|verdict|package-review|enforce) ;;
    *)
        echo "usage: $0 checkpoint|destinations|captures|ui-review|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$OUT"
LOG="$LOGS/birthday-$STAGE.log"
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
    local status=$?
    stop_recorder
    if [ -n "$SMALL_BOOTED_UDID" ]; then
        xcrun simctl shutdown "$SMALL_BOOTED_UDID" >/dev/null 2>&1 || true
        SMALL_BOOTED_UDID=""
    fi
    if [ -n "$RESTORE_CONTENT_SIZE" ]; then
        if ! restore_content_size && [ "$status" -eq 0 ]; then
            status=1
        fi
    fi
    if [ -n "$STATUS_BAR_OVERRIDDEN" ]; then
        xcrun simctl status_bar "$STATUS_BAR_OVERRIDDEN" clear >/dev/null 2>&1 || true
    fi
    if [ "$status" -eq 0 ]; then
        summary_line "birthday-$STAGE" "PASS"
    else
        summary_line "birthday-$STAGE" "FAIL (exit $status), see $LOG"
        echo "birthday_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
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
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/birthday_review.sh checkpoint' first. Nothing is captured for an unverified source."
        return 1
    fi
}

# ---------------------------------------------------------------------------------------
# checkpoint
# ---------------------------------------------------------------------------------------

stage_checkpoint() {
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

# Provenance: the approved assets must also equal the hashes recorded in the handoff records.
# The Birthday handoff's SHA256SUMS.txt covers the housing, the Manrope faces and the licence;
# Welcome's FONT_SOURCE.json must agree for the faces the app bundles.
assets = "Proximeet/Resources/Assets.xcassets/"
provenance, bundled = {}, ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")
try:
    handoff = dict(reversed(line.strip().split("  ", 1)) for line in
                   open("docs/design/birthday-approved/SHA256SUMS.txt") if line.strip())
    provenance[assets + "BirthdayHousing.imageset/birthday-housing.png"] = handoff["assets/birthday-housing.png"]
    provenance[assets + "Manrope-OFL.dataset/OFL.txt"] = handoff["fonts/OFL.txt"]
    fonts = {f["file"]: f["sha256"] for f in json.load(open("docs/design/welcome-approved/FONT_SOURCE.json"))["fonts"]}
    for face in bundled:
        name = "Manrope-%s.ttf" % face
        provenance[assets + "Manrope-%s.dataset/%s" % (face, name)] = handoff["fonts/" + name]
        if fonts.get(name) != handoff["fonts/" + name]:
            problems.append("Welcome and Birthday font records disagree  " + name)
except (OSError, ValueError, KeyError) as error:
    problems.append("provenance records unreadable: %r" % (error,))
for name, digest in sorted(provenance.items()):
    if name not in frozen:
        problems.append("approved asset not in the frozen manifest  " + name)
    elif os.path.isfile(name) and sha256(name) != digest:
        problems.append("differs from the approved handoff  " + name)

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
                problems.append("present        " + name + " (Welcome deleted it)")
            else:
                absent += 1

head = git("rev-parse", "HEAD") or "unavailable"
pin = os.environ.get("BIRTHDAY_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("BIRTHDAY_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but BIRTHDAY_EXPECTED_COMMIT is %s" % (head, pin))

lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("BIRTHDAY_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
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
    print("This checkout is not the reviewed Birthday revision. Do not review it as such.")
    sys.exit(1)
PY
    summary_line "birthday-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/birthday-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/birthday-runtimes-available.json"
    run python3 - "$META/birthday-devices-available.json" "$META/birthday-runtimes-available.json" \
        "$SIM_UDID" "$PRIMARY_TARGET" "$OUT/destination.txt" <<'PY'
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
}

# ---------------------------------------------------------------------------------------
# captures (supplementary DEBUG fixtures)
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

# fixture <file> <fixture name> <label>: relaunch on a fixture and capture after it settles.
fixture() {
    local file="$1" name="$2" label="$3"
    launch "$SIM_UDID" -ProximeetFixture "$name" || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$SIM_UDID" "$file" "FIXTURE (-ProximeetFixture $name): $label"
}

read_content_size() {
    local raw size
    raw="$(xcrun simctl ui "$SIM_UDID" content_size 2>&1)" || return 1
    size="$(printf '%s\n' "$raw" | tail -n 1 | awk '{ print $NF }')"
    case "$size" in
        extra-small|small|medium|large|extra-large|extra-extra-large|extra-extra-extra-large) ;;
        accessibility-medium|accessibility-large|accessibility-extra-large) ;;
        accessibility-extra-extra-large|accessibility-extra-extra-extra-large) ;;
        *) return 1 ;;
    esac
    printf '%s\n' "$size"
}

restore_content_size() {
    local wanted="$RESTORE_CONTENT_SIZE" actual
    [ -n "$wanted" ] || return 0
    RESTORE_CONTENT_SIZE=""
    run xcrun simctl ui "$SIM_UDID" content_size "$wanted" || return 1
    actual="$(read_content_size)" || actual="unreadable"
    note "Simulator text size after restore: '$actual' (expected '$wanted')."
    [ "$actual" = "$wanted" ]
}

capture_large_text() {
    local original
    original="$(read_content_size)" || { note "simctl could not report the current text size; not changed."; return 2; }
    RESTORE_CONTENT_SIZE="$original"
    run xcrun simctl ui "$SIM_UDID" content_size "$LARGE_CONTENT_SIZE" || return 1
    fixture 04-birthday-largest-text.png birthday-adult \
        "simctl content_size $LARGE_CONTENT_SIZE (undocumented command; unverified until the text is seen to grow)" || return 1
    restore_content_size
}

smaller_iphone() {
    xcrun simctl list -j devices available > "$META/birthday-simctl-devices.json"
    python3 - "$META/birthday-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
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

capture_smaller() {
    local smaller udid name
    smaller="$(smaller_iphone)"
    if [ -z "$smaller" ]; then
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        return 2
    fi
    udid="$(printf '%s' "$smaller" | cut -f1)"
    name="$(printf '%s' "$smaller" | cut -f2)"
    note "Smaller iPhone: $name ($udid)."
    if ! xcrun simctl list devices booted | grep -q "$udid"; then
        run xcrun simctl boot "$udid" || return 1
        SMALL_BOOTED_UDID="$udid"
    fi
    run xcrun simctl bootstatus "$udid" -b || return 1
    run xcrun simctl install "$udid" "$APP_PATH" || return 1
    launch "$udid" -ProximeetFixture birthday-adult || return 1
    sleep "$WARMUP_SECONDS"
    launch "$udid" -ProximeetFixture birthday-adult || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "05-birthday-smaller-iphone.png" "FIXTURE (-ProximeetFixture birthday-adult): $name" || return 1
    if [ -n "$SMALL_BOOTED_UDID" ]; then
        run xcrun simctl shutdown "$udid" || true
        SMALL_BOOTED_UDID=""
    fi
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

stage_captures() {
    require_checkpoint_match
    load_simulator
    check_app
    run xcrun simctl bootstatus "$SIM_UDID" -b
    run xcrun simctl install "$SIM_UDID" "$APP_PATH"
    rm -f "$OUT"/0*-birthday-*.png
    printf 'file\tsimulator\tcaptured_utc\tpixel_width\tpixel_height\tsha256\tnote\n' > "$OUT/captures.tsv"
    if run xcrun simctl status_bar "$SIM_UDID" override --time 9:41 --batteryState charged \
        --batteryLevel 100 --cellularBars 4; then
        STATUS_BAR_OVERRIDDEN="$SIM_UDID"
    else
        note "NOTE: status bar override unavailable; captures show the live status bar."
    fi
    note "Warmup launch (not captured), ${WARMUP_SECONDS}s."
    launch "$SIM_UDID" -ProximeetFixture welcome
    sleep "$WARMUP_SECONDS"
    guarded birthday-fix-empty fixture 01-birthday-empty.png birthday "fresh Birthday, DD / MMM / YYYY"
    guarded birthday-fix-adult fixture 02-birthday-adult.png birthday-adult "12 May 1997 entered and checked"
    guarded birthday-fix-under18 fixture 03-birthday-under18.png birthday-under18 "12 May 2012 entered and checked"
    guarded birthday-fix-largetext capture_large_text
    guarded birthday-fix-smaller capture_smaller
    run cat "$OUT/captures.tsv"
}

# ---------------------------------------------------------------------------------------
# ui-review
# ---------------------------------------------------------------------------------------

# export_results <xcresult> <attachments dir>
export_results() {
    local result="$1" dir="$2"
    [ -d "$result" ] || return 0
    ditto -c -k --sequesterRsrc --keepParent "$result" "$result.zip" || true
    xcrun xcresulttool get test-results summary --path "$result" > "${result%.xcresult}-summary.json" 2>>"$LOG" || true
    if xcrun xcresulttool export attachments --path "$result" --output-path "$dir" >> "$LOG" 2>&1; then
        note "Exported XCTest attachments to $dir."
    else
        note "NOTE: attachment export unavailable for $result; use the .xcresult.zip."
    fi
}

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    local build_status walk_status rest_status waited=0
    local movie="$OUT/birthday-interaction.mp4"
    local walk_result="$OUT/BirthdayWalkthrough.xcresult" rest_result="$OUT/BirthdayReview.xcresult"
    rm -rf "$walk_result" "$rest_result" "$walk_result.zip" "$rest_result.zip" "$movie" "$movie.log"
    export NSUnbufferedIO=YES

    # 1. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests/BirthdayReviewTests -only-testing:ProximeetUITests/WelcomeReviewTests \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "birthday-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "birthday-ui-build" "PASS (UI test harness compiled)"

    # 2. The recorded walkthrough: the recorder is confirmed active before the test starts.
    #    The app is closed first, so the movie does not open on the last fixture screen.
    run xcrun simctl bootstatus "$SIM_UDID" -b || true
    run xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
    xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 --force "$movie" > "$movie.log" 2>&1 &
    RECORDER_PID=$!
    while ! grep -q "Recording started" "$movie.log" 2>/dev/null && [ "$waited" -lt 20 ]; do
        kill -0 "$RECORDER_PID" 2>/dev/null || break
        sleep 0.5
        waited=$((waited + 1))
    done
    if grep -q "Recording started" "$movie.log" 2>/dev/null; then
        summary_line "birthday-recording" "confirmed active before the walkthrough"
    else
        note "WARNING: simctl did not confirm 'Recording started'; the walkthrough still runs, unrecorded evidence is labelled."
        summary_line "birthday-recording" "NOT CONFIRMED"
        stop_recorder
        rm -f "$movie"
    fi
    if run env TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"$WALKTHROUGH" -parallel-testing-enabled NO -resultBundlePath "$walk_result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
        walk_status=0
    else
        walk_status=$?
    fi
    stop_recorder
    if [ -s "$movie" ]; then
        shasum -a 256 "$movie" > "$movie.sha256"
    fi
    export_results "$walk_result" "$OUT/attachments-walkthrough"

    # 3. The typed-entry test and the Welcome regression tests.
    if run env TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests/BirthdayReviewTests/testTypedEntryPreservesComponentsAndKeyboard \
        -only-testing:ProximeetUITests/WelcomeReviewTests \
        -parallel-testing-enabled NO -resultBundlePath "$rest_result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
        rest_status=0
    else
        rest_status=$?
    fi
    export_results "$rest_result" "$OUT/attachments-review"

    # 4. What actually ran, from xcodebuild's per-test lines (to a file: bash 3.2 misparses
    #    heredocs inside $( )).
    python3 - "$LOG" "$REQUIRED_PASSING_TESTS" "$OUT/ui-review-tests.txt" "$walk_status" "$rest_status" \
        > "$OUT/ui-review-counts.txt" <<'PY'
import re
import sys

log, required, out_path = sys.argv[1], sys.argv[2].split(), sys.argv[3]
exits = [int(sys.argv[4]), int(sys.argv[5])]
outcome = {}
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?(WelcomeReviewTests|BirthdayReviewTests)[ ./](test\w+)(?:\(\))?\]?' (passed|failed|skipped)")
flags = {"welcome": False, "birthday": False}
for line in open(log, encoding="utf-8", errors="replace"):
    match = pattern.search(line)
    if match:
        outcome["%s.%s" % (match.group(1), match.group(2))] = match.group(3)
    if "WELCOME_REVIEW_FLAG_SEEN" in line:
        flags["welcome"] = True
    if "BIRTHDAY_REVIEW_FLAG_SEEN" in line:
        flags["birthday"] = True
counts = {k: sum(1 for v in outcome.values() if v == k) for k in ("passed", "failed", "skipped")}
executed = counts["passed"] + counts["failed"]
missing = [name for name in required if outcome.get(name) != "passed"]
ok = all(e == 0 for e in exits) and executed > 0 and counts["failed"] == 0 and not missing
lines = ["%s=%s" % item for item in sorted(outcome.items())]
lines += ["discovered=%d" % len(outcome), "executed=%d" % executed,
          "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
          "required_passed=" + ("yes" if not missing else "no (" + ", ".join(missing) + ")"),
          "flag_markers_in_log=welcome:%s birthday:%s" % (flags["welcome"], flags["birthday"]),
          "xcodebuild_exit_walkthrough=%d" % exits[0], "xcodebuild_exit_review=%d" % exits[1],
          "result=" + ("PASS" if ok else "FAIL")]
open(out_path, "w").write("\n".join(lines) + "\n")
print("executed %d of %d discovered (passed %d, failed %d, skipped %d); required passed: %s; exits %d/%d; %s"
      % (executed, len(outcome), counts["passed"], counts["failed"], counts["skipped"],
         "yes" if not missing else "no", exits[0], exits[1], "PASS" if ok else "FAIL"))
PY
    run cat "$OUT/ui-review-tests.txt"
    summary_line "birthday-ui-run" "$(cat "$OUT/ui-review-counts.txt")"
    grep -qx 'result=PASS' "$OUT/ui-review-tests.txt"
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
simulator = json.load(open(os.path.join(meta, "simulator.json"))) if os.path.isfile(os.path.join(meta, "simulator.json")) else {}
dims = []
if os.path.isfile(os.path.join(out, "captures.tsv")):
    for row in list(open(os.path.join(out, "captures.tsv")))[1:]:
        cells = row.rstrip("\n").split("\t")
        if len(cells) > 4 and cells[3]:
            dims.append("%s %sx%s" % (cells[0], cells[3], cells[4]))
movie = os.path.join(out, "birthday-interaction.mp4")
required = {
    "source gate (exact reviewed revision, approved assets)": source.get("result") == "MATCH",
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target") == "iPhone 17 Pro Max"
        and destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "domain tests on the Mac (swift test)": passed("domain-tests"),
    "test-harness compilation (build-for-testing)": passed("birthday-ui-build"),
    "UI tests executed and passed (Birthday walkthrough, typed entry, Welcome regression)": tests.get("result") == "PASS",
    "interaction recording confirmed and saved": last.get("birthday-recording", "").startswith("confirmed")
        and os.path.isfile(movie) and os.path.getsize(movie) > 0,
}
lines = [
    "Birthday review verdict (automated results only; manual review is listed separately)",
    "",
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"), tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"), simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"), destination.get("selected", "?")),
    "Images      " + ("; ".join(dims) if dims else "none recorded"),
    "",
    "Required automated results:",
]
lines += ["  %-86s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += ["    XCTest detail: executed %s, passed %s, failed %s, skipped %s; %s" % (
    tests.get("executed", "?"), tests.get("passed", "?"), tests.get("failed", "?"), tests.get("skipped", "?"),
    tests.get("flag_markers_in_log", "?"))]
lines += ["    " + line.strip() for line in open(os.path.join(out, "ui-review-tests.txt"))
          if line.startswith(("BirthdayReviewTests.", "WelcomeReviewTests."))] if os.path.isfile(os.path.join(out, "ui-review-tests.txt")) else []
lines += [
    "",
    "Supplementary DEBUG-fixture captures (reported, not required; not interactions):",
    "  empty %s | adult %s | under-18 %s" % (status("birthday-fix-empty"), status("birthday-fix-adult"), status("birthday-fix-under18")),
    "  largest text via simctl content_size (undocumented; UNVERIFIED until seen): " + status("birthday-fix-largetext"),
    "  smaller iPhone: " + status("birthday-fix-smaller"),
    "  unsigned simulator app zip: " + status("package"),
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/birthday-approved/reference (the founder decides)",
    "  VoiceOver: wheel adjustment, announcements and reading order",
    "  system Settings > Accessibility > Reduce Motion and larger text on a device",
    "  29 February: the 1 March policy needs product confirmation before production",
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
    run python3 - "$ROOT" "$OUT" "$ARTIFACTS/Birthday-Review.zip" <<'PY'
import html
import json
import os
import sys
import zipfile

root, out, out_zip = sys.argv[1:4]
ref = os.path.join(root, "docs/design/birthday-approved/reference")
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


board = add("approved/birthday-review.png", os.path.join(ref, "birthday-review.png"))
add("approved/birthday-housing-delivery.jpg", os.path.join(ref, "birthday-housing-delivery.jpg"), required=False)
video = add("captures/birthday-interaction.mp4", os.path.join(out, "birthday-interaction.mp4"))
fixtures = {key: add("fixtures/" + key, os.path.join(out, key), required=False) for key in (
    "01-birthday-empty.png", "02-birthday-adult.png", "03-birthday-under18.png",
    "04-birthday-largest-text.png", "05-birthday-smaller-iphone.png")}
for key in ("verdict.txt", "ui-review-tests.txt", "destination.txt", "source-checkpoint.txt", "captures.tsv",
            "BirthdayWalkthrough-summary.json", "BirthdayReview-summary.json"):
    add("results/" + key, os.path.join(out, key), required=key == "verdict.txt")
for key in ("BirthdayWalkthrough.xcresult.zip", "BirthdayReview.xcresult.zip"):
    add("results/" + key, os.path.join(out, key))
artifacts = os.path.dirname(out)
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


shots, used = {}, set()
for folder in ("attachments-walkthrough", "attachments-review"):
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
            # Several attachments share a name (every "note"); keep each one.
            stem, candidate, n = safe[:-len(extension)], safe, 1
            while candidate in used:
                n += 1
                candidate = "%s-%d%s" % (stem, n, extension)
            used.add(candidate)
            name = add("xctest/" + candidate, source)
            if extension in (".png", ".jpg", ".jpeg"):
                shots[base] = name

verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")


def img(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (name, html.escape(caption), html.escape(caption))


def approved(index, caption):
    if not board:
        return '<p class="missing">Approved reference missing.</p>'
    x = [24, 390, 756][index]
    return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -123px"></div>'
            '<figcaption>%s</figcaption></figure>') % (board, x, html.escape(caption))


def shot(key, caption):
    return img(shots.get(key), caption)


states = [
    ("birthday-empty", 0, "Empty: DD / MMM / YYYY, Continue disabled"),
    ("birthday-adult", 1, "Adult: 12 May 1997 on the wheels, Continue enabled"),
    ("birthday-under18", 2, "Under 18: corrected to 2012, Continue disabled"),
]
state_rows = "".join('<div class="row">%s%s</div>' % (shot(key, "This run (XCTest, real interaction): " + caption),
                                                     approved(index, "Approved design")) for key, index, caption in states)
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Birthday review</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:330px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1002px}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:780px}</style></head><body>
<h1>Proximeet Birthday: iOS Simulator review</h1>
<p><b>%s</b></p>
<p class="note">Real captures from this Codemagic simulator run next to the approved design. Screens marked XCTest come from
real taps and wheel adjustments; screens marked FIXTURE are supplementary launches into a prepared state. Automated checks
are not visual approval: judging the look is the founder's decision. The simulator app is not installable on a physical
iPhone.</p>
<h2>Interaction recording: route, wheel entry, Continue, correction, Back</h2><div class="row">%s</div>
<h2>States beside the approved design</h2>%s
<h2>One component chosen: the day alone, month and year still unset</h2><div class="row">%s</div>
<h2>Continue, Back and the kept draft</h2><div class="row">%s%s%s%s</div>
<h2>Typed entry (Enter date instead)</h2><div class="row">%s%s%s%s</div>
<h2>Welcome with the new demo choice</h2><div class="row">%s%s</div>
<h2>Supplementary fixture captures (not interactions)</h2><div class="row">%s%s%s%s%s</div>
<p class="note">The largest-text capture uses an undocumented simulator command and is unverified until the text is seen to
grow. VoiceOver and system accessibility settings are manual checks.</p>
<h2>Result</h2><pre>%s</pre>
<p>Source: <code>%s</code> (unsigned Debug simulator app: %s)</p>
<p>Details: %s</p>
<p class="missing">%s</p>
</body></html>""" % (
    html.escape(headline),
    ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>XCTest walkthrough, '
     'recorded on the simulator</figcaption></figure>' % video) if video else '<p class="missing">Recording not produced.</p>',
    state_rows,
    shot("birthday-day-only", "This run (XCTest): day set to 12; month and year stay unset, Continue disabled"),
    shot("birthday-pass-notice", "Continue: “Pass is next. This prototype stops here for now.”"),
    shot("back-to-welcome", "Back: settled Welcome"),
    shot("birthday-returned-draft-kept", "Returned: the draft is kept"),
    shot("more-options-choice", "More options: Continue the demo (no account) or Cancel"),
    shot("birthday-typed-keyboard", "Typed entry with the keyboard, before Done"),
    shot("birthday-typed-adult", "After Done: checked, Continue enabled"),
    shot("birthday-typed-impossible", "31 April refused"),
    shot("birthday-typed-future", "A future year refused"),
    shot("notice-continue-with-apple", "Continue with Apple: honest notice (unchanged)"),
    shot("welcome-default-settled", "Welcome geometry test"),
    img(fixtures["01-birthday-empty.png"], "FIXTURE: empty"),
    img(fixtures["02-birthday-adult.png"], "FIXTURE: adult"),
    img(fixtures["03-birthday-under18.png"], "FIXTURE: under 18"),
    img(fixtures["04-birthday-largest-text.png"], "FIXTURE: largest text (unverified command)"),
    img(fixtures["05-birthday-smaller-iphone.png"], "FIXTURE: smaller iPhone"),
    html.escape(verdict),
    html.escape(next((l.split("=", 1)[1] for l in read(os.path.join(out, "source-checkpoint.txt")).splitlines()
                      if l.startswith("git_head=")), "unknown")),
    " ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries if n.startswith("app/") and n.endswith(".zip"))
    or "not produced",
    " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
               if n.startswith(("results/", "logs/")) or (n.startswith("xctest/") and n.endswith((".txt", ".json")))),
    ("Not produced in this run: " + ", ".join(missing)) if missing else "")
os.makedirs(os.path.dirname(out_zip), exist_ok=True)
with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
    bundle.writestr("Birthday-Review/index.html", page)
    for name, source in entries:
        bundle.write(source, "Birthday-Review/" + name)
print("Birthday-Review.zip: %d files%s" % (len(entries) + 1, ("; missing: " + ", ".join(missing)) if missing else ""))

# The archive's checksum (a zip cannot hold its own), and small separate downloads of the three
# approved states and the walkthrough, so they can be reviewed without the large bundle.
import hashlib
artifacts = os.path.dirname(out_zip)
digest = hashlib.sha256(open(out_zip, "rb").read()).hexdigest()
open(out_zip + ".sha256", "w").write("%s  %s\n" % (digest, os.path.basename(out_zip)))
print("Birthday-Review.zip sha256 %s" % digest)
sources = dict(entries)
head = next((l.split("=", 1)[1] for l in read(os.path.join(out, "source-checkpoint.txt")).splitlines()
             if l.startswith("git_head=")), "unknown")
try:
    simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
except (OSError, ValueError):
    simulator = {}
readme = ("%s\nProximeet Birthday, source %s. Real iOS Simulator captures from the XCTest walkthrough (real taps and "
          "wheel adjustments, not fixtures) on %s, %s. The approved references and the full verdict "
          "(results/verdict.txt) are in Birthday-Review.zip. Automated checks are not visual approval.\n"
          % (headline, head, simulator.get("device_name", "an unrecorded simulator"),
             simulator.get("runtime_name", "an unrecorded runtime")))
screens = [("xctest/birthday-empty.png", "Birthday-1-empty-XCTest.png"),
           ("xctest/birthday-adult.png", "Birthday-2-adult-12-May-1997-XCTest.png"),
           ("xctest/birthday-under18.png", "Birthday-3-under-18-12-May-2012-XCTest.png")]
with zipfile.ZipFile(os.path.join(artifacts, "Birthday-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
    bundle.writestr("README.txt", readme)
    for name, target in screens:
        if name in sources:
            bundle.write(sources[name], target)
        else:
            bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
if "captures/birthday-interaction.mp4" in sources:
    with zipfile.ZipFile(os.path.join(artifacts, "Birthday-Walkthrough.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme.replace("captures from", "screen recording of"))
        bundle.write(sources["captures/birthday-interaction.mp4"], "Birthday-walkthrough-XCTest.mp4")
    print("Separate downloads: Birthday-Screens.zip, Birthday-Walkthrough.zip")
else:
    print("Separate downloads: Birthday-Screens.zip (Birthday-Walkthrough.zip not produced: no recording)")
PY
    summary_line "birthday-package" "$(unzip -l "$ARTIFACTS/Birthday-Review.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in Birthday-Review.zip"
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
    captures) stage_captures ;;
    ui-review) stage_ui_review ;;
    verdict) stage_verdict ;;
    package-review) stage_package_review ;;
    enforce) stage_enforce ;;
esac
