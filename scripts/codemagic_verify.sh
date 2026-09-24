#!/usr/bin/env bash
# Proximeet — manual, unsigned iOS Simulator verification. Called once per stage by
# codemagic.yaml; also runnable on a Mac with Xcode 26.6. See docs/reports/codemagic-setup.md.
#
#   bash scripts/codemagic_verify.sh <stage>
#
# Stages, in order:
#   metadata          source revision, host and tool versions; fails unless Xcode is 26.6
#   validate          scripts/validate_project.py on the checked-in project (no regeneration)
#   domain-tests      swift test --package-path ProximeetDomain on the Mac host
#   select-simulator  choose an installed iPhone simulator from simctl JSON (never downloads)
#   build             Proximeet scheme, Debug, for that simulator UDID, code signing disabled
#   package           ditto zip of the simulator .app, preserving the executable bit
#   interaction       XCTest-driven Band-to-Signal taps, captured movie and test attachments
#   captures          boot, install, one uncaptured warmup launch, then relaunch each DEBUG
#                     fixture (six entrance scenes, B1/B2 selections, Ready, a labelled B2
#                     Reduce Motion preview) and take real simctl screenshots; B2 at the
#                     largest accessibility text size only if simctl can read and restore
#                     the simulator text size
#
# Each stage writes build/artifacts/logs/<stage>.log, appends PASS or FAIL with its real
# exit status to build/artifacts/summary.txt, and exits with that status. Nothing is
# signed, uploaded or downloaded. Written for the macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
SHOTS="$ARTIFACTS/screenshots"
APP_OUT="$ARTIFACTS/app"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"

# DerivedData stays outside build/artifacts, so it is never collected as an artifact.
DERIVED_DATA="$ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
EXPECTED_XCODE="Xcode 26.6"
EXPECTED_BUNDLE_ID="com.proximeet.demo"
PREFERRED_SIMULATOR="iPhone 17 Pro Max"
MIN_IOS="17.0"
# Fixed pause after each launch so the first frame and short decorative animations
# settle before the capture. A capture aid only, never a timing or performance figure.
SETTLE_SECONDS=5
# One uncaptured launch right after installation, so first-run system notifications on a
# fresh simulator (for example the Apple Intelligence prompt) settle before any capture.
WARMUP_SECONDS=15
# Simulator text size for the large-text B2 capture; the original value is restored.
LARGE_CONTENT_SIZE="accessibility-extra-extra-extra-large"
# Set while the simulator text size is changed; finish() restores it on any exit.
RESTORE_CONTENT_SIZE=""

STAGE="${1:-}"
case "$STAGE" in
    metadata|validate|domain-tests|select-simulator|build|package|captures|interaction) ;;
    *)
        echo "usage: $0 metadata|validate|domain-tests|select-simulator|build|package|captures|interaction" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$SHOTS" "$APP_OUT"
LOG="$LOGS/$STAGE.log"
: > "$LOG"

utc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

summary_line() { printf '%s  %-17s %s\n' "$(utc_now)" "$1" "$2" >> "$SUMMARY"; }

finish() {
    local status=$?
    if [ -n "$RESTORE_CONTENT_SIZE" ]; then
        # Reached only when a failure interrupted the large-text capture.
        if ! restore_content_size && [ "$status" -eq 0 ]; then
            status=1
        fi
    fi
    if [ "$status" -eq 0 ]; then
        summary_line "$STAGE" "PASS"
    else
        summary_line "$STAGE" "FAIL (exit $status), see $LOG"
        echo "codemagic_verify: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
    fi
    exit "$status"
}
trap finish EXIT

note() { printf '%s\n' "$*" | tee -a "$LOG"; }

# Echo a command, stream its combined output to the console and $LOG, and return the
# command's own exit status (tee's only if the command succeeded and tee failed).
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

load_simulator() {
    if [ ! -f "$SIM_ENV" ]; then
        note "ERROR: $SIM_ENV is missing; run the select-simulator stage first."
        return 1
    fi
    # shellcheck source=/dev/null
    . "$SIM_ENV"
    note "Simulator: $SIM_NAME, $SIM_RUNTIME_NAME ($SIM_RUNTIME_BUILD), UDID $SIM_UDID"
}

