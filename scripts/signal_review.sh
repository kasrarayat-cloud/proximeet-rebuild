#!/usr/bin/env bash
# Proximeet — runtime review of the approved Signal (chapter 06) and the integration checks of its
# assignment, in the iOS Simulator. Manual and unsigned. Codemagic workflow: proximeet-signal-review
# (codemagic.yaml). See docs/verification/signal-mac-review.md.
#
#   SIGNAL_REVIEW_SCOPE=signal|regressions bash scripts/signal_review.sh <stage>
#
# Scopes (the run input SIGNAL_REVIEW_SCOPE; both run on the same pinned commit, and each result
# says which build supplied it). One scope does not fit a 28-minute build:
#   signal       Signal: the recorded full journey, all twelve states, first choices, changes,
#                no-ops, re-entry, interruptions (incl. background/resume), the endpoint, the missing
#                intent, relaunch, the Reduce Motion preview flag and the largest text size on two
#                widths; the integration checks: the
#                Birthday gate on the way back (full journey), the Guest List keyboard Back on the
#                real route and Done/Back on two phone sizes; the Wristband → Signal interaction test
#   regressions  the earlier chapters: the Wristband (its Continue preview now opens Signal), the
#                Guest List, the Pass, Birthday and Welcome (all four of its tests)
#
# Stages:
#   checkpoint    source gate. The approved assets (Welcome poses, Manrope fonts and licence, the
#                 Birthday housing, the Pass artwork, the Guest List card art, the four band
#                 artworks, the blank Signal tag, the approved references) must match
#                 docs/verification/signal-approved-files.sha256 and their handoff provenance;
#                 every other file must match docs/verification/signal-review-files.sha256 (which
#                 excludes only itself); no other file may exist; earlier deletions stay absent; the
#                 approved route's sources carry no verification, visibility, capture, network,
#                 persistence, logging or timer API, and the approved screens never use the legacy
#                 intent tint. Run inputs SIGNAL_EXPECTED_COMMIT (full 40-hex SHA) pins HEAD and
#                 SIGNAL_REVIEW_SCOPE names the scope; both required on Codemagic (CM_BUILD_ID
#                 set). Also records the time budget's start. Runs anywhere.
#   destinations  list installed simulators; report whether iPhone 17 Pro Max was selected; start
#                 the first boots of the selected simulator and of a smaller iPhone behind the
#                 compilation
#   ui-review     compile the UI test harness; clone the booted iPhone 17 Pro Max ("device B",
#                 deleted after the run, so it starts warm); run the scope's two lanes in parallel,
#                 then (signal scope) the smaller iPhone's keyboard check, largest-text test and
#                 fixture captures. The
#                 signal scope records the full journey first; the compact video is made in the
#                 background once the recording ends. Every xcodebuild is bounded by time; a failed
#                 test other than the recorded journey is retried once and reported as such. Zero
#                 executed tests, or any final failure or skip of a required test, fails the stage
#   compact-video half-size re-encode of the recording, trimmed to the app (signal scope)
#   verdict       automated results, kept apart from outstanding manual review
#   package-review  build/artifacts/Signal-Review.zip (signal) or Signal-Regressions-Review.zip
#                 (regressions), with an offline index.html; the signal scope also makes
#                 Signal-Screens.zip, Signal-walkthrough-compact.zip (and the loose .mp4 when re-encoded) and
#                 Signal-walkthrough-original.zip; each archive's SHA-256
#   enforce       fail the build unless the verdict says PASS (run last)
#
# Outputs go to build/artifacts/signal/, logs to build/artifacts/logs/signal-<stage>*.log, and
# PASS/FAIL lines to build/artifacts/summary.txt. Nothing is signed, uploaded or downloaded and no
# simulator runtime is installed. Written for the macOS system bash 3.2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="build/artifacts"
LOGS="$ARTIFACTS/logs"
META="$ARTIFACTS/metadata"
OUT="$ARTIFACTS/signal"
SUMMARY="$ARTIFACTS/summary.txt"
SIM_ENV="$META/simulator.env"
DEVICE_B_ENV="$META/signal-device-b.env"
SMALL_ENV="$META/signal-smaller.env"
T0_FILE="$META/signal-t0.txt"
SCOPE_FILE="$META/signal-scope.txt"
DERIVED_DATA="$ROOT/build/DerivedData"
DERIVED_DATA_B="$ROOT/build/DerivedDataB"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Proximeet.app"
BUNDLE_ID="com.proximeet.demo"
FROZEN_MANIFEST="docs/verification/signal-approved-files.sha256"
REVIEW_MANIFEST="docs/verification/signal-review-files.sha256"
DELETIONS="docs/verification/signal-review-deletions.txt"
CHECKPOINT_RESULT="$OUT/source-checkpoint.txt"
PRIMARY_TARGET="iPhone 17 Pro Max"
DEVICE_B_NAME="iPhone 17 Pro Max (signal review B)"
SMALLER_IPHONES="iPhone 17e|iPhone 16e|iPhone SE (3rd generation)|iPhone 17|iPhone 16|iPhone 17 Pro|iPhone 16 Pro"
# The UI work must end this many seconds after the checkpoint stage began (about a minute into the
# build), leaving the verdict, the packages and publishing inside the workflow's 28 minutes (the
# compact video is made during the UI work).
UI_DEADLINE_SECONDS=1440

# The tests. Signal scope: the selected simulator records the journey, then runs SIGNAL_MAIN_TESTS;
# device B runs SIGNAL_B_TESTS, the interaction test and both keyboard tests; the smaller iPhone the
# keyboard check and Signal's largest-text test. Regressions scope: the selected simulator runs the Wristband, Pass, Birthday and
# Welcome tests; device B the Guest List's on-screen-keyboard tests, then last its hardware-key
# tests (hardware key events can leave the simulator without its on-screen keyboard).
SIGNAL_WALKTHROUGH="testWalkthroughRealJourney"
SIGNAL_MAIN_TESTS="testAllTwelveStates testFirstChoicesChangesNoOpsAndReentry testRapidChangesAndInterruptionsStayConsistent testEndpointDuplicateTapsAndBack"
SIGNAL_B_TESTS="testAgeGateReturnJourneyBlocksForwardRoutesAndKeepsTheDrafts testRelaunchStartsWithoutAnApproach testReduceMotionPreviewAttachesAtOnce testLargestTextKeepsEveryChoiceReachable testMissingIntentKeepsSignalClosed"
INTERACTION_TESTS="testBandSignalInteraction testReducedMotionStillUpdatesImmediately"
KEYBOARD_TESTS="testKeyboardDoneAndBackStayIndependent testKeyboardBackOnTheRealRouteReturnsToTheCompletePass"
KEYBOARD_CHECK="testKeyboardDoneAndBackStayIndependent"
SMALLER_SIGNAL_TESTS="testLargestTextKeepsEveryChoiceReachable"
WRISTBAND_TESTS="testWalkthroughRouteChoicesBackReentryEndpoint testEveryChangeBetweenIntentsKeepsEverythingInAgreement testRapidChangesLeaveTheLastChoice testEndpointDuplicateTapsAndBack testRelaunchStartsUnselected testReduceMotionPreviewChangesWithoutMovement testLargestTextKeepsEveryChoiceReachable"
GUEST_LIST_TESTS="testWalkthroughEntryTypingChipsPreviewEditBackReentryEndpoint testInterestsToggleIndependentlyAndOptionalContentIsOmitted testKeyboardFocusOrderReachabilityAndDismissal testRepeatedTapsNeverDuplicateOrSkipARoute testRelaunchResetsTheDraftAndNothingIsConferred testReduceMotionPreviewKeepsTheCardStationary testLargestTextReflowsAndKeepsEverythingReachable"
GUEST_LIST_HARDWARE_KEY_TESTS="testBlankInternationalAndLongNames testOpenerLimitBoundariesAndPreservedPaste testHardwareTabAndShiftTabMoveBetweenFields"
PASS_TESTS="testWalkthroughStartFinishEndpointLeaveReentryCancelBack testGateRapidTapsWaitingAndResumeNeverAdvanceOnTheirOwn testReduceMotionPreviewKeepsThePassStationary testLargestTextKeepsTheDemoLabelWholeAndControlsReachable"
BIRTHDAY_TESTS="testWalkthroughEntryCorrectionContinueBack testTypedEntryPreservesComponentsAndKeyboard"
WELCOME_TESTS="testHonestNotices testReduceMotionPreviewLaunch testDefaultGeometry testLargestTextSize"
TEST_TIMEOUTS="-test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 360"
# One retry for a failed test (a launch timeout under load, "background assertion", cost the
# Wristband's first build a test). Every attempt is parsed and reported; only the final outcome
# counts, and exit 65 is accepted only for the run that shows the failed-then-passed test.
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
LAST_RUN_STATUS=0

