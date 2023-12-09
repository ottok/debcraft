#!/bin/bash

log_info "Building source package in ${PWD} for release"

BUILD_DIR="$BUILD_DIRS_PATH/release-$PACKAGE-$BUILD_ID"

mkdir --verbose --parents "$BUILD_DIR"

# Ensure sources are clean
git reset --hard; git clean -fdx

# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
# @TODO: run from BUILD_DIR or output to BUILD_DIR?
gbp buildpackage --git-notify=on --git-builder="debuild --no-lintian -i -I" -S -d

# Show source-only Lintian info without saving it in a file
lintian -EvIL +pedantic --profile=debian --color=always "$BUILD_DIR"/*.changes
