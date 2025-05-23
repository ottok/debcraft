#!/bin/bash

# Create directories, including 'source' subdirectory as the container mount
# would create it anyway
mkdir --parents "$BUILD_DIR/source"

# Copy sources if requested
if [ -n "$COPY" ]
then
  log_info "Copying sources to build directory to not pollute current directory with build artifacts"
  rsync --archive --exclude="**/.git/" "$PWD/" "$BUILD_DIR/source"
  SOURCE_DIR="$BUILD_DIR/source"
fi
# @TODO: If we want to avoid sources being polluted but not duplicate files too
# much or spend time on copying, try using overlays (but requires Podman 4.x series):
# '--volume=/...:/tmp/build/source:O,upperdir=/tmp/build/upper,workdir=/tmp/build/workdir'

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$BUILD_DIR/previous"
  CONTAINER_RUN_ARGS=" --volume=${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}:/tmp/build/previous $CONTAINER_RUN_ARGS"
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous tagged release was in ${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$BUILD_DIR/last-tagged"
  CONTAINER_RUN_ARGS=" --volume=${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}:/tmp/build/last-tagged $CONTAINER_RUN_ARGS"
fi

if [ -z "$SKIP_SOURCES" ] || [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  log_info "Building package at $BUILD_DIR"
  export DEBCRAFT_FULL_BUILD="true"
else
  log_info "Building package without creating source tarball at $BUILD_DIR"
fi

# Define variable only used in build
CCACHE_DIR="$BUILD_DIRS_PATH/ccache"
mkdir --parents "$CCACHE_DIR" "$BUILD_DIR/source"
# Instead of plain 'chown -R' use find and only apply chmod on files that need
# it to avoid excess disk writes and ctime updates in vain. Use 'execdir' as
# safer option to 'exec' and use the variant ending with plus so any non-zero
# exit code will be surfaced and calling script aborted.
find "$CCACHE_DIR" ! -uid "${UID}" -execdir chown --no-dereference --verbose "${UID}":"${GROUPS[0]}" {} +

if [ -n "$DEBUG" ]
then
  set -x
fi

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
#   just exit tty)
# --network=none to ensure build is hermetic and does not download anything
#
# Export all DEB* variables, such as DEB_BUILD_OPTIONS, DEBEMAIL, DEBNAME etc
#
# Export HOST_ARCH for cross build
#
# shellcheck disable=SC2086
$CONTAINER_CMD run \
    --name="$CONTAINER" \
    --interactive --tty --rm \
    --shm-size=1G \
    --network=none \
    --volume="$CCACHE_DIR":/.ccache \
    --volume="$BUILD_DIR":/tmp/build \
    --volume="${SOURCE_DIR:=$PWD}":/tmp/build/source \
    --workdir=/tmp/build/source \
    --env="CCACHE_DIR=/.ccache" \
    --env="DEB*" \
    --env="HOST_ARCH" \
    $CONTAINER_RUN_ARGS \
    "$CONTAINER" \
    /debcraft-builder.sh \
    || FAILURE="true"

# Intentionally do not log all output from the container. Those can be accessed
# if needed via Podman/Docker logs:
#
# podman logs --follow --names --timestamps latest
# journalctl --output=verbose -t "$CONTAINER"
# journalctl --output=cat --lines=50 CONTAINER_ID=dd2227ee084c

# @TODO: Using --userns=keep-id is slow, check if using mount flag U can help:
# https://www.redhat.com/sysadmin/rootless-podman-user-namespace-modes

# @TODO: Lintian supports build artifacts both in '..' and in '../build-area'

if [ -n "$DEBUG" ]
then
  set +x
fi

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "previous" directory was mounted
  rmdir "$BUILD_DIR/previous"
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "previous" directory was mounted
  rmdir "$BUILD_DIR/last-tagged"
fi

if [ -z "$COPY" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "source" directory was mounted (i.e. COPY was *not* used)
  rmdir "$BUILD_DIR/source"
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Build failed - see logs in file://$BUILD_DIR for details"
  exit 1
fi

# Notify must run outside container (gbp/git-notify=on with python3-notify2
# inside container fails with non-zero exit code)
if command -v notify-send >/dev/null 2>&1
then
  notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg --urgency=low "Build $BUILD_ID of $PACKAGE completed!" || true
fi
if command -v paplay >/dev/null 2>&1
then
  paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga || true
fi

echo
log_info "Artifacts at file://$BUILD_DIR"

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with those of previous similar build you can use for example:"
  log_info "  meld ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]} $BUILD_DIR &"
  if [ -f "$BUILD_DIR/diffoscope.html" ]
  then
    log_info "  browse file://$BUILD_DIR/diffoscope.html"
  fi
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with the previous tagged release run:"
  log_info "  meld ${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]} $BUILD_DIR &"
  if [ -f "$BUILD_DIR/diffoscope.html" ]
  then
    log_info "  browse file://$BUILD_DIR/diffoscope.last-tagged.html"
  fi
fi

# @TODO: Give tips on how/what to review and across which versions (e.g.
# previous successful build on same branch, or previous release in same
# Debian/Ubuntu series)

# @TODO: Remind user to visit Vcs-Browser url and contribute
