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
  IGNORE_NONZERO_EXIT_CODE="$3"

  ((TEST_NUMBER=TEST_NUMBER+1))

  echo "$SEPARATOR"
  echo "Executing test number $TEST_NUMBER (debcraft $COMMAND_TO_TEST)..."
  echo

  eval "$DEBCRAFT_CMD $COMMAND_TO_TEST" | tee "$TEMPDIR/test-$TEST_NUMBER.log" || RET=$?

  # Reset exit code to zero if test should not fail on it
  if [ -n "$IGNORE_NONZERO_EXIT_CODE" ]
  then
    RET=''
  fi

  # Get last line and strip colors and other ANSI codes
  TEST_OUTPUT_LAST_LINE="$(tail --lines=1 "$TEMPDIR/test-$TEST_NUMBER.log" | sed -e 's/\x1b\[[0-9;]*[mK]//g')"

  echo

  echo "Test number $TEST_NUMBER (debcraft $COMMAND_TO_TEST)"
  echo "completed with: $TEST_OUTPUT_LAST_LINE"
  echo "expected start: $EXPECTED_OUTPUT_LAST_LINE_START"

  # Note wildcard at end - the expected result only needs to match the start
  if [[ "$TEST_OUTPUT_LAST_LINE" == "$EXPECTED_OUTPUT_LAST_LINE_START"* ]] && \
     [ -z "$RET" ]
  then
    echo "TEST PASSED"
  else
    echo "ERROR: TEST FAILED (exit code $RET)"
    echo "For full test log see $TEMPDIR/test-$TEST_NUMBER.log"
    exit 1
  fi
}

TEST_CMD_PATH="$(readlink --canonicalize-existing --verbose "$0")"
DEBCRAFT_TEST_SRC_DIR="$(dirname "$TEST_CMD_PATH")"
DEBCRAFT_SRC_DIR="$(dirname "$DEBCRAFT_TEST_SRC_DIR")"
DEBCRAFT_CMD="$DEBCRAFT_SRC_DIR/debcraft.sh"

TEST_NUMBER=0

# Don't use any cache or compare to build logs from potential previous test runs
BUILD_DIRS_PATH="$(mktemp --directory)"
# Will be used inside debcraft.sh
export BUILD_DIRS_PATH

TEMPDIR="$(mktemp --directory)"

cd "$TEMPDIR" || exit 1

echo "Using directory $TEMPDIR for logs and artifacts in "

debcraft_test "help" "and https://www.debian.org/doc/debian-policy/" IGNORE_NONZERO_EXIT_CODE

# Prepare test git repository
# @TODO: Clone remote only if needed, otherwise reuse local clones
echo "$SEPARATOR" # Extra separator for test bed modifications

# Set TERM for tput in CI environments
if [ -z "${TERM:-}" ]
then
  export TERM=dumb
fi

gbp clone --pristine-tar --debian-branch=debian/latest https://salsa.debian.org/debian/entr.git
debcraft_test "build entr" "Artifacts at file:///"

cd entr

DEBCRAFT_PPA='' debcraft_test "release" "  gbp tag --verbose"

debcraft_test "build" "  browse file:///"

git clean -fdx

debcraft_test "build ." "  browse file:///"

debcraft_test "test" "Testing passed"

echo "$SEPARATOR" # Extra separator for test bed modifications
git reset --hard
git clean -fdx
rm --recursive --force --verbose .git
# Once git is deleted, there are no sources available for the build
debcraft_test "build --skip-sources" "Artifacts at file:///"

cd .. # exit 'entr' subdirectory

echo "$SEPARATOR" # Extra separator for test bed modifications
gbp clone https://salsa.debian.org/mariadb-team/galera-4.git
cd galera-4
export DEB_BUILD_OPTIONS="parallel=4 nocheck noautodbgsym"
debcraft_test "build --skip-sources --clean" "Cleaning and resetting"
export DEB_BUILD_OPTIONS=""
cd ..

# Skip remaining tests in GitLab CI
# These builds currently fail in the CI environment due to Docker-in-Docker bind
# mount limitations and lack of an tar pipe implementation to store build
# artifacts from builds so that later runs could use them.
if [ -n "${CI:-}" ]
then
  echo "Skipping tests affected by Docker-in-Docker mount issues in GitLab CI"
  exit 0
fi

mkdir hello-debhelper
cd hello-debhelper
for FILE in https://archive.debian.org/debian/pool/main/h/hello-debhelper/hello-debhelper_2.9.1.{tar.xz,dsc}
do
  curl -LO "$FILE"
done
debcraft_test "build hello-debhelper_2.9.1.dsc" "Artifacts at file:///"

# Run remaining tests from top-level
cd ..

debcraft_test "build molly-guard" "Artifacts at file:///"

debcraft_test "build https://salsa.debian.org/patryk/qnapi.git" "Artifacts at file:///"

echo "$SEPARATOR"
echo "Success! All $TEST_NUMBER Debcraft tests passed."
echo
