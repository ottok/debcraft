#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

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

if ls /extra_repository_dir/*.deb > /dev/null 2>&1
then
  log_info "Enable extra local repository"
  mkdir -p /tmp/var/extra_repository_dir
  cd /tmp/var/extra_repository_dir
  cp --archive --verbose /extra_repository_dir/*.deb .
  apt-ftparchive packages . > Packages
  apt-ftparchive release . > Release
  grep "^Package:" Packages
  # cd has no silent mode flag, so just suppress output
  cd - > /dev/null
  echo 'deb [trusted=yes] file:/tmp/var/extra_repository_dir ./' > /etc/apt/sources.list.d/extra_repository_dir.list
fi