STAGE="${1:-}"
case "$STAGE" in
    checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce) ;;
    *)
        echo "usage: SIGNAL_REVIEW_SCOPE=signal|regressions $0 checkpoint|destinations|ui-review|compact-video|verdict|package-review|enforce" >&2
        exit 2
        ;;
esac

mkdir -p "$LOGS" "$META" "$OUT"
LOG="$LOGS/signal-$STAGE${SIGNAL_LOG_SUFFIX:-}.log"
: > "$LOG"
# The scope recorded by the checkpoint (the checkpoint itself reads the run input).
SCOPE="$(cat "$SCOPE_FILE" 2>/dev/null || true)"
[ -n "$SCOPE" ] || SCOPE="${SIGNAL_REVIEW_SCOPE:-signal}"

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
        summary_line "signal-$STAGE" "PASS"
    else
        summary_line "signal-$STAGE" "FAIL (exit $status), see $LOG"
        echo "signal_review: stage '$STAGE' FAILED with exit $status; log: $LOG" >&2
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
        note "ERROR: $CHECKPOINT_RESULT does not say result=MATCH; run 'bash scripts/signal_review.sh checkpoint' first. Nothing is tested for an unverified source."
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
# Signal handoff's SHA256SUMS.txt covers the blank tag, the four band artworks (byte-identical to
# the Wristband's), the Manrope faces and the licence; the Guest List handoff's covers the card art;
# the Pass handoff's the pass artwork; the Birthday handoff's the housing; Welcome's
# FONT_SOURCE.json and the Birthday, Pass, Guest List and Wristband records must agree on the faces.
assets = "Proximeet/Resources/Assets.xcassets/"
provenance, bundled = {}, ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")


def sums(path):
    return dict(reversed(line.strip().split("  ", 1)) for line in open(path) if line.strip())


try:
    handoff = sums("docs/design/signal-approved/SHA256SUMS.txt")
    wristband = sums("docs/design/wristband-approved/SHA256SUMS.txt")
    guest = sums("docs/design/guest-list-approved/SHA256SUMS.txt")
    pass_sums = sums("docs/design/pass-approved/SHA256SUMS.txt")
    birthday = sums("docs/design/birthday-approved/SHA256SUMS.txt")
    provenance[assets + "SignalTag.imageset/signal-tag.png"] = handoff["assets/signal-tag.png"]
    for intent in ("Social", "Dating", "Business", "Activity"):
        name = "wristband-%s.png" % intent.lower()
        provenance[assets + "Wristband%s.imageset/%s" % (intent, name)] = handoff["assets/" + name]
        if wristband.get("assets/" + name) != handoff["assets/" + name]:
            problems.append("Signal and Wristband band records disagree  " + name)
    provenance[assets + "GuestListCard.imageset/guest-list-card.png"] = guest["assets/guest-list-card.png"]
    provenance[assets + "PassArtwork.imageset/pass-artwork.png"] = pass_sums["assets/pass-artwork.png"]
    provenance[assets + "BirthdayHousing.imageset/birthday-housing.png"] = birthday["assets/birthday-housing.png"]
    provenance[assets + "Manrope-OFL.dataset/OFL.txt"] = handoff["fonts/OFL.txt"]
    fonts = {f["file"]: f["sha256"] for f in json.load(open("docs/design/welcome-approved/FONT_SOURCE.json"))["fonts"]}
    for face in bundled:
        name = "Manrope-%s.ttf" % face
        provenance[assets + "Manrope-%s.dataset/%s" % (face, name)] = handoff["fonts/" + name]
        if any(record.get(key) != handoff["fonts/" + name] for record, key in
               ((fonts, name), (birthday, "fonts/" + name), (pass_sums, "fonts/" + name), (guest, "fonts/" + name),
                (wristband, "fonts/" + name))):
            problems.append("Welcome, Birthday, Pass, Guest List, Wristband and Signal font records disagree  " + name)
    for record, label in ((pass_sums, "Pass"), (guest, "Guest List"), (wristband, "Wristband")):
        if record.get("fonts/OFL.txt") != handoff["fonts/OFL.txt"]:
            problems.append("%s and Signal licence records disagree  fonts/OFL.txt" % label)
except (OSError, ValueError, KeyError) as error:
    problems.append("provenance records unreadable: %r" % (error,))
for name, digest in sorted(provenance.items()):
    if name not in frozen:
        problems.append("approved asset not in the frozen manifest  " + name)
    elif os.path.isfile(name) and sha256(name) != digest:
        problems.append("differs from the approved handoff  " + name)

# The approved route (Signal, Wristband, Guest List, Pass): no verification, visibility,
# membership, entitlement, presence, capture, network, persistence, logging or timer API in their
# sources. The visible sentences "You stay private until venue check-in.", "Choosing a band
# doesn't make you visible." and "No age or identity verification is performed." say what is not
# done; none is a flag.
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

# One intent mapping: the approved screens use the canonical Wristband colours and art, never the
# legacy tint (whose Social is cyan) that only the legacy, DEBUG-only later scenes still use.
for path in ("Proximeet/Scenes/SignalView.swift", "Proximeet/Scenes/WristbandView.swift"):
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

scope = os.environ.get("SIGNAL_REVIEW_SCOPE", "").strip()
if scope not in ("signal", "regressions"):
    if os.environ.get("CM_BUILD_ID") or scope:
        problems.append("SIGNAL_REVIEW_SCOPE must be 'signal' or 'regressions' (got %r)" % scope)
    scope = scope or "signal"

head = git("rev-parse", "HEAD") or "unavailable"
pin = os.environ.get("SIGNAL_EXPECTED_COMMIT", "").strip()
if pin:
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        problems.append("SIGNAL_EXPECTED_COMMIT is not a full 40-hex SHA")
    elif head != pin:
        problems.append("HEAD is %s, but SIGNAL_EXPECTED_COMMIT is %s" % (head, pin))
elif os.environ.get("CM_BUILD_ID"):
    problems.append("SIGNAL_EXPECTED_COMMIT is unset on Codemagic: the reviewed commit is not pinned")

lines = [
    "git_head=" + head,
    "git_tree=" + (git("rev-parse", "HEAD^{tree}") or "unavailable"),
    "git_branch=" + (git("rev-parse", "--abbrev-ref", "HEAD") or "unavailable"),
    "codemagic_commit=" + os.environ.get("CM_COMMIT", "unset"),
    "commit_pin=" + (("SIGNAL_EXPECTED_COMMIT=" + pin) if pin else "none (compare git_head with the reviewed SHA)"),
    "scope=" + scope,
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
    print("This checkout is not the reviewed Signal revision. Do not review it as such.")
    sys.exit(1)
PY
    sed -n 's/^scope=//p' "$CHECKPOINT_RESULT" > "$SCOPE_FILE"
    summary_line "signal-source" "$(grep '^result=' "$CHECKPOINT_RESULT") $(grep '^scope=' "$CHECKPOINT_RESULT") $(grep '^git_head=' "$CHECKPOINT_RESULT") $(grep '^commit_pin=' "$CHECKPOINT_RESULT" | cut -c1-60)"
}

# ---------------------------------------------------------------------------------------
# destinations and ui-review
# ---------------------------------------------------------------------------------------

stage_destinations() {
    load_simulator
    run xcrun simctl list devices available
    xcrun simctl list -j devices available > "$META/signal-devices-available.json"
    xcrun simctl list -j runtimes available > "$META/signal-runtimes-available.json"
    local status=0 smaller
    run python3 - "$META/signal-devices-available.json" "$META/signal-runtimes-available.json" \
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
    # tests: the selected simulator, which device B is later cloned from, and (signal scope) the
    # smaller iPhone.
    rm -f "$SMALL_ENV"
    run xcrun simctl boot "$SIM_UDID" || true
    if [ "$SCOPE" != "signal" ]; then
        note "Scope $SCOPE: no smaller iPhone is used."
        return "$status"
    fi
    smaller="$(smaller_iphone)" || smaller=""
    if [ -n "$smaller" ]; then
        printf 'SMALL_UDID=%s\nSMALL_NAME=%q\n' "$(printf '%s' "$smaller" | cut -f1)" "$(printf '%s' "$smaller" | cut -f2)" > "$SMALL_ENV"
        run xcrun simctl boot "$(printf '%s' "$smaller" | cut -f1)" || true
    else
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
    fi
    return "$status"
}

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
    xcrun simctl list -j devices available > "$META/signal-simctl-devices.json"
    python3 - "$META/signal-simctl-devices.json" "$SIM_RUNTIME_ID" "$SIM_UDID" "$SMALLER_IPHONES" <<'PY'
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
    run bounded "$seconds" env TEST_RUNNER_PROXIMEET_SIGNAL_REVIEW=1 TEST_RUNNER_PROXIMEET_WRISTBAND_REVIEW=1 \
        TEST_RUNNER_PROXIMEET_GUEST_LIST_REVIEW=1 \
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

