#!/usr/bin/env bash
# Proximeet — runtime review of the approved Welcome (chapter 01) in the iOS Simulator.
# Manual and unsigned. See docs/verification/welcome-mac-review.md.
#
#   bash scripts/welcome_review.sh <stage>
#
# Stages:
#   checkpoint  prove this checkout holds exactly the checkpointed Welcome: every file listed in
#               docs/verification/welcome-review-files.sha256 matches, no other file exists
#               under the app, test, project, package or scripts roots, and the Welcome
#               deletions are absent; runs anywhere with git and python3
#   captures    on a Mac, after `codemagic_verify.sh select-simulator` and `build`, and only
#               if the checkpoint stage matched: settled screenshot, a launch recording of the
#               pose study, the Reduce Motion preview recording, the largest text size, and a
#               smaller installed iPhone if one exists
#   ui-review   on a Mac, only if the checkpoint stage matched: WelcomeReviewTests (geometry,
#               both notices, Reduce Motion preview, largest text) with the review flag set,
#               plus exported attachments; fails unless the review tests actually ran
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
MANIFEST="docs/verification/welcome-review-files.sha256"
DELETIONS="docs/verification/welcome-review-deletions.txt"
CHECKPOINT_RESULT="$WELCOME/source-checkpoint.txt"
LARGE_CONTENT_SIZE="accessibility-extra-extra-extra-large"
# Smaller iPhones to try, in order, on the same runtime as the main simulator. Only
# already-installed simulators are used. Codemagic's Xcode 26.6 image lists iPhone 17,
# 17 Pro, 17 Pro Max, 17e and Air (docs.codemagic.io/specs-macos/xcode-26-6, 2026-09-25), so
# there it is iPhone 17e; a local Mac may also have an iPhone SE.
SMALLER_IPHONES="iPhone SE (3rd generation)|iPhone 17e|iPhone 16e|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
# WelcomeReviewTests has four tests. Notices and the Reduce Motion preview must pass on any
# iPhone; geometry is asserted only on the 440 x 956 reference and large text only when the
# launch argument takes effect, so those two may skip, and the summary says so.
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

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|captures|ui-review) ;;
    *)
        echo "usage: $0 checkpoint|captures|ui-review" >&2
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

