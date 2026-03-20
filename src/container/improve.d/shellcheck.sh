#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Read shell scripts into arrays (empty if no matches)
mapfile -t SH_SCRIPTS < <(grep -rlnw debian/ -e '^#!.*/sh' | sort -u || true)
mapfile -t BASH_SCRIPTS < <(grep -rlnw debian/ -e '^#!.*/bash' | sort -u || true)

# Run Shellcheck only if files of the type were found
if [ "${#SH_SCRIPTS[@]}" -gt 0 ]
then
  # Don't stop on findings
  echo "++ shellcheck -x --enable=all --shell=sh" "${SH_SCRIPTS[@]}"
  shellcheck -x --enable=all --shell=sh "${SH_SCRIPTS[@]}" || true
  shellcheck -x --enable=all --format=diff --shell=sh "${SH_SCRIPTS[@]}" >> shellcheck-fixes.diff || true
fi

if [ "${#BASH_SCRIPTS[@]}" -gt 0 ]
then
  # Don't stop on findings
  echo "++ shellcheck -x --enable=all --shell=bash" "${BASH_SCRIPTS[@]}"
  shellcheck -x --enable=all --shell=bash "${BASH_SCRIPTS[@]}" || true
  shellcheck -x --enable=all --format=diff --shell=bash "${BASH_SCRIPTS[@]}" >> shellcheck-fixes.diff || true
fi

# Apply patch if not empty, otherwise just remove it
if [[ -s shellcheck-fixes.diff ]]
then
  # Extra newline for better legibility
  echo
  patch --quiet --strip=1 < shellcheck-fixes.diff
else
  rm -f shellcheck-fixes.diff
fi

# Commit formatting changes if any files were modified by the tools above
if ! git diff --quiet
then
  git add -A
  git commit -F - <<'EOF'
Fix issues found by Shellcheck

Apply all fixes suggested by Shellcheck that can be applied automatically in
a way that is unlikely to change functionality, only make the syntax more
robust to protect from unintentional use and side effect.
EOF
fi
