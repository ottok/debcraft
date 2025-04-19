#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Documentation section hack to avoid too many comment line prefixes
cat /dev/null <<EOF

On older Debian/Ubuntu containers the sources typically look like this:

  $ cat /etc/apt/sources.list
  # deb http://snapshot.debian.org/archive/debian/20231120T000000Z bullseye main
  deb http://deb.debian.org/debian bullseye main
  # deb http://snapshot.debian.org/archive/debian-security/20231120T000000Z bullseye-security main
  deb http://deb.debian.org/debian-security bullseye-security main
  # deb http://snapshot.debian.org/archive/debian/20231120T000000Z bullseye-updates main
  deb http://deb.debian.org/debian bullseye-updates main

Alternatively they have commented out deb-src lines. Either way, the command
below will work in creating a new additional file with all sources duplicated to
have deb-src lines.

On newer Debian/Ubuntu containers the sources typically look like this:

  $ cat /etc/apt/sources.list.d/debian.sources
  Types: deb
  # http://snapshot.debian.org/archive/debian/20231120T000000Z
  URIs: http://deb.debian.org/debian
  Suites: sid
  Components: main
  Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Adding a 'deb-src' on the 'Types' line is enough to activate source repos.
EOF

if [ -f /etc/apt/sources.list.d/debian.sources ] || [ -f /etc/apt/sources.list.d/ubuntu.sources ]
then
  log_info "Enable deb-src repositories in container (new format)"
  sed 's/Types: deb/Types: deb deb-src/g' -i /etc/apt/sources.list.d/*.sources
elif  [ -f /etc/apt/sources.list ]
then
  log_info "Enable deb-src repositories in container (legacy format)"
  grep '^deb ' /etc/apt/sources.list | \
    sed 's/^deb /deb-src /g' > /etc/apt/sources.list.d/sources-list-with-deb-src.list
else
  log_error "Unable to detect deb-src format - source repositories not enabled!"
  exit 1
fi
