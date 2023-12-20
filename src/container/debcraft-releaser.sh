#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# This has no confirmed effect but setting just to be sure as some dpkg-* tools
# are supposed to use it
export DPKG_COLORS="always"

# Mimic debuild log file naming
BUILD_LOG="../$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_source.build"

# Passed to dpkg-source:
#   --diff-ignore (-i, ignore default file types e.g. .git folder)
#   --tar-ignore (-I, passing ignores to tar)
#
# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
gbp buildpackage \
  --git-builder='dpkg-buildpackage --no-sign --diff-ignore --tar-ignore' \
  -S | tee -a "$BUILD_LOG"

cd /tmp/build || exit 1

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo "Create lintian.log"
# Seems that --color=auto isn't enough inside a container, so use 'always'.
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian --verbose -EvIL +pedantic --color=always ./*.changes | tee -a "lintian.log" || true
