#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Get screen width from tput, pad with space and put '=' in with sed
SEPARATOR="$(printf "%$(tput cols)s" | sed 's/ /=/g')"

function debcraft_test() {
  COMMAND_TO_TEST="$1"
  EXPECTED_OUTPUT_LAST_LINE_START="$2"

  ((TEST_NUMBER=TEST_NUMBER+1))

  echo "$SEPARATOR"
  echo "Executing test number $TEST_NUMBER (debcraft $COMMAND_TO_TEST)..."
  echo

  eval "$DEBCRAFT_CMD $COMMAND_TO_TEST" | tee "$TEMPDIR/test-$TEST_NUMBER.log" || echo "WARNING: Exit code not zero"
  RET=$?

  # Get last line and strip colors and other ANSI codes
  TEST_OUTPUT_LAST_LINE="$(tail --lines=1 "$TEMPDIR/test-$TEST_NUMBER.log" | sed -e 's/\x1b\[[0-9;]*[mK]//g')"

  echo

  echo "Test number $TEST_NUMBER (debcraft $COMMAND_TO_TEST)"
  echo "completed with: $TEST_OUTPUT_LAST_LINE"
  echo "expected start: $EXPECTED_OUTPUT_LAST_LINE_START"

  # Note wildcard at end - the expected result only needs to match the start
  if [[ "$TEST_OUTPUT_LAST_LINE" == "$EXPECTED_OUTPUT_LAST_LINE_START_START"* ]] && \
     [[ "$RET" == 0 ]]
  then
    echo "TEST PASSED"
  else
    echo "ERROR: TEST FAILED"
    echo "Exit code: $RET"
    echo "For full test log see $TEMPDIR/test-$TEST_NUMBER.log"
    exit 1
  fi
}

TEST_CMD_PATH="$(readlink --canonicalize-existing --verbose "$0")"
DEBCRAFT_TEST_SRC_DIR="$(dirname "$TEST_CMD_PATH")"
DEBCRAFT_SRC_DIR="$(dirname "$DEBCRAFT_TEST_SRC_DIR")"
DEBCRAFT_CMD="$DEBCRAFT_SRC_DIR/debcraft.sh"

TEST_NUMBER=0

TEMPDIR="$(mktemp --directory)"

cd "$TEMPDIR" || exit 1

echo "Using directory $TEMPDIR for logs and artifacts in "

debcraft_test "help" "and https://www.debian.org/doc/debian-policy/"

# Prepare test git repository
# @TODO: Clone remote only if needed, otherwise reuse local clones
echo "$SEPARATOR" # Extra separator for test bed modifications
gbp clone --pristine-tar --debian-branch=master ~/debian/entr/pkg-entr/entr
debcraft_test "build entr" "Artifacts at"

echo "$SEPARATOR" # Extra separator for test bed modifications
cd entr
git clean -fdx
debcraft_test "build" "  meld /tmp"

echo "$SEPARATOR" # Extra separator for test bed modifications
git clean -fdx
debcraft_test "build ." "  meld /tmp"

echo "$SEPARATOR" # Extra separator for test bed modifications
git reset --hard
git clean -fdx
rm --recursive --force --verbose .git
debcraft_test "build" "  meld /tmp"

# Run remaining tests from top-level
cd ..

debcraft_test "build molly-guard" "Artifacts at"

debcraft_test "build https://salsa.debian.org/patryk/libnitrokey.git" "Artifacts at"

echo "$SEPARATOR"
echo "Success! All $TEST_NUMBER Debcraft tests passed."
echo
