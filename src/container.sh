#!/bin/bash

if [ -n "$(podman images --filter reference="$CONTAINER" --quiet)" ]
then
  log_info "Use container '$CONTAINER' for package '$PACKAGE'"
else
  log_info "Create container $CONTAINER"
  TEMPDIR="$(mktemp --directory)"
  cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$TEMPDIR"

  # Make it visible what this temporary directory was used for
  echo "CONTAINER=$CONTAINER" >> "$TEMPDIR/debcraft"

  # Customize baseimage
  sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$TEMPDIR/Containerfile"

  # Customize preinstalled build dependencies
  cp debian/control "$TEMPDIR/control"

  # @TODO: Pull new only if image previous build was successful etc
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"

  podman build --tag "$CONTAINER" "$TEMPDIR"
fi
