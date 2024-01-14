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

# Prepare stats
ccache --zero-stats > /dev/null
BUILD_START_TIME="$EPOCHSECONDS"

# Mimic debuild log filename '../<package>_<version>_<arch>.build'
# https://manpages.debian.org/unstable/devscripts/debuild.1.en.html#DESCRIPTION
# https://salsa.debian.org/debian/devscripts/-/blob/main/scripts/debuild.pl?ref_type=heads#L974-983
BUILD_LOG="../$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_$(dpkg-architecture --query DEB_HOST_ARCH).build"

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
  gbp buildpackage \
    --git-builder='dpkg-buildpackage --no-sign --build=any,all' \
    --git-no-create-orig | tee -a "$BUILD_LOG"
else
  # Fall-back to plain dpkg-buildpackage if no git repository
  dpkg-buildpackage --no-sign --build=any,all | tee -a "$BUILD_LOG"
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

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo
log_info "Create lintian.log"
# Seems that --color=auto isn't enough inside a container, so use 'always'.
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian --verbose -EvIL +pedantic --color=always ../*.changes | tee -a "../lintian.log" || true

# @TODO: Run Lintian in background (with & and later run 'wait') so that the
# filelist log can be created in parallel? Will it make overall progress faster?

cd /tmp/build || exit 1

# Log package contents
echo
log_info "Create filelist.log"
for package in *.deb
do
  # shellcheck disable=SC2129
  echo "$package" | cut -d '_' -f 1 >> "filelist.log"
  dpkg-deb --contents "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> "filelist.log"
  echo "------------------------------------------------" >> "filelist.log"
done

# @TODO: Both of these have the same output showing what files are new/changed
# and could be easily done, but offers no additional value:
#   debdiff --from previous/*.deb --to *.deb
#   debdiff previous/*.changes *.changes

# @TODO: Log output of `ldd -v` for each binary to track how dynamic dependencies change?

echo
log_info "Create maintainer-scripts.log"
for package in *.deb
do
  # shellcheck disable=SC2129
  PACKAGE_NAME="$(echo "$package" | cut -d '_' -f 1)"
  # Extract to directory with package name
  dpkg-deb --control "$package" "$PACKAGE_NAME"
  # Delete files not worth tracking
  (cd "$PACKAGE_NAME" && rm --force control md5sums templates)
  # Skip if directory is empty
  if [ -n "$(ls --almost-all "$PACKAGE_NAME/")" ]
  then
    # Use tail to list contents in one single file with headers between
    tail --lines=9999 "$PACKAGE_NAME"/* >> maintainer-scripts.log
  fi
  # Clean up temporary directory
  rm --recursive --force "$PACKAGE_NAME"
done


# Crude but fast and simple way to clean away ANSI color codes from logs
# @TODO: As 'less -K' and other tools support reading colored logs, we could
# consider keeping around colored logs in addition to plain logs for some files
sed -e 's/\x1b\[[0-9;]*[mK]//g' -i ./*.log

# Automatically do comparisons to previous build if exists
if [ -d "previous" ]
then
  for LOGFILE in *.log
  do
    # For each log, if a previous one with same name is found, create a diff
    # file but if there are no difference, remove the empty file
    if [ -f "previous/$LOGFILE" ]
    then
      ! diff -u "previous/$LOGFILE" "$LOGFILE" > "$LOGFILE.diff" || rm "$LOGFILE.diff" &
    fi
  done

  echo
  log_info "Create diffoscope report comparing to previous build"
  # Exit status is zero only if inputs are identical, so ignore exit code
  diffoscope --html=diffoscope.html \
    --exclude='*.log' --exclude='*.diff' --exclude='*.build' --exclude='*.html' \
    --exclude=previous --exclude=source \
    previous/ . || true
fi

# Note: Command `dpkg-deb --info filename.deb` just lists package size and
# debian/control snippet, not very useful for comparisons.
#
# Note: File list from commands `dpkg-deb --contents filename.deb` and `dpkg
# --contents filename.deb` is identical and contains fimestamps (of upstream
# release date?), so a diff would always show every single line as having
# changes and thus not suitable for comparisons.


# Wait to ensure all processes that were backgrounded earlier have completed too
wait

echo
log_info "Build completed in $((EPOCHSECONDS - BUILD_START_TIME)) seconds and created:"
# Don't show the mountpoint dir 'source'
ls --width=5 --size --human-readable --color=always --ignore={source,previous}
