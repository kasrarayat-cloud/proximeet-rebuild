#!/usr/bin/env bash
# Proximeet — runtime review of the approved Guest List (chapter 04) in the iOS Simulator.
# Manual and unsigned. Codemagic workflow: proximeet-guest-list-review (codemagic.yaml).
# See docs/verification/guest-list-mac-review.md.
#
#   bash scripts/guest_list_review.sh <stage>
#
# Stages:
#   checkpoint    source gate. The approved assets (Welcome poses, Manrope fonts and licence,
#                 the Birthday housing, the Pass artwork, the Guest List card art, the approved
#                 references) must match docs/verification/guest-list-approved-files.sha256 and
#                 their handoff provenance; every other file must match
#                 docs/verification/guest-list-review-files.sha256 (which excludes only itself); no
#                 other file may exist; earlier deletions stay absent; the Guest List and Pass
#                 sources carry no verification, visibility, capture, network, persistence, logging
#                 or timer API. Run input GUEST_LIST_EXPECTED_COMMIT (full 40-hex SHA) pins HEAD;
#                 required on Codemagic (CM_BUILD_ID set), optional elsewhere. Runs anywhere.
#   destinations  list installed simulators; report whether iPhone 17 Pro Max was selected
#   captures      supplementary DEBUG-fixture screenshots (labelled as fixtures): the empty editor,
#                 the fictional example, its card, the name-only card, the Reduce Motion preview
#                 flag, the largest text size, and a smaller iPhone
#   ui-review     compile the UI test harness; record the real Guest List walkthrough (entry,
#                 typing, chips, preview, editing, Back to Pass, re-entry, endpoint); then run the
#                 Guest List tests and the Pass, Birthday and Welcome regressions. Zero executed
#                 tests, or any failure or skip of a required test, fails the stage
#   compact-video half-size re-encode of the recording, trimmed to the app
#   verdict       automated results, kept apart from outstanding manual review
#   package-review  build/artifacts/Guest-List-Review.zip (offline index.html), Guest-List-Screens.zip,
#                 Guest-List-walkthrough-compact.zip/.mp4, Guest-List-walkthrough-original.zip and
#                 the archive's SHA-256
#   enforce       fail the build unless the verdict says PASS (run last)
#
# Outputs go to build/artifacts/guest-list/, logs to build/artifacts/logs/guest-list-<stage>.log,
# and PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or downloaded, no
# simulator runtime is installed, and no device is created. Written for the macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
OUT="$ARTIFACTS/guest-list"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DERIVED_DATA="$ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/guest-list-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/guest-list-review-files.sha256"
DELETIONS="docs/verification/guest-list-review-deletions.txt"
CHECKPOINT_RESULT="$OUT/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
LARGE_CONTENT_SIZE="accessibility-extra-extra-extra-large"
SMALLER_IPHONES="iPhone SE (3rd generation)|iPhone 17e|iPhone 16e|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
WALKTHROUGH="ProximeetUITests/GuestListReviewTests/testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint"
# Tests that must run and pass (a skip or an undiscovered test is a failure). Welcome geometry is
# asserted on the 440 x 956 reference, which the primary target provides; Welcome's large-text
# test may skip if its launch argument has no effect, and is reported either way.
# Hardware key events (Tab, or the ⌘V paste fallback) can leave the simulator without its
# on-screen keyboard, so those tests run last, in their own pass.
GUEST_LIST_HARDWARE_KEY_TESTS="testBlankInternationalAndLongNames testOpenerLimitBoundariesAndPreservedPaste testHardwareTabAndShiftTabMoveBetweenFields"
GUEST_LIST_TESTS="testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint testInterestsToggleIndependentlyAndOptionalContentIsOmitted testKeyboardFocusOrderReachabilityAndDismissal testRepeatedTapsNeverDuplicateOrSkipARoute testRelaunchResetsTheDraftAndNothingIsConferred testReduceMotionPreviewKeepsTheCardStationary testLargestTextReflowsAndKeepsEverythingReachable $GUEST_LIST_HARDWARE_KEY_TESTS"
REQUIRED_PASSING_TESTS="$(for t in $GUEST_LIST_TESTS; do printf 'GuestListReviewTests.%s ' "$t"; done)PassReviewTests.testWalkthroughStartFinishEndpointLeaveReentryCancelBack PassReviewTests.testGateRapidTapsWaitingAndResumeNeverAdvanceOnTheirOwn PassReviewTests.testReduceMotionPreviewKeepsThePassStationary PassReviewTests.testLargestTextKeepsTheDemoLabelWholeAndControlsReachable BirthdayReviewTests.testWalkthroughEntryCorrectionContinueBack BirthdayReviewTests.testTypedEntryPreservesComponentsAndKeyboard WelcomeReviewTests.testHonestNotices WelcomeReviewTests.testReduceMotionPreviewLaunch WelcomeReviewTests.testDefaultGeometry"
WARMUP_SECONDS=15
WARMUP_SMALL_SECONDS=8
SETTLE_SECONDS=3
RESTORE_CONTENT_SIZE=""
STATUS_BAR_OVERRIDDEN=""
RECORDER_PID=""
SMALL_BOOTED_UDID=""
LAUNCH_PID=""

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|captures|ui-review|compact-video|verdict|package-review|enforce) ;;
    *)
        echo "usage: $0 checkpoint|destinations|captures|ui-review|compact-video|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$OUT"
