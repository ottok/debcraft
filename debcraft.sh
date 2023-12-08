#!/bin/bash

# stop on errors
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

display_help() {
  echo "usage: Debcraft [options] <build|validate|release|prune> [<path|srcpkg|binpkg|binary>]"
  echo
  echo "Build and iterate on .deb packages."
  echo
  echo "optional arguments:"
  echo "  -d, --distribution       Linux distribution to build in (default: debian:sid)"
  echo "  -c, --container-command  container command to use (default: podman)"
  echo "  -h, --help               display this help and exit"
  echo "  --version                display version and exit"
}

# If Debcraft itself was run in a git repository, include the git commit id
display_version() {
  VERSION=0.1.0
  if [[ -e .git ]]
  then
    VERSION=${VERSION}-$(git log -n 1 --oneline | cut -d ' ' -f 1)
  fi
  echo "Debcraft version ${VERSION}"
}

# @TODO: Make installation directory detectaion portable
DEBCRAFT_CMD_PATH="$0"
DEBCRAFT_INSTALL_DIR="/home/otto/koodia/debcraft"

# Save for later use
DEBCRAFT_RUN_DIR="$(pwd)"

# shellcheck source=src/output.sh
source "$DEBCRAFT_INSTALL_DIR/src/output.sh"

# shellcheck source=src/distributions.sh
source "$DEBCRAFT_INSTALL_DIR/src/distributions.sh"

if [ -z "$1" ]
then
  log_error "Missing argument <build|validate|release|prune>"
  echo
  display_help
  exit 1
fi

while :
#log_info "Parsing option/argument: $1"
do
  case "$1" in
	-d | --distribution)
    export DISTRIBUTION="$1"
    shift
    ;;
	-c | --container-command)
    export CONTAINER_CMD="$1"
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
  log_error "Argument '$TARGET' not one of <build|validate|release|prune>"
  echo
  display_help
  exit 1
fi

# If no target defined, default to current directory
if [ -z "$TARGET" ]
then
  TARGET="$(pwd)"
fi

# If target is a path to sources, ensure the whole script runs from it
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
  log_warn "@TODO: Package lookup not implemented for $TARGET"
  # @TODO: if package exists as such, download with apt source, or figure out
  # source package using dpkg -S
  exit 1
fi

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config.sh
source "$DEBCRAFT_INSTALL_DIR/src/config.sh"

# If the action needs to run in a container, automatically create it
if [ "$ACTION" == "build" ] || [ "$ACTION" == "validate" ]
then
  # shellcheck source=src/container.sh
  source "$DEBCRAFT_INSTALL_DIR/src/container.sh"
fi

case "$ACTION" in
build)
  # shellcheck source=src/build.sh
  source "$DEBCRAFT_INSTALL_DIR/src/build.sh"
  ;;
validate)
  # shellcheck source=src/validate.sh
  source "$DEBCRAFT_INSTALL_DIR/src/validate.sh"
  ;;
release)
  # shellcheck source=src/release.sh
  source "$DEBCRAFT_INSTALL_DIR/src/release.sh"
  ;;
prune)
  # For debcraft- containers: podman volume prune --force && podman system prune --force
  # Delete also all mktemp generated directories, build dirs, caches etc
  log_warn "@TODO: Pruning not implemented"
  exit 1
  ;;
esac
