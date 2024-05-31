#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

log_info "Create local apt repository for testing newly build packages"
mkdir -p /var/temp
cd /var/temp
cp -a /tmp/build/previous-build/*.deb .
apt-ftparchive packages . > Packages
apt-ftparchive release . > Release
cd -

echo 'deb [trusted=yes] file:/var/temp ./' >> /etc/apt/sources.list.d/mariadb.list
apt-get update

log_info "Run autopkgtest"
autopkgtest --no-built-binaries --shell-fail -- null

#autopkgtest --no-built-binaries --test-name=configuration-tracing --shell -- null
