#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

PACKAGE_POLICY_VERSION="$(grep --only-matching --perl-regex "Standards-Version: \K([0-9.]+)" debian/control)"
LATEST_POLICY_VERSION="4.7.3"

# Bump Standards-Version to 4.7.3 (if not already)
if dpkg --compare-versions "$PACKAGE_POLICY_VERSION" lt "$LATEST_POLICY_VERSION"
then
  log_command sed -i -E 's/^\s*Standards-Version:\s*.*\s*$/Standards-Version: '"$LATEST_POLICY_VERSION"'/' debian/control

  # Commit if file changed
  if ! git diff --quiet debian/control
  then
    # Only stage the specific file we modified to avoid committing any
    # unrelated changes that might exist in the working directory
    git add debian/control
    git commit -F - <<EOF
Bump Debian Policy version to $LATEST_POLICY_VERSION

No changes required after reviewing checklist at
https://www.debian.org/doc/debian-policy/upgrading-checklist.html#version-${LATEST_POLICY_VERSION//./_}
EOF
  fi
else
  echo "Package already states 'Standards-Version: $PACKAGE_POLICY_VERSION'"
fi
