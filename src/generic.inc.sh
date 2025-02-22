#!/bin/bash

# Clean up before (and after) a build
function reset_if_source_repository_and_option_clean() {
  if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
  then
    log_info "Ensure git repository is clean and reset (including submodules)"
    git clean -fdx
    git submodule foreach --recursive git clean -fdx
    git reset --hard
    git submodule foreach --recursive git reset --hard
    git submodule update --init --recursive
  fi
}
