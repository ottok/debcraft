#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

display_help() {
  cat << EOF
usage: debcraft <build|improve|test|release|shell|prune> [options] [<path|pkg|srcpkg|dsc|git-url>]

Debcraft is a tool to easily build .deb packages. The 'build' argument accepts
as a subargument any of:

  * path to directory with program sources including a debian/ subdirectory with
  * the Debian packaging instructions

  * path to a .dsc file and source tarballs that can be built into a .deb

  * Debian package name, or source package name, that apt can download

  * git http(s) or ssh URL that can be downloaded and built

The command 'release' is intended to be used to upload a package that is ready
to be released. The command 'test' will run the Debian-specific regression test
suite if the package has autopkgtest support, and drop to a shell for
investigation if tests failed to pass. The command 'shell' can be used to play
around in the container and 'prune' will clean up temporary files by Debcraft.

In addition to parameters below, anything passed in DEB_BUILD_OPTIONS will also
be honored (currently DEB_BUILD_OPTIONS='$DEB_BUILD_OPTIONS'). Note that
Debcraft builds never runs as root, and thus packages with
DEB_RULES_REQUIRES_ROOT are not supported.

optional arguments:
  --build-dirs-path    Path for writing build files and artifacts (default: parent directory)
  --distribution       Linux distribution to build in (default: debian:sid)
  --container-command  container command to use (default: podman)
  --host-architecture  host architecture to use when performing a cross build
  --skip-sources       build only binaries and skip creating a source
                       tarball to make the build slightly faster
                       ('debcraft build' only)
  --with-binaries      create a release with both source and binaries,
                       for example with intent to upload to NEW
                       ('debcraft release' only)
  --pull               ensure container base is updated
  --copy               perform the build on a copy of the package directory
  --clean              ensure sources are clean before and after build
  --debug              emit debug information
  -h, --help           display this help and exit
  --version            display version and exit

To learn more, or to contribute to Debcraft, see project page at
https://salsa.debian.org/debian/debcraft

To gain more Debian Developer knowledge, please read
https://www.debian.org/doc/manuals/developers-reference/
and https://www.debian.org/doc/debian-policy/
EOF
}

# Canonicalize script name if was run via symlink
DEBCRAFT_CMD_PATH="$(readlink --canonicalize-existing --verbose "$0")"
DEBCRAFT_LIB_DIR="$(dirname "$DEBCRAFT_CMD_PATH")/src"

# Assume system installation directory if not running from source directory
if [ ! -r "$DEBCRAFT_LIB_DIR/container/output.inc.sh" ]
then
  DEBCRAFT_LIB_DIR="/usr/share/debcraft"
fi

# If Debcraft itself was run in a git repository, include the git commit id
display_version() {
  if [ -e "$(dirname "$DEBCRAFT_CMD_PATH")/.git" ]
  then
    cd "$(dirname "$DEBCRAFT_CMD_PATH")"
    if [ -z "$(git tag --list)" ]
    then
      echo "DEBCRAFT ERROR: Unable to view latest git tag. Please run 'git fetch --tags'."
      exit 1
    fi
    LATEST_TAG="$(git describe --first-parent --abbrev=0)"
    LATEST_VERSION="$(echo "$LATEST_TAG" | grep --only-matching --basic-regexp '[0-9.]*')"
    LATEST_COMMIT="$(git rev-parse --short HEAD)"
    echo "Debcraft $LATEST_VERSION-$LATEST_COMMIT"
  elif [ -f /usr/share/doc/debcraft/changelog.gz ]
  then
    VERSION="$(
      zgrep --only-matching --max-count=1 --perl-regexp '\(\K[^\)]*' \
      /usr/share/doc/debcraft/changelog.gz
      )"
    echo "Debcraft $VERSION"
  else
    echo "Debcraft version unknown: neither git version control nor installed package was found"
  fi
}

# Debug flag detection must run before output.inc.sh is loaded
case "$@" in
  *--debug*)
    export DEBUG="true"
    ;;
esac

# Output formatting library is reused inside container as well
# shellcheck source=src/container/output.inc.sh
source "$DEBCRAFT_LIB_DIR/container/output.inc.sh"

# shellcheck source=src/distributions.inc.sh
source "$DEBCRAFT_LIB_DIR/distributions.inc.sh"

# shellcheck source=src/generic.inc.sh
source "$DEBCRAFT_LIB_DIR/generic.inc.sh"

