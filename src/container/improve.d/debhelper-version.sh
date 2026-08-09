#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Bump Debhelper version by one, which most of the time should be safe to do
if grep --quiet --only-matching "debhelper-compat (= 13)" debian/control
then
  log_command sed -i 's/ debhelper-compat (= 13)/ debhelper-compat (= 14)/' debian/control

  # Commit if file changed
  if ! git diff --quiet debian/control
  then
    # Only stage the specific file we modified to avoid committing any
    # unrelated changes that might exist in the working directory
    git add debian/control
    git commit -F - <<EOF
Bump Debhelper version from 13 to 14

No changes required after reviewing checklist at
https://manpages.debian.org/unstable/debhelper/debhelper-compat-upgrade-checklist.7.en.html#v14
EOF
  fi
else
  echo "Package not using Debhelper 13, will not attempt to bump to 14"
fi
