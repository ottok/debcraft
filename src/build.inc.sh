#!/bin/bash

# Create directories, including 'source' subdirectory as the container mount
# would create it anyway
mkdir --parents "$BUILD_DIR/source"

# Build on a copy if requested, so that the original source directory is not
# polluted with build artifacts. Prefer a Podman overlay mount, which does not
# copy anything at all, and fall back to a shared git clone created inside the
# container for engines without overlay support (e.g. Docker).
COPY_MODE=""
if [ -n "$COPY" ]
then
  if [ "$CONTAINER_SUPPORTS_OVERLAYS" = "true" ]
  then
    # The original sources become the read-only lower layer and all build
    # writes go to an overlay upper layer that Podman keeps in its own storage
    # and destroys when the container exits. Since neither .git nor the working
    # tree are copied this is the fastest option, and the original directory is
    # guaranteed to stay untouched. Letting Podman manage the upper layer also
    # avoids the root-owned work directory that custom upperdir/workdir leaves
    # behind, which a regular user cannot remove afterwards.
    COPY_MODE="overlay"
    log_info "Building on a copy of the sources using an overlay filesystem to not pollute the current directory"
  else
    # The container creates a cheap shared git clone that reuses the object
    # database of the original repository, so the potentially very large .git
    # directory is never duplicated while git, gbp and pristine-tar keep
    # working inside the copy.
    COPY_MODE="clone"
    CONTAINER_RUN_ARGS+=("--env=COPY")
    log_info "Building on a copy of the sources to not pollute the current directory with build artifacts"
  fi