LOG="$LOGS/guest-list-$STAGE.log"
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
        summary_line "guest-list-$STAGE" "PASS"
    else
        summary_line "guest-list-$STAGE" "FAIL (exit $status), see $LOG"
        echo "guest_list_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
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
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/guest_list_review.sh checkpoint' first. Nothing is captured for an unverified source."
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
# The Guest List handoff's SHA256SUMS.txt covers the card art, the Manrope faces and the licence;
# the Pass handoff's covers the pass artwork; the Birthday handoff's covers the housing; Welcome's
# FONT_SOURCE.json and the Birthday and Pass records must agree on the faces.
assets = "Proximeet/Resources/Assets.xcassets/"
provenance, bundled = {}, ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")


def sums(path):
    return dict(reversed(line.strip().split("  ", 1)) for line in open(path) if line.strip())


try:
    handoff = sums("docs/design/guest-list-approved/SHA256SUMS.txt")
    pass_sums = sums("docs/design/pass-approved/SHA256SUMS.txt")
    birthday = sums("docs/design/birthday-approved/SHA256SUMS.txt")
    provenance[assets + "GuestListCard.imageset/guest-list-card.png"] = handoff["assets/guest-list-card.png"]
    provenance[assets + "PassArtwork.imageset/pass-artwork.png"] = pass_sums["assets/pass-artwork.png"]
    provenance[assets + "BirthdayHousing.imageset/birthday-housing.png"] = birthday["assets/birthday-housing.png"]
    provenance[assets + "Manrope-OFL.dataset/OFL.txt"] = handoff["fonts/OFL.txt"]
    fonts = {f["file"]: f["sha256"] for f in json.load(open("docs/design/welcome-approved/FONT_SOURCE.json"))["fonts"]}
    for face in bundled:
        name = "Manrope-%s.ttf" % face
        provenance[assets + "Manrope-%s.dataset/%s" % (face, name)] = handoff["fonts/" + name]
        if (fonts.get(name) != handoff["fonts/" + name] or birthday.get("fonts/" + name) != handoff["fonts/" + name]
                or pass_sums.get("fonts/" + name) != handoff["fonts/" + name]):
            problems.append("Welcome, Birthday, Pass and Guest List font records disagree  " + name)
    if pass_sums.get("fonts/OFL.txt") != handoff["fonts/OFL.txt"]:
        problems.append("Pass and Guest List licence records disagree  fonts/OFL.txt")
except (OSError, ValueError, KeyError) as error:
    problems.append("provenance records unreadable: %r" % (error,))
for name, digest in sorted(provenance.items()):
    if name not in frozen:
        problems.append("approved asset not in the frozen manifest  " + name)
    elif os.path.isfile(name) and sha256(name) != digest:
        problems.append("differs from the approved handoff  " + name)

# The Guest List and Pass route: no verification, visibility, membership, entitlement, presence,
# capture, network, persistence, logging or timer API in their sources. The visible sentences
# "This preview doesn't make you visible to anyone." and "No age or identity verification is
# performed." say what is not done; neither is a flag.
guarded_sources = ["Proximeet/Scenes/GuestListView.swift", "Proximeet/Scenes/PassView.swift",
                   "Proximeet/Components/RepeatTapGuard.swift", "Proximeet/App/DemoSession.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/GuestIntroduction.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/GuestListDemo.swift",
                   "ProximeetDomain/Sources/ProximeetDomain/PassDemo.swift"]
guard_forbidden = ["isVerified", "verified", "Verified", "isVisible", "Discoverable", "discoverable",
                   "membership", "Membership", "isMember", "entitlement", "Entitlement", "presence", "Presence",
                   "checkIn", "checkedIn", "access granted", "AVCapture", "LAContext", "LocalAuthentication",
                   "PhotosPicker", "UIImagePickerController", "VNDocumentCamera", "CLLocation", "URLSession",
                   "URLRequest", "UserDefaults", "@AppStorage", "@SceneStorage", "FileManager", "Keychain",
                   "SecItem", "print(", "NSLog", "os_log", "Logger(", "Timer", "asyncAfter", "Task.sleep",
                   "CADisplayLink", "TimelineView"]
