#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Build package
# Don't use colors as they garble the logs (unless 'tee' can be taught to filter our ANSI codes)
# Passed to dpkg-buildpackage: --no-sign (no keys available in container anyway)
# Passed to dpkg-source: --diff-ignore (-i, ignore default file types e.g. .git folder), --tar-ignore (-I, passing ignores to tar)
# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
gbp buildpackage --git-color=off --git-builder='debuild --no-lintian --no-sign --diff-ignore --tar-ignore' -S

cd /tmp/build || exit 1

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
# Don't use color, otherwise logs become unreadable and diffs messy
lintian -EvIL +pedantic --profile=debian --color=never ./*.changes > "lintian.log" || true