fi

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$BUILD_DIR/previous"
  CONTAINER_RUN_ARGS+=("--volume=${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}:/debcraft/previous")
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous tagged release was in ${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$BUILD_DIR/last-tagged"
  CONTAINER_RUN_ARGS+=("--volume=${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}:/debcraft/last-tagged")
fi

if [ -z "$SKIP_SOURCES" ] || [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  log_info "Building package at $BUILD_DIR"
  export DEBCRAFT_FULL_BUILD="true"
else
  log_info "Building package without creating source tarball at $BUILD_DIR"
fi

if [ -z "$SKIP_SOURCES" ]
then
  log_debug_var DEBIAN_VERSION
  log_debug_var PACKAGE_VERSION

  # Before starting the container, check that the orig tarball can be taken
  # from an existing file or pristine-tar branch, or download it if needed.
  conditional_download_orig_tarball "$PACKAGE" "$PACKAGE_VERSION"

  # Opportunistically copy the upstream tarball if it exists. Command dpkg-source
  # expects it in the parent directory of the source tree for '3.0 (quilt)'
  # format. This needs to happen before the container is run.
  #
  # Attempt to copy the tarball with any compression supported by dpkg-source
  copy_upstream_tarball "$PACKAGE" "$PACKAGE_VERSION" "$BUILD_DIR" || true
fi

# Ensure directories exist before they are mounted
mkdir --parents "$CACHE_DIR" "$BUILD_DIR/source"

# Instead of plain 'chown -R' use find and only apply chmod on files that need
# it to avoid excess disk writes and ctime updates in vain. Use 'execdir' as
# safer option to 'exec' and use the variant ending with plus so any non-zero
# exit code will be surfaced and calling script aborted.
find "$CACHE_DIR" ! -uid "${UID}" -execdir chown --no-dereference --verbose "${UID}":"${GROUPS[0]}" {} +

if [ -n "$DEBUG" ]
then
  set -x
fi

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically (but don't use it in CI!)
# --interactive needed for Ctrl+C to cancel build and stop container (and not
#   just exit tty), and also for CI to be able to pipe tar contents
# --network=none to ensure build is hermetic and does not download anything
#
# Export all DEB* variables, such as DEB_BUILD_OPTIONS, DEBEMAIL, DEBNAME etc
#
# Export HOST_ARCH for cross build
#
# shellcheck disable=SC2191
CONTAINER_RUN_ARGS+=(
  --name="$CONTAINER"
  --interactive
  --rm
  --shm-size=1G
  --network=none
  --volume="$CACHE_DIR":/debcraft/cache
  --volume="$BUILD_DIR":/debcraft
  --workdir=/debcraft/source
  --env="DEB*"
  --env="HOST_ARCH"
)

# Mount current path as sources unless defined otherwise
SOURCE_PATH="${SOURCE_DIR:-$PWD}"

if [[ "${DOCKER_HOST:-}" == tcp://* ]]
then
  # DinD: daemon can not see $PWD -> stream sources via tar, then run the builder
  tar -C "$SOURCE_PATH" -cf - . | \
    "$CONTAINER_CMD" run \
      "${CONTAINER_RUN_ARGS[@]}" \
      "$CONTAINER" \
    bash -lc 'mkdir -p /debcraft/source && tar -C /debcraft/source -xf - && /debcraft-builder.sh' \
    || FAILURE=true
else
  # Local/sibling: bind-mount sources and run the builder.
  if [ "$COPY_MODE" = "overlay" ]
  then
    # Mount the original sources as the read-only lower layer of a temporary
    # Podman-managed overlay so that all modifications are discarded when the
    # container exits
    CONTAINER_RUN_ARGS+=("--volume=${SOURCE_PATH}:/debcraft/source:O")
  elif [ -n "$COPY" ]
  then
    # The clone is created inside the container, so the original sources are
    # only ever read and can be mounted read-only.
    CONTAINER_RUN_ARGS+=("--volume=${SOURCE_PATH}:/debcraft/source:ro")
  else
    CONTAINER_RUN_ARGS+=("--volume=${SOURCE_PATH}:/debcraft/source")
  fi
  "$CONTAINER_CMD" run \
    --tty \
    "${CONTAINER_RUN_ARGS[@]}" \
    "$CONTAINER" \
    /debcraft-builder.sh \
    || FAILURE=true
fi

# Intentionally do not log all output from the container. Those can be accessed
# if needed via Podman/Docker logs:
#
# podman logs --follow --names --timestamps latest
# journalctl --output=verbose -t "$CONTAINER"
# journalctl --output=cat --lines=50 CONTAINER_ID=dd2227ee084c

# @TODO: Using --userns=keep-id is slow, check if using mount flag U can help:
# https://www.redhat.com/sysadmin/rootless-podman-user-namespace-modes

# @TODO: Lintian supports build artifacts both in '..' and in '../build-area'

# Regardless if running with `--debug` and if `set -x` was set or not, always
# turn it off now and in a way that does not print extra `++` prefixed lines
{ set +x; } 2>/dev/null

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

if [ -n "$COPY" ] && [ -d "$BUILD_DIR/copy" ]
then
  # Clean up the copy of the sources to save space after build completes
  rm -rf "$BUILD_DIR/copy"
fi

if [ -d "$BUILD_DIR/source" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "source" directory was mounted
  rmdir "$BUILD_DIR/source" || true
fi

# Clean up temporary mount directorie from polluting build artifacts, but
# only if they exist (they might not exists when running inside DinD in CI)
if [ -d "$BUILD_DIR/cache" ]
then
  rmdir "$BUILD_DIR/cache"
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Build failed - see logs in $(clickable_link "$BUILD_DIR") for details"
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
log_info "Artifacts at $(clickable_link "$BUILD_DIR")"

if [ "$DEBCRAFT_RELEASE_TO" ]
then
  echo
  log_info "Making built packages available in $DEBCRAFT_RELEASE_TO"
  mkdir --parents "$DEBCRAFT_RELEASE_TO"
  for i in "$BUILD_DIR"/*.deb
  do
    cp --verbose "$i" "$DEBCRAFT_RELEASE_TO"/
  done
fi

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with those of previous similar build you can use for example:"
  log_info "  meld ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]} $BUILD_DIR &"
  if [ -f "$BUILD_DIR/diffoscope.previous.html" ]
  then
    log_info "  browse $(clickable_link "$BUILD_DIR/diffoscope.previous.html")"
  fi
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with the previous tagged release run:"
  log_info "  meld ${LAST_TAGGED_SUCCESSFUL_BUILD_DIRS[0]} $BUILD_DIR &"
  if [ -f "$BUILD_DIR/diffoscope.last-tagged.html" ]
  then
    log_info "  browse $(clickable_link "$BUILD_DIR/diffoscope.last-tagged.html")"
  fi
fi

# @TODO: Give tips on how/what to review and across which versions (e.g.
# previous successful build on same branch, or previous release in same
# Debian/Ubuntu series)

# @TODO: Remind user to visit Vcs-Browser url and contribute
