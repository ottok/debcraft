#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

if [ -d /tmp/build/extra-repository ]
then
  mkdir -p /tmp/var/extra-repository
  cd /tmp/var/extra-repository
  cp -a /tmp/build/extra-repository/*.deb .
  apt-ftparchive packages . > Packages
  apt-ftparchive release . > Release
  grep "^Package:" Packages
  # cd has no silent mode flag, so just suppress output
  cd - > /dev/null
  echo 'deb [trusted=yes] file:/var/temp ./' > /etc/apt/sources.list.d/debcraft-extra-repository.list
fi





exit 0


if [ -n "$DEBCRAFT_EXTRA_REPOSITORY" ]
then
  log_info "Enable extra repository: $DEBCRAFT_EXTRA_REPOSITORY"

  if [ -n "$DEBUG" ]
  then
    # Debug what repositories are available to begin with
    head --verbose --lines=50 /etc/apt/sources.list.d/*
    grep -R "^deb " /etc/apt/sources.* || true

    head --verbose /etc/os-release
    . /etc/os-release
  fi
fi
# @TODO: Add base repositories if missing?
#cat << EOF > /etc/apt/sources.list.d/base-$VERSION_CODENAME-repos.list
#deb http://deb.debian.org/debian $VERSION_CODENAME main
#deb http://deb.debian.org/debian-security $VERSION_CODENAME-security main
#deb http://deb.debian.org/debian $VERSION_CODENAME-updates main
#EOF

case "$DEBCRAFT_EXTRA_REPOSITORY" in
  backports)
    # @TODO: Add backports if changelog is *-backports, or git branch 'debian/*-backports'?
    echo "deb http://deb.debian.org/debian $VERSION_CODENAME-backports main" \
      > /etc/apt/sources.list.d/backports.list
    ;;
  experimental)
    # @TODO: Add experimental if changelog is experimental, or git branch 'debian/experimental'?
    echo "deb http://deb.debian.org/debian experimental main contrib non-free non-free-firmware" \
      > /etc/apt/sources.list.d/experimental.list
    # ..or alternatively if apt version is newer than X?:
    cat << EOF > /etc/apt/sources.list.d/experimental.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: experimental
Components: main contrib non-free non-free-firmware
EOF
    ;;
esac

# If there was a custom repository, update apt cache
if [ -n "$DEBCRAFT_EXTRA_REPOSITORY" ]
then
  apt-get update

  # @TODO: Should this also be done following the example in Salsa CI add_extra_repositories.sh?
  #apt-get upgrade --assume-yes
  #apt-get --assume-yes install ca-certificates
fi
