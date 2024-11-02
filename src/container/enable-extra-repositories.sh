#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Debug what repositories are available to begin with
grep -r "^deb " /etc/apt/sources.*

. /etc/os-release

# @TODO: Add base repositories if missing?
cat << EOF > /etc/apt/sources.list.d/base-$VERSION_CODENAME-repos.list
deb http://deb.debian.org/debian $VERSION_CODENAME main
deb http://deb.debian.org/debian-security $VERSION_CODENAME-security main
deb http://deb.debian.org/debian $VERSION_CODENAME-updates main
EOF

# @TODO: Add experimental if changelog is experimental, or git branch 'debian/experimental'?
echo "deb http://deb.debian.org/debian experimental main" > /etc/apt/sources.list.d/experimental.list

# @TODO: Add backports if changelog is *-backports, or git branch 'debian/*-backports'?
echo "deb http://deb.debian.org/debian $VERSION_CODENAME-backports main" > /etc/apt/sources.list.d/backports.list

# @TODO: Custom repository passed in as a variable? Is path, use local repo. If URL, use remote repo.


apt-get update

apt-get update
