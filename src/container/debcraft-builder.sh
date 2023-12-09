#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Reset ccache stats, silently
ccache --zero-stats --show-stats

# Build package
gbp buildpackage --git-builder='debuild --no-lintian --no-sign -i -I'

# Show ccache stats
ccache --show-stats

cd /tmp/build || exit 1

# Log package contents
for package in *.deb
do
  echo "$package" | cut -d '_' -f 1 >> "filelist.log"
  dpkg-deb -c "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> "filelist.log"
  echo "------------------------------------------------" >> "filelist.log"
done

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
# Don't use color, otherwise logs become unreadable and diffs messy
lintian -EvIL +pedantic --profile=debian --color=never ./*.changes > "lintian.log" || true
