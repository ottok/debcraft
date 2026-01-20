#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# Roll back branches and delete tags to revert import
#
# @TODO: This should be smart enough to check the version string it sees in
# latest tag and commit contents to know if they actually should be rolled back
# or not
function revert_import() {
  log_info "Attempting to revert the changes done by 'debcraft update'"
  log_command git checkout "$UPSTREAM_BRANCH" \
  && log_command git tag -d "$(git tag --points-at)" \
  && log_command git reset --hard "$UPSTREAM_BRANCH_COMMIT_ID_BEFORE"

  if [ "$PRISTINE_TAR" = "True" ]
  then
    log_command git checkout pristine-tar \
    && log_command git reset --hard "$PRISTINE_TAR_COMMIT_ID_BEFORE"
  fi

  log_command git checkout "$DEBIAN_BRANCH" \
  && log_command git reset --hard "$DEBIAN_BRANCH_COMMIT_ID_BEFORE"

  log_info "Successfully reverted the changes done by 'debcraft update'"
}

# Get configs
function gbp_config() {
  if [ -z "$1" ]
  then
    log_error "Error: gbp_config() requires the an argument"
    exit 1
  else
    gbp config import-orig | grep --only-matching --max-count=1 --perl "$1=\K.*"
  fi
}

if ! command -V gbp > /dev/null
then
  log_error "This command only works on a system with 'git-buildpackage' installed"
  exit
fi

log_info "Checking this Debian source package and git repository is compatible with automatic updates"

# Validate package tracker in git
if [ ! -d .git ]
then
  log_error "Unable to proceed as this package does not seem to be in git" \
            "version control and using git-buildpackage would can't work"
  exit 1
fi

# Validate that package actually can have an upstream and is not a native package
if ! grep --quiet -F "3.0 (quilt)" debian/source/format
then
  log_error "Unable to proceed as the source package format does not match '3.0 (quilt)':"
  tail --verbose debian/source/format
  exit 1
fi

# Validate that package is maintained on Salsa so a Merge Request can be submitted
VCS_GIT="$(grep --only-matching --max-count=1 --perl "Vcs-Git: \K.*" debian/control)" || true
log_debug_var VCS_GIT

if [ -z "$VCS_GIT" ]
then
  log_error "Package must be maintained in git and have a Vcs-Git field so" \
            "that a Merge Request can be submitted to update the package"
  exit 1
fi

# Check if a remote exists with url https://salsa.. and don't fail it not found
VCS_GIT_ORIGIN_NAME="$(git remote --verbose | grep --max-count=1 -F "$VCS_GIT")" || true
if [ -z "$VCS_GIT_ORIGIN_NAME" ]
then
  # Try again with the SSH URL variant
  VCS_GIT_SSH="${VCS_GIT/https:\/\/salsa.debian.org\//git@salsa.debian.org:}"
  VCS_GIT_ORIGIN_NAME="$(git remote --verbose | grep --max-count=1 -F "$VCS_GIT_SSH" | cut -f 1)"
fi

if [ -z "$VCS_GIT_ORIGIN_NAME" ]
then
  log_error "Unable to find a git origin that points to the packaging on" \
            "Salsa, Debian's GitLab instance"
  exit 1
fi

# Validate that upstreamvcs exists
UPSTREAMVCS_GIT="$(git remote get-url upstreamvcs 2> /dev/null)" || true
if [ -z "$UPSTREAMVCS_GIT" ]
then
  log_info "No git remote with the name 'upstreamvcs' found, attempting to" \
           "add it using debian/upstream/metadata"
  UPSTREAMVCS_URL="$(grep --only-matching --max-count=1 --perl "Repository: \K.*" debian/upstream/metadata)" || true
  log_debug_var UPSTREAMVCS_URL

  if [ -z "$UPSTREAMVCS_URL" ]
  then
    log_error "Unable to proceed there is no git remote with the name" \
              "'upstreamvcs' which git-buildpackage would expect to fetch from"
    exit 1
  fi

  log_info "Add git remote 'upstreamvcs' $UPSTREAMVCS_URL"
  git remote add upstreamvcs "$UPSTREAMVCS_URL"
  # @TODO: Ideally upstreamvcs would be added with only the `-t main` or
  # equivalent to have only the main development branch tracked to avoid
  # pullning in miscellaneous extra branches and commits
fi

# Validate that a git-buildpackage config exists
if [ ! -f debian/gbp.conf ]
then
  log_error "Unable to proceed as this package (or branch) lacks a debian/gbp.conf" \
            "and doing operations on packages that don't have explicit git-buildpackage" \
            "is too risky. For an example of a gbp.conf file, see e.g." \
            "$(clickable_link "salsa.debian.org/debian/dh-make/-/blob/master/lib/debian/gbp.conf.ex")"
  exit 1
