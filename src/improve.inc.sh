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
    --volume="${SOURCE_DIR:=$PWD}":/debcraft/source \
    --workdir=/debcraft/source \
    --env="DEB*" \
    "${CONTAINER_RUN_ARGS[@]}" \
    "$CONTAINER" \
    /debcraft-improve.sh \
    || FAILURE="true"

# Regardless if running with `--debug` and if `set -x` was set or not, always
# turn it off now and in a way that does not print extra `++` prefixed lines
{ set +x; } 2>/dev/null

# If the container returned an error code, stop here after cleanup completed
if [ -n "$FAILURE" ]
then
  log_error "Unresolvable issues found - please read the output above carefully"
  exit 1
fi


log_info "Improving package complete"
