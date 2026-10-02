#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# Run a codemod tool if this container has it installed. The tools below are
# packaged in the 'debian-codemods' source package, but as two separate binary
# packages, and neither is available in every distribution, so each tool is
# looked up on its own and a missing one is skipped rather than aborting the
# whole hook.
function run_if_available() {
  local TOOL="$1"
  shift
  if ! command -v "$TOOL" > /dev/null
  then
    echo "No '$TOOL' available in this container, skipping"
    return 0
  fi
  local CMD=("$TOOL" "$@")
  echo "++ ${CMD[*]}"
  if "${CMD[@]}"
  then
    true
  else
    # shellcheck disable=SC2155 # exit code of the tool must not be masked
    local EXIT_CODE=$?
    log_warn "'$TOOL' failed with exit code $EXIT_CODE."
  fi
  # Both tools are built on breezy, which creates '.config/breezy/ignore' in
  # the working tree as it opens it. As that file is untracked it makes the
  # working tree look dirty, and the next tool refuses to run unless its tree
  # is clean, so remove the artifact again after every tool.
  rm -vf .config/breezy/ignore || true
}

# Note! Unlike most other improve.d hooks, this one does not commit anything as
# both tools below commit every change they make by themselves.

# '--no-update-changelog' because this runs on a feature branch and never for a
# release, and the maintainer is expected to write the changelog entry at the
# time the branch is actually merged for upload.
#
# '--modern' to use features and compatibility levels that are not yet
# available in Debian stable. 'debcraft improve' is only ever run on a
# development branch targeting the latest Debian release, so such improvements
# would never end up in a maintenance release, and backporting stays an
# explicit choice for the maintainer.
#
# '--uncertain' to also apply fixes that 'lintian-brush' is not fully certain
# about. This fixes more issues at the risk of getting something wrong, and
# 'lintian-brush' warns in its output whenever it made such a change.
run_if_available lintian-brush \
                 --no-update-changelog \
                 --modern \
                 --uncertain

# 'deb-scrub-obsolete' drops versioned depends, conflicts and build-depends as
# well as maintscript entries that have become obsolete. Note that its
# '--upgrade-release' option defaults to 'oldstable', so it leaves alone any
# constraint that is still needed to upgrade from a supported release. All other
# options are left at their upstream defaults on purpose.
run_if_available deb-scrub-obsolete \
                 --no-update-changelog
