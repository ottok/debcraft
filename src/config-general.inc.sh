#!/bin/bash

case "$BUILD_DIRS_PATH" in
  "")
    # If BUILD_DIRS_PATH is not set, use use parent directory
    BUILD_DIRS_PATH="$(cd .. && pwd)"
    ;;
  *)
    # If BUILD_DIRS_PATH is defined, use it as-is
    if [ ! -d "$BUILD_DIRS_PATH" ]
    then
      log_error "Invalid value in --build-dirs-path=$BUILD_DIRS_PATH"
      exit 1
    fi
esac

# Additional sanity check
if touch "$BUILD_DIRS_PATH/debcraft-test"
then
  rm "$BUILD_DIRS_PATH/debcraft-test"
else
  log_error "Unable to access '$BUILD_DIRS_PATH' - check permissions"
  exit 1
fi

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
export BUILD_DIRS_PATH
export CONTAINER_CMD
export CONTAINER_RUN_ARGS
