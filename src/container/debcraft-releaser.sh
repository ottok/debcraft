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
  # shellcheck source=src/container/cache.inc.sh
  source "/cache.inc.sh"
fi

# Mimic debuild log filename '<package>_<version>_source.build'
BUILD_LOG="$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_source.build"

# shellcheck source=src/container/pristine-tar.inc.sh
source "/pristine-tar.inc.sh"

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
  --git-builder="dpkg-buildpackage --post-clean --no-sign $DPKG_BUILDPACKAGE_ARGS" \
  $GBP_ARGS | tee -a "../$BUILD_LOG"

if [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  # Older ccache does not support '--verbose' but will print stats anyway, just
  # followed by help section. Newer ccache 4.0+ (Ubuntu 22.04 "Focal", Debian 12
  # "Bullseye") however require '--verbose' to show any cache hit stats at all.
  ccache --show-stats --verbose || true

  if command -v sccache > /dev/null
  then
    log_info "Cache stats: sccache"
    sccache --show-stats
    # --show-adv-stats available only in Debian 13 "Trixie" and newer
  fi
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
