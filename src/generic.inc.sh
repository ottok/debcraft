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
