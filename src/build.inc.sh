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
# '--volume=/...:/debcraft/source:O,upperdir=/debcraft/upper,workdir=/debcraft/workdir'

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
  # Extract package version from debian/changelog
  # This assumes PACKAGE is already set by debcraft.sh
  DEBIAN_VERSION="$(head -n 1 debian/changelog | grep --only-matching --perl-regexp '\(\K[^)]+')"
  # First, remove everything before the colon, including the colon itself
  EPOCHLESS_DEBIAN_VERSION="${DEBIAN_VERSION#*:}"
  # Then, remove everything from the first hyphen onwards.
  PACKAGE_VERSION="${EPOCHLESS_DEBIAN_VERSION%-*}"

  # Opportunistically copy the upstream tarball if it exists. Command dpkg-source
  # expects it in the parent directory of the source tree for '3.0 (quilt)'
  # format. This needs to happen before the container is run.
  #
  # Attempt to copy the tarball with any compression supported by dpkg-source
  for ext in xz gz bz2 lzma
  do
    TARBALL_PATH="../${PACKAGE}_${PACKAGE_VERSION}.orig.tar.${ext}"
    if [ -f "$TARBALL_PATH" ]
    then
      cp --verbose --no-clobber "$TARBALL_PATH" "$BUILD_DIR/"
      # Exit loop after finding and copying the first tarball
      break
    fi
  done
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
  # Local/sibling: bind-mount sources and run the builder
  CONTAINER_RUN_ARGS+=("--volume=${SOURCE_PATH}:/debcraft/source")
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

if [ -z "$COPY" ] && [ -d "$BUILD_DIR/source" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "source" directory was mounted (i.e. COPY was *not* used)
  rmdir "$BUILD_DIR/source"
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
