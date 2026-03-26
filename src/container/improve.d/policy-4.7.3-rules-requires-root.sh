#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Debian Policy 4.7.3
# Drop redundant "Rules-Requires-Root: no"
if grep -qE "^\s*Rules-Requires-Root:\s*no\s*$" debian/control
then
  log_command sed -i -E '/^\s*Rules-Requires-Root:\s*no\s*$/d' debian/control

  # Commit if file changed
  if ! git diff --quiet debian/control
  then
    # Only stage the specific file we modified to avoid committing any
    # unrelated changes that might exist in the working directory
    git add debian/control
    git commit -F - <<'EOF'
Drop redundant `Rules-Requires-Root: no`

As of dpkg version 1.22.13, this field is set to "no" by default.
As such, in this case the Rules-Requires-Root field is redundant and should be
removed.
EOF
  fi
else
  echo "No 'Rules-Requires-Root: no' found"
fi
