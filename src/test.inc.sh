#!/bin/bash

log_info "Starting interactive autopkgtest run in container for source package at $PWD"
log_info "If the test fails, investigate it and end session by typing 'exit' or press Ctrl+D."

SHELL_DIR="$(mktemp -d)"

# Define variable only used in build
CCACHE_DIR="$BUILD_DIRS_PATH/ccache"

# Create directories, including 'source' subdirectory as the container mount
# would create it anyway
mkdir --parents "$CCACHE_DIR" "$SHELL_DIR/source"

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$BUILD_DIR/previous-build"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}:/tmp/build/previous-build $EXTRA_CONTAINER_MOUNTS"
else
  log_error "No previous build found. Running autopkgtest requires packages to exist first."
  exit 1
fi

# Note use of RELEASE directory, *not* BUILD
if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous release was in ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$RELEASE_DIR/previous-release"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}:/tmp/build/previous-release $EXTRA_CONTAINER_MOUNTS"
fi

if [ -n "$DEBUG" ]
then
  set -x
fi

# See build.inc.sh for explanation of container run parameters
# shellcheck disable=SC2086
$CONTAINER_CMD run \
    --name="$CONTAINER" \
    --interactive --tty --rm \
    --shm-size=1G \
    --cap-add SYS_PTRACE \
    --volume="$CCACHE_DIR":/.ccache \
    --volume="$SHELL_DIR":/tmp/build \
    $EXTRA_CONTAINER_MOUNTS \
    --volume="${SOURCE_DIR:=$PWD}":/tmp/build/source \
    --workdir=/tmp/build/source \
    --env="CCACHE_DIR=/.ccache" \
    --env="DEB*" \
    "$CONTAINER" \
    /debcraft-tester.sh \
    || FAILURE="true"

# NOTE! Intentionally omit $CONTAINER_RUN_ARGS as this container should run as
# root so user can install/upgrade tools.

if [ -n "$DEBUG" ]
then
  set +x
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Testing found issues - please read the output above carefully"
  exit 1
fi


log_info "Testing passed"