# xcrun_run <name> <udid> <derived data> <bundle> <natural seconds> <retry yes|no> <-only-testing...>:
# one bounded run, its exit recorded in $OUT/runs.txt as "<name> <bundle> <exit> <retry>", its
# attachments exported.
lane_run() {
    local name="$1" udid="$2" derived="$3" bundle="$4" seconds="$5" retry="$6" status=0
    shift 6
    rm -rf "$OUT/$bundle.xcresult"
    if [ "$retry" = "yes" ]; then
        xctest "$udid" "$derived" "$OUT/$bundle.xcresult" "$(budget "$seconds")" "$@" || status=$?
    else
        RETRY="" xctest "$udid" "$derived" "$OUT/$bundle.xcresult" "$(budget "$seconds")" "$@" || status=$?
    fi
    printf '%s %s %s %s\n' "$name" "$bundle" "$status" "$retry" >> "$OUT/runs.txt"
    LAST_RUN_STATUS="$status"
    export_results "$OUT/$bundle.xcresult" "$OUT/attachments-$bundle"
    return 0
}

# Device B's lane for the scope, on <udid> with <derived data>.
lane_b() {
    local udid="$1" derived="$2"
    if [ "$SCOPE" = "signal" ]; then
        # shellcheck disable=SC2046
        lane_run signal_b "$udid" "$derived" SignalB 1000 yes \
            $(only SignalReviewTests $SIGNAL_B_TESTS) $(only BandSignalInteractionTests $INTERACTION_TESTS) \
            $(only GuestListReviewTests $KEYBOARD_TESTS)
    else
        # shellcheck disable=SC2046
        lane_run regressions_b "$udid" "$derived" RegressionsB 1000 yes $(only GuestListReviewTests $GUEST_LIST_TESTS)
        # shellcheck disable=SC2046
        lane_run hardware_keys_b "$udid" "$derived" GuestListHardwareKeysB 420 yes \
            $(only GuestListReviewTests $GUEST_LIST_HARDWARE_KEY_TESTS)
    fi
}

# The keyboard Done/Back check, Signal's largest-text test and three Signal fixture captures on the
# smaller iPhone (signal scope). smaller.txt records the xcodebuild exit; the verdict decides from the
# per-test results, so this summary line never says PASS on its own.
smaller_segment() {
    local udid name left
    if [ ! -f "$SMALL_ENV" ]; then
        note "No smaller iPhone from '$SMALLER_IPHONES' is installed on $SIM_RUNTIME_NAME."
        printf 'device=none installed\n' > "$OUT/smaller.txt"
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
        return 1
    fi
    note "Smaller iPhone: $name ($udid)."
    printf 'device=%s (%s)\n' "$name" "$udid" > "$OUT/smaller.txt"
    run xcrun simctl boot "$udid" || true
    BOOTED_BY_US="$BOOTED_BY_US $udid"
    run bounded "$(budget 240)" xcrun simctl bootstatus "$udid" -b || return 1
    status_bar "$udid"
    # shellcheck disable=SC2046
    lane_run smaller "$udid" "$DERIVED_DATA" KeyboardSmaller 360 yes $(only GuestListReviewTests $KEYBOARD_CHECK) \
        $(only SignalReviewTests $SMALLER_SIGNAL_TESTS)
    printf 'tests_xcodebuild_exit=%s (keyboard check and largest text; see the per-test results)\n' "$LAST_RUN_STATUS" \
        >> "$OUT/smaller.txt"
    run xcrun simctl install "$udid" "$APP_PATH" || return 1
    launch "$udid" -ProximeetFixture signal -ProximeetFixtureBand social || return 1
    sleep "$WARMUP_SMALL_SECONDS"
    guarded sig-fix-smaller-social fixture_signal "$udid" 01-signal-smaller-social-none.png "social" "" \
        "Social, no approach on $name"
    guarded sig-fix-smaller-dating fixture_signal "$udid" 02-signal-smaller-dating-chat.png "dating" "chatFirst" \
        "Dating, Chat first on $name"
    guarded sig-fix-smaller-activity fixture_signal "$udid" 03-signal-smaller-activity-hello.png "activity" "okayToSayHello" \
        "Activity, Okay to say hello on $name"
    run xcrun simctl shutdown "$udid" || true
    return 0
}

# fixture_signal <udid> <file> <band> <approach or ""> <label>: a direct launch into Signal.
fixture_signal() {
    local udid="$1" file="$2" band="$3" approach="$4" label="$5"
    if [ -n "$approach" ]; then
        launch "$udid" -ProximeetFixture signal-selected -ProximeetFixtureBand "$band" -ProximeetFixtureSignal "$approach" || return 1
    else
        launch "$udid" -ProximeetFixture signal -ProximeetFixtureBand "$band" || return 1
    fi
    sleep "$SETTLE_SECONDS"
    screenshot "$udid" "$file" "FIXTURE, direct launch (-ProximeetFixture signal${approach:+-selected}, $band${approach:+, $approach}): $label"
}

