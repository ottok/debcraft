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
  elif command -v distrobox-host-exec >/dev/null 2>&1 && distrobox-host-exec podman --version >/dev/null 2>&1
  then
    CONTAINER_CMD="distrobox-host-exec podman"
  elif command -v distrobox-host-exec >/dev/null 2>&1 && distrobox-host-exec docker --version >/dev/null 2>&1
  then
    CONTAINER_CMD="distrobox-host-exec docker"
  else
    log_error "Either 'podman' or 'docker' must be available to use Debcraft"
    exit 1
  fi
fi

# Determine container type and customizations if needed
version=$(${CONTAINER_CMD} --version)
if [[ $version =~ 'podman' ]]
then
  CONTAINER_TYPE='podman'
  CONTAINER_RUN_ARGS='--userns=keep-id'
elif [[ $version =~ 'Docker' ]]
then
  CONTAINER_TYPE='docker'
  CONTAINER_RUN_ARGS="--user=${UID}"
else
  log_error "Invalid value in --container-command=$CONTAINER_CMD"
  exit 1
fi

# Explicit exports
export CONTAINER_CMD
export CONTAINER_TYPE
export CONTAINER_RUN_ARGS

# Enable TTY only for interactive shells (not in GitLab CI) [ -t 1 ] checks if
# stdout (file descriptor 1) is attached to a terminal
if [ -t 1 ] && [ -z "${GITLAB_CI:-}" ]
then
  DEBCRAFT_INTERACTIVE="--interactive --tty"
else
  DEBCRAFT_INTERACTIVE=""
fi
export DEBCRAFT_INTERACTIVE
