#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

echo "Enable deb-src repositories in container"

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
EOF
if [ -f /etc/apt/sources.list ]
then
  grep '^deb ' /etc/apt/sources.list | \
    sed 's/^deb /deb-src /g' > /etc/apt/sources.list.d/sources-list-with-deb-src.list
fi

cat /dev/null <<EOF
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
if [ -f /etc/apt/sources.list.d/debian.sources ]
then
  sed 's/Types: deb/Types: deb deb-src/g' -i /etc/apt/sources.list.d/debian.sources
fi

apt-get update
