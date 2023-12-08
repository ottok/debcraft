#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Reset ccache stats, silently
ccache --zero-stats > /dev/null

# Build package
# Don't use colors as they garble the logs (unless 'tee' can be taught to filter our ANSI codes)
# Passed to dpkg-buildpackage: --no-sign (no keys available in container anyway)
# Passed to dpkg-source: --diff-ignore (-i, ignore default file types e.g. .git folder), --tar-ignore (-I, passing ignores to tar)
gbp buildpackage --git-color=off --git-builder='debuild --no-lintian --no-sign --diff-ignore --tar-ignore'

# Show ccache stats which should have some hits in case ccache was used during the build
ccache --show-stats

cd /tmp/build || exit 1

# Log package contents
for package in *.deb
do
  # shellcheck disable=SC2129
  echo "$package" | cut -d '_' -f 1 >> "filelist.log"
  dpkg-deb -c "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> "filelist.log"
  echo "------------------------------------------------" >> "filelist.log"
done

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
# Don't use color, otherwise logs become unreadable and diffs messy
lintian -EvIL +pedantic --profile=debian --color=never ./*.changes > "lintian.log" || true
