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

# @TODO: The below will run for any ACTION, but maybe downloading sources should
# be refactored to be only a feature in 'build'. Also the commands should run
# inside a Debcraft container with matching --distribution.
case "$TARGET" in
  '')
    # If no target defined, default to current directory
    TARGET="$(pwd)"
    ;;

  http://* | https://* | git@*)
    # Arguments with this form must be git urls
    #
    # @TODO: Use --depth=1 if gbp would support automatically fetching more
    # commits until it sees the merge on the upstream branch and has enough to
    # actually build the package
    gbp clone --verbose --pristine-tar "$TARGET"
    # shellcheck disable=SC2012
    NEWEST_DIRECTORY="$(ls --sort=time --format=single-column --group-directories-first | head --lines=1)"
    PACKAGE="$NEWEST_DIRECTORY"
    # From now on the TARGET is the resolved package source directory
    TARGET="$PACKAGE"
    ;;

  *.dsc)
    # Use Debian source .dcs control file
    log_info "Use $TARGET and unpack associated Debian and source tar packages"
    dpkg-source --extract "$TARGET"
    # shellcheck disable=SC2012
    NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first | head --lines=1)"
    # Use ctime above as dpkg-source will keep original mtime for packages
    # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
    # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
    PACKAGE="${NEWEST_DIRECTORY%-*}"
    # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
    ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"
    # From now on the TARGET is the resolved package source directory name without version
    TARGET="$PACKAGE"
    ;;

  */*)
    # Arguments with a single slash anywhere that didn't match a git url are
    # assumed to be directory names, so use them as-is
    log_info "Use package in path '$TARGET'"
    ;;

  *)
    if [ -d "$TARGET" ]
    then
      # An argument that didn't match any of the above tests could be a directory
      # name, and if so, use it as-is.
      :
    elif [ "$(apt-cache showsrc "$TARGET" | wc -l)" -gt 1 ]
    then
      # Otherwise assume check if it is a binary or source and try to get it
      # with apt-source. If 'apt-cache showsrc' yields no results it will output
      # 'W: Unable to locate package $TARGET' in stderr which would
      # intentionally be visible for the user. The stdout will also have one
      # line of output. If there is a result, the stdout would be much longer.
      log_info "Download source package for '$TARGET'"
      apt-get source "$TARGET"
      # shellcheck disable=SC2012
      NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first | head --lines=1)"
      # Use ctime above as dpkg-source will keep original mtime for packages
      # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
      # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
      PACKAGE="${NEWEST_DIRECTORY%-*}"
      # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
      ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"
      # From now on the TARGET is the resolved package source directory name without version
      TARGET="$PACKAGE"
    elif command -v "$TARGET" > /dev/null
    then
      # As a last attempt, try to find what command the $TARGET might be, and
      # resolve the source package for it
      log_info "Attempt to find source package for command '$TARGET'"
      PACKAGE="$(dpkg --search "$(command -v "$TARGET")" | cut --delimiter=':' --field 1)"
      if [ -n "$PACKAGE" ]
      then
        log_info "Download source package for '$PACKAGE'"
        apt-get source "$PACKAGE"
        # shellcheck disable=SC2012
        NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first | head --lines=1)"
        # Use ctime above as dpkg-source will keep original mtime for packages
        # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
        # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
        PACKAGE="${NEWEST_DIRECTORY%-*}"
        # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
        ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"
        # From now on the TARGET is the resolved package source directory name without version
        TARGET="$PACKAGE"
      #elif [ -f /var/lib/command-not-found/commands.db ]
      #then
      # @TODO: Search command-not-found database if exists
      else
        log_error "Unable to find any Debian package for command '$TARGET'"
        exit 1
      fi
    else
      log_error "Unable to find any source package for argument '$TARGET'"
      exit 1
    fi
    ;;
esac

# At this point in the code a directory with the sources should exist
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
  log_error "Seems $TARGET is not a directory nor anything we can use"
  exit 1
fi

log_info "Running in path $PWD"

if [ -n "$(git status --porcelain --ignored --untracked-files=all)" ]
then
  log_error "Git repository is not clean, cannot proceed with building."
  exit 1
fi

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config.inc.sh"

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