# Sets APP_BUNDLE_ID and APP_EXECUTABLE from the built bundle and checks both.
check_app() {
    if [ ! -d "$APP_PATH" ]; then
        note "ERROR: no built app at $APP_PATH; run the build stage first."
        return 1
    fi
    APP_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
    APP_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")"
    if [ "$APP_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]; then
        note "ERROR: CFBundleIdentifier is '$APP_BUNDLE_ID', expected '$EXPECTED_BUNDLE_ID'."
        return 1
    fi
    if [ ! -x "$APP_PATH/$APP_EXECUTABLE" ]; then
        note "ERROR: $APP_PATH/$APP_EXECUTABLE is missing or not executable."
        return 1
    fi
}

stage_metadata() {
    : > "$SUMMARY"
    local head branch commit_date subject dirty
    head="$(git rev-parse HEAD)"
    branch="$(git rev-parse --abbrev-ref HEAD)"
    commit_date="$(git log -1 --format=%cI)"
    subject="$(git log -1 --format=%s)"
    dirty="$(git status --porcelain)"
    {
        echo "recorded_utc=$(utc_now)"
        echo "git_head=$head"
        echo "git_branch=$branch"
        echo "git_commit_date=$commit_date"
        echo "git_subject=$subject"
        echo "codemagic_commit=${CM_COMMIT:-unset}"
        echo "codemagic_branch=${CM_BRANCH:-unset}"
        echo "codemagic_build_id=${CM_BUILD_ID:-unset}"
        if [ -z "$dirty" ]; then
            echo "worktree=clean"
        else
            echo "worktree=modified (results do not describe git_head exactly)"
            printf '%s\n' "$dirty" | sed 's/^/  /'
        fi
    } > "$META/source.txt"

    local macos_version macos_build machine cpu developer_dir xcode_version xcode_line
    local xcode_build sdk_version sdk_build swift_version python_version git_version
    macos_version="$(sw_vers -productVersion)"
    macos_build="$(sw_vers -buildVersion)"
    machine="$(uname -m)"
    cpu="$(sysctl -n machdep.cpu.brand_string)"
    developer_dir="$(xcode-select -p)"
    xcode_version="$(xcodebuild -version)"
    xcode_line="$(printf '%s\n' "$xcode_version" | sed -n '1p')"
    xcode_build="$(printf '%s\n' "$xcode_version" | sed -n '2p')"
    sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
    sdk_build="$(xcrun --sdk iphonesimulator --show-sdk-build-version)"
    swift_version="$(swift --version 2>&1)"
    swift_version="$(printf '%s\n' "$swift_version" | sed -n '1p')"
    python_version="$(python3 --version 2>&1)"
    git_version="$(git --version)"
    {
        echo "macos=$macos_version ($macos_build)"
        echo "machine=$machine"
        echo "cpu=$cpu"
        echo "developer_dir=$developer_dir"
        echo "xcode=$xcode_line"
        echo "xcode_build=$xcode_build"
        echo "iphonesimulator_sdk=$sdk_version ($sdk_build)"
        echo "swift=$swift_version"
        echo "python3=$python_version"
        echo "git=$git_version"
    } > "$META/tools.txt"

    run cat "$META/source.txt" "$META/tools.txt"
    run xcrun simctl list runtimes available
    summary_line "source" "$head ($branch)"
    summary_line "xcode" "$xcode_line, $xcode_build; macOS $macos_version; $cpu"

    if [ "$xcode_line" != "$EXPECTED_XCODE" ]; then
        note "ERROR: expected '$EXPECTED_XCODE' (codemagic.yaml environment.xcode) but found '$xcode_line'."
        return 1
    fi
    note "Xcode matches the pinned '$EXPECTED_XCODE'."
}

stage_validate() {
    run python3 scripts/validate_project.py
}

stage_domain_tests() {
    run swift test --package-path ProximeetDomain
}

stage_select_simulator() {
    run xcrun simctl list devices available
    xcrun simctl list -j runtimes available > "$META/simctl-runtimes.json"
    xcrun simctl list -j devices available > "$META/simctl-devices.json"
    rm -f "$SIM_ENV" "$META/simulator.json"
    run python3 - "$META/simctl-runtimes.json" "$META/simctl-devices.json" \
        "$META/simulator.json" "$SIM_ENV" "$PREFERRED_SIMULATOR" "$MIN_IOS" <<'PY'
import json
import shlex
import sys

runtimes_path, devices_path, json_path, env_path, preferred, minimum = sys.argv[1:7]


def version(text):
    parts = []
    for piece in str(text).split("."):
        digits = "".join(ch for ch in piece if ch.isdigit())
        parts.append(int(digits) if digits else 0)
    return tuple((parts + [0, 0, 0, 0])[:4])


with open(runtimes_path) as handle:
    runtimes = json.load(handle).get("runtimes", [])
with open(devices_path) as handle:
    devices_by_runtime = json.load(handle).get("devices", {})

ios_runtimes = {}
for runtime in runtimes:
    identifier = runtime.get("identifier", "")
    is_ios = runtime.get("platform") == "iOS" or ".SimRuntime.iOS-" in identifier
    if is_ios and runtime.get("isAvailable") is True \
            and version(runtime.get("version", "0")) >= version(minimum):
        ios_runtimes[identifier] = runtime

candidates = []
for identifier, devices in sorted(devices_by_runtime.items()):
    runtime = ios_runtimes.get(identifier)
    if runtime is None:
        continue
    for device in devices:
        if device.get("isAvailable") is True and device.get("name", "").startswith("iPhone"):
            candidates.append((runtime, device))

if not candidates:
    print("ERROR: no available iPhone simulator on an installed iOS >= %s runtime." % minimum)
    print("iOS runtimes considered: %s" % (", ".join(sorted(ios_runtimes)) or "none"))
    print("This workflow never downloads simulator runtimes.")
    sys.exit(1)

# Deterministic: the preferred model first, then the highest iOS runtime, then name, then UDID.
candidates.sort(key=lambda item: (
    0 if item[1]["name"] == preferred else 1,
    tuple(-part for part in version(item[0].get("version", "0"))),
    item[1]["name"],
    item[1]["udid"],
))
runtime, device = candidates[0]
selected = {
    "rule": "name == %r first; then highest iOS runtime >= %s; then name; then UDID"
            % (preferred, minimum),
    "preferred_name_matched": device["name"] == preferred,
    "device_name": device["name"],
    "udid": device["udid"],
    "device_type": device.get("deviceTypeIdentifier", ""),
    "state_before_boot": device.get("state", ""),
    "runtime_identifier": runtime["identifier"],
    "runtime_name": runtime.get("name", ""),
    "runtime_version": runtime.get("version", ""),
    "runtime_build": runtime.get("buildversion", ""),
    "candidates": [
        {"name": d["name"], "udid": d["udid"], "runtime": r.get("name", r["identifier"])}
        for r, d in candidates
    ],
}
with open(json_path, "w") as handle:
    json.dump(selected, handle, indent=2, sort_keys=True)
    handle.write("\n")
with open(env_path, "w") as handle:
    for key, value in (
        ("SIM_UDID", selected["udid"]),
        ("SIM_NAME", selected["device_name"]),
        ("SIM_RUNTIME_ID", selected["runtime_identifier"]),
        ("SIM_RUNTIME_NAME", selected["runtime_name"]),
        ("SIM_RUNTIME_VERSION", selected["runtime_version"]),
        ("SIM_RUNTIME_BUILD", selected["runtime_build"]),
    ):
        handle.write("%s=%s\n" % (key, shlex.quote(value)))
print("Selected %s, %s (%s), UDID %s; preferred name matched: %s; %d candidate(s)." % (
    selected["device_name"], selected["runtime_name"], selected["runtime_build"],
    selected["udid"], selected["preferred_name_matched"], len(candidates)))
PY
    load_simulator
    summary_line "simulator" "$SIM_NAME, $SIM_RUNTIME_NAME ($SIM_RUNTIME_BUILD), UDID $SIM_UDID"
}

stage_build() {
    load_simulator
    export NSUnbufferedIO=YES
    run xcodebuild \
        -project Proximeet.xcodeproj \
        -scheme Proximeet \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        build
    check_app
    local archs
    archs="$(lipo -archs "$APP_PATH/$APP_EXECUTABLE")"
    run ls -l "$APP_PATH/$APP_EXECUTABLE"
    run file "$APP_PATH/$APP_EXECUTABLE"
    {
        echo "configuration=Debug"
        echo "platform=iphonesimulator"
        echo "bundle_id=$APP_BUNDLE_ID"
        echo "executable=$APP_EXECUTABLE"
        echo "architectures=$archs"
        echo "code_signing=disabled (CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)"
        echo "built_for=$SIM_NAME, $SIM_RUNTIME_NAME ($SIM_RUNTIME_BUILD), UDID $SIM_UDID"
        echo "note=Unsigned Debug iOS Simulator build. It cannot be installed on a device or distributed through TestFlight."
    } > "$META/app.txt"
    run cat "$META/app.txt"
    if [ ! -s "$APP_PATH/ProximeetSignature.usdz" ]; then
        note "ERROR: the built bundle is missing ProximeetSignature.usdz."
        return 1
    fi
    run shasum -a 256 "$APP_PATH/ProximeetSignature.usdz"
    if [ ! -e "$APP_PATH/SignatureStudio.realityenv" ]; then
        note "ERROR: the built bundle is missing compiled SignatureStudio.realityenv (a raw .skybox copy is insufficient)."
        return 1
    fi
    run ls -ld "$APP_PATH/SignatureStudio.realityenv"
}

stage_package() {
    check_app
    local short zip verify_dir
    short="$(git rev-parse --short=12 HEAD)"
    zip="$APP_OUT/Proximeet-Debug-iphonesimulator-$short.zip"
    rm -f "$zip" "$zip.sha256"
    run ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$zip"
    verify_dir="$(mktemp -d)"
    run ditto -x -k "$zip" "$verify_dir"
    if [ ! -x "$verify_dir/Proximeet.app/$APP_EXECUTABLE" ]; then
        note "ERROR: Proximeet.app/$APP_EXECUTABLE is not executable after extracting $zip."
        return 1
    fi
    note "Verified: Proximeet.app/$APP_EXECUTABLE keeps its executable bit after extraction."
    rm -rf "$verify_dir"
    (cd "$APP_OUT" && shasum -a 256 "$(basename "$zip")") > "$zip.sha256"
    run cat "$zip.sha256"
    note "NOTE: $zip is an unsigned Debug iOS Simulator app. It cannot be installed on a device or through TestFlight."
}

# launch_app <launch arguments...>: relaunch the app and set LAUNCH_PID from simctl.
# ${1+"$@"} keeps bash 3.2 with `set -u` happy when no arguments are given.
launch_app() {
    local output status
    LAUNCH_PID=""
    set +e
    output="$(xcrun simctl launch --terminate-running-process "$SIM_UDID" "$APP_BUNDLE_ID" ${1+"$@"} 2>&1)"
    status=$?
    set -e
    note "$output"
    note "[exit $status] xcrun simctl launch --terminate-running-process $SIM_UDID $APP_BUNDLE_ID ${*-}"
    if [ "$status" -ne 0 ]; then
        return "$status"
    fi
    LAUNCH_PID="${output##*: }"
    case "$LAUNCH_PID" in
        ''|*[!0-9]*)
            note "ERROR: no process ID in the simctl launch output."
            return 1
            ;;
    esac
}

