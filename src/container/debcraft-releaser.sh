#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# This has no confirmed effect but setting just to be sure as some dpkg-* tools
# are supposed to use it
export DPKG_COLORS="always"

# Use environment if set, otherwise use nice defaults
log_info "DEB_BUILD_OPTIONS set as '$DEB_BUILD_OPTIONS'"

# Prepare stats and cache
BUILD_START_TIME="$EPOCHSECONDS"

if [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  ccache --zero-stats > /dev/null
  export PATH="/usr/lib/ccache:${PATH}"
fi

# Mimic debuild log filename '<package>_<version>_source.build'
BUILD_LOG="$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_source.build"

# Parse upstream version to extract pristine-tar
DEBIAN_VERSION="$(dpkg-parsechangelog --show-field=version)"
log_debug_var DEBIAN_VERSION
# Remove epoch (if any) and Debian revision to get upstream version
UPSTREAM_VERSION="${DEBIAN_VERSION#*:}"
log_debug_var UPSTREAM_VERSION
UPSTREAM_VERSION="${UPSTREAM_VERSION%%-*}"
log_debug_var UPSTREAM_VERSION

# If pristine-tar branch exists, attempt to export so when package builds it
# would already have access to upstream source tarball and signature so they are
# used.
if [ -n "$(git branch --list pristine-tar)" ]
then
  # Get signature file if exists while ignoring any errors from the output parsing
  SIGNATURE_FILE="$(git ls-tree --name-only pristine-tar | grep "_$UPSTREAM_VERSION.*asc$")" || true
  log_debug_var SIGNATURE_FILE
  if [ -n "$SIGNATURE_FILE" ]
  then
    TARBALL_FILE="$(basename --suffix .asc "$SIGNATURE_FILE")"
    # The option --signature-file exists only starting from version 1.45 in Debian Buster
    if dpkg --compare-versions "$(dpkg-query -W -f='${Version}' pristine-tar)" gt "1.45"
    then
      log_info "Create original source package and signature using pristine-tar"
      pristine-tar checkout "../$TARBALL_FILE" --signature-file "../$SIGNATURE_FILE"
    else
      log_info "Create original source package using pristine-tar"
      pristine-tar checkout "../$TARBALL_FILE"
    fi
  else
    log_info "No signature file found on pristine-tar branch"
  fi
fi

# Normal releases in Debian are source-only. However, full binary releases are
# still needed for any uploads that need to pass the NEW queue, e.g. any
# completely new package or old package with new binary package name.
if [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  DPKG_BUILDPACKAGE_ARGS="--diff-ignore --tar-ignore"
  # Empty means full build, both source and binaries
  GBP_ARGS=""
else
  DPKG_BUILDPACKAGE_ARGS="--diff-ignore --tar-ignore"
  # Use -S so all tools (dpkg-build, dpkg-source) see it as using --build=source
  # alone would not be enough
  GBP_ARGS="-S"
fi

# Passed to dpkg-source:
#   --diff-ignore (-i, ignore default file types e.g. .git folder)
#   --tar-ignore (-I, passing ignores to tar)
gbp buildpackage --git-ignore-branch \
  --git-builder="dpkg-buildpackage --no-sign $DPKG_BUILDPACKAGE_ARGS" \
  $GBP_ARGS | tee -a "../$BUILD_LOG"

if [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  # Older ccache does not support '--verbose' but will print stats anyway, just
  # followed by help section. Newer ccache 4.0+ (Ubuntu 22.04 "Focal", Debian 12
  # "Bullseye") however require '--verbose' to show any cache hit stats at all.
  ccache --show-stats --verbose || true
fi

# @TODO: If `gbp tag` had a mode to give the previous release git tag on current
# branch (adhering to gbp.conf) this script could additionally draft a
# report-bug.txt with all the required text needed to send with
# 'report-bug --body-file=report-bug.txt' or to copy-paste on Launchpad:
#
#   git diff TAG..HEAD | xz > VERSION.debdiff.xz
#   dpkg-parsechangelog --show-field=changes >> report-bug.txt
#   git diff --stat TAG..HEAD >> report-bug.txt

# After the build, run the analyzer
# shellcheck source=src/container/debcraft-analyzer.sh
source "/debcraft-analyzer.sh"