for path in guarded_sources:
    if not os.path.isfile(path):
        problems.append("guarded source missing  " + path)
        continue
    text = open(path, encoding="utf-8").read()
    for token in guard_forbidden:
        if token in text:
            problems.append("Guest List guard: %s contains %r" % (path, token))

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
pin = os.environ.get("GUEST_LIST_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("GUEST_LIST_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but GUEST_LIST_EXPECTED_COMMIT is %s" % (head, pin))
elif os.environ.get("CM_BUILD_ID"):
    problems.append("GUEST_LIST_EXPECTED_COMMIT is unset on Codemagic: the reviewed commit is not pinned")

lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("GUEST_LIST_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
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
    print("This checkout is not the reviewed Guest List revision. Do not review it as such.")
    sys.exit(1)
PY
    summary_line "guest-list-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    prestart_smaller
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/guest-list-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/guest-list-runtimes-available.json"
    run python3 - "$META/guest-list-devices-available.json" "$META/guest-list-runtimes-available.json" \
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

# fixture <file> <fixture name> <label> [launch arguments]: relaunch on a fixture and capture
# after it settles.
fixture() {
    local file="$1" name="$2" label="$3"
    shift 3
    launch "$SIM_UDID" -ProximeetFixture "$name" ${1+"$@"} || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$SIM_UDID" "$file" "FIXTURE (-ProximeetFixture $name${1+ $*}): $label"
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
    fixture 06-guest-list-largest-text-editor.png guest-list-filled \
        "the fictional example, simctl content_size $LARGE_CONTENT_SIZE (undocumented command; unverified until the text is seen to grow)" || return 1
    fixture 07-guest-list-largest-text-card.png guest-list-card \
        "its card, simctl content_size $LARGE_CONTENT_SIZE (undocumented command; unverified until the text is seen to grow)" || return 1
    restore_content_size
}

# Starts booting the smaller iPhone now, behind the build and the main captures, so its first
# boot (minutes on a fresh machine) is not waited out later. Best effort: capture_smaller boots
# it itself if this did not.
prestart_smaller() {
    local smaller
    smaller="$(smaller_iphone)" || return 0
    [ -n "$smaller" ] || return 0
    note "Booting the smaller iPhone in the background: $(printf '%s' "$smaller" | cut -f2)."
    xcrun simctl boot "$(printf '%s' "$smaller" | cut -f1)" >> "$LOG" 2>&1 || true
}

smaller_iphone() {
    xcrun simctl list -j devices available > "$META/guest-list-simctl-devices.json"
    python3 - "$META/guest-list-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
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
    # Already booting or booted since the destinations stage, normally; shut down afterwards.
    xcrun simctl boot "$udid" >> "$LOG" 2>&1 || true
    SMALL_BOOTED_UDID="$udid"
    run xcrun simctl bootstatus "$udid" -b || return 1
    run xcrun simctl install "$udid" "$APP_PATH" || return 1
    launch "$udid" -ProximeetFixture guest-list || return 1
    sleep "$WARMUP_SMALL_SECONDS"
    launch "$udid" -ProximeetFixture guest-list-filled || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "08-guest-list-smaller-editor.png" "FIXTURE (-ProximeetFixture guest-list-filled): the fictional example on $name" || return 1
    launch "$udid" -ProximeetFixture guest-list-card || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "09-guest-list-smaller-card.png" "FIXTURE (-ProximeetFixture guest-list-card): its card on $name" || return 1
    launch "$udid" -ProximeetFixture guest-list-name-only || return 1
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "10-guest-list-smaller-name-only.png" "FIXTURE (-ProximeetFixture guest-list-name-only): a name-only card on $name" || return 1
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
    rm -f "$OUT"/[01]*-guest-list-*.png
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
    guarded gl-fix-empty fixture 01-guest-list-empty.png guest-list "the empty editor, opened from a completed Pass"
    guarded gl-fix-filled fixture 02-guest-list-filled.png guest-list-filled "the fictional Alex example"
    guarded gl-fix-card fixture 03-guest-list-card.png guest-list-card "the fictional example's card"
    guarded gl-fix-name-only fixture 04-guest-list-name-only.png guest-list-name-only "a name-only card: no opener, no interests"
    guarded gl-fix-rm fixture 05-guest-list-reduce-motion-preview-card.png guest-list-card \
        "app-level Reduce Motion preview flag, not the system setting" -ProximeetReduceMotionPreview YES
    guarded gl-fix-largetext capture_large_text
    guarded gl-fix-smaller capture_smaller
    run cat "$OUT/captures.tsv"
}

# ---------------------------------------------------------------------------------------
# ui-review
# ---------------------------------------------------------------------------------------

# export_results <xcresult> <attachments dir>
export_results() {
    local result="$1" dir="$2"
    [ -d "$result" ] || return 0
    xcrun xcresulttool get test-results summary --path "$result" > "${result%.xcresult}-summary.json" 2>>"$LOG" || true
    if xcrun xcresulttool export attachments --path "$result" --output-path "$dir" >> "$LOG" 2>&1; then
        note "Exported XCTest attachments to $dir."
    else
        note "NOTE: attachment export unavailable for $result; the per-test results are in the log and summary."
    fi
}

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    local build_status walk_status rest_status keys_status waited=0 recording_started test rest_only="" keys_only=""
    local movie="$OUT/guest-list-walkthrough-original.mp4"
    local walk_result="$OUT/GuestListWalkthrough.xcresult" rest_result="$OUT/GuestListReview.xcresult"
    local keys_result="$OUT/GuestListHardwareKeys.xcresult"
    rm -rf "$walk_result" "$rest_result" "$keys_result" "$walk_result.zip" "$rest_result.zip" "$keys_result.zip" \
        "$movie" "$movie.log" "$OUT/recording-started.txt"
    export NSUnbufferedIO=YES

    # 1. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests/GuestListReviewTests -only-testing:ProximeetUITests/PassReviewTests \
        -only-testing:ProximeetUITests/BirthdayReviewTests -only-testing:ProximeetUITests/WelcomeReviewTests \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "guest-list-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "guest-list-ui-build" "PASS (UI test harness compiled)"

    # 2. The recorded walkthrough: the recorder is confirmed active before the test starts, and
    #    the app is closed first. compact-video trims the lead-in by frame brightness.
    run xcrun simctl bootstatus "$SIM_UDID" -b || true
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
        summary_line "guest-list-recording" "confirmed active before the walkthrough"
    else
        note "WARNING: simctl did not confirm 'Recording started'; the walkthrough still runs, unrecorded."
        summary_line "guest-list-recording" "NOT CONFIRMED"
        stop_recorder
        rm -f "$movie"
    fi
    if run env TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 TEST_RUNNER_PROXIMEET_PASS_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
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

    # 3. The other Guest List tests that use only the on-screen keyboard, and the Pass, Birthday
    #    and Welcome regressions.
    for test in $GUEST_LIST_TESTS; do
        case " $GUEST_LIST_HARDWARE_KEY_TESTS " in
            *" $test "*) keys_only="$keys_only -only-testing:ProximeetUITests/GuestListReviewTests/$test" ;;
            *)
                case "$test" in
                    testWalkthrough*) ;;
                    *) rest_only="$rest_only -only-testing:ProximeetUITests/GuestListReviewTests/$test" ;;
                esac
                ;;
        esac
    done
    # shellcheck disable=SC2086
    if run env TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 TEST_RUNNER_PROXIMEET_PASS_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_BIRTHDAY_REVIEW=1 TEST_RUNNER_PROXIMEET_WELCOME_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        $rest_only \
        -only-testing:ProximeetUITests/PassReviewTests \
        -only-testing:ProximeetUITests/BirthdayReviewTests \
        -only-testing:ProximeetUITests/WelcomeReviewTests \
        -parallel-testing-enabled NO -resultBundlePath "$rest_result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
        rest_status=0
    else
        rest_status=$?
    fi
    export_results "$rest_result" "$OUT/attachments-review"

    # 4. Last, the tests that send hardware key events.
    # shellcheck disable=SC2086
    if run env TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 xcodebuild \
        -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        $keys_only \
        -parallel-testing-enabled NO -resultBundlePath "$keys_result" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
        keys_status=0
    else
        keys_status=$?
    fi
    export_results "$keys_result" "$OUT/attachments-keys"

    # 5. What actually ran, from xcodebuild's per-test lines (to a file: bash 3.2 misparses
    #    heredocs inside $( )).
    python3 - "$LOG" "$REQUIRED_PASSING_TESTS" "$OUT/ui-review-tests.txt" "$walk_status" "$rest_status" "$keys_status" \
        > "$OUT/ui-review-counts.txt" <<'PY'
