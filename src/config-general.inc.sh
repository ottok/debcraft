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
  CONTAINER_RUN_ARGS=("--userns=keep-id")
elif [[ $version =~ 'Docker' ]]
then
  CONTAINER_TYPE='docker'
  CONTAINER_RUN_ARGS=("--user=${UID}")
else
  log_error "Invalid value in --container-command=$CONTAINER_CMD"
  exit 1
fi

# Use [ -t 1 ] to check if stdout (file descriptor 1) is attached to a terminal
# in order to later decide if `--tty` can be used when launching containers.
# When running inside a CI system never try to attach a terminal.
if [ -t 1 ] && [ -z "${CI:-}" ]
then
  CONTAINER_CAN_HAVE_TTY=true
fi


# Explicit exports
export CONTAINER_CMD
export CONTAINER_TYPE
export CONTAINER_RUN_ARGS
export CONTAINER_CAN_HAVE_TTY
