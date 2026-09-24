#!/usr/bin/env bash
# Native DEBUG fixture entrances, not an interactive end-to-end test.
set -euo pipefail
if [ "$#" -ne 3 ]; then
    echo 'Usage: capture_fixture_reel.sh <simulator-udid> <bundle-id> <output.mp4>' >&2
    exit 2
fi
SIMULATOR_ID="$1"
BUNDLE_IDENTIFIER="$2"
VIDEO_PATH="$3"
mkdir -p "$(dirname "$VIDEO_PATH")"
RECORDER_PID=''
finish_recording() {
    if [ -n "$RECORDER_PID" ]; then
        kill -INT "$RECORDER_PID" 2>/dev/null || true
        wait "$RECORDER_PID" 2>/dev/null || true
        RECORDER_PID=''
    fi
}
trap finish_recording EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun simctl io "$SIMULATOR_ID" recordVideo --codec=h264 --force "$VIDEO_PATH" > "$VIDEO_PATH.log" 2>&1 &
RECORDER_PID=$!
sleep 1
kill -0 "$RECORDER_PID"
for FIXTURE_NAME in welcome band signal-selected; do
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_IDENTIFIER" \
        -ProximeetFixture "$FIXTURE_NAME" \
        -ProximeetFixtureBand social -ProximeetFixtureSignal chatFirst
    sleep 5
    kill -0 "$RECORDER_PID"
done
finish_recording
trap - EXIT INT TERM
if [ ! -s "$VIDEO_PATH" ]; then
    echo 'ERROR: simulator recorder did not create a nonempty movie.' >&2
    exit 1
fi
shasum -a 256 "$VIDEO_PATH" > "$VIDEO_PATH.sha256"
printf '%s\n' \
    'Native iOS simulator DEBUG fixture entrance reel.' \
    'Order: Welcome, Band, Signal with Social / Chat first selected.' \
    'Each scene is launched independently. This is not an interactive end-to-end walkthrough.' \
    'Recording is runtime evidence, not proof of frame rate, haptics, or accessibility compliance.' \
    > "$VIDEO_PATH.txt"
printf 'Recorded fixture entrances: %s\n' "$VIDEO_PATH"
