#!/bin/bash

# @TODO: Skip building container in vain repeatedly
# (if container already exists and is newer than debian/control mtime/ctime)
#
# podman images --noheading --filter reference="$CONTAINER" --format="table {{.ID}} {{.Repository}} {{.Tag}} {{.CreatedAt}} {{.CreatedSince}}"
# 3ea068db053c  localhost/debcraft-entr-debian-sid  latest      2023-12-10 02:36:49 +0000 UTC 5 hours ago
#

CONTAINER_DIR="$BUILD_DIRS_PATH/debcraft-container-$PACKAGE"

log_info "Building container '$CONTAINER' in '$CONTAINER_DIR' for build ID '$BUILD_ID'"

mkdir --verbose --parents "$CONTAINER_DIR"
cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER for build $BUILD_ID" >> "$CONTAINER_DIR/status.log"

# Customize baseimage distribution release/seris to match package to be built
sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$CONTAINER_DIR/Containerfile"

# Customize preinstalled build dependencies to match the package to be built
cp debian/control "$CONTAINER_DIR/control"

# Force pulling new base image
# @TODO: Automatically use --pull when making sure dependencies are updated
if [ -n "$CLEAN" ]
then
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"
fi

# Podman does not need '--file=Containerfile', but needed for Docker compatibility
# shellcheck disable=SC2086 # intentionally allow variable to expand to multiple arguments
"$CONTAINER_CMD" build  \
  --tag "$CONTAINER" \
  --iidfile="$CONTAINER_DIR/container-$BUILD_ID-iid" \
  $CONTAINER_BUILD_ARGS \
  --file="$CONTAINER_DIR/Containerfile" \
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
