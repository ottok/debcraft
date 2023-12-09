#!/bin/bash

# Use environment if set, otherwise use nice defaults
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-parallel=4 nocheck noautodbgsym}"
echo "Running with DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS'"

# Use BUILD_DIRS_PATH
BUILD_ID="$(date '+%s').$COMMIT_ID+$BRANCH_NAME"

CCACHE_DIR="$BUILD_DIRS_PATH/ccache"
BUILD_DIR="$BUILD_DIRS_PATH/build-$BUILD_ID"

mkdir --verbose --parents "$CCACHE_DIR" "$BUILD_DIR"

# Run build inside a contianer image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
# just exit tty)
# NOTE!: If build fails, script fails here (due to set pipefail) and there
# will be no notifications or sounds to user.
# shellcheck disable=SC2086
podman run --name "$CONTAINER" \
    $CONTAINER_RUN_ARGS \
    --interactive --tty --rm \
    --shm-size=1G \
    --cpus=4 \
    -v "$CCACHE_DIR":/.ccache \
    -v "$BUILD_DIR":/tmp/build \
    -v "$PWD":/tmp/build/source \
    -w /tmp/build/source \
    -e CCACHE_DIR=/.ccache \
    -e DEB_BUILD_OPTIONS="$DEB_BUILD_OPTIONS" \
    -e BUILD_ID="$BUILD_ID" \
    "$CONTAINER" \
    /debcraft-runner \
    | tee "$BUILD_DIR/build-$BUILD_ID.log"


# Notify
notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg \
  --urgency=low "Build of $TARGET at $COMMIT_ID (branch $BRANCH_NAME) ready"
paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga
