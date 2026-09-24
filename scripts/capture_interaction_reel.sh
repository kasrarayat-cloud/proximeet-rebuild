#!/usr/bin/env bash
# Runs real XCTest taps on the installed simulator while recording that same device.
# No signing, simulator clone, runtime download, network service or fixture replay.
set -euo pipefail
if [ "$#" -ne 3 ]; then
    echo 'Usage: capture_interaction_reel.sh <simulator-udid> <derived-data> <artifacts-dir>' >&2
    exit 2
fi
SIMULATOR_ID="$1"
DERIVED_DATA_PATH="$2"
ARTIFACTS_PATH="$3"
UI_PATH="$ARTIFACTS_PATH/interaction"
RESULT_PATH="$UI_PATH/BandSignal.xcresult"
VIDEO_PATH="$UI_PATH/13-band-signal-interaction.mp4"
mkdir -p "$UI_PATH"
# Unique fresh CI checkout required: preserve prior evidence if run manually twice.
if [ -e "$RESULT_PATH" ] || [ -e "$VIDEO_PATH" ]; then
    echo 'ERROR: interaction results already exist; choose a fresh artifacts directory.' >&2
    exit 2
fi

COMMON_ARGS=(
    -project Proximeet.xcodeproj -scheme Proximeet -configuration Debug
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID"
    -derivedDataPath "$DERIVED_DATA_PATH"
    -only-testing:ProximeetUITests
    -parallel-testing-enabled NO
    -maximum-concurrent-test-simulator-destinations 1
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
)
export NSUnbufferedIO=YES
# Compile the runner before recording to keep build time out of the movie.
xcodebuild "${COMMON_ARGS[@]}" build-for-testing
xcrun simctl bootstatus "$SIMULATOR_ID" -b

RECORDER_PID=''
finish_recording() {
    if [ -n "$RECORDER_PID" ]; then
        if kill -0 "$RECORDER_PID" 2>/dev/null; then
            kill -INT "$RECORDER_PID" 2>/dev/null || true
        fi
        wait "$RECORDER_PID" 2>/dev/null || true
        RECORDER_PID=''
    fi
}
trap finish_recording EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun simctl io "$SIMULATOR_ID" recordVideo --codec=h264 --force "$VIDEO_PATH" \
    > "$UI_PATH/recorder.log" 2>&1 &
RECORDER_PID=$!
sleep 1
kill -0 "$RECORDER_PID"

set +e
xcodebuild "${COMMON_ARGS[@]}" \
    -resultBundlePath "$RESULT_PATH" \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 600 \
    -maximum-test-execution-time-allowance 600 \
    test-without-building
TEST_STATUS=$?
set -e
finish_recording
trap - EXIT INT TERM

printf 'xcodebuild_exit=%s\nsimulator_udid=%s\n' "$TEST_STATUS" "$SIMULATOR_ID" \
    > "$UI_PATH/result.txt"
# Preserve the result bundle even on a failed assertion for diagnosis.
if [ -d "$RESULT_PATH" ]; then
    ditto -c -k --sequesterRsrc --keepParent "$RESULT_PATH" "$UI_PATH/BandSignal.xcresult.zip"
    if ! xcrun xcresulttool export attachments --path "$RESULT_PATH" \
        --output-path "$UI_PATH/attachments"; then
        echo 'Attachment export unavailable; screenshots remain in BandSignal.xcresult.zip.' \
            >> "$UI_PATH/result.txt"
    fi
    if ! xcrun xcresulttool get test-results summary --path "$RESULT_PATH" \
        > "$UI_PATH/test-summary.json"; then
        echo 'Test-summary export unavailable; use xcodebuild log and xcresult.' >> "$UI_PATH/result.txt"
    fi
fi
if [ ! -s "$VIDEO_PATH" ]; then
    echo 'ERROR: interaction recording is absent or empty.' >&2
    [ "$TEST_STATUS" -ne 0 ] && exit "$TEST_STATUS"
    exit 1
fi
shasum -a 256 "$VIDEO_PATH" > "$VIDEO_PATH.sha256"
printf '%s\n' \
    'Native iOS simulator recording of XCTest-driven button taps and assertions.' \
    'Tests start at the Band fixture, then change real app state through UI controls.' \
    'Includes normal-motion selection and an app-level Reduce Motion override test.' \
    'The XCTest runner may show the simulator home screen between tests.' \
    'No claim of physical-device frame rate, haptics or system accessibility verification.' \
    > "$VIDEO_PATH.txt"
echo "XCTest interaction finished with exit $TEST_STATUS."
exit "$TEST_STATUS"