import re
import sys

log, required, out_path = sys.argv[1], sys.argv[2].split(), sys.argv[3]
exits = [int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])]
outcome = {}
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?(WelcomeReviewTests|BirthdayReviewTests|PassReviewTests|GuestListReviewTests)[ ./](test\w+)(?:\(\))?\]?' (passed|failed|skipped)")
flags = {"welcome": False, "birthday": False, "pass": False, "guest-list": False}
walkthrough_start = None
for line in open(log, encoding="utf-8", errors="replace"):
    match = pattern.search(line)
    if match:
        outcome["%s.%s" % (match.group(1), match.group(2))] = match.group(3)
    for key, marker in (("welcome", "WELCOME_REVIEW_FLAG_SEEN"), ("birthday", "BIRTHDAY_REVIEW_FLAG_SEEN"),
                        ("pass", "PASS_REVIEW_FLAG_SEEN"), ("guest-list", "GUEST_LIST_REVIEW_FLAG_SEEN")):
        if marker in line:
            flags[key] = True
    started = re.search(r"GUEST_LIST_WALKTHROUGH_START (\d+(?:\.\d+)?)", line)
    if started and walkthrough_start is None:
        walkthrough_start = started.group(1)
counts = {k: sum(1 for v in outcome.values() if v == k) for k in ("passed", "failed", "skipped")}
executed = counts["passed"] + counts["failed"]
missing = [name for name in required if outcome.get(name) != "passed"]
ok = all(e == 0 for e in exits) and executed > 0 and counts["failed"] == 0 and not missing
lines = ["%s=%s" % item for item in sorted(outcome.items())]
lines += ["discovered=%d" % len(outcome), "executed=%d" % executed,
          "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
          "required_passed=" + ("yes" if not missing else "no (" + ", ".join(missing) + ")"),
          "flag_markers_in_log=" + " ".join("%s:%s" % item for item in sorted(flags.items())),
          "walkthrough_started_epoch=%s" % (walkthrough_start or "unknown"),
          "xcodebuild_exit_walkthrough=%d" % exits[0], "xcodebuild_exit_review=%d" % exits[1],
          "xcodebuild_exit_hardware_keys=%d" % exits[2],
          "result=" + ("PASS" if ok else "FAIL")]
