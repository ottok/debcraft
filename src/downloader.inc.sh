#!/bin/bash

# Run build inside a container image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
#   just exit tty)
#
# shellcheck disable=SC2086
"$CONTAINER_CMD" run \
    --name="$DOWNLOAD_CONTAINER" \
    --interactive --tty --rm \
    --volume="$PWD":/tmp/debcraft \
    --workdir=/tmp/debcraft \
    $CONTAINER_RUN_ARGS \
    "$DOWNLOAD_CONTAINER" \
    /debcraft-downloader.sh "$TARGET" \
    || FAILURE="true"

if [ -n "$FAILURE" ]
then
  log_error "Downloading package '$TARGET' failed"
  exit 1
fi
