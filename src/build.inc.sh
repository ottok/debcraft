#!/bin/bash

# Use environment if set, otherwise use nice defaults
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-parallel=4 nocheck noautodbgsym}"
log_info "Obey DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS'"

# Use BUILD_DIRS_PATH
CCACHE_DIR="$BUILD_DIRS_PATH/ccache"
# shellcheck disable=SC2153 # BUILD_DIR is defined in calling parent Debcraft
BUILD_DIR="$BUILD_DIRS_PATH/debcraft-build-$PACKAGE-$BUILD_ID"

mkdir --parents "$CCACHE_DIR" "$BUILD_DIR/source"

# Instead of plain 'chown -R' use find and only apply chmod on files that need
# it to avoid excess disk writes and ctime updates in vain. Use 'edecdir' as
# safer option to 'exec' and use the variant ending with plus so any non-zero
# exit code will be surfaced and calling script aborted.
find "$CCACHE_DIR" ! -uid "${UID}" -execdir chown --no-dereference --verbose "${UID}":"${GROUPS[0]}" {} +

log_info "Building package in $BUILD_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Starting container $CONTAINER" >> "$BUILD_DIR/status.log"

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
#   just exit tty)
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
    | tee -a "$BUILD_DIR/build.log" \
    || FAILURE="true"

# podman logs --follow --names --timestamps latest
# journalctl --output=verbose -t "$CONTAINER"
# journalctl --output=cat --lines=50 CONTAINER_ID=dd2227ee084c


# Using --userns=keep-id is slow, check if using mount flag U can help:
# https://www.redhat.com/sysadmin/rootless-podman-user-namespace-modes

# @TODO: Redirect all output to log if too verbose?
# >> "$BUILD_DIR/build.log" \

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
log_info "$MSG"

# Notify
notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg --urgency=low "$MSG"
paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga

echo
log_info "Results visible in $BUILD_DIR"
log_info "Please review the result and compare to previous build (if exists)"
log_info "You can use for example:"
log_info "  meld ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]} $BUILD_DIR &"
# @TODO: Give tips on how/what to review and across which versions (e.g.
# previous successful build on same branch, or previous release in same
# Debian/Ubuntu series)
