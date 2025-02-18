#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# shellcheck source=src/container/debcraft-repository.sh
source "/debcraft-repository.sh"

apt-get update

# Normally dpkg-source applies the patches, but when running a binary-only
# build directly in the Debian packaging git repository dpkg-source will be
# skipped and sources will remain unpatched
if [ -f debian/patches/series ]
then
  log_warn "Debian patches are *not* applied automatically as sources are tested as-is."
  log_warn "Run 'gbp pq import --force' or equivalent to apply patches before starting tests."
fi

log_info "Run autopkgtest"
autopkgtest --ignore-restrictions=breaks-testbed --no-built-binaries --shell-fail -- null

# For command options and configs, see
# - https://manpages.debian.org/unstable/autopkgtest/autopkgtest.1.en.html
# - https://sources.debian.org/src/autopkgtest/latest/doc/README.running-tests.rst/
# - https://sources.debian.org/src/autopkgtest/latest/doc/README.package-tests.rst/