# First launch after installation, never captured. The pause lets first-run system
# notifications settle; the process must still be alive afterwards.
warmup() {
    note ""
    note "== warmup: first launch after installation (not captured)"
    launch_app -ProximeetFixture welcome
    note "Waiting ${WARMUP_SECONDS}s for first-run simulator notifications to settle."
    sleep "$WARMUP_SECONDS"
    run ps -p "$LAUNCH_PID" -o pid= -o stat= -o comm=
    summary_line "warmup" "first launch, ${WARMUP_SECONDS}s, process alive (PID $LAUNCH_PID)"
}

# capture <name> <note or empty> <launch arguments...>
capture() {
    local name="$1" label="$2"
    shift 2
    local png="$SHOTS/$name.png"
    local pid width height digest
    note ""
    note "== $name"
    launch_app "$@"
    pid="$LAUNCH_PID"
    sleep "$SETTLE_SECONDS"
    run ps -p "$pid" -o pid= -o stat= -o comm=
    rm -f "$png"
    run xcrun simctl io "$SIM_UDID" screenshot --type=png "$png"
    # The launched process is still alive after the capture, so the image is not a
    # post-crash home screen. It does not prove the pixels are correct; review them.
    run ps -p "$pid" -o pid= -o stat= -o comm=
    if [ ! -s "$png" ]; then
        note "ERROR: $png is missing or empty."
        return 1
    fi
    width="$(sips -g pixelWidth "$png" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$png" | awk '/pixelHeight/ { print $2 }')"
    digest="$(shasum -a 256 "$png" | awk '{ print $1 }')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name.png" "$pid" "$(utc_now)" "$width" "$height" \
        "$digest" "$*" "${label:-DEBUG fixture launch}" >> "$SHOTS/captures.tsv"
    note "Captured $png (${width}x${height}) from PID $pid."
}

