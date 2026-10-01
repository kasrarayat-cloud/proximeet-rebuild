#!/bin/sh
# D2 runs once in the existing Wave build, on its Main build-for-testing host.
# Simulator test hosts do not have the repository required by these readers.
# Other workflows and the Small/test-without-building phases do no extra work.
# https://developer.apple.com/documentation/xcode/environment-variable-reference
# https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
# This wrapper is also valid in zsh, which Xcode Cloud uses for non-executable files.
set -eu

wave_workflow_id=$(printf '%s' "${CI_WORKFLOW_ID:-}" | tr '[:upper:]' '[:lower:]')
if [ "$wave_workflow_id" != '8aa8688e-79e8-4c32-8fb4-e81c0c3aa893' ]; then
    exit 0
fi
case "${CI_XCODEBUILD_ACTION:-}" in
    test-without-building) exit 0 ;;
    build-for-testing) ;;
    *) echo 'D2_FAILED: Wave workflow must use a Test action.' >&2; exit 1 ;;
esac
case "${CI_TEST_PLAN:-}" in
    WaveVerificationSmall) exit 0 ;;
    WaveVerificationMain) ;;
    *) echo 'D2_FAILED: Wave build-for-testing has no recognized test plan.' >&2; exit 1 ;;
esac

python3 - <<'PY'
import collections
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile

EXPECTED = {
    "DomainSourceGuardTests/testDomainSourcesHaveNoSideEffectAPIs",
    "DomainSourceGuardTests/testDomainImportsOnlyFoundation",
    "PlacesBackWiringTests/testEscapeIsHandledOnTheScreensContainerThroughTheSharedBack",
    "PlacesBackWiringTests/testNoControlGoesBackAroundTheSharedRoute",
    "PlacesBackWiringTests/testEveryBackControlUsesTheSharedBack",
    "PlacesRouteTests/testThePlacesSourceReadsNoClockCalendarOrLocation",
    "RoomDemoTests/testTheRetiredWaveInformationPanelIsGone",
    "WaveDemoTests/testTheSessionMirrorMatchesTheAppWiring",
}


def fail(message):
    print("D2_FAILED: " + message, file=sys.stderr, flush=True)
    raise SystemExit(1)


repository = os.environ.get("CI_PRIMARY_REPOSITORY_PATH", "")
commit = os.environ.get("CI_COMMIT", "")
if not repository:
    fail("CI_PRIMARY_REPOSITORY_PATH is missing.")
if not re.fullmatch(r"[0-9a-fA-F]{40}", commit):
    fail("CI_COMMIT must identify the complete candidate revision.")
root = Path(repository)
package = root / "ProximeetDomain"
for required in (
    package / "Package.swift",
    root / "Proximeet/App/DemoSession.swift",
    root / "Proximeet/Scenes/PlacesView.swift",
):
    if not required.is_file():
        fail("Required source file is missing: " + str(required.relative_to(root)))

test_filter = r"(^|\.)(?:" + "|".join(re.escape(name) for name in sorted(EXPECTED)) + r")$"
print("D2_BEGIN " + json.dumps({"commit": commit, "expected": 8, "host": "macOS",
                              "plan": "WaveVerificationMain"}, sort_keys=True), flush=True)
with tempfile.TemporaryDirectory(prefix="proximeet-wave-d2-") as scratch:
    command = ["xcrun", "--sdk", "macosx", "swift", "test", "--package-path", str(package),
               "--scratch-path", scratch, "--filter", test_filter]
    # Include package compilation in this limit. Kill the process group on timeout,
    # so child compilers/tests do not outlive the failed custom-script phase.
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
    except OSError as error:
        fail("Could not start the macOS Swift test command: " + str(error))
    try:
        output, _ = process.communicate(timeout=300)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        output, _ = process.communicate()
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
        fail("The macOS source-reading checks exceeded 300 seconds.")
    print(output, end="" if output.endswith("\n") else "\n", flush=True)
    if process.returncode:
        fail("The macOS Swift test command exited with status " + str(process.returncode) + ".")

events = collections.defaultdict(list)
for raw_name, event in re.findall(
    r"^Test Case '([^']+)' (started|passed|failed|skipped)(?=[ .(])", output, re.MULTILINE
):
    darwin_name = re.fullmatch(r"-\[([^ ]+) ([^ ]+)\]", raw_name)
    if darwin_name:
        class_name, method = darwin_name.groups()
        identity = class_name.rsplit(".", 1)[-1] + "/" + method
    elif "." in raw_name:
        class_name, method = raw_name.rsplit(".", 1)
        identity = class_name.rsplit(".", 1)[-1] + "/" + method
    else:
        fail("Unrecognized XCTest case identity: " + raw_name)
    events[identity].append(event)

if set(events) != EXPECTED:
    fail("Test identities differ: " + json.dumps({"missing": sorted(EXPECTED - set(events)),
                                                "unexpected": sorted(set(events) - EXPECTED)}))
invalid = {name: events[name] for name in sorted(EXPECTED) if events[name] != ["started", "passed"]}
if invalid:
    fail("Each source-reading test must start and pass exactly once: " + json.dumps(invalid))
summaries = re.findall(
    r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures? \((\d+) unexpected\)",
    output,
)
if not summaries or tuple(int(value or 0) for value in summaries[-1]) != (8, 0, 0, 0):
    fail("The final XCTest summary must report exactly eight tests, zero skips and zero failures.")
for identity in sorted(EXPECTED):
    print("D2_PASSED " + identity)
print("D2_RESULT " + json.dumps({"commit": commit, "executed": 8, "passed": 8, "failed": 0,
                               "skipped": 0, "repeated": 0}, sort_keys=True), flush=True)
PY
