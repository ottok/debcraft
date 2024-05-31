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

log_info "Run autopkgtest"
autopkgtest --ignore-restrictions=breaks-testbed --no-built-binaries --shell-fail -- null

# For command options and configs, see
# - https://manpages.debian.org/unstable/autopkgtest/autopkgtest.1.en.html
# - https://sources.debian.org/src/autopkgtest/latest/doc/README.running-tests.rst/
# - https://sources.debian.org/src/autopkgtest/latest/doc/README.package-tests.rst/
