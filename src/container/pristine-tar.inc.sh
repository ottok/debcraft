#!/bin/bash

# Parse upstream version to extract pristine-tar
# Use pre-set DEBIAN_VERSION from host if available, otherwise parse it
if [ -z "$DEBIAN_VERSION" ]
then
  DEBIAN_VERSION="$(dpkg-parsechangelog --show-field=version)"
fi
log_debug_var DEBIAN_VERSION

# Remove epoch (if any) and Debian revision to get upstream version
UPSTREAM_VERSION="${DEBIAN_VERSION#*:}"
log_debug_var UPSTREAM_VERSION
UPSTREAM_VERSION="${UPSTREAM_VERSION%%-*}"
log_debug_var UPSTREAM_VERSION

# Find an orig tarball in the parent directory and set ORIG_TARBALL_EXISTS.
# Keep the extension order in sync with find_orig_tarball() in generic.inc.sh.
# The package name and version come from the locally mounted source tree under
# the user's control. Path traversal via these values is not a security
# boundary, as building the source package already executes arbitrary code.
# PACKAGE_NAME is set by the calling script before sourcing this file.
function find_orig_tarball_in_parent() {
  local ext
  for ext in xz gz bz2 lzma zst
  do
    ORIG_TARBALL="../${PACKAGE_NAME}_${UPSTREAM_VERSION}.orig.tar.${ext}"
    if [ -f "$ORIG_TARBALL" ]
    then
      ORIG_TARBALL_EXISTS=true
      return 0
    fi
  done
  ORIG_TARBALL_EXISTS=false
  return 1
}

# Configure gbp to reuse an existing orig tarball instead of creating a new one
# shellcheck disable=SC2034 # GBP_ARGS is used by the caller after sourcing this file
function set_gbp_args_for_orig_tarball() {
  if [ "$ORIG_TARBALL_EXISTS" = true ]
  then
    log_info "Using existing orig tarball, preventing gbp from creating a new one"
    GBP_ARGS="--git-no-create-orig"
  else
    log_info "No orig tarball found, allowing gbp to create one from upstream tag"
    GBP_ARGS=""
  fi
}

# If the orig tarball is already available, it will be used as-is. There is no
# need to export anything from pristine-tar.
PRISTINE_TAR_BRANCH_EXISTS=false
if [ -n "$(git branch --list pristine-tar)" ]
then
  PRISTINE_TAR_BRANCH_EXISTS=true
elif git show-ref --verify --quiet refs/remotes/origin/pristine-tar
then
  PRISTINE_TAR_BRANCH_EXISTS=true
fi

if find_orig_tarball_in_parent
then
  if [ "$PRISTINE_TAR_BRANCH_EXISTS" = true ]
  then
    log_info "Use original source package $ORIG_TARBALL and disregard branch pristine-tar contents"
  else
    log_info "Use original source package $ORIG_TARBALL"
  fi
  return 0
fi

# Ensure local pristine-tar branch exists if remote has it
# (handles fresh clones where only origin/pristine-tar exists)
if [ "$PRISTINE_TAR_BRANCH_EXISTS" = true ] && [ -z "$(git branch --list pristine-tar)" ]
then
  log_info "Creating local pristine-tar branch from origin/pristine-tar"
  git branch pristine-tar origin/pristine-tar
fi

# If pristine-tar branch exists, attempt to export so when package builds it
# would already have access to upstream source tarball and signature so they are
# used.
if [ "$PRISTINE_TAR_BRANCH_EXISTS" = true ]
then
  # Get signature file if exists while ignoring any errors from the output parsing
  SIGNATURE_FILE="$(git ls-tree --name-only pristine-tar | grep "_$UPSTREAM_VERSION.*asc$")" || true
  log_debug_var SIGNATURE_FILE
  if [ -n "$SIGNATURE_FILE" ]
  then
    TARBALL_FILE="$(basename --suffix .asc "$SIGNATURE_FILE")"
    # pristine-tar checkout automatically appends .delta, so strip it if present
    TARBALL_FILE="${TARBALL_FILE%.delta}"
    # The option --signature-file exists only starting from version 1.45 in Debian Buster
    if dpkg --compare-versions "$(dpkg-query -W -f='${Version}' pristine-tar)" gt "1.45"
    then
      log_info "Create original source package and signature using pristine-tar"
      pristine-tar checkout "../$TARBALL_FILE" --signature-file "../$SIGNATURE_FILE"
    else
      log_info "Create original source package using pristine-tar"
      pristine-tar checkout "../$TARBALL_FILE"
    fi
  else
    # No signature file, but check if tarball exists without signature
    TARBALL_FILE="$(git ls-tree --name-only pristine-tar | grep "_${UPSTREAM_VERSION}\.orig\.tar\." | head -n 1)" || true
    if [ -n "$TARBALL_FILE" ]
    then
      # pristine-tar checkout automatically appends .delta, so strip it if present
      TARBALL_FILE="${TARBALL_FILE%.delta}"
      log_info "Create original source package using pristine-tar"
      pristine-tar checkout "../$TARBALL_FILE"
    else
      log_info "No orig tarball found on pristine-tar branch"
    fi
  fi
fi

# pristine-tar checkout may have just created the orig tarball. Check again so
# gbp reuses it instead of creating a new one from the upstream tag.
find_orig_tarball_in_parent > /dev/null || true
