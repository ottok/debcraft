#!/bin/bash

# Create directories, including 'source' subdirectory as the container mount
# would create it anyway
mkdir --parents "$RELEASE_DIR/source"

# Version control sanity check
if [ ! -d "$PWD/.git" ]
then
  log_error "Debcraft does not support doing source builds for release unless"
  log_error "version control is used (e.g. git)"
  exit 1
fi

# Parameters sanity check
if [ -n "$COPY" ]
then
  log_error "Cannot proceed with 'release' if --copy is used"
  exit 1
fi

# Note use of RELEASE directory, *not* BUILD
if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous release was in ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$RELEASE_DIR/previous"
  CONTAINER_RUN_ARGS+=("--volume=${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}:/debcraft/previous")
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous tagged release was in ${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$RELEASE_DIR/last-tagged"
  CONTAINER_RUN_ARGS+=("--volume=${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]}:/debcraft/last-tagged")
fi

if [ -n "$WITH_BINARIES" ] || [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  log_info "Building full package with source and binaries (e.g. for release into NEW) at $RELEASE_DIR"
  export DEBCRAFT_FULL_BUILD="true"
else
  log_info "Building source package for release at $RELEASE_DIR"
fi

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
    cp --verbose --update=none "$TARBALL_PATH" "$RELEASE_DIR/"
    # Exit loop after finding and copying the first tarball
    break
  fi
done

# Ensure directories exist before they are mounted
mkdir --parents "$CACHE_DIR" "$RELEASE_DIR/source"

# Instead of plain 'chown -R' use find and only apply chmod on files that need
# it to avoid excess disk writes and ctime updates in vain. Use 'execdir' as
# safer option to 'exec' and use the variant ending with plus so any non-zero
# exit code will be surfaced and calling script aborted.
find "$CACHE_DIR" ! -uid "${UID}" -execdir chown --no-dereference --verbose "${UID}":"${GROUPS[0]}" {} +

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
    --network=none \
    --volume="$CACHE_DIR":/debcraft/cache \
    --volume="$RELEASE_DIR":/debcraft \
    --volume="${SOURCE_DIR:=$PWD}":/debcraft/source \
    --workdir=/debcraft/source \
    --env="DEB*" \
    "${CONTAINER_RUN_ARGS[@]}" \
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

if [ -n "${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  # Clean up temporary mount directory from polluting build artifacts
  # if a "previous" directory was mounted
  rmdir "$RELEASE_DIR/last-tagged"
fi


# Clean up temporary mount directorie from polluting build artifacts, but
# only if they exist (they might not exists when running inside DinD in CI)
if [ -d "$RELEASE_DIR/source" ]
then
  rmdir "$RELEASE_DIR/source"
fi

if [ -d "$RELEASE_DIR/cache" ]
then
  rmdir "$RELEASE_DIR/cache"
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Source build failed - see logs in $(clickable_link "$RELEASE_DIR") for details"
  exit 1
fi

echo
log_info "Artifacts at $(clickable_link "$RELEASE_DIR")"

if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with those of previous similar build you can use for example:"
  log_info "  meld ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]} $RELEASE_DIR &"
  if [ -f "$RELEASE_DIR/diffoscope.html" ]
  then
    log_info "  browse $(clickable_link "$RELEASE_DIR/diffoscope.html")"
  fi
fi

if [ -n "${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  echo
  log_info "To compare build artifacts with the previous tagged release run:"
  log_info "  meld ${LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS[0]} $RELEASE_DIR &"
  if [ -f "$RELEASE_DIR/diffoscope.html" ]
  then
    log_info "  browse $(clickable_link "$RELEASE_DIR/diffoscope.last-tagged.html")"
  fi
fi