# Prints the simulator's current text size as one simctl size name, or fails if simctl
# cannot report one this script recognises.
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

# Restores the text size recorded in RESTORE_CONTENT_SIZE and confirms it by reading it
# back. Uses explicit returns so it behaves the same inside the EXIT trap.
restore_content_size() {
    local wanted="$RESTORE_CONTENT_SIZE" actual
    [ -n "$wanted" ] || return 0
    RESTORE_CONTENT_SIZE=""
    run xcrun simctl ui "$SIM_UDID" content_size "$wanted" || return 1
    actual="$(read_content_size)" || actual="unreadable"
    note "Simulator text size after restore: '$actual' (expected '$wanted')."
    if [ "$actual" != "$wanted" ]; then
        note "ERROR: the simulator text size was not restored."
        return 1
    fi
    summary_line "text-size" "restored to $wanted"
}

# capture_large_text <name> <note> <launch arguments...>: capture at LARGE_CONTENT_SIZE
# only when simctl can read the current size, so it can be restored afterwards.
capture_large_text() {
    local name="$1" original
    note ""
    note "== $name: reading the simulator text size"
    if ! original="$(read_content_size)"; then
        note "SKIPPED $name: 'xcrun simctl ui $SIM_UDID content_size' gave no readable size, so the setting was not changed."
        summary_line "large-text" "SKIPPED (simctl ui content_size unavailable or unreadable)"
        return 0
    fi
    note "Current simulator text size: $original"
    RESTORE_CONTENT_SIZE="$original"
    run xcrun simctl ui "$SIM_UDID" content_size "$LARGE_CONTENT_SIZE"
    capture "$@"
    restore_content_size
}