stage_ui_review() {
    require_checkpoint_match
    load_simulator
    check_app
    local build_status waited=0 recording_started b_udid="" b_log="$LOGS/signal-ui-review-device-b.log"
    local movie="$OUT/signal-walkthrough-original.mp4" walk_status=0
    rm -rf "$OUT"/*.xcresult "$OUT"/attachments-* "$movie" "$movie.log" "$OUT/recording-started.txt" \
        "$OUT/runs.txt" "$OUT/smaller.txt" "$OUT"/0*-signal-*.png "$b_log" \
        "$OUT/walkthrough-started.txt" "$OUT/compact-video.txt" "$OUT/signal-walkthrough-compact.mp4" \
        "$OUT/signal-walkthrough-compact.mp4.sha256"
    : > "$OUT/runs.txt"
    printf 'file\tsimulator\tcaptured_utc\tpixel_width\tpixel_height\tsha256\tnote\n' > "$OUT/captures.tsv"
    export NSUnbufferedIO=YES
    note "Scope: $SCOPE. UI deadline: $(remaining)s left of the ${UI_DEADLINE_SECONDS}s budget."

    # 1. Test-harness compilation (the app and ProximeetUITests), recorded on its own.
    if run bounded "$(budget 600)" xcodebuild -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
        -only-testing:ProximeetUITests \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing; then
        build_status=0
    else
        build_status=$?
    fi
    if [ "$build_status" -ne 0 ]; then
        summary_line "signal-ui-build" "FAIL (xcodebuild build-for-testing exit $build_status)"
        return 1
    fi
    summary_line "signal-ui-build" "PASS (UI test harness compiled)"

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
        summary_line "signal-device-b" "cloned $b_udid from $SIM_UDID ($SIM_NAME, $SIM_RUNTIME_NAME)"
        rm -rf "$DERIVED_DATA_B"
        if ! run cp -Rc "$DERIVED_DATA" "$DERIVED_DATA_B" && ! run ditto "$DERIVED_DATA" "$DERIVED_DATA_B"; then
            note "WARNING: the build products could not be copied for device B; everything runs on $SIM_NAME."
            b_udid=""
        fi
    else
        b_udid=""
        note "WARNING: device B could not be cloned; the tests run in sequence on $SIM_NAME."
        summary_line "signal-device-b" "NOT CLONED; tests run in sequence"
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
            note "Device B ($b_udid), scope $SCOPE."
            lane_b "$b_udid" "$DERIVED_DATA_B"
        ) &
        B_PID=$!
        summary_line "signal-parallel" "device B $b_udid runs its $SCOPE lane beside the selected simulator's"
    fi

    # 3. The selected simulator's lane.
    if [ "$SCOPE" = "signal" ]; then
        # The recorded journey: the recorder is confirmed active before the test starts, and the
        # app is closed first. It keeps its full holds and is never retried (a retry would not be
        # the recorded run); the bound leaves room for its result bundle to be written.
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
            summary_line "signal-recording" "confirmed active before the journey"
        else
            note "WARNING: simctl did not confirm 'Recording started'; the journey still runs, unrecorded."
            summary_line "signal-recording" "NOT CONFIRMED"
            stop_recorder
            rm -f "$movie"
        fi
        if run bounded "$(budget 540)" env TEST_RUNNER_PROXIMEET_SIGNAL_REVIEW=1 xcodebuild \
            -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug \
            -destination "platform=iOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED_DATA" \
            -only-testing:"ProximeetUITests/SignalReviewTests/$SIGNAL_WALKTHROUGH" -parallel-testing-enabled NO \
            $TEST_TIMEOUTS -resultBundlePath "$OUT/SignalJourney.xcresult" \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test-without-building; then
            walk_status=0
        else
            walk_status=$?
        fi
        stop_recorder
        printf 'journey SignalJourney %s no\n' "$walk_status" >> "$OUT/runs.txt"
        if [ -s "$movie" ]; then
            shasum -a 256 "$movie" > "$movie.sha256"
        fi
        export_results "$OUT/SignalJourney.xcresult" "$OUT/attachments-SignalJourney"
        # The compact video is made now, in the background, from the journey's own start marker.
        sed -n 's/.*SIGNAL_WALKTHROUGH_START \([0-9][0-9.]*\).*/\1/p' "$LOG" | head -n 1 > "$OUT/walkthrough-started.txt"
        if [ -s "$movie" ]; then
            SIGNAL_LOG_SUFFIX=-during-ui-review SIGNAL_REVIEW_SCOPE="$SCOPE" bash scripts/signal_review.sh compact-video > /dev/null 2>&1 &
            COMPACT_PID=$!
        fi
        # shellcheck disable=SC2046
        lane_run signal_main "$SIM_UDID" "$DERIVED_DATA" SignalMain 900 yes $(only SignalReviewTests $SIGNAL_MAIN_TESTS)
    else
        # shellcheck disable=SC2046
        lane_run regressions_main "$SIM_UDID" "$DERIVED_DATA" RegressionsMain 1000 yes \
            $(only WristbandReviewTests $WRISTBAND_TESTS) $(only PassReviewTests $PASS_TESTS) \
            $(only BirthdayReviewTests $BIRTHDAY_TESTS) $(only WelcomeReviewTests $WELCOME_TESTS)
    fi

    # 4. Without device B, its lane runs here, after the selected simulator's.
    if [ -z "$b_udid" ]; then
        lane_b "$SIM_UDID" "$DERIVED_DATA"
    fi

    # 5. Signal scope: the smaller iPhone (the selected simulator shuts down first to free memory).
    if [ "$SCOPE" = "signal" ]; then
        if [ -n "$b_udid" ]; then
            run xcrun simctl shutdown "$SIM_UDID" || true
        fi
        if smaller_segment; then
            summary_line "signal-smaller" "ran: $(tr '\n' ' ' < "$OUT/smaller.txt")"
        else
            summary_line "signal-smaller" "segment exit $?: $(tr '\n' ' ' < "$OUT/smaller.txt" 2>/dev/null)"
        fi
    fi

    # 6. Device B's results, and the compact video.
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
    run cat "$OUT/captures.tsv" "$OUT/runs.txt"

    # 7. What actually ran, per simulator and per run, from xcodebuild's per-test lines (to a file:
    #    bash 3.2 misparses heredocs inside $( )).
    local small_udid=""
    if [ -f "$SMALL_ENV" ]; then
        small_udid="$(sed -n 's/^SMALL_UDID=//p' "$SMALL_ENV")"
    fi
    {
        if [ "$SCOPE" = "signal" ]; then
            for t in $SIGNAL_WALKTHROUGH $SIGNAL_MAIN_TESTS; do printf 'main SignalReviewTests.%s\n' "$t"; done
            for t in $SIGNAL_B_TESTS; do printf 'b SignalReviewTests.%s\n' "$t"; done
            for t in $INTERACTION_TESTS; do printf 'b BandSignalInteractionTests.%s\n' "$t"; done
            for t in $KEYBOARD_TESTS; do printf 'b GuestListReviewTests.%s\n' "$t"; done
            for t in $KEYBOARD_CHECK; do printf 'small GuestListReviewTests.%s\n' "$t"; done
            for t in $SMALLER_SIGNAL_TESTS; do printf 'small SignalReviewTests.%s\n' "$t"; done
        else
            for t in $WRISTBAND_TESTS; do printf 'main WristbandReviewTests.%s\n' "$t"; done
            for t in $PASS_TESTS; do printf 'main PassReviewTests.%s\n' "$t"; done
            for t in $BIRTHDAY_TESTS; do printf 'main BirthdayReviewTests.%s\n' "$t"; done
            for t in $WELCOME_TESTS; do printf 'main WelcomeReviewTests.%s\n' "$t"; done
            for t in $GUEST_LIST_TESTS $GUEST_LIST_HARDWARE_KEY_TESTS; do printf 'b GuestListReviewTests.%s\n' "$t"; done
        fi
    } > "$OUT/required.txt"
    python3 - "$OUT/ui-review-tests.txt" "$OUT/required.txt" "$OUT/runs.txt" "$SIM_UDID" "$b_udid" "$small_udid" \
        "$SCOPE" "$LOG" "$b_log" > "$OUT/ui-review-counts.txt" <<'PY'
import os
import re
import sys

out_path, required_path, runs_path, main_id, b_id, small_id, scope = sys.argv[1:8]
logs = sys.argv[8:]
pattern = re.compile(r"Test [Cc]ase '(?:-\[)?(?:[\w.]*\.)?(\w+ReviewTests|BandSignalInteractionTests)[ ./](test\w+)(?:\(\))?\]?' "
                     r"(passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
outcomes, history, run_history, durations, markers = {}, {}, {}, {}, set()
walk_start = None
for path in logs:
    if not os.path.isfile(path):
        continue
    device, bundle = "unknown", None
    for line in open(path, encoding="utf-8", errors="replace"):
        started = re.search(r"^\$ .*-destination platform=iOS Simulator,id=([0-9A-F-]{36})", line)
        if started:
            device = started.group(1)
            named = re.search(r"-resultBundlePath \S*?(\w+)\.xcresult", line)
            bundle = named.group(1) if named else None
        match = pattern.search(line)
        if match:
            name = "%s.%s" % (match.group(1), match.group(2))
            key = (device, name)
            outcomes[key] = match.group(3)
            history.setdefault(key, []).append(match.group(3))
            run_history.setdefault((bundle, name), []).append(match.group(3))
            if match.group(4):
                durations[key] = match.group(4)
        for flag in ("SIGNAL", "WRISTBAND", "GUEST_LIST", "PASS", "BIRTHDAY", "WELCOME"):
            if flag + "_REVIEW_FLAG_SEEN" in line:
                markers.add(flag.lower())
        begun = re.search(r"SIGNAL_WALKTHROUGH_START (\d+(?:\.\d+)?)", line)
        if begun and walk_start is None:
            walk_start = begun.group(1)

lane_device = {"main": main_id, "b": b_id or main_id, "small": small_id}
missing = []
for line in open(required_path):
    lane, name = line.split()
    device = lane_device.get(lane)
    if not device or outcomes.get((device, name)) != "passed":
        missing.append("%s on %s" % (name, {"main": "the selected iPhone 17 Pro Max",
                                           "b": "device B" if b_id else "the selected simulator",
                                           "small": "the smaller iPhone"}[lane]))

retried_in = {bundle for (bundle, name), runs in run_history.items() if "failed" in runs[:-1] and runs[-1] == "passed"}
retried = sorted("%s[%s] %s" % (name, bundle, " then ".join(runs))
                 for (bundle, name), runs in run_history.items() if "failed" in runs[:-1])
runs = []
for line in open(runs_path):
    parts = line.split()
    if len(parts) == 4:
        runs.append(parts)
# A run's exit: 0, or 65 only when that run shows a test that failed and then passed (xcodebuild exits
# 65 when any attempt failed); never for the recorded journey, which is not retried. Anything else
# (a timeout, a skip for time, 65 without such a test) fails the stage.
bad_runs = [r for r in runs if not (r[2] == "0" or (r[2] == "65" and r[3] == "yes" and r[1] in retried_in))]
counts = {k: sum(1 for v in outcomes.values() if v == k) for k in ("passed", "failed", "skipped")}
executed = counts["passed"] + counts["failed"]
unique = {name for (_, name), outcome in outcomes.items() if outcome in ("passed", "failed")}
ok = executed > 0 and counts["failed"] == 0 and not missing and not bad_runs and runs
label = {main_id: "main", b_id: "deviceB", small_id: "smaller"}
lines = []
for (device, name), outcome in sorted(outcomes.items(), key=lambda item: (item[0][1], item[0][0])):
    runs_for = history.get((device, name), [outcome])
    lines.append("%s[%s]=%s%s%s" % (name, label.get(device, device), outcome,
                                    (" (%s s)" % durations[(device, name)]) if (device, name) in durations else "",
                                    (" after a retry: " + " then ".join(runs_for)) if "failed" in runs_for[:-1] else ""))
lines += ["scope=" + scope,
          "unique_test_cases=%d" % len(unique),
          "executions=%d" % executed,
          "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
          "required_passed=" + ("yes" if not missing else "no (" + "; ".join(missing) + ")"),
          "retried=" + ("; ".join(retried) if retried else "none"),
          "flag_markers_in_log=" + " ".join(sorted(markers)),
          "walkthrough_started_epoch=%s" % (walk_start or "unknown"),
          "devices=main %s; device B %s; smaller %s" % (main_id, b_id or "not used", small_id or "not used")]
lines += ["xcodebuild_exit_%s=%s (bundle %s, retry %s)" % (r[0], r[2], r[1], r[3]) for r in runs]
lines += ["result=" + ("PASS" if ok else "FAIL")]
open(out_path, "w").write("\n".join(lines) + "\n")
print("scope %s: %d unique cases, %d executions (passed %d, failed %d, skipped %d; %d retried after a failure); "
      "required passed: %s; runs %s; %s"
      % (scope, len(unique), executed, counts["passed"], counts["failed"], counts["skipped"], len(retried),
         "yes" if not missing else "no", ",".join("%s:%s" % (r[0], r[2]) for r in runs), "PASS" if ok else "FAIL"))
PY
    # Device B's log joins this one only now, after the parse, so no result is read twice.
    if [ -n "$b_udid" ]; then
        cat "$b_log" >> "$LOG" 2>/dev/null || true
    fi
    run cat "$OUT/ui-review-tests.txt"
    summary_line "signal-ui-run" "$(cat "$OUT/ui-review-counts.txt")"
    grep -qx 'result=PASS' "$OUT/ui-review-tests.txt"
}

# ---------------------------------------------------------------------------------------
# compact-video
# ---------------------------------------------------------------------------------------

stage_compact_video() {
    local movie="$OUT/signal-walkthrough-original.mp4" compact="$OUT/signal-walkthrough-compact.mp4"
    local start=0 marker started pid waited=0 status=1
    if [ "$SCOPE" != "signal" ]; then
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
movie = os.path.join(out, "signal-walkthrough-original.mp4")
covered = {
    "signal": "Signal: the recorded journey, all twelve states, first choices, changes, no-ops, re-entry, rapid changes, "
              "Continue, Back and background/resume during the movement, the endpoint, the missing intent, relaunch, the "
              "Reduce Motion preview flag, the largest text on two sizes; the Birthday gate on the way back; the Guest "
              "List keyboard Back on the real route and Done/Back on two sizes; the Wristband → Signal interaction test",
    "regressions": "the Wristband (Continue preview opens Signal), the Guest List, the Pass, Birthday, Welcome (all four)",
}.get(scope, "unknown scope")
required = {
    "source gate (exact reviewed revision, approved assets, Signal guard, intent colour guard)": source.get("result") == "MATCH",
    "scope recorded by the source gate matches this run (%s)" % scope: source.get("scope") == scope,
    "primary target iPhone 17 Pro Max selected": destination.get("primary_target") == "iPhone 17 Pro Max"
        and destination.get("primary_target_selected") == "yes",
    "app compilation (xcodebuild build, unsigned)": passed("build"),
    "domain tests on the Mac (swift test)": passed("domain-tests"),
    "test-harness compilation (build-for-testing)": passed("signal-ui-build"),
    "UI tests executed and passed (%s; none skipped, every run's exit accounted for)" % covered: tests.get("result") == "PASS"
        and tests.get("scope") == scope,
}
if scope == "signal":
    required["journey recording confirmed and saved"] = last.get("signal-recording", "").startswith("confirmed") \
        and os.path.isfile(movie) and os.path.getsize(movie) > 0
lines = [
    "Signal review verdict, scope '%s' (automated results only; manual review is listed separately)" % scope,
    "",
    "Build       Codemagic %s; this verdict covers only the '%s' scope's tests. The other scope runs as its own build "
    "on the same commit." % (os.environ.get("CM_BUILD_ID", "(not on Codemagic)"), scope),
    "Source      git_head=%s  commit_pin=%s" % (source.get("git_head", "?"), source.get("commit_pin", "?")),
    "Toolchain   %s, %s; iphonesimulator SDK %s" % (tools.get("xcode", "?"), tools.get("xcode_build", "?"), tools.get("iphonesimulator_sdk", "?")),
    "Simulator   %s, %s (%s)" % (simulator.get("device_name", "?"), simulator.get("runtime_name", "?"), simulator.get("runtime_build", "?")),
    "Target      primary %s installed: %s; selected: %s" % (destination.get("primary_target", "?"),
                                                            destination.get("primary_target_installed", "?"), destination.get("selected", "?")),
    "Devices     %s" % tests.get("devices", "?"),
    "Device B    %s" % status("signal-device-b"),
    "Smaller     %s" % (smaller.get("device", "not run") if scope == "signal" else "not used in this scope"),
    "",
    "Required automated results:",
]
lines += ["  %-150s %s" % (name, "PASS" if ok else "FAIL / NOT RUN") for name, ok in required.items()]
lines += ["    XCTest detail: %s unique test cases, %s executions (passed %s, failed %s, skipped %s); review flags seen: %s" % (
    tests.get("unique_test_cases", "?"), tests.get("executions", "?"), tests.get("passed", "?"), tests.get("failed", "?"),
    tests.get("skipped", "?"), tests.get("flag_markers_in_log", "?"))]
lines += ["    required: " + tests.get("required_passed", "?")]
lines += ["    retried (failed, then run once more): " + tests.get("retried", "?")]
path = os.path.join(out, "ui-review-tests.txt")
if os.path.isfile(path):
    lines += ["    " + line.strip() for line in open(path)
              if re.match(r"^\w+Tests\.test\w+\[", line) or line.startswith("xcodebuild_exit")]
lines += ["", "Supplementary (reported, not required):"]
if scope == "signal":
    lines += ["  smaller iPhone fixture captures (direct launches, not interactions): Social none %s | Dating Chat first %s | "
              "Activity Okay to say hello %s" % (status("sig-fix-smaller-social"), status("sig-fix-smaller-dating"),
                                                 status("sig-fix-smaller-activity")),
              "  compact walkthrough video: " + compact.get("result", "NOT RUN")]
lines += [
    "  unsigned simulator app zip (simulator only; not installable on a device): " + status("package"),
    "",
    "OUTSTANDING manual review (automation cannot establish these):",
    "  visual approval against docs/design/signal-approved/reference (the founder decides)",
    "  VoiceOver: the single-choice reading, the selection announcement, focus after each choice and after Back",
    "  system Settings > Accessibility > Reduce Motion (only the app's preview flag was tested), including a change "
    "during the movement (not run: XCUITest cannot change it inside a running app), and larger text on a device",
    "  landscape and iPad (the app is portrait-only on iPhone; other orientations are untested)",
    "  composing keyboards (Japanese, Chinese, Korean) and the software keyboard on a device",
    "  motion smoothness on a device (simulator recordings drop frames and have variable frame timing)",
]
ok = all(required.values())
lines += ["", "AUTOMATED VERDICT: " + ("PASS (scope %s; manual review still outstanding)" % scope if ok else "FAIL (scope %s)" % scope)]
open(os.path.join(out, "verdict.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if ok else 1)
PY
}

# ---------------------------------------------------------------------------------------
# package-review and enforce
# ---------------------------------------------------------------------------------------

stage_package_review() {
    run python3 - "$ROOT" "$OUT" "$ARTIFACTS" "$SCOPE" <<'PY'
import hashlib
import html
import json
import os
import re
import shutil
import sys
import zipfile

root, out, artifacts, scope = sys.argv[1:5]
signal = scope == "signal"
title = "Signal-Review" if signal else "Signal-Regressions-Review"
out_zip = os.path.join(artifacts, title + ".zip")
ref = os.path.join(root, "docs/design/signal-approved/reference")
intents = ("social", "dating", "business", "activity")
approaches = (("none", "no approach"), ("chat", "Chat first"), ("hello", "Okay to say hello"))
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


board = add("approved/signal-review.png", os.path.join(ref, "signal-review.png"), required=signal)
deliveries = {intent: add("approved/%s-delivery.jpg" % intent, os.path.join(ref, "%s-delivery.jpg" % intent), required=signal)
              for intent in intents}
tag_delivery = add("approved/tag-delivery.png", os.path.join(ref, "tag-delivery.png"), required=signal)
compact = add("captures/signal-walkthrough-compact.mp4", os.path.join(out, "signal-walkthrough-compact.mp4"), required=signal)
original = add("captures/signal-walkthrough-original.mp4", os.path.join(out, "signal-walkthrough-original.mp4"), required=signal)
fixture_files = ("01-signal-smaller-social-none.png", "02-signal-smaller-dating-chat.png", "03-signal-smaller-activity-hello.png")
fixtures = {key: add("fixtures/" + key, os.path.join(out, key), required=False) for key in fixture_files}
for key in sorted(os.listdir(out)) if os.path.isdir(out) else []:
    if key.endswith(("-summary.json", ".sha256")) or key in (
            "verdict.txt", "ui-review-tests.txt", "ui-review-counts.txt", "required.txt", "runs.txt", "destination.txt",
            "source-checkpoint.txt", "captures.tsv", "compact-video.txt", "smaller.txt"):
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


def walk(node, test=None):
    # xcresulttool's manifest: [{testIdentifier, attachments: [{exportedFileName, suggestedHumanReadableName, timestamp}]}]
    if isinstance(node, dict):
        test = node.get("testIdentifier", test)
        exported, readable = node.get("exportedFileName"), node.get("suggestedHumanReadableName")
        if exported and readable:
            yield str(exported), str(readable), float(node.get("timestamp") or 0), test or "?"
        for value in node.values():
            yield from walk(value, test)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value, test)


# Every screenshot and note, from every run. When a retried test attached the same name twice, the
# latest attempt's image is shown (the verdict lists every retry).
shots, stamps, notes, used = {}, {}, [], set()
folders = sorted(n for n in os.listdir(out) if n.startswith("attachments-")) if os.path.isdir(out) else []
for folder in folders:
    directory = os.path.join(out, folder)
    try:
        items = list(walk(json.load(open(os.path.join(directory, "manifest.json")))))
    except (OSError, ValueError):
        items = [(n, n, 0.0, "?") for n in sorted(os.listdir(directory))] if os.path.isdir(directory) else []
    for exported, readable, stamp, test in items:
        source = os.path.join(directory, exported)
        extension = os.path.splitext(exported)[1].lower()
        if extension not in (".png", ".jpg", ".jpeg", ".txt", ".json") or not os.path.isfile(source):
            continue
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
            if base not in shots or stamp >= stamps[base]:
                shots[base], stamps[base] = name, stamp
        elif extension == ".txt":
            notes.append("%s (%s): %s" % (test.split("/")[-1].replace("()", ""), folder.replace("attachments-", ""),
                                          read(source).strip()))

verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
head = kv(os.path.join(out, "source-checkpoint.txt")).get("git_head", "unknown")
compact_note = kv(os.path.join(out, "compact-video.txt")).get("result", "not produced")
smaller_device = kv(os.path.join(out, "smaller.txt")).get("device", "not run")
results = {}
for line in read(os.path.join(out, "ui-review-tests.txt")).splitlines():
    if re.match(r"^\w+Tests\.test\w+\[", line):
        key, _, value = line.partition("=")
        name, _, device = key.partition("[")
        results.setdefault(name, []).append("%s: %s" % (device.rstrip("]"), value))


def img(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (name, html.escape(caption), html.escape(caption))


def approved(index, caption):
    # The board is 1480 x 1570 at 1x; the three Social frames (440 x 956) sit at x 40 / 520 / 1000, y 172.
    # Shown at 0.75.
    if not board:
        return '<p class="missing">Approved reference missing.</p>'
    return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -129px"></div>'
            '<figcaption>%s</figcaption></figure>') % (board, [30, 390, 750][index], html.escape(caption))


def materials():
    # The board's row of attached tags on all four band materials (y 1240-1400), shown at 0.75.
    if not board:
        return ""
    return ('<figure><div class="materials" style="background-image:url(%s)"></div><figcaption>Approved board: the '
            'attached tag on all four band materials</figcaption></figure>') % board


def shot(key, caption):
    return img(shots.get(key), caption)


def prefixed(prefix):
    return sorted((k, v) for k, v in shots.items() if k.startswith(prefix))


def largest_text():
    # Top, choices, bottom, for each width in turn.
    order = {"top": 0, "choices": 1, "bottom": 2}
    return sorted(prefixed("signal-largest-text-"), key=lambda kv: (kv[0].split("-")[-2], order.get(kv[0].split("-")[3], 9)))


def hero(key, intent):
    # The hero: 376 x 216 at (32, 326) on the 440 x 956 screen, beside the band and tag delivery references.
    name = shots.get(key)
    left = ('<figure><div class="hero" style="background-image:url(%s)"></div><figcaption>This run: the %s band with the '
            'attached tag, Chat first (screen crop 32, 326, 376 x 216)</figcaption></figure>' % (name, intent)) if name else \
        '<p class="missing">%s hero: not produced in this run.</p>' % intent
    band = deliveries.get(intent)
    right = ('<figure><img class="delivery" src="%s" alt="approved %s band"><figcaption>Approved band delivery (540 x 260 '
             'on RGB 5,6,6)</figcaption></figure>' % (band, intent)) if band else \
        '<p class="missing">Approved %s delivery reference missing.</p>' % intent
    return '<div class="row">%s%s</div>' % (left, right)


def video(name, caption):
    if not name:
        return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
    return ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>%s</figcaption>'
            '</figure>') % (name, html.escape(caption))


def row(*cells):
    return '<div class="row">%s</div>' % "".join(cells)


def outcome(test):
    found = results.get(test)
    if found:
        return "; ".join(found)
    return "run in the other scope's build" if test.split(".")[0] in OTHER.get(scope, ()) else "not run in this build"


OTHER = {"signal": ("WristbandReviewTests", "PassReviewTests", "BirthdayReviewTests", "WelcomeReviewTests"),
         "regressions": ("SignalReviewTests", "BandSignalInteractionTests")}
findings = [
    ("Age gate on the way back",
     "Going back to Birthday and entering an under-18, incomplete, impossible, future or uncommitted date keeps every "
     "in-memory draft and blocks every forward route: Birthday's Continue, the completed Pass, the Guest List card, the "
     "Wristband and Signal, and any pushed path. Once the approved entry has been touched, an old adult date (the legacy "
     "input) cannot authorize it. Correcting the date needs an explicit Continue and opens the Pass at its intro; "
     "relaunch clears everything. The leap-day policy is unchanged.",
     ["SignalReviewTests.testAgeGateReturnJourneyBlocksForwardRoutesAndKeepsTheDrafts",
      "domain: AgeGateReturnTests (5 tests, in the swift test step)"]),
    ("One intent colour mapping",
     "Signal draws the band with the Wristband's canonical style and artwork (Social is coral). The legacy cyan Social "
     "tint is still used only by the DEBUG-only legacy scenes, and they were left unchanged. The source gate forbids "
     "the legacy tint and palette intent colours in SignalView and WristbandView. Every state's band is classified by "
     "its pixels.",
     ["SignalReviewTests.testAllTwelveStates", "source gate: intent colour guard"]),
    ("Test coverage reconciled",
     "The Guest List baseline (6ab75905) executed 20 tests. The Wristband run (6ab78983) executed 27 unique tests (28 "
     "executions) and ran only three of Welcome's four: testLargestTextSize was missing from its list. It is restored "
     "here. BandSignalInteractionTests drove the legacy band and signal screens and was rewritten for the approved "
     "flow; its retired legacy assertions are covered by the Wristband and Signal review tests. The two scopes, on the "
     "same commit, cover all 41 UI test methods (43 executions: the keyboard Done/Back check and Signal's "
     "largest-text test run on two sizes).",
     ["WelcomeReviewTests.testLargestTextSize", "BandSignalInteractionTests.testBandSignalInteraction",
      "BandSignalInteractionTests.testReducedMotionStillUpdatesImmediately"]),
    ("Guest List keyboard Back, real route",
     "The earlier guest-list-keyboard-back-corner-440pt capture came from a direct launch (the DEBUG fixture "
     "guest-list-filled). The Pass under that fixture is a new screen at its intro, which is why the capture showed the "
     "intro. Those captures are now labelled -direct-launch. A full-journey test runs Welcome → Birthday → the completed "
     "Pass → the editor. With the keyboard open, Back returns to the actual, complete Pass and the draft is kept. Done "
     "and Back stay separate on both phone sizes.",
     ["GuestListReviewTests.testKeyboardBackOnTheRealRouteReturnsToTheCompletePass",
      "GuestListReviewTests.testKeyboardDoneAndBackStayIndependent"]),
]
finding_rows = "".join(
    "<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (
        html.escape(name), html.escape(text),
        "<br>".join("%s: <b>%s</b>" % (html.escape(t), html.escape(outcome(t))) if "Tests.test" in t else html.escape(t)
                    for t in tests))
    for name, text, tests in findings)
test_rows = "".join("<tr><td>%s</td><td>%s</td></tr>" % (html.escape(t), html.escape("; ".join(r)))
                    for t, r in sorted(results.items()))

if signal:
    twelve = "".join(
        row(*[shot("signal-%s-%s-fixture" % (intent, key), "%s, %s (FIXTURE, direct launch)" % (intent.title(), label))
              for key, label in approaches])
        for intent in intents)
    sections = [
        ("Walkthrough: the real journey from Welcome, through Birthday, the Pass, the Guest List and the Wristband, into Signal",
         row(video(compact, "Compact walkthrough (%s)" % compact_note), video(original, "Original simulator recording, unedited"))),
        ("The approved design (Social) beside the real journey",
         row(shot("signal-journey-social-none", "This run (XCTest, real route): Social, no approach"),
             shot("signal-journey-social-chat", "This run: Chat first, chosen by a real tap"),
             shot("signal-journey-social-hello", "This run: Okay to say hello")) +
         row(approved(0, "Approved: no approach"), approved(1, "Approved: Chat first"), approved(2, "Approved: Okay to say hello"))),
        ("All twelve states (XCTest, direct launches into each state; geometry, pose, icon, summary and Continue checked)",
         twelve + row(materials())),
        ("The hero: band and tag against the delivery references",
         "".join(hero("signal-%s-chat-fixture" % intent, intent) for intent in intents) +
         (row('<figure><img class="tag" src="%s" alt="approved blank tag"><figcaption>Approved blank tag delivery (176 x 136, '
              'transparent)</figcaption></figure>' % tag_delivery) if tag_delivery else "")),
        ("Route, re-entry, edits and the end of the preview (real journey)",
         row(shot("signal-journey-dating-hello-kept", "Back, Dating chosen, forward: Okay to say hello kept, attached"),
             shot("signal-journey-after-edit-kept", "Guest List edited: both values kept"),
             shot("signal-journey-endpoint", "Continue preview: “End of this preview.” with OK"),
             shot("signal-after-relaunch-none", "After relaunch: no approach"))),
        ("Changes, interruptions and repeated taps (direct launches)",
         row(shot("signal-reentry-attached-fixture", "Re-entry: attached at once"),
             shot("signal-after-rapid-changes-fixture", "Rapid changes: the last choice"),
             shot("signal-after-back-during-movement-fixture", "Back during the first movement, then forward"),
             shot("signal-after-background-resume-fixture", "Background during the first movement, then resume"),
             shot("signal-endpoint-fixture", "Continue preview after repeated taps: one message"))),
        ("Reduce Motion (the app's preview flag, not the system setting)",
         row(shot("signal-reduce-motion-preview-activity-chat-fixture", "Preview flag: attached immediately"))),
        ("Largest accessibility text size (direct launches; the iPhone 17 Pro Max and the smaller iPhone, by width)",
         row(*[img(v, "Largest text, %s: %s" % (k.split("-")[-2], k.split("-")[3]))
               for k, v in largest_text()]) if largest_text()
         else '<p class="missing">Largest-text captures: not produced in this run.</p>'),
        ("Smaller iPhone (%s): supplementary direct launches, not interactions" % smaller_device,
         row(*[img(fixtures[key], "FIXTURE, direct launch: " + key[3:-4].replace("-", " ")) for key in fixture_files])),
        ("Integration: the Birthday gate on the way back (full journey)",
         row(shot("age-gate-return-under18-journey", "Back to Birthday, under 18: every forward route blocked"),
             shot("age-gate-return-pass-intro-journey", "Corrected, Continue: the Pass at its intro"),
             shot("age-gate-return-signal-kept-journey", "Forward again: the intent and approach kept"))),
        ("Integration: the Guest List keyboard Back (full journey) and Done/Back (direct launches, two sizes)",
         row(shot("guest-list-keyboard-open-full-journey", "Full journey: keyboard open in the editor"),
             shot("guest-list-keyboard-back-corner-full-journey", "Full journey: Back returns to the complete Pass")) +
         row(*[img(v, "DIRECT LAUNCH: " + k.replace("guest-list-keyboard-", "").replace("-", " "))
                for k, v in prefixed("guest-list-keyboard-done-back-") + prefixed("guest-list-keyboard-back-corner-")
                if not k.endswith("full-journey")])),
        ("Wristband → Signal interaction test (direct launch into the Wristband)",
         row(*[img(v, k) for k, v in sorted(shots.items()) if k[:3] in ("01-", "02-", "03-", "04-", "05-", "06-", "07-", "08-")])),
    ]
else:
    sections = [
        ("Wristband: its Continue preview now opens Signal",
         row(shot("wristband-empty", "Wristband: no intent"), shot("wristband-social", "Social"),
             shot("wristband-continue-signal", "Continue preview: Signal with the chosen band"),
             shot("wristband-after-double-back", "Double tap on Back: the card, once"))),
        ("Guest List, Pass, Birthday and Welcome",
         row(shot("guest-list-continue-wristband", "Guest List card: Continue preview opens the Wristband"),
             shot("guest-list-back-pass-complete", "Guest List Back: the complete Pass"),
             shot("pass-continue-guest-list", "Pass: Continue preview opens the Guest List"),
             shot("birthday-continue-opens-pass", "Birthday's Continue opens the Pass"),
             shot("welcome-default-settled", "Welcome geometry test"), shot("largest-text-top", "Welcome, largest text"))),
    ]
body = "".join("<h2>%s</h2>%s" % (html.escape(t), content) for t, content in sections)
try:
    page_simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
except (OSError, ValueError):
    page_simulator = {}
build_label = ("Codemagic build %s" % os.environ["CM_BUILD_ID"]) if os.environ.get("CM_BUILD_ID") else \
    "a simulator run outside Codemagic"
page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Signal review (%s)</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:376px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
img.delivery{width:376px;height:181px}img.tag{width:176px;height:136px;background:#050606}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1177.5px}
.materials{width:1050px;max-width:100%%;height:120px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1177.5px;background-position:-30px -930px}
.hero{width:376px;height:216px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:440px 956px;background-position:-32px -326px}
table{border-collapse:collapse;max-width:1100px}td,th{border:1px solid #333;padding:6px 8px;vertical-align:top;font-size:13px;text-align:left}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:780px}</style></head><body>
<h1>Proximeet Signal: iOS Simulator review, scope “%s”</h1>
<p><b>%s</b></p>
<p class="note">Source <code>%s</code>. Real captures from %s (%s, %s; the smaller iPhone where a caption says so or
names a width other than 440 pt).
The approved design they are compared with is unchanged. The tests were split across two builds on this same commit: “signal” and
“regressions”. This page shows one of them, and every result names the device it ran on. Captures named “journey” come
from the real route, driven by real taps and typing. Captures marked FIXTURE or DIRECT LAUNCH open a prepared state
directly. Alex is fictional sample data. The approach stays in memory for the run. Choosing one sends no Wave, opens no
chat, makes no match and grants no permission. Automated checks are not visual approval; that is the founder's decision.
The simulator app cannot be installed on an iPhone.</p>
%s
<h2>Integration findings</h2><table><tr><th>Finding</th><th>Resolution</th><th>Evidence (this build)</th></tr>%s</table>
<h2>Every test in this build</h2><table><tr><th>Test</th><th>Device: outcome (duration)</th></tr>%s</table>
<p class="note">The Reduce Motion screens use the app's preview flag, not the system setting. VoiceOver, composing
keyboards, the system Reduce Motion setting, other orientations and on-device motion are manual checks.</p>
<h2>Notes attached by the tests</h2><pre>%s</pre>
<h2>Result</h2><pre>%s</pre>
<p>Unsigned simulator app (simulator only): %s</p>
<p>Details: %s</p>
<p class="missing">%s</p>
</body></html>""" % (
    html.escape(scope), html.escape(scope), html.escape(headline), html.escape(head), html.escape(build_label),
    html.escape(page_simulator.get("device_name", "an unrecorded simulator")),
    html.escape(page_simulator.get("runtime_name", "an unrecorded runtime")), body, finding_rows, test_rows,
    html.escape("\n\n".join(notes) or "none"), html.escape(verdict),
    " ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries if n.startswith("app/") and n.endswith(".zip"))
    or "not produced",
    " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
               if n.startswith(("results/", "logs/")) or (n.startswith("xctest/") and n.endswith((".txt", ".json")))),
    ("Not produced in this run: " + ", ".join(missing)) if missing else "")

# Every relative link and image in the page must name a file in the archive.
targets = set(re.findall(r'(?:src|href)="([^"#:]+)"', page)) | set(re.findall(r"url\(([^)]+)\)", page))
packed = {n for n, _ in entries}
broken = sorted(t for t in targets if t not in packed)
if broken:
    print("BROKEN relative links in index.html: " + ", ".join(broken))
os.makedirs(artifacts, exist_ok=True)
with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
    bundle.writestr(title + "/index.html", page)
    for name, source in entries:
        bundle.write(source, title + "/" + name)
print("%s.zip: %d files, %d relative links checked, %d broken%s" % (
    title, len(entries) + 1, len(targets), len(broken), ("; missing: " + ", ".join(missing)) if missing else ""))
open(os.path.join(out, "package-links.txt"), "w").write("links=%d\nbroken=%s\n" % (len(targets), ",".join(broken) or "none"))

# The archive's checksum (a zip cannot hold its own) and the small separate downloads.
digest = hashlib.sha256(open(out_zip, "rb").read()).hexdigest()
open(out_zip + ".sha256", "w").write("%s  %s\n" % (digest, os.path.basename(out_zip)))
print("%s.zip sha256 %s" % (title, digest))
if not signal:
    sys.exit(1 if broken else 0)
sources = dict(entries)
try:
    simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
except (OSError, ValueError):
    simulator = {}
readme = ("%s\nProximeet Signal, source %s, on %s, %s. File names say where each screen came from: XCTest-journey is "
          "the real route (real taps from Welcome); XCTest-FIXTURE-direct-launch opens a prepared state directly; "
          "simctl-FIXTURE-direct-launch is a plain simulator capture after launching into a prepared state. Alex is "
          "fictional sample data; choosing an approach sends nothing and grants no permission. The approved references, "
          "the integration findings and the full verdict (results/verdict.txt) are in Signal-Review.zip. Automated "
          "checks are not visual approval.\n"
          % (headline, head, simulator.get("device_name", "an unrecorded simulator"),
             simulator.get("runtime_name", "an unrecorded runtime")))
screens = []
for number, intent in enumerate(intents):
    for index, (key, label) in enumerate(approaches):
        screens.append(("signal-%s-%s-fixture" % (intent, key),
                        "Signal-%02d-%s-%s-XCTest-FIXTURE-direct-launch.png" % (number * 3 + index + 1, intent, key)))
screens += [("signal-journey-social-none", "Signal-13-social-none-XCTest-journey.png"),
            ("signal-journey-social-chat", "Signal-14-social-chat-XCTest-journey.png"),
            ("signal-journey-social-hello", "Signal-15-social-hello-XCTest-journey.png"),
            ("signal-journey-endpoint", "Signal-16-end-of-preview-XCTest-journey.png"),
            ("age-gate-return-under18-journey", "Integration-1-age-gate-under-18-blocked-XCTest-journey.png"),
            ("age-gate-return-pass-intro-journey", "Integration-2-age-gate-corrected-pass-intro-XCTest-journey.png"),
            ("age-gate-return-signal-kept-journey", "Integration-3-age-gate-signal-kept-XCTest-journey.png"),
            ("guest-list-keyboard-open-full-journey", "Integration-4-guest-list-keyboard-open-XCTest-journey.png"),
            ("guest-list-keyboard-back-corner-full-journey", "Integration-5-guest-list-back-complete-pass-XCTest-journey.png")]
with zipfile.ZipFile(os.path.join(artifacts, "Signal-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
    bundle.writestr("README.txt", readme)
    for key, target in screens:
        name = shots.get(key)
        if name and name in sources:
            bundle.write(sources[name], target)
        else:
            bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
    for index, key in enumerate(fixture_files, start=20):
        target = "Signal-%d-smaller-iphone-%s-simctl-FIXTURE-direct-launch.png" % (index, key[3:-4].replace("signal-smaller-", ""))
        if fixtures.get(key):
            bundle.write(sources[fixtures[key]], target)
        else:
            bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
    largest = largest_text()
    for number, (key, name) in enumerate(largest, start=30):
        bundle.write(sources[name], "Signal-%d-%s-XCTest-FIXTURE-direct-launch.png" % (number, key[len("signal-"):-len("-fixture")]))
    if not largest:
        bundle.writestr("Signal-30-largest-text.MISSING.txt", "Not produced in this run.\n")
    keyboard = [(k, v) for k, v in prefixed("guest-list-keyboard-done-back-") + prefixed("guest-list-keyboard-back-corner-")
                if k.endswith("direct-launch")]
    for number, (key, name) in enumerate(keyboard, start=6):
        bundle.write(sources[name], "Integration-%d-%s-XCTest-FIXTURE.png" % (number, key))
    if not keyboard:
        bundle.writestr("Integration-6-guest-list-keyboard-direct-launch.MISSING.txt", "Not produced in this run.\n")
    if notes:
        bundle.writestr("Notes-attached-by-the-tests.txt", "\n\n".join(notes) + "\n")
made = ["Signal-Screens.zip"]
if compact:
    reencoded = compact_note == "RE-ENCODED"
    if reencoded:
        inner = "Signal-walkthrough-compact-RE-ENCODED.mp4"
        label = ("Compact walkthrough: RE-ENCODED. A half-size AVFoundation re-encode, not the original encoding, trimmed "
                 "to the app by frame brightness (the journey's start marker is the fallback). The unedited recording is "
                 "in Signal-walkthrough-original.zip.\n")
    else:
        inner = "Signal-walkthrough-FALLBACK-COPY-not-re-encoded-not-trimmed.mp4"
        label = ("Compact walkthrough: %s. The re-encode did not complete, so this is a plain copy of the unedited "
                 "recording: not re-encoded and not trimmed.\n" % compact_note)
    with zipfile.ZipFile(os.path.join(artifacts, "Signal-walkthrough-compact.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + label)
        bundle.write(sources[compact], inner)
    made.append("Signal-walkthrough-compact.zip")
    if reencoded:
        shutil.copyfile(sources[compact], os.path.join(artifacts, "Signal-walkthrough-compact.mp4"))
        made.append("Signal-walkthrough-compact.mp4")
if original:
    with zipfile.ZipFile(os.path.join(artifacts, "Signal-walkthrough-original.zip"), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme + "The unedited simulator recording of the real journey.\n")
        bundle.write(sources[original], "Signal-walkthrough-original.mp4")
    made.append("Signal-walkthrough-original.zip")
for name in made:
    path = os.path.join(artifacts, name)
    open(path + ".sha256", "w").write("%s  %s\n" % (hashlib.sha256(open(path, "rb").read()).hexdigest(), name))
print("Separate downloads: " + ", ".join(made))
sys.exit(1 if broken else 0)
PY
    local title="Signal-Review"
    [ "$SCOPE" = "signal" ] || title="Signal-Regressions-Review"
    summary_line "signal-package" "$(unzip -l "$ARTIFACTS/$title.zip" 2>/dev/null | tail -1 | awk '{print $2}') files in $title.zip; $(tr '\n' ' ' < "$OUT/package-links.txt" 2>/dev/null)"
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
