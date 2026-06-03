#!/bin/bash

# Clean up before (and after) a build
function reset_if_source_repository_and_option_clean() {
  if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
  then
    echo
    log_info "Cleaning and resetting the git repository (including submodules)"
    git clean -fdx --quiet
    git submodule --quiet foreach --recursive git clean -fdx
    git reset --hard --quiet
    git submodule --quiet foreach --recursive git reset --hard
    git submodule --quiet update --init --recursive
  fi
}

# Copy upstream tarball from parent directory to destination if it exists
# Usage: copy_upstream_tarball <package> <version> <destination>
function copy_upstream_tarball() {
  local package="$1"
  local version="$2"
  local dest="$3"

  for ext in xz gz bz2 lzma zst
  do
    local tarball_path="../${package}_${version}.orig.tar.${ext}"
    if [ -f "$tarball_path" ]
    then
      cp_update_none "$tarball_path" "$dest/"
      return 0
    fi
  done
  return 1
}

# Check if orig tarball already exists in parent directory
# Usage: check_orig_tarball_exists <package> <version>
# Returns: 0 if found, 1 if not found
function check_orig_tarball_exists() {
  local package="$1"
  local version="$2"

  for ext in xz gz bz2 lzma zst
  do
    if [ -f "../${package}_${version}.orig.tar.${ext}" ]
    then
      return 0
    fi
  done
  return 1
}

# cp --update=none if available, otherwise use legacy/obsolete cp --no-clobber
# coreutils version 9.3 was released 2023-04-18
function cp_update_none() {
  coreutils_version=$(cp --version | head -1 | sed "s/.* //")
  if printf "9.3\n%s" "$coreutils_version" | sort --version-sort --check=quiet
  then
    cp --verbose --update=none "$@"
  else
    cp --verbose --no-clobber "$@"
  fi
}

# Ensure git user identity is available for operations that make commits.
# If the repository has local user.name/email, nothing is done.  If not
# locally but globally configured, exports GIT_AUTHOR_NAME,
# GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME and GIT_COMMITTER_EMAIL so the
# identity can be forwarded into containers.  If neither is configured,
# prints an error and exits.
function ensure_git_identity() {
  if git config --local user.name >/dev/null 2>&1 &&
     git config --local user.email >/dev/null 2>&1
  then
    return 0
  fi

  local global_name global_email
  global_name="$(git config --global user.name 2>/dev/null || true)"
  global_email="$(git config --global user.email 2>/dev/null || true)"

  if [ -n "$global_name" ] && [ -n "$global_email" ]
  then
    export GIT_AUTHOR_NAME="$global_name"
    export GIT_AUTHOR_EMAIL="$global_email"
    export GIT_COMMITTER_NAME="$global_name"
    export GIT_COMMITTER_EMAIL="$global_email"
    log_info "Using global git identity '$global_name <$global_email>'"
    return 0
  fi

  log_error "Git user name and email are not configured." \
            "Please set them in this repository with:" \
            "  git config --local user.name 'Your Name'" \
            "  git config --local user.email 'you@example.com'" \
            "Or configure them globally with:" \
            "  git config --global user.name 'Your Name'" \
            "  git config --global user.email 'you@example.com'"
  exit 1
}
