#!/bin/bash

# Clean up before (and after) a build
function reset_if_source_repository_and_option_clean() {
  if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
  then
    log_info "Ensure git repository is clean and reset (including submodules)"
    git clean -fdx --quiet
    git submodule --quiet foreach --recursive git clean -fdx
    git reset --hard --quiet
    git submodule --quiet foreach --recursive git reset --hard
    git submodule --quiet update --init --recursive
  fi
}
