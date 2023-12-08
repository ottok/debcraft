#!/bin/bash

# If target is a path to sources, get the source package name from
# debian/changelog
if [ -d "$TARGET" ]
then
  # @TODO: Changing directory should probably be done in top-level script so it is inherited automatically to all other scripts
  cd "$TARGET" || (echo "ERROR: Unable to change directory to $TARGET"; exit 1)
  if [ -f "debian/changelog" ]
  then
    PACKAGE="$(dpkg-parsechangelog --show-field=source)"
  else
    echo "ERROR: No $TARGET/debian/changelog found, not a valid source package directory"
    exit 1
  fi
else
  echo "@TODO: Package lookup not implemented for $TARGET"
  exit 1
fi

case "$DISTRIBUTION" in
"")
  # If DISTRIBUTION is not set, try to guess it
  if [ ! -e debian/changelog ]
  then
    # If debian/changelog cannot be used, default to using Debian unstable "sid"
    BASEIMAGE="debian:sid"
  else
    # Parse the latest debian/changelog entry
    DISTRIBUTION="$(dpkg-parsechangelog  --show-field=distribution)"
    # ..or if that is UNRELEASED, the second last entry
    if [ "$DISTRIBUTION" == "UNRELEASED" ]
    then
      DISTRIBUTION="$(dpkg-parsechangelog  --show-field=distribution --count=1 --offset=1)"
    fi
    # Let function map dpkg-parsechangelog value to a sensible baseimage
    BASEIMAGE="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
  fi
  ;;
*)
  # If DISTRIBUTION is defined, use it to set BASEIMAGE
  BASEIMAGE="$DISTRIBUTION"
esac

case "$CONTAINER_CMD" in
docker)
  # Using Docker is valid option but requires some extra args to work
  CONTAINER_CMD="docker"
  CONTAINER_RUN_ARGS="--user=$(id -u)"
  ;;
podman | "")
  # Default to using Podman
  CONTAINER_CMD="podman"
  ;;
*)
  echo "ERROR: Unknown value in --container-command=""$CONTAINER_CMD"
  exit 1
esac

# Container name
CONTAINER="debcraft-$PACKAGE-${BASEIMAGE//:/-}"

# Explicit exports
export PACKAGE
export BASEIMAGE
export CONTAINER
export CONTAINER_CMD
export CONTAINER_RUN_ARGS

echo "Using '$CONTAINER_CMD' container image '$CONTAINER'"
