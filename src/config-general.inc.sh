#!/bin/bash

# If no explicit value, try to autodetect and default to Podman if both installed
if [ -z "$CONTAINER_CMD" ]
then
  if command -v podman > /dev/null
  then
    CONTAINER_CMD="podman"
  elif command -v docker > /dev/null
  then
    CONTAINER_CMD="docker"
  else
    log_error "Either 'podman' or 'docker' must be available to use Debcraft"
    exit 1
  fi
fi

# Define customizations if needed
case "$CONTAINER_CMD" in
  docker)
    # Using Docker is valid option but requires some extra args to work
    CONTAINER_RUN_ARGS="--user=${UID}"
    ;;
  podman)
    CONTAINER_RUN_ARGS="--userns=keep-id"
    ;;
  *)
    log_error "Invalid value in --container-command=$CONTAINER_CMD"
    exit 1
esac

# Explicit exports
export CONTAINER_CMD
export CONTAINER_RUN_ARGS
