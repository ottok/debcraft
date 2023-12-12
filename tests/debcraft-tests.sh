#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

function debcraft_test() {
  COMMAND_TO_TEST="$1"
  EXPECTED_OUTPUT_LAST_LINE="$2"

  ((TEST_NUMBER=TEST_NUMBER+1))

  echo "============================"
  echo "Executing test $TEST_NUMBER:"
  echo "  debcraft $COMMAND_TO_TEST"
  echo "  -> $EXPECTED_OUTPUT_LAST_LINE"
  echo "============================"
  echo

  eval "$DEBCRAFT_CMD $COMMAND_TO_TEST" | tee "$TEMPDIR/test-$TEST_NUMBER.log" || echo "WARNING: Exit code not zero"

  TEST_OUTPUT_LAST_LINE="$(tail --lines=1 "$TEMPDIR/test-$TEST_NUMBER.log")"

  # Normalize BUILD_ID
  TEST_OUTPUT_LAST_LINE="${TEST_OUTPUT_LAST_LINE/Build * of/Build BUILD_ID of}"

  echo

  if [ "$TEST_OUTPUT_LAST_LINE" == "$EXPECTED_OUTPUT_LAST_LINE" ]
  then
    echo "Test $TEST_NUMBER passed!"
  else
    echo "ERROR: Test $TEST_NUMBER failed!"
    echo "Test output last line was:"
    echo "$TEST_OUTPUT_LAST_LINE"
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


debcraft_test "help" "  --version            display version and exit"

# Prepare test git repository
#gbp clone --depth=1 --pristine-tar --debian-branch=master https://..
gbp clone --color=off --pristine-tar --debian-branch=master ~/debian/entr/pkg-entr/entr
cd entr

debcraft_test "build ." "Build BUILD_ID of entr completed!"

# Clean away git repository
git reset --hard
git clean -fdx
rm --recursive --force --verbose .git

# @TODO: The last test always fail as the debcraft-builder.sh currently uses git-buildpackage which requires a git repository
#debcraft_test "build ." "Build BUILD_ID of entr completed!"


echo "============================"
echo "Success! All $TEST_NUMBER Debcraft tests passed."
echo "============================"
echo
