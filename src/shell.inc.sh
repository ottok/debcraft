#!/bin/bash

log_info "Starting interactive root shell in container for source package at $PWD"

SHELL_DIR="$(mktemp -d)"

# Ensure directories exist before they are mounted
mkdir --parents "$CACHE_DIR" "$SHELL_DIR/source"

if [ -n "${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}" ]
then
  log_info "Previous build was in ${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}"
  mkdir --parents "$SHELL_DIR/previous-build"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_BUILD_DIRS[0]}:/debcraft/previous-build $EXTRA_CONTAINER_MOUNTS"
fi

# Note use of RELEASE directory, *not* BUILD
if [ -n "${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}" ]
then
  log_info "Previous release was in ${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}"
  mkdir --parents "$SHELL_DIR/previous-release"
  EXTRA_CONTAINER_MOUNTS=" --volume=${PREVIOUS_SUCCESSFUL_RELEASE_DIRS[0]}:/debcraft/previous-release $EXTRA_CONTAINER_MOUNTS"
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
    cp --verbose --no-clobber "$TARBALL_PATH" "$SHELL_DIR/"
    # Exit loop after finding and copying the first tarball
    break
  fi
done

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
    --cap-add SYS_PTRACE \
    --volume="$CACHE_DIR":/debcraft/cache \
    --volume="$SHELL_DIR":/debcraft \
    $EXTRA_CONTAINER_MOUNTS \
    --volume="${SOURCE_DIR:=$PWD}":/debcraft/source \
    --workdir=/debcraft/source \
    --env="DEB*" \
    "$CONTAINER" \
    /debcraft-shell.sh

# NOTE! Intentionally omit $CONTAINER_RUN_ARGS as this container should run as
# root so user can install/upgrade tools.

if [ -n "$DEBUG" ]
then
  set +x
fi

log_info "Interactive shell exited"
