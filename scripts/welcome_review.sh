#!/usr/bin/env bash
# Proximeet — runtime review of the approved Welcome (chapter 01) in the iOS Simulator.
# Manual and unsigned. Codemagic workflow: proximeet-welcome-review (codemagic.yaml).
# See docs/verification/welcome-mac-review.md.
#
#   bash scripts/welcome_review.sh <stage>
#
# Stages:
#   checkpoint    source gate. The whole checkout must be exactly the reviewed revision:
#                 the frozen Welcome app, project, package and approved references
#                 (docs/verification/welcome-approved-files.sha256) plus every other tracked
#                 file (docs/verification/welcome-review-files.sha256, which excludes only
#                 itself); no other file; the Welcome deletions absent. Optional run input
#                 WELCOME_EXPECTED_COMMIT (full 40-hex SHA) pins HEAD as well. Runs anywhere.
#   destinations  list installed simulator destinations; report whether the primary target,
#                 iPhone 17 Pro Max, was available and selected
#   captures      launch recording (the recorder is confirmed active before a cold launch),
#                 settled screenshot, Reduce Motion preview, largest text, a smaller iPhone
#   ui-review     compile the UI test harness, then run only WelcomeReviewTests with the review
#                 flag set for the test runner; zero executed tests is a failure
#   verdict       one summary that keeps app compilation, test-harness compilation, runtime
#                 assertions, captures and outstanding manual checks apart; exits non-zero if a
#                 required automated result failed or never ran
#   package-review  build/artifacts/Welcome-Review.zip: the real captures, the approved
#                 references, the verdict and an offline index.html viewer
#   enforce       fail the build unless the verdict says PASS (run last, after packaging)
#
# Outputs go to build/artifacts/welcome/, logs to build/artifacts/logs/welcome-<stage>.log,
# and PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or
# downloaded, no simulator runtime is installed, and no device is created. Written for the
# macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
WELCOME="$ARTIFACTS/welcome"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DERIVED_DATA="$ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/welcome-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/welcome-review-files.sha256"
DELETIONS="docs/verification/welcome-review-deletions.txt"
CHECKPOINT_RESULT="$WELCOME/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
LARGE_CONTENT_SIZE="accessibility-extra-extra-extra-large"
# Smaller iPhones to try, in order, on the same runtime as the main simulator. Only
# already-installed simulators are used. Codemagic's Xcode 26.6 image lists iPhone 17,
# 17 Pro, 17 Pro Max, 17e and Air (docs.codemagic.io/specs-macos/xcode-26-6, 2026-09-25), so
# there it is iPhone 17e; a local Mac may also have an iPhone SE.
SMALLER_IPHONES="iPhone SE (3rd generation)|iPhone 17e|iPhone 16e|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
TEST_SELECTION="ProximeetUITests/WelcomeReviewTests"
# Notices and the Reduce Motion preview must pass on any iPhone. Geometry is asserted only on
# the 440 x 956 reference and large text only when its launch argument takes effect; those may
# skip, and the summary shows every skip. A skip is never a pass.
REQUIRED_PASSING_TESTS="testHonestNotices testReduceMotionPreviewLaunch"
WARMUP_SECONDS=15
RECORD_SECONDS=6
SETTLE_SECONDS=5
# Cleanup state for finish(): anything still set on exit is undone there.
RESTORE_CONTENT_SIZE=""
STATUS_BAR_OVERRIDDEN=""
RECORDER_PID=""
SMALL_BOOTED_UDID=""
LAUNCH_PID=""
PRIMARY_CAPTURE_FAILED=""

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|captures|ui-review|verdict|package-review|enforce) ;;
    *)
        echo "usage: $0 checkpoint|destinations|captures|ui-review|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$WELCOME"
LOG="$LOGS/welcome-$STAGE.log"
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

# simctl finalises the movie on SIGINT (Xcode 12.3 notes). Bounded: if the recorder has not
# exited within 15 s it is terminated, so a stuck recorder cannot hang the build.
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
        summary_line "welcome-$STAGE" "PASS"
    else
        summary_line "welcome-$STAGE" "FAIL (exit $status), see $LOG"
        echo "welcome_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
    fi
    exit "$status"
}
trap finish EXIT
# A stage stopped by a signal (e.g. the build's time limit) must be recorded as failed.
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

# Captures and the XCTest review describe the reviewed revision only.
require_checkpoint_match() {
    if ! grep -qx 'result=MATCH' "$CHECKPOINT_RESULT" 2>/dev/null; then
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/welcome_review.sh checkpoint' on this checkout first. Nothing is captured for an unverified source."
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
import os
import re
import subprocess
import sys

frozen_path, review_path, deletions, out_path = sys.argv[1:5]
# The approved application, project, package and design references: frozen since the
# Welcome commit. Every file under these roots must be listed in the frozen manifest.
FROZEN_ROOTS = ("Proximeet/", "Proximeet.xcodeproj/", "ProximeetDomain/", "docs/design/welcome-approved/")


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
for name in sorted(frozen):
    if not name.startswith(FROZEN_ROOTS):
        problems.append("frozen entry outside the frozen roots   " + name)
for name in sorted(review):
    if name.startswith(FROZEN_ROOTS):
        problems.append("frozen-root file in the review manifest   " + name)
expected = dict(review, **frozen)
for name, digest in sorted(expected.items()):
    if not os.path.isfile(name):
        problems.append("missing        " + name)
    elif sha256(name) != digest:
        problems.append(("changed (frozen Welcome file)  " if name in frozen else "differs        ") + name)

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
                problems.append("present        " + name + " (the Welcome change deletes it)")
            else:
                absent += 1

head = git("rev-parse", "HEAD") or "unavailable"
pin = os.environ.get("WELCOME_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("WELCOME_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but WELCOME_EXPECTED_COMMIT is %s" % (head, pin))

status = git("status", "--porcelain") or ""
lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("WELCOME_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
    "git_status_porcelain_lines=%d" % len([l for l in status.splitlines() if l]),
    "frozen_manifest_sha256=" + sha256(frozen_path),
    "review_manifest_sha256=" + sha256(review_path),
    "codemagic_yaml_sha256=" + (sha256("codemagic.yaml") if os.path.isfile("codemagic.yaml") else "absent"),
    "frozen_files_checked=%d" % len(frozen),
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
    print("This checkout is not the reviewed Welcome revision. Do not review it as such.")
    sys.exit(1)
PY
    summary_line "welcome-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/welcome-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/welcome-runtimes-available.json"
    run xcodebuild -showdestinations -project Proximeet.xcodeproj -scheme Proximeet \
        || note "NOTE: xcodebuild -showdestinations failed; the simctl list above still stands."
    run python3 - "$META/welcome-devices-available.json" "$META/welcome-runtimes-available.json" \
        "$SIM_UDID" "$PRIMARY_TARGET" "$WELCOME/destination.txt" <<'PY'
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
# captures
# ---------------------------------------------------------------------------------------

# launch <udid> <launch arguments...>: relaunch the app and set LAUNCH_PID from simctl.
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

# The app launched last must still be running, or a capture could show a post-crash screen.
require_alive() {
    if ! ps -p "$LAUNCH_PID" >/dev/null 2>&1; then
        note "ERROR: the app process $LAUNCH_PID is not running; the capture would not show the app."
        return 1
    fi
}

# screenshot <udid> <file name> <note>. Explicit returns throughout: the capture functions run
# where errexit is off (each capture is guarded so one failure does not stop the others).
screenshot() {
    local udid="$1" name="$2" label="$3" png width height digest
    png="$WELCOME/$name"
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
        "$label" >> "$WELCOME/captures.tsv"
}

# record_launch <file name> <seconds> <launch arguments...>: terminate any running instance,
# start the recorder, wait until simctl confirms it is recording, then cold-launch the app, so
# the recording holds the home screen, the launch and the whole pose study.
record_launch() {
    local name="$1" seconds="$2" movie waited=0
    shift 2
    movie="$WELCOME/$name"
    rm -f "$movie" "$movie.log"
    run xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
    sleep 2
    xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 --force "$movie" > "$movie.log" 2>&1 &
    RECORDER_PID=$!
    # simctl reports "Recording started" once the first frame is queued (Xcode 12.3 notes).
    while ! grep -q "Recording started" "$movie.log" 2>/dev/null && [ "$waited" -lt 20 ]; do
        if ! kill -0 "$RECORDER_PID" 2>/dev/null; then
            note "ERROR: the simulator recorder exited before recording; see $movie.log."
            RECORDER_PID=""
            return 1
        fi
        sleep 0.5
        waited=$((waited + 1))
    done
    if ! grep -q "Recording started" "$movie.log" 2>/dev/null; then
        note "ERROR: simctl never confirmed 'Recording started' within 10 s; not launching into an unconfirmed recording."
        stop_recorder
        rm -f "$movie"
        return 1
    fi
    sleep 1
    launch "$SIM_UDID" ${1+"$@"} || return 1
    sleep "$seconds"
    require_alive || return 1
    stop_recorder
    if [ ! -s "$movie" ]; then
        note "ERROR: $movie is missing or empty."
        return 1
    fi
    shasum -a 256 "$movie" > "$movie.sha256"
    printf '%s\t%s\t%s\t\t\t%s\t%s\n' "$name" "$SIM_UDID" "$(utc_now)" \
        "$(awk '{ print $1 }' "$movie.sha256")" "recording confirmed active before cold launch: $* (${seconds}s after launch)" \
        >> "$WELCOME/captures.tsv"
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

# Prints "udid<TAB>name" for the first installed smaller iPhone on the main runtime, or nothing.
smaller_iphone() {
    xcrun simctl list -j devices available > "$META/welcome-simctl-devices.json"
    python3 - "$META/welcome-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
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

capture_motion() {
    record_launch welcome-motion.mp4 "$RECORD_SECONDS" -ProximeetFixture welcome || return 1
    screenshot "$SIM_UDID" 01-welcome-settled.png "settled, ${RECORD_SECONDS}s after launch"
}

# App-level Reduce Motion preview only; the system setting is a manual check. The movie is the
# evidence; the screenshot, taken seconds later, only shows the settled layout.
capture_reduce_motion_preview() {
    record_launch welcome-reduce-motion.mp4 4 -ProximeetFixture welcome -ProximeetReduceMotionPreview YES || return 1
    screenshot "$SIM_UDID" 02-welcome-preview-flag-settled-layout.png \
        "-ProximeetReduceMotionPreview YES, 4 s after launch; layout only, not Reduce Motion evidence"
}

# Uses the undocumented `simctl ui content_size`; the result is unverified until a person
# checks that the screenshot's text actually grew.
capture_large_text() {
    local original
    original="$(read_content_size)" || { note "simctl could not report the current text size; not changed."; return 2; }
    RESTORE_CONTENT_SIZE="$original"
    run xcrun simctl ui "$SIM_UDID" content_size "$LARGE_CONTENT_SIZE" || return 1
    launch "$SIM_UDID" -ProximeetFixture welcome || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$SIM_UDID" 03-welcome-largest-text-top.png \
        "simctl content_size $LARGE_CONTENT_SIZE (undocumented command; unverified until the text is seen to grow)" || return 1
    restore_content_size
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
    launch "$udid" -ProximeetFixture welcome || return 1
    sleep "$WARMUP_SECONDS"
    launch "$udid" -ProximeetFixture welcome || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "04-welcome-smaller-iphone.png" "$name, settled" || return 1
    if [ -n "$SMALL_BOOTED_UDID" ]; then
        run xcrun simctl shutdown "$udid" || true
        SMALL_BOOTED_UDID=""
    fi
}

# guarded <summary label> <function>: run one capture; record PASS, FAIL or SKIPPED (exit 2).
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
        *) summary_line "$label" "FAIL, see $LOG"
           [ "$label" != welcome-cap-motion ] || PRIMARY_CAPTURE_FAILED="yes" ;;
    esac
    return 0
}

stage_captures() {
    require_checkpoint_match
    load_simulator
    check_app
    run xcrun simctl bootstatus "$SIM_UDID" -b
    run xcrun simctl install "$SIM_UDID" "$APP_PATH"
    # Never let a file from an earlier run stand in for this run's evidence.
    rm -f "$WELCOME"/0*-welcome-*.png "$WELCOME"/welcome-motion.mp4* "$WELCOME"/welcome-reduce-motion.mp4*
    printf 'file\tsimulator\tcaptured_utc\tpixel_width\tpixel_height\tsha256\tnote\n' > "$WELCOME/captures.tsv"
    # Same status bar in every capture, so screenshots are comparable. Optional. Flags as
    # documented in Apple's Xcode 11 notes and WWDC20 session 10647.
    if run xcrun simctl status_bar "$SIM_UDID" override --time 9:41 --batteryState charged \
        --batteryLevel 100 --cellularBars 4; then
        STATUS_BAR_OVERRIDDEN="$SIM_UDID"
    else
        note "NOTE: status bar override unavailable; captures show the live status bar."
    fi
    note "Warmup launch (not captured), ${WARMUP_SECONDS}s."
    launch "$SIM_UDID" -ProximeetFixture welcome
    sleep "$WARMUP_SECONDS"

    guarded welcome-cap-motion capture_motion
    guarded welcome-cap-reduce capture_reduce_motion_preview
    guarded welcome-cap-largetext capture_large_text
    guarded welcome-cap-smaller capture_smaller
    run cat "$WELCOME/captures.tsv"
    # The primary evidence is the launch recording and the settled screenshot of this run.
    [ -z "$PRIMARY_CAPTURE_FAILED" ]
}

# ---------------------------------------------------------------------------------------
# ui-review
# ---------------------------------------------------------------------------------------

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    local result="$WELCOME/WelcomeReview.xcresult" build_status run_status verdict
    rm -rf "$result"
    export NSUnbufferedIO=YES
    # 1. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"$TEST_SELECTION" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
        build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "welcome-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "welcome-ui-build" "PASS (UI test harness compiled)"

    # 2. Only WelcomeReviewTests, with the review flag for the test runner. xcodebuild passes
    #    TEST_RUNNER_-prefixed variables to the runner without the prefix (Xcode 13 notes).
    if run env TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:"$TEST_SELECTION" \
        -parallel-testing-enabled NO \
        -resultBundlePath "$result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
        test-without-building; then
        run_status=0
    else
        run_status=$?
    fi
    if [ -d "$result" ]; then
        ditto -c -k --sequesterRsrc --keepParent "$result" "$WELCOME/WelcomeReview.xcresult.zip" || true
        if xcrun xcresulttool export attachments --path "$result" --output-path "$WELCOME/attachments" \
            >> "$LOG" 2>&1; then
            note "Exported XCTest attachments to $WELCOME/attachments."
        else
            note "NOTE: attachment export unavailable; use WelcomeReview.xcresult.zip."
        fi
        xcrun xcresulttool get test-results summary --path "$result" > "$WELCOME/test-summary.json" 2>>"$LOG" || true
    fi
    # Geometry JSON: from the exported attachments if possible, otherwise from the log lines.
    # The attachment manifest format is not documented on the web, so every step is guarded.
    python3 - "$WELCOME" "$LOG" <<'PY' || true
import json
import os
import sys

welcome, log = sys.argv[1:3]
keys = ("geometry-default", "geometry-reduce-motion-preview", "geometry-largest-text")
found = set()
try:
    manifest = json.load(open(os.path.join(welcome, "attachments", "manifest.json")))
    for test in manifest if isinstance(manifest, list) else []:
        for item in (test.get("attachments", []) if isinstance(test, dict) else []):
            name = str(item.get("suggestedHumanReadableName", ""))
            exported = os.path.join(welcome, "attachments", str(item.get("exportedFileName", "")))
            for key in keys:
                if name.startswith(key + ".") or name.startswith(key + "_") or name == key:
                    if os.path.isfile(exported) and key not in found:
                        with open(exported, "rb") as src, open(os.path.join(welcome, key + ".json"), "wb") as dst:
                            dst.write(src.read())
                        found.add(key)
except (OSError, ValueError, AttributeError):
    pass
for line in open(log, encoding="utf-8", errors="replace"):
    if "WELCOME_REVIEW_JSON " in line:
        _, rest = line.split("WELCOME_REVIEW_JSON ", 1)
        key, _, payload = rest.strip().partition(" ")
        if key in keys and key not in found:
            try:
                json.loads(payload)
            except ValueError:
                continue
            with open(os.path.join(welcome, key + ".json"), "w") as dst:
                dst.write(payload + "\n")
            found.add(key)
print("geometry files: " + (", ".join(sorted(found)) or "none"))
PY
    # 3. What actually ran, from xcodebuild's per-test lines. (Written to a file, not a command
    #    substitution: bash 3.2 misparses heredocs inside $( ).)
    python3 - "$LOG" "$REQUIRED_PASSING_TESTS" "$WELCOME/ui-review-tests.txt" "$run_status" \
        > "$WELCOME/ui-review-counts.txt" <<'PY'
import re
import sys

log, required, out_path, xcodebuild_exit = sys.argv[1], sys.argv[2].split(), sys.argv[3], int(sys.argv[4])
outcome = {}
# Both xcodebuild styles: "Test Case '-[Module.WelcomeReviewTests testX]' passed (…)" and
# "Test case 'WelcomeReviewTests.testX()' passed on '…' (…)".
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?WelcomeReviewTests[ ./](test\w+)(?:\(\))?\]?' (passed|failed|skipped)")
flag_seen = False
for line in open(log, encoding="utf-8", errors="replace"):
    match = pattern.search(line)
    if match:
        outcome[match.group(1)] = match.group(2)
    if "WELCOME_REVIEW_FLAG_SEEN" in line:
        flag_seen = True
counts = {k: sum(1 for v in outcome.values() if v == k) for k in ("passed", "failed", "skipped")}
executed = counts["passed"] + counts["failed"]
missing = [name for name in required if outcome.get(name) != "passed"]
ok = xcodebuild_exit == 0 and executed > 0 and counts["failed"] == 0 and not missing
lines = ["%s=%s" % item for item in sorted(outcome.items())]
lines += ["discovered=%d" % len(outcome), "executed=%d" % executed,
          "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
          "required_passed=" + ("yes" if not missing else "no (" + ", ".join(missing) + ")"),
          # Tests skip in setUp without the flag, so an executed test proves it reached the runner.
          "flag_reached_runner=" + ("yes" if executed > 0 else "no evidence")
          + ("; marker in log" if flag_seen else "; marker not in log"),
          "xcodebuild_exit=%d" % xcodebuild_exit, "result=" + ("PASS" if ok else "FAIL")]
open(out_path, "w").write("\n".join(lines) + "\n")
print("executed %d of %d discovered (passed %d, failed %d, skipped %d); required passed: %s; xcodebuild exit %d; %s"
      % (executed, len(outcome), counts["passed"], counts["failed"], counts["skipped"],
         "yes" if not missing else "no", xcodebuild_exit, "PASS" if ok else "FAIL"))
PY
    run cat "$WELCOME/ui-review-tests.txt"
    verdict="$(cat "$WELCOME/ui-review-counts.txt")"
    summary_line "welcome-ui-run" "$verdict"
    grep -qx 'result=PASS' "$WELCOME/ui-review-tests.txt"
}

# ---------------------------------------------------------------------------------------
# verdict
# ---------------------------------------------------------------------------------------

stage_verdict() {
    run python3 - "$SUMMARY" "$META" "$WELCOME" <<'PY'
import json
import os
import sys

summary_path, meta, welcome = sys.argv[1:4]
last = {}
for line in open(summary_path, encoding="utf-8", errors="replace") if os.path.isfile(summary_path) else []:
    parts = line.rstrip("\n").split(None, 2)
    if len(parts) >= 2:
        last[parts[1]] = parts[2] if len(parts) > 2 else ""


def status(label):
    text = last.get(label)
    return "NOT RUN" if text is None else text


def passed(label):
    return last.get(label, "").startswith("PASS")


def kv(path):
    out = {}
    if os.path.isfile(path):
        for line in open(path):
            key, sep, value = line.rstrip("\n").partition("=")
            if sep:
                out.setdefault(key, value)
    return out


tools, source = kv(os.path.join(meta, "tools.txt")), kv(os.path.join(welcome, "source-checkpoint.txt"))
destination, tests = kv(os.path.join(welcome, "destination.txt")), kv(os.path.join(welcome, "ui-review-tests.txt"))
simulator = {}
if os.path.isfile(os.path.join(meta, "simulator.json")):
    simulator = json.load(open(os.path.join(meta, "simulator.json")))
dims = []
if os.path.isfile(os.path.join(welcome, "captures.tsv")):
    for row in list(open(os.path.join(welcome, "captures.tsv")))[1:]:
        cells = row.rstrip("\n").split("\t")
        if len(cells) > 4 and cells[3]:
            dims.append("%s %sx%s" % (cells[0], cells[3], cells[4]))

required = {
    "source gate (exact reviewed revision)": source.get("result") == "MATCH",
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "test-harness compilation (build-for-testing)": last.get("welcome-ui-build", "").startswith("PASS"),
    "runtime assertions (WelcomeReviewTests executed and passed)": tests.get("result") == "PASS",
    "launch recording confirmed and settled screenshot": passed("welcome-cap-motion"),
}
lines = [
    "Welcome review verdict (automated results only; manual review is listed separately)",
    "",
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"),
                                                   tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"),
                                 simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"),
                                                            destination.get("selected", "?")),
    "Images      " + ("; ".join(dims) if dims else "none recorded"),
    "",
    "Required automated results:",
]
lines += ["  %-62s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += [
    "  %-62s %s" % ("  XCTest detail", "executed %s, passed %s, failed %s, skipped %s, flag: %s" % (
        tests.get("executed", "?"), tests.get("passed", "?"), tests.get("failed", "?"),
        tests.get("skipped", "?"), tests.get("flag_reached_runner", "?"))),
    "",
    "Other captures (reported, not required):",
    "  Reduce Motion preview recording (app override, NOT the system setting): " + status("welcome-cap-reduce"),
    "  Largest text via simctl content_size (undocumented; UNVERIFIED until seen): " + status("welcome-cap-largetext"),
    "  Smaller iPhone (optional): " + status("welcome-cap-smaller"),
    "  Unsigned simulator app zip: " + status("package"),
    "",
    "Pending off-machine: analyze_welcome_review.py on the VPS (motion timing relative to visible app",
    "content, Reduce Motion frames, reference comparison). Its synthetic self-test is not runtime evidence.",
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/welcome-approved/reference (the founder decides)",
    "  VoiceOver reading order and announcements",
    "  system Settings > Accessibility > Reduce Motion",
    "  a tap during the first second of the pose study, and interruption (backgrounding mid-motion)",
    "  Apple branding correction before sign-in or distribution (HIG artwork and black/white rules)",
]
ok = all(required.values())
lines += ["", "AUTOMATED VERDICT: " + ("PASS (manual review still outstanding)" if ok else "FAIL")]
open(os.path.join(welcome, "verdict.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if ok else 1)
PY
}

# ---------------------------------------------------------------------------------------
# package-review and enforce
# ---------------------------------------------------------------------------------------

# One downloadable Welcome-Review.zip with whatever this run produced, the approved
# references beside it, and an offline viewer. Missing items are listed, never invented.
stage_package_review() {
    run python3 - "$ROOT" "$WELCOME" "$ARTIFACTS/Welcome-Review.zip" <<'PY'
import html
import json
import os
import sys
import zipfile

root, welcome, out_zip = sys.argv[1:4]
ref = os.path.join(root, "docs/design/welcome-approved/reference")
entries, missing = [], []   # (path inside Welcome-Review/, source path)


def add(name, source, required=True):
    if os.path.isfile(source):
        entries.append((name, source))
        return name
    if required:
        missing.append(name)
    return None


def read(path):
    return open(path, encoding="utf-8", errors="replace").read() if os.path.isfile(path) else ""


shots = {key: add("captures/" + key, os.path.join(welcome, key), required=req) for key, req in (
    ("01-welcome-settled.png", True), ("02-welcome-preview-flag-settled-layout.png", False),
    ("03-welcome-largest-text-top.png", False), ("04-welcome-smaller-iphone.png", False))}
videos = {key: add("captures/" + key, os.path.join(welcome, key), required=req) for key, req in (
    ("welcome-motion.mp4", True), ("welcome-reduce-motion.mp4", False))}
refs = {key: add("approved/" + key, os.path.join(ref, key)) for key in (
    "welcome-settled.png", "welcome-key-poses.png", "welcome-motion-study.mp4")}
for key in ("verdict.txt", "ui-review-tests.txt", "destination.txt", "source-checkpoint.txt", "captures.tsv"):
    add("results/" + key, os.path.join(welcome, key), required=key == "verdict.txt")

# XCTest attachments: the export's manifest format is not documented, so search it for any
# object that names an exported file, and keep images and text by their readable names.
attachments = []
attach_dir = os.path.join(welcome, "attachments")


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


try:
    pairs = list(walk(json.load(open(os.path.join(attach_dir, "manifest.json")))))
except (OSError, ValueError):
    pairs = [(n, n) for n in sorted(os.listdir(attach_dir))] if os.path.isdir(attach_dir) else []
for exported, readable in pairs:
    source = os.path.join(attach_dir, exported)
    extension = os.path.splitext(exported)[1].lower()
    if extension in (".png", ".jpg", ".jpeg", ".txt", ".json") and os.path.isfile(source):
        safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in readable)
        if not safe.lower().endswith(extension):
            safe += extension
        name = add("xctest/" + safe, source)
        attachments.append((readable, name, extension))

verdict = read(os.path.join(welcome, "verdict.txt")) or "No verdict was produced in this run."
headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")


def img(name, caption):
    return ('<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (name, html.escape(caption), html.escape(caption))
            if name else '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption))


def vid(name, caption):
    return ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>%s</figcaption></figure>'
            % (name, html.escape(caption)) if name else '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption))


notices = [(r, n) for r, n, e in attachments if e in (".png", ".jpg", ".jpeg") and r.startswith("notice")]
other_images = [(r, n) for r, n, e in attachments if e in (".png", ".jpg", ".jpeg") and not r.startswith("notice")]
texts = [(r, n) for r, n, e in attachments if e in (".txt", ".json")]
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Welcome review</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0}figcaption{color:#aaa;font-size:13px;max-width:330px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:760px}</style></head><body>
<h1>Proximeet Welcome: iOS Simulator review</h1>
<p><b>%s</b></p>
<p class="note">Real captures from this Codemagic simulator run, next to the approved design references. Automated
checks are not visual approval: judging how Welcome looks and moves is the founder's decision. The simulator app is
not installable on a physical iPhone.</p>
<h2>Settled Welcome vs approved reference</h2><div class="row">%s%s</div>
<h2>Launch recording (closed, opening, settled) vs approved motion study</h2><div class="row">%s%s</div>
<h2>Button notices (XCTest screenshots)</h2><div class="row">%s</div>
<h2>Other captures</h2><div class="row">%s%s%s%s</div>
<p class="note">The Reduce Motion recording uses the app's preview flag, not the system setting. The largest-text
capture uses an undocumented simulator command and is unverified until the text is seen to grow. VoiceOver, the
system Reduce Motion setting and interruption are manual checks.</p>
<h2>Other XCTest screenshots</h2><div class="row">%s</div>
<h2>Result</h2><pre>%s</pre>
<p>Details: %s</p>
<p class="missing">%s</p>
</body></html>""" % (
    html.escape(headline),
    img(shots["01-welcome-settled.png"], "This run: settled Welcome"),
    img(refs["welcome-settled.png"], "Approved reference (Figma 1:35)"),
    vid(videos["welcome-motion.mp4"], "This run: cold launch into the 2D pose study"),
    vid(refs["welcome-motion-study.mp4"], "Approved motion study"),
    "".join(img(n, r) for r, n in notices) or '<p class="missing">No notice screenshots were exported in this run.</p>',
    vid(videos["welcome-reduce-motion.mp4"], "Reduce Motion preview flag (app override)"),
    img(shots["02-welcome-preview-flag-settled-layout.png"], "Layout under the preview flag"),
    img(shots["03-welcome-largest-text-top.png"], "Largest text size (unverified command)"),
    img(shots["04-welcome-smaller-iphone.png"], "Smaller iPhone"),
    "".join(img(n, r) for r, n in other_images) or "<p>None.</p>",
    html.escape(verdict),
    " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
               if n.startswith("results/") or n.startswith("xctest/") and n.endswith((".txt", ".json"))),
    ("Not produced in this run: " + ", ".join(missing)) if missing else "")
os.makedirs(os.path.dirname(out_zip), exist_ok=True)
with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
    bundle.writestr("Welcome-Review/index.html", page)
    for name, source in entries:
        bundle.write(source, "Welcome-Review/" + name)
print("Welcome-Review.zip: %d files%s" % (len(entries) + 1, ("; missing: " + ", ".join(missing)) if missing else ""))
PY
    summary_line "welcome-package" "$(unzip -l "$ARTIFACTS/Welcome-Review.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in Welcome-Review.zip"
}

stage_enforce() {
    run cat "$WELCOME/verdict.txt" || true
    if grep -q '^AUTOMATED VERDICT: PASS' "$WELCOME/verdict.txt" 2>/dev/null; then
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