fi

# Used in commands below
SOURCE_PACKAGE_NAME=$(head -n 1 debian/changelog | cut -d ' ' -f 1)

# Used in revert_import() and commands below
DEBIAN_BRANCH="$(gbp config import-orig.debian-branch)"
log_debug_var DEBIAN_BRANCH
DEBIAN_BRANCH_COMMIT_ID_BEFORE="$(git rev-parse --short "$DEBIAN_BRANCH")"
log_debug_var DEBIAN_BRANCH_COMMIT_ID_BEFORE

# Used in revert_import()
UPSTREAM_BRANCH="$(gbp config import-orig.upstream-branch)"
log_debug_var UPSTREAM_BRANCH
UPSTREAM_BRANCH_COMMIT_ID_BEFORE="$(git rev-parse --short "$UPSTREAM_BRANCH")"
log_debug_var UPSTREAM_BRANCH_COMMIT_ID_BEFORE

# Used in revert_import()
PRISTINE_TAR="$(gbp config import-orig.pristine-tar)"
log_debug_var PRISTINE_TAR
if [ "$PRISTINE_TAR" = "True" ]
then
  PRISTINE_TAR_COMMIT_ID_BEFORE="$(git rev-parse --short pristine-tar)"
  log_debug_var PRISTINE_TAR_COMMIT_ID_BEFORE
fi

log_info "Ensuring local git checkout is up-to-date with git remote '$VCS_GIT'"

# Make sure latest commits are fetched from the official vcs-git location
git remote add vcs-git "$VCS_GIT"
log_command gbp pull --track-missing vcs-git
git remote remove vcs-git
# @TODO: If git-buildpackage adds support for fetching with URL, the above could
# be replaced with simply:
#   gbp pull --track-missing "$VCS_GIT"

# @TODO: Maybe we should not use gbp pull at all, but something custom instead
# that would make sure sure that local git is neither behind _nor_ ahead the
# canonical packaging git repository, and offer to automatically reset local
# branches to match remote if diverged.

# @TODO: To be able to submit MR the package must be on Salsa, but pushing could
# also be done from a fork

# Remove Salsa URL and .git extension, and urlencode slash with '%2F' to get the Salsa project name
SALSA_PROJECT_API_NAME="${VCS_GIT#https://salsa.debian.org/}"
SALSA_PROJECT_API_NAME="${SALSA_PROJECT_API_NAME%.git}"
SALSA_PROJECT_API_NAME="${SALSA_PROJECT_API_NAME//\//%2F}"

OPEN_MRS="$(curl -s https://salsa.debian.org/api/v4/projects/"$SALSA_PROJECT_API_NAME"/merge_requests?state=opened | jq -r '.[] | "\t\u001b]8;;\(.web_url)\u001b\\MR!\(.iid)\t\(.title)\u001b]8;;\u001b\\"')"

if [ -n "$OPEN_MRS" ]
then
  log_info "This project has open Merge Requests that should probably be reviewed first:"
  echo "$OPEN_MRS"
  echo
  read -r -p "Press Ctrl+C to abort and attend Merge Requests, or press enter to proceed"
fi

# @TODO: Debsnap is too verbose, write something custom and light-weight that
# ensures git history includes the latest versions uploaded to Debian
#
# PREVIOUS_VERSION=$(dpkg-parsechangelog --count 2 --offset 1 --show-field Version)
#
# log_info "Ensure git repository head matches what as most recently uploaded to Debian"
#
# DEBSNAP_DIR="$(mktemp -d)"
# (cd "$DEBSNAP_DIR"; debsnap --first "$PREVIOUS_VERSION" "$SOURCE_PACKAGE_NAME")
# gbp import-dscs "$DEBSNAP_DIR"/*/*.dsc

log_info "Fetching upstream git tags from $(git remote get-url upstreamvcs) to" \
         "see if there are new release tags"
# Use `--verbose` so there is always some output, capture stderr as `--verbose`
# seems to use it, and `tail` to avoid too much output
log_command_cap_output git fetch upstreamvcs --tags --verbose

# @TODO: If Debian packaging stored upstream OpenPGP or SSH keys, the next step
# after fetching tags would be to run `git verify-tag`

log_info "Run 'gbp import-orig --uscan' to import new upstream version (if found)"
log_command gbp import-orig --uscan --no-interactive --postimport="dch -v %(version)s 'New upstream release'"

# @TODO: Note that if upstream was already imported to the git repository, but
# `debcraft update` is run on some other branch, `uscan` won't find anything and
# `import-ref` should be run instead, with as known upstream release tag, e.g.:
#   gbp import-ref --upstream-version=10.11.14 --no-sign-tags --no-interactive --postimport="dch -v %(version)s # 'New upstream release'"