open(out_path, "w").write("\n".join(lines) + "\n")
print("executed %d of %d discovered (passed %d, failed %d, skipped %d); required passed: %s; exits %d/%d/%d; %s"
      % (executed, len(outcome), counts["passed"], counts["failed"], counts["skipped"],
         "yes" if not missing else "no", exits[0], exits[1], exits[2], "PASS" if ok else "FAIL"))
PY
    run cat "$OUT/ui-review-tests.txt"
    summary_line "guest-list-ui-run" "$(cat "$OUT/ui-review-counts.txt")"
    grep -qx 'result=PASS' "$OUT/ui-review-tests.txt"
}

# ---------------------------------------------------------------------------------------
# compact-video
# ---------------------------------------------------------------------------------------

# A half-size re-encode of the recording, trimmed to the app (by frame brightness, with the
# walkthrough's start marker as the fallback). AVFoundation, through scripts/compact_video.swift;
# the original is untouched. If the re-encode fails, the fallback is a labelled copy.
stage_compact_video() {
    local movie="$OUT/guest-list-walkthrough-original.mp4" compact="$OUT/guest-list-walkthrough-compact.mp4"
    local start=0 marker started pid waited=0 status=1
    rm -f "$compact" "$OUT/compact-video.txt"
    if [ ! -s "$movie" ]; then
        note "No recording to compact."
        printf 'result=NOT PRODUCED (no recording)\n' > "$OUT/compact-video.txt"
        return 2
    fi
    marker="$(sed -n 's/^walkthrough_started_epoch=//p' "$OUT/ui-review-tests.txt" 2>/dev/null || true)"
    started="$(cat "$OUT/recording-started.txt" 2>/dev/null || true)"
    if [ -n "$marker" ] && [ "$marker" != "unknown" ] && [ -n "$started" ]; then
        start="$(python3 -c "import sys; print('%.2f' % max(0.0, float(sys.argv[1]) - float(sys.argv[2]) - 0.5))" "$marker" "$started")"
    fi
    note "Trim start: ${start}s (walkthrough start $marker, recording start $started)."
    xcrun swift scripts/compact_video.swift "$movie" "$compact" "$start" > "$OUT/compact-video.out" 2>> "$LOG" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 600 ]; do
        sleep 0.5
        waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        note "WARNING: the re-encode did not finish within 300 s; stopping it."
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    elif wait "$pid"; then
        status=0
    fi
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
compact = kv(os.path.join(out, "compact-video.txt"))
simulator = json.load(open(os.path.join(meta, "simulator.json"))) if os.path.isfile(os.path.join(meta, "simulator.json")) else {}
movie = os.path.join(out, "guest-list-walkthrough-original.mp4")
required = {
    "source gate (exact reviewed revision, approved assets, Guest List guard)": source.get("result") == "MATCH",
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target") == "iPhone 17 Pro Max"
        and destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "domain tests on the Mac (swift test)": passed("domain-tests"),
    "test-harness compilation (build-for-testing)": passed("guest-list-ui-build"),
    "UI tests executed and passed (Guest List, Pass, Birthday, Welcome; no required test skipped)": tests.get("result") == "PASS",
    "interaction recording confirmed and saved": last.get("guest-list-recording", "").startswith("confirmed")
        and os.path.isfile(movie) and os.path.getsize(movie) > 0,
}
lines = [
    "Guest List review verdict (automated results only; manual review is listed separately)",
    "",
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"), tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"), simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"), destination.get("selected", "?")),
    "",
    "Required automated results:",
]
lines += ["  %-92s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += ["    XCTest detail: executed %s, passed %s, failed %s, skipped %s; %s" % (
    tests.get("executed", "?"), tests.get("passed", "?"), tests.get("failed", "?"), tests.get("skipped", "?"),
    tests.get("flag_markers_in_log", "?"))]
