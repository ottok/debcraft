#!/bin/bash

log_info "Downloading package '$TARGET'"

# Obey 'debuilder --distribution' parameter if given
if [ -n "$DISTRIBUTION" ]
then
  DOWNLOAD_BASENAME="$(get_baseimage_from_distribution_name "$DISTRIBUTION")"
else
  DOWNLOAD_BASENAME="debian:sid"
fi

DOWNLOAD_CONTAINER="debcraft-${DOWNLOAD_BASENAME//:/-}"

CONTAINER_DIR="$BUILD_DIRS_PATH/debcraft-container"
mkdir --verbose --parents "$CONTAINER_DIR"

log_debug_var "CONTAINER_DIR"

cp --archive "$DEBCRAFT_INSTALL_DIR"/src/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER for build $BUILD_ID" >> "$CONTAINER_DIR/status.log"

# Customize baseimage
sed "s/FROM debian:sid/FROM $DOWNLOAD_BASENAME/" -i "$CONTAINER_DIR/Containerfile"

# Customize preinstalled build dependencies
sed '/COPY control/,/^$/d' -i "$CONTAINER_DIR/Containerfile"

# Force pulling new base image
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

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
#   just exit tty)
# NOTE!: If build fails, script fails here (due to set pipefail) and there
# will be no notifications or sounds to user.
# shellcheck disable=SC2086
"$CONTAINER_CMD" run \
    --name="$DOWNLOAD_CONTAINER" \
    --interactive --tty --rm \
    --volume="$PWD":/tmp/download \
    --workdir=/tmp/download \
    $CONTAINER_RUN_ARGS \
    "$DOWNLOAD_CONTAINER" \
    /debcraft-downloader "$TARGET" \
    || FAILURE="true"

if [ -n "$FAILURE" ]
then
  log_error "Downloading package '$TARGET' failed"
  exit 1
fi
