#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# shellcheck source=src/container/cache.inc.sh
source "/cache.inc.sh"

# Run in the background to not block shell prompt
# shellcheck source=src/container/debcraft-repository.sh
source "/debcraft-repository.sh" &

sleep 1

log_info "Type 'exit' or press Ctrl+D to exit"

/bin/bash