lines += ["    " + line.strip() for line in open(os.path.join(out, "ui-review-tests.txt"))
          if line.startswith(("GuestListReviewTests.", "PassReviewTests.", "BirthdayReviewTests.", "WelcomeReviewTests."))] if os.path.isfile(os.path.join(out, "ui-review-tests.txt")) else []
lines += [
    "",
    "Supplementary (reported, not required):",
    "  DEBUG-fixture captures (not interactions): empty %s | example %s | card %s | name-only %s | Reduce Motion preview flag %s" % (
        status("gl-fix-empty"), status("gl-fix-filled"), status("gl-fix-card"), status("gl-fix-name-only"), status("gl-fix-rm")),
    "  largest text via simctl content_size (undocumented; UNVERIFIED until seen): " + status("gl-fix-largetext"),
    "  smaller iPhone: " + status("gl-fix-smaller"),
    "  compact walkthrough video: " + compact.get("result", "NOT RUN"),
    "  unsigned simulator app zip (simulator only; not installable on a device): " + status("package"),
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/guest-list-approved/reference (the founder decides)",
    "  VoiceOver: reading order, the card read once, focus after preview and edit, the limit announcements",
    "  composing input with a real input method (for example Japanese, Chinese or Korean) on a device",
    "  system Settings > Accessibility > Reduce Motion (only the app's preview flag was captured) and larger text on a device",
    "  the software and hardware keyboards on a device, and on smaller phones",
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
out_zip = os.path.join(artifacts, "Guest-List-Review.zip")
ref = os.path.join(root, "docs/design/guest-list-approved/reference")
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


board = add("approved/guest-list-review.png", os.path.join(ref, "guest-list-review.png"))
add("approved/guest-delivery.jpg", os.path.join(ref, "guest-delivery.jpg"), required=False)
compact = add("captures/guest-list-walkthrough-compact.mp4", os.path.join(out, "guest-list-walkthrough-compact.mp4"))
original = add("captures/guest-list-walkthrough-original.mp4", os.path.join(out, "guest-list-walkthrough-original.mp4"))
fixture_files = ("01-guest-list-empty.png", "02-guest-list-filled.png", "03-guest-list-card.png",
                 "04-guest-list-name-only.png", "05-guest-list-reduce-motion-preview-card.png",
                 "06-guest-list-largest-text-editor.png", "07-guest-list-largest-text-card.png",
                 "08-guest-list-smaller-editor.png", "09-guest-list-smaller-card.png", "10-guest-list-smaller-name-only.png")
fixtures = {key: add("fixtures/" + key, os.path.join(out, key), required=False) for key in fixture_files}
for key in ("verdict.txt", "ui-review-tests.txt", "destination.txt", "source-checkpoint.txt", "captures.tsv",
            "compact-video.txt", "guest-list-walkthrough-original.mp4.sha256", "guest-list-walkthrough-compact.mp4.sha256",
            "GuestListWalkthrough-summary.json", "GuestListReview-summary.json", "GuestListHardwareKeys-summary.json"):
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


shots, used = {}, set()
for folder in ("attachments-walkthrough", "attachments-review", "attachments-keys"):
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
                shots[base] = name

verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
head = kv(os.path.join(out, "source-checkpoint.txt")).get("git_head", "unknown")
compact_note = kv(os.path.join(out, "compact-video.txt")).get("result", "not produced")


def img(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (name, html.escape(caption), html.escape(caption))


def approved(index, caption):
    # The board is 1480 x 1336 at 1x, frames at x 32 / 520 / 1008, y 246; shown at 0.75.
    if not board:
        return '<p class="missing">Approved reference missing.</p>'
    x = [24, 390, 756][index]
    return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -184.5px"></div>'
            '<figcaption>%s</figcaption></figure>') % (board, x, html.escape(caption))


def shot(key, caption):
    return img(shots.get(key), caption)


def video(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>%s</figcaption>'
            '</figure>') % (name, html.escape(caption))


def row(*cells):
    return '<div class="row">%s</div>' % "".join(cells)


states = [
    ("guest-list-empty", 0, "Empty editor: Preview my card disabled"),
    ("guest-list-filled", 1, "The fictional Alex example, typed and selected by real taps"),
    ("guest-list-card", 2, "Personal card: Continue preview / Edit introduction"),
]
state_rows = "".join(row(shot(key, "This run (XCTest, real taps): " + caption), approved(index, "Approved design"))
                     for key, index, caption in states)
sections = [
    ("Walkthrough: entry, typing, chips, preview, editing, Back to Pass, re-entry, end of preview",
     row(video(compact, "Compact walkthrough (%s)" % compact_note), video(original, "Original simulator recording, unedited"))),
    ("The three states beside the approved design", state_rows),
    ("Keyboard", row(shot("guest-list-keyboard-open", "Typing the introduction: field and actions above the keyboard"),
                     shot("guest-list-keyboard-opener", "Return adds a line in the introduction"),
                     shot("guest-list-keyboard-dismissed", "Done: labels and draft kept"),
                     shot("guest-list-hardware-tab", "Hardware Tab and Shift-Tab (last state)"))),
    ("Validation and names", row(shot("guest-list-name-blank", "Blank name: gentle help, Preview waits"),
                                 shot("guest-list-validation", "121 / 120: the paste is kept, help shown, Preview waits"),
                                 shot("guest-list-name-1", "Zoë Ødegård-Nakamura (pasted with spaces)"),
                                 shot("guest-list-name-2", "김민지"), shot("guest-list-name-3", "محمد سالم"),
                                 shot("guest-list-name-4", "Punctuation kept"), shot("guest-list-name-5", "A long name: the card grows"),
                                 shot("guest-list-name-5-foot", "The long name's card, scrolled to its foot"),
                                 shot("guest-list-card-120-emoji", "120 family emoji: within the limit"))),
    ("Optional content", row(shot("guest-list-name-only-card", "Name only: no rule, no interest line"),
                             shot("guest-list-two-interests", "Two interests: check marks, not colour alone"),
                             shot("guest-list-card-two-interests", "Card: Coffee / Outdoors, separators only between them"))),
    ("Route, re-entry and the end of the preview",
     row(shot("guest-list-edit-kept", "Edit introduction: raw text and selections kept"),
         shot("guest-list-back-pass-complete", "Back: the Pass, still complete"),
         shot("guest-list-reentry-kept", "Re-entry: the draft kept"),
         shot("guest-list-endpoint", "Continue preview: “End of this preview.” with OK"),
         shot("guest-list-after-double-back", "Double tap on Back: the complete Pass, not Birthday"),
         shot("guest-list-after-relaunch-empty", "After relaunch: empty again"))),
    ("Reduce Motion (the app's preview flag, not the system setting)",
     row(shot("guest-list-reduce-motion-preview-editor", "Preview flag: editor"),
         shot("guest-list-reduce-motion-preview-card", "Preview flag: the card, stationary"))),
    ("Largest accessibility text size (XCTest)",
     row(shot("guest-list-largest-text-top", "Header and fields"), shot("guest-list-largest-text-editor-bottom", "Scrolled: chips and actions"),
         shot("guest-list-largest-text-card-top", "Card page"), shot("guest-list-largest-text-card", "The grown card"),
         shot("guest-list-largest-text-card-bottom", "Scrolled: both actions"))),
    ("Pass, Birthday and Welcome regressions",
     row(shot("pass-continue-guest-list", "Pass: Continue preview opens the Guest List"), shot("pass-complete", "Pass complete"),
         shot("birthday-continue-opens-pass", "Birthday's Continue opens Pass"), shot("welcome-default-settled", "Welcome geometry test"))),
    ("Supplementary fixture captures (not interactions)",
     row(*[img(fixtures[key], "FIXTURE: " + key[3:-4].replace("-", " ")) for key in fixture_files])),
]
body = "".join("<h2>%s</h2>%s" % (html.escape(title), content) for title, content in sections)
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Guest List review</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:330px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1002px}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:780px}</style></head><body>
<h1>Proximeet Guest List: iOS Simulator review</h1>
<p><b>%s</b></p>
<p class="note">Source <code>%s</code>. Real captures from this Codemagic simulator run (iPhone 17 Pro Max, 440 × 956 pt) next
to the unchanged approved design. Screens from XCTest come from real taps, typing and pastes; screens marked FIXTURE are
supplementary launches into a prepared state. Alex is fictional sample data. The introduction stays in memory for the run;
nothing makes anyone visible, and nothing is verified. Automated checks are not visual approval, which is the founder's
decision. The simulator app cannot be installed on an iPhone.</p>
%s
<p class="note">The largest-text fixture captures use an undocumented simulator command and are unverified until the text is
seen to grow. VoiceOver, input-method composition, the system Reduce Motion setting and on-device motion are manual checks.</p>
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
    bundle.writestr("Guest-List-Review/index.html", page)
    for name, source in entries:
        bundle.write(source, "Guest-List-Review/" + name)
