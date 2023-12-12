#!/bin/bash

# podman images --noheading --filter reference=debcraft-entr-debian-sid --format "table {{.ID}} {{.Repository}} {{.Tag}} {{.CreatedAt}}"
# 3ea068db053c  localhost/debcraft-entr-debian-sid  latest      2023-12-10 02:36:49 +0000 UTC

# build if
# - container missing
# - container exists, but timestamp older than debian/control file
# - container exitss, but is more than one day old and the previouis build for exact same commit passed, so use --pull to make sure base image is fully up-to-date

# OR - always try to build and let 'podman build' decide if image missing or control file has updated?

# if [ -n "$("$CONTAINER_CMD" images --noheading --filter reference="$CONTAINER")" ] && [ -z "$DEBUG" ]
#then
#  log_info "Container '$CONTAINER' already exists and is newer than package 'control' file, no need to build it"

CONTAINER_DIR="$BUILD_DIRS_PATH/debcraft-container-$PACKAGE"
mkdir --verbose --parents "$CONTAINER_DIR"

log_debug_var "CONTAINER_DIR"

cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER for build $BUILD_ID" >> "$CONTAINER_DIR/status.log"

# Customize baseimage
sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$CONTAINER_DIR/Containerfile"

# Customize preinstalled build dependencies
cp debian/control "$CONTAINER_DIR/control"

# Force pulling new base image
if [ -n "$CLEAN" ]
then
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"
fi

# @TODO: Automatically use --pull when making sure dependencies are updated

# intentionally allow variable to expand to multiple arguments
# shellcheck disable=SC2086
"$CONTAINER_CMD" build  \
  --tag "$CONTAINER" \
  --iidfile="$CONTAINER_DIR/container-$BUILD_ID-iid" \
  $CONTAINER_BUILD_ARGS \
  "$CONTAINER_DIR" \
  | tee -a "$CONTAINER_DIR/build.log" \
  || FAILURE="true"

# @TODO: Redirect all output to log if too verbose?
# --logfile="$CONTAINER_DIR/container-$BUILD_ID.log" \

if [ -n "$FAILURE" ]
then
  tail "$CONTAINER_DIR"/*.log
  echo
  log_error "Container build failed - see logs in $CONTAINER_DIR for details"
  exit 1
fi