# @TODO: If git-buildpackage didn't sign the tags automatically, one would need
# to run something along this to re-tag with signatures:
#   git tag --force --sign --message="$(git tag --list --format='%(contents:subject)' upstream/26.4.24)" upstream/26.4.24 upstream/latest

log_info "Pre-populate debian/changelog with appropriate update and launch" \
         "editor for proof-reading and tweaking"
# Note that this will use whatever user has configured as their preferred 'sensible-editor'
log_command gbp dch --distribution=UNRELEASED --spawn-editor=always --commit --commit-msg="Update changelog and refresh patches after %(version)s import" -- debian

# Remove Debian revision from `%(version)s` to have pure upstream version in commit message
message=$(git log -1 --pretty=%s)
message="${message/ [0-9]*:/ }"  # Remove epoch (e.g., " 1:") while preserving context
message="${message//-[0-9]* / }"  # Remove Debian revision (e.g., "-0ubuntu1") while keeping following word separated
git commit --amend --no-edit --message="$message"

log_info "Rebase debian/patches/* on this new upstream version"
log_command gbp pq import --force --time-machine=10

# Perform rebase with safeguard
if ! git rebase -
then
    # Failure path - instruct user to use separate shell session
    log_warn "Patch rebase failed due to conflicts"
    echo
    log_info "You must resolve these conflicts in a SEPARATE shell session before 'debcraft update' can proceed"
    echo
    echo "  1. Open a NEW shell session / terminal window"
    echo "  2. Ensure you are in directory $(pwd)"
    echo "  3. To start resolving the merge conflict, run:"
    echo "       git mergetool"
    echo "  4. After exiting the merge tool, run:"
    echo "       git rebase --continue"
    echo "  5. Repeat steps 3-4 until you see 'Successfully rebased and updated'"
    echo "  6. Return to THIS session when rebase is complete and press Enter to continue"
    echo

    while true
    do
        read -r -p "Press [Enter] to continue after rebase, or type [a]bort to revert all changes: " choice

        case $choice in
            '')
                # Verify rebase actually completed successfully
                if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]
                then
                    log_warn "Rebase appears to still be in progress! Please ensure you completed the rebase in the other shell."
                    echo
                else
                    break
                fi
                ;;
            [aA])
                log_info "Aborting update and cleaning up..."

                # Abort rebase if still in progress
                if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]
                then
                    git rebase --abort
                fi

                # Drop patch-queue branch
                gbp pq drop 2>/dev/null || true

                # Revert entire import
                revert_import
                exit 1
                ;;
            *)
                log_warn "Invalid input. Press [Enter] after rebase, or type 'a' to abort."
                ;;
        esac
    done
fi

# Verify we're on the patch-queue branch and export patches
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == patch-queue/* ]]
then
    log_command gbp pq export --drop
    log_command git commit --amend --all --no-edit
else
    log_error "Unexpected branch state: '$CURRENT_BRANCH' not a patch-queue branch."
    revert_import
    exit 1
fi

echo
log_info "Please review the result of the import using 'gitk --all &' or similar command/tool"
echo

while true
do
  read -r -p "Was the new upstream version import successful and should the result be [k]ept, or reverted [K|r]?  " selection
  case $selection in
    ''|[Kk]*)
      echo
      IMPORT_BRANCH_NAME="next/$(git branch --show-current)"
      log_info "Run the following commands to have the import on a new branch" \
              "and publish it for review in your project fork on Salsa:"
      echo "  git checkout -B $IMPORT_BRANCH_NAME"
      echo "  git checkout $DEBIAN_BRANCH && git reset --hard $DEBIAN_BRANCH_COMMIT_ID_BEFORE"
      echo "  git checkout $IMPORT_BRANCH_NAME"
      echo "  git push --set-upstream <fork> $IMPORT_BRANCH_NAME"
      echo
      log_info "Once all changes are done and approved, merge to Debian branch" \
               "and finalize changelog for upload:"
      echo "  git checkout $DEBIAN_BRANCH"
      echo "  git merge $IMPORT_BRANCH_NAME"
      echo "  gbp dch --release --commit -- debian"
      echo "  debcraft release"
      echo
      log_info "Before releasing, remember to review the list of open bug" \
               "reports in Debian in case any of them was fixed by the new" \
               "upstream version, or if any should be fixed in Debian" \
               "proceeding with this release:"
      echo "  querybts --buglist --source $SOURCE_PACKAGE_NAME | sort -h"
      echo
      break
      ;;
    [Rr]*)
      echo
      log_warn "Reverting upstream import!"
      revert_import
      break
      ;;
    *)
      log_warn "Invalid selection. Please enter (k)eep or (r)revert."
      ;;
  esac
done
