#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Reset ccache stats, silently
#ccache --zero-stats > /dev/null
ccache --show-stats  --verbose || true

# Build package
# Don't use colors as they garble the logs (unless 'tee' can be taught to filter our ANSI codes)
export DPKG_COLORS=never

# Don't use default build system debuild as it will remove intentional
# environment variables (e.g. CCACHE_DIR) and it also runs unnecessary steps
# (e.g. Lintian and signing) which we want to do separately.

# Passed to dpkg-buildpackage: --no-sign (no keys available in container anyway)
# Passed to dpkg-source: --diff-ignore (-i, ignore default file types e.g. .git folder), --tar-ignore (-I, passing ignores to tar)
#gbp buildpackage --git-color=off --git-builder='debuild --no-lintian --no-sign --diff-ignore --tar-ignore'
gbp buildpackage --git-color=off --git-builder='dpkg-buildpackage -us -uc -ui --diff-ignore --tar-ignore'

# Older ccache does not support '--verbose' but will print stats anyway, just
# followed by help section. Newer ccache 4.0+ (Ubuntu 22.04 "Focal", Debian 12
# "Bullseye") however require '--verbose' to show any cache hit stats at all.
ccache --show-stats  --verbose || true


cd /tmp/build || exit 1

# Log package contents
echo "Creating filelist.log.."
for package in *.deb
do
  # shellcheck disable=SC2129
  echo "$package" | cut -d '_' -f 1 >> "filelist.log"
  dpkg-deb -c "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> "filelist.log"
  echo "------------------------------------------------" >> "filelist.log"
done

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo "Creating lintian.log.."
# Don't use color, otherwise logs become unreadable and diffs messy
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian -EvIL +pedantic --color=never ./*.changes | tee "lintian.log" || true
