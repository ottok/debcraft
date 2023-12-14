#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Passed to dpkg-source:
#   --diff-ignore (-i, ignore default file types e.g. .git folder)
#   --tar-ignore (-I, passing ignores to tar)
#
# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
gbp buildpackage --git-color=off \
  --git-builder='dpkg-buildpackage --no-sign --diff-ignore --tar-ignore' \
  -S

cd /tmp/build || exit 1

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo "Create lintian.log"
# Don't use color, otherwise logs become unreadable and diffs messy
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian -EvIL +pedantic --color=never ./*.changes | tee "lintian.log" || true
