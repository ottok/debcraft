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

# Reset ccache stats, silently
ccache --zero-stats > /dev/null

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
  #
  # Passed to dpkg-source:
  #   --diff-ignore (-i, ignore default file types e.g. .git folder)
  #   --tar-ignore (-I, passing ignores to tar)
  gbp buildpackage \
    --git-builder='dpkg-buildpackage --no-sign --build=any,all --no-pre-clean --no-post-clean' \
    --git-no-create-orig  --git-ignore-new
else
  # Fall-back to plain dpkg-buildpackage if no git repository
  dpkg-buildpackage --no-sign --build=any,all --no-pre-clean --no-post-clean
fi
# @TODO: Test building just binaries to make build faster, and later also
# test skipping clean steps and running in parallel
#  '--build=any,all --no-pre-clean --no-post-clean'\
#  '--jobs=auto '\

# @TODO: At least for MariaDB seems rebuild needs 'debian/rules clean' target to run
# otherwise dh_install fails, thus using '--no-pre-clean --no-post-clean'  is not
# compatible with MariaDB
#   dh_install: warning: Cannot find (any matches for) "usr/lib/mysql/plugin/ha_archive.so" (tried in ., debian/tmp)


# Older ccache does not support '--verbose' but will print stats anyway, just
# followed by help section. Newer ccache 4.0+ (Ubuntu 22.04 "Focal", Debian 12
# "Bullseye") however require '--verbose' to show any cache hit stats at all.
ccache --show-stats  --verbose || true

# @TODO: Why is Lintian silent?
# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo "Create lintian.log"
# Seems that --color=auto isn't enough inside a container, so use 'always'.
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian --verbose -EvIL +pedantic --color=always | tee "../lintian.log" || true


cd /tmp/build || exit 1

# Log package contents
echo "Create filelist.log"
for package in *.deb
do
  # shellcheck disable=SC2129
  echo "$package" | cut -d '_' -f 1 >> "filelist.log"
  dpkg-deb -c "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> "filelist.log"
  echo "------------------------------------------------" >> "filelist.log"
done

# Crude but fast and simple way to clean away ANSI color codes from logs
# @TODO: As 'less -K' and other tools support reading colored logs, we could
# consider keeping around colored logs in addition to plain logs for some files
sed -e 's/\x1b\[[0-9;]*[mK]//g' -i *.log
