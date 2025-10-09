#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

log_info "Checking if Debian source package and git repository is compatible with automatic updates"

# Roll back branches and delete tags to revert import
function revert_import() {
  git checkout $UPSTREAM_BRANCH && git tag -d "$(git tag --points-at)" && git reset --hard $UPSTREAM_BRANCH_COMMIT_ID_BEFORE

  if [ "$PRISTINE_TAR" = "True" ]
  then
    git checkout pristine-tar && git reset --hard HEAD^
  fi

  git checkout $DEBIAN_BRANCH && git reset --hard $DEBIAN_BRANCH_COMMIT_ID_BEFORE
}

# Get configs
function gbp_config() {
  if [ -z "$1" ]
  then
    log_error "Error: gbp_config() requires the an argument"
    exit 1
  else
    echo $(gbp config import-orig | grep --only-matching --max-count=1 --perl "$1=\K.*")
  fi
}


# Validate package tracker in git
if [ ! -d .git ]
then
  log_error "Unable to proceed as this package does not seem to be in git version control" \
            "and using git-buildpackage would can't work"
  exit 1
fi

# Validate if upstreamvcs exists
if ! git remote get-url upstreamvcs > /dev/null
then
  log_error "Unable to proceed there is no git remote with the name 'upstreamvcs' which git-buildpackage would expect to fetch from"
  exit 1
fi

# Validate that package is maintained on Salsa so a Merge Request can be submitted
VCS_GIT="$(grep --only-matching --max-count=1 --perl "Vcs-Git: \K.*" debian/control)" || true
log_debug_var VCS_GIT

if [ -z "$VCS_GIT" ]
then
  log_error "Package must be maintained in git and have a Vcs-Git field so that" \
            "a Merge Request can be submitted to update the package"
  exit 1
fi

# Check if a remote exists with url https://salsa.. and don't fail it not found
VCS_GIT_ORIGIN_NAME="$(git remote --verbose | grep --max-count=1 -F $VCS_GIT)" || true
if [ -z "$VCS_GIT_ORIGIN_NAME" ]
then
  # Try again with the SSH URL variant
  VCS_GIT_SSH="${VCS_GIT/https:\/\/salsa.debian.org\//git@salsa.debian.org:}"
  VCS_GIT_ORIGIN_NAME="$(git remote --verbose | grep --max-count=1 -F $VCS_GIT_SSH | cut -f 1)"
fi

if [ -z "$VCS_GIT_ORIGIN_NAME" ]
then
  log_error "Unable to find a git origin that points to the packaging on Salsa," \
            "Debian's GitLab instance"
  exit 1
fi

# Validate that a git-buildpackage config exists
if [ ! -f debian/gbp.conf ]
then
  log_error "Unable to proceed as this package (or branch) lacks a debian/gbp.conf " \
            "and doing operations on packages that don't have explicit git-buildpackage" \
            "is too risky. For an example of a gbp.conf file, see e.g." \
            "https://salsa.debian.org/debian/dh-make/-/blob/master/lib/debian/gbp.conf.ex"
  exit 1
fi

DEBIAN_BRANCH="$(gbp_config debian-branch)"
log_debug_var DEBIAN_BRANCH
DEBIAN_BRANCH_COMMIT_ID_BEFORE="$(git rev-parse --short $DEBIAN_BRANCH)"
log_debug_var DEBIAN_BRANCH_COMMIT_ID_BEFORE

UPSTREAM_BRANCH="$(gbp_config upstream-branch)"
log_debug_var UPSTREAM_BRANCH
UPSTREAM_BRANCH_COMMIT_ID_BEFORE="$(git rev-parse --short $UPSTREAM_BRANCH)"
log_debug_var UPSTREAM_BRANCH_COMMIT_ID_BEFORE

PRISTINE_TAR="$(gbp_config pristine-tar)"
log_debug_var PRISTINE_TAR
if [ "$PRISTINE_TAR" = "True" ]
then
  PRISTINE_TAR_COMMIT_ID_BEFORE="$(git rev-parse --short pristine-tar)"
  log_debug_var PRISTINE_TAR_COMMIT_ID_BEFORE
fi

set -x

log_info "Ensure local git checkout is up-to-date with git remote '$VCS_GIT_ORIGIN_NAME'"
# @TODO: This will only work if fetch possible without SSH credentials
git pull --track-missing "$VCS_GIT_ORIGIN_NAME"

# @TODO: git-buildpackage does not support fetching with URL, only with
# preconfigured git remote names
#gbp pull --track-missing "$VCS_GIT"


# @TODO: Maybe we should not use gbp pull at all, as we ideally want to make
# sure that local git is neither behind _nor_ ahead the canonical packaging git
# repository, and offer to automatically reset local branches to match remote if
# diverged.

# @TODO: To be able to submit MR the package must be on Salsa, but pushing could also
# be done from a fork
