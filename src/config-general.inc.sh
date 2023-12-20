#!/bin/bash

case "$CONTAINER_CMD" in
  docker)
    # Using Docker is valid option but requires some extra args to work
    CONTAINER_CMD="docker"
    CONTAINER_RUN_ARGS="--user=${UID}"
    ;;
  podman | "")
    # Default to using Podman
    CONTAINER_CMD="podman"
    CONTAINER_RUN_ARGS="--userns=keep-id"
    ;;
  *)
    log_error "Invalid value in --container-command=$CONTAINER_CMD"
    exit 1
esac

# Explicit exports
export CONTAINER_CMD
export CONTAINER_RUN_ARGS