if [ -z "$1" ]
then
  log_error "Missing argument <build|improve|test|release|shell|prune>"
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
      log_debug "Using BUILD_DIRS_PATH=$2"
      shift 2
      ;;
    --distribution)
      # The value is the next argument, e.g. '--distribution bookworm'
      export DISTRIBUTION="$2"
      log_debug "Using DISTRIBUTION=$2"
      shift 2
      ;;
    --container-command)
      export CONTAINER_CMD="$2"
      log_debug "Using CONTAINER_CMD=$2"
      shift 2
      ;;
    --host-architecture)
      export HOST_ARCH="$2"
      shift 2
      ;;
    --skip-sources)
      export SKIP_SOURCES="true"
      shift
      ;;
    --with-binaries)
      export WITH_BINARIES="true"
      shift
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
    build | improve | test | release | shell | prune)
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
  # If ACTION is empty the TARGET might have been populated
  log_error "Argument '$TARGET' not one of <build|improve|test|release|shell|prune>"
  echo
  display_help
  exit 1
fi

if [ -n "$SKIP_SOURCES" ] && [ "$ACTION" != "build" ]
then
  log_error "Parameter --skip-sources can only be used with action 'build'"
  echo
  display_help
  exit 1
fi

if [ -n "$WITH_BINARIES" ] && [ "$ACTION" != "release" ]
then
  log_error "Parameter --with-binaries can only be used with action 'release'"
  echo
  display_help
  exit 1
fi

log_debug_var ACTION

# Configure general program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-general.inc.sh
source "$DEBCRAFT_LIB_DIR/config-general.inc.sh"

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

log_debug_var TARGET

if [ -z "$TARGET" ]
then
  # If no argument defined, default to current directory
  TARGET="$(pwd)"
elif [ -d "$TARGET" ]
then
  # If an argument was given, and it is a directory, use TARGET as-is
  :
elif [ ! -d "$TARGET" ] && [[ "build improve" =~ $ACTION ]]
then
  # If the argument exists, but didn't point to a valid path, try to use the
  # argument to download the package

  # shellcheck source=src/downloader-container.inc.sh
  source "$DEBCRAFT_LIB_DIR/downloader-container.inc.sh"

  # shellcheck source=src/downloader.inc.sh
  source "$DEBCRAFT_LIB_DIR/downloader.inc.sh"

  # After a download, a subdirectory <TARGET>-<VERSION> might be present, and
  # if a container build already ran, also a debcraft-container-<TARGET> will
  # be present and that should be excluded from the listing below that aims to
  # find the downloaded sources.

  # shellcheck disable=SC2012
  NEWEST_DIRECTORY="$(ls --sort=time --time=ctime --format=single-column --group-directories-first --hide="debcraft-container-*" | head --lines=1 || true)"
  # Note! Use ctime above as dpkg-source will keep original mtime for packages
  # and ensure it never emits exit codes, only text output

  # Remove shortest pattern from end of variable, e.g. 'xz-utils-5.2.4' -> 'xz-utils'
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  #PACKAGE="${NEWEST_DIRECTORY%-*}"
  # Ensure source directory exists with the package name, e.g. 'grep' -> 'grep-3.4'
  #ln --verbose --force --symbolic "$NEWEST_DIRECTORY" "$PACKAGE"

  # Newest directory contains the downloaded source package now, use it as TARGET
  export TARGET="$NEWEST_DIRECTORY"
else
  log_error "Debcraft command '$ACTION' can only used after a build has run," \
            "and a directory with the Debian package source exist."
  exit 1
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
  log_error "Directory '$TARGET' is not a valid source package directory as" \
            "debian/changelog was not found"
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

# Clean up before the build if applicable
reset_if_source_repository_and_option_clean

# Configure program behaviour after user options and arguments have been parsed
# shellcheck source=src/config-package.inc.sh
source "$DEBCRAFT_LIB_DIR/config-package.inc.sh"

# If the action needs to run in a container, automatically create it
if [ "$ACTION" != "prune" ]
then
  # shellcheck source=src/container.inc.sh
  source "$DEBCRAFT_LIB_DIR/container.inc.sh"
fi

case "$ACTION" in
  build)
    # shellcheck source=src/build.inc.sh
    source "$DEBCRAFT_LIB_DIR/build.inc.sh"
    ;;
  improve)
    # shellcheck source=src/improve.inc.sh
    source "$DEBCRAFT_LIB_DIR/improve.inc.sh"
    ;;
  test)
    # shellcheck source=src/test.inc.sh
    source "$DEBCRAFT_LIB_DIR/test.inc.sh"
    ;;
  release)
    # shellcheck source=src/release.inc.sh
    source "$DEBCRAFT_LIB_DIR/release.inc.sh"
    # shellcheck source=src/release-ppa.inc.sh
    source "$DEBCRAFT_LIB_DIR/release-ppa.inc.sh"
    # shellcheck source=src/release-dput.inc.sh
    source "$DEBCRAFT_LIB_DIR/release-dput.inc.sh"
    ;;
  shell)
    # shellcheck source=src/shell.inc.sh
    source "$DEBCRAFT_LIB_DIR/shell.inc.sh"
    ;;
  prune)
    # shellcheck source=src/prune.inc.sh
    source "$DEBCRAFT_LIB_DIR/prune.inc.sh"
    ;;
esac

# Clean up after a successful build if applicable
reset_if_source_repository_and_option_clean
