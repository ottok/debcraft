#!/bin/bash

# Use BUILD_DIRS_PATH
BUILD_DIR="$BUILD_DIRS_PATH/debcraft-release-$PACKAGE-$BUILD_ID"

mkdir --parents "$BUILD_DIR/source"

log_info "Building source package in $BUILD_DIR"

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
    -v "$BUILD_DIR":/tmp/build \
    -v "$PWD":/tmp/build/source \
    -w /tmp/build/source \
    $CONTAINER_RUN_ARGS \
    "$CONTAINER" \
    /debcraft-releaser \
    | tee -a "$BUILD_DIR/build.log" \
    || FAILURE="true"

#     >> "$BUILD_DIR/build.log" \

if [ -n "$FAILURE" ]
then
  tail -n 50 "$BUILD_DIR"/*.log
  echo
  log_error "Source build failed - see logs in $BUILD_DIR for details"
  exit 1
fi

# Use same message both on command-line and in notification
MSG="Source build $BUILD_ID of $PACKAGE completed!"

echo
echo "$MSG"

# Notify
notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg --urgency=low "$MSG"
paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga

echo
echo "Results visible in $BUILD_DIR"
echo "To complete the release process, please review, sign and upload:"
echo "cd $BUILD_DIR"
echo "debsign *.changes"
echo "dput *.changes"
echo "cd - # Return back to source directory"
echo "gbp tag"
echo "gbp push"