stop_recorder() {
    if [ -n "$RECORDER_PID" ]; then
        kill -INT "$RECORDER_PID" 2>/dev/null || true
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

# Captures and the XCTest review describe the checkpointed Welcome only.
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
    run python3 - "$MANIFEST" "$DELETIONS" "$CHECKPOINT_RESULT" <<'PY'
import hashlib
import os
import subprocess
import sys

manifest, deletions, out_path = sys.argv[1:4]
# Everything that can change what is built or how it is checked must be exactly the
# checkpointed file set; docs outside the manifest and codemagic.yaml are recorded, not gated
# (the lead may add the proposed manual workflow to codemagic.yaml).
STRICT_ROOTS = ("Proximeet/", "ProximeetUITests/", "Proximeet.xcodeproj/", "ProximeetDomain/", "scripts/")


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def sha256(path):
    with open(path, "rb") as data:
        return hashlib.sha256(data.read()).hexdigest()


expected, problems = {}, []
with open(manifest) as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        digest, path = line.split("  ", 1)
        expected[path] = digest
for path, digest in sorted(expected.items()):
    if not os.path.isfile(path):
        problems.append("missing   " + path)
    elif sha256(path) != digest:
        problems.append("differs   " + path)

listed = git("ls-files", "--cached", "--others", "--exclude-standard")
if listed is None:
    problems.append("git unavailable: cannot list the checkout, so extra files cannot be ruled out")
    present = []
else:
    present = [p for p in listed.splitlines() if p and os.path.lexists(p)]
extra = sorted(p for p in present if p.startswith(STRICT_ROOTS) and p not in expected)
problems += ["unexpected " + p for p in extra]

absent = 0
with open(deletions) as handle:
    for path in (line.strip() for line in handle):
        if path and not path.startswith("#"):
            if os.path.lexists(path):
                problems.append("present   " + path + " (the Welcome change deletes it)")
            else:
                absent += 1

status = git("status", "--porcelain") or ""
lines = [
    "git_head=" + (git("rev-parse", "HEAD") or "unavailable"),
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "git_status_porcelain_lines=%d" % len([l for l in status.splitlines() if l]),
    "manifest=" + manifest,
    "manifest_sha256=" + sha256(manifest),
    "codemagic_yaml_sha256=" + (sha256("codemagic.yaml") if os.path.isfile("codemagic.yaml") else "absent"),
    "strict_roots=" + " ".join(STRICT_ROOTS),
    "files_checked=%d" % len(expected),
    "deletions_confirmed=%d" % absent,
    "result=" + ("MATCH" if not problems else "MISMATCH"),
]
lines += ["problem=" + p for p in problems]
with open(out_path, "w") as out:
    out.write("\n".join(lines) + "\n")
print("\n".join(lines))
if problems:
    print("This checkout is not the checkpointed Welcome. Do not review it as such.")
    sys.exit(1)
PY
    summary_line "welcome-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^files_checked=' "$CHECKPOINT_RESULT") $(grep '^git_tree=' "$CHECKPOINT_RESULT")"
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

# screenshot <udid> <file name> <note>
screenshot() {
    local udid="$1" name="$2" label="$3" png width height digest
    png="$WELCOME/$name"
    rm -f "$png"
    # Explicit returns: this also runs where errexit is off (the optional smaller iPhone).
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

# record_launch <file name> <seconds> <launch arguments...>: the previous app instance is
# terminated first, so the recording opens on the home screen, then shows the launch and the
# whole pose study from the first app frame.
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
            note "ERROR: the simulator recorder exited early; see $movie.log."
            RECORDER_PID=""
            return 1
        fi
        sleep 0.5
        waited=$((waited + 1))
    done
    if ! grep -q "Recording started" "$movie.log" 2>/dev/null; then
        note "NOTE: no 'Recording started' line after 10 s; continuing (see $movie.log)."
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
        "$(awk '{ print $1 }' "$movie.sha256")" "recording: $* (${seconds}s after launch)" >> "$WELCOME/captures.tsv"
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

# capture_smaller <udid> <name>: optional; every failure returns non-zero to the caller, which
# records it without failing the stage. A simulator booted here is shut down again.
capture_smaller() {
    local udid="$1" name="$2"
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

stage_captures() {
    require_checkpoint_match
    load_simulator
    check_app
    run xcrun simctl bootstatus "$SIM_UDID" -b
    run xcrun simctl install "$SIM_UDID" "$APP_PATH"
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

    # 1. The pose study from launch, then the settled screen of that same process.
    record_launch welcome-motion.mp4 "$RECORD_SECONDS" -ProximeetFixture welcome
    screenshot "$SIM_UDID" 01-welcome-settled.png "settled, ${RECORD_SECONDS}s after launch"

    # 2. App-level Reduce Motion preview (the system setting is a manual check). The movie is
    #    the evidence; the screenshot, taken seconds later, only shows the settled layout.
    record_launch welcome-reduce-motion.mp4 4 -ProximeetFixture welcome -ProximeetReduceMotionPreview YES
    screenshot "$SIM_UDID" 02-welcome-preview-flag-settled-layout.png \
        "-ProximeetReduceMotionPreview YES, 4 s after launch; layout only, not Reduce Motion evidence"

    # 3. Largest accessibility text size, restored afterwards.
    local original
    if original="$(read_content_size)"; then
        RESTORE_CONTENT_SIZE="$original"
        run xcrun simctl ui "$SIM_UDID" content_size "$LARGE_CONTENT_SIZE"
        launch "$SIM_UDID" -ProximeetFixture welcome
        sleep "$SETTLE_SECONDS"
        screenshot "$SIM_UDID" 03-welcome-largest-text-top.png "simctl content_size $LARGE_CONTENT_SIZE; top of page"
        restore_content_size
    else
        note "SKIPPED large text: simctl could not report the current text size, so it was not changed."
        summary_line "welcome-largetext" "SKIPPED (content_size unreadable)"
    fi

    # 4. A smaller installed iPhone, if any (no device is created, nothing is downloaded).
    local smaller small_udid small_name
    smaller="$(smaller_iphone)"
    if [ -z "$smaller" ]; then
        note "SKIPPED smaller iPhone: none of '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        summary_line "welcome-smaller" "SKIPPED (no smaller iPhone installed)"
    else
        small_udid="$(printf '%s' "$smaller" | cut -f1)"
        small_name="$(printf '%s' "$smaller" | cut -f2)"
        note "Smaller iPhone: $small_name ($small_udid)."
        if capture_smaller "$small_udid" "$small_name"; then
            summary_line "welcome-smaller" "captured on $small_name"
        else
            note "WARNING: the optional smaller-iPhone capture failed; see this log."
            summary_line "welcome-smaller" "FAILED on $small_name (optional; other captures stand)"
        fi
    fi
    run cat "$WELCOME/captures.tsv"
}

# ---------------------------------------------------------------------------------------
# ui-review
# ---------------------------------------------------------------------------------------

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    local result="$WELCOME/WelcomeReview.xcresult" status counts
    rm -rf "$result"
    export NSUnbufferedIO=YES
    # The prefix makes xcodebuild pass PROXIMEET_WELCOME_REVIEW=1 to the test runner only.
    # Collect evidence even when an assertion fails; the verdict is decided below.
    if run env TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" \
        -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests/WelcomeReviewTests \
        -parallel-testing-enabled NO \
        -resultBundlePath "$result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
        test; then
        status=0
    else
        status=$?
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
    # Verdict from xcodebuild's own per-test lines: a skip is never a pass. (Output goes to a
    # file, not a command substitution: bash 3.2 misparses heredocs inside $( ).)
    python3 - "$LOG" "$REQUIRED_PASSING_TESTS" "$WELCOME/ui-review-tests.txt" > "$WELCOME/ui-review-counts.txt" <<'PY'
import re
import sys

log, required, out_path = sys.argv[1], sys.argv[2].split(), sys.argv[3]
outcome = {}
# Both xcodebuild styles: "Test Case '-[Module.WelcomeReviewTests testX]' passed (…)" and
# "Test case 'WelcomeReviewTests.testX()' passed on '…' (…)".
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?WelcomeReviewTests[ ./](test\w+)(?:\(\))?\]?' (passed|failed|skipped)")
for line in open(log, encoding="utf-8", errors="replace"):
    match = pattern.search(line)
    if match:
        outcome[match.group(1)] = match.group(2)
lines = ["%s=%s" % item for item in sorted(outcome.items())]
missing = [name for name in required if outcome.get(name) != "passed"]
lines.append("required_passed=" + ("yes" if not missing else "no (" + ", ".join(missing) + ")"))
open(out_path, "w").write("\n".join(lines) + "\n")
counts = {k: sum(1 for v in outcome.values() if v == k) for k in ("passed", "failed", "skipped")}
print("passed %(passed)d, failed %(failed)d, skipped %(skipped)d" % counts
      + ("" if not missing else "; required not passed: " + ", ".join(missing)))
PY
    counts="$(cat "$WELCOME/ui-review-counts.txt")"
    run cat "$WELCOME/ui-review-tests.txt"
    printf 'xcodebuild_exit=%s\nsimulator=%s (%s)\ntests=%s\n' "$status" "$SIM_NAME" "$SIM_UDID" "$counts" \
        > "$WELCOME/ui-review-result.txt"
    summary_line "welcome-ui" "xcodebuild exit $status; $counts"
    if [ "$status" -eq 0 ] && ! grep -qx 'required_passed=yes' "$WELCOME/ui-review-tests.txt"; then
        note "ERROR: xcodebuild succeeded but the required Welcome review tests did not pass (skipped or not run): the review measured nothing."
        status=1
    fi
    return "$status"
}

case "$STAGE" in
    checkpoint) stage_checkpoint ;;
    captures) stage_captures ;;
    ui-review) stage_ui_review ;;
esac
