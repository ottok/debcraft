#!/bin/bash

# Define BASEIMAGE
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

      # If really on UNRELEASED was only option, default to debian:sid, which
      # is a possible scenario and sensible action on completely new packages
      if [ -z "$DISTRIBUTION" ]
      then
        BASEIMAGE="debian:sid"
      else
        # Let function map dpkg-parsechangelog value to a sensible baseimage
        BASEIMAGE="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
      fi
    fi
    ;;
  *:*)
    # If DISTRIBUTION is defined and has colon demarking components, use as-is
    BASEIMAGE="$DISTRIBUTION"
    ;;
  *)
    # If DISTRIBUTION is defined in some other format, ensure it maps to BASEIMAGE
    BASEIMAGE="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
esac

# Remove longest pattern from end of variable, e.g. 'bookworm-security' would be 'bookworm'
# (https://tldp.org/LDP/abs/html/parameter-substitution.html)
#RELEASE_NAME="${1%%-*}"

# Container name
# Replace on or more occurrences of colons with dash in container name
CONTAINER="debcraft-$PACKAGE-${BASEIMAGE//:/-}${HOST_ARCH/#/-}"

# Build id must always be defined
BUILD_ID="$(date '+%s')"

# If PWD has a git repository append BUILD_ID with git tag and branch
if [ -d "$PWD/.git" ]
then
  # Set git commit id and name for later use
  COMMIT_ID="$(git -C "$PWD/.git" rev-parse --short HEAD)"
  # Strip branch paths and any slashes so version string is clean, and if there
  # is no symbolic-ref at all ("fatal: ref HEAD is not a symbolic ref") when
  # for example building a detached head, fall-back to using just commit id
  BRANCH_NAME="$(git -C "$PWD/.git" symbolic-ref HEAD | sed 's|.*heads/||' || echo "$COMMIT_ID")"

  # The BUILD_ID will appended to the Debian/Ubuntu version string, and thus
  # cannot have slahses, dashes or underscores.
  BRANCH_NAME="${BRANCH_NAME////.}"
  BRANCH_NAME="${BRANCH_NAME//-/.}"
  BRANCH_NAME="${BRANCH_NAME//_/.}"

  # This format is compatible to be appended to package version string
  BUILD_ID="$BUILD_ID.$COMMIT_ID+$BRANCH_NAME"
fi

# Podman man page mentions support for architectures arm, arm64, 386, amd64,
# ppc64le, s390x as well as variants such as arm/v5 and arm/v7. See 'podman run'
# man page --platform and --variant.
#
# @TODO: Figure out how to get 'amd64' from system and use it first, later allow user to choose:
# - `uname -a` only has formax x86_64
# - `lsb_release -a` and /etc/os-release only has distro name
# - `dpkg-architecture --query DEB_BUILD_ARCH` is Debian/Ubuntu dependent
#
# None of these Bash variables have amd64 either:
# - HOSTNAME: XPS-13-9370
# - HOSTTYPE: x86_64
# - MACHTYPE: x86_64-pc-linux-gnu
# - OSTYPE: linux-gnu
#ARCH=

case "$BUILD_DIRS_PATH" in
  "")
    # If BUILD_DIRS_PATH is not set, use use parent directory of TARGET
    BUILD_DIRS_PATH="$(cd .. && pwd)"
    ;;
  *)
    # If BUILD_DIRS_PATH is defined, use it as-is
    if [ ! -d "$BUILD_DIRS_PATH" ]
    then
      if [ ! -e "$BUILD_DIRS_PATH" ]
      then
        log_error "Invalid value in --build-dirs-path=$BUILD_DIRS_PATH: directory does not exist"
      else
        log_error "Invalid value in --build-dirs-path=$BUILD_DIRS_PATH: not a directory"
      fi
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

# Actions 'build' and 'improve' operate on the BUILD_DIR
BUILD_DIR="$BUILD_DIRS_PATH/debcraft-build-$PACKAGE-$BUILD_ID"
# Action 'release' places artifacts in a differently named directory
RELEASE_DIR="$BUILD_DIRS_PATH/debcraft-release-$PACKAGE-$BUILD_ID"

# Explicit exports
export PACKAGE
export BASEIMAGE
export CONTAINER
export BUILD_ID
export BUILD_DIRS_PATH
export BUILD_DIR
export RELEASE_DIR

