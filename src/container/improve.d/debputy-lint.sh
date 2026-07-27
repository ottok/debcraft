#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

CMD=(debputy lint --auto-fix)
echo "++ ${CMD[*]}"

if "${CMD[@]}"
then
  true
else
  EXIT_CODE=$?
  log_warn "Failed with exit code $EXIT_CODE."
fi

if ! git diff --quiet
then
  git commit -a -F - <<'EOF'
Apply `debputy lint`

Run Debputy to automatically fix various minor issues.

EOF
fi
