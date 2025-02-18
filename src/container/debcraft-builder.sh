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

# Prepare stats and cache
BUILD_START_TIME="$EPOCHSECONDS"
ccache --zero-stats > /dev/null
export PATH="/usr/lib/ccache:${PATH}"

# Mimic debuild log filename '<package>_<version>_<arch>.build'
# https://manpages.debian.org/unstable/devscripts/debuild.1.en.html#DESCRIPTION
# https://salsa.debian.org/debian/devscripts/-/blob/main/scripts/debuild.pl?ref_type=heads#L974-983
BUILD_LOG="$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_$(dpkg-architecture --query DEB_HOST_ARCH).build"

# Normal builds in Debian are full binary releases with sources
if [ -n "$DEBCRAFT_FULL_BUILD" ]
then
  # Empty means full build, both source and binaries
  DPKG_BUILDPACKAGE_ARGS=""
  GBP_ARGS=""
else
  # Skip generating source package to make (binary) build faster by default
  DPKG_BUILDPACKAGE_ARGS="--build=any,all"
  GBP_ARGS="--git-no-create-orig"

  # Normally dpkg-source applies the patches, but when running a binary-only
  # build directly in the Debian packaging git repository dpkg-source will be
  # skipped and sources will remain unpatched
  if [ -f debian/patches/series ]
  then
    log_warn "Debian patches are *not* applied as this is a binary-only build that omits invoking 'dpkg-source'."
    log_warn "Run 'gbp pq import --force' or equivalent to apply patches before building."
  fi
fi

if [ -n "$HOST_ARCH" ] && ! dpkg-architecture -e "$HOST_ARCH"
then
  # Apply host architecture to build process if not the same as build architecture
  DPKG_BUILDPACKAGE_ARGS="$DPKG_BUILDPACKAGE_ARGS --host-arch $HOST_ARCH"
  # Set default variables so cross compiling is easier. DEB_BUILD_* properties
  # are only set here if not already set prior.  This matches what sbuild does
  # when it performs a cross build.
  # https://salsa.debian.org/debian/sbuild/-/blob/archive/debian/0.89.0/lib/Sbuild/Build.pm?ref_type=tags#L2886-2895
  # https://salsa.debian.org/debian/sbuild/-/blob/archive/debian/0.89.0/lib/Sbuild/Conf.pm?ref_type=tags#L167-177
  export CONFIG_SITE=/etc/dpkg-cross/cross-config.$HOST_ARCH
  export DEB_BUILD_OPTIONS=${DEB_BUILD_OPTIONS:-nocheck}
  export DEB_BUILD_PROFILES=${DEB_BUILD_PROFILES:-cross nocheck}
fi

# Use environment if set, otherwise use nice defaults
log_info "DEB_BUILD_OPTIONS set as '$DEB_BUILD_OPTIONS'"

# Teach user what is done and why
log_info "Running 'dpkg-buildpackage --build=any,all' to create .deb packages"

if [ -d ".git" ]
then
  # Always use git-buildpackage if possible
  #
  # Don't use default build system which is debuild, as sanitizes environment
  # variables while we intentionally want to keep e.g. CCACHE_DIR and it also runs
  # Lintian and signs packages, which we specifically want to do separately.
  # Instead use dpkg-buildpackage directly (debuild would use it anyway) and also
  # instruct it to only build binary packages, skipping source package generation
  # and skipping related cleanup steps.
  log_info "Running 'gbp buildpackage $GBP_ARGS' to create .deb packages from git repository"
  # shellcheck disable=SC2086 # intentionally pass variable that can be multiple arguments
  gbp buildpackage --git-ignore-branch \
    --git-builder="dpkg-buildpackage --no-sign $DPKG_BUILDPACKAGE_ARGS" \
    $GBP_ARGS | tee -a "../$BUILD_LOG"
else
  # Fall-back to plain dpkg-buildpackage if no git repository
  log_info "Running 'dpkg-buildpackage $DPKG_BUILDPACKAGE_ARGS' to create .deb packages from plain sources directory"
  # shellcheck disable=SC2086 # intentionally pass variable that can be multiple arguments
  dpkg-buildpackage --no-sign $DPKG_BUILDPACKAGE_ARGS | tee -a "../$BUILD_LOG"
fi
# @TODO: Test building just binaries to make build faster, and later also
# test skipping rules/clean steps with '--no-pre-clean --no-post-clean'
# or run in parallel with '--jobs=auto'
#
# @TODO: At least for MariaDB seems rebuild needs 'debian/rules clean' target to run
# otherwise dh_install fails, thus using '--no-pre-clean --no-post-clean'  is not
# compatible with MariaDB
#   dh_install: warning: Cannot find (any matches for) "usr/lib/mysql/plugin/ha_archive.so" (tried in ., debian/tmp)

# Older ccache does not support '--verbose' but will print stats anyway, just
# followed by help section. Newer ccache 4.0+ (Ubuntu 22.04 "Focal", Debian 12
# "Bullseye") however require '--verbose' to show any cache hit stats at all.
ccache --show-stats --verbose || true

# After the build, run the analyzer
# shellcheck source=src/container/debcraft-analyzer.sh
source "/debcraft-analyzer.sh"