print("Guest-List-Review.zip: %d files%s" % (len(entries) + 1, ("; missing: " + ", ".join(missing)) if missing else ""))

# The archive's checksum (a zip cannot hold its own) and the small separate downloads.
digest = hashlib.sha256(open(out_zip, "rb").read()).hexdigest()
open(out_zip + ".sha256", "w").write("%s  %s\n" % (digest, os.path.basename(out_zip)))
print("Guest-List-Review.zip sha256 %s" % digest)
sources = dict(entries)
try:
    simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
except (OSError, ValueError):
    simulator = {}
readme = ("%s\nProximeet Guest List, source %s. Real iOS Simulator captures from the XCTest runs (real taps, typing and "
          "pastes, not fixtures) on %s, %s. Alex is fictional sample data; nothing makes anyone visible and nothing is "
          "verified. The approved references and the full verdict (results/verdict.txt) are in Guest-List-Review.zip. "
          "Automated checks are not visual approval.\n"
          % (headline, head, simulator.get("device_name", "an unrecorded simulator"),
             simulator.get("runtime_name", "an unrecorded runtime")))
screens = [("guest-list-empty", "Guest-List-1-empty-editor-XCTest.png"),
           ("guest-list-filled", "Guest-List-2-filled-editor-XCTest.png"),
           ("guest-list-card", "Guest-List-3-personal-card-XCTest.png"),
           ("guest-list-name-only-card", "Guest-List-4-name-only-card-XCTest.png"),
           ("guest-list-validation", "Guest-List-5-validation-feedback-XCTest.png"),
           ("guest-list-endpoint", "Guest-List-6-end-of-preview-XCTest.png"),
           ("guest-list-largest-text-top", "Guest-List-7-largest-text-editor-XCTest.png"),
           ("guest-list-largest-text-card", "Guest-List-8-largest-text-card-XCTest.png"),
           ("guest-list-keyboard-open", "Guest-List-9-keyboard-open-XCTest.png")]
