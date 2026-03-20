#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Apply `debputy reformat --style black`
log_command debputy reformat --style black

# Apply `wrap-and-sort -vast` that modifies more files than debputy, and helps
# ensure all changes are easy to track in git
log_command wrap-and-sort -ast

# Commit formatting changes if any files were modified by the tools above
if ! git diff --quiet
then
  git add -A
  git commit -F - <<'EOF'
Apply consistent formatting to packaging files

Run `debputy reformat --style black` and `wrap-and-sort -vast` to enforce
uniform deb822 formatting with one item per line. This makes future
changes to dependencies and other lists easier to track in git diffs.

No functional changes.
EOF
fi
