#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

CMD=(codespell
     --write-changes
     --check-filenames
     --check-hidden
     --skip="debian/changelog,debian/patches,debian/vendor,debian/source/lintian-overrides,*.lintian-overrides,*.po,*.pot"
     debian/)
echo "++ ${CMD[*]}"

if "${CMD[@]}"
then
  true
else
  EXIT_CODE=$?
  log_warn "Failed with exit code $EXIT_CODE. Either fix spelling manually," \
           "or add overrides in debian/.codespellrc to suppress false findings."
fi

CMD=(debputy lint --spellcheck --auto-fix)
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
Fix spelling

Fix minor typos and spelling mistakes that can be automatically corrected.

No functional changes.
EOF
fi
