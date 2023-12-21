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

# Prepare stats
BUILD_START_TIME="$EPOCHSECONDS"

# Mimic debuild log file naming
BUILD_LOG="../$(dpkg-parsechangelog --show-field=source)_$(dpkg-parsechangelog --show-field=version)_source.build"

# Passed to dpkg-source:
#   --diff-ignore (-i, ignore default file types e.g. .git folder)
#   --tar-ignore (-I, passing ignores to tar)
#
# Use -S so all tools (dpkg-build, dpkg-source) see it as using --build=source
# would not bee enough
gbp buildpackage \
  --git-builder='dpkg-buildpackage --no-sign --diff-ignore --tar-ignore' \
  -S | tee -a "$BUILD_LOG"

# Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
# will likely always emit errors if package complex enough
echo
log_info "Create lintian.log"
# Seems that --color=auto isn't enough inside a container, so use 'always'.
# Using --profle=debian is not needed as build container always matches target
# Debian/Ubuntu release and Lintian in them should automatically default to
# correct profile.
lintian --verbose -EvIL +pedantic --color=always | tee -a "../lintian.log" || true

# @TODO: If `gbp tag` had a mode to give the previous release git tag on current
# branch (adhering to gbp.conf) this script could additionally draft a
# report-bug.txt with all the required text needed to send with
# 'report-bug --body-file=report-bug.txt' or to copy-paste on Launchpad:
#
#   git diff TAG..HEAD | xz > VERSION.debdiff.xz
#   dpkg-parsechangelog --show-field=changes >> report-bug.txt
#   git diff --stat TAG..HEAD >> report-bug.txt

cd /tmp/build || exit 1

# Crude but fast and simple way to clean away ANSI color codes from logs
# @TODO: As 'less -K' and other tools support reading colored logs, we could
# consider keeping around colored logs in addition to plain logs for some files
sed -e 's/\x1b\[[0-9;]*[mK]//g' -i ./*.log

# Automatically do comparisons to previous build if exists
if [ -d "previous" ]
then
  for LOGFILE in *.log
  do
    # For each log, create the diff but if there are no difference, remove the
    # empty file
    ! diff -u "previous/$LOGFILE" "$LOGFILE" > "$LOGFILE.log.diff" || rm "$LOGFILE.log.diff" &
  done
fi

# Wait to ensure all processes that were backgrounded earlier have completed too
wait

echo
log_info "Source build for release completed in $((EPOCHSECONDS - BUILD_START_TIME)) seconds and created:"
# Don't show the mountpoint dir 'source'
ls --width=5 --size --human-readable --color=always --ignore={source,previous}
