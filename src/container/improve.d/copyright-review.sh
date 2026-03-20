#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Use if clause to capture error and continue
CMD="lrc"
echo "++ $CMD"
if $CMD
then
  true
else
  EXIT_CODE=$?
  log_warn "Failed with exit code $EXIT_CODE. Either fix debian/copyright," \
           "or add overrides in debian/lrc.config to suppress false findings."
fi
