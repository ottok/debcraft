#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

if [ -d /debcraft/previous-build ]
then
  log_info "Create local apt repository for testing newly built packages"

  mkdir -p /var/temp
  cd /var/temp || (log_error "Unable to change directory to /var/temp"; exit 1)
  cp --archive /debcraft/previous-build/*.deb .
  apt-ftparchive packages . > Packages
  apt-ftparchive release . > Release
  grep "^Package:" Packages

  # cd has no silent mode flag, so just suppress output
  cd - > /dev/null

  echo 'deb [trusted=yes] file:/var/temp ./' >> /etc/apt/sources.list.d/debcraft.list
  # Run in the background to not block shell prompt
  apt-get update -qq
else
  log_info "No previous build found, skip creating local apt repository"
fi
