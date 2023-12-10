#!/bin/bash

# Use environment if set, otherwise use nice defaults
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-parallel=4 nocheck noautodbgsym}"
log_info "Obey DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS'"

# Use BUILD_DIRS_PATH
CCACHE_DIR="$BUILD_DIRS_PATH/ccache"
BUILD_DIR="$BUILD_DIRS_PATH/debcraft-build-$PACKAGE-$BUILD_ID"

mkdir --parents "$CCACHE_DIR" "$BUILD_DIR/source"

log_info "Building package in $BUILD_DIR"

# Make sure sources are clean
if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
then
  log_info "Ensure git respository is clean and reset (including submodules)"
  git clean -fdx
  git submodule foreach --recursive git clean -fdx
  git reset --hard
  git submodule foreach --recursive git reset --hard
  git submodule update --init --recursive
fi

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Starting container $CONTAINER" >> "$BUILD_DIR/status.log"

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
# just exit tty)
# NOTE!: If build fails, script fails here (due to set pipefail) and there
# will be no notifications or sounds to user.
# shellcheck disable=SC2086
"$CONTAINER_CMD" run \
    --name "$CONTAINER" \
    --interactive --tty --rm \
    --shm-size=1G \
    --cpus=4 \
    -v "$CCACHE_DIR":/.ccache \
    -v "$BUILD_DIR":/tmp/build \
    -v "$PWD":/tmp/build/source \
    -w /tmp/build/source \
    -e CCACHE_DIR=/.ccache \
    -e DEB_BUILD_OPTIONS="$DEB_BUILD_OPTIONS" \
    $CONTAINER_RUN_ARGS \
    "$CONTAINER" \
    /debcraft-builder \
    >> "$BUILD_DIR/build.log" \
    || FAILURE="true"

#    | tee -a "$BUILD_DIR/build.log" \

if [ -n "$FAILURE" ]
then
  tail -n 50 "$BUILD_DIR"/*.log
  echo
  log_error "Build failed - see logs in $BUILD_DIR for details"
  exit 1
fi

# Use same message both on command-line and in notification
MSG="Build $BUILD_ID of $PACKAGE completed!"

echo
echo "$MSG"

# Notify
notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg --urgency=low "$MSG"
paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga
