#!/bin/bash

if [ -n "$(podman images --filter label="$CONTAINER" --quiet)" ]
then
  log_info "Use container '$CONTAINER' for package '$PACKAGE'"
else
  log_info "Create container $CONTAINER"
  TEMPDIR="$(mktemp --directory)"
  touch "$TEMPDIR/Containerfile.$CONTAINER"
  cat "$DEBCRAFT_INSTALL_DIR/src/Containerfile" >> "$TEMPDIR/Containerfile.$CONTAINER"

  # Customize baseimage
  sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$TEMPDIR/Containerfile.$CONTAINER"

  # Customize preinstalled build dependencies
  cp debian/control "$TEMPDIR/control"

  # @TODO: Pull new only if image previous build was successful etc
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"

  podman build --tag "$CONTAINER" --file "$TEMPDIR/Containerfile.$CONTAINER"
fi
