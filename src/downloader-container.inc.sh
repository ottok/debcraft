#!/bin/bash

# Obey 'debcraft --distribution' parameter if given
if [ -n "$DISTRIBUTION" ]
then
  DOWNLOAD_BASENAME="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
else
  DOWNLOAD_BASENAME="debian:sid"
fi

DOWNLOAD_CONTAINER="debcraft-${DOWNLOAD_BASENAME//:/-}"

# @TODO: Skip building container in vain repeatedly

CONTAINER_DIR="$BUILD_DIRS_PATH/debcraft-container"

log_info "Building container '$DOWNLOAD_CONTAINER' in '$CONTAINER_DIR' for downloader use"

mkdir --verbose --parents "$CONTAINER_DIR"
cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER" >> "$CONTAINER_DIR/status.log"

# Customize baseimage to match --distribution parameter
sed "s/FROM debian:sid/FROM $DOWNLOAD_BASENAME/" -i "$CONTAINER_DIR/Containerfile"

# Skip control file from DOWNLOAD_CONTAINER
sed '/COPY control/,/^$/d' -i "$CONTAINER_DIR/Containerfile"

# Force pulling new base image if requested
if [ -n "$CLEAN" ]
then
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --pull"
fi

# intentionally allow variable to expand to multiple arguments
# shellcheck disable=SC2086
"$CONTAINER_CMD" build  \
  --tag "$DOWNLOAD_CONTAINER" \
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
