#!/bin/bash

# Obey 'debcraft --distribution' parameter if given
if [ -n "$DISTRIBUTION" ]
then
  DOWNLOAD_BASENAME="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
else
  DOWNLOAD_BASENAME="debian:sid"
fi

log_debug "Building container using base image '$DOWNLOAD_BASENAME'"

DOWNLOAD_CONTAINER="debcraft-${DOWNLOAD_BASENAME//:/-}"

# @TODO: Skip building container in vain repeatedly

CONTAINER_DIR="$(mktemp -d)/debcraft-container"

log_info "Building container '$DOWNLOAD_CONTAINER' in '$CONTAINER_DIR' for downloader use"

mkdir --verbose --parents "$CONTAINER_DIR"
cp --archive "$DEBCRAFT_LIB_DIR"/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER" >> "$CONTAINER_DIR/status.log"

# Customize baseimage to match --distribution parameter
sed "s/FROM debian:sid/FROM $DOWNLOAD_BASENAME/" -i "$CONTAINER_DIR/Containerfile"

# Skip extra files not needed in DOWNLOAD_CONTAINER
sed '/COPY ci/,/^$/d' -i "$CONTAINER_DIR/Containerfile"
sed '/COPY control/,/^$/d' -i "$CONTAINER_DIR/Containerfile"

# Ensure the last line updates the apt archive cache
echo "RUN apt-get update -q" >> "$CONTAINER_DIR/Containerfile"

# Force pulling new base image if requested
if [ -n "$PULL" ]
then
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --no-cache --pull=true"
fi

# intentionally allow variable to expand to multiple arguments
# shellcheck disable=SC2086
$CONTAINER_CMD build  \
  --tag "$DOWNLOAD_CONTAINER" \
  --file "$CONTAINER_DIR/Containerfile" \
  --iidfile="$CONTAINER_DIR/container-$BUILD_ID-iid" \
  $CONTAINER_BUILD_ARGS \
  "$CONTAINER_DIR" \
  | tee -a "$CONTAINER_DIR/build.log" \
  || FAILURE="true"

# @TODO: Redirect all output to log if too verbose?
# --logfile="$CONTAINER_DIR/container-$BUILD_ID.log" \

if [ -n "$FAILURE" ]
then
  log_error "Container build failed - see output above for details"
  exit 1
fi