stage_captures() {
    load_simulator
    check_app
    run xcrun simctl bootstatus "$SIM_UDID" -b
    run xcrun simctl install "$SIM_UDID" "$APP_PATH"
    rm -f "$SHOTS"/*.png
    printf 'file\tpid\tcaptured_utc\tpixel_width\tpixel_height\tsha256\tlaunch_arguments\tnote\n' \
        > "$SHOTS/captures.tsv"
    warmup
    # The six entrance scenes in flow order, then selections and Ready.
    capture 01-welcome "" \
        -ProximeetFixture welcome
    capture 02-birthday-fixture-date \
        "Birthday scene after returning from the pass, so the wheel shows the fixture date (17 May 1995)" \
        -ProximeetFixture birthday
    capture 03-demo-pass "" \
        -ProximeetFixture pass
    capture 04-guest-list-empty "" \
        -ProximeetFixture guest-list
    capture 04b-guest-list-filled "Saved fictional profile through the normal domain transition" \
        -ProximeetFixture guest-list-filled
    capture 05-b1-band "" \
        -ProximeetFixture band
    capture 06-b1-band-selected-social "" \
        -ProximeetFixture band-selected -ProximeetFixtureBand social
    capture 07-b2-signal-social "" \
        -ProximeetFixture signal -ProximeetFixtureBand social
    capture 08-b2-signal-selected-social-chatFirst "" \
        -ProximeetFixture signal-selected -ProximeetFixtureBand social -ProximeetFixtureSignal chatFirst
    capture 09-ready-social-chatFirst "" \
        -ProximeetFixture ready -ProximeetFixtureBand social -ProximeetFixtureSignal chatFirst
    capture 10-b2-signal-selected-social-chatFirst-reduce-motion-preview-app-override \
        "App-level -ProximeetReduceMotionPreview override only; not the system Reduce Motion setting and not an accessibility test" \
        -ProximeetFixture signal-selected -ProximeetFixtureBand social -ProximeetFixtureSignal chatFirst \
        -ProximeetReduceMotionPreview YES
    capture_large_text 11-b2-signal-selected-social-chatFirst-simulator-text-size-ax5 \
        "Simulator text size set with simctl ui content_size $LARGE_CONTENT_SIZE, then restored; a single capture, not an accessibility review" \
        -ProximeetFixture signal-selected -ProximeetFixtureBand social -ProximeetFixtureSignal chatFirst
    if bash scripts/capture_fixture_reel.sh "$SIM_UDID" "$APP_BUNDLE_ID" "$SHOTS/12-fixture-entrances.mp4"; then
        summary_line "fixture-reel" "captured native DEBUG scene entrances; not an interactive end-to-end test"
    else
        note "WARNING: optional native entrance recording failed; inspect its recorder log."
        summary_line "fixture-reel" "UNAVAILABLE (recording failed; screenshots remain independent evidence)"
    fi
    run cat "$SHOTS/captures.tsv"
}

stage_interaction() {
    load_simulator
    check_app
    run bash scripts/capture_interaction_reel.sh "$SIM_UDID" "$DERIVED_DATA" "$ARTIFACTS"
    summary_line "interaction" "XCTest real taps passed; native simulator movie and xcresult recorded"
}

case "$STAGE" in
    metadata) stage_metadata ;;
    validate) stage_validate ;;
    domain-tests) stage_domain_tests ;;
    select-simulator) stage_select_simulator ;;
    build) stage_build ;;
    package) stage_package ;;
    captures) stage_captures ;;
    interaction) stage_interaction ;;
esac
