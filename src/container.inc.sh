#!/bin/bash

if [ -n "$("$CONTAINER_CMD" images --filter reference="$CONTAINER" --quiet)" ] && [ -z "$DEBUG" ]
then
  log_info "Container '$CONTAINER' already exists, no need to build it"
else
  log_info "Create container $CONTAINER"

  TEMPDIR="$(mktemp --directory)"
  log_debug_var "TEMPDIR"

  cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$TEMPDIR"

  # Make it visible what this temporary directory was used for
  echo "CONTAINER=$CONTAINER" >> "$TEMPDIR/debcraft"

  # Customize baseimage
  sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$TEMPDIR/Containerfile"

  # Customize preinstalled build dependencies
  cp debian/control "$TEMPDIR/control"

  # @TODO: Pull new only if image previous build was successful etc
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"

  "$CONTAINER_CMD" build --tag "$CONTAINER" "$TEMPDIR" | tee -a "$TEMPDIR/container-build.log"
fi
