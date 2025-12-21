#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]
then
  log_info "Enable *-proposed for Ubuntu builds to ensure compatibility with other software currently being released"
  # Idempotent sed that will only change the first 'Suite: <release>' once
  sed -i 's/^Suites: \([a-z]*\) /Suites: \1-proposed \1 /' /etc/apt/sources.list.d/ubuntu.sources
  # Example:
  # Suites: resolute resolute-updates resolute-backports
  # Suites: resolute-security
  # ->
  # Suites: resolute-proposed resolute resolute-updates resolute-backports
  # Suites: resolute-security
fi

if ls /ci/extra_repository.* > /dev/null 2>&1
then
  log_info "Enable extra remote repository"

  if [ -f /ci/extra_repository.list ]
  then
    cp --archive --verbose ci/extra_repository.list /etc/apt/sources.list.d/
  fi

  if [ -f /ci/extra_repository.sources ]
  then
    cp --archive --verbose ci/extra_repository.sources /etc/apt/sources.list.d/
  fi

  if [ -f /ci/extra_repository.asc ]
  then
    cp --archive --verbose ci/extra_repository.asc /etc/apt/trusted.gpg.d/
  fi
fi

if ls /debcraft/extra_repository_dir/*.deb > /dev/null 2>&1
then
  log_info "Enable extra local repository"
  cd /debcraft/extra_repository_dir
  apt-ftparchive packages . > Packages
  apt-ftparchive release . > Release
  grep "^Package:" Packages
  # cd has no silent mode flag, so just suppress output
  cd - > /dev/null
  echo 'deb [trusted=yes] file:/debcraft/extra_repository_dir ./' > /etc/apt/sources.list.d/extra_repository_dir.list
fi
