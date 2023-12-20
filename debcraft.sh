#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

display_help() {
  echo "usage: debcraft [options] <build|validate|release|prune> [<path|pkg|srcpkg|dsc|git-url>]"
  echo
  echo "Debcraft is a tool to easily build .deb packages. The 'build' argument accepts"
  echo "as a subargument any of:"
  echo "  * path to directory with program sources including a debian/ subdirectory"
  echo "    with the Debian packaging instructions"
  echo "  * path to a .dsc file and source tarballs that can be built into a .deb"
  echo "  * Debian package name, or source package name, that apt can download"
  echo "  * git http(s) or ssh url that can be downloaded and built"
  echo
  echo "The commands 'validate' and 'release' are intended to be used to finalilze"
  echo "a package build. The command 'prune' will clean up temporary files by Debcraft."
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
      # The value is the next argument, e.g. '--distribution bookworm'
      export DISTRIBUTION="$2"
      shift 2
      ;;
    --container-command)
      export CONTAINER_CMD="$2"
      shift 2
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

# Configure general program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-general.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config-general.inc.sh"

if [ -z "$TARGET" ]
then
  # If no argument defined, default to current directory
  TARGET="$(pwd)"
elif [ ! -d "$TARGET" ]
then
  # If the argument exists, but didn't point to a valid path, try to use the
  # argument to download the package

  # shellcheck source=src/downloader.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/downloader.inc.sh"

  # shellcheck disable=SC2012
  NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first | head --lines=1)"
  # Note! Use ctime above as dpkg-source will keep original mtime for packages

  # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  #PACKAGE="${NEWEST_DIRECTORY%-*}"
  # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
  #ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"

  # Newest directory contains the downloaded source package now, use it as TARGET
  TARGET="$NEWEST_DIRECTORY"
fi

# The previous step guarentees that the source directory either exits, was
# downloaded or the script exection stopped. From here onwards the script can
# assume that $PWD is a working directory with sources.
cd "$TARGET" || (log_error "Unable to change directory to $TARGET"; exit 1)

if [ -f "debian/changelog" ]
then
  # If dpkg-parsechangelog fails and emits exit code, Debcraft will
  # intentionally halt completely at this point
  PACKAGE="$(dpkg-parsechangelog --show-field=source)"
else
  log_error "No $TARGET/debian/changelog found, not a valid source package directory"
  exit 1
fi

log_info "Running in path $PWD that has Debian package sources for '$PACKAGE'"

if [ -d ".git" ] && [ -n "$(git status --porcelain --ignored --untracked-files=all)" ]
then
  log_error "Git repository is not clean, cannot proceed building."
  exit 1
fi

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-package.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config-package.inc.sh"

# @TODO: Uncommitted changes test - don't proceed in vain if git
# clean/reset/commit needs to run first

# Make sure sources are clean
if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
then
  log_info "Ensure git repository is clean and reset (including submodules)"
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
    log_error "@TODO: Pruning not implemented"
    exit 1
    ;;
esac
