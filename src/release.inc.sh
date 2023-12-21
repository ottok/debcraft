#!/bin/bash

# Parameters sanity check
if [ -n "$COPY" ]
then
  log_error "Cannot proceed with 'release' if --copy is used"
  exit 1
fi

# Version control sanity check
if [ ! -d "$PWD/.git" ]
then
  log_error "Debcraft does not support doing source builds for release unless"
  log_error "version control is used (e.g. git)"
  exit 1
fi

# Create directories, including 'source' subdirectory as the container mount
# would create it anyway
mkdir --parents "$RELEASE_DIR/source"

# Note use of RELEASE directory, *not* BUILD
if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$RELEASE_DIR/previous"
  CONTAINER_RUN_ARGS=" --volume=${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}:/tmp/build/previous $CONTAINER_RUN_ARGS"
fi

log_info "Building source package for release at $RELEASE_DIR"

if [ -n "$DEBUG" ]
then
  set -x
fi

# See build.inc.sh for explanation of container run parameters
# shellcheck disable=SC2086
"$CONTAINER_CMD" run \
    --name="$CONTAINER" \
    --interactive --tty --rm \
    --shm-size=1G \
    --volume="$RELEASE_DIR":/tmp/build \
    --volume="${SOURCE_DIR:=$PWD}":/tmp/build/source \
    --workdir=/tmp/build/source \
    --env="DEB*" \
    $CONTAINER_RUN_ARGS \
    "$CONTAINER" \
    /debcraft-releaser.sh \
    || FAILURE="true"

if [ -n "$DEBUG" ]
then
  set +x
fi

if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "previous" directory was mounted
  rmdir "$RELEASE_DIR/previous"
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Source build failed - see logs in $RELEASE_DIR for details"
  exit 1
fi

echo
log_info "Artifacts at $RELEASE_DIR"

if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "To compare build artifacts with those of previous similar build you can use for example:"
  log_info "  meld ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]} $RELEASE_DIR &"
fi
