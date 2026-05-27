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
  # Get signature file(s) if exists while ignoring any errors from the output parsing
  SIGNATURE_FILES="$(git ls-tree --name-only pristine-tar | grep "_$UPSTREAM_VERSION.*asc$" || true)"
  log_debug_var SIGNATURE_FILES
  if [ -n "$SIGNATURE_FILES" ]
  then
    while IFS= read -r SIGNATURE_FILE
    do
      [ -n "$SIGNATURE_FILE" ] || continue
      TARBALL_FILE="$(basename --suffix .asc "$SIGNATURE_FILE")"
      # pristine-tar checkout automatically appends .delta, so strip it if present
      TARBALL_FILE="${TARBALL_FILE%.delta}"
      # The option --signature-file exists only starting from version 1.45 in Debian Buster
      if [ ! -f "../$TARBALL_FILE" ]
      then
        if dpkg --compare-versions "$(dpkg-query -W -f='${Version}' pristine-tar)" gt "1.45"
        then
          log_info "Create original source package and signature using pristine-tar"
          if ! pristine-tar checkout "../$TARBALL_FILE" --signature-file "../$SIGNATURE_FILE"
          then
            if [[ "$TARBALL_FILE" == *"orig-"*.tar.* ]]
            then
              log_error "pristine-tar failed to checkout component tarball $TARBALL_FILE"
              exit 1
            else
              log_info "pristine-tar failed to checkout main tarball $TARBALL_FILE - will let gbp create it from upstream tag"
            fi
          fi
        else
          log_info "Create original source package using pristine-tar"
          if ! pristine-tar checkout "../$TARBALL_FILE"
          then
            if [[ "$TARBALL_FILE" == *"orig-"*.tar.* ]]
            then
              log_error "pristine-tar failed to checkout component tarball $TARBALL_FILE"
              exit 1
            else
              log_info "pristine-tar failed to checkout main tarball $TARBALL_FILE - will let gbp create it from upstream tag"
            fi
          fi
        fi
      else
        log_info "Tarball $TARBALL_FILE already exists, skipping pristine-tar checkout"
      fi
    done <<< "$SIGNATURE_FILES"
  else
    # No signature file, but check if tarball(s) exist without signature
    # Support multipart packages with multiple upstream tarballs (e.g. orig-component.tar)
    TARBALL_FOUND=false
    while IFS= read -r TARBALL_FILE
    do
      [ -n "$TARBALL_FILE" ] || continue
      # pristine-tar checkout automatically appends .delta, so strip it if present
      TARBALL_FILE="${TARBALL_FILE%.delta}"
      if [ ! -f "../$TARBALL_FILE" ]
      then
        log_info "Create original source package using pristine-tar"
        if ! pristine-tar checkout "../$TARBALL_FILE"
        then
          # Component tarballs (orig-*.tar.*) cannot be recreated by gbp, so
          # their absence is fatal. The main orig.tar.* can be recreated by gbp
          # from the upstream tag, so allow that to fail gracefully.
          if [[ "$TARBALL_FILE" == *"orig-"*.tar.* ]]
          then
            log_error "pristine-tar failed to checkout component tarball $TARBALL_FILE"
            exit 1
          else
            log_info "pristine-tar failed to checkout main tarball $TARBALL_FILE - will let gbp create it from upstream tag"
          fi
        fi
      else
        log_info "Tarball $TARBALL_FILE already exists, skipping pristine-tar checkout"
      fi
      TARBALL_FOUND=true
    done < <(git ls-tree --name-only pristine-tar | grep "_${UPSTREAM_VERSION}\.orig.*\.tar\..*\.delta$" || true)
    if [ "$TARBALL_FOUND" = false ]
    then
      log_info "No orig tarball found on pristine-tar branch"
    fi
  fi
fi
