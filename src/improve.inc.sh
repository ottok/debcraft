#!/bin/bash

log_info "Improving source package at $PWD"

if [ -n "$DEBUG" ]
then
  set -x
fi

# See build.inc.sh for explanation of container run parameters
# shellcheck disable=SC2086
$CONTAINER_CMD run \
    --name="$CONTAINER" \
    --interactive \
    ${CONTAINER_CAN_HAVE_TTY:+--tty} \
    --rm \
    --shm-size=1G \
    --volume="${SOURCE_DIR:=$PWD}":/tmp/build/source \
    --workdir=/tmp/build/source \
    --env="DEB*" \
    "${CONTAINER_RUN_ARGS[@]}" \
    "$CONTAINER" \
    /debcraft-improve.sh \
    || FAILURE="true"

if [ -n "$DEBUG" ]
then
  set +x
fi

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Unresolvable issues found - please read the output above carefully"
  exit 1
fi


log_info "Improving package complete"