log_info "Use '$CONTAINER_CMD' container image '$CONTAINER' for package '$PACKAGE'"

# Previous successful builds that produced a .buildinfo file
# shellcheck disable=SC2086 # intentionally pass wildcards to ls
mapfile -t PREVIOUS_SUCCESSFUL_BUILDINFO_FILES < <(
  ls --sort=time --time=ctime --format=single-column --group-directories-first --directory \
    ${BUILD_DIRS_PATH}/debcraft-{build,release}-${PACKAGE}-*+${BRANCH_NAME}/*.buildinfo \
    2> /dev/null
)

# @TODO: If there are no previous builds of the same branch, check for _any_
# previous builds of same package and suggest that as the comparison point

# Convert into two arrays of path names
PREVIOUS_SUCCESSFUL_BUILD_DIRS=()
PREVIOUS_SUCCESSFUL_RELEASE_DIRS=()
for BUILDINFO_FILE in "${PREVIOUS_SUCCESSFUL_BUILDINFO_FILES[@]}"
do
  case $BUILDINFO_FILE in
    */debcraft-build-*)
      PREVIOUS_SUCCESSFUL_BUILD_DIRS+=("$(dirname "$BUILDINFO_FILE")")
      ;;
    */debcraft-release-*)
      PREVIOUS_SUCCESSFUL_RELEASE_DIRS+=("$(dirname "$BUILDINFO_FILE")")
      ;;
  esac
done
log_debug_var PREVIOUS_SUCCESSFUL_BUILD_DIRS
log_debug_var PREVIOUS_SUCCESSFUL_RELEASE_DIRS

export PREVIOUS_SUCCESSFUL_BUILD_DIRS
export PREVIOUS_SUCCESSFUL_RELEASE_DIRS

# If PWD has a git repository and --with-binaries is not used, try looking up
# latest tagged releases
if [ -d "$PWD/.git" ]
then
  if [ -n "$(git tag --list)" ]
  then
    # Get the first tag encountered when traversing branch history
    NAME_OF_LAST_TAG="$(git describe --first-parent --abbrev=0)"
    log_debug_var NAME_OF_LAST_TAG
    # The '^{}' will dereference the tag to the commit id
    COMMIT_ID_OF_LAST_TAG="$(git rev-parse --short "$NAME_OF_LAST_TAG"^{})"
    log_debug_var COMMIT_ID_OF_LAST_TAG

    # Previous successful builds that produced a .buildinfo with a commit matching
    # the latest tagged release, ignoring branch name
    # shellcheck disable=SC2086 # intentionally pass wildcards to ls
    mapfile -t LAST_TAGGED_SUCCESSFUL_BUILDINFO_FILES < <(
      ls --sort=time --time=ctime --format=single-column --group-directories-first --directory \
        ${BUILD_DIRS_PATH}/debcraft-{build,release}-${PACKAGE}-*.${COMMIT_ID_OF_LAST_TAG}+*/*.buildinfo \
        2> /dev/null
    )
  else
    log_warn "Unable to find any git tags, which are needed to identify" \
             "previous release and compare build artifacts with it. " \
             "Run 'git fetch --tags' to ensure any remote tag is available locally."
    LAST_TAGGED_SUCCESSFUL_BUILDINFO_FILES=()
  fi

  log_debug_var LAST_TAGGED_SUCCESSFUL_BUILDINFO_FILES

  # Convert into two arrays of path names
  LAST_TAGGED_SUCCESSFUL_BUILD_DIRS=()
  LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS=()
  for BUILDINFO_FILE in "${LAST_TAGGED_SUCCESSFUL_BUILDINFO_FILES[@]}"
  do
   case $BUILDINFO_FILE in
     */debcraft-build-*)
       LAST_TAGGED_SUCCESSFUL_BUILD_DIRS+=("$(dirname "$BUILDINFO_FILE")")
       ;;
     */debcraft-release-*)
       LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS+=("$(dirname "$BUILDINFO_FILE")")
       ;;
   esac
  done
  log_debug_var LAST_TAGGED_SUCCESSFUL_BUILD_DIRS
  log_debug_var LAST_TAGGED_SUCCESSFUL_RELEASE_DIRS
fi