with zipfile.ZipFile(os.path.join(artifacts, "Guest-List-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
    bundle.writestr("README.txt", readme)
    for key, target in screens:
        name = shots.get(key)
        if name and name in sources:
            bundle.write(sources[name], target)
        else:
            bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
made = ["Guest-List-Screens.zip"]
if compact:
    label = ("Compact walkthrough: %s. Half-size re-encode, trimmed to the app by frame brightness. The unedited recording "
             "is in Guest-List-walkthrough-original.zip.\n" % compact_note)
    with zipfile.ZipFile(os.path.join(artifacts, "Guest-List-walkthrough-compact.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + label)
        bundle.write(sources[compact], "Guest-List-walkthrough-compact.mp4")
    shutil.copyfile(sources[compact], os.path.join(artifacts, "Guest-List-walkthrough-compact.mp4"))
    made += ["Guest-List-walkthrough-compact.zip", "Guest-List-walkthrough-compact.mp4"]
if original:
    with zipfile.ZipFile(os.path.join(artifacts, "Guest-List-walkthrough-original.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + "The unedited simulator recording of the walkthrough.\n")
        bundle.write(sources[original], "Guest-List-walkthrough-original.mp4")
    made.append("Guest-List-walkthrough-original.zip")
print("Separate downloads: " + ", ".join(made))
PY
    summary_line "guest-list-package" "$(unzip -l "$ARTIFACTS/Guest-List-Review.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in Guest-List-Review.zip"
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
    compact-video) stage_compact_video ;;
    verdict) stage_verdict ;;
    package-review) stage_package_review ;;
    enforce) stage_enforce ;;
esac
