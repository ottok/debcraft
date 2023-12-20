#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

echo "Enable deb-src repositories in container"

if [ -f /etc/apt/sources.list ]
then
  grep '^deb ' /etc/apt/sources.list | \
    sed 's/^deb /deb-src /g' > /etc/apt/sources.list.d/sources-list-with-deb-src.list
fi

if [ -f /etc/apt/sources.list.d/debian.sources ]
then
  sed 's/Types: deb/Types: deb deb-src/g' -i /etc/apt/sources.list.d/debian.sources
fi

apt-get update


exit 0

root@1a361802ba0f:/build# cat /etc/apt/sources.list
# deb http://snapshot.debian.org/archive/debian/20231120T000000Z bullseye main
deb http://deb.debian.org/debian bullseye main
# deb http://snapshot.debian.org/archive/debian-security/20231120T000000Z bullseye-security main
deb http://deb.debian.org/debian-security bullseye-security main
# deb http://snapshot.debian.org/archive/debian/20231120T000000Z bullseye-updates main
deb http://deb.debian.org/debian bullseye-updates main

grep '^deb ' /etc/apt/sources.list | sed 's/^deb /deb-src /g' > /etc/apt/sources.list.d/sources-list-with-deb-src.list

root@1a361802ba0f:/build# cat /etc/apt/sources.list.d/sources-list-with-deb-src.list
deb-src http://deb.debian.org/debian bullseye main
deb-src http://deb.debian.org/debian-security bullseye-security main
deb-src http://deb.debian.org/debian bullseye-updates main


root@8020a675bde6:/build# cat /etc/apt/sources.list.d/debian.sources
Types: deb
# http://snapshot.debian.org/archive/debian/20231120T000000Z
URIs: http://deb.debian.org/debian
Suites: sid
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

sed 's/Types: deb/Types: deb deb-src/g' -i /etc/apt/sources.list.d/debian.sources

root@8020a675bde6:/build# cat /etc/apt/sources.list.d/debian.sources
Types: deb deb-src
# http://snapshot.debian.org/archive/debian/20231120T000000Z
URIs: http://deb.debian.org/debian
Suites: sid
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
