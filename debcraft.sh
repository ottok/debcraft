#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

display_help() {
  echo "usage: debcraft [options] <build|validate|release|prune> [<path|srcpkg|binpkg|binary>]"
  echo
  echo "Debcraft is a tool to easily build and rebuild .deb packages."
  echo
  echo "In addition to parameters below, anything passed in DEB_BUILD_OPTIONS will also"
  echo "be honored (currently DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS')."
  echo
  echo "optional arguments:"
  echo "  --build-dirs-path    Path for writing build files and arfitacs (default: parent directory)"
  echo "  --distribution       Linux distribution to build in (default: debian:sid)"
  echo "  --container-command  container command to use (default: podman)"
  echo "  --clean              ensure container base is updated and sources clean"
  echo "  -h, --help           display this help and exit"
  echo "  --version            display version and exit"
}

# If Debcraft itself was run in a git repository, include the git commit id
display_version() {
  VERSION=0.1.0
  if [ -e .git ]
  then
    VERSION="$VERSION-$(git log -n 1 --oneline | cut -d ' ' -f 1)"
  fi
  echo "Debcraft version $VERSION"
}

# Canonicalize script name if was run via symlink
DEBCRAFT_CMD_PATH="$(readlink --canonicalize-existing --verbose "$0")"
DEBCRAFT_INSTALL_DIR="$(dirname "$DEBCRAFT_CMD_PATH")"

# Save for later use
DEBCRAFT_RUN_DIR="$(pwd)"

# shellcheck source=src/output.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/output.inc.sh"

# shellcheck source=src/distributions.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/distributions.inc.sh"

if [ -z "$1" ]
then
  log_error "Missing argument <build|validate|release|prune>"
  echo
  display_help
  exit 1
fi

while :
log_debug "Parse option/argument: $1"
do
  case "$1" in
	--build-dirs-path)
    export BUILD_DIRS_PATH="$1"
    shift
    ;;
	--distribution)
    export DISTRIBUTION="$1"
    shift
    ;;
	--container-command)
    export CONTAINER_CMD="$1"
    shift
    ;;
	--clean)
    export CLEAN="true"
    shift
    ;;
	-h | --help)
    display_help  # Call your function
    exit 0
    ;;
	--version)
    display_version
    exit 0
    ;;
	--)
    # No more options
    shift
    break
    ;;
	-*)
    log_error "Unknown option: $1"
    ## or call function display_help
    exit 1
    ;;
  build | validate | release | prune)
    export ACTION="$1"
    shift
    ;;
  *)
    export TARGET="$1"
    # No more options or arguments
    break
    ;;
  esac
done

if [ -z "$ACTION" ]
then
  # IF ACTION isempty the TARGET might have been populated
  log_error "Argument '$TARGET' not one of <build|validate|release|prune>"
  echo
  display_help
  exit 1
fi

log_debug_var ACTION

# If no target defined, default to current directory
if [ -z "$TARGET" ]
then
  TARGET="$(pwd)"
fi

# If target is a path to sources, ensure the whole script runs from it
# From this point onwards $PWD will point to working directory with sources
if [ -d "$TARGET" ]
then
  cd "$TARGET" || (log_error "Unable to change directory to $TARGET"; exit 1)

  if [ -f "debian/changelog" ]
  then
    PACKAGE="$(dpkg-parsechangelog --show-field=source)"
  else
    log_error "No $TARGET/debian/changelog found, not a valid source package directory"
    exit 1
  fi
else
  log_error "@TODO: Package lookup not implemented for $TARGET"
  # @TODO: if package exists as such, download with apt source, or figure out
  # source package using dpkg -S
  exit 1
fi

log_info "Running in path $PWD"

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config.inc.sh"

# Make sure sources are clean
if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
then
  log_info "Ensure git respository is clean and reset (including submodules)"
  git clean -fdx
  git submodule foreach --recursive git clean -fdx
  git reset --hard
  git submodule foreach --recursive git reset --hard
  git submodule update --init --recursive
fi

# If the action needs to run in a container, automatically create it
if [ "$ACTION" == "build" ] || [ "$ACTION" == "validate" ] || [ "$ACTION" == "release" ]
then
  # shellcheck source=src/container.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/container.inc.sh"
fi

case "$ACTION" in
build)
  # shellcheck source=src/build.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/build.inc.sh"
  ;;
validate)
  # shellcheck source=src/validate.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/validate.inc.sh"
  ;;
release)
  # shellcheck source=src/release.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/release.inc.sh"
  ;;
prune)
  # For debcraft-* containers: podman volume prune --force && podman system prune --force
  # Delete also all mktemp generated directories, build dirs, caches etc
  log_warn "@TODO: Pruning not implemented"
  exit 1
  ;;
esac
