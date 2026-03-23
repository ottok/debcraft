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
# Ensure local pristine-tar branch exists if remote has it
# (handles fresh clones where only origin/pristine-tar exists)
if [ -z "$(git branch --list pristine-tar)" ] && \
   git show-ref --verify --quiet refs/remotes/origin/pristine-tar
then
  log_info "Creating local pristine-tar branch from origin/pristine-tar"
  git branch pristine-tar origin/pristine-tar
fi

# If pristine-tar branch exists, attempt to export so when package builds it
# would already have access to upstream source tarball and signature so they are
# used.
if [ -n "$(git branch --list pristine-tar)" ]
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
