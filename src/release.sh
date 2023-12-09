#!/bin/bash

log_info "Building source package in ${PWD}"

# Ensure sources are clean
git reset --hard; git clean -fdx

# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
gbp buildpackage --git-notify=on --git-builder="debuild --no-lintian -i -I" -S -d

# Show source-only Lintian info without saving it in a file
lintian -EvIL +pedantic --profile=debian --color=always ../*.changes 
