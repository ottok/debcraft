#!/bin/bash

case "$BUILD_DIRS_PATH" in
"")
  # If BUILD_DIRS_PATH is not set, use use parent directory
  BUILD_DIRS_PATH="$(cd .. && pwd)"
  ;;
*)
  # If BUILD_DIRS_PATH is defined, use it as-is
  if [ ! -d "$BUILD_DIRS_PATH" ]
  then
    log_error "Invalid value in --build-dirs-path=$BUILD_DIRS_PATH"
    exit 1
  fi
esac

# Additional sanity check
if touch "$BUILD_DIRS_PATH/debcraft-test"
then
  rm "$BUILD_DIRS_PATH/debcraft-test"
else
  log_error "Unable to access '$BUILD_DIRS_PATH' - check permissions"
  exit 1
fi

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
      DISTRIBUTION="$(dpkg-parsechangelog  --show-field=distribution --offset=1 --count=1)"
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
  CONTAINER_RUN_ARGS="--userns=keep-id"
  ;;
*)
  log_error "Invalid value in --container-command=$CONTAINER_CMD"
  exit 1
esac

# Container name
CONTAINER="debcraft-$PACKAGE-${BASEIMAGE//:/-}"

# Build id must always be defined
BUILD_ID="$(date '+%s')"

# If PWD has a git repository append BUILD_ID with git tag and branch
if [ -d "$PWD/.git" ]
then
  # Set git commit id and name for later use
  COMMIT_ID=$(git -C "$PWD/.git" log -n 1 --oneline | cut -d ' ' -f 1)
  # Strip branch paths and any slashes so version string is clean
  BRANCH_NAME=$(git -C "$PWD/.git" symbolic-ref HEAD | sed 's|.*heads/||')

  # The BUILD_ID will appended to the Debian/Ubuntu version string, and thus
  # cannot have slahses, dashes or underscores.
  BRANCH_NAME="$(echo "$BRANCH_NAME" | \
    sed 's|/|.|g' | \
    sed 's/-/./g' | \
    sed 's/_/./g' \
    )"

  # This format is compatible to be appended to package version string
  BUILD_ID="$BUILD_ID.$COMMIT_ID+$BRANCH_NAME"
fi

# Podman man page mentions support for architectures arm, arm64, 386, amd64, ppc64le, s390x
# @TODO: Figure out how to get 'amd64' from system and use it first, later allow user to choose:
# - `uname -a` only has formax x86_64
# - `lsb_release -a` and /etc/os-release only has distro name
# - `dpkg-architecture --query DEB_BUILD_ARCH` is Debian/Ubuntu dependent
#ARCH=

# Explicit exports
export PACKAGE
export BUILD_DIRS_PATH
export BASEIMAGE
export CONTAINER
export CONTAINER_CMD
export CONTAINER_RUN_ARGS
export BUILD_ID

log_info "Use '$CONTAINER_CMD' container image '$CONTAINER' for package '$PACKAGE'"
