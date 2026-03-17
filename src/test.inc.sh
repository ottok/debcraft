#!/bin/bash

log_info "Starting interactive autopkgtest run in container for source package at $PWD"
log_info "If the test fails, investigate it and end session by typing 'exit' or press Ctrl+D."

SHELL_DIR="$(mktemp -d)"

# Ensure directories exist before they are mounted
mkdir --parents "$CACHE_DIR" "$BUILD_DIR/source"

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}"

  # Warn if binaries are older than latest git commit
  if [ -d "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ] && [ -n "$(find "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" -maxdepth 1 -name '*.deb' -print -quit 2>/dev/null)" ]
  then
    latest_commit_time=$(git log -1 --format=%ct 2>/dev/null)
    newest_deb_time=$(find "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" -name '*.deb' -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)

    if [ -n "$latest_commit_time" ] && [ -n "$newest_deb_time" ] && [ "$latest_commit_time" -gt "$newest_deb_time" ]
    then
      log_warn "Latest git commit is newer than built binaries"
      log_warn "Binaries built: $(date -d @"$newest_deb_time" '+%Y-%m-%d %H:%M:%S')"
      log_warn "Latest commit:  $(date -d @"$latest_commit_time" '+%Y-%m-%d %H:%M:%S')"
      log_warn "Run 'debcraft build' to test current code"
      echo
      read -r -p "Press Ctrl+C to abort, or press enter to proceed with test"
    fi
  fi

  mkdir --parents "$BUILD_DIR/previous-build"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}:/debcraft/previous-build $EXTRA_CONTAINER_MOUNTS"
else
  log_error "No previous build found. Running autopkgtest requires packages to exist first."
  exit 1
fi

# Note use of RELEASE directory, *not* BUILD
if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous release was in ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$RELEASE_DIR/previous-release"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}:/debcraft/previous-release $EXTRA_CONTAINER_MOUNTS"
fi

if [ -n "$DEBUG" ]
then
  set -x
fi

# See build.inc.sh for explanation of container run parameters
# shellcheck disable=SC2086
$CONTAINER_CMD run \
    --name="$CONTAINER" \
    --interactive \
    ${CONTAINER_CAN_HAVE_TTY:+--tty} \
    --rm \
    --shm-size=1G \
    --cap-add SYS_PTRACE \
    --volume="$CACHE_DIR":/debcraft/cache \
    --volume="$SHELL_DIR":/debcraft \
    $EXTRA_CONTAINER_MOUNTS \
    --volume="${SOURCE_DIR:=$PWD}":/debcraft/source \
    --workdir=/debcraft/source \
    --env="DEB*" \
    "$CONTAINER" \
    /debcraft-tester.sh \
    || FAILURE="true"

# NOTE! Intentionally omit $CONTAINER_RUN_ARGS as this container should run as
# root so user can install/upgrade tools.

# Regardless if running with `--debug` and if `set -x` was set or not, always
# turn it off now and in a way that does not print extra `++` prefixed lines
{ set +x; } 2>/dev/null

log_info "Test output saved to ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}/test.log"

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Test failed! Please read the output above carefully"
  exit 1
fi

log_info "Test passed!"
