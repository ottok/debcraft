#!/bin/bash

case "$DISTRIBUTION" in
"")
  # If DISTRIBUTION is not set, try to guess it
  if [ ! -e debian/changelog ]
  then
    # If debian/changelog cannot be used, but current OS is a flavor of Debian,
    # try to use current distribution and release
    if grep --quiet "ID_LIKE=debian" /etc/os-release
    then
      source /etc/os-release
      BASEIMAGE="$ID:$VERSION_CODENAME"
    else
      # Otherwise default to using Debian unstable "sid"
      BASEIMAGE="debian:sid"
    fi
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
  log_error "Unknown value in --container-command=""$CONTAINER_CMD"
  exit 1
esac

# Container name
CONTAINER="debcraft-$PACKAGE-${BASEIMAGE//:/-}"

# If TARGET is a path and has a git repostory, identify artifacts with git
# metadata, otherwise just use timestamp
if [ -d "$TARGET/.git" ]
then
  # Set git commit id and name for later use
  COMMIT_ID=$(git -C "$TARGET/.git" log -n 1 --oneline | cut -d ' ' -f 1)
  # Strip branch paths and any slashes so version string is clean
  BRANCH_NAME=$(git -C "$TARGET/.git" symbolic-ref HEAD | sed 's|.*heads/||' | sed 's|/|.|g')

  BUILD_ID="$COMMIT_ID-$BRANCH_NAME"
else
  BUILD_ID="timestamp"
fi

# Explicit exports
export PACKAGE
export BASEIMAGE
export CONTAINER
export CONTAINER_CMD
export CONTAINER_RUN_ARGS
export BUILD_ID

log_info "Using '$CONTAINER_CMD' container image '$CONTAINER'"
