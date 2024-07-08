#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

display_help() {
  echo "usage: debcraft [options] <build|validate|release|shell|prune> [<path|pkg|srcpkg|dsc|git-url>]"
  echo
  echo "Debcraft is a tool to easily build .deb packages. The 'build' argument accepts"
  echo "as a subargument any of:"
  echo "  * path to directory with program sources including a debian/ subdirectory"
  echo "    with the Debian packaging instructions"
  echo "  * path to a .dsc file and source tarballs that can be built into a .deb"
  echo "  * Debian package name, or source package name, that apt can download"
  echo "  * git http(s) or ssh URL that can be downloaded and built"
  echo
  echo "The commands 'validate' and 'release' are intended to be used to finalize"
  echo "a package build. The command 'shell' can be used to pay around in the container"
  echo "and 'prune' will clean up temporary files by Debcraft."
  echo
  echo "In addition to parameters below, anything passed in DEB_BUILD_OPTIONS will also"
  echo "be honored (currently DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS')."
  echo "Note that Debcraft builds never runs as root, and thus packages with"
  echo "DEB_RULES_REQUIRES_ROOT are not supported."
  echo
  echo "optional arguments:"
  echo "  --build-dirs-path    Path for writing build files and artifacts (default: parent directory)"
  echo "  --distribution       Linux distribution to build in (default: debian:sid)"
  echo "  --container-command  container command to use (default: podman)"
  echo "  --pull               ensure container base is updated"
  echo "  --copy               perform the build on a copy of the package directory"
  echo "  --clean              ensure sources are clean"
  echo "  -h, --help           display this help and exit"
  echo "  --version            display version and exit"
  echo
  echo "To gain more Debian Developer knowledge, please read"
  echo "https://www.debian.org/doc/manuals/developers-reference/"
  echo "and https://www.debian.org/doc/debian-policy/"
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

# Debug flag detection must run before output.inc.sh is loaded
case "$@" in
  *--debug*)
    export DEBUG="true"
    ;;
esac

# Output formatting library is reused inside container as well
# shellcheck source=src/container/output.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/container/output.inc.sh"

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
      export BUILD_DIRS_PATH="$2"
      shift 2
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
    --pull)
      export PULL="true"
      shift
      ;;
    --clean)
      export CLEAN="true"
      shift
      ;;
    --copy)
      export COPY="true"
      shift
      ;;
    --debug)
      # Debug mode detection is already done earlier, ignore it at this stage
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
    build | validate | release | shell | prune)
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
  log_error "Argument '$TARGET' not one of <build|validate|release|shell|prune>"
  echo
  display_help
  exit 1
fi

log_debug_var ACTION

# Configure general program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-general.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config-general.inc.sh"

# @TODO: Nag of dependencies are not available: git, dpkg-parsechangelog, rsync,
# notify-send, paplay, tee, sed
#
# Bash must be new enough to have 'mapfile'.

# Docker does not support '--noheading', so the command will always output at
# least one line
# Hack: Listing images is very slow on Podman, so branch off two different tests
# shellcheck disable=2235 # two subshells necessary in this case
if ([ "$CONTAINER_TYPE" == 'podman' ] && \
    ! grep --quiet debcraft ~/.local/share/containers/storage/overlay-images/images.json 2>/dev/null) \
   || \
   ([ "$CONTAINER_TYPE" == 'docker' ] && \
   [ "$($CONTAINER_CMD images 'debcraft*' | wc -l)" -eq 1 ])
then
  log_warn "No previous Debcraft container was found and thus the first run of"
  log_warn "this tool is expected to be slow as the container base layer needs"
  log_warn "to be built. Re-runs of Debcraft will be fast."
fi

if [ -z "$TARGET" ]
then
  # If no argument defined, default to current directory
  TARGET="$(pwd)"
elif [ ! -d "$TARGET" ]
then
  # If the argument exists, but didn't point to a valid path, try to use the
  # argument to download the package

  # shellcheck source=src/downloader-container.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/downloader-container.inc.sh"

  # shellcheck source=src/downloader.inc.sh
  source "$DEBCRAFT_INSTALL_DIR/src/downloader.inc.sh"

  # shellcheck disable=SC2012
  NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first | head --lines=1 || true)"
  # Note! Use ctime above as dpkg-source will keep original mtime for packages
  # and ensure it never emits exit codes, only text output

  # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  #PACKAGE="${NEWEST_DIRECTORY%-*}"
  # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
  #ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"

  # Newest directory contains the downloaded source package now, use it as TARGET
  export TARGET="$NEWEST_DIRECTORY"
fi

log_debug_var TARGET

# The previous step guarantees that the source directory either exits, was
# downloaded or the script execution stopped. From here onwards the script can
# assume that $PWD is a working directory with sources.
cd "$TARGET" || (log_error "Unable to change directory to $TARGET"; exit 1)

log_debug_var PWD

if [ -f "debian/changelog" ]
then
  # If dpkg-parsechangelog fails and emits exit code, Debcraft will
  # intentionally halt completely at this point
  #
  # @TODO: Having dpkg-parsechangelog as a dependency is against the design
  # principle of having Debcraft as an universal tool
  PACKAGE="$(dpkg-parsechangelog --show-field=source)"
else
  log_error "No $TARGET/debian/changelog found, not a valid source package directory"
  exit 1
fi

log_info "Running in path $PWD that has Debian package sources for '$PACKAGE'"

# Make sure sources are clean on actions that depend on it
if [ "$ACTION" == "build" ] || [ "$ACTION" == "release" ]
then
  # Every deb build potentially generates these temporary files, and it is safe
  # to assume that they should be deleted before restarting the build, so do it
  # automatically to make the overall experience friendlier
  rm -rf debian/.debhelper debian/debhelper-build-stamp \
         debian/debhelper.log debian/*.debhelper.log \
         debian/substvars debian/*.substvars debian/files

  # If there are still more files, the user needs to make a decision
  if [ -z "$CLEAN" ] &&
     [ -z "$COPY" ] &&
     [ -d "$PWD/.git" ] &&
     [ -n "$(git status --porcelain --ignored --untracked-files=all)" ]
  then
    log_error "Modified or additional files found"\
              "\n$(git status --porcelain --ignored --untracked-files=all | head)"\
              "\nCannot proceed building unless --clean or --copy is used."
    exit 1
  fi
fi

# @TODO: If repository is a git clone, but not a `gbp clone`, it can be converted
# to gbp with `gbp pull --verbose --ignore-branch --pristine-tar --track-missing`

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

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-package.inc.sh
source "$DEBCRAFT_INSTALL_DIR/src/config-package.inc.sh"

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
    # shellcheck source=src/release-ppa.inc.sh
    source "$DEBCRAFT_INSTALL_DIR/src/release-ppa.inc.sh"
    # shellcheck source=src/release-dput.inc.sh
    source "$DEBCRAFT_INSTALL_DIR/src/release-dput.inc.sh"
    ;;
  shell)
    # shellcheck source=src/shell.inc.sh
    source "$DEBCRAFT_INSTALL_DIR/src/shell.inc.sh"
    ;;
  prune)
    # shellcheck source=src/prune.inc.sh
    source "$DEBCRAFT_INSTALL_DIR/src/prune.inc.sh"
    ;;
esac
