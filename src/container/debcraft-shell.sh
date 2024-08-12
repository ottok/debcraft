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

log_info "Type 'exit' or press Ctrl+D to exit"

/bin/bash
